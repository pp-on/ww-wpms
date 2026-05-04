    #!/bin/bash
#
# WordPress Installation Functions v2.0
# Part of Webwerk WordPress Management Suite
# Focused on Barrierefreiheit (Accessibility)
#
# Description: Core installation functions for WordPress sites
# Author: Webwerk Team
# License: MIT
#

set -euo pipefail

#===============================================================================
# SCRIPT METADATA
#===============================================================================

# Only set if not already defined (avoid readonly conflicts)
if [[ -z "${SCRIPT_VERSION:-}" ]]; then
    readonly SCRIPT_VERSION="2.0"
fi
if [[ -z "${SCRIPT_NAME:-}" ]]; then
    readonly SCRIPT_NAME="WordPress Installation Functions"
fi
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

#===============================================================================
# LOGGING FUNCTIONS
#===============================================================================

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*" | tee -a "${LOG_FILE:-${PWD}/webwerk-install.log}"
}

log_error() {
    echo -e "\033[31m[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*\033[0m" | tee -a "${LOG_FILE:-${PWD}/webwerk-install.log}" >&2
}

log_warning() {
    echo -e "\033[33m[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $*\033[0m" | tee -a "${LOG_FILE:-${PWD}/webwerk-install.log}" >&2
}

log_success() {
    echo -e "\033[32m[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $*\033[0m" | tee -a "${LOG_FILE:-${PWD}/webwerk-install.log}"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "\033[36m[$(date +'%Y-%m-%d %H:%M:%S')] [DEBUG] $*\033[0m" | tee -a "${LOG_FILE:-${PWD}/webwerk-install.log}" >&2
    fi
}

#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

# Generate secure password
generate_wp_password() {
    if [[ -z "${WP_ADMIN_PASSWORD:-}" ]]; then
        if command -v openssl >/dev/null 2>&1; then
            WP_ADMIN_PASSWORD="$(openssl rand -base64 16 | tr -d '=' | head -c 16)"
        else
            WP_ADMIN_PASSWORD="wp$(date +%s | sha256sum | head -c 16)"
        fi
        export WP_ADMIN_PASSWORD
        log_debug "Generated password: $WP_ADMIN_PASSWORD"
    fi
}

# Load MySQL fallback functions when needed
load_mysql_fallback() {
    local mysql_fallback_script="${SCRIPT_DIR}/mysql_fallback_functions.sh"
    
    if [[ -f "$mysql_fallback_script" ]]; then
        log_warning "WP-CLI database functions failed, loading MySQL fallback functions"
        # shellcheck source=./mysql_fallback_functions.sh
        source "$mysql_fallback_script"
        return 0
    else
        log_error "MySQL fallback script not found: $mysql_fallback_script"
        return 1
    fi
}

#===============================================================================
# DATABASE FUNCTIONS (WP-CLI FIRST, MYSQL FALLBACK)
#===============================================================================

# Reset WordPress database (WP-CLI first, MySQL fallback)
reset_wordpress_database() {
    local db_name="${1:-$DB_NAME}"
    
    log_info "Resetting WordPress database: $db_name"
    
    # Try WP-CLI database reset first
    if command -v ${WP_CLI_PATH%% *} >/dev/null 2>&1; then
        log_debug "Attempting WP-CLI database reset"
        if ${WP_CLI_PATH} db reset --yes 2>/dev/null; then
            log_success "Database reset via WP-CLI"
            return 0
        else
            log_warning "WP-CLI database reset failed, trying MySQL fallback"
        fi
    else
        log_debug "WP-CLI not available, using MySQL fallback"
    fi
    
    # Load MySQL fallback functions and try manual reset
    if load_mysql_fallback; then
        if mysql_reset_database "$db_name"; then
            log_success "Database reset via MySQL fallback"
            return 0
        fi
    fi
    
    log_error "All database reset methods failed"
    return 1
}

