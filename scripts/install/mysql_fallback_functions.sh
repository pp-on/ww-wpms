#!/bin/bash
#
# MySQL Fallback Functions v2.0
# Part of Webwerk WordPress Management Suite
# 
# Description: Manual database operations when WP-CLI fails
# Author: Webwerk Team
# License: MIT
#

set -euo pipefail

#===============================================================================
# MYSQL FALLBACK FUNCTIONS
#===============================================================================

# Test database connection manually
mysql_test_connection() {
    local db_host="${1:-$DB_HOST}"
    local db_user="${2:-$DB_USER}"
    local db_password="${3:-$DB_PASSWORD}"
    local timeout="${4:-5}"
    
    log_debug "Testing manual MySQL connection to $db_host"
    
    if mysql \
        --host="$db_host" \
        --user="$db_user" \
        --password="$db_password" \
        --connect-timeout="$timeout" \
        --execute="SELECT 1;" >/dev/null 2>&1; then
        
        log_debug "Manual MySQL connection successful"
        return 0
    else
        log_error "Manual MySQL connection failed"
        return 1
    fi
}

# Check if database exists manually
mysql_check_database_exists() {
    local db_name="${1:-$DB_NAME}"
    
    log_debug "Checking database '$db_name' existence manually"
    
    local db_exists
    if db_exists=$(mysql \
        --host="$DB_HOST" \
        --user="$DB_USER" \
        --password="$DB_PASSWORD" \
        --execute="SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$db_name';" \
        2>/dev/null | grep -c "$db_name" || true); then
        
        if [[ "$db_exists" -gt 0 ]]; then
            log_debug "Database '$db_name' exists"
            return 0
        else
            log_debug "Database '$db_name' does not exist"
            return 1
        fi
    else
        log_error "Failed to check database existence manually"
        return 2
    fi
}

# Create database manually
mysql_create_database() {
    local db_name="${1:-$DB_NAME}"
    local force="${2:-false}"
    local charset="${3:-utf8mb4}"
    local collation="${4:-utf8mb4_unicode_ci}"
    
    log_info "Creating database manually: $db_name"
    
    # Check if database exists
    if mysql_check_database_exists "$db_name"; then
        if [[ "$force" != "true" ]]; then
            log_warning "Database '$db_name' exists. All data will be permanently deleted!"
            echo "Continue? [y/N]: "
            read -r answer
            if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
                log_error "Database creation cancelled by user"
                return 1
            fi
        fi
        
        log_info "Dropping existing database: $db_name"
        mysql --host="$DB_HOST" --user="$DB_USER" --password="$DB_PASSWORD" \
            --execute="DROP DATABASE IF EXISTS \`$db_name\`;" || {
            log_error "Failed to drop existing database: $db_name"
            return 1
        }
    fi
    
    log_info "Creating new database: $db_name (charset: $charset, collation: $collation)"
    if mysql --host="$DB_HOST" --user="$DB_USER" --password="$DB_PASSWORD" \
        --execute="CREATE DATABASE \`$db_name\` CHARACTER SET $charset COLLATE $collation;"; then
        
        log_success "Database '$db_name' created successfully via manual MySQL"
        return 0
    else
        log_error "Failed to create database manually: $db_name"
        return 1
    fi
}

# Drop all WordPress tables manually
mysql_drop_wp_tables() {
    local db_name="${1:-$DB_NAME}"
    local db_prefix="${2:-$DB_PREFIX}"
    
    log_info "Dropping WordPress tables manually from database: $db_name"
    
    # Get list of WordPress tables
    local wp_tables
    if wp_tables=$(mysql --host="$DB_HOST" --user="$DB_USER" --password="$DB_PASSWORD" \
        --database="$db_name" \
        --execute="SHOW TABLES LIKE '${db_prefix}%';" \
        --skip-column-names 2>/dev/null); then
        
        if [[ -n "$wp_tables" ]]; then
            log_info "Found WordPress tables with prefix '$db_prefix', dropping them"
            
            # Drop each table
            while IFS= read -r table; do
                if [[ -n "$table" ]]; then
                    log_debug "Dropping table: $table"
                    mysql --host="$DB_HOST" --user="$DB_USER" --password="$DB_PASSWORD" \
                        --database="$db_name" \
                        --execute="DROP TABLE IF EXISTS \`$table\`;" 2>/dev/null || \
                        log_warning "Could not drop table: $table"
                fi
            done <<< "$wp_tables"
            
            log_success "WordPress tables dropped manually"
        else
            log_info "No WordPress tables found with prefix '$db_prefix'"
        fi
        
        return 0
    else
        log_error "Failed to get table list from database: $db_name"
        return 1
    fi
}

