#!/bin/bash
#
# WordPress Local Installation Script v2.0
# Part of Webwerk WordPress Management Suite
# Focused on Barrierefreiheit (Accessibility)
#
# Description: Installs WordPress locally with various configuration options
# Author: Webwerk Team
# License: MIT
#

set -euo pipefail

# Get script directory for sourcing other files
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${PWD}/webwerk-install.log"

#===============================================================================
# CONFIGURATION SECTION
#===============================================================================

# Initialize configuration with derived values
init_config() {
    # Derived values from current directory
    readonly CURRENT_DIR="$(basename "$PWD")"
    
    # Set defaults for variables not configured
    DB_NAME="${DB_NAME:-${CURRENT_DIR//[^a-zA-Z0-9]/_}}"
    WP_URL="${WP_URL:-${LOCAL_URL_BASE:-arbeit.local/repos}/${CURRENT_DIR}}"
    WP_TITLE="${WP_TITLE:-test${CURRENT_DIR^^}}"
    
    # Generate admin password if not set
    if [[ -z "${WP_ADMIN_PASSWORD:-}" ]]; then
        WP_ADMIN_PASSWORD="$(openssl rand -base64 12)"
    fi
    
    # Construct repository URL if not explicitly set
    if [[ -z "${REPO_URL:-}" ]]; then
        # If GIT_SSH_HOST is set, use SSH config host alias (includes user from ~/.ssh/config)
        if [[ -n "${GIT_SSH_HOST:-}" ]]; then
            REPO_URL="${GIT_SSH_HOST}:pfennigparade/${CURRENT_DIR}.git"
        else
            case "${GIT_PROTOCOL:-https}" in
                "https")
                    REPO_URL="https://${GIT_HOST:-github.com}/${GIT_USER:-pfennigparade}/${CURRENT_DIR}.git"
                    ;;
                "ssh")
                    REPO_URL="git@${GIT_HOST:-github.com}:${GIT_USER:-pfennigparade}/${CURRENT_DIR}.git"
                    ;;
            esac
        fi
    fi
    
    log_info "Configuration initialized for: $CURRENT_DIR"
}

#===============================================================================
# LOGGING AND OUTPUT FUNCTIONS
#===============================================================================

# Logging functions
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $*" | tee -a "$LOG_FILE" >&2
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $*" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "Script failed at line $line_number with exit code $exit_code"
    log_error "Last command: $BASH_COMMAND"
    exit $exit_code
}

# Set up error trapping
trap 'handle_error $LINENO' ERR

#===============================================================================
# VALIDATION FUNCTIONS
#===============================================================================

# Validate requirements
validate_requirements() {
    local missing_deps=()
    
    # Check required commands
    local required_commands=("php" "mysql" "git")
    local cmd
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check WP-CLI
    if ! command -v "$WP_CLI_PATH" &> /dev/null; then
        missing_deps+=("wp-cli")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install missing dependencies and try again"
        exit 1
    fi
    
    log_success "All requirements validated"
}

# Validate database connection
validate_database() {
    log_info "Validating database connection..."
    
    if ! mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" &>/dev/null; then
        log_error "Cannot connect to database with provided credentials"
        log_error "Host: $DB_HOST, User: $DB_USER"
        exit 1
    fi
    
    log_success "Database connection validated"
}

#===============================================================================
# INSTALLATION MODES
#===============================================================================

# Install WordPress with all features
install_full_wordpress() {
    log_info "Starting full WordPress installation for: $CURRENT_DIR"
    
    download_wordpress
    create_wp_config
    create_database
    install_wordpress
    setup_htaccess
    disable_search_indexing
    clone_repository
    setup_license_keys
    set_permissions
    
    log_success "Full WordPress installation completed"
}

# Install minimal WordPress (without git repo)
install_minimal_wordpress() {
    log_info "Starting minimal WordPress installation for: $CURRENT_DIR"
    
    download_wordpress
    create_wp_config
    create_database
    install_wordpress
    setup_htaccess
    
    log_success "Minimal WordPress installation completed"
}

