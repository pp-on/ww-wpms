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

# Site status — core version (+ available update), plugin and theme lists per site
do_status() {
    local configs=()
    while IFS= read -r config; do
        configs+=("$config")
    done < <(find "$WORDPRESS_BASE_DIR" -maxdepth 2 -name "wp-config.php" | sort)

    local total=${#configs[@]} idx=0
    local config site_dir name version update key
    for config in "${configs[@]}"; do
        (( ++idx ))
        site_dir="$(dirname "$config")"
        name="$(basename "$site_dir")"

        echo -e "\033[36m================================\n  [$idx/$total] $name\n================================\033[0m"

        if ! $WP_CLI_PATH --path="$site_dir" core is-installed &>/dev/null; then
            echo -e "\033[31mWP ERR — not installed or broken\033[0m"
        else
            version=$($WP_CLI_PATH --path="$site_dir" core version 2>/dev/null || true)
            update=$($WP_CLI_PATH --path="$site_dir" core check-update --field=version 2>/dev/null | grep -v '^Success' | xargs || true)
            if [[ -n "$update" ]]; then
                echo -e "\033[32mWP OK\033[0m  $version \033[33m(update available: $update)\033[0m"
            else
                echo -e "\033[32mWP OK\033[0m  $version (up to date)"
            fi

            echo -e "\033[33mPlugins:\033[0m"
            $WP_CLI_PATH --path="$site_dir" plugin list --fields=name,status,version,update_version 2>/dev/null || echo "  (failed to list plugins)"
            echo -e "\033[33mThemes:\033[0m"
            $WP_CLI_PATH --path="$site_dir" theme list --fields=name,status,version,update_version 2>/dev/null || echo "  (failed to list themes)"
        fi

        if (( idx < total )); then
            read -rsn1 -p "Press any key for next site, c to stop... " key
            echo
            [[ "${key,,}" == "c" ]] && break
        fi
    done
}

# Brief status — core version + plugin/theme update counts, all sites, non-interactive
do_status_brief() {
    local configs=()
    while IFS= read -r config; do
        configs+=("$config")
    done < <(find "$WORDPRESS_BASE_DIR" -maxdepth 2 -name "wp-config.php" | sort)

    local config site_dir name version update p_total p_upd t_total t_upd
    for config in "${configs[@]}"; do
        site_dir="$(dirname "$config")"
        name="$(basename "$site_dir")"

        if ! $WP_CLI_PATH --path="$site_dir" core is-installed &>/dev/null; then
            echo -e "\033[31m$name   WP ERR — not installed or broken\033[0m"
            continue
        fi

        version=$($WP_CLI_PATH --path="$site_dir" core version 2>/dev/null || true)
        update=$($WP_CLI_PATH --path="$site_dir" core check-update --field=version 2>/dev/null | grep -v '^Success' | xargs || true)
        if [[ -n "$update" ]]; then
            echo -e "\033[36m$name\033[0m   WP $version \033[33m(update: $update)\033[0m"
        else
            echo -e "\033[36m$name\033[0m   WP $version (up to date)"
        fi

        p_total=$($WP_CLI_PATH --path="$site_dir" plugin list --format=count 2>/dev/null || echo 0)
        p_upd=$($WP_CLI_PATH --path="$site_dir" plugin list --update=available --format=count 2>/dev/null || echo 0)
        t_total=$($WP_CLI_PATH --path="$site_dir" theme list --format=count 2>/dev/null || echo 0)
        t_upd=$($WP_CLI_PATH --path="$site_dir" theme list --update=available --format=count 2>/dev/null || echo 0)

        if [[ "$p_upd" -gt 0 ]]; then
            echo -e "  plugins: $p_total total, \033[33m$p_upd can be updated\033[0m"
        else
            echo "  plugins: $p_total total, all up to date"
        fi
        if [[ "$t_upd" -gt 0 ]]; then
            echo -e "  themes:  $t_total total, \033[33m$t_upd can be updated\033[0m"
        else
            echo "  themes:  $t_total total, all up to date"
        fi
        echo
    done
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
  -C, --status                 Per-site status: core version (+update), plugin and
                               theme lists; any key = next site, c = stop
  -B, --brief                  Brief status for all sites: core version + plugin/
                               theme totals and updatable counts (non-interactive)
  -l, --list                   List plugins for selected sites
  -T, --themes [NUM|NAME]      List themes; optionally activate by number or name
  -o, --os-detection           Show operating system information
  -c, --colors                 Initialize color scheme

OUTPUT & FORMATTING:
  --out TEXT TYPE             Output formatted text with border
  -t, --text-color TEXT COLOR  Output colored text

GIT OPERATIONS:
  --git SUBCOMMAND            Run git subcommand (pull, log)
  -G, --git-pull              Update repositories via git pull (legacy alias: -gl)

PLUGIN MANAGEMENT:
  -i, --install-plugin PLUGIN Install plugin on selected sites
  -y, --copy-plugins FROM     Copy plugin from path to selected sites
  -u, --update PLUGIN         Update specific plugin (or 'all') (legacy alias: -up)

LICENSE KEYS:
  -f, --acf-pro-lk            Setup ACF Pro license key
  -m, --wp-migrate-db-pro     Setup WP Migrate DB Pro license key
  --akeeba-license            Setup Akeeba Download ID
  --setup-all-licenses        Setup all available license keys

USER MANAGEMENT:
  -n, --new-user              Create new admin user
  -U, --wp-user USER          Set username for new user (default: ${wp_user})
  -P, --wp-password PASS      Set password for new user
  -E, --wp-email EMAIL        Set email for new user (default: ${wp_email})

DATABASE:
  -R, --search-replace OLD NEW  Run wp search-replace across selected sites

WORDPRESS CONFIGURATION:
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
parse_arguments() {
    # Expand combined short flags (e.g. -Ag -> -A -g)
    # Multi-char short flags (-gl, -up) must not be split
    local expanded=()
    for arg in "$@"; do
        if [[ "$arg" == "-gl" || "$arg" == "-up" ]]; then
            expanded+=("$arg")
        elif [[ "$arg" =~ ^-[^-][a-zA-Z]+$ ]]; then
            for ((i=1; i<${#arg}; i++)); do
                expanded+=("-${arg:$i:1}")
            done
        else
            expanded+=("$arg")
        fi
    done
    set -- "${expanded[@]}"

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
                process_sites_all
                ;;
            -H|--health-check)
                do_health_check
                ;;
            -C|--status)
                do_status
                ;;
            -B|--brief)
                do_status_brief
                ;;
            -p|--print)
                print_sites
                ;;
            -c|--colors)
                colors
                ;;
            -l|--list)
                list_wp_plugins
                ;;
            -T|--themes)
                if [[ $# -gt 1 && "${2}" != -* ]]; then
                    shift
                    list_wp_themes "$1"
                else
                    list_wp_themes
                fi
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
                wp_debug "$1"
                ;;
            -z|--hide-errors)
                wp_hide_errors
                ;;
            -f|--acf-pro-lk)
                wp_license_plugins "ACF_PRO"
                ;;
            -m|--wp-migrate-db-pro)
                wp_license_plugins "WPMDB"
                ;;
            --akeeba-license)
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
    # Handle help before anything else
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            show_help
            exit 0
        fi
    done

    log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"

    # Initialize colors if available (sourced from wphelpfunctions.sh)
    type colors &>/dev/null && colors

    sites=()

    # Set verbose mode for search functions
    verbose=1
    export verbose

    # Action flags execute inline during parsing, so the no-selection
    # fallback (current directory) must be prepared before parsing
    local has_selection=0
    for arg in "$@"; do
        case "$arg" in
            -a|--all-sites|-A|--all-sites-auto|-s|--sites) has_selection=1 ;;
            --*) ;;
            -[!-]*) [[ "$arg" == *[aAs]* ]] && has_selection=1 ;;
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
