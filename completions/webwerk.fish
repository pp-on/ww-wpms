# Fish completions for webwerk WordPress Management Suite

# ── Helpers ──────────────────────────────────────────────────────────────────

function __ww_no_cmd
    not __fish_seen_subcommand_from install update mod get remove ddev status
end

function __ww_get_ctx
    __fish_seen_subcommand_from get
    and not __fish_seen_subcommand_from install update mod remove ddev
end

function __ww_get_no_target
    __ww_get_ctx
    and not __fish_seen_subcommand_from plugins themes core status brief git url db
end

function __ww_install_ctx
    __fish_seen_subcommand_from install
    and not __fish_seen_subcommand_from update mod remove ddev
end

function __ww_update_ctx
    __fish_seen_subcommand_from update
    and not __fish_seen_subcommand_from install mod remove ddev
end

function __ww_update_no_target
    __ww_update_ctx
    and not __fish_seen_subcommand_from core plugins plugin themes theme
end

function __ww_ddev_no_sub
    __fish_seen_subcommand_from ddev
    and not __fish_seen_subcommand_from install mod update remove
end

function __ww_mod_ctx
    __fish_seen_subcommand_from mod
    and not __fish_seen_subcommand_from install update remove
end

function __ww_mod_env
    __ww_mod_ctx
    and not __fish_seen_subcommand_from local ddev
end

# ── Top-level commands ────────────────────────────────────────────────────────

complete -c webwerk -f -n __ww_no_cmd -a install -d 'Install WordPress site'
complete -c webwerk -f -n __ww_no_cmd -a update  -d 'Update WordPress (core+plugins+themes)'
complete -c webwerk -f -n __ww_no_cmd -a mod     -d 'Modify/manage existing WordPress sites'
complete -c webwerk -f -n __ww_no_cmd -a get     -d 'Read-only: list plugins/themes/core, URLs, db query'
complete -c webwerk -f -n __ww_no_cmd -a remove  -d 'Remove a DDEV site'
complete -c webwerk -f -n __ww_no_cmd -a ddev    -d 'DDEV operations'
complete -c webwerk -f -n __ww_no_cmd -a status  -d 'Show configuration status'
complete -c webwerk    -n __ww_no_cmd -s h -l help  -d 'Show help'
complete -c webwerk    -n __ww_no_cmd -l debug       -d 'Enable debug mode'

# ── install: modes ────────────────────────────────────────────────────────────

complete -c webwerk -f \
    -n '__ww_install_ctx; and not __fish_seen_subcommand_from local bare ddev' \
    -a local   -d 'Local install with git repository (default)'
complete -c webwerk -f \
    -n '__ww_install_ctx; and not __fish_seen_subcommand_from local bare ddev' \
    -a bare    -d 'Bare install without git'
complete -c webwerk -f \
    -n '__ww_install_ctx; and not __fish_seen_subcommand_from local bare ddev' \
    -a ddev    -d 'DDEV containerized install'

# ── install: options ──────────────────────────────────────────────────────────

