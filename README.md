# Webwerk WordPress Management Suite v2.0

A comprehensive WordPress management suite focused on **Barrierefreiheit** (Accessibility) for web agencies and developers.

## 📋 Table of Contents

- [Features](#-features)
- [System Requirements](#-system-requirements)
- [Installation](#-installation)
- [Shell Completions](#shell-completions)
- [Quick Start](#-quick-start)
- [Project Structure](#-project-structure)
- [Configuration](#-configuration)
- [Installation Modes](#-installation-modes)
- [Command Reference](#-command-reference)
- [Architecture](#-architecture)
- [Security Features](#-security-features)
- [Accessibility Focus](#-accessibility-barrierefreiheit-focus)
- [DDEV Integration](#-ddev-integration)
- [Advanced Configuration](#-advanced-configuration)
- [Logging](#-logging)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)
- [Support](#-support)

## ✨ Features

- **Multi-Mode Installation**: Local, bare, and DDEV containerized installations
- **Automated Updates**: Batch update WordPress core, themes, and plugins across multiple sites
- **License Management**: Secure handling of ACF Pro, WP Migrate DB Pro, and Akeeba licenses
- **Git Integration**: Automatic repository cloning and synchronization
- **Environment Detection**: Automatic detection of WSL2, DDEV, Docker, and Git Bash environments
- **Debug Management**: Easy toggle of WordPress debug modes
- **User Management**: Create and manage WordPress admin users
- **Plugin Management**: Install, copy, update, (de)activate, and remove plugins across sites (`mod plugin …`)
- **Site Config**: View/change per-site license status, git remote, and home/siteurl (`mod site …`)
- **Read-only Queries**: Inspect plugins/themes/core/status/URLs and run DB reads without changes (`webwerk get …`)
- **Security Hardening**: Automated file permissions and database security
- **Comprehensive Logging**: Detailed operation logs with timestamps
- **Accessibility Focus**: Built-in support for WCAG compliance and German localization

## 🖥️ System Requirements

### Required
- **Bash**: Version 4.0 or higher
- **WP-CLI**: Latest version recommended
- **MySQL/MariaDB**: 5.7+ or 10.0+
- **PHP**: 7.4+ (8.0+ recommended)
- **Git**: For repository cloning

### Optional
- **DDEV**: For containerized development (v1.19+)
- **Docker**: If using DDEV mode
- **Composer**: For PHP dependency management

### Supported Environments
- Linux (Ubuntu, Debian, CentOS, Fedora)
- WSL2 (Windows Subsystem for Linux)
- macOS
- Git Bash on Windows (limited support)

## 📦 Installation

### System-Wide Installation

Install `webwerk` to make it available system-wide:

```bash
# Clone the repository
cd ~/git
git clone https://github.com/webwerk/ww-wpms.git
cd ww-wpms

# Run the installation script
sudo ./install.sh

# Verify installation
webwerk --version
webwerk doctor
```

The installation script will:
1. Copy `webwerk` to `/usr/local/bin/`
2. Create symlinks for the scripts directory
3. Set proper execution permissions
4. Verify WP-CLI installation

### Manual Installation

If you prefer not to install system-wide:

```bash
# Clone the repository
git clone https://github.com/webwerk/ww-wpms.git
cd ww-wpms

# Make scripts executable
chmod +x webwerk
chmod +x scripts/**/*.sh

# Use the local webwerk script
./webwerk doctor
```

### Shell Completions

Completion files for fish, bash, and zsh are in `completions/`. Running `./install.sh` installs them automatically. To install manually:

**Fish:**
```bash
cp completions/webwerk.fish ~/.config/fish/completions/
```

**Bash** (add to `~/.bashrc`):
```bash
mkdir -p ~/.bash_completion.d
cp completions/webwerk.bash ~/.bash_completion.d/
echo 'for f in ~/.bash_completion.d/*.bash; do source "$f"; done' >> ~/.bashrc
```

**Zsh** (add to `~/.zshrc` before `compinit`):
```bash
mkdir -p ~/.local/share/zsh/completions
cp completions/_webwerk ~/.local/share/zsh/completions/
echo 'fpath=(~/.local/share/zsh/completions $fpath)' >> ~/.zshrc
# then restart shell or run:
autoload -Uz compinit && compinit
```

Completions cover all subcommands, targets (`core`, `plugins`, `plugin`, `themes`, `theme`), and flags.

### Update Existing Installation

To update an already installed webwerk:

```bash
# Navigate to the repository
cd ~/git/ww-wpms

# Pull latest changes
git pull

# Reinstall system-wide
sudo ./install.sh
```

## 🚀 Quick Start

### 1. Setup Configuration Files

**Copy the .env template:**
```bash
cp env.example .env
# Edit .env with your preferred settings
```

**Create license keys file:**
```bash
cp keys.template ~/.keys
chmod 600 ~/.keys
# Edit ~/.keys with your actual license keys
```

### 2. Basic Usage

```bash
# Install new WordPress site (local mode is default)
webwerk install --wp-title="My Accessible Site"

# Install with DDEV
webwerk install ddev

# Modify DDEV site
webwerk mod ddev -S

# Update every WordPress site in the dir (pause between each)
webwerk update -a

# Same, no prompts at all
webwerk update -A

# Manage existing sites
webwerk mod -s mysite -x on

# Check system status
webwerk doctor

# Get help for any subcommand
webwerk update -h
webwerk mod -h
webwerk install -h
```

## 📁 Project Structure

```
webwerk/
├── webwerk                          # Main dispatcher script
├── .env                            # Configuration (copy from env.example)
├── env.example                    # Configuration template
├── keys.template                   # License keys template
├── README.md                       # This file
├── completions/
│   ├── webwerk.fish               # Fish shell completions
│   ├── webwerk.bash               # Bash completions
│   └── _webwerk                   # Zsh completions
└── scripts/
    ├── install/
    │   ├── wplocalinstall.sh      # WordPress installation
    │   └── wpfunctionsinstall.sh  # Installation functions
    ├── update/
    │   └── wpupdate.sh           # Update management
    ├── mod/
    │   └── wpmod.sh              # Site modification (writes)
    ├── get/
    │   └── wpget.sh              # Read-only retrieval/query
    └── utils/
        └── wphelpfunctions.sh    # Shared helper functions
```

## ⚙️ Configuration

### Main Configuration (.env)

All default values are stored in `.env`. Key settings:

```bash
# Database
DB_HOST=localhost
DB_USER=wordpress
DB_PASSWORD=your_secure_password

# WordPress
WP_ADMIN_USER=admin
WP_ADMIN_EMAIL=your@email.com
WP_LOCALE=de_DE

# Git
GIT_USER=your_github_username
GIT_PROTOCOL=ssh
GIT_SSH_HOST=arbeit  # SSH host alias from ~/.ssh/config (optional)

# Development
# Base URL for local installs — WordPress siteurl will be: LOCAL_URL_BASE/<dirname>
# Must match an existing nginx/apache vhost with PHP-FPM support.
LOCAL_URL_BASE=netcup.local
DISABLE_SEARCH_INDEXING=true
```

### License Keys (~/.keys)

**Keep this file private and out of version control!**

```bash
# Plugin licenses
ACF_PRO_LICENSE=your_acf_license
WPMDB_LICENCE=your_migrate_db_license
AKEEBA_DOWNLOAD_ID=your_akeeba_id
```

## 🎯 Installation Modes

### Local Installation
Complete WordPress setup with repository cloning (the default mode):
```bash
webwerk install --wp-title="Accessible Website"
# or explicitly:
webwerk install local --wp-title="Accessible Website"
```

Features:
- ✅ WordPress core download
- ✅ Database creation
- ✅ Admin user setup
- ✅ Repository cloning into `wp-content` (`.git` kept — stays a working clone)
- ✅ Plugin activation
- ✅ License key setup
- ✅ .htaccess configuration
- ✅ Search engine indexing disabled
- ✅ File permissions setup
- ✅ Single-line progress bar (default on a terminal; `-v`/`--verbose` for full log)

### Bare Installation
WordPress without repository:
```bash
webwerk install bare --wp-title="Simple Site"
```

Features:
- ✅ WordPress core download
- ✅ Database creation
- ✅ Admin user setup
- ✅ .htaccess configuration
- ❌ No repository cloning
- ❌ No plugin setup

### DDEV Installation
Containerized development with DDEV:
```bash
webwerk install ddev --wp-title="DDEV Site"
```

Features:
- ✅ DDEV container setup
- ✅ WordPress installation in container
- ✅ Database in container
- ✅ Repository cloning
- ✅ Plugin activation
- ✅ Accessible via `sitename.ddev.site`

## 🛠️ Command Reference

### Command Grammar

```
webwerk VERB [MODE] [WHAT] [OPTIONS]
  VERB = install | update | mod | get | remove | status
  MODE = local (default) | bare | ddev
  WHAT = the verb's object/scope, where it has one:
           get    plugins | themes | core | status | brief | git | url | db
           update plugins | plugin <name> | themes | theme <name> | core
           mod    theme [webwerk|NAME|NUM]
                  plugin <install|copy|update|activate|deactivate|remove|list> [NAME]
                  site   <license|remote|url> [show|set|add …]
                  config <debug|errors|indexing|https|htaccess> [on|off|…]
                  branch [merge [NAME]]        # overview / merge current → NAME (live)
                  user   [add NAME [--role R] [--pass P] [--email E]]

# Verbs and modes accept any unambiguous abbreviation:
#   i->install  u->update  m->mod  g->get  r->remove  s->status
#   l->local    b->bare     d->ddev
# (the old 'full'/'minimal'/'wp' names are gone; use local/bare)

# Any command also takes 'help': webwerk help, webwerk <verb> help,
# and per-target/-WHAT: webwerk get themes help, webwerk mod site help
```

### Installation Commands

```bash
# Local install (default)
webwerk install --wp-title="My Site"
webwerk install local --wp-title="My Site"

# Bare install (no repo, no plugins)
webwerk install bare --wp-title="Simple Site"

# DDEV install
webwerk install ddev --wp-title="DDEV Site"
webwerk install ddev -G arbeit          # with SSH host alias for repo cloning
webwerk install ddev -n                 # use nip.io (no /etc/hosts admin rights needed)

# Batch: install into every empty subdirectory of the current dir
# (dir name = site/repo name; non-empty dirs are skipped, never overwritten)
cd ~/www/repos/netcup
webwerk install -A -G arbeit            # all empty subdirs, non-interactive
webwerk install -a -G arbeit            # prompt y/n/x per subdir

# Custom database settings (long form or short aliases)
webwerk install --db-host=127.0.0.1 --db-user=custom --db-password=secret
webwerk install -H 127.0.0.1 -U custom -P secret

# Short aliases also exist for the other options, e.g.
webwerk install -t "My Site" -u https://example.test -w /usr/local/bin/wp -d /path/to/dir

# SSH repository cloning
webwerk install -G arbeit               # SSH host alias from ~/.ssh/config
webwerk install -p ssh                  # -p = --git-protocol

# Override base URL (WordPress siteurl = <base>/<dirname>)
webwerk install -G arbeit -b netcup.local

# Activate the site theme after cloning
webwerk install -G arbeit -T               # auto-detect the theme
webwerk install -G arbeit --theme=webwerk  # activate a specific theme

# Show the full install log instead of the progress bar
webwerk install -G arbeit -v
webwerk install -G arbeit --verbose

# Show help
webwerk install -h
```

When run in a terminal, `webwerk install` shows a single-line progress bar
(`[bar] xx% (n/11) | current activity`); errors and warnings break out on their
own line. Use `-v`/`--verbose` (or `--debug`) for the full log. When the output is
piped or redirected, the full log is used automatically. The cloned `wp-content`
keeps its `.git`, so it stays a working git clone (use `webwerk get git` to inspect).

`-A`/`-a` run a **batch install** over the immediate subdirectories of the current
directory: each empty subdir is installed (its name becomes the site/repo name),
non-empty subdirs are skipped with a warning so existing installs are never
overwritten. `-A` is non-interactive; `-a` prompts `y`/`n`/`x` per directory.

`-T`/`--theme` activates the site theme after the repo is cloned. With no value it
**auto-detects**, trying these names in order and activating the first one installed:
the agency theme `webwerk`, then the install dir name, then the dir name with a
trailing `-suffix` stripped (e.g. `acme-relaunch` → `acme`). Pass `--theme=NAME` to
activate a specific theme instead. If nothing matches and the install is interactive
(not a batch install), it lists the installed themes and prompts you to pick one by
number or name (Enter skips). A miss only warns; it never fails the install.

Most long install options also have short aliases: `-H`/`-U`/`-P`/`-N` (database),
`-u` `--wp-url`, `-t` `--wp-title`, `-e` `--wp-admin-email`, `-r` `--repo-url`,
`-g` `--git-user`, `-p` `--git-protocol`, `-w` `--wp-cli`, `-d` `--target-dir`,
`-X` `--production`, `-m` `--multisite`, `-s` `--subdomains`, `-T` `--theme` (plus
existing `-b`, `-G`, `-n`, `-v`). The admin options have no single-letter short (since `-a`/`-A` are batch),
but accept the shorter aliases `--wpu` (user), `--wpp` (pass), `--wpe` (email).

### Update Commands

Default updates core + plugins + themes. Short alias: `webwerk u`. Combined short flags supported (e.g. `-ASp`).

```bash
# No selection: discover every site in the base dir and ask y/n/x before each
# (y = update, n = skip, x = abort), under a '== [N/total] site ==' header
webwerk update

# Update every site, pausing after each (any key = next, x = exit)
webwerk update -a          # --all / --all-sites are aliases

# Update every site, no pause and no prompts (fully automatic)
webwerk update -A          # same as -ay

# List every site numbered, then update the ones you pick (e.g. 1,2,4,11),
# pausing after each
webwerk update -l

# Batch: all sites, no pause, compact output
webwerk update -B

# Quiet: one status line per site, updated in place — [1/35] alpha (55%),
# where the percent is how far through that site's steps. Rest goes to the log
webwerk update -q

# Verbose: the detailed per-section output plus wp's own messages (downloads,
# update steps), streamed under a pinned [1/35] [####----] alpha · core (55%) bar
webwerk update -v

# Update specific target only (-A already runs unattended, no need for -y)
webwerk update core -A            # core only
webwerk update plugins -A         # all plugins
webwerk update plugin woocommerce -A  # one plugin
webwerk update themes -A          # all themes
webwerk update theme twentyfour -A    # one theme

# Update specific sites
webwerk update -s site1,site2

# Patch-level only (e.g. 8.1.1 → 8.1.2)
webwerk update -Am

# Skip core update
webwerk update -Ac

# Git commits in wp-content: -g = one commit per plugin, -S/--sum = one
# summary commit covering all plugins AND themes for the site
webwerk update -Ag                # a commit per plugin
webwerk update -AS                # single summary commit

# Push happens ONLY with -p — there is no push prompt. Without -p the run
# commits locally and prints a quiet "· not pushed (use -p)" hint.
webwerk update -AS                # commit only, not pushed
webwerk update -ASp               # commit + push
webwerk update -AP                # push selected sites, no update (-P = push-only)
webwerk update -s site1,site2 -P  # push specific sites

# Exclude specific plugins
webwerk update -A -x plugin1,plugin2

# Show all options
webwerk update -h
```

Output per site is a clean, aligned summary (wp-cli's own output goes to the
log file; add `-v`/`--verbose` to also stream it under each section, or `-q`/
`--quiet` for just a one-line-per-site progress indicator):

```
== [1/35] alpha ==
▸ core     up to date (6.4.1)
▸ repo     pulled
▸ plugins
    akismet      5.1 → 5.2
    woocommerce  8.3 → 8.4
▸ themes
    twentytwentyfour  1.0 → 1.1
  ✓ committed  8a21a27  update 2 plugins, 1 theme
  · not pushed (use -p)
```

With `-q` the whole run collapses to one line per site, rewritten in place; the
percent is how far through that site's steps (core → plugins → themes → commit):

```
[35/35] omega (100%)
```

With `-v` you get the summary above *plus* wp-cli's own output, streamed dim and
indented under each section, with the progress bar pinned underneath:

```
[1/35] [##########----------] alpha · core (50%)
    Downloading update from https://wordpress.org/wordpress-6.5.zip...
    Unpacking the update...
▸ core     updated 6.4.1 → 6.5
```

Display modes are mutually exclusive; when more than one is given the precedence
is `-B` (compact) > `-q`/`-v` > the default detailed view.

There are no per-item confirmation prompts: bare `update` asks once per site
(y/n/x), `-a` pauses between sites so you can review, and `-A`/`-ay`/`-B` run
unattended.

### Management Commands

```bash
# Enable debug mode
./webwerk mod --sites=mysite --enable-debug

# Add ACF Pro license
./webwerk mod --sites=mysite --setup-acf-license

# Create new admin user
./webwerk mod --sites=mysite --new-user --wp-user=newadmin --wp-password=securepass

# Copy plugins between sites
./webwerk mod --copy-plugins=/path/to/plugin --sites=site1,site2

# Update repository
./webwerk mod --sites=mysite --git-pull

# Force HTTPS on site
./webwerk mod --sites=mysite --force-https

# Activate a theme (WHAT form). No arg lists & prompts; 'webwerk' activates the
# webwerk theme (skips if active, picks one if missing); NAME|NUM activates it.
./webwerk mod --sites=mysite theme webwerk
./webwerk mod --sites=mysite theme            # list & pick interactively
./webwerk mod --sites=mysite theme astra      # activate a named theme
# -W abbreviates the word 'webwerk'; -T NUM|NAME also activates
./webwerk mod --sites=mysite theme -W

# Plugin actions (WHAT form): install/copy/update wrap -i/-y/-u;
# activate/deactivate/remove are new; list forwards to 'get plugins'
./webwerk mod --sites=mysite plugin install wordpress-seo
./webwerk mod --sites=mysite plugin update all
./webwerk mod --sites=mysite plugin activate akismet
./webwerk mod --sites=mysite plugin deactivate hello-dolly
./webwerk mod --sites=mysite plugin remove hello-dolly
./webwerk mod --sites=mysite plugin copy /path/to/plugin

# Site config (WHAT form): view with no sub-action, change with set/add.
# (-s/-a/-A may appear anywhere; they're applied before the action)
./webwerk mod -s mysite site license               # is ACF/WP-Migrate/Akeeba applied?
./webwerk mod -s mysite site license --values      # also reveal the configured keys
./webwerk mod -s mysite site license set acf       # apply a license (acf|wpmdb|akeeba|all)
./webwerk mod -s mysite site remote                # show the wp-content git remote
./webwerk mod -s mysite site remote set URL        # set origin (omit URL to edit inline)
./webwerk mod -s mysite site remote add backup URL # add a named remote
./webwerk mod -s mysite site url                   # show home + siteurl
./webwerk mod -s mysite site url set home URL      # set home (or: siteurl | both)

# WordPress config toggles (WHAT form): view with no sub-action, change with a value
./webwerk mod -s mysite config                     # show debug/indexing/https state
./webwerk mod -s mysite config debug on            # WP_DEBUG on|off   (= -x)
./webwerk mod -s mysite config errors show         # show|hide PHP errors (hide = -z)
./webwerk mod -s mysite config indexing off        # search-engine indexing (off = -r)
./webwerk mod -s mysite config https               # force HTTPS       (= -S)

# Git branches (WHAT form): overview + merge into the live branch.
# 'branch' fetches, then shows current branch, tracking, ahead/behind, status.
# 'branch merge [NAME]' merges the current branch into NAME (default: live),
# switches back afterwards and never pushes; dirty trees, detached HEADs and
# missing target branches are skipped, conflicting merges are aborted.
./webwerk mod -A branch                            # overview of every site
./webwerk mod -s mysite branch merge               # merge current -> live
./webwerk mod -A branch merge staging              # merge current -> staging

# Users (WHAT form)
./webwerk mod -s mysite user                       # list users per site
./webwerk mod -s mysite user add jane --role editor --email jane@x.test
./webwerk mod -s mysite user add bob               # role defaults to admin, random pass

# Select all sites without interactive prompts
./webwerk mod -A --update all

# Health check — verify wp core is-installed for every site
./webwerk mod -H
```

> **Read vs. write:** `mod` is for *changing* sites. Read-only inspection
> (status, lists, URLs, db queries) lives in `webwerk get` — see below. The old
> `mod` read flags (`-C`/`-B`/`-e`/`-O`/`-l`/`-g`) have been **removed**; use the
> `webwerk get` equivalents. (`mod -T [NUM|NAME]` still lists/activates themes.)

### Get Commands (read-only)

`webwerk get <what>` retrieves information from sites without changing anything.
All targets accept `-s site1,site2` / `-a` selection (default: every site under
the base dir).

```bash
# List plugins / themes per site (--format table|csv|json|count|yaml)
./webwerk get plugins
./webwerk get themes -s acme --format json

# Core version (+ available update) per site
./webwerk get core

# Full per-site status (core + plugins + themes)
./webwerk get status

# Brief overview: core version + plugin/theme update counts
./webwerk get brief
./webwerk get brief --errors      # only broken sites
./webwerk get brief --outdated    # only sites with updates

# Git overview of each wp-content repo (remote, branch/upstream, dirty count)
./webwerk get git

# Site URLs (siteurl / home) per site
./webwerk get url

# Run a read query per site (warns, but proceeds, on non-SELECT statements)
./webwerk get db "SELECT post_title FROM wp_posts LIMIT 5" -s acme
```

### Remove Commands (destructive)

`webwerk remove` drops the database **and** deletes the site files. `local` is the
default mode, so the mode word is optional. It only acts on real WordPress installs,
refuses protected paths (`/`, `$HOME`), and confirms per site unless `-A`/`-y`.

```bash
# Remove the WP site in the current dir (local is the default; prompts to confirm)
./webwerk remove
./webwerk remove local            # explicit, same as above

# Remove specific / all sites under the base dir
./webwerk remove -s acme          # the 'acme' site
./webwerk remove -A               # every WP site under the base dir, no prompt

# Remove the DDEV containers + configuration here
./webwerk remove ddev
```

## 🏗️ Architecture

### Core Components

The Webwerk WordPress Management Suite follows a modular architecture with clear separation of concerns:

#### Main Dispatcher (`webwerk`)
- Entry point for all operations
- Command routing and parsing
- Configuration loading and validation
- Environment detection
- Logging setup

#### Script Modules

**Installation Module** (`scripts/install/`)
- `wplocalinstall.sh`: Main WordPress installation engine
- `wpfunctionsinstall.sh`: Installation-specific functions
- Handles local, bare, and DDEV installation modes
- Repository cloning and plugin activation
- Database creation and WordPress configuration

**Update Module** (`scripts/update/`)
- `wpupdate.sh`: Update management system
- Batch update WordPress core, themes, and plugins
- Git integration for version control
- Backup creation before updates
- Rollback functionality

**Modification Module** (`scripts/mod/`)
- `wpmod.sh`: Site modification and management tools
- Debug mode toggling
- User creation and management
- License key setup
- Plugin copying and activation

**Utilities Module** (`scripts/utils/`)
- `wphelpfunctions.sh`: 850+ lines of shared functions
- Site discovery and WordPress detection
- Database operations
- Git integration
- File permission management
- Logging utilities

### Key Functions

**Site Discovery** (`wphelpfunctions.sh`)
```bash
searchwp()               # Find WordPress installations
process_sites()          # Process multiple sites in batch (interactive)
process_sites_all()      # Process all sites non-interactively (no prompts)
process_dirs()           # Process comma-separated site list
```

**Plugin Management**
```bash
wp_update()          # Update WordPress core and plugins
copy_plugins()       # Copy plugins between sites
install_plugins()    # Install and activate plugins
```

**License Management**
```bash
wp_setup_all_licenses()  # Setup all license keys
wp_key_acf_pro()         # Configure ACF Pro license
wp_key_migrate()         # Configure WP Migrate DB license
```

**User Management**
```bash
wp_new_user()        # Create new WordPress admin user
wp_rights()          # Set correct file permissions
```

**Debug Control**
```bash
wp_debug()           # Enable/disable debug mode (on/off)
wp_hide_errors()     # Suppress error display in wp-config.php
wp_force_https()     # Enforce HTTPS and update siteurl/home
```

**Git Integration**
```bash
update_repo()        # Pull latest changes in wp-content
git_wp()             # Git operations for WordPress (pull/log)
```

**SEO Management**
```bash
wp_block_se()        # Disable search engine indexing
wp_enable_se()       # Enable search engine indexing
```

### Configuration System

The suite uses a hierarchical configuration approach:

1. **Environment Variables**: Highest priority
2. **`.env` File**: Project-specific configuration
3. **`~/.keys` File**: Sensitive license keys
4. **Script Defaults**: Fallback values

Configuration is loaded in `webwerk:1` and propagated to all child scripts.

### Data Flow

```
User Command → webwerk (Dispatcher)
    ↓
Parse Arguments & Load Config
    ↓
Environment Detection (WSL/DDEV/Docker)
    ↓
Route to Appropriate Module
    ↓
Load Utility Functions (wphelpfunctions.sh)
    ↓
Execute Operations with Logging
    ↓
Return Status & Log Results
```

### Error Handling

- Exit on error (`set -e`)
- Undefined variable detection (`set -u`)
- Pipeline failure detection (`set -o pipefail`)
- Comprehensive error logging
- User-friendly error messages

### Logging System

All operations are logged with structured format:
```
[TIMESTAMP] [LEVEL] [FUNCTION] Message
```

Levels: `INFO`, `WARNING`, `ERROR`, `SUCCESS`, `DEBUG`

Logs are written to:
- `webwerk.log` - General operations
- `webwerk-install.log` - Installation-specific
- `webwerk-update.log` - Update operations

## 🔒 Security Features

### License Key Management
- License keys stored in `~/.keys` (outside repository)
- Automatic setup during installation
- Support for ACF Pro, WP Migrate DB Pro, Akeeba Backup

### Database Security
- Secure password generation
- Connection validation
- Proper user permissions

### File Permissions
- Automatic permission setting
- Web server user configuration
- Upload directory security

## ♿ Accessibility (Barrierefreiheit) Focus

This suite is designed for agencies focusing on web accessibility:

### Built-in Accessibility Features
- German locale by default (`de_DE`)
- WCAG compliance level configuration
- Accessibility plugin integration
- Screen reader friendly logging output

### Recommended Workflow
1. Install WordPress with accessibility theme
2. Clone repository with accessibility plugins
3. Configure WCAG compliance level
4. Test with accessibility tools

## 🐳 DDEV Integration

Full DDEV support for containerized development:

### DDEV Features
- Automatic project configuration
- Container-based database
- SSL certificates
- MailHog email testing
- XDebug integration

### DDEV Commands
```bash
# Install DDEV site
webwerk install ddev                        # standard install
webwerk install ddev -G arbeit             # with SSH host for repo cloning
webwerk install ddev -n                    # use nip.io (no /etc/hosts admin rights)
webwerk install ddev -W                    # also add entry to Windows hosts file

# Access site
open https://mysite.ddev.site

# Modify DDEV site (runs wp commands inside container)
webwerk mod ddev -S                        # force HTTPS
webwerk mod ddev -x on                    # enable debug mode
webwerk mod ddev -f                       # setup ACF Pro license
webwerk mod ddev -h                       # show all mod options

# Update DDEV site plugins
webwerk update ddev                        # update all plugins (core by default)
webwerk update ddev -c                     # skip core, plugins only
webwerk update ddev -A                     # auto all, no prompts
webwerk update ddev -h                    # show all update options

# WP-CLI in container
ddev wp --info

# Database access
ddev mysql
```

## 🔧 Advanced Configuration

### Environment Detection
The suite automatically detects:
- WSL2 environments
- DDEV containers
- Docker environments
- Git Bash on Windows

### Custom Overrides
Add environment-specific settings to `.env`:

```bash
# WSL2 specific settings
if [[ "$(uname -a)" =~ WSL ]]; then
    DB_HOST=127.0.0.1
    LOCAL_URL_BASE=localhost/repos
fi

# Production overrides
if [[ "${ENVIRONMENT:-}" == "production" ]]; then
    WP_DEBUG_DEFAULT=false
    DISABLE_SEARCH_INDEXING=false
    FORCE_SSL=true
fi
```

## 📝 Logging

All operations are logged with timestamps:

```bash
# View recent logs
tail -f webwerk.log

# View installation logs
tail -f webwerk-install.log

# Search logs
grep "ERROR" webwerk.log
```

Log levels: `INFO`, `WARNING`, `ERROR`, `SUCCESS`

## 📚 Usage Examples

### Example 1: Setting Up a New Accessible Website

```bash
# 1. Install WordPress with full setup
webwerk install --wp-title="Accessible Company Website"

# 2. Enable debug mode for development
webwerk mod -s accessible-company -x on

# 3. Setup license keys for premium plugins
webwerk mod -s accessible-company -f

# 4. Create additional admin user
webwerk mod -s accessible-company -n -U webmaster -P SecurePass123
```

### Example 2: Batch Update Multiple Sites

```bash
# Update all sites, pause between each to review output (core+plugins+themes)
webwerk update -a

# Same, no prompts (unattended)
webwerk update -A

# Update only plugins across all sites
webwerk update plugins -A

# Update one plugin across all sites
webwerk update plugin woocommerce -A

# Auto update all, one summary commit per site, review, then push separately
webwerk update -AS              # commits only (not pushed)
webwerk update -AP              # push when ready

# Commit and push in one go
webwerk update -ASp

# Patch-level only, exclude specific plugins
webwerk update -Am -x woocommerce,elementor
```

### Example 3: DDEV Development Workflow

```bash
# 1. Create DDEV site
webwerk install ddev --wp-title="Development Site"

# 2. Access the site
open https://development-site.ddev.site

# 3. Run WP-CLI commands in container
ddev wp plugin list
ddev wp theme list

# 4. Import database
ddev import-db --src=backup.sql.gz

# 5. Update site
webwerk update ddev -A
```

### Example 4: Repository Management

```bash
# Clone repository during installation via SSH host alias
webwerk install -G arbeit --wp-title="Corporate Site"

# Update repository on existing site
webwerk mod -s corporate-site -gl

# DDEV install with SSH host
webwerk install ddev -G arbeit
```

### Example 5: Plugin Management

```bash
# Copy plugin to multiple sites
webwerk mod -y /path/to/custom-plugin -s site1,site2,site3

# Install and activate specific plugin
webwerk mod -s mysite -i acf-pro
```

## 💡 Best Practices

### Configuration Management
1. **Always use `.env` file**: Don't hardcode configuration values
2. **Keep `.keys` secure**: Set permissions to `600` (owner read/write only)
3. **Use separate configs**: Different `.env` for development/production
4. **Version control**: Add `env.example` but exclude `.env`

### Security
1. **Strong passwords**: Use generated passwords for database and admin users
2. **Regular updates**: Schedule weekly update checks
3. **License keys**: Never commit license keys to version control
4. **File permissions**: Let webwerk handle permissions automatically
5. **Debug mode**: Disable debug mode in production environments

### Development Workflow
1. **Use DDEV locally**: Containerized environment for consistent development
2. **Version control**: Commit after major changes
3. **Test updates**: Test updates on staging before production
4. **Backup first**: Always backup before major operations
5. **Log review**: Check logs regularly for errors or warnings

### Multi-Site Management
1. **Batch operations**: Use `-A` (unattended) or `-a` (pause to review) for consistent updates
2. **Site naming**: Use consistent naming conventions
3. **Documentation**: Document custom configurations in site-specific notes
4. **Staging first**: Test on staging sites before applying to production

### Performance
1. **Exclude unnecessary plugins**: Use `--exclude-plugins` for site-specific needs
2. **Minor updates**: Use `--minor` flag for safer, incremental updates
3. **Git integration**: Use `-S` (one summary commit) or `-g` (per-plugin), add `-p` to push
4. **Cleanup**: Remove unused plugins and themes regularly

## 🔄 Automation

### Cron Jobs

Automate regular maintenance with cron:

```bash
# Edit crontab
crontab -e

# Update all sites weekly (Sunday 2 AM): unattended, summary commit + push
0 2 * * 0 /usr/local/bin/webwerk update -ASp >> /var/log/webwerk-cron.log 2>&1

# Daily backup at midnight
0 0 * * * /usr/local/bin/webwerk backup --all-sites >> /var/log/webwerk-backup.log 2>&1

# Weekly security scan (Monday 3 AM)
0 3 * * 1 /usr/local/bin/webwerk security-check --all-sites >> /var/log/webwerk-security.log 2>&1
```

### Systemd Timers

Alternative to cron using systemd:

```bash
# Create timer unit: /etc/systemd/system/webwerk-update.timer
[Unit]
Description=Weekly WordPress Update

[Timer]
OnCalendar=Sun 02:00
Persistent=true

[Install]
WantedBy=timers.target

# Create service unit: /etc/systemd/system/webwerk-update.service
[Unit]
Description=Webwerk WordPress Update

[Service]
Type=oneshot
ExecStart=/usr/local/bin/webwerk update -ASp
User=www-data

# Enable timer
sudo systemctl enable webwerk-update.timer
sudo systemctl start webwerk-update.timer
```

### CI/CD Integration

Integrate with GitHub Actions:

```yaml
name: WordPress Update
on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install webwerk
        run: sudo ./install.sh
      - name: Update WordPress (summary commit + push per site)
        run: webwerk update -ASp
```

## 🚨 Troubleshooting

### Common Issues

**WP-CLI not found:**
```bash
# Update WP_CLI_PATH in .env
WP_CLI_PATH=/usr/local/bin/wp
```

**Database connection failed:**
```bash
# Check database settings in .env
DB_HOST=localhost
DB_USER=wordpress
DB_PASSWORD=your_password

# Test connection manually
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e "SELECT 1;"
```

**Repository clone failed:**
```bash
# Check repository URL and permissions
./webwerk install --repo-url=https://github.com/user/repo.git

# For private repos, use SSH or add token to ~/.keys
GIT_PROTOCOL=ssh
```

**License keys not working:**
```bash
# Verify ~/.keys file exists and has correct permissions
ls -la ~/.keys
chmod 600 ~/.keys

# Check license key format
cat ~/.keys
```

### Debug Mode
Enable debug output:
```bash
./webwerk debug --mode=local --wp-title="Debug Site"
```

### System Status
Check system configuration:
```bash
./webwerk doctor
```

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create feature branch
3. Update relevant scripts
4. Test with different modes
5. Update documentation
6. Submit pull request

### Coding Standards
- Use `bash` strict mode (`set -euo pipefail`)
- Add comprehensive error handling
- Include logging for all operations
- Follow shell scripting best practices
- Document all functions

### Testing
Test all modes before submitting:
```bash
# Verify help works for all subcommands
webwerk -h
webwerk install -h
webwerk update -h
webwerk mod -h
webwerk update ddev -h
webwerk mod ddev -h

# Test all installation modes
webwerk install local --wp-title="Test Full"
webwerk install bare --wp-title="Test Minimal"
webwerk install ddev --wp-title="Test DDEV"

# Test update functionality
webwerk update -s testsite

# Test management features
webwerk mod -s testsite -x on
```

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

- 📧 Email: support@webwerk.com
- 🐛 Issues: [GitHub Issues](https://github.com/webwerk/wordpress-tools/issues)
- 📖 Wiki: [GitHub Wiki](https://github.com/webwerk/wordpress-tools/wiki)
- 💬 Discussions: [GitHub Discussions](https://github.com/webwerk/wordpress-tools/discussions)

## 🙏 Acknowledgments

- WordPress community for WP-CLI
- DDEV team for containerization
- Accessibility community for guidance
- Contributors and testers

---

**Webwerk** - Making WordPress accessible for everyone! ♿✨