# Test database connection (WP-CLI first, MySQL fallback)
test_database_connection() {
    log_info "Testing database connection"
    
    # Try WP-CLI database check first
    if command -v ${WP_CLI_PATH%% *} >/dev/null 2>&1; then
        if ${WP_CLI_PATH} db check 2>/dev/null; then
            log_success "Database connection successful (WP-CLI)"
            return 0
        else
            log_debug "WP-CLI database check failed, trying MySQL fallback"
        fi
    fi
    
    # Load MySQL fallback and test connection
    if load_mysql_fallback; then
        if mysql_test_connection; then
            log_success "Database connection successful (MySQL fallback)"
            return 0
        fi
    fi
    
    log_error "Database connection failed"
    return 1
}

#===============================================================================
# WORDPRESS CORE FUNCTIONS
#===============================================================================

# Download WordPress core
download_wordpress_core() {
    local locale="${1:-${WP_LOCALE}}"
    local force="${2:-true}"
    
    log_info "Downloading WordPress core (locale: $locale)"
    
    # Check if WordPress already exists
    if [[ -f "wp-config-sample.php" && "$force" != "true" ]]; then
        log_info "WordPress core already exists, skipping download"
        return 0
    fi
    
    if ${WP_CLI_PATH} core download --locale="$locale" --force; then
        # Verify download
        if [[ -f "wp-config-sample.php" && -f "index.php" && -d "wp-includes" ]]; then
            log_success "WordPress core downloaded and verified"
            return 0
        else
            log_error "WordPress download incomplete - missing core files"
            return 1
        fi
    else
        log_error "Failed to download WordPress core"
        return 1
    fi
}

# Create wp-config.php
create_wordpress_config() {
    local db_name="${1:-$DB_NAME}"
    local db_user="${2:-$DB_USER}"
    local db_password="${3:-$DB_PASSWORD}"
    local db_host="${4:-$DB_HOST}"
    local db_prefix="${5:-$DB_PREFIX}"
    
    log_info "Creating wp-config.php"
    log_info "Database: $db_name on $db_host (prefix: $db_prefix)"
    
    # Remove existing wp-config.php
    if [[ -f "wp-config.php" ]]; then
        log_warning "Removing existing wp-config.php"
        rm -f wp-config.php
    fi
    
    # Create wp-config.php
    if ${WP_CLI_PATH} config create \
        --dbname="$db_name" \
        --dbuser="$db_user" \
        --dbpass="$db_password" \
        --dbhost="$db_host" \
        --dbprefix="$db_prefix" \
        --force; then
        
        # Add enhanced configuration
        add_enhanced_wp_config
        
        # Set secure permissions
        chmod "${CONFIG_FILE_PERMISSIONS:-600}" wp-config.php
        
        log_success "wp-config.php created successfully"
        return 0
    else
        log_error "Failed to create wp-config.php"
        return 1
    fi
}

# Create DDEV-specific wp-config.php
create_ddev_wordpress_config() {
    local db_prefix="${1:-$DB_PREFIX}"
    
    log_info "Creating DDEV wp-config.php"
    
    if ddev wp config create \
        --dbname=db \
        --dbuser=db \
        --dbpass=db \
        --dbhost=db \
        --dbprefix="$db_prefix" \
        --skip-check \
        --force; then
        
        add_enhanced_wp_config
        chmod "${CONFIG_FILE_PERMISSIONS:-600}" wp-config.php
        log_success "DDEV wp-config.php created successfully"
        return 0
    else
        log_error "Failed to create DDEV wp-config.php"
        return 1
    fi
}

