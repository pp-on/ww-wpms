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

    # Build lines with printf instead of character-by-character loops
    local line
    line=$(printf "%${total_width}s" | tr ' ' "$line_char")

    local prefix
    prefix=$(printf "%${side_length}s" | tr ' ' "$line_char")
    local centered_line="${prefix}${label}"
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

    for site in "$search_dir"*/; do
        if [[ -d "$site/wp-content/" ]]; then
            site=${site##"$search_dir"}
            [[ "$verbose" = "1" ]] && echo "Found $site"
            sites+=("$site")
            (( anzahl++ ))
        fi
    done
}

# Process comma-separated directories
process_dirs() {
    local dirs="$1"
    [[ -z "$dirs" ]] && return

    local site answer
    local -a site_list
    IFS=',' read -ra site_list <<< "$dirs"

    for site in "${site_list[@]}"; do
        site="${site%%/}"
        [[ -z "$site" ]] && continue

        while [[ ! -d "${WORDPRESS_BASE_DIR}/${site}" ]]; do
            echo "${WORDPRESS_BASE_DIR}/${site} not found — [n]ew name or [c]ontinue: "
            read -r answer
            case "$answer" in
                n) read -rp "New name: " site ;;
                c) site=""; break ;;
            esac
        done

        [[ -n "$site" ]] && sites+=("$site")
    done
}

