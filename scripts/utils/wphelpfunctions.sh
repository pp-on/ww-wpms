#!/bin/bash
#
# WordPress Helper Functions v2.0
# Part of Webwerk WordPress Management Suite
# Focused on Barrierefreiheit (Accessibility)
#
# Description: Shared utility functions for WordPress management
# Author: Webwerk Team
# License: MIT
#
# Make functions available to be used in other scripts
# for maintaining more than one WordPress sites on a web server or locally
#

set -euo pipefail

#===============================================================================
# SCRIPT METADATA
#===============================================================================

readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_NAME="WordPress Helper Functions"

#===============================================================================
# COLOR FUNCTIONS
#===============================================================================

colors() {
    # Reset
    Color_Off="\e[0m"       # Text Reset

    # Regular Colors
    Black="\e[30m"          # Black
    Red="\e[31m"            # Red
    Green="\e[32m"          # Green
    Yellow="\e[33m"         # Yellow
    Blue="\e[34m"           # Blue
    Purple="\e[35m"         # Purple
    Cyan="\e[36m"           # Cyan
    White="\e[37m"          # White
}

# Initialize colors
colors

#===============================================================================
# LOGGING AND OUTPUT FUNCTIONS
#===============================================================================

# Enhanced output function with customizable formatting
out() {
    local text="$1"
    local color_key="${2,,}"  # Convert to lowercase
    local line_char="${3:--}" # Default to '-'
    local color="$Cyan"       # Default color
    local total_width="${OUTPUT_LINE_WIDTH:-60}"

    # Choose color based on keyword
    case "$color_key" in
        1 | warning) color="$Yellow" ;;
        3 | error)   color="$Red" ;;
        4 | good)    color="$Green" ;;
        *)           color="$Cyan" ;;
    esac

    # Format label with padding
    local label=" ${text} "
    local label_length=${#label}
    local side_length=$(( (total_width - label_length) / 2 ))

    # Build full line
    local line=""
    for ((i = 0; i < total_width; i++)); do
        line+="$line_char"
    done

    # Build centered label line
    local centered_line=""
    for ((i = 0; i < side_length; i++)); do
        centered_line+="$line_char"
    done
    centered_line+="$label"
    while [[ ${#centered_line} -lt $total_width ]]; do
        centered_line+="$line_char"
    done

    # Output
    echo -e "${color}${line}"
    echo -e "${centered_line}"
    echo -e "${line}${Color_Off}"
}

# Colored text output
txt() {
    local line="$1"
    local color_code="$2"
    
    case $color_code in
        y) line="${Yellow}${line}" ;;
        r) line="${Red}${line}" ;;
        c) line="${Cyan}${line}" ;;
        b) line="${Blue}${line}" ;;
        g) line="${Green}${line}" ;;
    esac

    echo -e "${line}${Color_Off}"
}

#===============================================================================
# SITE DISCOVERY AND MANAGEMENT
#===============================================================================

# Search for WordPress installations in directory
searchwp() {
    local search_dir="${1:-${WORDPRESS_SEARCH_DIR:-.}}"
    local site
    
    for site in $(ls -d "$search_dir"*/); do
        if [[ -d "$site/wp-content/" ]]; then
            site=${site##"$search_dir"}
            [[ "$verbose" = "1" ]] && sleep 1 && echo "Found $site"
            sites+=("$site")
            (( anzahl++ ))
        fi
    done
}

# Process comma-separated directories
process_dirs() {
    local dirs="$1"
    local site
    local remaining_dirs="$dirs"
    
    if [[ -n "$dirs" ]]; then
        while [[ "$remaining_dirs" != "$site" ]]; do
            site=${remaining_dirs%%,*}
            remaining_dirs=${remaining_dirs#"$site",}
            
            # Validate directory exists
            while [[ ! -d "${WORDPRESS_BASE_DIR}$site" ]]; do
                echo "${WORDPRESS_BASE_DIR}$site not found! Type [n]ew name or [c]ontinue..."
                read -r answer
                case "$answer" in
                    n)
                        echo "----------------"
                        echo "Enter new name: "
                        read -r site
                        echo "----------------"
                        ;;
                    c)
                        site=""
                        break
                        ;;
                    *)
                        continue
                        ;;
                esac
            done
            
            [[ -n "$site" ]] && sites+=("$site")
        done
    fi
}