# Add enhanced WordPress configuration
add_enhanced_wp_config() {
    log_info "Adding enhanced WordPress configuration"
    
    cat >> wp-config.php << EOF

/**
 * Enhanced WordPress Configuration
 * Generated by Webwerk WordPress Management Suite v${SCRIPT_VERSION}
 * $(date '+%Y-%m-%d %H:%M:%S')
 */

/* Security Settings */
if (!defined('DISALLOW_FILE_EDIT')) {
    define('DISALLOW_FILE_EDIT', ${DISABLE_FILE_EDITING});
}

if (!defined('FORCE_SSL_ADMIN')) {
    define('FORCE_SSL_ADMIN', ${FORCE_SSL_ADMIN});
}

/* Performance Settings */
if (!defined('WP_MEMORY_LIMIT')) {
    define('WP_MEMORY_LIMIT', '${WP_MEMORY_LIMIT}');
}

if (!defined('WP_MAX_MEMORY_LIMIT')) {
    define('WP_MAX_MEMORY_LIMIT', '${WP_MAX_MEMORY_LIMIT}');
}

/* Debug Settings */
if (!defined('WP_DEBUG')) {
    define('WP_DEBUG', ${WP_DEBUG_DEFAULT});
}

if (!defined('WP_DEBUG_LOG')) {
    define('WP_DEBUG_LOG', ${WP_DEBUG_LOG_DEFAULT});
}

if (!defined('WP_DEBUG_DISPLAY')) {
    define('WP_DEBUG_DISPLAY', ${WP_DEBUG_DISPLAY_DEFAULT});
}

EOF

    # Add conditional settings
    if [[ "${DISABLE_XML_RPC}" == "true" ]]; then
        echo "add_filter('xmlrpc_enabled', '__return_false');" >> wp-config.php
    fi

    if [[ "${HIDE_WP_VERSION}" == "true" ]]; then
        echo "remove_action('wp_head', 'wp_generator');" >> wp-config.php
    fi

    echo "" >> wp-config.php
    log_debug "Enhanced configuration added to wp-config.php"
}

# Install WordPress
install_wordpress_core() {
    local site_url="${1:-$WP_URL}"
    local site_title="${2:-$WP_TITLE}"
    local admin_user="${3:-$WP_ADMIN_USER}"
    local admin_email="${4:-$WP_ADMIN_EMAIL}"
    
    # Generate password if not set
    generate_wp_password
    
    log_info "Installing WordPress"
    log_info "Site URL: $site_url"
    log_info "Site Title: $site_title"
    log_info "Admin User: $admin_user"
    log_info "Admin Email: $admin_email"
    
    if ${WP_CLI_PATH} core install \
        --url="$site_url" \
        --title="$site_title" \
        --admin_user="$admin_user" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$admin_email" \
        --skip-email; then
        
        # Set WordPress language if not English
        if [[ "$WP_LOCALE" != "en_US" ]]; then
            ${WP_CLI_PATH} language core install "$WP_LOCALE" --activate 2>/dev/null || \
                log_warning "Failed to set language to $WP_LOCALE"
        fi
        
        # Set timezone
        ${WP_CLI_PATH} option update timezone_string "$WP_TIMEZONE" 2>/dev/null || \
            log_warning "Failed to set timezone"
        
        log_success "WordPress installed successfully"
        log_info "Admin credentials - User: $admin_user, Password: $WP_ADMIN_PASSWORD"
        return 0
    else
        log_error "WordPress installation failed"
        return 1
    fi
}

#===============================================================================
# REPOSITORY FUNCTIONS
#===============================================================================

# Clone git repository
clone_git_repository() {
    local repo_url="${1:-$REPO_URL}"
    local target_dir="${2:-wp-content}"
    local force="${3:-true}"
    
    if [[ -z "$repo_url" ]]; then
        log_warning "No repository URL specified, skipping git clone"
        return 0
    fi
    
    log_info "Cloning repository: $repo_url"
    log_info "Target directory: $target_dir"
    
    # Remove existing directory if force is true
    if [[ -d "$target_dir" && "$force" == "true" ]]; then
        log_warning "Removing existing $target_dir directory"
        rm -rf "$target_dir"
    fi
    
    # Clone repository
    if git clone --depth 1 "$repo_url" "$target_dir"; then
        log_success "Repository cloned successfully"
        
        # Remove .git directory for deployment
        if [[ -d "$target_dir/.git" ]]; then
            rm -rf "$target_dir/.git"
        fi
        
        # Activate plugins if enabled
        if [[ "${AUTO_ACTIVATE_PLUGINS}" == "true" ]]; then
            activate_all_plugins
        fi
        
        return 0
    else
        log_error "Failed to clone repository: $repo_url"
        return 1
    fi
}