# Install WordPress with DDEV
install_ddev_wordpress() {
    log_info "Starting DDEV WordPress installation for: $CURRENT_DIR"
    
    # Override settings for DDEV
    DB_USER="db"
    DB_PASSWORD="db"
    DB_NAME="db"
    DB_HOST="db"
    WP_URL="${CURRENT_DIR}.ddev.site"
    WP_CLI_PATH="ddev wp"
    
    # Initialize DDEV
    log_info "Initializing DDEV configuration"
    ddev config --project-type=wordpress --docroot=. --project-name="$CURRENT_DIR"
    
    log_info "Starting DDEV containers"
    ddev start
    
    download_wordpress
    create_ddev_config
    install_wordpress
    disable_search_indexing
    setup_htaccess
    clone_repository
    setup_license_keys
    set_permissions
    
    log_success "DDEV WordPress installation completed"
}

#===============================================================================
# CORE INSTALLATION FUNCTIONS
#===============================================================================

download_wordpress() {
    log_info "Downloading WordPress core (locale: $WP_LOCALE)"
    $WP_CLI_PATH core download --locale="$WP_LOCALE" --force
    log_success "WordPress core downloaded"
}

create_wp_config() {
    log_info "Creating wp-config.php"
    log_info "Using database host: $DB_HOST"
    
    if [[ -f "wp-config.php" ]]; then
        log_warning "wp-config.php exists, removing..."
        rm wp-config.php
    fi
    
    $WP_CLI_PATH config create \
        --dbname="$DB_NAME" \
        --dbuser="$DB_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost="$DB_HOST" \
        --force
    
    log_success "wp-config.php created"
}

create_ddev_config() {
    log_info "Creating DDEV wp-config.php"
    ddev wp config create \
        --dbname=db \
        --dbuser=db \
        --dbpass=db \
        --dbhost=db \
        --skip-check \
        --force
    log_success "DDEV wp-config.php created"
}

create_database() {
    log_info "Creating database: $DB_NAME"
    $WP_CLI_PATH db reset --yes || {
        log_warning "Database reset failed, creating new database"
        mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "DROP DATABASE IF EXISTS \`$DB_NAME\`; CREATE DATABASE \`$DB_NAME\`;"
    }
    log_success "Database created: $DB_NAME"
}

install_wordpress() {
    log_info "Installing WordPress"
    log_info "Site URL: $WP_URL"
    log_info "Admin User: $WP_ADMIN_USER"
    log_info "Admin Email: $WP_ADMIN_EMAIL"
    
    $WP_CLI_PATH core install \
        --url="$WP_URL" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email
    
    log_success "WordPress installed successfully"
    log_info "Admin credentials - User: $WP_ADMIN_USER, Password: $WP_ADMIN_PASSWORD"
}

clone_repository() {
    if [[ -z "${REPO_URL:-}" ]]; then
        log_warning "No repository URL specified, skipping git clone"
        return 0
    fi
    
    log_info "Cloning repository: $REPO_URL"
    
    if [[ -d "./wp-content/" ]]; then
        log_warning "Removing existing wp-content directory"
        rm -rf ./wp-content/
    fi
    
    if git clone "$REPO_URL" wp-content; then
        log_success "Repository cloned successfully"
        
        log_info "Activating all plugins"
        $WP_CLI_PATH plugin activate --all
        log_success "All plugins activated"
    else
        log_error "Failed to clone repository: $REPO_URL"
        return 1
    fi
}

setup_license_keys() {
    log_info "Setting up license keys"
    
    # ACF Pro License
    if [[ -n "${ACF_PRO_LICENSE:-}" ]]; then
        setup_acf_license
    else
        log_warning "ACF_PRO_LICENSE not found in ~/.keys"
    fi
    
    # WPMDB License  
    if [[ -n "${WPMDB_LICENCE:-}" ]]; then
        setup_wpmdb_license
    else
        log_warning "WPMDB_LICENCE not found in ~/.keys"
    fi
    
    # Akeeba Download ID
    if [[ -n "${AKEEBA_DOWNLOAD_ID:-}" ]]; then
        setup_akeeba_download_id
    else
        log_warning "AKEEBA_DOWNLOAD_ID not found in ~/.keys"
    fi
}

setup_acf_license() {
    log_info "Setting up ACF Pro license"
    if ! grep -q "ACF_PRO_LICENSE" wp-config.php; then
        cat >> wp-config.php << EOF

/* ACF Pro License */
if (!defined('ACF_PRO_LICENSE')) {
    define('ACF_PRO_LICENSE', '$ACF_PRO_LICENSE');
}
EOF
        log_success "ACF Pro license added to wp-config.php"
    else
        log_info "ACF Pro license already exists in wp-config.php"
    fi
}

