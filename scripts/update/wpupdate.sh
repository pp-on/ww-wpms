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
minor=0
summary_commit=""
git_mode=0
auto_yes="${AUTO_UPDATE_CONFIRM:-false}"
core_update=""
exclude_plugins=""
sites=()

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

log_warning() {
    echo -e "\033[33m[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $*\033[0m" | tee -a "$LOG_FILE" >&2
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
            out "Auto-updating core..." 4
            answer="y"
        fi
        
        echo -e "\n--------------"
        if [[ "$answer" = "y" || "$answer" = "Y" ]]; then
            log_info "Updating WordPress core"
            if "${WP_CLI_PATH}" core update --locale="${WP_LOCALE}" --skip-themes; then
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
    out "Updating repository..." 1
    sleep 1
    
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
    
    for plugin in $available_updates; do
        # Skip excluded plugins
        if [[ -n "$exclude_plugins" ]] && [[ "$exclude_plugins" =~ $plugin ]]; then
            log_info "Skipping excluded plugin: $plugin"
            continue
        fi
        
        old_version=$("${WP_CLI_PATH}" plugin get "$plugin" --field=version 2>/dev/null || echo "unknown")
        
        out "Updating $plugin" 4
        sleep 1
        
        if "${WP_CLI_PATH}" plugin update "$plugin" &>/dev/null; then
            new_version=$("${WP_CLI_PATH}" plugin get "$plugin" --field=version 2>/dev/null || echo "unknown")
            
            if [[ "$old_version" != "$new_version" ]]; then
                plugins[$plugin_count]="$plugin: $old_version → $new_version"
                
                out "Staging changes..." 2
                sleep 1
                
                if git add -A "plugins/$plugin" &>/dev/null; then
                    commit_message="plugin ${plugins[$plugin_count]}"
                    
                    out "Writing commit:" 2
                    out "chore: update $commit_message" 4
                    
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
    
    sleep 2
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
    
    if [[ "$auto_yes" != "true" ]]; then
        "${WP_CLI_PATH}" plugin list --update=available
        echo -e "\nAll plugins will be updated. Proceed? [y/N]: "
        read -r answer
        echo -e "\n--------------"
        
        if [[ "$answer" = "y" || "$answer" = "Y" ]]; then
            if "${WP_CLI_PATH}" plugin update --all; then
                log_success "All plugins updated successfully"
            else
                log_error "Some plugin updates failed"
                return 1
            fi
        else
            log_info "Plugin updates cancelled by user"
        fi
    else
        "${WP_CLI_PATH}" plugin list --update=available
        out "Auto-updating all plugins" 4
        
        if "${WP_CLI_PATH}" plugin update --all; then
            log_success "All plugins auto-updated successfully"
        else
            log_error "Auto-update failed for some plugins"
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
    local site_dir="${WORDPRESS_BASE_DIR}${site}"
    
    echo -e "${Cyan}================================"
    echo -e "\t$site"
    echo -e "================================${Color_Off}"
    
    log_info "Processing site: $site"
    
    if ! cd "$site_dir" &>/dev/null; then
        log_error "Cannot access site directory: $site_dir"
        return 1
    fi
    
    sleep 1
    
    echo -e "${Green}---------------"
    echo -e "Checking Site"
    echo -e "---------------${Color_Off}"
    
    # Check if WordPress site is working
    local site_check
    site_check=$("${WP_CLI_PATH}" core check-update 2>&1 || echo "error")
    
    if [[ "$site_check" != *"error"* ]]; then
        echo -e "${Green}Site is functional${Color_Off}"
    else
        echo -e "${Red}Site check failed: $site_check${Color_Off}"
        cd - &>/dev/null
        return 1
    fi
    
    # Update WordPress core
    echo -e "${Yellow}---------------"
    echo -e "Checking Core Updates"
    echo -e "---------------${Color_Off}"
    
    if ! update_core; then
        log_warning "Core update failed for site: $site"
    fi
    
    # Update plugins
    echo -e "${Yellow}---------------"
    echo -e "Checking Plugin Updates"
    echo -e "---------------${Color_Off}"
    
    if [[ "$git_mode" -ge 1 ]]; then
        if ! update_plugins_with_git; then
            log_warning "Git-based plugin updates failed for site: $site"
        fi
    else
        if ! update_plugins_simple; then
            log_warning "Plugin updates failed for site: $site"
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

USAGE: $0 [OPTIONS]

SITE SELECTION:
  -a, --all-sites              Update all WordPress sites in directory
  -s, --sites SITES            Update specific sites (comma-separated)
  -d DIR                       Set base directory (default: ${WORDPRESS_BASE_DIR})

UPDATE OPTIONS:
  -m, --minor                  Include minor version updates
  -y, --yes-update             Auto-confirm all updates (no prompts)
  -c, --core-update            Update WordPress core
  -x, --exclude-plugins LIST   Exclude plugins from updates (comma-separated)

GIT INTEGRATION:
  -g                          Enable git mode (commit each plugin separately)
  --sum                       Create single summary commit for all updates
  --gp, --git-push            Enable git push after updates

WP-CLI CONFIGURATION:
  -w PATH                     Set WP-CLI path (default: ${WP_CLI_PATH})
  -u USER                     Set database user (if needed)

OUTPUT & DISPLAY:
  -c, --colors                Initialize color scheme
  -h, --help                  Show this help message

EXAMPLES:
  # Update all sites with auto-confirmation
  $0 --all-sites --yes-update
  
  # Update specific sites with git integration
  $0 --sites site1,site2 -g --sum
  
  # Update with minor versions and exclude specific plugins
  $0 --all-sites --minor --exclude-plugins plugin1,plugin2
  
  # Update and auto-push to git
  $0 --all-sites -g --git-push --yes-update

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

For more information: https://github.com/webwerk/wordpress-tools
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all-sites)
                process_sites
                ;;
            -u)
                shift
                DB_USER="$1"
                export DB_USER
                ;;
            -s|--sites)
                shift
                process_dirs "$1"
                ;;
            -m|--minor)
                minor=1
                ;;
            -y|--yes-update)
                auto_yes="true"
                ;;
            -c|--colors)
                colors
                ;;
            --sum)
                summary_commit="true"
                ;;
            -g)
                git_mode=1
                ;;
            --gp|--git-push)
                git_mode=2
                ;;
            -d)
                shift
                WORDPRESS_BASE_DIR="$1"
                export WORDPRESS_BASE_DIR
                ;;
            -w)
                shift
                WP_CLI_PATH="$1"
                export WP_CLI_PATH
                ;;
            -x|--exclude-plugins)
                shift
                exclude_plugins="$1"
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
    log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    
    # Initialize colors
    colors
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Validate required tools
    if ! command -v "${WP_CLI_PATH}" >/dev/null 2>&1; then
        log_error "WP-CLI not found at: ${WP_CLI_PATH}"
        exit 1
    fi
    
    # Process all selected sites
    local processed_sites=0
    local failed_sites=0
    
    for site in "${sites[@]}"; do
        if process_single_site "$site"; then
            ((processed_sites++))
        else
            ((failed_sites++))
            log_error "Failed to process site: $site"
        fi
    done
    
    # Final summary
    log_success "Update process completed"
    log_info "Sites processed successfully: $processed_sites"
    
    if [[ $failed_sites -gt 0 ]]; then
        log_warning "Sites with failures: $failed_sites"
        exit 1
    fi
    
    log_success "$SCRIPT_NAME completed successfully"
}

# Execute main function with all arguments
main "$@"