complete -c webwerk -f -n __ww_install_ctx -s A -d 'Batch: install into every empty subdirectory (non-interactive)'
complete -c webwerk -f -n __ww_install_ctx -s a -d 'Batch: prompt y/n/x per empty subdirectory'
complete -c webwerk -n __ww_install_ctx -s H -l db-host        -r -d 'Database hostname'
complete -c webwerk -n __ww_install_ctx -s U -l db-user        -r -d 'Database username'
complete -c webwerk -n __ww_install_ctx -s P -l db-password    -r -d 'Database password'
complete -c webwerk -n __ww_install_ctx -s N -l db-name        -r -d 'Database name'
complete -c webwerk -n __ww_install_ctx -s u -l wp-url         -r -d 'WordPress site URL'
complete -c webwerk -n __ww_install_ctx -s b -l base-url       -r -d 'Base URL for local dev (e.g. netcup.local)'
complete -c webwerk -n __ww_install_ctx -s t -l wp-title       -r -d 'WordPress site title'
complete -c webwerk -n __ww_install_ctx -l wp-admin-user -l wpu       -r -d 'Admin username'
complete -c webwerk -n __ww_install_ctx -l wp-admin-pass -l wpp       -r -d 'Admin password'
complete -c webwerk -n __ww_install_ctx -s e -l wp-admin-email -l wpe -r -d 'Admin email'
complete -c webwerk -n __ww_install_ctx -s T -l theme         -d 'Activate site theme after clone (auto-detect, or =NAME)'
complete -c webwerk -n __ww_install_ctx -s r -l repo-url       -r -d 'Repository URL to clone'
complete -c webwerk -n __ww_install_ctx -s g -l git-user       -r -d 'Git username'
complete -c webwerk -n __ww_install_ctx -s p -l git-protocol   -r -d 'Git protocol' -a 'https\tHTTPS ssh\tSSH'
complete -c webwerk -n __ww_install_ctx -s G -l git-host       -r -d 'SSH host alias from ~/.ssh/config'
complete -c webwerk -n __ww_install_ctx -s w -l wp-cli         -r -d 'Path to WP-CLI executable'
complete -c webwerk -n __ww_install_ctx -s d -l target-dir     -r -d 'Target installation directory'
complete -c webwerk -n __ww_install_ctx -s n -l nip-io       -d 'Use nip.io DNS (no hosts file, DDEV only)'
complete -c webwerk -n __ww_install_ctx -l lemp              -d 'Generate nginx.conf (default)'
complete -c webwerk -n __ww_install_ctx -l lamp              -d 'Generate .htaccess (LAMP stack)'
complete -c webwerk -n __ww_install_ctx -s X -l production    -d 'Add nginx security hardening'
complete -c webwerk -n __ww_install_ctx -s m -l multisite     -d 'Install as WordPress Multisite'
complete -c webwerk -n __ww_install_ctx -s s -l subdomains    -d 'Subdomain network (requires --multisite)'
complete -c webwerk -n __ww_install_ctx -s v -l verbose      -d 'Show full install log instead of the progress bar'
complete -c webwerk -n __ww_install_ctx -l debug             -d 'Enable debug mode'
complete -c webwerk -n __ww_install_ctx -s h -l help         -d 'Show help'

# ── update: targets ───────────────────────────────────────────────────────────

complete -c webwerk -f -n __ww_update_no_target -a local   -d 'Update local site (default)'
complete -c webwerk -f -n __ww_update_no_target -a ddev    -d 'Update the DDEV site here'
complete -c webwerk -f -n __ww_update_no_target -a core    -d 'Update core only'
complete -c webwerk -f -n __ww_update_no_target -a plugins -d 'Update all plugins'
complete -c webwerk -f -n __ww_update_no_target -a plugin  -d 'Update one plugin (name required)'
complete -c webwerk -f -n __ww_update_no_target -a themes  -d 'Update all themes'
complete -c webwerk -f -n __ww_update_no_target -a theme   -d 'Update one theme (name required)'

# ── update: options ───────────────────────────────────────────────────────────