# Process sites interactively
process_sites() {
    local search_dir="${1:-${WORDPRESS_BASE_DIR}}"
    local site
    
    if [[ -z "${sites:-}" ]]; then
        for site in $(ls -d "$search_dir"*/); do
            if [[ -d "$site/wp-content/" ]]; then
                local site_name=${site##"$search_dir"}
                echo "Found $site_name"
                echo "Should it be processed? [y/N] "
                read -r answer
                echo -e "\n--------------"
                
                if [[ "$answer" = "y" || "$answer" = "Y" ]]; then
                    site_name=${site_name%%/}
                    sites+=("$site_name")
                fi
            fi
        done
    fi
}

# Print selected sites
print_sites() {
    echo -e "${Yellow}----------------"
    sleep 1
    echo -e "${#sites[@]} selected websites" 
    echo "----------------"
    for site in "${sites[@]}"; do
        echo -e "${Cyan}$site"
    done
    echo -e "${Yellow}----------------${Color_Off}"
}

#===============================================================================
# SYSTEM DETECTION
#===============================================================================

# Operating system detection
os_detection() {
    local show_output="${1:-0}"
    local uname_output
    local detected_os
    
    uname_output="$(uname -a)"
    
    case $(echo "${uname_output}" | tr '[:upper:]' '[:lower:]') in
        linux)
            detected_os="$(cat /etc/os-release | grep '_NAME' | cut -d '=' -f2)"
            ;;
        *wsl*|*buntu*)
            detected_os="$(cat /etc/os-release | sed -n '1p' | cut -d '"' -f2)"
            ;;
        msys*|cygwin*|mingw*)
            detected_os="Git_Bash"
            ;;
        *)
            detected_os="Unknown"
            ;;
    esac
    
    [[ "$show_output" -eq 1 ]] && out "$detected_os" 1
    echo "$detected_os"
}

#===============================================================================
# WORDPRESS PLUGIN FUNCTIONS
#===============================================================================

# List plugins for all sites
list_wp_plugins() {
    local site
    local continue_key
    
    for site in "${sites[@]}"; do
        echo -e "${Green}----------------"
        cd "${WORDPRESS_BASE_DIR}$site" &>/dev/null
        echo -e "$site"
        echo -e "----------------${Color_Off}"
        
        "${WP_CLI_PATH}" plugin list --color
        echo -e "${Yellow} $("${WP_CLI_PATH}" plugin list --format=count) Plugins"
        echo -e "${Purple}To continue press any key and enter...${Color_Off}"
        read -r continue_key
        cd - &>/dev/null
    done
}

# Copy plugins between sites
copy_plugins() {
    local from="$1"
    local plugin_name target site
    
    plugin_name=$(basename "$from")
    
    for site in "${sites[@]}"; do
        out "${site}" 1
        target="${WORDPRESS_BASE_DIR}${site}/wp-content/plugins/"
        
        if [[ -d "${target}${plugin_name}" ]]; then
            out "${plugin_name} already exists" 3
        else
            out "copying ${plugin_name} from ${from}" 2
            cp "$from" "${target}" -r
            sleep 1
            echo "Done"
            
            out "Activating $plugin_name" 2
            cd "${WORDPRESS_BASE_DIR}${site}"
            "${WP_CLI_PATH}" plugin activate "$plugin_name"
            cd - &>/dev/null
        fi
    done
}

# Remove plugins from sites
remove_plugins() {
    local plugin_name="$1"
    local pause="${2:-0}"
    local site continue_key
    
    for site in "${sites[@]}"; do
        out "$site" 1
        cd "${WORDPRESS_BASE_DIR}${site}/wp-content/plugins"
        
        if [[ -d "$plugin_name" ]]; then
            out "Removing $plugin_name" 2
            "${WP_CLI_PATH}" plugin delete "$plugin_name"
            sleep 1
            echo "Done"
        fi
        
        if [[ "$pause" -eq 1 ]]; then
            echo -e "${Purple}To continue press any key and enter...${Color_Off}"
            read -r continue_key
        fi
        cd - &>/dev/null
    done
}

# Install plugins on sites
install_plugins() {
    local plugin_name="$1"
    local site
    
    for site in "${sites[@]}"; do
        out "${site}" 1
        cd "${WORDPRESS_BASE_DIR}${site}"
        
        local target="wp-content/plugins/"
        if [[ -d "${target}${plugin_name}" ]]; then
            out "${plugin_name} already exists" 3
        else
            "${WP_CLI_PATH}" plugin install "$plugin_name"
            "${WP_CLI_PATH}" plugin activate "$plugin_name"
        fi
        cd - &>/dev/null
    done
}