setup_wpmdb_license() {
    log_info "Setting up WP Migrate DB Pro license"
    if ! grep -q "WPMDB_LICENCE" wp-config.php; then
        cat >> wp-config.php << EOF

/* WP Migrate DB Pro License */
if (!defined('WPMDB_LICENCE')) {
    define('WPMDB_LICENCE', '$WPMDB_LICENCE');
}
EOF
        log_success "WPMDB license added to wp-config.php"
    else
        log_info "WPMDB license already exists in wp-config.php"
    fi
}

setup_akeeba_download_id() {
    log_info "Setting up Akeeba Download ID in database"
    
    # Add Akeeba Download ID to wp_options table
    $WP_CLI_PATH option update akeeba_download_id "$AKEEBA_DOWNLOAD_ID"
    
    log_success "Akeeba Download ID added to database"
}

setup_htaccess() {
    log_info "Creating .htaccess file"
    
    # Get directory structure for RewriteBase
    local parent_dir current_dir target_directory
    parent_dir="$(basename "$(dirname "$PWD")")"
    current_dir="$(basename "$PWD")"
    target_directory="/$parent_dir/$current_dir"
    
    cat > .htaccess << EOF
<IfModule mod_rewrite.c>
RewriteEngine On

# Force HTTPS
RewriteCond %{HTTPS} !=on
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# WordPress specific rules
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase $target_directory
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . $target_directory/index.php [L]
</IfModule>
EOF
    
    chmod 644 .htaccess
    log_success ".htaccess created with RewriteBase: $target_directory"
}

disable_search_indexing() {
    log_info "Disabling search engine indexing for development"
    $WP_CLI_PATH option update blog_public 0
    log_success "Search engine indexing disabled"
}

set_permissions() {
    log_info "Setting file permissions"
    
    # Set proper ownership (adjust as needed for your system)
    if command -v chown &> /dev/null && [[ -n "${WEBSERVER_USER:-}" ]]; then
        chown -R "$WEBSERVER_USER:$WEBSERVER_USER" wp-content/
        log_success "Ownership set to $WEBSERVER_USER"
    fi
    
    # Set proper permissions for uploads
    chmod -R 755 wp-content/uploads/ 2>/dev/null || {
        log_warning "Could not set permissions for wp-content/uploads (may not exist yet)"
    }
    
    log_success "File permissions configured"
}

#===============================================================================
# COMMAND LINE INTERFACE
#===============================================================================

show_help() {
    cat << EOF
WordPress Local Installation Script v2.0
=========================================

TLDR:
  # Quick DDEV install with SSH host alias
  $0 --mode=ddev -G arbeit

  # Full install with custom title
  $0 --mode=full --wp-title="My Site"

  # Minimal install without repo
  $0 --mode=minimal

USAGE: $0 [OPTIONS]

INSTALLATION MODES:
  --mode=full     Full WordPress installation with git repository (default)
  --mode=minimal  Minimal WordPress installation without git repository
  --mode=ddev     DDEV-based WordPress installation

DATABASE OPTIONS:
  --db-host=HOST        Database hostname (default: localhost)
  --db-user=USER        Database username (default: wordpress)
  --db-password=PASS    Database password
  --db-name=NAME        Database name (default: current directory name)

WORDPRESS OPTIONS:
  --wp-url=URL          WordPress site URL
  --wp-title=TITLE      WordPress site title
  --wp-admin-user=USER  WordPress admin username (default: admin)
  --wp-admin-pass=PASS  WordPress admin password (auto-generated if not set)
  --wp-admin-email=EMAIL WordPress admin email

GIT OPTIONS:
  --repo-url=URL        Full repository URL to clone
  --git-user=USER       GitHub username (default: pfennigparade)
  --git-protocol=PROTO  Git protocol: https or ssh (default: https)
  --git-host=HOST       SSH host alias from ~/.ssh/config (e.g., arbeit, privat)
  -G HOST               Short form of --git-host

OTHER OPTIONS:
  --wp-cli=PATH         Path to WP-CLI executable (default: wp)
  --target-dir=DIR      Target installation directory (default: current dir)
  --debug               Enable debug mode
  --help                Show this help message

EXAMPLES:
  $0 --mode=full --wp-title="My Site"
  $0 --mode=ddev --repo-url=https://github.com/user/repo.git
  $0 --mode=ddev -G arbeit
  $0 --mode=minimal --db-host=127.0.0.1

CONFIGURATION FILES:
  .env          Environment variables (optional)
  ~/.keys       License keys (ACF_PRO_LICENSE, WPMDB_LICENCE, AKEEBA_DOWNLOAD_ID)

For more information, visit: https://github.com/webwerk/wordpress-tools
EOF
}