complete -c webwerk -n __ww_update_ctx -s a -l all-sites      -d 'Prompt y/n/x per site'
complete -c webwerk -n __ww_update_ctx -s A -l all-sites-auto -d 'Auto all sites, pause between each (x=exit)'
complete -c webwerk -n __ww_update_ctx -s B -l batch          -d 'Auto all sites, no pause, compact output'
complete -c webwerk -n __ww_update_ctx -s V -l progress       -d 'Progress-only output, normal output goes to log file'
complete -c webwerk -n __ww_update_ctx -s s -l sites       -r  -d 'Specific sites (comma-separated)'
complete -c webwerk -n __ww_update_ctx -s y -l yes-update      -d 'Auto-confirm all updates'
complete -c webwerk -n __ww_update_ctx -s c -l skip-core       -d 'Skip core update'
complete -c webwerk -n __ww_update_ctx -s m -l minor           -d 'Patch-level only (e.g. 8.1.1 → 8.1.2)'
complete -c webwerk -n __ww_update_ctx -s g                    -d 'Git mode (commit per plugin)'
complete -c webwerk -n __ww_update_ctx -l sum                  -d 'Single summary git commit'
complete -c webwerk -n __ww_update_ctx -s p -l git-push        -d 'Push after updates'
complete -c webwerk -n __ww_update_ctx -s P -l push-only       -d 'Push only (no update)'
complete -c webwerk -n __ww_update_ctx -s x -l exclude-plugins -r -d 'Exclude plugins (comma-separated)'
complete -c webwerk -n __ww_update_ctx -s h -l help            -d 'Show help'

# ── ddev: subcommands ─────────────────────────────────────────────────────────

complete -c webwerk -f -n __ww_ddev_no_sub -a install -d 'DDEV WordPress install'
complete -c webwerk -f -n __ww_ddev_no_sub -a mod     -d 'Modify DDEV site'
complete -c webwerk -f -n __ww_ddev_no_sub -a update  -d 'Update DDEV site'
complete -c webwerk -f -n __ww_ddev_no_sub -a remove  -d 'Remove DDEV containers'

# ── remove: mode + options ────────────────────────────────────────────────────

function __ww_remove_ctx
    __fish_seen_subcommand_from remove
    and not __fish_seen_subcommand_from install update mod
end
function __ww_remove_no_mode
    __ww_remove_ctx
    and not __fish_seen_subcommand_from local ddev
end
function __ww_remove_local
    __ww_remove_ctx
    and __fish_seen_subcommand_from local
end

complete -c webwerk -f -n __ww_remove_no_mode -a local -d 'DESTRUCTIVE: drop DB + delete files of a WP site'
complete -c webwerk -f -n __ww_remove_no_mode -a ddev  -d 'Remove DDEV containers'
complete -c webwerk    -n __ww_remove_local -s s -l sites          -r -d 'Site(s) to remove (comma-separated)'
complete -c webwerk -f -n __ww_remove_local -s a -l all-sites          -d 'All sites under base dir (prompt each)'
complete -c webwerk -f -n __ww_remove_local -s A -l all-sites-auto     -d 'All sites under base dir (no prompt)'
complete -c webwerk -f -n __ww_remove_local -s y -l yes                -d 'Skip the confirmation prompt'

# ── mod: environment target (local default / ddev) ────────────────────────────

complete -c webwerk -f -n __ww_mod_env -a local -d 'Modify local WordPress sites (default)'
complete -c webwerk -f -n __ww_mod_env -a ddev  -d 'Modify DDEV WordPress site'

# ── mod: options ──────────────────────────────────────────────────────────────