# Update plugins
wp_update() {
    local plugin="$1"
    local countdown=4
    local site
    
    for site in "${sites[@]}"; do
        out "$site" 1
        out "check $plugin if there is one, update it"
        cd "${WORDPRESS_BASE_DIR}$site"
        
        if [[ "$plugin" != "all" ]]; then
            out "found $plugin! Updating..." 2
            "${WP_CLI_PATH}" plugin update "$plugin"
        else
            out "updating all plugins" 2
            "${WP_CLI_PATH}" plugin list --update=available
            
            while [[ "$countdown" -ge 0 ]]; do
                out "$countdown" 4
                sleep 1
                (( countdown-- ))
            done
            
            "${WP_CLI_PATH}" plugin update --all
        fi
        cd - &>/dev/null
    done
}

#===============================================================================
# LICENSE KEY MANAGEMENT
#===============================================================================

# Setup license keys for plugins
wp_license_plugins() {
    local plugin="$1"
    local license
    
    case "$plugin" in
        "ACF_PRO")
            if [[ -n "${ACF_PRO_LICENSE:-}" ]]; then
                read -r -d '' license <<- EOM
if (!defined('${plugin}_LICENSE')){
    define( 'ACF_PRO_LICENSE', '${ACF_PRO_LICENSE}' );
}
EOM
            else
                out "ACF_PRO_LICENSE not found in environment" 3
                return 1
            fi
            ;;
        "WPMDB")
            if [[ -n "${WPMDB_LICENCE:-}" ]]; then
                read -r -d '' license <<- EOM
if (!defined('${plugin}_LICENSE')){
    define( 'WPMDB_LICENCE', '${WPMDB_LICENCE}');
}
EOM
            else
                out "WPMDB_LICENCE not found in environment" 3
                return 1
            fi
            ;;
        *)
            out "Unknown plugin license: $plugin" 3
            return 1
            ;;
    esac
    
    out "activating ${plugin}_LICENSE" 2
    sleep 1
    
    # Add license only if not found
    if grep -q "$plugin" wp-config.php; then
        echo "${plugin}_LICENSE already exists"
    else
        echo "$license" >> ./wp-config.php
        sleep 1
        out "done" 4
    fi
}

# Legacy ACF Pro setup (for compatibility)
wp_key_acf_pro() {
    wp_license_plugins "ACF_PRO"
}

# Legacy WP Migrate DB setup (for compatibility)
wp_key_migrate() {
    wp_license_plugins "WPMDB"
    out "activating pull setting" 4
    "${WP_CLI_PATH}" migrate setting update pull on
}

# Setup Akeeba Download ID
wp_key_akeeba() {
    if [[ -z "${AKEEBA_DOWNLOAD_ID:-}" ]]; then
        out "AKEEBA_DOWNLOAD_ID not found in environment" 3
        return 1
    fi
    
    out "Setting up Akeeba Download ID" 2
    
    # Add to database via WP-CLI
    if "${WP_CLI_PATH}" option update akeeba_download_id "$AKEEBA_DOWNLOAD_ID" 2>/dev/null; then
        out "Akeeba Download ID added to database" 4
        
        # Also add to wp-config.php as backup
        if ! grep -q "AKEEBA_DOWNLOAD_ID" wp-config.php 2>/dev/null; then
            local akeeba_config
            read -r -d '' akeeba_config <<- EOM
if (!defined('AKEEBA_DOWNLOAD_ID')) {
    define('AKEEBA_DOWNLOAD_ID', '${AKEEBA_DOWNLOAD_ID}');
}
EOM
            echo "$akeeba_config" >> ./wp-config.php
            out "Akeeba Download ID also added to wp-config.php" 2
        fi
        
        sleep 1
        out "Akeeba setup completed" 4
        return 0
    else
        out "Failed to set Akeeba Download ID in database" 3
        return 1
    fi
}

