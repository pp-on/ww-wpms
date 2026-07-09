#!/bin/bash
#
# WordPress Update Script v2.0
# Part of Webwerk WordPress Management Suite
# Focused on Barrierefreiheit (Accessibility)
#
# Description: Update WordPress core and plugins across multiple sites
# Author: Webwerk Team
# License: MIT
#

set -euo pipefail

#===============================================================================
# SCRIPT METADATA
#===============================================================================

readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_NAME="WordPress Update Script"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${PWD}/webwerk-update.log"

#===============================================================================
# CONFIGURATION
#===============================================================================

# Initialize variables with defaults from environment
WORDPRESS_BASE_DIR="${WORDPRESS_BASE_DIR:-./}"
minor=0
summary_commit=""
git_mode=0
auto_yes="${AUTO_UPDATE_CONFIRM:-false}"
core_update=true
skip_plugins=false
only_plugins=""
update_themes=false
only_theme=""
exclude_plugins=""
sites=()
updated_plugins=()   # "name: old → new" lines collected per site in git mode
updated_themes=()    # "theme name: old → new" lines collected per site in git mode
auto_all=false
interactive_select=false  # bare `update` (no selection): ask y/n/x before each site
selection_made=false      # any of -s/-a/-A/-B/-l seen? if not, default to interactive-all
push_only=false
compact=false
progress=false
_prog_idx=0
_prog_total=0
_prog_site=""

# Note: Helper functions are loaded by the webwerk dispatcher  
# No need to source wphelpfunctions.sh again - functions are already available

#===============================================================================
# LOGGING FUNCTIONS
#===============================================================================