# Activate all available plugins
activate_all_plugins() {
    log_info "Activating all available plugins"
    
    if ${WP_CLI_PATH} plugin activate --all 2>/dev/null; then
        local active_count
        active_count=$(${WP_CLI_PATH} plugin list --status=active --format=count 2>/dev/null || echo "unknown")
        log_success "All plugins activated (total active: $active_count)"
        return 0
    else
        log_warning "Some plugins failed to activate"
        return 1
    fi
}

#===============================================================================
# LICENSE KEY FUNCTIONS
#===============================================================================

# Setup all license keys
setup_all_license_keys() {
    log_info "Setting up license keys from ~/.keys"
    
    local keys_setup=0
    
    # ACF Pro License
    if [[ -n "${ACF_PRO_LICENSE:-}" ]]; then
        if setup_acf_pro_license; then ((keys_setup++)); fi
    fi
    
    # WP Migrate DB Pro License
    if [[ -n "${WPMDB_LICENCE:-}" ]]; then
        if setup_wpmdb_license; then ((keys_setup++)); fi
    fi
    
    # Akeeba Download ID
    if [[ -n "${AKEEBA_DOWNLOAD_ID:-}" ]]; then
        if setup_akeeba_download_id; then ((keys_setup++)); fi
    fi
    
    if [[ $keys_setup -gt 0 ]]; then
        log_success "$keys_setup license keys configured"
    else
        log_info "No license keys were configured"
    fi
    
    return 0
}

# Setup ACF Pro license
setup_acf_pro_license() {
    log_info "Setting up ACF Pro license"
    
    if grep -q "ACF_PRO_LICENSE" wp-config.php 2>/dev/null; then
        log_info "ACF Pro license already exists in wp-config.php"
        return 0
    fi
    
    cat >> wp-config.php << EOF

/* ACF Pro License Key */
if (!defined('ACF_PRO_LICENSE')) {
    define('ACF_PRO_LICENSE', '${ACF_PRO_LICENSE}');
}
EOF
    
    log_success "ACF Pro license added to wp-config.php"
    return 0
}

# Setup WP Migrate DB Pro license
setup_wpmdb_license() {
    log_info "Setting up WP Migrate DB Pro license"
    
    if grep -q "WPMDB_LICENCE" wp-config.php 2>/dev/null; then
        log_info "WPMDB license already exists in wp-config.php"
        return 0
    fi
    
    cat >> wp-config.php << EOF

/* WP Migrate DB Pro License Key */
if (!defined('WPMDB_LICENCE')) {
    define('WPMDB_LICENCE', '${WPMDB_LICENCE}');
}
EOF
    
    log_success "WPMDB license added to wp-config.php"
    return 0
}

# Setup Akeeba Download ID in database
setup_akeeba_download_id() {
    log_info "Setting up Akeeba Download ID in database"
    
    # Add to database
    if ${WP_CLI_PATH} option update akeeba_download_id "$AKEEBA_DOWNLOAD_ID" 2>/dev/null; then
        log_success "Akeeba Download ID added to database"
        
        # Also add to wp-config.php as backup
        if ! grep -q "AKEEBA_DOWNLOAD_ID" wp-config.php 2>/dev/null; then
            cat >> wp-config.php << EOF

/* Akeeba Download ID */
if (!defined('AKEEBA_DOWNLOAD_ID')) {
    define('AKEEBA_DOWNLOAD_ID', '${AKEEBA_DOWNLOAD_ID}');
}
EOF
        fi
        
        return 0
    else
        log_error "Failed to set Akeeba Download ID in database"
        return 1
    fi
}

#===============================================================================
# CONFIGURATION FUNCTIONS
#===============================================================================