complete -c webwerk -n __ww_mod_ctx -s a -l all-sites                      -d 'Process all sites (interactive)'
complete -c webwerk -n __ww_mod_ctx -s A -l all-sites-auto                 -d 'Process all sites (non-interactive)'
complete -c webwerk -n __ww_mod_ctx -s s -l sites                       -r  -d 'Specific sites (comma-separated)'
complete -c webwerk -n __ww_mod_ctx -s d -l original-dir                -r  -d 'Set base directory'
complete -c webwerk -n __ww_mod_ctx -s p -l print                          -d 'Print selected sites'
complete -c webwerk -n __ww_mod_ctx -s H -l health-check                   -d 'Check sites with wp core is-installed'
complete -c webwerk -n __ww_mod_ctx -s C -l status                         -d 'Per-site status: core version, plugins, themes'
complete -c webwerk -n __ww_mod_ctx -s B -l brief                          -d 'Brief status: core + plugin/theme update counts (all sites)'
complete -c webwerk -n __ww_mod_ctx -s e -l errors                         -d 'Brief status, only sites with errors (broken/missing)'
complete -c webwerk -n __ww_mod_ctx -s O -l outdated                       -d 'Brief status, only sites with available updates'
complete -c webwerk -n __ww_mod_ctx -s l -l list                           -d 'List plugins for selected sites'
complete -c webwerk -n __ww_mod_ctx -s T -l themes                         -d 'List themes (optionally activate by number/name)'
complete -c webwerk -n __ww_mod_ctx -s W -l theme-webwerk                   -d "Activate 'webwerk' theme (skip if active; else pick one)"
complete -c webwerk -f -n '__ww_mod_env; and not __fish_seen_subcommand_from theme plugin site config user' -a site -d 'Site config: site <license|remote|url> [show|set|add]'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from site; and not __fish_seen_subcommand_from license remote url' -a 'license remote url' -d 'site config target'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from license; and not __fish_seen_subcommand_from show set' -a 'show set' -d 'license action'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from license; and __fish_seen_subcommand_from set' -a 'acf wpmdb akeeba all' -d 'license to apply'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from remote; and not __fish_seen_subcommand_from show add set' -a 'show add set' -d 'remote action'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from url; and not __fish_seen_subcommand_from show set' -a 'show set' -d 'url action'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from url; and __fish_seen_subcommand_from set' -a 'home siteurl both' -d 'which url'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from theme plugin site config user' -a help -d 'Show help for this WHAT'
complete -c webwerk -f -n '__ww_mod_env; and not __fish_seen_subcommand_from theme plugin site config user' -a theme -d 'Activate a theme: theme [webwerk|NAME|NUM]'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from theme' -a webwerk -d 'Activate the webwerk theme'
complete -c webwerk -f -n '__ww_mod_env; and not __fish_seen_subcommand_from theme plugin site config user' -a plugin -d 'Plugin actions: plugin <install|copy|update|activate|deactivate|remove|list>'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from plugin; and not __fish_seen_subcommand_from install copy update activate deactivate remove list' -a 'install copy update activate deactivate remove list' -d 'plugin action'
complete -c webwerk -f -n '__ww_mod_env; and not __fish_seen_subcommand_from theme plugin site config user' -a config -d 'WP toggles: config <debug|errors|indexing|https|htaccess>'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from config; and not __fish_seen_subcommand_from debug errors indexing https htaccess' -a 'debug errors indexing https htaccess' -d 'config toggle'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from debug indexing; and not __fish_seen_subcommand_from on off' -a 'on off' -d 'state'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from errors; and not __fish_seen_subcommand_from hide show' -a 'hide show' -d 'errors display'
complete -c webwerk -f -n '__ww_mod_env; and not __fish_seen_subcommand_from theme plugin site config user' -a user -d 'Users: user [add NAME --role ... --pass ... --email ...]'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from user; and not __fish_seen_subcommand_from add' -a add -d 'add a user'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from user add' -l role -r -a 'admin editor author contributor subscriber' -d 'role (admin default)'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from user add' -l pass -r -d 'password'
complete -c webwerk -f -n '__ww_mod_ctx; and __fish_seen_subcommand_from user add' -l email -r -d 'email'
complete -c webwerk -n __ww_mod_ctx -s o -l os-detection                   -d 'Show OS information'
complete -c webwerk -n __ww_mod_ctx -l git                              -r  -d 'Run git subcommand' -a 'pull\tpull log\tlog'
complete -c webwerk -n __ww_mod_ctx -s G -l git-pull                       -d 'Update repos via git pull'
complete -c webwerk -n __ww_mod_ctx -s g -l git-status                     -d 'Overview of each wp-content git repo (remote, branch, status)'
complete -c webwerk -n __ww_mod_ctx -s u -l update                      -r  -d 'Update plugin (or all)'
complete -c webwerk -n __ww_mod_ctx -s i -l install-plugin              -r  -d 'Install plugin on selected sites'
complete -c webwerk -n __ww_mod_ctx -s y -l copy-plugins                -r  -d 'Copy plugin from path to selected sites'
complete -c webwerk -n __ww_mod_ctx -s f -l acf-pro-lk                     -d 'Setup ACF Pro license key'
complete -c webwerk -n __ww_mod_ctx -s m -l wp-migrate-db-pro              -d 'Setup WP Migrate DB Pro license key'
complete -c webwerk -n __ww_mod_ctx -s k -l akeeba-license                  -d 'Setup Akeeba Download ID'
complete -c webwerk -n __ww_mod_ctx -l setup-all-licenses                  -d 'Setup all available license keys'
complete -c webwerk -n __ww_mod_ctx -s n -l new-user                       -d 'Create new admin user'
complete -c webwerk -n __ww_mod_ctx -s U -l wp-user                    -r  -d 'Username for new user'
complete -c webwerk -n __ww_mod_ctx -s P -l wp-password                -r  -d 'Password for new user'
complete -c webwerk -n __ww_mod_ctx -s E -l wp-email                   -r  -d 'Email for new user'
complete -c webwerk -n __ww_mod_ctx -s R -l search-replace             -r  -d 'Run wp search-replace (OLD NEW)'
complete -c webwerk -n __ww_mod_ctx -s x -l wp-debug                   -r  -d 'Enable/disable debug mode' -a 'on\tEnable off\tDisable'
complete -c webwerk -n __ww_mod_ctx -s z -l hide-errors                    -d 'Hide WordPress errors'
complete -c webwerk -n __ww_mod_ctx -s r -l disable-search-engine-indexing -d 'Disable search engine indexing'
complete -c webwerk -n __ww_mod_ctx -l enable-search-engine-indexing        -d 'Enable search engine indexing'
complete -c webwerk -n __ww_mod_ctx -l htaccess                            -d 'Create/update .htaccess file'
complete -c webwerk -n __ww_mod_ctx -s S -l force-https                    -d 'Force HTTPS'
complete -c webwerk -n __ww_mod_ctx -s w -l location-wp                -r  -d 'Set WP-CLI path'
complete -c webwerk -n __ww_mod_ctx -s h -l help                           -d 'Show help'