# Reset database manually (drop and recreate)
mysql_reset_database() {
    local db_name="${1:-$DB_NAME}"
    
    log_info "Resetting database manually: $db_name"
    
    if mysql_create_database "$db_name" "true"; then
        log_success "Database reset manually via drop/recreate"
        return 0
    else
        log_error "Manual database reset failed"
        return 1
    fi
}

# Import SQL file manually
mysql_import_sql() {
    local sql_file="$1"
    local db_name="${2:-$DB_NAME}"
    
    if [[ ! -f "$sql_file" ]]; then
        log_error "SQL file not found: $sql_file"
        return 1
    fi
    
    log_info "Importing SQL file manually: $sql_file"
    
    if mysql --host="$DB_HOST" --user="$DB_USER" --password="$DB_PASSWORD" \
        --database="$db_name" < "$sql_file"; then
        
        log_success "SQL file imported successfully: $sql_file"
        return 0
    else
        log_error "Failed to import SQL file: $sql_file"
        return 1
    fi
}

# Export database manually
mysql_export_database() {
    local db_name="${1:-$DB_NAME}"
    local output_file="${2:-${db_name}_$(date +%Y%m%d_%H%M%S).sql}"
    
    log_info "Exporting database manually: $db_name to $output_file"
    
    if mysqldump --host="$DB_HOST" --user="$DB_USER" --password="$DB_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        "$db_name" > "$output_file"; then
        
        log_success "Database exported successfully: $output_file"
        return 0
    else
        log_error "Failed to export database: $db_name"
        return 1
    fi
}

# Check MySQL server status
mysql_check_server_status() {
    log_info "Checking MySQL server status"
    
    local mysql_version server_info
    
    if mysql_version=$(mysql --host="$DB_HOST" --user="$DB_USER" --password="$DB_PASSWORD" \
        --execute="SELECT VERSION();" --skip-column-names 2>/dev/null); then
        
        log_info "MySQL version: $mysql_version"
        
        if server_info=$(mysql --host="$DB_HOST" --user="$DB_USER" --password="$DB_PASSWORD" \
            --execute="SHOW STATUS LIKE 'Uptime';" --skip-column-names 2>/dev/null); then
            
            log_info "MySQL server info: $server_info"
        fi
        
        return 0
    else
        log_error "Cannot connect to MySQL server"
        return 1
    fi
}

# Optimize database manually
mysql_optimize_database() {
    local db_name="${1:-$DB_NAME}"
    
    log_info "Optimizing database manually: $db_name"
    
    # Get all tables in database
    local tables
    if tables=$(mysql --host="$DB_HOST" --user="$DB_USER" --password="$DB_PASSWORD" \
        --database="$db_name" \
        --execute="SHOW TABLES;" \
        --skip-column-names 2>/dev/null); then
        
        if [[ -n "$tables" ]]; then
            log_info "Optimizing tables in database: $db_name"
            
            while IFS= read -r table; do
                if [[ -n "$table" ]]; then
                    log_debug "Optimizing table: $table"
                    mysql --host="$DB_HOST" --user="$DB_USER" --password="$DB_PASSWORD" \
                        --database="$db_name" \
                        --execute="OPTIMIZE TABLE \`$table\`;" >/dev/null 2>&1 || \
                        log_debug "Could not optimize table: $table"
                fi
            done <<< "$tables"
            
            log_success "Database optimization completed"
        else
            log_info "No tables found in database: $db_name"
        fi
        
        return 0
    else
        log_error "Failed to get table list for optimization"
        return 1
    fi
}

# Export WordPress installation functions
export -f mysql_test_connection mysql_check_database_exists mysql_create_database
export -f mysql_drop_wp_tables mysql_reset_database mysql_import_sql mysql_export_database
export -f mysql_check_server_status mysql_optimize_database

log_debug "MySQL fallback functions loaded successfully"