# Process sites interactively
process_sites() {
    local search_dir="${1:-${WORDPRESS_BASE_DIR}}"
    local site

    if [[ -z "${sites:-}" ]]; then
        for site in "$search_dir"*/; do
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

# Process all sites non-interactively (no y/N prompts)
process_sites_all() {
    local search_dir="${1:-${WORDPRESS_BASE_DIR}}"
    search_dir="${search_dir%/}"
    sites=()
    local site site_name
    for site in "$search_dir"/*/; do
        if [[ -d "$site/wp-content/" ]]; then
            site_name="${site##"$search_dir/"}"
            site_name="${site_name%%/}"
            sites+=("$site_name")
        fi
    done
}

# Print selected sites
print_sites() {
    echo -e "${Yellow}----------------"
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
    local lower="${uname_output,,}"

    case "$lower" in
        *wsl*|*microsoft*)
            detected_os="$(grep '^PRETTY_NAME' /etc/os-release | cut -d '=' -f2 | tr -d '"') (WSL)"
            ;;
        *buntu*|linux*)
            detected_os="$(grep '^PRETTY_NAME' /etc/os-release | cut -d '=' -f2 | tr -d '"')"
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
        (
            cd "${WORDPRESS_BASE_DIR}/$site" || exit 1
            echo -e "${Green}----------------"
            echo -e "$site"
            echo -e "----------------${Color_Off}"

            local plugin_count
            plugin_count=$("${WP_CLI_PATH}" plugin list --format=count)
            "${WP_CLI_PATH}" plugin list --color
            echo -e "${Yellow} ${plugin_count} Plugins"
            echo -e "${Purple}To continue press any key and enter...${Color_Off}"
            read -r continue_key
        )
    done
}

list_wp_themes() {
    local theme_arg="${1:-}"
    local site

    for site in "${sites[@]}"; do
        local site_path
        if [[ "$site" = /* ]]; then
            site_path="$site"
        else
            site_path="${WORDPRESS_BASE_DIR}/${site}"
        fi

        (
            cd "$site_path" || exit 0

            echo -e "${Green}----------------"
            echo -e "$site"
            echo -e "----------------${Color_Off}"

            local themes
            mapfile -t themes < <("${WP_CLI_PATH}" theme list --field=name 2>/dev/null)
            "${WP_CLI_PATH}" theme list --fields=name,status,title --color

            if [[ ${#themes[@]} -eq 0 ]]; then
                echo "No themes found."
                exit 0
            fi

            echo ""
            local i
            for ((i=0; i<${#themes[@]}; i++)); do
                echo "  $((i+1))) ${themes[$i]}"
            done

            local target=""
            if [[ -n "$theme_arg" ]]; then
                if [[ "$theme_arg" =~ ^[0-9]+$ ]]; then
                    local idx=$(( theme_arg - 1 ))
                    if [[ $idx -ge 0 && $idx -lt ${#themes[@]} ]]; then
                        target="${themes[$idx]}"
                    else
                        echo -e "${Red}Invalid theme number: $theme_arg${Color_Off}"
                        exit 0
                    fi
                else
                    target="$theme_arg"
                fi
            else
                echo -e "${Purple}Activate which theme? (number/name, or Enter to skip): ${Color_Off}"
                local choice
                read -r choice
                if [[ -z "$choice" ]]; then
                    echo "Skipped."
                    exit 0
                fi
                if [[ "$choice" =~ ^[0-9]+$ ]]; then
                    local idx=$(( choice - 1 ))
                    if [[ $idx -ge 0 && $idx -lt ${#themes[@]} ]]; then
                        target="${themes[$idx]}"
                    else
                        echo -e "${Red}Invalid number${Color_Off}"
                        exit 0
                    fi
                else
                    target="$choice"
                fi
            fi

            echo -e "${Yellow}Activating: $target${Color_Off}"
            "${WP_CLI_PATH}" theme activate "$target"
        )
    done
}

# Activate the 'webwerk' theme on each selected site:
#   - already active   -> skip
#   - installed        -> activate it
#   - not installed    -> list themes and let the user pick one to activate
wp_activate_webwerk_theme() {
    local site
    for site in "${sites[@]}"; do
        local site_path
        if [[ "$site" = /* ]]; then
            site_path="$site"
        else
            site_path="${WORDPRESS_BASE_DIR}/${site}"
        fi

        (
            cd "$site_path" || exit 0

            echo -e "${Green}----------------"
            echo -e "$site"
            echo -e "----------------${Color_Off}"

            local active
            active=$("${WP_CLI_PATH}" theme list --status=active --field=name 2>/dev/null | head -n1)
            if [[ "$active" == "webwerk" ]]; then
                echo "webwerk theme already active — skipping."
                exit 0
            fi

            if "${WP_CLI_PATH}" theme is-installed webwerk 2>/dev/null; then
                echo -e "${Yellow}Activating: webwerk${Color_Off}"
                "${WP_CLI_PATH}" theme activate webwerk
                exit 0
            fi

            echo -e "${Yellow}webwerk theme not installed — pick one to activate.${Color_Off}"
            local themes
            mapfile -t themes < <("${WP_CLI_PATH}" theme list --field=name 2>/dev/null)
            if [[ ${#themes[@]} -eq 0 ]]; then
                echo "No themes found."
                exit 0
            fi
            "${WP_CLI_PATH}" theme list --fields=name,status,title --color
            echo ""
            local i
            for ((i=0; i<${#themes[@]}; i++)); do
                echo "  $((i+1))) ${themes[$i]}"
            done

            echo -e "${Purple}Activate which theme? (number/name, or Enter to skip): ${Color_Off}"
            local choice target
            read -r choice
            if [[ -z "$choice" ]]; then
                echo "Skipped."
                exit 0
            fi
            if [[ "$choice" =~ ^[0-9]+$ ]]; then
                local idx=$(( choice - 1 ))
                if [[ $idx -ge 0 && $idx -lt ${#themes[@]} ]]; then
                    target="${themes[$idx]}"
                else
                    echo -e "${Red}Invalid number${Color_Off}"
                    exit 0
                fi
            else
                target="$choice"
            fi
            echo -e "${Yellow}Activating: $target${Color_Off}"
            "${WP_CLI_PATH}" theme activate "$target"
        )
    done
}

# Run `wp plugin <action> <name>` on each selected site (activate|deactivate|delete).
wp_plugin_action() {
    local action="$1" name="$2"
    local site
    for site in "${sites[@]}"; do
        local site_path
        if [[ "$site" = /* ]]; then
            site_path="$site"
        else
            site_path="${WORDPRESS_BASE_DIR}/${site}"
        fi
        (
            cd "$site_path" || exit 0
            echo -e "${Green}----------------"
            echo -e "$site"
            echo -e "----------------${Color_Off}"
            echo -e "${Yellow}plugin $action: $name${Color_Off}"
            "${WP_CLI_PATH}" plugin "$action" "$name"
        )
    done
}

# Copy plugins between sites
copy_plugins() {
    local from="$1"
    local plugin_name target site

    plugin_name=$(basename "$from")

    for site in "${sites[@]}"; do
        out "${site}" 1
        target="${WORDPRESS_BASE_DIR}/${site}/wp-content/plugins/"

        if [[ -d "${target}${plugin_name}" ]]; then
            out "${plugin_name} already exists" 3
        else
            out "copying ${plugin_name} from ${from}" 2
            cp "$from" "${target}" -r
            echo "Done"

            out "Activating $plugin_name" 2
            ( cd "${WORDPRESS_BASE_DIR}/${site}" && "${WP_CLI_PATH}" plugin activate "$plugin_name" )
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
        (
            cd "${WORDPRESS_BASE_DIR}/${site}/wp-content/plugins" || exit 1

            if [[ -d "$plugin_name" ]]; then
                out "Removing $plugin_name" 2
                "${WP_CLI_PATH}" plugin delete "$plugin_name"
                echo "Done"
            fi
        )

        if [[ "$pause" -eq 1 ]]; then
            echo -e "${Purple}To continue press any key and enter...${Color_Off}"
            read -r continue_key
        fi
    done
}

# Install plugins on sites
install_plugins() {
    local plugin_name="$1"
    local site

    for site in "${sites[@]}"; do
        out "${site}" 1
        (
            cd "${WORDPRESS_BASE_DIR}/${site}" || exit 1

            local target="wp-content/plugins/"
            if [[ -d "${target}${plugin_name}" ]]; then
                out "${plugin_name} already exists" 3
            else
                "${WP_CLI_PATH}" plugin install "$plugin_name"
                "${WP_CLI_PATH}" plugin activate "$plugin_name"
            fi
        )
    done
}

# Update plugins
wp_update() {
    local plugin="$1"
    local site
    local target_dir

    for site in "${sites[@]}"; do
        out "$site" 1
        out "check $plugin if there is one, update it" 2

        if [[ "$site" == "." || "${WORDPRESS_BASE_DIR}${site}" == "." ]]; then
            target_dir="."
        else
            target_dir="${WORDPRESS_BASE_DIR}/${site}"
        fi

        (
            if [[ "$target_dir" != "." ]]; then
                cd "$target_dir" || exit 1
            fi

            if [[ "$plugin" != "all" ]]; then
                out "found $plugin! Updating..." 2
                ${WP_CLI_PATH} plugin update "$plugin"
            else
                out "updating all plugins" 2
                ${WP_CLI_PATH} plugin list --update=available
                ${WP_CLI_PATH} plugin update --all
            fi
        )
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
                read -r -d '' license <<- EOM || true
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
                read -r -d '' license <<- EOM || true
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

    # Add license only if not found
    if grep -q "$plugin" wp-config.php; then
        echo "${plugin}_LICENSE already exists"
    else
        echo "$license" >> ./wp-config.php
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
    ${WP_CLI_PATH} migrate setting update pull on
}

# Setup Akeeba Download ID
wp_key_akeeba() {
    if [[ -z "${AKEEBA_DOWNLOAD_ID:-}" ]]; then
        out "AKEEBA_DOWNLOAD_ID not found in environment" 3
        return 1
    fi

    out "Setting up Akeeba Download ID" 2

    if ${WP_CLI_PATH} option update akeeba_download_id "$AKEEBA_DOWNLOAD_ID" 2>/dev/null; then
        out "Akeeba Download ID added to database" 4

        if ! grep -q "AKEEBA_DOWNLOAD_ID" wp-config.php 2>/dev/null; then
            local akeeba_config
            read -r -d '' akeeba_config <<- EOM || true
if (!defined('AKEEBA_DOWNLOAD_ID')) {
    define('AKEEBA_DOWNLOAD_ID', '${AKEEBA_DOWNLOAD_ID}');
}
EOM
            echo "$akeeba_config" >> ./wp-config.php
            out "Akeeba Download ID also added to wp-config.php" 2
        fi

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

    if [[ -n "${ACF_PRO_LICENSE:-}" ]]; then
        if wp_key_acf_pro; then
            ((setup_count++))
        fi
    fi

    if [[ -n "${WPMDB_LICENCE:-}" ]]; then
        if wp_key_migrate; then
            ((setup_count++))
        fi
    fi

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
# SITE CONFIG (mod site license|remote|url)
#===============================================================================

# Resolve a site name to its filesystem path (absolute stays; else BASE/site).
_site_path() {
    if [[ "$1" = /* ]]; then echo "$1"; else echo "${WORDPRESS_BASE_DIR}/$1"; fi
}

_site_header() {
    echo -e "${Green}----------------"
    echo -e "$1"
    echo -e "----------------${Color_Off}"
}

# mod site license [show_values] — per site: is each license applied?
site_license_status() {
    local show_values="${1:-0}" site sp cfg mark
    for site in "${sites[@]}"; do
        sp="$(_site_path "$site")"; cfg="$sp/wp-config.php"
        _site_header "$site"
        if grep -q "ACF_PRO_LICENSE" "$cfg" 2>/dev/null; then mark="${Green}applied${Color_Off}"; else mark="${Yellow}not applied${Color_Off}"; fi
        echo -e "  ACF Pro:     $mark"
        if grep -q "WPMDB_LICENCE" "$cfg" 2>/dev/null; then mark="${Green}applied${Color_Off}"; else mark="${Yellow}not applied${Color_Off}"; fi
        echo -e "  WP Migrate:  $mark"
        if grep -q "AKEEBA_DOWNLOAD_ID" "$cfg" 2>/dev/null \
           || [[ -n "$(${WP_CLI_PATH} --path="$sp" option get akeeba_download_id 2>/dev/null || true)" ]]; then
            mark="${Green}applied${Color_Off}"; else mark="${Yellow}not applied${Color_Off}"; fi
        echo -e "  Akeeba:      $mark"
    done
    if [[ "$show_values" == "1" ]]; then
        echo -e "${Purple}Configured license values (from ~/.keys / .env):${Color_Off}"
        echo "  ACF_PRO_LICENSE    = ${ACF_PRO_LICENSE:-<not set>}"
        echo "  WPMDB_LICENCE      = ${WPMDB_LICENCE:-<not set>}"
        echo "  AKEEBA_DOWNLOAD_ID = ${AKEEBA_DOWNLOAD_ID:-<not set>}"
    fi
}

# mod site license set <acf|wpmdb|akeeba|all>
site_license_set() {
    local which="$1" site sp
    for site in "${sites[@]}"; do
        sp="$(_site_path "$site")"
        _site_header "$site"
        ( cd "$sp" || exit 0
          case "$which" in
              acf)    wp_license_plugins "ACF_PRO" ;;
              wpmdb)  wp_key_migrate ;;
              akeeba) wp_key_akeeba ;;
              all)    wp_setup_all_licenses ;;
              *) log_error "license set: use acf, wpmdb, akeeba, or all"; exit 1 ;;
          esac )
    done
}

# mod site remote — show remotes per site
site_remote_show() {
    local site sp repo
    for site in "${sites[@]}"; do
        sp="$(_site_path "$site")"; repo="$sp/wp-content"
        _site_header "$site"
        if git -C "$repo" rev-parse --is-inside-work-tree &>/dev/null; then
            git -C "$repo" remote -v | sed 's/^/  /' || echo "  <none>"
        else
            echo -e "  ${Yellow}no git repo in wp-content${Color_Off}"
        fi
    done
}

# mod site remote add <name> <url>
site_remote_add() {
    local name="$1" url="$2" site sp repo
    for site in "${sites[@]}"; do
        sp="$(_site_path "$site")"; repo="$sp/wp-content"
        _site_header "$site"
        if git -C "$repo" rev-parse --is-inside-work-tree &>/dev/null; then
            git -C "$repo" remote add "$name" "$url" \
                && echo -e "  ${Green}added remote $name -> $url${Color_Off}"
        else
            echo -e "  ${Yellow}no git repo in wp-content — skipped${Color_Off}"
        fi
    done
}

# mod site remote set [url] — set origin url; omit url to edit the current value
site_remote_set() {
    local url="${1:-}" site sp repo cur new
    for site in "${sites[@]}"; do
        sp="$(_site_path "$site")"; repo="$sp/wp-content"
        _site_header "$site"
        if ! git -C "$repo" rev-parse --is-inside-work-tree &>/dev/null; then
            echo -e "  ${Yellow}no git repo in wp-content — skipped${Color_Off}"; continue
        fi
        cur="$(git -C "$repo" remote get-url origin 2>/dev/null || echo '')"
        if [[ -n "$url" ]]; then new="$url"; else read -e -i "$cur" -p "  origin url: " new || true; fi
        [[ -z "$new" ]] && { echo "  (skipped)"; continue; }
        if [[ -n "$cur" ]]; then
            git -C "$repo" remote set-url origin "$new" && echo -e "  ${Green}origin -> $new${Color_Off}"
        else
            git -C "$repo" remote add origin "$new" && echo -e "  ${Green}added origin -> $new${Color_Off}"
        fi
    done
}

# mod site url — show home/siteurl per site
site_url_show() {
    local site sp
    for site in "${sites[@]}"; do
        sp="$(_site_path "$site")"
        _site_header "$site"
        echo "  home:    $(${WP_CLI_PATH} --path="$sp" option get home 2>/dev/null || echo '?')"
        echo "  siteurl: $(${WP_CLI_PATH} --path="$sp" option get siteurl 2>/dev/null || echo '?')"
    done
}

# mod site url set <home|siteurl|both> [url] — omit url to edit the current value
site_url_set() {
    local which="$1" url="${2:-}" site sp opt c n
    local opts=()
    case "$which" in
        home) opts=(home) ;;
        siteurl) opts=(siteurl) ;;
        both) opts=(home siteurl) ;;
    esac
    for site in "${sites[@]}"; do
        sp="$(_site_path "$site")"
        _site_header "$site"
        for opt in "${opts[@]}"; do
            c="$(${WP_CLI_PATH} --path="$sp" option get "$opt" 2>/dev/null || echo '')"
            if [[ -n "$url" ]]; then n="$url"; else read -e -i "$c" -p "  $opt: " n || true; fi
            [[ -z "$n" ]] && { echo "  ($opt skipped)"; continue; }
            ${WP_CLI_PATH} --path="$sp" option update "$opt" "$n" >/dev/null 2>&1 \
                && echo -e "  ${Green}$opt -> $n${Color_Off}"
        done
    done
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

    for site in "${sites[@]}"; do
        out "$site" 1
        ( cd "${WORDPRESS_BASE_DIR}/$site" && "${WP_CLI_PATH}" user create "$username" "$email" --user_pass="$password" --role=administrator )
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
        chown "$webserver_user:$webserver_group" "${WORDPRESS_BASE_DIR}/${site}/wp-content" -Rvf
        chmod -Rv "${UPLOAD_PERMISSIONS:-755}" "${WORDPRESS_BASE_DIR}/${site}/wp-content/uploads"
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

# Force HTTPS on WordPress site
wp_force_https() {
    local site
    local target_dir

    for site in "${sites[@]}"; do
        out "Forcing HTTPS for WordPress site: $site" 2

        if [[ "$site" == "." || "${WORDPRESS_BASE_DIR}${site}" == "." ]]; then
            target_dir="."
        else
            target_dir="${WORDPRESS_BASE_DIR}/${site}"
        fi

        (
            if [[ "$target_dir" != "." ]]; then
                cd "$target_dir" || exit 1
            fi

            # Remove existing HTTPS-related block and orphaned lines in one pass
            sed -i -e '/Force HTTPS - Added by webwerk mod script/,/FORCE_SSL_ADMIN/d' \
                   -e '/FORCE_SSL_ADMIN/d' \
                   -e '/WP_HOME/d' \
                   -e '/WP_SITEURL/d' \
                   wp-config.php 2>/dev/null || true

            local site_url
            site_url=$(${WP_CLI_PATH} option get siteurl 2>/dev/null || echo "")

            if [[ -z "$site_url" ]]; then
                out "Warning: Could not detect site URL" 3
                site_url="https://\$_SERVER['HTTP_HOST']"
            else
                site_url="${site_url/http:/https:}"
                out "Site URL: $site_url" 2
            fi

            cat <<'EOF' >> wp-config.php

// Force HTTPS - Added by webwerk mod script
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
define('FORCE_SSL_ADMIN', true);
EOF

            ${WP_CLI_PATH} option update home "$site_url" 2>/dev/null || true
            ${WP_CLI_PATH} option update siteurl "$site_url" 2>/dev/null || true

            out "HTTPS forcing enabled successfully" 4
            out "Site URL updated to: $site_url" 2
        )
    done
}

#===============================================================================
# GIT FUNCTIONS
#===============================================================================

# Update repositories
update_repo() {
    local site

    for site in "${sites[@]}"; do
        out "${site}" 1
        (
            cd "${WORDPRESS_BASE_DIR}/${site}/wp-content" || exit 1
            out "updating repository..." 1
            git pull 1>/dev/null
        )
    done
}

# Git operations for WordPress sites
git_wp() {
    local subcommand="$1"
    local site

    for site in "${sites[@]}"; do
        out "${site}" 1
        (
            cd "${WORDPRESS_BASE_DIR}/${site}/wp-content" || exit 1

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
        )
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

# Enable search engine indexing
wp_enable_se() {
    out "Enabling search engine indexing for $(basename "$PWD")"
    "${WP_CLI_PATH}" option update blog_public 1
}

#===============================================================================
# CUSTOM POST TYPE EXPORT
#===============================================================================

# Export Custom Post Types
wp_getCPT() {
    local cpts=""
    local cpts_sql
    OPTIND=1

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

    out "$1" 1      # variable name
    out "$var" 2    # current value
    var="$value"
    out "$var" 1    # new value
}

#===============================================================================
# FUNCTION EXPORTS
#===============================================================================

# Export all functions for use by other scripts
export -f colors out txt
export -f searchwp process_dirs process_sites process_sites_all print_sites
export -f os_detection
export -f list_wp_plugins list_wp_themes wp_activate_webwerk_theme copy_plugins remove_plugins install_plugins wp_update wp_plugin_action
export -f wp_license_plugins wp_key_acf_pro wp_key_migrate wp_key_akeeba wp_setup_all_licenses
export -f _site_path _site_header site_license_status site_license_set
export -f site_remote_show site_remote_add site_remote_set site_url_show site_url_set
export -f wp_new_user wp_rights
export -f htaccess wp_hide_errors wp_debug wp_force_https
export -f update_repo git_wp wp_block_se wp_enable_se
export -f wp_getCPT assign_env

[[ "${WEBWERK_QUIET:-0}" != "1" ]] && out "$SCRIPT_NAME v$SCRIPT_VERSION loaded successfully" 4 || true

# Conditional output based on flags
[[ "${print:-0}" = "1" ]] && print_sites || true
[[ "${total:-0}" = "1" ]] && echo -e "\n=======\nTotal ${anzahl:-0} WP-Sites" || true