# Setup all license keys at once
wp_setup_all_licenses() {
    local setup_count=0
    
    out "Setting up all available license keys" 1
    
    # Try ACF Pro
    if [[ -n "${ACF_PRO_LICENSE:-}" ]]; then
        if wp_key_acf_pro; then
            ((setup_count++))
        fi
    fi
    
    # Try WP Migrate DB
    if [[ -n "${WPMDB_LICENCE:-}" ]]; then
        if wp_key_migrate; then
            ((setup_count++))
        fi
    fi
    
    # Try Akeeba
    if [[ -n "${AKEEBA_DOWNLOAD_ID:-}" ]]; then
        if wp_key_akeeba; then
            ((setup_count++))
        fi
    fi
    
    if [[ $setup_count -gt 0 ]]; then
        out "$setup_count license keys configured successfully" 4
    else
        out "No license keys were configured" 3
    fi
}

#===============================================================================
# USER MANAGEMENT
#===============================================================================

# Create new WordPress user
wp_new_user() {
    local username="$1"
    local password="$2"
    local email="$3"
    local site
    
    out "creating user ${username}"
    sleep 1
    
    for site in "${sites[@]}"; do
        out "$site" 1
        cd "${WORDPRESS_BASE_DIR}$site"
        "${WP_CLI_PATH}" user create "$username" "$email" --user_pass="$password" --role=administrator
        cd - &>/dev/null
    done
}

#===============================================================================
# FILE PERMISSIONS AND RIGHTS
#===============================================================================

# Set proper WordPress file permissions
wp_rights() {
    local site
    local webserver_user="${WEBSERVER_USER:-www-data}"
    local webserver_group="${WEBSERVER_GROUP:-www-data}"
    
    for site in "${sites[@]}"; do
        out "changing ownership ${site}"
        chown "$webserver_user:$webserver_group" "${WORDPRESS_BASE_DIR}${site}/wp-content" -Rvf
        chmod -Rv "${UPLOAD_PERMISSIONS:-755}" "${WORDPRESS_BASE_DIR}${site}/wp-content/uploads"
    done 
}

#===============================================================================
# HTACCESS MANAGEMENT
#===============================================================================

# Create basic .htaccess for SEO
htaccess() {
    local parent_dir current_dir target_directory
    
    parent_dir=$(dirname "$PWD")
    parent_dir=${parent_dir##*/}
    current_dir=${PWD##*/}
    target_directory="/$parent_dir/$current_dir"

    out "creating .htaccess with $target_directory" 2
    
    cat << EOF > .htaccess
<IfModule mod_rewrite.c>
RewriteEngine On

# Force HTTPS
$(if [[ "${FORCE_SSL}" == "true" ]]; then
    echo "RewriteCond %{HTTPS} !=on"
    echo "RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]"
else
    echo "# RewriteCond %{HTTPS} !=on"
    echo "# RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]"
fi)

RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase $target_directory
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . $target_directory/index.php [L]
</IfModule>	
EOF
    
    sleep 1
    chmod "${HTACCESS_FILE_PERMISSIONS:-644}" .htaccess
    echo "Done"
}

#===============================================================================
# DEBUG MANAGEMENT
#===============================================================================

# Hide WordPress errors
wp_hide_errors() {
    out "hiding errors" 4
    # Remove DEBUG lines
    sed -i '/DEBUG/d' wp-config.php
    
    cat <<EOF >> wp-config.php
ini_set('display_errors','Off');
ini_set('error_reporting', E_ALL );
define('WP_DEBUG', false);
define('WP_DEBUG_DISPLAY', false);
EOF
}

# Toggle WordPress debug mode
wp_debug() {
    local switch="${1:-on}"
    
    if [[ "$switch" = "off" ]]; then
        "${WP_CLI_PATH}" config set --raw WP_DEBUG false
        "${WP_CLI_PATH}" config set --raw WP_DEBUG_LOG false
        "${WP_CLI_PATH}" config set --raw WP_DEBUG_DISPLAY false
        out "Debugging is off" 4
    else
        "${WP_CLI_PATH}" config set --raw WP_DEBUG true
        "${WP_CLI_PATH}" config set --raw WP_DEBUG_LOG true
        "${WP_CLI_PATH}" config set --raw WP_DEBUG_DISPLAY false
        out "Debugging is on" 4
    fi
}

#===============================================================================
# GIT FUNCTIONS
#===============================================================================

# Update repositories
update_repo() {
    local site
    
    for site in "${sites[@]}"; do
        out "${site}" 1
        cd "${WORDPRESS_BASE_DIR}${site}/wp-content" &>/dev/null
        out "updating repository..." 1
        sleep 1
        git pull 1>/dev/null
        cd - &>/dev/null
    done
}

# Git operations for WordPress sites
git_wp() {
    local subcommand="$1"
    local site
    
    for site in "${sites[@]}"; do
        out "${site}" 1
        cd "${WORDPRESS_BASE_DIR}${site}/wp-content" &>/dev/null
        
        case "$subcommand" in
            pull)
                git pull
                ;;
            log)
                git log --graph --max-count=10
                ;;
            *)
                echo "Unknown git command: $subcommand"
                ;;
        esac
        cd - &>/dev/null
    done 
}

