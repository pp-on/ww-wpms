# Fish completions for webwerk WordPress Management Suite

# ── Helpers ──────────────────────────────────────────────────────────────────

# Resolve TOKEN against WORDS like the dispatcher's resolve_word:
# exact match wins, else a unique prefix (u -> update, doc -> doctor).
function __ww_resolve
    set -l tok $argv[1]
    set -l words $argv[2..-1]
    if contains -- $tok $words
        echo $tok
        return 0
    end
    set -l m (string match -- "$tok*" $words)
    test (count $m) -eq 1; and echo $m[1]
end

# Print the verb on the command line, with abbreviations resolved.
# Fails if no verb has been given yet.
function __ww_verb
    set -l verbs install update set get remove doctor
    set -l toks
    for tok in (commandline -opc)[2..-1]
        string match -q -- '-*' $tok; or set -a toks $tok
    end
    set -q toks[1]; or return 1
    __ww_resolve $toks[1] $verbs
end

function __ww_is_verb
    set -l v (__ww_verb); or return 1
    contains -- $v $argv
end

# True when the previous word is exactly ARGV[1] (e.g. right after 'plugin')
function __ww_after_word
    set -l toks (commandline -opc)
    test "$toks[-1]" = "$argv[1]"
end

# Site dirs (containing wp-content/) under the current dir; comma lists ok
function __ww_site_names
    set -l prefix (string replace -r '[^,]*$' '' -- (commandline -ct))
    for d in */
        if test -d "$d"wp-content
            echo "$prefix"(string trim -rc / -- $d)
        end
    end
end

# Git branch names across the current dir's wp-content repo(s)
function __ww_branch_names
    for d in wp-content */wp-content
        git -C $d branch --format='%(refname:short)' 2>/dev/null
    end | sort -u
end