parse_arguments() {
    local mode="full"
    local skip_next=false

    while [[ $# -gt 0 ]]; do
        if [[ "$skip_next" == true ]]; then
            skip_next=false
            shift
            continue
        fi

        case $1 in
            --mode=*)
                mode="${1#*=}"
                ;;
            --db-host=*)
                DB_HOST="${1#*=}"
                ;;
            --db-user=*)
                DB_USER="${1#*=}"
                ;;
            --db-password=*)
                DB_PASSWORD="${1#*=}"
                ;;
            --db-name=*)
                DB_NAME="${1#*=}"
                ;;
            --wp-url=*)
                WP_URL="${1#*=}"
                ;;
            --wp-title=*)
                WP_TITLE="${1#*=}"
                ;;
            --wp-admin-user=*)
                WP_ADMIN_USER="${1#*=}"
                ;;
            --wp-admin-pass=*)
                WP_ADMIN_PASSWORD="${1#*=}"
                ;;
            --wp-admin-email=*)
                WP_ADMIN_EMAIL="${1#*=}"
                ;;
            --repo-url=*)
                REPO_URL="${1#*=}"
                ;;
            --git-user=*)
                GIT_USER="${1#*=}"
                ;;
            --git-protocol=*)
                GIT_PROTOCOL="${1#*=}"
                ;;
            --git-host=*)
                GIT_SSH_HOST="${1#*=}"
                ;;
            -G)
                if [[ -z "${2:-}" ]]; then
                    log_error "-G requires an argument (SSH host alias)"
                    exit 1
                fi
                GIT_SSH_HOST="$2"
                skip_next=true
                ;;
            --wp-cli=*)
                WP_CLI_PATH="${1#*=}"
                ;;
            --target-dir=*)
                cd "${1#*=}" || {
                    log_error "Cannot change to directory: ${1#*=}"
                    exit 1
                }
                ;;
            --debug)
                set -x
                ;;
            --help)
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

    # Set installation mode
    INSTALL_MODE="$mode"
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================

main() {
    log_info "Starting WordPress Local Installation Script v2.0"
    log_info "Working directory: $PWD"
    
    # Note: Configuration is loaded by dispatcher script
    # All environment variables and license keys are already available
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize derived configuration
    init_config
    
    # Validate system requirements
    validate_requirements
    validate_database
    
    # Source required helper functions
    if [[ -f "${SCRIPT_DIR}/../utils/wphelpfunctions.sh" ]]; then
        # shellcheck source=../utils/wphelpfunctions.sh
        source "${SCRIPT_DIR}/../utils/wphelpfunctions.sh"
    else
        log_error "Required file wphelpfunctions.sh not found in ${SCRIPT_DIR}/../utils/"
        exit 1
    fi
    
    if [[ -f "${SCRIPT_DIR}/wpfunctionsinstall.sh" ]]; then
        # shellcheck source=./wpfunctionsinstall.sh
        source "${SCRIPT_DIR}/wpfunctionsinstall.sh"
    else
        log_error "Required file wpfunctionsinstall.sh not found in $SCRIPT_DIR"
        exit 1
    fi
    
    # Execute installation based on mode
    case "$INSTALL_MODE" in
        "full")
            install_full_wordpress
            ;;
        "minimal")
            install_minimal_wordpress
            ;;
        "ddev")
            install_ddev_wordpress
            ;;
        *)
            log_error "Invalid installation mode: $INSTALL_MODE"
            log_error "Valid modes: full, minimal, ddev"
            exit 1
            ;;
    esac
    
    # Display summary
    log_success "Installation completed successfully!"
    log_info "Site URL: $WP_URL"
    log_info "Admin User: $WP_ADMIN_USER"
    log_info "Admin Password: $WP_ADMIN_PASSWORD"
    log_info "Database: $DB_NAME on $DB_HOST"
    log_info "Log file: $LOG_FILE"
}

# Execute main function with all arguments
main "$@"
