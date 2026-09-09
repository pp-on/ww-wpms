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
  - `set/` - Site modification and management (writes/changes)
  - `get/` - Read-only retrieval/query (plugins/themes/core/status/url/db)
  - `utils/` - Shared helper functions and utilities

### Key Scripts

- **`webwerk:1`** - Main entry point with command routing and configuration loading
- **`scripts/utils/wphelpfunctions.sh:1`** - Core utility library with 850+ lines of shared functions
- **`scripts/install/wplocalinstall.sh:1`** - WordPress installation engine
- **`scripts/update/wpupdate.sh`** - Update management system
- **`scripts/set/wpset.sh`** - Site modification tools (writes)
- **`scripts/get/wpget.sh`** - Read-only retrieval: `webwerk get plugins|plugin|themes|core|status|brief|remote|branch|url|license|db|profiles` (`get plugin NAME` finds which sites have a plugin whose slug or human title matches NAME; `get branch` lists wp-content branches; `-l` local / `-r` remote / both; it refreshes the remote refs first (`git fetch --prune`, `--no-fetch` opts out) so branches created on origin after the clone are listed — that touches only `refs/remotes`, creating a local branch stays `set branch add`; `get license` shows per-site ACF/WP-Migrate/Akeeba applied-status, `-x`/`--values` also reveals the configured keys). Reads live here only; the old `set` read flags (`-C`/`-B`/`-e`/`-O`/`-l`/`-g`) and `set plugin list` were removed. (`set -T NUM|NAME` still activates a theme.)

## Command Grammar

The CLI is **verb-first**: `webwerk VERB [MODE] [WHAT] [OPTIONS]`.

- **VERB** = `install | update | set | get | remove | doctor` — the action/intent.
- **MODE** = `local (default) | bare | ddev` — where it runs. `bare` is install-only;
  `local` is the default for every verb (including `remove`); `ddev` runs against the
  DDEV container. `ddev` is a **mode word only** (`install ddev`, `update ddev`, …) —
  there is no standalone `ddev <verb>` form. `doctor` takes no mode; its WHATs are
  `config` (default — the tool/env) and `sites` (per-site health).
- **WHAT** = the verb's object/scope where it has one, e.g. `get themes`,
  `update plugins`, `update plugin <name>`, `set theme [webwerk|NAME|NUM]`,
  `set plugin <install|copy|update|activate|deactivate|remove> [NAME]`,
  `set site <license|remote|url>`,
  `set branch <NAME|all|rename [OLD] NEW|merge [NAME]>` (`branch NAME` does the whole sequence in one
  command: fetch (when NAME is unknown) → create it *tracking* `origin/NAME` if origin
  has it, else from the current branch → switch to it → `push -u origin`; the word
  `no-push` keeps it local, no NAME → pick from existing. `branch all`: bring in every
  remote branch not local yet, no checkout/no push — the `set`-time counterpart of
  `install -B/--all-branches`. merge: merge current into NAME, default `live`, no push.
  rename: `git branch -m [OLD] NEW` per site + `push -u origin NEW`; one name renames
  whatever branch the site is on, `no-push` stays local. `origin/OLD` is deliberately
  never deleted — irreversible and breaks other clones — only reported.
  The verb `add` is optional (`branch add NAME` == `branch NAME`) and is *required* for
  more than one name, so a mistyped `merge`/`rename` can't create+push branches. There is no
  `branch fetch` verb. Listing branches moved to `get branch`),
  `set config <debug|errors|indexing|hardening|https|htaccess> [on|off|hide|show]`,
  `set user [add NAME [--role R] [--pass P] [--email E]]`,
  `set profile <add|edit|rm|default> [NAME] [USER] [HOST] [PROTO]` (git profiles:
  name + git user + host + protocol, the only source of clone URLs. Not
  site-scoped - it writes the `.env` and exits. Listing is `get profiles`).
  (`set` WHATs wrap the old flags, kept as aliases: `-T`, `-i`/`-y`/`-u`,
  `-f`/`-m`/`-k`, `-x`/`-z`/`-S`/`-r`/`--htaccess`, `-n`+`-U`/`-P`/`-E`. `set site`
  is write-only (viewing moved to `get`: `get license`, `get url`, `get
  remote` - `site remote show` also still works as a quick per-selection
  look): `site license <acf|wpmdb|akeeba|all>` applies a license; `site
  remote [URL|profile [NAME]]` sets the wp-content git remote directly or
  builds it from a git profile the same way `install -G` does (no NAME uses
  the default profile); `site url <home|siteurl|both> [URL]` (or a bare URL
  for "both") updates home/siteurl. `set config` shows/toggles the WP
  settings; `set user`
  lists/adds users (role defaults to administrator).
  `set` hoists config/selection flags (`-d`/`-w`/`-s`/`-a`/`-A`) to the front in
  `main()`, so they may appear anywhere on the line — even after a WHAT action.)
