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
  - `mod/` - Site modification and management (writes/changes)
  - `get/` - Read-only retrieval/query (plugins/themes/core/status/url/db)
  - `utils/` - Shared helper functions and utilities

### Key Scripts

- **`webwerk:1`** - Main entry point with command routing and configuration loading
- **`scripts/utils/wphelpfunctions.sh:1`** - Core utility library with 850+ lines of shared functions
- **`scripts/install/wplocalinstall.sh:1`** - WordPress installation engine
- **`scripts/update/wpupdate.sh`** - Update management system
- **`scripts/mod/wpmod.sh`** - Site modification tools (writes)
- **`scripts/get/wpget.sh`** - Read-only retrieval: `webwerk get plugins|themes|core|status|brief|git|url|db`. Reads live here only; the old `mod` read flags (`-C`/`-B`/`-e`/`-O`/`-l`/`-g`) and `mod plugin list` were removed. (`mod -T NUM|NAME` still activates a theme.)

## Command Grammar

The CLI is **verb-first**: `webwerk VERB [MODE] [WHAT] [OPTIONS]`.

- **VERB** = `install | update | mod | get | remove | doctor` — the action/intent.
- **MODE** = `local (default) | bare | ddev` — where it runs. `bare` is install-only;
  `local` is the default for every verb (including `remove`); `ddev` runs against the
  DDEV container. `ddev` is a **mode word only** (`install ddev`, `update ddev`, …) —
  there is no standalone `ddev <verb>` form. `doctor` takes no mode; its WHATs are
  `config` (default — the tool/env) and `sites` (per-site health).
- **WHAT** = the verb's object/scope where it has one, e.g. `get themes`,
  `update plugins`, `update plugin <name>`, `mod theme [webwerk|NAME|NUM]`,
  `mod plugin <install|copy|update|activate|deactivate|remove> [NAME]`,
  `mod site <license|remote|url> [show|set|add …]`,
  `mod branch [merge [NAME]]` (overview / merge current branch into NAME,
  default `live`, no push),
  `mod config <debug|errors|indexing|https|htaccess> [on|off|hide|show]`,
  `mod user [add NAME [--role R] [--pass P] [--email E]]`.
  (`mod` WHATs wrap the old flags, kept as aliases: `-T`, `-i`/`-y`/`-u`,
  `-f`/`-m`/`-k`, `-x`/`-z`/`-S`/`-r`/`--htaccess`, `-n`+`-U`/`-P`/`-E`. `mod site`
  groups site-level config views/writes: license applied-status (+`--values`),
  git remote, home/siteurl. `mod config` shows/toggles the WP settings; `mod user`
  lists/adds users (role defaults to administrator).
  `mod` hoists config/selection flags (`-d`/`-w`/`-s`/`-a`/`-A`) to the front in
  `main()`, so they may appear anywhere on the line — even after a WHAT action.)
- Verbs and modes accept any unambiguous prefix abbreviation (`i/u/m/g/r/s`,
  `l/b/d`). A bare `help` word works at any level: `webwerk help`, `webwerk <verb> help`,
  and `webwerk get <what> help` (per-target help).

### Why verb-first (and not wp-cli's noun-first)

wp-cli is `wp NOUN VERB` (`wp plugin list`) because it does **resource CRUD on one
site** — the noun is the stable thing you act on. webwerk is **intent/orchestration
across many sites**: its top level is genuinely verbs (install a site, update
everything, remove a site, get an overview), and `install`/`mod`/`remove`/`doctor`
have no natural noun. Going noun-first would force noun-first onto `get`/`update`
while the rest stayed verb-first — a fractured grammar. So keep verb-first for every
command. The `WHAT` words (`plugins`, `themes`, `core`, `db`) intentionally reuse
wp-cli's noun names, so users get the familiarity without the reordering. When adding
a command, make it a verb (or a `WHAT` under an existing verb), not a noun-first form.

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
webwerk doctor
```

## Common Commands

### Installation Modes

```bash
# Full installation with repository cloning
./webwerk install local --wp-title="Accessible Website"

# Minimal WordPress-only installation
./webwerk install bare --wp-title="Simple Site"

# DDEV containerized development
./webwerk install ddev --wp-title="DDEV Site"

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

# Status overviews (read-only; live under `get`, add -s site1,site2 to scope)
./webwerk get status   # full per-site status (core, plugins, themes)
./webwerk get brief    # brief status; --errors = only errors, --outdated = only outdated
./webwerk get git      # wp-content git overview (remote, branch, status)

# Modify a DDEV site (local is default): webwerk mod [local|ddev]
./webwerk mod ddev -x on
```

### System Status

```bash
# Check system configuration and script availability
./webwerk doctor

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
- **Interactive `-s` picker**: `select_sites_interactive()` (wphelpfunctions.sh, exported) - bare `-s` (no value) lists sites numbered and reads a name/number selection; prints the chosen names as CSV on stdout (list+prompt to /dev/tty). Wired into every `-s` handler: `update`/`mod`/`get`/`doctor sites`/`remove`. `-s name,name` stays direct (no prompt)
- **Plugin Management**: `wp_update()`, `copy_plugins()`, `install_plugins()`
- **License Management**: `wp_setup_all_licenses()`, `wp_key_acf_pro()`, `wp_key_migrate()`
- **User Management**: `wp_new_user()` - Administrator account creation
- **Debug Control**: `wp_debug()`, `wp_hide_errors()`, `wp_force_https()` - Development mode and HTTPS
- **SEO Management**: `wp_block_se()`, `wp_enable_se()` - Search engine indexing control
- **Git Integration**: `update_repo()`, `git_wp()` - Repository synchronization
- **Status Overviews (wpget.sh)**: `get_status()` (`get status`), `get_brief()` (`get brief` + `--errors`/`--outdated`), `get_git()` (`get git`) - per-site core/plugin/theme and wp-content git overviews; honor `-s` or scan the base dir. `-a` pauses between sites (`maybe_pause()`, TTY only, `x` quits); `-A`/default stream
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
./webwerk install ddev --wp-title="Test DDEV"

# Test update functionality
./webwerk update --sites=testsite

# Test management features
./webwerk mod --sites=testsite --enable-debug
```