# Create .htaccess file
create_htaccess_file() {
    log_info "Creating .htaccess file"
    
    # Determine directory structure for RewriteBase
    local parent_dir current_dir target_directory
    parent_dir="$(basename "$(dirname "$PWD")")"
    current_dir="$(basename "$PWD")"
    target_directory="/$parent_dir/$current_dir"
    
    cat > .htaccess << EOF
# WordPress .htaccess - Generated by Webwerk v${SCRIPT_VERSION}
# $(date '+%Y-%m-%d %H:%M:%S')

<IfModule mod_rewrite.c>
RewriteEngine On

$(if [[ "${FORCE_SSL}" == "true" ]]; then
    echo "# Force HTTPS"
    echo "RewriteCond %{HTTPS} !=on"
    echo "RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]"
else
    echo "# Force HTTPS (disabled)"
    echo "# RewriteCond %{HTTPS} !=on"
    echo "# RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]"
fi)

# WordPress specific rules
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase $target_directory
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . $target_directory/index.php [L]
</IfModule>

# Security Headers
<IfModule mod_headers.c>
    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options SAMEORIGIN
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
</IfModule>

# Disable XML-RPC
<Files xmlrpc.php>
    Order Allow,Deny
    Deny from all
</Files>

# Protect wp-config.php
<Files wp-config.php>
    Order Allow,Deny
    Deny from all
</Files>

# Disable directory browsing
Options -Indexes

# PHP Configuration
<IfModule mod_php.c>
    php_value upload_max_filesize ${PHP_UPLOAD_MAX_FILESIZE}
    php_value post_max_size ${PHP_POST_MAX_SIZE}
    php_value max_execution_time ${PHP_MAX_EXECUTION_TIME}
    php_value max_input_vars ${PHP_MAX_INPUT_VARS}
    php_value memory_limit ${WP_MEMORY_LIMIT}
</IfModule>
EOF
    
    chmod "${HTACCESS_FILE_PERMISSIONS:-644}" .htaccess
    log_success ".htaccess created with RewriteBase: $target_directory"
    return 0
}

# Disable search engine indexing
disable_search_engine_indexing() {
    if [[ "${DISABLE_SEARCH_INDEXING}" == "true" ]]; then
        log_info "Disabling search engine indexing for development"
        
        if ${WP_CLI_PATH} option update blog_public 0 2>/dev/null; then
            log_success "Search engine indexing disabled"
            return 0
        else
            log_error "Failed to disable search engine indexing"
            return 1
        fi
    else
        log_info "Search engine indexing enabled (production mode)"
        return 0
    fi
}

# Set file permissions
set_file_permissions() {
    log_info "Setting file permissions"
    
    # Set ownership if configured
    if [[ -n "${WEBSERVER_USER:-}" ]] && command -v chown &> /dev/null; then
        if chown -R "$WEBSERVER_USER:$WEBSERVER_GROUP" . 2>/dev/null; then
            log_success "Ownership set to $WEBSERVER_USER:$WEBSERVER_GROUP"
        else
            log_warning "Could not set ownership (insufficient permissions)"
        fi
    fi
    
    # Set directory permissions
    find . -type d -exec chmod "${DIR_PERMISSIONS:-755}" {} \; 2>/dev/null || \
        log_warning "Could not set directory permissions"
    
    # Set file permissions
    find . -type f -exec chmod "${FILE_PERMISSIONS:-644}" {} \; 2>/dev/null || \
        log_warning "Could not set file permissions"
    
    # Set special permissions for uploads
    if [[ -d "wp-content/uploads" ]]; then
        chmod -R "${UPLOAD_PERMISSIONS:-755}" wp-content/uploads/ 2>/dev/null || \
            log_warning "Could not set uploads permissions"
    fi
    
    log_success "File permissions configured"
    return 0
}

#===============================================================================
# DDEV FUNCTIONS
#===============================================================================

# Initialize DDEV project
initialize_ddev_project() {
    local project_name="${1:-$(basename "$PWD")}"
    
    log_info "Initializing DDEV project: $project_name"
    
    if ! command -v ddev &> /dev/null; then
        log_error "DDEV is not installed"
        return 1
    fi
    
    if ddev config \
        --project-type="${DDEV_PROJECT_TYPE}" \
        --docroot="${DDEV_DOCROOT}" \
        --project-name="$project_name" \
        --php-version="${DDEV_PHP_VERSION}"; then
        
        log_success "DDEV project configured"
        return 0
    else
        log_error "Failed to configure DDEV project"
        return 1
    fi
}

# Start DDEV containers
start_ddev_containers() {
    log_info "Starting DDEV containers"
    
    if ddev start; then
        log_success "DDEV containers started successfully"
        
        local project_name site_url
        project_name=$(basename "$PWD")
        site_url="https://${project_name}.ddev.site"
        log_info "Site URL: $site_url"
        
        return 0
    else
        log_error "Failed to start DDEV containers"
        return 1
    fi
}