log_info() {
    if [[ "$progress" == true ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "$LOG_FILE"
    else
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*" | tee -a "$LOG_FILE"
    fi
}

log_error() {
    echo -e "\033[31m[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*\033[0m" | tee -a "$LOG_FILE" >&2
}

log_success() {
    if [[ "$progress" == true ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $*" >> "$LOG_FILE"
    else
        echo -e "\033[32m[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $*\033[0m" | tee -a "$LOG_FILE"
    fi
}

log_warning() {
    echo -e "\033[33m[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $*\033[0m" | tee -a "$LOG_FILE" >&2
}

prog() {
    [[ "$progress" != true ]] && return
    local line width
    line="$(printf '[%s/%s] %s [%s]' "$_prog_idx" "$_prog_total" "$_prog_site" "$1")"
    width=$(( ${COLUMNS:-119} - 1 ))
    printf '\r%b%.*s%b\033[K' "${Cyan}" "$width" "$line" "${Color_Off}"
}

# Run a command with its output routed to the log file, keeping the terminal
# clean (we surface results ourselves via step/render_rows/the compact lines).
quiet_run() {
    "$@" &>> "$LOG_FILE"
}

# Fail with a clear message when an option is missing its argument
require_arg() {
    if [[ -z "${2:-}" ]]; then
        log_error "Option $1 requires an argument"
        exit 1
    fi
}

# True when we can actually read from the controlling terminal. /dev/tty may
# exist as a device node yet fail to open when there's no controlling tty
# (pipes, cron), so test by opening it rather than with -e.
have_tty() {
    { true </dev/tty; } 2>/dev/null
}

#===============================================================================
# OUTPUT HELPERS (normal mode only; compact/-V handle their own output)
#===============================================================================

Dim="\033[2m"

# Colored step line: "▸ label     status".  Status is optional and may itself
# contain colors (printf pads the label; echo -e renders the status).
step() { # color label [status]
    [[ "$compact" == true || "$progress" == true ]] && return 0
    if [[ -n "${3:-}" ]]; then
        printf "${1}▸ %-8s${Color_Off} " "$2"
        echo -e "$3"
    else
        echo -e "${1}▸ ${2}${Color_Off}"
    fi
}

# Indented, name-aligned "name  old → new" rows.
# Args are tab-separated "name<TAB>old<TAB>new" (no color escapes in the fields).
render_rows() {
    [[ "$compact" == true || "$progress" == true ]] && return 0
    local maxw=0 e name old new
    for e in "$@"; do name="${e%%$'\t'*}"; (( ${#name} > maxw )) && maxw=${#name}; done
    for e in "$@"; do
        IFS=$'\t' read -r name old new <<< "$e"
        printf "    ${Green}%-*s${Color_Off}  %s → %s\n" "$maxw" "$name" "$old" "$new"
    done
}

# A quiet, de-emphasized note line ("  · not pushed …").
note() {
    [[ "$compact" == true || "$progress" == true ]] && return 0
    echo -e "  ${Dim}$1${Color_Off}"
}

# A "  ✓ text" / "  ✗ text" result line (text may contain colors).
ok()   { [[ "$compact" == true || "$progress" == true ]] && return 0; echo -e "  ${Green}✓${Color_Off} $1"; }
fail() { [[ "$compact" == true || "$progress" == true ]] && return 0; echo -e "  ${Red}✗${Color_Off} $1"; }

#===============================================================================
# CORE UPDATE FUNCTIONS
#===============================================================================

# Update WordPress core
update_core() {
    local old_ver new_ver up_to_date
    old_ver=$("${WP_CLI_PATH}" core version 2>/dev/null || echo "?")
    up_to_date=$("${WP_CLI_PATH}" core check-update 2>/dev/null | grep -c Success || true)

    if [[ "${up_to_date:-0}" -gt 0 ]]; then
        step "$Blue" core "up to date ${Dim}(${old_ver})${Color_Off}"
        return 0
    fi

    if quiet_run "${WP_CLI_PATH}" core update --locale="${WP_LOCALE}" --skip-themes; then
        new_ver=$("${WP_CLI_PATH}" core version 2>/dev/null || echo "?")
        step "$Blue" core "updated ${old_ver} → ${new_ver}"
    else
        step "$Blue" core "update failed"
        return 1
    fi
}

#===============================================================================
# GIT INTEGRATION FUNCTIONS
#===============================================================================

# Update plugins with git integration
update_plugins_with_git() {
    local plugin_count=0
    local old_version new_version commit_message
    local _pwd="$PWD"

    # Change to repository directory
    if ! cd wp-content &>/dev/null; then
        log_error "Cannot access wp-content directory"
        return 1
    fi
    
    # Update repository first
    if git pull &>/dev/null; then
        step "$Purple" repo "pulled"
    else
        step "$Purple" repo "no remote"
    fi

    # Which plugins have an update available?
    local available_updates
    if [[ $minor -eq 0 ]]; then
        available_updates=$("${WP_CLI_PATH}" plugin list --update=available --field=name 2>/dev/null || echo "")
    else
        available_updates=$("${WP_CLI_PATH}" plugin list --update=available --minor --field=name 2>/dev/null || echo "")
    fi

    # Apply only/exclude filters (exact name match, comma-bounded)
    local filtered=()
    for plugin in $available_updates; do
        [[ -n "$only_plugins" && ",$only_plugins," != *",$plugin,"* ]] && continue
        [[ -n "$exclude_plugins" && ",$exclude_plugins," == *",$plugin,"* ]] && continue
        filtered+=("$plugin")
    done

    if [[ ${#filtered[@]} -eq 0 ]]; then
        step "$Cyan" plugins "up to date"
        cd "$_pwd" &>/dev/null
        return 0
    fi

    local _pl_total=${#filtered[@]} _pl_idx=0
    for plugin in "${filtered[@]}"; do
        (( ++_pl_idx ))
        prog "plugins → $plugin ${_pl_idx}/${_pl_total}"

        old_version=$("${WP_CLI_PATH}" plugin get "$plugin" --field=version 2>/dev/null || echo "?")
        if ! "${WP_CLI_PATH}" plugin update "$plugin" &>/dev/null; then
            fail "plugin $plugin: update failed"
            continue
        fi
        new_version=$("${WP_CLI_PATH}" plugin get "$plugin" --field=version 2>/dev/null || echo "?")
        [[ "$old_version" == "$new_version" ]] && continue

        updated_plugins[$plugin_count]="$plugin"$'\t'"$old_version"$'\t'"$new_version"
        [[ "$compact" == true && "$progress" != true ]] && echo -e "  ${Green}↑${Color_Off} $plugin $old_version → $new_version"

        if git add -A "plugins/$plugin" &>/dev/null; then
            # -S collects for one summary commit (finalize); otherwise commit now
            if [[ -z "$summary_commit" ]]; then
                git commit -m "chore: update plugin $plugin: $old_version → $new_version" &>/dev/null \
                    || log_warning "Failed to commit update for $plugin"
            fi
            ((plugin_count++))
        else
            log_warning "Failed to stage changes for $plugin"
        fi
    done

    step "$Cyan" plugins
    render_rows "${updated_plugins[@]}"

    cd "$_pwd" &>/dev/null
    return 0
}

# Summary commit, update summary and push for git mode.
# Runs after plugins AND themes so theme updates land in the same commit/push.
finalize_git_updates() {
    local _pwd="$PWD"
    if ! cd wp-content &>/dev/null; then
        return 0
    fi

    local np=${#updated_plugins[@]} nt=${#updated_themes[@]}
    local total=$(( np + nt ))

    # Nothing updated this run: no commit, summary or push to do
    if [[ $total -eq 0 ]]; then
        cd "$_pwd" &>/dev/null
        return 0
    fi

    # "N plugins, M themes" (only the non-zero parts)
    local what=""
    (( np > 0 )) && what="$np plugin$([[ $np -ne 1 ]] && echo s)"
    if (( nt > 0 )); then
        [[ -n "$what" ]] && what+=", "
        what+="$nt theme$([[ $nt -ne 1 ]] && echo s)"
    fi

    # -S: one summary commit listing plugins and themes together
    if [[ -n "$summary_commit" ]]; then
        local body="" e name old new
        for e in "${updated_plugins[@]}"; do
            IFS=$'\t' read -r name old new <<< "$e"; body+="  - $name: $old → $new"$'\n'
        done
        for e in "${updated_themes[@]}"; do
            IFS=$'\t' read -r name old new <<< "$e"; body+="  - theme $name: $old → $new"$'\n'
        done
        if git commit -F- <<EOF &>/dev/null
chore: update $what ($(date "+%d-%m-%y"))

$body
EOF
        then
            ok "committed  ${Dim}$(git rev-parse --short HEAD)${Color_Off}  update $what"
        else
            fail "summary commit failed"
        fi
    elif [[ "$git_mode" -ge 1 ]]; then
        ok "committed  ${Dim}$what (separate commits)${Color_Off}"
    fi

    # Push only with -p (git_mode 2). Never prompt.
    if [[ "$git_mode" -eq 2 ]]; then
        local branch; branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
        if git push &>/dev/null; then
            ok "pushed to ${branch}"
        else
            fail "push failed"
        fi
    else
        note "· not pushed (use -p)"
    fi

    cd "$_pwd" &>/dev/null
    return 0
}

# Update plugins without git
update_plugins_simple() {
    # Snapshot name,current,target for the plugins that have an update
    local csv_flag=""
    [[ $minor -ne 0 ]] && csv_flag="--minor"
    local csv
    # shellcheck disable=SC2086
    csv=$("${WP_CLI_PATH}" plugin list --update=available $csv_flag --fields=name,version,update_version --format=csv 2>/dev/null | tail -n +2)

    # Build the display rows, honoring only/exclude filters
    local rows=() name old new r
    while IFS=, read -r name old new; do
        [[ -z "$name" ]] && continue
        [[ -n "$only_plugins" && ",$only_plugins," != *",$name,"* ]] && continue
        [[ -n "$exclude_plugins" && ",$exclude_plugins," == *",$name,"* ]] && continue
        rows+=("$name"$'\t'"$old"$'\t'"$new")
    done <<< "$csv"

    if [[ ${#rows[@]} -eq 0 ]]; then
        step "$Cyan" plugins "up to date"
        return 0
    fi

    prog "plugins → ${#rows[@]} pending"

    local plugin_args
    if [[ -n "$only_plugins" ]]; then
        plugin_args="${only_plugins//,/ }"
    else
        plugin_args="--all"
        [[ -n "$exclude_plugins" ]] && plugin_args="--all --exclude=${exclude_plugins}"
    fi

    # shellcheck disable=SC2086
    if ! quiet_run "${WP_CLI_PATH}" plugin update $plugin_args; then
        step "$Cyan" plugins
        render_rows "${rows[@]}"
        fail "some plugin updates failed"
        return 1
    fi

    step "$Cyan" plugins
    render_rows "${rows[@]}"
    [[ "$compact" == true && "$progress" != true ]] && for r in "${rows[@]}"; do
        IFS=$'\t' read -r name old new <<< "$r"; echo -e "  ${Green}↑${Color_Off} $name $old → $new"
    done
    return 0
}

# Update themes
update_themes_fn() {
    local theme_args
    if [[ -n "$only_theme" ]]; then
        theme_args="$only_theme"
    else
        theme_args="--all"
    fi

    # Snapshot name,current,target for themes that have an update
    local csv rows=() name old new
    csv=$("${WP_CLI_PATH}" theme list --update=available --fields=name,version,update_version --format=csv 2>/dev/null | tail -n +2)
    while IFS=, read -r name old new; do
        [[ -z "$name" ]] && continue
        [[ -n "$only_theme" && "$name" != "$only_theme" ]] && continue
        rows+=("$name"$'\t'"$old"$'\t'"$new")
    done <<< "$csv"

    if [[ ${#rows[@]} -eq 0 ]]; then
        step "$Yellow" themes "up to date"
        return 0
    fi

    prog "themes → ${#rows[@]} pending"

    # shellcheck disable=SC2086
    if ! quiet_run "${WP_CLI_PATH}" theme update $theme_args; then
        step "$Yellow" themes
        render_rows "${rows[@]}"
        fail "some theme updates failed"
        return 1
    fi

    step "$Yellow" themes
    render_rows "${rows[@]}"

    # Track for the git summary; stage now, commit here only in per-item (-g) mode
    updated_themes+=("${rows[@]}")
    if [[ "$git_mode" -ge 1 ]] && git -C wp-content rev-parse --git-dir &>/dev/null; then
        if git -C wp-content add -A themes &>/dev/null; then
            if [[ -z "$summary_commit" ]]; then
                git -C wp-content commit -m "chore: update ${#rows[@]} theme(s) $(date "+%d-%m-%y")" &>/dev/null \
                    || log_warning "Failed to commit theme updates"
            fi
        else
            log_warning "Failed to stage theme updates"
        fi
    fi
}

#===============================================================================
# SITE PROCESSING FUNCTIONS
#===============================================================================

# Process single WordPress site
process_single_site() {
    local site="$1"
    local site_dir="${WORDPRESS_BASE_DIR}/${site}"
    
    if [[ "$progress" == true ]]; then
        log_info "Processing site: $site"
    elif [[ "$compact" == true ]]; then
        echo -e "${Cyan}→ [${_prog_idx}/${_prog_total}] $site${Color_Off}"
    else
        echo -e "${Cyan}== [${_prog_idx}/${_prog_total}] $site ==${Color_Off}"
        log_info "Processing site: $site"
    fi

    local _base_pwd="$PWD"
    if ! cd "$site_dir" &>/dev/null; then
        log_error "Cannot access site directory: $site_dir"
        return 1
    fi

    updated_plugins=()
    updated_themes=()

    [[ "$compact" != true && "$progress" != true ]] && sleep 1

    # Check if WordPress site is working
    local site_check
    site_check=$("${WP_CLI_PATH}" core check-update 2>&1 || echo "error")

    if [[ "$site_check" == *"error"* ]]; then
        fail "$site: site check failed"
        cd "$_base_pwd" &>/dev/null
        return 1
    fi

    # Update WordPress core
    prog "core"
    if [[ "$core_update" == true ]]; then
        if ! update_core; then
            log_warning "Core update failed for site: $site"
        fi
    else
        step "$Blue" core "skipped (-c)"
    fi
    
    # Update plugins
    if [[ "$skip_plugins" == true ]]; then
        log_info "Plugin updates skipped (core only)"
    else
        if [[ "$git_mode" -ge 1 ]]; then
            if ! update_plugins_with_git; then
                log_warning "Git-based plugin updates failed for site: $site"
            fi
        else
            if ! update_plugins_simple; then
                log_warning "Plugin updates failed for site: $site"
            fi
        fi
    fi

    # Update themes (only when explicitly requested)
    if [[ "$update_themes" == true ]]; then
        if ! update_themes_fn; then
            log_warning "Theme update failed for site: $site"
        fi
    fi

    # Git mode: summary commit + push, now that plugins AND themes are done
    if [[ "$git_mode" -ge 1 ]] && [[ "$skip_plugins" != true || "$update_themes" == true ]]; then
        finalize_git_updates
    fi

    cd "$_base_pwd" &>/dev/null
    return 0
}

#===============================================================================
# COMMAND LINE INTERFACE
#===============================================================================

# Show help information
show_help() {
    cat << EOF
WordPress Update Script v${SCRIPT_VERSION}
=========================================

USAGE: webwerk update [core|plugins] [OPTIONS]

TARGET (optional):
  core                         Update WordPress core only
  plugins                      Update all plugins
  plugin <name>                Update one specific plugin — name required
  themes                       Update all themes
  theme <name>                 Update one specific theme — name required
  (omit)                       Update core + plugins + themes (default)

SITE SELECTION:
  (no selection)               Discover every site in the base dir and ask y/n/x
                               before each ('== [N/total] site ==' header)
  -a, --all, --all-sites       Update every site, pausing after each (any key = next,
                               x = exit)
  -A, --all-sites-auto         Update every site, no pause and no confirmations
                               (same as -ay)
  -l, --list-select            List every site numbered, then update the ones you
                               pick (e.g. 1,2,4,11), pausing after each
  -B, --batch                  Like -A but compact one-line-per-plugin output
  -s, --sites SITES            Update specific sites (comma-separated)
  -d DIR                       Set base directory (default: ${WORDPRESS_BASE_DIR:-./})

UPDATE OPTIONS:
  -m, --minor                  Update only patch-level changes (e.g. 8.1.1 → 8.1.2)
  -y, --yes-update             Auto-confirm all updates (no prompts)
  -c, --skip-core              Skip WordPress core update (core is updated by default)
  -x, --exclude-plugins LIST   Exclude plugins from updates (comma-separated)

GIT INTEGRATION:
  -g                          Enable git mode (commit each plugin separately)
  -S, --sum                   Single summary commit for all updates (implies git mode)
  -p, --git-push              Enable git push after updates
  -P, --push-only             Skip updates; just git push selected sites

WP-CLI CONFIGURATION:
  -w PATH                     Set WP-CLI path (default: ${WP_CLI_PATH:-wp})
  -u USER                     Set database user (if needed)

OUTPUT & DISPLAY:
  -V, --progress               Progress-only output: [N/total] site + per-plugin/theme
                               lines; normal output is written to the log file instead
  --colors                    Initialize color scheme
  -h, --help                  Show this help message

EXAMPLES:
  webwerk update                                       # ask y/n/x before each site
  webwerk update -a                                    # update all sites, pause between each
  webwerk update -A                                    # update all, no pause, no prompts (= -ay)
  webwerk update -l                                    # pick sites by number, then update them
  webwerk update core -Ay                              # core only, auto all
  webwerk update plugins -Ay                           # plugins only, auto all
  webwerk update plugins -Ay                           # all plugins, auto all sites
  webwerk update plugin woocommerce -Ay                # one plugin, auto all sites
  webwerk update -A --minor --exclude-plugins plugin1  # patch-level only, skip plugin1
  webwerk update -Agpy                                 # update all, commit, push
  webwerk update -AP                                   # push all sites (no update)

CONFIGURATION:
  Configuration loaded from: .env
  Auto-confirm updates: ${AUTO_UPDATE_CONFIRM:-false}
  WordPress locale: ${WP_LOCALE:-en_US}
  Log file: $LOG_FILE

WORKFLOW:
  1. Check WordPress core for updates
  2. Update core if available (with confirmation)
  3. Check plugins for updates
  4. Update plugins (with git integration if enabled)
  5. Commit and push changes if git mode is active

For more information: https://github.com/ojnickel/ww-wpms
EOF
}

# -l: list every site in the base dir with a number, then let the user pick a
# subset (e.g. "1,2,4,11"). Populates `sites` with the chosen names. Needs a TTY.
select_sites_numbered() {
    local search_dir="${WORDPRESS_BASE_DIR%/}"
    if ! have_tty; then
        log_error "-l needs a terminal to show the list and read your selection."
        exit 1
    fi
    local d name
    local -a all=()
    for d in "$search_dir"/*/; do
        [[ -d "${d}wp-content/" ]] || continue
        name="${d#"$search_dir/"}"; all+=("${name%/}")
    done
    if [[ ${#all[@]} -eq 0 ]]; then
        log_error "No sites found in $search_dir"
        exit 1
    fi
    local i
    for i in "${!all[@]}"; do
        printf '  [%d] %s\n' "$((i + 1))" "${all[i]}" >/dev/tty
    done
    printf 'Select sites (e.g. 1,2,4,11): ' >/dev/tty
    local reply
    read -r reply </dev/tty || reply=""
    local -a picks=()
    IFS=', ' read -ra picks <<< "$reply"
    local p
    for p in "${picks[@]}"; do
        [[ "$p" =~ ^[0-9]+$ ]] || continue
        (( p >= 1 && p <= ${#all[@]} )) || continue
        sites+=("${all[$((p - 1))]}")
    done
    if [[ ${#sites[@]} -eq 0 ]]; then
        log_error "No valid sites selected."
        exit 1
    fi
}

# Parse command line arguments
parse_arguments() {
    # Expand combined short flags (e.g. -Ay -> -A -y)
    local expanded=()
    for arg in "$@"; do
        if [[ "$arg" =~ ^-[^-][a-zA-Z]+$ ]]; then
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
            -a|--all|--all-sites)
                process_sites_all
                auto_all=true
                selection_made=true
                ;;
            -A|--all-sites-auto)
                process_sites_all
                auto_all=true
                auto_yes="true"   # -A == -ay: no confirmations, no between-site pause
                selection_made=true
                ;;
            -l|--list-select)
                select_sites_numbered
                auto_all=true     # pause between the picked sites, like -a
                selection_made=true
                ;;
            -B|--batch)
                process_sites_all
                auto_all=true
                auto_yes="true"
                compact=true
                selection_made=true
                ;;
            -u)
                require_arg "$1" "${2:-}"
                shift
                DB_USER="$1"
                export DB_USER
                ;;
            -s|--sites)
                require_arg "$1" "${2:-}"
                shift
                process_dirs "$1"
                selection_made=true
                ;;
            -m|--minor)
                minor=1
                ;;
            -y|--yes-update)
                auto_yes="true"
                ;;
            -c|--skip-core)
                core_update=false
                ;;
            --skip-plugins)
                skip_plugins=true
                ;;
            --only-plugins)
                require_arg "$1" "${2:-}"
                shift
                only_plugins="$1"
                ;;
            --update-themes)
                update_themes=true
                ;;
            --only-theme)
                require_arg "$1" "${2:-}"
                shift
                only_theme="$1"
                update_themes=true
                ;;
            --colors)
                colors
                ;;
            -S|--sum)
                summary_commit="true"
                # --sum implies git mode (commit); don't downgrade push mode if -p already set
                if [[ "$git_mode" -lt 1 ]]; then git_mode=1; fi
                ;;
            -g)
                git_mode=1
                ;;
            -p|--git-push)
                git_mode=2
                ;;
            -P|--push-only)
                push_only=true
                ;;
            -d)
                require_arg "$1" "${2:-}"
                shift
                WORDPRESS_BASE_DIR="$1"
                export WORDPRESS_BASE_DIR
                ;;
            -w)
                require_arg "$1" "${2:-}"
                shift
                WP_CLI_PATH="$1"
                export WP_CLI_PATH
                ;;
            -x|--exclude-plugins)
                require_arg "$1" "${2:-}"
                shift
                exclude_plugins="$1"
                ;;
            -V|--progress)
                progress=true
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
    # Handle help before anything else; pre-detect -V so the start log stays quiet
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            show_help
            exit 0
        fi
        if [[ "$arg" == "--progress" || "$arg" =~ ^-[a-zA-Z]*V ]]; then
            progress=true
        fi
    done

    log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"

    # Initialize colors if available (sourced from wphelpfunctions.sh)
    type colors &>/dev/null && colors

    # Parse command line arguments
    parse_arguments "$@"

    # No site selection given (bare `update`): discover every site in the base
    # dir and ask y/n/x before each one.
    if [[ "$selection_made" != true ]]; then
        process_sites_all
        interactive_select=true
        if ! have_tty; then
            log_error "'webwerk update' with no site selection asks before each site and needs a terminal."
            log_error "For unattended runs use -A (all, no prompts) or -B (batch)."
            exit 1
        fi
    fi

    _prog_total=${#sites[@]}
    if [[ "$progress" == true && "$_prog_total" -gt 0 ]]; then
        echo -e "Found ${_prog_total} site$([[ "$_prog_total" -eq 1 ]] && echo "" || echo "s")"
    fi

    # Validate required tools (handle "ddev wp" as multi-word command)
    local wp_binary="${WP_CLI_PATH%% *}"
    if ! command -v "$wp_binary" >/dev/null 2>&1; then
        log_error "WP-CLI not found at: ${WP_CLI_PATH}"
        exit 1
    fi
    
    # Process all selected sites
    local processed_sites=0
    local failed_sites=0
    
    for site in "${sites[@]}"; do
        (( ++_prog_idx ))
        _prog_site="$site"

        if [[ "$interactive_select" == true ]]; then
            read -rp "Update site [${_prog_idx}/${_prog_total}] '$site'? [y/n/x]: " choice </dev/tty
            case "$choice" in
                y|Y) ;;
                x|X) log_info "Aborted by user."; exit 0 ;;
                *)   continue ;;
            esac
        fi

        if [[ "$push_only" == true ]]; then
            if (cd "$site" && git push); then
                log_success "Pushed: $site"
                (( ++processed_sites ))
            else
                log_error "Push failed: $site"
                (( ++failed_sites ))
            fi
        elif process_single_site "$site"; then
            (( ++processed_sites ))
        else
            (( ++failed_sites ))
            log_error "Failed to process site: $site"
        fi

        # Pause between sites for -a/-l; -A/-ay/-B (auto_yes) skip it, and so do
        # piped/cron runs (no TTY) so they process every site.
        if [[ "$auto_all" == true && "$compact" != true && "$auto_yes" != "true" && -t 0 ]]; then
            read -rsn1 -p "Press any key to continue, x to exit... " key
            echo
            if [[ "${key,,}" == "x" ]]; then
                log_info "Aborted by user."
                exit 0
            fi
        fi
    done
    
    # Final summary
    log_success "Update process completed"
    log_info "Sites processed successfully: $processed_sites"
    [[ "$progress" == true ]] && echo -e "\n${Green}Done: ${processed_sites} ok, ${failed_sites} failed${Color_Off}"

    if [[ $failed_sites -gt 0 ]]; then
        log_warning "Sites with failures: $failed_sites"
        exit 1
    fi

    log_success "$SCRIPT_NAME completed successfully"
}

# Execute main function with all arguments
main "$@"