# Installed plugin/theme names in the current dir's site(s); comma lists ok
function __ww_content_names # plugins|themes
    set -l kind $argv[1]
    set -l prefix (string replace -r '[^,]*$' '' -- (commandline -ct))
    for d in wp-content/$kind/*/ */wp-content/$kind/*/
        echo "$prefix"(string split / -- $d)[-2]
    end | sort -u
end

function __ww_no_cmd
    not __ww_verb >/dev/null
end

function __ww_get_ctx
    __ww_is_verb get
end

function __ww_get_no_target
    __ww_get_ctx
    and not __fish_seen_subcommand_from plugins plugin themes core status brief git branch url db
end

function __ww_install_ctx
    __ww_is_verb install
end

function __ww_update_ctx
    __ww_is_verb update
end

function __ww_update_no_target
    __ww_update_ctx
    and not __fish_seen_subcommand_from core plugins plugin themes theme
end

function __ww_set_ctx
    __ww_is_verb set
end

function __ww_set_env
    __ww_set_ctx
    and not __fish_seen_subcommand_from local ddev
end

# ── Top-level commands ────────────────────────────────────────────────────────

complete -c webwerk -f -n __ww_no_cmd -a install -d 'Install WordPress site'
complete -c webwerk -f -n __ww_no_cmd -a update  -d 'Update WordPress (core+plugins+themes)'
complete -c webwerk -f -n __ww_no_cmd -a set     -d 'Modify/manage existing WordPress sites'
complete -c webwerk -f -n __ww_no_cmd -a get     -d 'Read-only: list plugins/themes/core, URLs, db query'
complete -c webwerk -f -n __ww_no_cmd -a remove  -d 'Remove a WordPress/DDEV site'
complete -c webwerk -f -n __ww_no_cmd -a doctor  -d 'Diagnostics: config (tool setup) or sites (per-site health)'
complete -c webwerk -f -n __ww_no_cmd -a help    -d 'Show help (optionally: help <verb>)'
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
complete -c webwerk -n __ww_install_ctx -l no-activate       -d "Don't activate cloned plugins (default: activate all)"
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
complete -c webwerk -f -n '__ww_update_ctx; and __ww_after_word plugin' -a '(__ww_content_names plugins)' -d 'Installed plugin'
complete -c webwerk -f -n '__ww_update_ctx; and __ww_after_word theme'  -a '(__ww_content_names themes)'  -d 'Installed theme'

# ── update: options ───────────────────────────────────────────────────────────

complete -c webwerk -n __ww_update_ctx -s a -l all -l all-sites -d 'Update all sites, pause between each (x=exit)'
complete -c webwerk -n __ww_update_ctx -s A -l all-sites-auto -d 'Update all sites, no pause, no prompts (= -ay)'
complete -c webwerk -n __ww_update_ctx -s l -l list-select -d 'List sites numbered; pick a subset (e.g. 1,2,4,11)'
complete -c webwerk -n __ww_update_ctx -s B -l batch          -d 'Auto all sites, no pause, compact output'
complete -c webwerk -n __ww_update_ctx -s q -l quiet          -d 'Quiet: one status line per site ([i/T] site (P%)); full output to log'
complete -c webwerk -n __ww_update_ctx -s v -l verbose        -d "Verbose: detailed output + streamed wp messages + progress bar"
complete -c webwerk -n __ww_update_ctx -s s -l sites       -x -a '(__ww_site_names)' -d 'Specific sites (comma-separated)'
complete -c webwerk -n __ww_update_ctx -s y -l yes-update      -d 'Auto-confirm all updates'
complete -c webwerk -n __ww_update_ctx -s c -l skip-core       -d 'Skip core update'
complete -c webwerk -n __ww_update_ctx -s m -l minor           -d 'Patch-level only (e.g. 8.1.1 → 8.1.2)'
complete -c webwerk -n __ww_update_ctx -s g                    -d 'Git mode (commit per plugin)'
complete -c webwerk -n __ww_update_ctx -s S -l sum             -d 'Single summary git commit'
complete -c webwerk -n __ww_update_ctx -s p -l git-push        -d 'Push after updates'
complete -c webwerk -n __ww_update_ctx -s P -l push-only       -d 'Push only (no update)'
complete -c webwerk -n __ww_update_ctx -s x -l exclude-plugins -r -d 'Exclude plugins (comma-separated)'
complete -c webwerk -n __ww_update_ctx -s h -l help            -d 'Show help'

# ── remove: mode + options ────────────────────────────────────────────────────

function __ww_remove_ctx
    __ww_is_verb remove
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
complete -c webwerk    -n __ww_remove_local -s s -l sites          -x -a '(__ww_site_names)' -d 'Site(s) to remove (comma-separated)'
complete -c webwerk -f -n __ww_remove_local -s a -l all-sites          -d 'All sites under base dir (prompt each)'
complete -c webwerk -f -n __ww_remove_local -s A -l all-sites-auto     -d 'All sites under base dir (no prompt)'
complete -c webwerk -f -n __ww_remove_local -s y -l yes                -d 'Skip the confirmation prompt'

# ── doctor: config (tool) / sites (per-site health) ───────────────────────────

function __ww_doctor_ctx
    __ww_is_verb doctor
end
function __ww_doctor_no_sub
    __ww_doctor_ctx
    and not __fish_seen_subcommand_from config sites
end
function __ww_doctor_sites
    __ww_doctor_ctx
    and __fish_seen_subcommand_from sites
end

complete -c webwerk -f -n __ww_doctor_no_sub -a config -d "Check webwerk's own setup (.env, ~/.keys, WP-CLI, scripts)"
complete -c webwerk -f -n __ww_doctor_no_sub -a sites  -d 'Per-site health verdict (WordPress installed / DB reachable)'
complete -c webwerk    -n __ww_doctor_sites -s s -l sites -x -a '(__ww_site_names)' -d 'Specific sites (comma-separated)'
complete -c webwerk -f -n __ww_doctor_sites -s a -l all-sites      -d 'All sites under the base dir'
complete -c webwerk -f -n __ww_doctor_sites -s A -l all-sites-auto -d 'All sites under the base dir'

# ── set: environment target (local default / ddev) ────────────────────────────

complete -c webwerk -f -n __ww_set_env -a local -d 'Modify local WordPress sites (default)'
complete -c webwerk -f -n __ww_set_env -a ddev  -d 'Modify DDEV WordPress site'

# ── set: options ──────────────────────────────────────────────────────────────

complete -c webwerk -n __ww_set_ctx -s a -l all-sites                      -d 'Process all sites (interactive)'
complete -c webwerk -n __ww_set_ctx -s A -l all-sites-auto                 -d 'Process all sites (non-interactive)'
complete -c webwerk -n __ww_set_ctx -s s -l sites                       -x -a '(__ww_site_names)' -d 'Specific sites (comma-separated)'
complete -c webwerk -n __ww_set_ctx -s d -l original-dir                -r  -d 'Set base directory'
complete -c webwerk -n __ww_set_ctx -s p -l print                          -d 'Print selected sites'
complete -c webwerk -n __ww_set_ctx -s T -l themes                         -d 'List themes (optionally activate by number/name)'
complete -c webwerk -n __ww_set_ctx -s W -l theme-webwerk                   -d "Activate 'webwerk' theme (skip if active; else pick one)"
complete -c webwerk -f -n '__ww_set_env; and not __fish_seen_subcommand_from theme plugin site config user branch' -a site -d 'Site config: site <license|remote|url> [show|set|add]'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from site; and not __fish_seen_subcommand_from license remote url' -a 'license remote url' -d 'site config target'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from license; and not __fish_seen_subcommand_from show set' -a 'show set' -d 'license action'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from license; and __fish_seen_subcommand_from set' -a 'acf wpmdb akeeba all' -d 'license to apply'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from remote; and not __fish_seen_subcommand_from show add set' -a 'show add set' -d 'remote action'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from url; and not __fish_seen_subcommand_from show set' -a 'show set' -d 'url action'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from url; and __fish_seen_subcommand_from set' -a 'home siteurl both' -d 'which url'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from theme plugin site config user branch' -a help -d 'Show help for this WHAT'
complete -c webwerk -f -n '__ww_set_env; and not __fish_seen_subcommand_from theme plugin site config user branch' -a theme -d 'Activate a theme: theme [webwerk|NAME|NUM]'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from theme' -a webwerk -d 'Activate the webwerk theme'
complete -c webwerk -f -n '__ww_set_env; and not __fish_seen_subcommand_from theme plugin site config user branch' -a plugin -d 'Plugin actions: plugin <install|copy|update|activate|deactivate|remove>'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from plugin; and not __fish_seen_subcommand_from install copy update activate deactivate remove' -a 'install copy update activate deactivate remove' -d 'plugin action'
complete -c webwerk -n '__ww_set_ctx; and __fish_seen_subcommand_from plugin' -l no-activate -d "With install/copy, don't activate the plugin"
complete -c webwerk -f -n '__ww_set_env; and not __fish_seen_subcommand_from theme plugin site config user branch' -a config -d 'WP toggles: config <debug|errors|indexing|https|htaccess>'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from config; and not __fish_seen_subcommand_from debug errors indexing https htaccess' -a 'debug errors indexing https htaccess' -d 'config toggle'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from debug indexing; and not __fish_seen_subcommand_from on off' -a 'on off' -d 'state'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from errors; and not __fish_seen_subcommand_from hide show' -a 'hide show' -d 'errors display'
complete -c webwerk -f -n '__ww_set_env; and not __fish_seen_subcommand_from theme plugin site config user branch' -a branch -d 'Git branches: branch [merge [NAME]]'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from branch; and not __fish_seen_subcommand_from add merge' -a add   -d 'Create NAME if missing + switch (local; add "push" to push)'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from branch; and not __fish_seen_subcommand_from add merge' -a merge -d 'Merge current branch into NAME (default live), no push'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from branch; and __fish_seen_subcommand_from merge' -a '(__ww_branch_names)' -d 'Target branch'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from branch; and __fish_seen_subcommand_from add' -a '(__ww_branch_names)' -d 'Branch to create/switch'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from branch; and __fish_seen_subcommand_from add' -a push -d 'Also push -u origin'
complete -c webwerk -f -n '__ww_set_env; and not __fish_seen_subcommand_from theme plugin site config user branch' -a user -d 'Users: user [add NAME --role ... --pass ... --email ...]'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from user; and not __fish_seen_subcommand_from add' -a add -d 'add a user'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from user add' -l role -r -a 'admin editor author contributor subscriber' -d 'role (admin default)'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from user add' -l pass -r -d 'password'
complete -c webwerk -f -n '__ww_set_ctx; and __fish_seen_subcommand_from user add' -l email -r -d 'email'
complete -c webwerk -n __ww_set_ctx -s o -l os-detection                   -d 'Show OS information'
complete -c webwerk -n __ww_set_ctx -l git                              -r  -d 'Run git subcommand' -a 'pull\tpull log\tlog'
complete -c webwerk -n __ww_set_ctx -s G -l git-pull                       -d 'Update repos via git pull'
complete -c webwerk -n __ww_set_ctx -s u -l update                      -r  -d 'Update plugin (or all)'
complete -c webwerk -n __ww_set_ctx -s i -l install-plugin              -r  -d 'Install plugin on selected sites'
complete -c webwerk -n __ww_set_ctx -s y -l copy-plugins                -r  -d 'Copy plugin from path to selected sites'
complete -c webwerk -n __ww_set_ctx -s f -l acf-pro-lk                     -d 'Setup ACF Pro license key'
complete -c webwerk -n __ww_set_ctx -s m -l wp-migrate-db-pro              -d 'Setup WP Migrate DB Pro license key'
complete -c webwerk -n __ww_set_ctx -s k -l akeeba-license                  -d 'Setup Akeeba Download ID'
complete -c webwerk -n __ww_set_ctx -l setup-all-licenses                  -d 'Setup all available license keys'
complete -c webwerk -n __ww_set_ctx -s n -l new-user                       -d 'Create new admin user'
complete -c webwerk -n __ww_set_ctx -s U -l wp-user                    -r  -d 'Username for new user'
complete -c webwerk -n __ww_set_ctx -s P -l wp-password                -r  -d 'Password for new user'
complete -c webwerk -n __ww_set_ctx -s E -l wp-email                   -r  -d 'Email for new user'
complete -c webwerk -n __ww_set_ctx -s R -l search-replace             -r  -d 'Run wp search-replace (OLD NEW)'
complete -c webwerk -n __ww_set_ctx -s x -l wp-debug                   -r  -d 'Enable/disable debug mode' -a 'on\tEnable off\tDisable'
complete -c webwerk -n __ww_set_ctx -s z -l hide-errors                    -d 'Hide WordPress errors'
complete -c webwerk -n __ww_set_ctx -s r -l disable-search-engine-indexing -d 'Disable search engine indexing'
complete -c webwerk -n __ww_set_ctx -l enable-search-engine-indexing        -d 'Enable search engine indexing'
complete -c webwerk -n __ww_set_ctx -l htaccess                            -d 'Create/update .htaccess file'
complete -c webwerk -n __ww_set_ctx -s S -l force-https                    -d 'Force HTTPS'
complete -c webwerk -n __ww_set_ctx -s w -l location-wp                -r  -d 'Set WP-CLI path'
complete -c webwerk -n __ww_set_ctx -s h -l help                           -d 'Show help'

# ── get: read-only retrieval ──────────────────────────────────────────────────
complete -c webwerk -f -n __ww_get_no_target -a plugins -d 'List plugins per site'
complete -c webwerk -f -n __ww_get_no_target -a plugin  -d 'Find which sites have a plugin (by NAME)'
complete -c webwerk -f -n __ww_get_no_target -a themes  -d 'List themes per site'
complete -c webwerk -f -n __ww_get_no_target -a core    -d 'Core version (+update) per site'
complete -c webwerk -f -n __ww_get_no_target -a status  -d 'Full per-site status'
complete -c webwerk -f -n __ww_get_no_target -a brief   -d 'Brief: core + plugin/theme update counts'
complete -c webwerk -f -n __ww_get_no_target -a git     -d 'Git overview of each wp-content repo'
complete -c webwerk -f -n __ww_get_no_target -a branch  -d 'List branches in each wp-content repo (-l/-r)'
complete -c webwerk -f -n __ww_get_no_target -a url     -d 'siteurl / home per site'
complete -c webwerk -f -n __ww_get_no_target -a db      -d 'Run a query per site (warns on non-SELECT)'
complete -c webwerk -f -n '__ww_get_ctx; and __ww_after_word plugin' -a '(__ww_content_names plugins)' -d 'Installed plugin'
complete -c webwerk -n __ww_get_ctx -s s -l sites    -x -a '(__ww_site_names)' -d 'Comma-separated site names'
complete -c webwerk -n __ww_get_ctx -s a -l all-sites       -d 'All sites, pausing between each so you can read it'
complete -c webwerk -n __ww_get_ctx -s A -l all-sites-auto  -d 'All sites, no pause (also the default)'
complete -c webwerk -n __ww_get_ctx -s l -l local           -d 'branch: local branches only'
complete -c webwerk -n __ww_get_ctx -s r -l remote          -d 'branch: remote branches only'
complete -c webwerk -n __ww_get_ctx -l format        -r -d 'Output format (table|csv|json|count|yaml)'
complete -c webwerk -n __ww_get_ctx -l errors           -d 'brief: only broken sites'
complete -c webwerk -n __ww_get_ctx -l outdated         -d 'brief: only sites with updates'
complete -c webwerk -n __ww_get_ctx -s h -l help        -d 'Show help'
complete -c webwerk -f -n __ww_get_ctx -a help          -d 'Show help (per-target after a target word)'
