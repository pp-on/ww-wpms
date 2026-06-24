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
- **`scripts/utils/wphelpfunctions.sh:1`** - Core utility library with 850+ lines of shared functions
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
./webwerk install local --wp-title="Accessible Website"

# Minimal WordPress-only installation
./webwerk install bare --wp-title="Simple Site"

# DDEV containerized development
./webwerk ddev install --wp-title="DDEV Site"

# Install shows a single-line phase progress bar by default on a TTY;
# use -v/--verbose (or pipe the output) for the full log
./webwerk install local --wp-title="Site" -v

# Batch install into every empty subdirectory of the current dir
# (dir name = site/repo name; non-empty dirs skipped). -a prompts per dir.
cd ~/www/repos/netcup && ./webwerk install -A -G arbeit

# Activate the site theme after cloning: -T/--theme auto-detects
# (webwerk -> dir name -> dir name minus trailing -suffix), or --theme=NAME.
# No match + interactive (non-batch) -> prompts to pick an installed theme.
./webwerk install -G arbeit -T
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

# Status overviews (add -s site1,site2 to scope to specific sites)
./webwerk mod -C    # full per-site status (core, plugins, themes)
./webwerk mod -B    # brief status; -e = only errors, -O = only outdated
./webwerk mod -g    # wp-content git overview (remote, branch, status)

# Modify a DDEV site (local is default): webwerk mod [local|ddev]
./webwerk mod ddev -x on
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
- **Debug Control**: `wp_debug()`, `wp_hide_errors()`, `wp_force_https()` - Development mode and HTTPS
- **SEO Management**: `wp_block_se()`, `wp_enable_se()` - Search engine indexing control
- **Git Integration**: `update_repo()`, `git_wp()` - Repository synchronization
- **Status Overviews (wpmod.sh)**: `do_status()` (`-C`), `do_status_brief()` (`-B`/`-e`/`-O`), `do_git_status()` (`-g`) - per-site core/plugin/theme and wp-content git overviews; all use `collect_site_dirs()` to honor `-s`/`-a` or scan the base dir
- **Install Progress (webwerk)**: `render_install_progress()` + `run_install()` - single-line phase progress bar shown by default on a TTY; `-v`/`--verbose` (or piped output) falls back to the full log
- **Batch Install (webwerk)**: `run_install_batch()` - `install -A`/`-a` install into each empty immediate subdirectory of the current dir (dir name = site/repo name); non-empty dirs skipped, never overwritten. Most long install options also have short aliases (`-H`/`-U`/`-P`/`-N`, `-u`/`-t`/`-e`, `-r`/`-g`/`-p`, `-w`/`-d`, `-X`/`-m`/`-s`)

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
./webwerk install local --wp-title="Test Full"
./webwerk install bare --wp-title="Test Minimal"
./webwerk ddev install --wp-title="Test DDEV"

# Test update functionality
./webwerk update --sites=testsite

# Test management features
./webwerk mod --sites=testsite --enable-debug
```