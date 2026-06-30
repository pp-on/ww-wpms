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
interactive_select=false
auto_all=false
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

# Run a command; in progress mode send its output to the log file instead of the terminal
quiet_run() {
    if [[ "$progress" == true ]]; then
        "$@" &>> "$LOG_FILE"
    else
        "$@"
    fi
}

# Fail with a clear message when an option is missing its argument
require_arg() {
    if [[ -z "${2:-}" ]]; then
        log_error "Option $1 requires an argument"
        exit 1
    fi
}

#===============================================================================
# CORE UPDATE FUNCTIONS
#===============================================================================

# Update WordPress core
update_core() {
    log_info "Checking WordPress core for updates"
    
    local success_check
    success_check=$("${WP_CLI_PATH}" core check-update 2>/dev/null | grep Success || echo "")
    
    if [[ -z "$success_check" ]]; then
        log_info "WordPress core update available"
        
        if [[ "$auto_yes" != "true" ]]; then
            echo -e "\nProceed with Core Update? [y/N]: "
            read -r answer
        else
            [[ "$progress" != true ]] && out "Auto-updating core..." 4
            answer="y"
        fi

        [[ "$progress" != true ]] && echo -e "\n--------------"
        if [[ "$answer" = "y" || "$answer" = "Y" ]]; then
            log_info "Updating WordPress core"
            if quiet_run "${WP_CLI_PATH}" core update --locale="${WP_LOCALE}" --skip-themes; then
                log_success "WordPress core updated successfully"
            else
                log_error "WordPress core update failed"
                return 1
            fi
        else
            log_info "Core update skipped by user"
        fi
    else
        log_info "WordPress core is up to date"
    fi
}

#===============================================================================
# GIT INTEGRATION FUNCTIONS
#===============================================================================