#===============================================================================
# HIGH-LEVEL INSTALLATION FUNCTIONS
#===============================================================================

# Complete WordPress installation
install_full_wordpress() {
    log_info "Starting full WordPress installation"
    
    download_wordpress_core || return 1
    create_wordpress_config || return 1
    reset_wordpress_database || return 1
    install_wordpress_core || return 1
    create_htaccess_file || return 1
    disable_search_engine_indexing || return 1
    clone_git_repository || return 1
    setup_all_license_keys || return 1
    set_file_permissions || return 1
    
    log_success "Full WordPress installation completed successfully"
    return 0
}

# Minimal WordPress installation
install_minimal_wordpress() {
    log_info "Starting minimal WordPress installation"
    
    download_wordpress_core || return 1
    create_wordpress_config || return 1
    reset_wordpress_database || return 1
    install_wordpress_core || return 1
    create_htaccess_file || return 1
    disable_search_engine_indexing || return 1
    set_file_permissions || return 1
    
    log_success "Minimal WordPress installation completed successfully"
    return 0
}

# DDEV WordPress installation
# DEPRECATED: This function is replaced by install_ddev_wordpress() in wplocalinstall.sh
_deprecated_install_ddev_wordpress() {
    log_info "Starting DDEV WordPress installation"
    
    # Override database settings for DDEV
    export DB_USER="db"
    export DB_PASSWORD="db"
    export DB_NAME="db"
    export DB_HOST="db"
    export WP_CLI_PATH="ddev wp"
    
    # Set site URL for DDEV
    local project_name
    project_name="$(basename "$PWD")"
    export WP_URL="https://${project_name}.ddev.site"
    
    initialize_ddev_project || return 1
    start_ddev_containers || return 1
    download_wordpress_core || return 1
    create_ddev_wordpress_config || return 1
    install_wordpress_core || return 1
    disable_search_engine_indexing || return 1
    create_htaccess_file || return 1
    clone_git_repository || return 1
    setup_all_license_keys || return 1
    set_file_permissions || return 1
    
    log_success "DDEV WordPress installation completed successfully"
    return 0
}

#===============================================================================
# VALIDATION FUNCTIONS
#===============================================================================

# Validate WordPress installation
validate_wordpress_installation() {
    log_info "Validating WordPress installation"
    
    local validation_errors=0
    
    # Check essential files
    local required_files=("wp-config.php" "index.php" "wp-load.php")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required file missing: $file"
            ((validation_errors++))
        fi
    done
    
    # Check essential directories
    local required_dirs=("wp-content" "wp-includes" "wp-admin")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Required directory missing: $dir"
            ((validation_errors++))
        fi
    done
    
    # Test database connection
    if ! test_database_connection; then
        log_error "Database connection validation failed"
        ((validation_errors++))
    fi
    
    if [[ $validation_errors -eq 0 ]]; then
        log_success "WordPress installation validation passed"
        return 0
    else
        log_error "WordPress installation validation failed with $validation_errors errors"
        return 1
    fi
}

#===============================================================================
# FUNCTION EXPORTS
#===============================================================================

# Export all functions for use by other scripts
export -f log_info log_error log_warning log_success log_debug
export -f generate_wp_password load_mysql_fallback
export -f test_database_connection reset_wordpress_database
export -f download_wordpress_core create_wordpress_config create_ddev_wordpress_config 
export -f add_enhanced_wp_config install_wordpress_core
export -f clone_git_repository activate_all_plugins
export -f setup_all_license_keys setup_acf_pro_license setup_wpmdb_license setup_akeeba_download_id
export -f create_htaccess_file disable_search_engine_indexing set_file_permissions
export -f initialize_ddev_project start_ddev_containers
export -f install_full_wordpress install_minimal_wordpress install_ddev_wordpress
export -f validate_wordpress_installation

log_info "$SCRIPT_NAME v$SCRIPT_VERSION loaded successfully"
log_debug "MySQL fallback functions will be loaded only when WP-CLI database operations fail"
