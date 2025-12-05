# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Webwerk WordPress Management Suite v2.0** - a comprehensive collection of Bash scripts for automated WordPress installation, updates, and management. The suite focuses on **Barrierefreiheit** (Accessibility) for web agencies and developers, supporting local development, DDEV containerization, and remote server deployments.

## Architecture

### Core Components

- **`webwerk`** - Main dispatcher script that orchestrates all operations
- **`scripts/`** - Modular script collection organized by function:
  - `install/` - WordPress installation scripts
  - `update/` - Update management scripts  
  - `mod/` - Site modification and management
  - `utils/` - Shared helper functions and utilities

### Key Scripts

- **`webwerk:1`** - Main entry point with command routing and configuration loading
- **`scripts/utils/wphelpfunctions.sh:1`** - Core utility library with 700+ lines of shared functions
- **`scripts/install/wplocalinstall.sh:1`** - WordPress installation engine
- **`scripts/update/wpupdate.sh`** - Update management system
- **`scripts/mod/wpmod.sh`** - Site modification tools

## Configuration System

The suite uses a dual-configuration approach:

1. **`.env`** - Main configuration file with database, WordPress, and development settings
2. **`~/.keys`** - Sensitive license keys (ACF Pro, WP Migrate DB, Akeeba) stored outside repository

Configuration is loaded hierarchically: environment variables → `.env` → `~/.keys`

## Installation

### System Installation
```bash
# Install webwerk for system-wide access
./install.sh

# Verify installation
webwerk status
```

## Common Commands

### Installation Modes

```bash
# Full installation with repository cloning
./webwerk full install --wp-title="Accessible Website"

# Minimal WordPress-only installation
./webwerk minimal install --wp-title="Simple Site"

# DDEV containerized development
./webwerk ddev install --wp-title="DDEV Site"
```

### Updates and Management

```bash
# Update all sites
./webwerk update --all-sites

# Update specific sites with git commits
./webwerk update --sites=site1,site2 --git --summary

# Enable debug mode
./webwerk mod --sites=mysite --enable-debug

# Setup license keys
./webwerk mod --sites=mysite --setup-acf-license
```

### System Status

```bash
# Check system configuration and script availability
./webwerk status

# View help and available commands
./webwerk --help
```

## Development Workflow

### Environment Detection
The suite automatically detects:
- WSL2 environments  
- DDEV containers
- Docker environments
- Git Bash on Windows

### Key Functions (wphelpfunctions.sh)
- **Site Discovery**: `searchwp()`, `process_sites()` - WordPress installation detection
- **Plugin Management**: `wp_update()`, `copy_plugins()`, `install_plugins()`
- **License Management**: `wp_setup_all_licenses()`, `wp_key_acf_pro()`, `wp_key_migrate()`
- **User Management**: `wp_new_user()` - Administrator account creation
- **Debug Control**: `wp_debug()`, `wp_hide_errors()` - Development mode toggling
- **Git Integration**: `update_repo()`, `git_wp()` - Repository synchronization

### Configuration Variables
Essential variables defined in `.env`:
- `DB_HOST`, `DB_USER`, `DB_PASSWORD` - Database connection
- `WP_CLI_PATH` - WP-CLI binary location
- `GIT_USER`, `GIT_PROTOCOL` - Repository settings
- `LOCAL_URL_BASE` - Development URL structure
- `WEBSERVER_USER`, `WEBSERVER_GROUP` - File permissions

## Logging

All operations are logged with timestamps to:
- `webwerk.log` - General operations
- `webwerk-install.log` - Installation-specific logs

Log levels: `INFO`, `WARNING`, `ERROR`, `SUCCESS`

## Testing

Test all installation modes before making changes:

```bash
# Test each mode
./webwerk full install --wp-title="Test Full"
./webwerk minimal install --wp-title="Test Minimal"
./webwerk ddev install --wp-title="Test DDEV"

# Test update functionality
./webwerk update --sites=testsite

# Test management features
./webwerk mod --sites=testsite --enable-debug
```