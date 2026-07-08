#!/bin/bash
#
# WordPress Site Modification Script v2.0
# Part of Webwerk WordPress Management Suite
# Focused on Barrierefreiheit (Accessibility)
#
# Description: Modify and manage existing WordPress sites
# Author: Webwerk Team
# License: MIT
#

set -euo pipefail

#===============================================================================
# SCRIPT METADATA
#===============================================================================

readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_NAME="WordPress Site Modification Script"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${PWD}/webwerk-mod.log"

#===============================================================================
# CONFIGURATION
#===============================================================================

# Initialize variables with defaults from environment
wp_config_path=""
sites=()
anzahl=0
WORDPRESS_BASE_DIR="${WORDPRESS_BASE_DIR:-$PWD}"

# User management defaults
wp_user="${WP_MOD_DEFAULT_USER:-test}"
wp_password="${WP_MOD_DEFAULT_PASSWORD:-}"
wp_email="${WP_MOD_DEFAULT_EMAIL:-${WP_ADMIN_EMAIL:-}}"

# Note: Helper functions are loaded by the webwerk dispatcher
# No need to source wphelpfunctions.sh again - functions are already available

#===============================================================================
# LOGGING FUNCTIONS
#===============================================================================

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "\033[31m[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*\033[0m" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo -e "\033[32m[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $*\033[0m" | tee -a "$LOG_FILE"
}

# Fail with a clear message when an option is missing its argument
require_arg() {
    if [[ -z "${2:-}" ]]; then
        log_error "Option $1 requires an argument"
        exit 1
    fi
}

