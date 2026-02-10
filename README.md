# Webwerk WordPress Management Suite v2.0

A comprehensive WordPress management suite focused on **Barrierefreiheit** (Accessibility) for web agencies and developers.

## 📋 Table of Contents

- [Features](#-features)
- [System Requirements](#-system-requirements)
- [Installation](#-installation)
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

- **Multi-Mode Installation**: Full, minimal, and DDEV containerized installations
- **Automated Updates**: Batch update WordPress core, themes, and plugins across multiple sites
- **License Management**: Secure handling of ACF Pro, WP Migrate DB Pro, and Akeeba licenses
- **Git Integration**: Automatic repository cloning and synchronization
- **Environment Detection**: Automatic detection of WSL2, DDEV, Docker, and Git Bash environments
- **Debug Management**: Easy toggle of WordPress debug modes
- **User Management**: Create and manage WordPress admin users
- **Plugin Management**: Copy and activate plugins across multiple sites
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
webwerk status
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
./webwerk status
```

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
cp .env.example .env
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
# Install new WordPress site
./webwerk full install --wp-title="My Accessible Site"

# Install with DDEV
./webwerk ddev install

# Modify DDEV site
./webwerk ddev mod --force-https

# Update WordPress sites
./webwerk update --all-sites

# Manage existing sites
./webwerk mod --sites=mysite --enable-debug

# Check system status
./webwerk status
```

## 📁 Project Structure

```
webwerk/
├── webwerk                          # Main dispatcher script
├── .env                            # Configuration (copy from .env.example)
├── .env.example                    # Configuration template
├── keys.template                   # License keys template
├── README.md                       # This file
└── scripts/
    ├── install/
    │   ├── wplocalinstall.sh      # WordPress installation
    │   └── wpfunctionsinstall.sh  # Installation functions
    ├── update/
    │   └── wpupdate.sh           # Update management
    ├── mod/
    │   └── wpmod.sh              # Site modification
    └── utils/
        └── wphelpfuntions.sh     # Shared helper functions
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
LOCAL_URL_BASE=arbeit.local/repos
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

### Full Installation
Complete WordPress setup with repository cloning:
```bash
./webwerk full install --wp-title="Accessible Website"
```

Features:
- ✅ WordPress core download
- ✅ Database creation
- ✅ Admin user setup
- ✅ Repository cloning
- ✅ Plugin activation
- ✅ License key setup
- ✅ .htaccess configuration
- ✅ Search engine indexing disabled
- ✅ File permissions setup

### Minimal Installation
WordPress without repository:
```bash
./webwerk minimal install --wp-title="Simple Site"
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
./webwerk ddev install --wp-title="DDEV Site"
```

Features:
- ✅ DDEV container setup
- ✅ WordPress installation in container
- ✅ Database in container
- ✅ Repository cloning
- ✅ Plugin activation
- ✅ Accessible via `sitename.ddev.site`

## 🛠️ Command Reference

### Installation Commands

```bash
# Basic installation
./webwerk install --wp-title="My Site"

# Custom database settings
./webwerk install --db-host=127.0.0.1 --db-user=custom --db-password=secret

# Custom repository
./webwerk install --repo-url=https://github.com/user/repo.git

# SSH repository cloning with SSH host alias
./webwerk install --git-host=arbeit

# SSH repository cloning (traditional)
./webwerk install --git-protocol=ssh

# Install in specific directory
./webwerk install --target-dir=/path/to/site --wp-title="Remote Site"
```

### Update Commands

```bash
# Update all sites
./webwerk update --all-sites

# Update specific sites
./webwerk update --sites=site1,site2,site3

# Update with git commits
./webwerk update --sites=mysite --git --summary

# Minor updates only
./webwerk update --sites=mysite --minor

# Exclude specific plugins
./webwerk update --exclude-plugins=plugin1,plugin2
```

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
- Handles full, minimal, and DDEV installation modes
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
- `wphelpfunctions.sh`: 700+ lines of shared functions
- Site discovery and WordPress detection
- Database operations
- Git integration
- File permission management
- Logging utilities

### Key Functions

**Site Discovery** (`wphelpfunctions.sh`)
```bash
searchwp()           # Find WordPress installations
process_sites()      # Process multiple sites in batch
validate_wp_site()   # Verify WordPress installation
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
wp_reset_password()  # Reset user password
```

**Debug Control**
```bash
wp_debug()           # Enable/disable debug mode
wp_hide_errors()     # Control error display
wp_log_errors()      # Configure error logging
```

**Git Integration**
```bash
update_repo()        # Update repository from remote
git_wp()             # Git operations for WordPress
commit_updates()     # Commit update changes
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
./webwerk ddev install                      # Standard install (auto-adds /etc/hosts entry)
./webwerk ddev install -G arbeit            # With SSH host for repo cloning
./webwerk ddev install -n                   # Use nip.io instead of ddev.site
./webwerk ddev install -W                   # Also add entry to Windows hosts file

# Access site
open https://mysite.ddev.site

# Modify DDEV site (runs commands inside container)
./webwerk ddev mod --force-https
./webwerk ddev mod --enable-debug
./webwerk ddev mod --setup-acf-license

# Update plugins
./webwerk ddev update                       # Update all plugins
./webwerk ddev update --core                # Update core + plugins
./webwerk ddev update --plugins=x,y         # Update specific plugins
./webwerk ddev update --dry-run             # Preview updates

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
./webwerk install --mode=full --wp-title="Accessible Company Website"

# 2. Enable debug mode for development
./webwerk mod --sites=accessible-company --enable-debug

# 3. Setup license keys for premium plugins
./webwerk mod --sites=accessible-company --setup-acf-license

# 4. Create additional admin user
./webwerk mod --sites=accessible-company --new-user \
    --wp-user=webmaster --wp-password=SecurePass123
```

### Example 2: Batch Update Multiple Sites

```bash
# Update all WordPress installations in current directory
./webwerk update --all-sites --git --summary

# Update specific sites with minor updates only
./webwerk update --sites=site1,site2,site3 --minor

# Update excluding specific plugins
./webwerk update --sites=mysite \
    --exclude-plugins=woocommerce,elementor
```

### Example 3: DDEV Development Workflow

```bash
# 1. Create DDEV site
./webwerk install --mode=ddev --wp-title="Development Site"

# 2. Access the site
open https://development-site.ddev.site

# 3. Run WP-CLI commands in container
ddev wp plugin list
ddev wp theme list

# 4. Import database
ddev import-db --src=backup.sql.gz

# 5. Update site
./webwerk update --sites=development-site
```

### Example 4: Repository Management

```bash
# Clone repository during installation
./webwerk install --mode=full \
    --repo-url=https://github.com/mycompany/wp-theme.git \
    --wp-title="Corporate Site"

# Update repository on existing site
./webwerk mod --sites=corporate-site --git-pull

# Use SSH host alias for private repositories
./webwerk install --mode=full --git-host=arbeit

# Use SSH for private repositories (traditional)
./webwerk install --mode=full \
    --repo-url=git@github.com:mycompany/private-theme.git \
    --git-protocol=ssh
```

### Example 5: Plugin Management

```bash
# Copy plugins from source to multiple sites
./webwerk mod --copy-plugins=/path/to/custom-plugin \
    --sites=site1,site2,site3

# Install and activate specific plugins
./webwerk mod --sites=mysite --install-plugins=acf-pro,wp-migrate-db-pro
```

## 💡 Best Practices

### Configuration Management
1. **Always use `.env` file**: Don't hardcode configuration values
2. **Keep `.keys` secure**: Set permissions to `600` (owner read/write only)
3. **Use separate configs**: Different `.env` for development/production
4. **Version control**: Add `.env.example` but exclude `.env`

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
1. **Batch operations**: Use `--all-sites` for consistent updates
2. **Site naming**: Use consistent naming conventions
3. **Documentation**: Document custom configurations in site-specific notes
4. **Staging first**: Test on staging sites before applying to production

### Performance
1. **Exclude unnecessary plugins**: Use `--exclude-plugins` for site-specific needs
2. **Minor updates**: Use `--minor` flag for safer, incremental updates
3. **Git integration**: Use `--git` flag to track changes
4. **Cleanup**: Remove unused plugins and themes regularly

## 🔄 Automation

### Cron Jobs

Automate regular maintenance with cron:

```bash
# Edit crontab
crontab -e

# Update all sites weekly (Sunday 2 AM)
0 2 * * 0 /usr/local/bin/webwerk update --all-sites --git >> /var/log/webwerk-cron.log 2>&1

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
ExecStart=/usr/local/bin/webwerk update --all-sites --git
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
      - name: Update WordPress
        run: webwerk update --all-sites --git
      - name: Commit changes
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "Automated WordPress update" || true
          git push
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
./webwerk debug --mode=full --wp-title="Debug Site"
```

### System Status
Check system configuration:
```bash
./webwerk status
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
# Test all installation modes
./webwerk install --mode=full --wp-title="Test Full"
./webwerk install --mode=minimal --wp-title="Test Minimal"
./webwerk install --mode=ddev --wp-title="Test DDEV"

# Test update functionality
./webwerk update --sites=testsite

# Test management features
./webwerk mod --sites=testsite --enable-debug
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