- Verbs and modes accept any unambiguous prefix abbreviation (`i/u/m/g/r/s`,
  `l/b/d`). A bare `help` word works at any level: `webwerk help`, `webwerk <verb> help`,
  and `webwerk get <what> help` (per-target help).

### Why verb-first (and not wp-cli's noun-first)

wp-cli is `wp NOUN VERB` (`wp plugin list`) because it does **resource CRUD on one
site** — the noun is the stable thing you act on. webwerk is **intent/orchestration
across many sites**: its top level is genuinely verbs (install a site, update
everything, remove a site, get an overview), and `install`/`set`/`remove`/`doctor`
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
./webwerk set --sites=mysite --enable-debug

# Setup license keys
./webwerk set --sites=mysite --setup-acf-license

# Status overviews (read-only; live under `get`, add -s site1,site2 to scope)
./webwerk get status   # full per-site status (core, plugins, themes)
./webwerk get brief    # brief status; --errors = only errors, --outdated = only outdated
./webwerk get remote   # wp-content remote URL(s) (add fetch/push to see just one)

# Modify a DDEV site (local is default): webwerk set [local|ddev]
./webwerk set ddev -x on
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
- **Interactive `-s` picker**: `select_sites_interactive()` (wphelpfunctions.sh, exported) - bare `-s` (no value) lists sites numbered and reads a name/number selection; prints the chosen names as CSV on stdout (list+prompt to /dev/tty). Wired into every `-s` handler: `update`/`set`/`get`/`doctor sites`/`remove`. `-s name,name` stays direct (no prompt)
- **Plugin Management**: `wp_update()`, `copy_plugins()`, `install_plugins()`
- **License Management**: `wp_setup_all_licenses()`, `wp_key_acf_pro()`, `wp_key_migrate()`
- **User Management**: `wp_new_user()` - Administrator account creation
- **Debug Control**: `wp_debug()`, `wp_hide_errors()`, `wp_force_https()` - Development mode and HTTPS
- **SEO Management**: `wp_block_se()`, `wp_enable_se()` - Search engine indexing control
- **Git Integration**: `update_repo()`, `git_wp()` - Repository synchronization
- **Status Overviews (wpget.sh)**: `get_status()` (`get status`), `get_brief()` (`get brief` + `--errors`/`--outdated`), `get_remote()` (`get remote [fetch|push]`) - per-site core/plugin/theme status and wp-content remote URL(s); honor `-s` or scan the base dir. `-a` pauses between sites (`maybe_pause()`, TTY only, `x` quits); `-A`/default stream
- **Install Progress (webwerk)**: `render_install_progress()` + `run_install()` - single-line phase progress bar shown by default on a TTY; `-v`/`--verbose` (or piped output) falls back to the full log
- **Batch Install (webwerk)**: `run_install_batch()` - `install -A`/`-a` install into each empty immediate subdirectory of the current dir (dir name = site/repo name); non-empty dirs skipped, never overwritten. Most long install options also have short aliases (`-H`/`-U`/`-P`/`-N`, `-u`/`-t`/`-e`, `-r`/`-g`/`-p`, `-w`/`-d`, `-X`/`-m`/`-s`)

### Configuration Variables
Essential variables defined in `.env`:
- `DB_HOST`, `DB_USER`, `DB_PASSWORD` - Database connection
- `WP_CLI_PATH` - WP-CLI binary location
- `GIT_PROFILE_<name>="USER HOST PROTO"` - **git profiles**, the only source of
  clone URLs; nothing about a git account is hardcoded. Four parts: profile name,
  git user/org, host (an `~/.ssh/config` alias when PROTO=ssh, a hostname when
  https), protocol. `GIT_PROFILE` names the default; `-G NAME` picks one per run
  (parsed into `WEBWERK_GIT_PROFILE` - do **not** name that variable
  `GIT_PROFILE_*`, it would collide with the profile namespace). Stored in the
  `.env` in use (`WEBWERK_ENV_FILE`), never in the repo. No profile and no `-r`
  is a hard error; with no profiles at all, install prompts to create one.
  `-g`/`--git-user` and `-p`/`--git-protocol` were removed (they error with a
  pointer to profiles). Library: `scripts/utils/gitprofiles.sh` (`gp_*`, exported)
- `LOCAL_URL_BASE` - Development URL structure (siteurl = `<base>/<dirname>`).
  Not hardcoded either: unset + no `-b`/`-u` prompts once and saves to the
  `.env` (`gp_resolve_base_url()`); ddev sets its own `.ddev.site`/nip.io URL
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
./webwerk set --sites=testsite --enable-debug
```