# DEPRECATED: the read-only views (status/brief/list/themes/git) moved to
# `webwerk get`. These flags now forward there (carrying the -s/-a selection) and
# print a one-line notice; the aliases will be removed in a future release.
run_get() {
    local target="$1"; shift   # rest = extra get args (e.g. --outdated)
    local sel=()
    if [[ ${#sites[@]} -gt 0 && "${sites[*]}" != "." ]]; then
        sel=(-s "$(IFS=','; echo "${sites[*]}")")
    fi
    WORDPRESS_BASE_DIR="$WORDPRESS_BASE_DIR" WP_CLI_PATH="$WP_CLI_PATH" \
        bash "${SCRIPT_DIR}/../get/wpget.sh" "$target" "${sel[@]}" "$@"
}

forward_to_get() {
    echo -e "\033[33m[deprecated] this view moved to 'webwerk get $1' — forwarding (alias will be removed)\033[0m" >&2
    run_get "$@"
}

#===============================================================================
# HELPER FUNCTIONS
#===============================================================================

# Find wp-config.php in directory
find_wp_config() {
    local search_dir="${1:-${WORDPRESS_BASE_DIR:-.}}"
    wp_config_path=$(find "$search_dir" -name "wp-config.php" 2>/dev/null | head -n 1)
    
    if [[ -n "$wp_config_path" ]]; then
        log_info "Found wp-config.php at: $wp_config_path"
    else
        log_error "wp-config.php not found in: $search_dir"
    fi
}

# Setup Akeeba Download ID (new function)
setup_akeeba_download_id() {
    log_info "Setting up Akeeba Download ID for current site"
    
    if wp_key_akeeba; then
        log_success "Akeeba Download ID configured successfully"
    else
        log_error "Failed to configure Akeeba Download ID"
        return 1
    fi
}

# Run wp search-replace across all WordPress installs in WORDPRESS_BASE_DIR
do_search_replace() {
    local old="$1"
    local new="$2"
    local count=0

    while IFS= read -r config; do
        local site_dir
        site_dir="$(dirname "$config")"
        log_info "[$site_dir] replacing '$old' → '$new'"
        if $WP_CLI_PATH --path="$site_dir" search-replace "$old" "$new" --report-changed-only; then
            ((count++)) || true
        else
            log_error "Failed: $site_dir"
        fi
    done < <(find "$WORDPRESS_BASE_DIR" -maxdepth 2 -name "wp-config.php")

    log_success "Done — $count site(s) updated"
}

# Health check — wp core is-installed across all WP installs in WORDPRESS_BASE_DIR
do_health_check() {
    local ok=0 err=0
    while IFS= read -r config; do
        local site_dir name
        site_dir="$(dirname "$config")"
        name="$(basename "$site_dir")"
        if $WP_CLI_PATH --path="$site_dir" core is-installed 2>/dev/null; then
            echo -e "\033[32mOK\033[0m  $name"
            ((ok++)) || true
        else
            echo -e "\033[31mERR\033[0m $name"
            ((err++)) || true
        fi
    done < <(find "$WORDPRESS_BASE_DIR" -maxdepth 2 -name "wp-config.php" | sort)
    log_info "Health check — $ok OK, $err ERR"
}

# Setup all license keys for current site
setup_all_licenses() {
    log_info "Setting up all license keys for current site"
    
    if wp_setup_all_licenses; then
        log_success "License keys configured successfully"
    else
        log_error "Some license keys failed to configure"
        return 1
    fi
}

#===============================================================================
# COMMAND LINE INTERFACE
#===============================================================================

# Per-WHAT help: webwerk mod theme help
show_theme_help() {
    cat << EOF
webwerk mod theme — activate a theme on selected sites

Usage:
  webwerk mod theme [webwerk|NAME|NUM] [-s sites | -a | -A]

  (no arg)   list installed themes and pick one to activate; with -A
             (no prompts) print the per-site overview like 'get themes'
  webwerk    activate the 'webwerk' theme; skip if already active; if it
             isn't installed, list themes and pick one
  NAME       activate the theme by name
  NUM        activate the theme by its number in the list

Site selection (may appear anywhere on the line):
  -s NAMES   comma-separated site names under the base dir
  -a         all sites under the base dir, prompting y/N per site
  -A         all sites under the base dir, no prompts
  (default: the current directory)

Aliases: -W abbreviates the word 'webwerk' (theme -W = theme webwerk);
-T NUM|NAME also activates.
EOF
}

# Per-WHAT help: webwerk mod plugin help
show_plugin_help() {
    cat << EOF
webwerk mod plugin — manage plugins on selected sites

Usage:
  webwerk mod plugin <action> [NAME|FROM] [-s sites | -a | -A]

Actions:
  install NAME      install (and activate) a plugin   (alias: -i NAME)
  copy FROM         copy a plugin from a path          (alias: -y FROM)
  update NAME|all   update a plugin (or all)           (alias: -u NAME|all)
  activate NAME     activate a plugin
  deactivate NAME   deactivate a plugin
  remove NAME       delete a plugin
  list              list plugins (-> webwerk get plugins)

Site selection (may appear anywhere on the line):
  -s NAMES   comma-separated site names under the base dir
  -a         all sites under the base dir, prompting y/N per site
  -A         all sites under the base dir, no prompts
  (default: the current directory)
EOF
}

# Per-WHAT help: webwerk mod site help
show_site_help() {
    cat << EOF
webwerk mod site — view/change site config on selected sites

Usage:
  webwerk mod site license [show [--values] | set <acf|wpmdb|akeeba|all>]
  webwerk mod site remote  [show | add NAME URL | set [URL]]
  webwerk mod site url     [show | set <home|siteurl|both> [URL]]

No sub-action (or 'show') displays current values; 'set'/'add' change them.
  license show   per-site: is each license applied? (--values also prints the
                 configured keys from ~/.keys/.env)
  license set    apply a license (acf=-f, wpmdb=-m, akeeba=-k, all)
  remote set     set origin's URL; omit URL to edit the current value inline
  url set        update home/siteurl; omit URL to edit the current value inline

Site selection (may appear anywhere on the line; default: current directory):
  -s NAMES   comma-separated site names under the base dir
  -a         all sites under the base dir, prompting y/N per site
  -A         all sites under the base dir, no prompts
EOF
}

# Per-WHAT help: webwerk mod config help
show_config_help() {
    cat << EOF
webwerk mod config — view/change WordPress config toggles on selected sites

Usage:
  webwerk mod config                 show debug / indexing / https state per site
  webwerk mod config debug on|off    toggle WP_DEBUG        (= -x on|off)
  webwerk mod config errors hide|show   hide/show PHP errors   (hide = -z)
  webwerk mod config indexing on|off search-engine indexing (off = -r)
  webwerk mod config https           force HTTPS in wp-config + URLs (= -S)
  webwerk mod config htaccess        create/update .htaccess (= --htaccess)

Site selection (-s NAMES | -a | -A) may appear anywhere; default = current dir.
EOF
}

# Per-WHAT help: webwerk mod branch help
show_branch_help() {
    cat << EOF
webwerk mod branch — wp-content git branch overview and merges per site

Usage:
  webwerk mod branch                 per site: fetch, then show current branch,
                                     tracking branch, ahead/behind, local
                                     branches and working-tree status
  webwerk mod branch merge [NAME]    merge the current branch into NAME
                                     (default: live), then switch back

merge never pushes (push with 'webwerk update -P' or manually) and never
leaves a repo half-done: sites with a dirty tree, detached HEAD or a missing
target branch are skipped, and conflicting merges are aborted.

Site selection (-s NAMES | -a | -A) may appear anywhere; default = current dir.
EOF
}

# Per-WHAT help: webwerk mod user help
show_user_help() {
    cat << EOF
webwerk mod user — manage users on selected sites

Usage:
  webwerk mod user                   list users per site
  webwerk mod user add NAME [--role R] [--pass P] [--email E]

  --role   administrator (default; 'admin' accepted) | editor | author |
           contributor | subscriber. If omitted and interactive, you're prompted
           to pick one (Enter = administrator); non-interactive keeps the default.
  --pass   password (a random 16-char one is generated if omitted)
  --email  email address

Aliases: -n (+ -U/-P/-E) creates an administrator.
Site selection (-s NAMES | -a | -A) may appear anywhere; default = current dir.
EOF
}

# Show help information
show_help() {
    cat << EOF
WordPress Site Modification Script v${SCRIPT_VERSION}
===================================================

USAGE: $0 [OPTIONS]

SITE SELECTION:
  -a, --all-sites              Process all WordPress sites in directory (interactive)
  -A, --all-sites-auto         Process all WordPress sites non-interactively
  -s, --sites SITES            Process specific sites (comma-separated)
  -d, --original-dir DIR       Set base directory (default: ${WORDPRESS_BASE_DIR:-./})

INFORMATION & DISPLAY:
  -p, --print                  Print selected sites
  -H, --health-check           Check all sites with wp core is-installed
  -o, --os-detection           Show operating system information
  -c, --colors                 Initialize color scheme

  Read-only views below have MOVED to 'webwerk get' (these aliases forward there
  and will be removed in a future release):
  -C, --status                 -> webwerk get status
  -B, --brief                  -> webwerk get brief
  -e, --errors                 -> webwerk get brief --errors
  -O, --outdated               -> webwerk get brief --outdated
  -l, --list                   -> webwerk get plugins
  -T, --themes [NUM|NAME]      list -> webwerk get themes; with NUM|NAME activates

SITE CONFIG (webwerk mod site help for details):
  site license [show|set ...]  Show if ACF/WP-Migrate/Akeeba licenses are applied
                               (--values reveals keys); set applies them
  site remote  [show|add|set]  Show/add/set the wp-content git remote
  site url     [show|set ...]  Show/set home & siteurl

THEMES:
  theme [webwerk|NAME|NUM]     Activate a theme. No arg = list & pick. 'webwerk'
                               = activate the webwerk theme (skip if already active;
                               pick one if not installed). NAME|NUM = activate it.
  -W                           Abbreviates the word 'webwerk' ('theme -W')
  (-T NUM|NAME also activates — see the forwarding note above)

OUTPUT & FORMATTING:
  --out TEXT TYPE             Output formatted text with border
  -t, --text-color TEXT COLOR  Output colored text

GIT OPERATIONS (webwerk mod branch help for details):
  branch                      Per-site branch overview (fetch, branch, tracking,
                              ahead/behind, status)
  branch merge [NAME]         Merge current branch into NAME (default live),
                              no push, switch back afterwards
  --git SUBCOMMAND            Run git subcommand (pull, log)
  -G, --git-pull              Update repositories via git pull (legacy alias: -gl)
  -g, --git-status            MOVED -> webwerk get git (this alias forwards)

PLUGIN MANAGEMENT:
  plugin install NAME          Install (+activate) a plugin on selected sites
  plugin copy FROM             Copy a plugin from a path to selected sites
  plugin update NAME|all       Update a plugin (or all)
  plugin activate NAME         Activate a plugin
  plugin deactivate NAME       Deactivate a plugin
  plugin remove NAME           Delete a plugin
  plugin list                  List plugins (-> webwerk get plugins)
  Flag aliases for the first three:
  -i, --install-plugin PLUGIN  = plugin install
  -y, --copy-plugins FROM      = plugin copy
  -u, --update PLUGIN          = plugin update (legacy alias: -up)

LICENSE KEYS:
  -f, --acf-pro-lk            Setup ACF Pro license key
  -m, --wp-migrate-db-pro     Setup WP Migrate DB Pro license key
  -k, --akeeba-license        Setup Akeeba Download ID
  --setup-all-licenses        Setup all available license keys

USER MANAGEMENT (webwerk mod user help for details):
  user [add …]                List users, or add one (role defaults to admin)
  -n, --new-user              Create new admin user (with -U/-P/-E)
  -U, --wp-user USER          Set username for new user (default: ${wp_user})
  -P, --wp-password PASS      Set password for new user
  -E, --wp-email EMAIL        Set email for new user (default: ${wp_email})

DATABASE:
  -R, --search-replace OLD NEW  Run wp search-replace across selected sites

WORDPRESS CONFIGURATION (webwerk mod config help for details):
  config [debug|errors|indexing|https|htaccess …]  View/toggle the settings below
  -x, --wp-debug MODE         Enable/disable debug mode (on/off)
  -z, --hide-errors           Hide WordPress errors
  -r, --disable-search-engine-indexing  Disable search engine indexing
  --enable-search-engine-indexing       Enable search engine indexing
  --htaccess                  Create/update .htaccess file
  -S, --force-https           Force HTTPS (updates wp-config.php and site URLs)

OTHER OPTIONS:
  -w, --location-wp PATH      Set WP-CLI path (default: ${WP_CLI_PATH:-wp})
  -h, --help                  Show this help message

EXAMPLES:
  # Setup ACF Pro license for all sites
  $0 -a --acf-pro-lk
  
  # Create new user on specific sites
  $0 -s site1,site2 --new-user --wp-user newadmin --wp-email admin@example.com
  
  # Update all plugins on all sites with git commits
  $0 -a --update all -g
  
  # Setup all licenses for current directory
  $0 --setup-all-licenses

CONFIGURATION:
  Configuration loaded from: .env
  License keys loaded from: ~/.keys
  Log file: $LOG_FILE

For more information: https://github.com/ojnickel/ww-wpms
EOF
}

# Parse command line arguments
# Expand combined short flags (e.g. -Ag -> -A -g) into EXPANDED_ARGS
# Multi-char short flags (-gl, -up) must not be split
expand_bundled_flags() {
    EXPANDED_ARGS=()
    local arg i
    for arg in "$@"; do
        if [[ "$arg" == "-gl" || "$arg" == "-up" ]]; then
            EXPANDED_ARGS+=("$arg")
        elif [[ "$arg" =~ ^-[^-][a-zA-Z]+$ ]]; then
            for ((i=1; i<${#arg}; i++)); do
                EXPANDED_ARGS+=("-${arg:$i:1}")
            done
        else
            EXPANDED_ARGS+=("$arg")
        fi
    done
}

parse_arguments() {
    expand_bundled_flags "$@"
    set -- ${EXPANDED_ARGS[@]+"${EXPANDED_ARGS[@]}"}

    while [[ $# -gt 0 ]]; do
        case $1 in
            --out)
                require_arg "$1" "${2:-}"
                shift
                out "$1" "${2:-1}"
                [[ $# -gt 1 ]] && shift
                ;;
            -t|--text-color)
                require_arg "$1" "${2:-}"
                shift
                txt "$1" "${2:-c}"
                [[ $# -gt 1 ]] && shift
                ;;
            --git)
                require_arg "$1" "${2:-}"
                shift
                git_wp "$1"
                ;;
            -G|-gl|--git-pull)
                update_repo
                ;;
            -g|--git-status)
                forward_to_get git
                ;;
            -d|--original-dir)
                require_arg "$1" "${2:-}"
                shift
                WORDPRESS_BASE_DIR="$1"
                export WORDPRESS_BASE_DIR
                ;;
            -o|--os-detection)
                os_detection 1
                ;;
            -a|--all-sites)
                process_sites
                ;;
            -A|--all-sites-auto)
                all_sites_auto=1
                process_sites_all
                ;;
            -H|--health-check)
                do_health_check
                ;;
            -C|--status)
                forward_to_get status
                ;;
            -B|--brief)
                forward_to_get brief
                ;;
            -e|--errors)
                forward_to_get brief --errors
                ;;
            -O|--outdated)
                forward_to_get brief --outdated
                ;;
            -p|--print)
                print_sites
                ;;
            -c|--colors)
                colors
                ;;
            -l|--list)
                forward_to_get plugins
                ;;
            -T|--themes)
                if [[ $# -gt 1 && "${2}" != -* ]]; then
                    # number/name given -> activate (a write, stays in mod)
                    shift
                    list_wp_themes "$1"
                else
                    # list-only -> moved to `webwerk get themes`
                    forward_to_get themes
                fi
                ;;
            theme)
                # WHAT form: webwerk mod theme [webwerk|NAME|NUM]
                #   no arg   -> list + interactive pick
                #   webwerk  -> skip if active, pick if missing (-W = 'webwerk')
                #   NAME|NUM -> same as -T NAME|NUM (activate it)
                if [[ $# -gt 1 && "${2}" != -* ]]; then
                    shift
                    if [[ "$1" == "webwerk" ]]; then
                        wp_activate_webwerk_theme
                    else
                        list_wp_themes "$1"
                    fi
                elif [[ ${all_sites_auto:-0} -eq 1 ]]; then
                    # -A is no-prompt; print the per-site overview instead of
                    # the interactive picker (same view as 'get themes')
                    run_get themes
                else
                    list_wp_themes ""
                fi
                ;;
            plugin)
                # WHAT form: webwerk mod plugin <action> [NAME|FROM]
                #   install NAME | copy FROM | update NAME|all  (= -i / -y / -u)
                #   activate NAME | deactivate NAME | remove NAME
                #   list  (-> webwerk get plugins)
                require_arg "plugin" "${2:-}"
                shift
                case "$1" in
                    install)    require_arg "plugin install" "${2:-}";    shift; install_plugins "$1" ;;
                    copy)       require_arg "plugin copy" "${2:-}";       shift; copy_plugins "$1" ;;
                    update)     require_arg "plugin update" "${2:-}";     shift; wp_update "$1" ;;
                    activate)   require_arg "plugin activate" "${2:-}";   shift; wp_plugin_action activate "$1" ;;
                    deactivate) require_arg "plugin deactivate" "${2:-}"; shift; wp_plugin_action deactivate "$1" ;;
                    remove)     require_arg "plugin remove" "${2:-}";     shift; wp_plugin_action delete "$1" ;;
                    list)       forward_to_get plugins ;;
                    *) log_error "plugin: unknown action '$1'. Use: install, copy, update, activate, deactivate, remove, list"; exit 1 ;;
                esac
                ;;
            site)
                # WHAT form: webwerk mod site <license|remote|url> [show|set|add ...]
                # Terminal: reads positionals directly and returns. Selection/config
                # flags are hoisted to the front in main(), so they may appear anywhere.
                local _sub="${2:-}" a3="${3:-}" a4="${4:-}" a5="${5:-}"
                case "$_sub" in
                    license)
                        case "$a3" in
                            ""|show)
                                if [[ "$a4" == "--values" || "$a4" == "-x" ]]; then
                                    site_license_status 1; else site_license_status 0; fi ;;
                            --values|-x) site_license_status 1 ;;
                            set)
                                [[ -z "$a4" ]] && { log_error "site license set <acf|wpmdb|akeeba|all>"; exit 1; }
                                site_license_set "$a4" ;;
                            *) log_error "site license: use [show [--values]] | set <acf|wpmdb|akeeba|all>"; exit 1 ;;
                        esac ;;
                    remote)
                        case "$a3" in
                            ""|show) site_remote_show ;;
                            add)
                                [[ -z "$a4" || -z "$a5" ]] && { log_error "site remote add NAME URL"; exit 1; }
                                site_remote_add "$a4" "$a5" ;;
                            set) site_remote_set "$a4" ;;
                            *) log_error "site remote: use [show] | add NAME URL | set [URL]"; exit 1 ;;
                        esac ;;
                    url)
                        case "$a3" in
                            ""|show) site_url_show ;;
                            set)
                                case "$a4" in
                                    home)         site_url_set home "$a5" ;;
                                    siteurl|site) site_url_set siteurl "$a5" ;;
                                    both)         site_url_set both "$a5" ;;
                                    "") log_error "site url set <home|siteurl|both> [URL]"; exit 1 ;;
                                    *)  site_url_set both "$a4" ;;
                                esac ;;
                            *) log_error "site url: use [show] | set <home|siteurl|both> [URL]"; exit 1 ;;
                        esac ;;
                    "") log_error "site: use license | remote | url"; exit 1 ;;
                    *) log_error "site: unknown target '$_sub'. Use: license, remote, url"; exit 1 ;;
                esac
                return 0
                ;;
            branch)
                # WHAT form: webwerk mod branch [merge [NAME]]
                #   no action -> per-site wp-content branch overview (fetches first)
                #   merge     -> merge current branch into NAME (default live), no push
                local b_sub="${2:-}" b_target="${3:-}"
                case "$b_sub" in
                    ""|show) site_branch_show ;;
                    merge)   site_branch_merge "${b_target:-live}" ;;
                    *) log_error "branch: use [show] | merge [NAME]  (NAME defaults to 'live')"; exit 1 ;;
                esac
                return 0
                ;;
            config)
                # WHAT form: webwerk mod config <debug|errors|indexing|https|htaccess> [on|off|hide|show]
                local c_what="${2:-}" c_val="${3:-}"
                case "$c_what" in
                    ""|show)  site_config_show ;;
                    debug)    [[ "$c_val" =~ ^(on|off)$ ]]   || { log_error "config debug on|off"; exit 1; };    site_config debug "$c_val" ;;
                    errors)   [[ "$c_val" =~ ^(hide|show)$ ]] || { log_error "config errors hide|show"; exit 1; }; site_config errors "$c_val" ;;
                    indexing) [[ "$c_val" =~ ^(on|off)$ ]]   || { log_error "config indexing on|off"; exit 1; }; site_config indexing "$c_val" ;;
                    https)    wp_force_https ;;
                    htaccess) site_config htaccess ;;
                    *) log_error "config: use [show] | debug on|off | errors hide|show | indexing on|off | https | htaccess"; exit 1 ;;
                esac
                return 0
                ;;
            user)
                # WHAT form: webwerk mod user [add NAME [--role R] [--pass P] [--email E]]
                shift  # consume 'user'
                case "${1:-show}" in
                    ""|show) site_user_show ;;
                    add)
                        shift  # consume 'add'
                        local u_name="" u_role="administrator" u_role_set=0 u_pass="" u_email=""
                        while [[ $# -gt 0 ]]; do
                            case "$1" in
                                --role)  shift; [[ $# -gt 0 ]] && { u_role="$1"; u_role_set=1; shift; } ;;
                                --pass)  shift; [[ $# -gt 0 ]] && { u_pass="$1"; shift; } ;;
                                --email) shift; [[ $# -gt 0 ]] && { u_email="$1"; shift; } ;;
                                -*) log_error "user add: unknown option '$1'"; exit 1 ;;
                                *)  [[ -z "$u_name" ]] && u_name="$1"; shift ;;
                            esac
                        done
                        [[ -z "$u_name" ]]  && { log_error "user add NAME [--role R] [--pass P] [--email E]"; exit 1; }
                        # role omitted + interactive -> pick one (Enter = administrator);
                        # non-interactive (piped/scripted) keeps the administrator default
                        if [[ $u_role_set -eq 0 && -t 0 ]]; then
                            u_role="$(pick_user_role)"
                        fi
                        [[ "$u_role" == "admin" ]] && u_role="administrator"
                        [[ -z "$u_role" ]]  && u_role="administrator"
                        [[ -z "$u_pass" ]]  && u_pass="$(generate_random_string 16)"
                        [[ -z "$u_email" ]] && u_email="${wp_email:-}"
                        out "Creating user ${u_name} (role: ${u_role})" 1
                        site_user_add "$u_name" "$u_role" "$u_pass" "$u_email" ;;
                    *) log_error "user: use [show] | add NAME [--role R] [--pass P] [--email E]"; exit 1 ;;
                esac
                return 0
                ;;
            -s|--sites)
                require_arg "$1" "${2:-}"
                shift
                process_dirs "$1"
                ;;
            -u|-up|--update)
                require_arg "$1" "${2:-}"
                shift
                wp_update "$1"
                ;;
            --htaccess)
                htaccess
                ;;
            -S|--force-https)
                wp_force_https
                ;;
            -x|--wp-debug)
                require_arg "$1" "${2:-}"
                shift
                site_config debug "$1"
                ;;
            -z|--hide-errors)
                site_config errors hide
                ;;
            -f|--acf-pro-lk)
                wp_license_plugins "ACF_PRO"
                ;;
            -m|--wp-migrate-db-pro)
                wp_license_plugins "WPMDB"
                ;;
            -k|--akeeba-license)
                setup_akeeba_download_id
                ;;
            --setup-all-licenses)
                setup_all_licenses
                ;;
            -r|--disable-search-engine-indexing)
                wp_block_se
                ;;
            --enable-search-engine-indexing)
                wp_enable_se
                ;;
            -i|--install-plugin)
                require_arg "$1" "${2:-}"
                shift
                install_plugins "$1"
                ;;
            -y|--copy-plugins)
                require_arg "$1" "${2:-}"
                shift
                copy_plugins "$1"
                ;;
            -n|--new-user)
                # Generate password if not set
                if [[ -z "$wp_password" ]]; then
                    wp_password=$(generate_random_string 16)
                fi
                
                out "Creating user ${wp_user} with password ${wp_password}" 1
                echo "Continue? [y/N]: "
                read -r answer
                
                if [[ "$answer" = "y" || "$answer" = "Y" ]]; then
                    wp_new_user "$wp_user" "$wp_password" "$wp_email"
                else
                    out "User creation aborted" 3
                fi
                ;;
            -U|--wp-user)
                require_arg "$1" "${2:-}"
                shift
                wp_user="$1"
                ;;
            -P|--wp-password)
                require_arg "$1" "${2:-}"
                shift
                wp_password="$1"
                ;;
            -E|--wp-email)
                require_arg "$1" "${2:-}"
                shift
                wp_email="$1"
                ;;
            -w|--location-wp)
                require_arg "$1" "${2:-}"
                shift
                WP_CLI_PATH="$1"
                export WP_CLI_PATH
                ;;
            -R|--search-replace)
                if [[ -z "${2:-}" || -z "${3:-}" ]]; then
                    log_error "Option -R/--search-replace requires two arguments: OLD NEW"
                    exit 1
                fi
                shift
                local _sr_old="$1"
                shift
                local _sr_new="$1"
                do_search_replace "$_sr_old" "$_sr_new"
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                log_error "Use --help for usage information"
                exit 1
                ;;
        esac
        shift
    done
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================

