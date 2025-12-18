




























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
proc_sites=0
sites=()
anzahl=0

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
  -a, --all-sites              Process all WordPress sites in directory
  -s, --sites SITES            Process specific sites (comma-separated)
  -d, --original-dir DIR       Set base directory (default: ${WORDPRESS_BASE_DIR})

INFORMATION & DISPLAY:
  -p, --print                  Print selected sites
  -l, --list                   List plugins for selected sites
  -o, --os-detection           Show operating system information
  -c, --colors                 Initialize color scheme

OUTPUT & FORMATTING:
  --out TEXT TYPE             Output formatted text with border
  -t, --text-color TEXT COLOR  Output colored text

GIT OPERATIONS:
  -g                          Enable git mode
  --git SUBCOMMAND            Run git subcommand (pull, log)
  -gl, --git-pull             Update repositories via git pull

PLUGIN MANAGEMENT:
  -i, --install-plugin PLUGIN Install plugin on selected sites
  -y, --copy-plugins FROM     Copy plugin from path to selected sites
  -up, --update PLUGIN        Update specific plugin (or 'all')

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

WORDPRESS CONFIGURATION:
  -x, --wp-debug MODE         Enable/disable debug mode (on/off)
  -z, --hide-errors           Hide WordPress errors
  -r, --disable-search-engine-indexing  Disable search engine indexing
  --htaccess                  Create/update .htaccess file
  -S, --force-https           Force HTTPS (updates wp-config.php and site URLs)

OTHER OPTIONS:
  -w, --location-wp PATH      Set WP-CLI path (default: ${WP_CLI_PATH})
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

For more information: https://github.com/webwerk/wordpress-tools
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --out)
                shift
                out "$1" "${2:-1}"
                shift
                ;;
            -t|--text-color)
                shift
                txt "$1" "${2:-c}"
                shift
                ;;
            --git)
                shift
                git_wp "$1"
                ;;
            -gl|--git-pull)
                update_repo
                ;;
            -g)
                git=1
                ;;
            -d|--original-dir)
                shift
                WORDPRESS_BASE_DIR="$1"
                export WORDPRESS_BASE_DIR
                ;;
            -o|--os-detection)
                os_detection 1
                ;;
            -a|--all-sites)
                process_sites
                proc_sites=1
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
            -s|--sites)
                shift
                process_dirs "$1"
                proc_sites=1
                ;;
            -up|--update)
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
            -i|--install-plugin)
                shift
                install_plugins "$1"
                ;;
            -y|--copy-plugins)
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
                shift
                wp_user="$1"
                ;;
            -P|--wp-password)
                shift
                wp_password="$1"
                ;;
            -E|--wp-email)
                shift
                wp_email="$1"
                ;;
            -w|--location-wp)
                shift
                WP_CLI_PATH="$1"
                export WP_CLI_PATH
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

    # Initialize sites array with current directory as default
    # This will be used if no -a or -s flags are provided
    sites=("${WORDPRESS_BASE_DIR}")

    # Parse command line arguments
    parse_arguments "$@"

    # Find wp-config.php if needed
    find_wp_config

    # Update sites array if no explicit site selection was made
    if [[ $proc_sites -eq 0 ]]; then
        log_info "No sites specified, using current directory: ${WORDPRESS_BASE_DIR}"
    fi

    # Set verbose mode for search functions
    verbose=1
    export verbose

    log_success "$SCRIPT_NAME completed successfully"
}

# Execute main function with all arguments
main "$@"