#===============================================================================
# SEO AND SEARCH ENGINE MANAGEMENT
#===============================================================================

# Block search engine indexing
wp_block_se() {
    out "Disabling search engine indexing for $(basename "$PWD")"
    "${WP_CLI_PATH}" option update blog_public 0
}

#===============================================================================
# CUSTOM POST TYPE EXPORT
#===============================================================================

# Export Custom Post Types
wp_getCPT() {
    local cpts=""
    local cpts_sql
    
    # Parse arguments
    while getopts "c:" opt; do
        case $opt in
            c) cpts="$OPTARG" ;;
            *) echo "Invalid option" >&2; exit 1 ;;
        esac
    done

    # Check if CPTs were specified
    if [[ -z "$cpts" ]]; then
        echo "Missing CPTs! Usage: $0 -c cpt1,cpt2,..."
        exit 1
    fi

    # Generate SQL WHERE condition for CPTs
    cpts_sql=$(echo "$cpts" | sed "s/,/','/g")
    cpts_sql="('$cpts_sql')"

    # Export CPTs
    "${WP_CLI_PATH}" db query "SELECT * FROM wp_posts WHERE post_type IN $cpts_sql" --allow-root > cpts.sql

    # Export Postmeta (custom fields)
    "${WP_CLI_PATH}" db query "SELECT * FROM wp_postmeta WHERE post_id IN (SELECT ID FROM wp_posts WHERE post_type IN $cpts_sql)" --allow-root >> cpts.sql

    # Export Taxonomies (relationships between CPTs and taxonomies)
    "${WP_CLI_PATH}" db query "SELECT * FROM wp_term_relationships WHERE object_id IN (SELECT ID FROM wp_posts WHERE post_type IN $cpts_sql)" --allow-root >> cpts.sql

    # Export Taxonomy information
    "${WP_CLI_PATH}" db query "SELECT * FROM wp_term_taxonomy WHERE term_taxonomy_id IN (SELECT term_taxonomy_id FROM wp_term_relationships WHERE object_id IN (SELECT ID FROM wp_posts WHERE post_type IN $cpts_sql))" --allow-root >> cpts.sql

    # Export Terms
    "${WP_CLI_PATH}" db query "SELECT * FROM wp_terms WHERE term_id IN (SELECT term_id FROM wp_term_taxonomy WHERE term_taxonomy_id IN (SELECT term_taxonomy_id FROM wp_term_relationships WHERE object_id IN (SELECT ID FROM wp_posts WHERE post_type IN $cpts_sql))))" --allow-root >> cpts.sql

    echo "Export completed: cpts.sql"
}

#===============================================================================
# LEGACY COMPATIBILITY
#===============================================================================

# Legacy function for environment variable assignment
assign_env() {
    declare -n var="$1"
    local value="$2"
    
    out "$var" 1
    out "${!var}" 2
    var="$value"
    out "$var" 1
}

#===============================================================================
# FUNCTION EXPORTS
#===============================================================================

# Export all functions for use by other scripts
export -f colors out txt
export -f searchwp process_dirs process_sites print_sites
export -f os_detection
export -f list_wp_plugins copy_plugins remove_plugins install_plugins wp_update
export -f wp_license_plugins wp_key_acf_pro wp_key_migrate wp_key_akeeba wp_setup_all_licenses
export -f wp_new_user wp_rights
export -f htaccess wp_hide_errors wp_debug
export -f update_repo git_wp wp_block_se
export -f wp_getCPT assign_env

# Initialize colors and show loading message
colors
out "$SCRIPT_NAME v$SCRIPT_VERSION loaded successfully" 4

# Conditional output based on flags
[[ "${print:-0}" = "1" ]] && print_sites
[[ "${total:-0}" = "1" ]] && echo -e "\n=======\nTotal ${anzahl:-0} WP-Sites"