main() {
    # Handle help before anything else (generic, or WHAT-scoped: theme/plugin)
    local _help_req=0 _help_what=""
    for arg in "$@"; do
        case "$arg" in
            -h|--help|help)              _help_req=1 ;;
            theme|plugin|site|config|user|branch) _help_what="$arg" ;;
        esac
    done
    if [[ $_help_req -eq 1 ]]; then
        case "$_help_what" in
            theme)  show_theme_help ;;
            plugin) show_plugin_help ;;
            site)   show_site_help ;;
            config) show_config_help ;;
            user)   show_user_help ;;
            branch) show_branch_help ;;
            *)      show_help ;;
        esac
        exit 0
    fi

    log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"

    # Initialize colors if available (sourced from wphelpfunctions.sh)
    type colors &>/dev/null && colors

    sites=()

    # Set verbose mode for search functions
    verbose=1
    export verbose

    # Split bundled short flags first (e.g. -Wa -> -W -a), so the hoist below
    # also catches selection flags hidden inside a bundle.
    expand_bundled_flags "$@"
    set -- ${EXPANDED_ARGS[@]+"${EXPANDED_ARGS[@]}"}

    # -W abbreviates the word 'webwerk' (e.g. 'theme -W' = 'theme webwerk')
    local _args=() _arg
    for _arg in "$@"; do
        [[ "$_arg" == "-W" ]] && _arg="webwerk"
        _args+=("$_arg")
    done
    set -- ${_args[@]+"${_args[@]}"}

    # Forgiving ordering: hoist config (-d/-w) then selection (-s/-a/-A) to the
    # front, so they take effect no matter where they appear on the line (WHAT
    # actions like 'site' consume the rest and run in place, so a trailing
    # '-s'/'-A' would otherwise be missed). Relative order is otherwise preserved.
    local _cfg=() _sel=() _rest=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--original-dir|-w|--location-wp)
                _cfg+=("$1"); shift
                [[ $# -gt 0 ]] && { _cfg+=("$1"); shift; } ;;
            -s|--sites)
                _sel+=("$1"); shift
                [[ $# -gt 0 ]] && { _sel+=("$1"); shift; } ;;
            -a|--all-sites|-A|--all-sites-auto)
                _sel+=("$1"); shift ;;
            *)
                _rest+=("$1"); shift ;;
        esac
    done
    set -- ${_cfg[@]+"${_cfg[@]}"} ${_sel[@]+"${_sel[@]}"} ${_rest[@]+"${_rest[@]}"}

    # Action flags execute inline during parsing, so the no-selection
    # fallback (current directory) must be prepared before parsing
    local has_selection=0
    for arg in "$@"; do
        case "$arg" in
            -a|--all-sites|-A|--all-sites-auto|-s|--sites) has_selection=1 ;;
        esac
    done
    if [[ $has_selection -eq 0 ]]; then
        sites=(".")
        log_info "No sites specified, using current directory"
    fi

    # Parse command line arguments
    parse_arguments "$@"

    log_success "$SCRIPT_NAME completed successfully"
}

# Execute main function with all arguments
main "$@"