# Update plugins with git integration
update_plugins_with_git() {
    local git_commit_summary=""
    local plugins=()
    local plugin_count=0
    local old_version new_version commit_message
    
    # Change to repository directory
    if ! cd wp-content &>/dev/null; then
        log_error "Cannot access wp-content directory"
        return 1
    fi
    
    # Update repository first
    [[ "$compact" != true && "$progress" != true ]] && out "Updating repository..." 1
    [[ "$compact" != true && "$progress" != true ]] && sleep 1

    if ! git pull &>/dev/null; then
        log_warning "Git pull failed or no remote repository"
    fi
    
    # Process each plugin that needs updating
    local available_updates
    if [[ $minor -eq 0 ]]; then
        available_updates=$("${WP_CLI_PATH}" plugin list --update=available --field=name 2>/dev/null || echo "")
    else
        available_updates=$("${WP_CLI_PATH}" plugin list --update=available --minor --field=name 2>/dev/null || echo "")
    fi
    
    if [[ -z "$available_updates" ]]; then
        log_info "No plugin updates available"
        cd - &>/dev/null
        return 0
    fi

    # Apply only/exclude filters first (exact name match, comma-bounded)
    local filtered=()
    for plugin in $available_updates; do
        if [[ -n "$only_plugins" ]] && [[ ",$only_plugins," != *",$plugin,"* ]]; then
            continue
        fi
        if [[ -n "$exclude_plugins" ]] && [[ ",$exclude_plugins," == *",$plugin,"* ]]; then
            log_info "Skipping excluded plugin: $plugin"
            continue
        fi
        filtered+=("$plugin")
    done

    local _pl_total=${#filtered[@]} _pl_idx=0

    for plugin in "${filtered[@]}"; do
        (( ++_pl_idx ))
        prog "plugins → $plugin ${_pl_idx}/${_pl_total}"

        old_version=$("${WP_CLI_PATH}" plugin get "$plugin" --field=version 2>/dev/null || echo "unknown")
        
        [[ "$compact" != true && "$progress" != true ]] && out "Updating $plugin" 4
        [[ "$compact" != true && "$progress" != true ]] && sleep 1

        if "${WP_CLI_PATH}" plugin update "$plugin" &>/dev/null; then
            new_version=$("${WP_CLI_PATH}" plugin get "$plugin" --field=version 2>/dev/null || echo "unknown")

            if [[ "$old_version" != "$new_version" ]]; then
                plugins[$plugin_count]="$plugin: $old_version → $new_version"
                [[ "$compact" == true && "$progress" != true ]] && echo -e "  ${Green}↑${Color_Off} $plugin $old_version → $new_version"

                [[ "$compact" != true && "$progress" != true ]] && out "Staging changes..." 2
                [[ "$compact" != true && "$progress" != true ]] && sleep 1

                if git add -A "plugins/$plugin" &>/dev/null; then
                    commit_message="plugin ${plugins[$plugin_count]}"

                    [[ "$compact" != true && "$progress" != true ]] && out "Writing commit:" 2
                    [[ "$compact" != true && "$progress" != true ]] && out "chore: update $commit_message" 4
                    
                    if [[ -z "$summary_commit" ]]; then
                        # Separate commit for each plugin
                        if git commit -m "chore: update $commit_message" &>/dev/null; then
                            log_info "Committed update for $plugin"
                        else
                            log_warning "Failed to commit update for $plugin"
                        fi
                    else
                        # Add to summary for single commit
                        git_commit_summary="$git_commit_summary $((plugin_count + 1)). \"$commit_message\""
                    fi
                    
                    ((plugin_count++))
                else
                    log_warning "Failed to stage changes for $plugin"
                fi
            else
                log_warning "Plugin $plugin version unchanged after update"
            fi
        else
            log_error "Failed to update plugin: $plugin"
        fi
    done
    
    # Handle summary commit
    if [[ -n "$summary_commit" && $plugin_count -gt 0 ]]; then
        log_info "Creating summary commit for $plugin_count plugins"
        
        local commit_body=""
        for plugin_info in "${plugins[@]}"; do
            commit_body="$commit_body$plugin_info\n"
        done
        
        if git commit -F- << EOF &>/dev/null
chore: update $plugin_count plugins $(date "+%d-%m-%y")
--------------------------------

$(printf "%s\n" "${plugins[@]}")
EOF
        then
            log_success "Summary commit created successfully"
        else
            log_error "Failed to create summary commit"
        fi
    fi
    
    # Display summary
    if [[ "$progress" != true ]]; then
        sleep 1
        out "Update Summary:" 1
        out "$plugin_count plugins updated" 2

        if [[ -z "$summary_commit" ]]; then
            for plugin_info in "${plugins[@]}"; do
                echo "$plugin_info"
                echo "------------------------------"
            done
        else
            echo "Summary commit with $plugin_count plugin updates"
        fi
    fi
    
    # Handle git push
    if [[ "$auto_yes" != "true" ]]; then
        echo "Push to remote repository? [y/N]: "
        read -r push_answer
        if [[ "$push_answer" = "y" || "$push_answer" = "Y" ]]; then
            if git push &>/dev/null; then
                log_success "Changes pushed to remote repository"
            else
                log_error "Failed to push changes"
            fi
        else
            log_info "Changes not pushed to remote repository"
        fi
    else
        if [[ "$git_mode" -eq 2 ]]; then
            if git push &>/dev/null; then
                log_success "Auto-pushed changes to remote repository"
            else
                log_error "Auto-push failed"
            fi
        else
            log_info "Auto-push disabled"
        fi
    fi
    
    [[ "$progress" != true ]] && sleep 2
    cd - &>/dev/null

    return 0
}

# Update plugins without git
update_plugins_simple() {
    log_info "Checking for plugin updates"
    
    local plugins_needing_update
    if [[ $minor -eq 0 ]]; then
        plugins_needing_update=$("${WP_CLI_PATH}" plugin list --fields=name,update 2>/dev/null | grep available || echo "")
    else
        plugins_needing_update=$("${WP_CLI_PATH}" plugin list --fields=name,update --minor 2>/dev/null | grep available || echo "")
    fi
    
    if [[ -z "$plugins_needing_update" ]]; then
        log_info "No plugin updates available"
        return 0
    fi

    local _pl_count=0
    _pl_count=$(echo "$plugins_needing_update" | wc -l)
    prog "plugins → ${_pl_count} pending"

    if [[ "$auto_yes" != "true" ]]; then
        "${WP_CLI_PATH}" plugin list --update=available
        echo -e "\nAll plugins will be updated. Proceed? [y/N]: "
        read -r answer
        echo -e "\n--------------"

        local plugin_args
        if [[ -n "$only_plugins" ]]; then
            plugin_args="${only_plugins//,/ }"
        else
            plugin_args="--all"
            [[ -n "$exclude_plugins" ]] && plugin_args="--all --exclude=${exclude_plugins}"
        fi

        if [[ "$answer" = "y" || "$answer" = "Y" ]]; then
            # shellcheck disable=SC2086
            if quiet_run "${WP_CLI_PATH}" plugin update $plugin_args; then
                log_success "Plugins updated successfully"
            else
                log_error "Some plugin updates failed"
                return 1
            fi
        else
            log_info "Plugin updates cancelled by user"
        fi
    else
        [[ "$progress" != true ]] && "${WP_CLI_PATH}" plugin list --update=available
        [[ "$progress" != true ]] && out "Auto-updating plugins" 4

        local plugin_args
        if [[ -n "$only_plugins" ]]; then
            plugin_args="${only_plugins//,/ }"
        else
            plugin_args="--all"
            [[ -n "$exclude_plugins" ]] && plugin_args="--all --exclude=${exclude_plugins}"
        fi

        # shellcheck disable=SC2086
        if quiet_run "${WP_CLI_PATH}" plugin update $plugin_args; then
            log_success "Plugins auto-updated successfully"
        else
            log_error "Auto-update failed for some plugins"
            return 1
        fi
    fi
}

# Update themes
update_themes_fn() {
    local theme_args
    if [[ -n "$only_theme" ]]; then
        theme_args="$only_theme"
    else
        theme_args="--all"
    fi

    log_info "Checking for theme updates"

    local _th_list _th_count=0
    _th_list=$("${WP_CLI_PATH}" theme list --update=available --field=name 2>/dev/null)
    [[ -n "$_th_list" ]] && _th_count=$(echo "$_th_list" | wc -l)
    prog "themes → ${_th_count} pending"

    if [[ "$auto_yes" != "true" ]]; then
        "${WP_CLI_PATH}" theme list --update=available
        echo -e "\nProceed with theme update? [y/N]: "
        read -r answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            # shellcheck disable=SC2086
            if quiet_run "${WP_CLI_PATH}" theme update $theme_args; then
                log_success "Themes updated successfully"
            else
                log_error "Theme update failed"
                return 1
            fi
        else
            log_info "Theme update cancelled by user"
        fi
    else
        # shellcheck disable=SC2086
        if quiet_run "${WP_CLI_PATH}" theme update $theme_args; then
            log_success "Themes auto-updated successfully"
        else
            log_error "Auto-update failed for themes"
            return 1
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
        echo -e "${Cyan}→ $site${Color_Off}"
    else
        echo -e "${Cyan}================================"
        echo -e "\t$site"
        echo -e "================================${Color_Off}"
        log_info "Processing site: $site"
    fi

    if ! cd "$site_dir" &>/dev/null; then
        log_error "Cannot access site directory: $site_dir"
        return 1
    fi

    [[ "$compact" != true && "$progress" != true ]] && sleep 1

    # Check if WordPress site is working
    local site_check
    site_check=$("${WP_CLI_PATH}" core check-update 2>&1 || echo "error")

    if [[ "$site_check" == *"error"* ]]; then
        echo -e "${Red}✗ $site: site check failed${Color_Off}"
        cd - &>/dev/null
        return 1
    fi

    [[ "$compact" != true && "$progress" != true ]] && echo -e "${Green}---------------\nChecking Site\n---------------${Color_Off}"
    [[ "$compact" != true && "$progress" != true ]] && echo -e "${Green}Site is functional${Color_Off}"

    # Update WordPress core
    [[ "$compact" != true && "$progress" != true ]] && echo -e "${Yellow}---------------\nChecking Core Updates\n---------------${Color_Off}"
    prog "core"

    if [[ "$core_update" == true ]]; then
        if ! update_core; then
            log_warning "Core update failed for site: $site"
        fi
    else
        log_info "Core update skipped (-c)"
    fi
    
    # Update plugins
    if [[ "$skip_plugins" == true ]]; then
        log_info "Plugin updates skipped (core only)"
    else
        [[ "$compact" != true && "$progress" != true ]] && echo -e "${Yellow}---------------\nChecking Plugin Updates\n---------------${Color_Off}"

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
        [[ "$compact" != true && "$progress" != true ]] && echo -e "${Yellow}---------------\nChecking Theme Updates\n---------------${Color_Off}"
        if ! update_themes_fn; then
            log_warning "Theme update failed for site: $site"
        fi
    fi
    
    log_success "Finished processing site: $site"
    cd - &>/dev/null
    
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
  -a, --all-sites              Discover all sites; prompt y/n/x per site before updating
  -A, --all-sites-auto         Discover all sites; update all without prompting,
                               pause after each site (any key = next, x = exit)
  -B, --batch                  Like -A but no pause; compact one-line-per-plugin output
  -s, --sites SITES            Update specific sites (comma-separated)
  -d DIR                       Set base directory (default: ${WORDPRESS_BASE_DIR:-./})

UPDATE OPTIONS:
  -m, --minor                  Update only patch-level changes (e.g. 8.1.1 → 8.1.2)
  -y, --yes-update             Auto-confirm all updates (no prompts)
  -c, --skip-core              Skip WordPress core update (core is updated by default)
  -x, --exclude-plugins LIST   Exclude plugins from updates (comma-separated)

GIT INTEGRATION:
  -g                          Enable git mode (commit each plugin separately)
  --sum                       Single summary commit for all updates (implies git mode)
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
  webwerk update -a                                    # prompt per site (core + plugins)
  webwerk update -A                                    # auto all, pause between sites
  webwerk update -Ay                                   # auto all, no confirmations
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
            -a|--all-sites)
                process_sites
                interactive_select=true
                ;;
            -A|--all-sites-auto)
                process_sites_all
                auto_all=true
                ;;
            -B|--batch)
                process_sites_all
                auto_all=true
                auto_yes="true"
                compact=true
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
            --sum)
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
            read -rp "Update site '$site'? [y/n/x]: " choice
            case "$choice" in
                y|Y) ;;
                n|N) continue ;;
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

        if [[ "$auto_all" == true && "$compact" != true ]]; then
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