# ── get: read-only retrieval ──────────────────────────────────────────────────
complete -c webwerk -f -n __ww_get_no_target -a plugins -d 'List plugins per site'
complete -c webwerk -f -n __ww_get_no_target -a themes  -d 'List themes per site'
complete -c webwerk -f -n __ww_get_no_target -a core    -d 'Core version (+update) per site'
complete -c webwerk -f -n __ww_get_no_target -a status  -d 'Full per-site status'
complete -c webwerk -f -n __ww_get_no_target -a brief   -d 'Brief: core + plugin/theme update counts'
complete -c webwerk -f -n __ww_get_no_target -a git     -d 'Git overview of each wp-content repo'
complete -c webwerk -f -n __ww_get_no_target -a url     -d 'siteurl / home per site'
complete -c webwerk -f -n __ww_get_no_target -a db      -d 'Run a query per site (warns on non-SELECT)'
complete -c webwerk -n __ww_get_ctx -s s -l sites    -r -d 'Comma-separated site names'
complete -c webwerk -n __ww_get_ctx -s a -l all-sites   -d 'All sites under the base dir'
complete -c webwerk -n __ww_get_ctx -l format        -r -d 'Output format (table|csv|json|count|yaml)'
complete -c webwerk -n __ww_get_ctx -l errors           -d 'brief: only broken sites'
complete -c webwerk -n __ww_get_ctx -l outdated         -d 'brief: only sites with updates'
complete -c webwerk -n __ww_get_ctx -s h -l help        -d 'Show help'
complete -c webwerk -f -n __ww_get_ctx -a help          -d 'Show help (per-target after a target word)'
