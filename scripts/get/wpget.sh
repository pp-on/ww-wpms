#!/bin/bash
#
# WordPress Site Retrieval Script v2.0
# Part of Webwerk WordPress Management Suite
#
# Description: Read-only retrieval/query for existing WordPress sites.
#   This is the "get" half of the read/write split: it only reads from sites
#   (list plugins/themes/core, site URLs, db queries). Anything that *changes*
#   a site lives in `webwerk set`.
# License: MIT
#

set -euo pipefail

#===============================================================================
# SCRIPT METADATA
#===============================================================================

readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_NAME="WordPress Site Retrieval Script"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${PWD}/webwerk-get.log"

# Git profiles (gp_* functions); normally already exported by the dispatcher
if ! declare -F gp_list >/dev/null 2>&1 && [[ -f "${SCRIPT_DIR}/../utils/gitprofiles.sh" ]]; then
    # shellcheck source=../utils/gitprofiles.sh
    source "${SCRIPT_DIR}/../utils/gitprofiles.sh"
fi

#===============================================================================
# CONFIGURATION
#===============================================================================

sites=()
WORDPRESS_BASE_DIR="${WORDPRESS_BASE_DIR:-$PWD}"
WP_CLI_PATH="${WP_CLI_PATH:-wp}"
FORMAT=""   # optional --format passthrough for `wp ... list`
pause_between=0   # -a pauses between sites so each can be read; -A / default stream
BRANCH_SCOPE="both"   # get branch: both | local (-l) | remote (-r)
BRANCH_FETCH=1        # get branch: refresh remote refs before listing (--no-fetch = off)

# Helper functions are loaded and exported by the webwerk dispatcher.

#===============================================================================
# LOGGING
#===============================================================================

log_info()    { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "\033[31m[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*\033[0m" | tee -a "$LOG_FILE" >&2; }
log_warning() { echo -e "\033[33m[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $*\033[0m" | tee -a "$LOG_FILE" >&2; }

require_arg() {
    if [[ -z "${2:-}" ]]; then
        log_error "Option $1 requires an argument"
        exit 1
    fi
}

#===============================================================================
# SITE SELECTION
#===============================================================================

# Populate global SITE_DIRS with the -s/-a selected sites, or every install
# under WORDPRESS_BASE_DIR when nothing is selected. (Mirrors wpset.sh.)
collect_site_dirs() {
    SITE_DIRS=()
    if [[ ${#sites[@]} -gt 0 && "${sites[*]}" != "." ]]; then
        local s
        for s in "${sites[@]}"; do
            SITE_DIRS+=("$WORDPRESS_BASE_DIR/$s")
        done
    else
        local config
        while IFS= read -r config; do
            SITE_DIRS+=("$(dirname "$config")")
        done < <(find "$WORDPRESS_BASE_DIR" -maxdepth 2 -name "wp-config.php" | sort)
    fi
}

# With -a, wait for a keypress between sites so each block can be read; -A and
# the default stream straight through. Only pauses on an interactive terminal.
# Arg: how many sites have already been shown (0 = first, never pauses).
maybe_pause() {
    (( pause_between )) || return 0
    (( ${1:-0} > 0 )) || return 0
    [[ -t 1 ]] || return 0
    local key
    printf '\033[2m  — any key: next site · x: quit —\033[0m ' >/dev/tty 2>/dev/null || return 0
    read -rsn1 key </dev/tty 2>/dev/null || return 0
    printf '\n' >/dev/tty
    [[ "${key,,}" == "x" ]] && exit 0
    return 0
}

# Run a wp subcommand for every selected site, with a per-site header.
# Usage: for_each_site <wp arg>...
for_each_site() {
    collect_site_dirs
    local total=${#SITE_DIRS[@]} idx=0 site_dir name
    if (( total == 0 )); then
        log_warning "No WordPress sites found under $WORDPRESS_BASE_DIR"
        return 0
    fi
    for site_dir in "${SITE_DIRS[@]}"; do
        (( ++idx ))
        maybe_pause $(( idx - 1 ))
        name="$(basename "$site_dir")"
        echo -e "\033[36m== [$idx/$total] $name ==\033[0m"
        $WP_CLI_PATH --path="$site_dir" "$@" 2>/dev/null || echo "  (failed)"
    done
}

#===============================================================================
# GETTERS (read-only)
#===============================================================================

get_plugins() {
    local fmt=(--fields=name,status,version,update_version)
    [[ -n "$FORMAT" ]] && fmt=(--format="$FORMAT")
    for_each_site plugin list "${fmt[@]}"
}

# get plugin NAME — find which sites have a plugin matching NAME.
# Case-insensitive substring match on the plugin slug OR its human title. If a
# site has no substring hit, fall back to an acronym match: NAME (>=2 chars) as
# a prefix of the title's initials, so 'acf' finds 'Advanced Custom Fields'.
# Only matching sites print. title is queried last so it's the only field that
# may contain commas — the slug/status/version columns stay safe to split on.
get_plugin() {
    local needle="${1:-}"
    if [[ -z "$needle" ]]; then
        log_error "Usage: webwerk get plugin NAME [-s sites | -a]"
        exit 1
    fi
    collect_site_dirs
    local total=${#SITE_DIRS[@]} idx=0 site_dir name matches found=0
    for site_dir in "${SITE_DIRS[@]}"; do
        (( ++idx ))
        matches=$($WP_CLI_PATH --path="$site_dir" plugin list \
            --fields=name,status,version,update_version,title --format=csv 2>/dev/null \
            | awk -F, -v n="${needle,,}" '
                NR==1 { next }
                {
                    title = ""
                    for (i = 5; i <= NF; i++) title = title (i > 5 ? "," : "") $i
                    row = $1 "," $2 "," $3 "," $4
                    if (index(tolower($1), n) || index(tolower(title), n)) {
                        sub_rows[++s] = row; next
                    }
                    if (length(n) >= 2) {           # acronym fallback candidate
                        m = split(tolower(title), w, /[^a-z0-9]+/)
                        acr = ""
                        for (j = 1; j <= m; j++) if (w[j] != "") acr = acr substr(w[j], 1, 1)
                        if (index(acr, n) == 1) acr_rows[++a] = row
                    }
                }
                END {
                    if (s > 0)      { print "substring"; for (i = 1; i <= s; i++) print sub_rows[i] }
                    else if (a > 0) { print "acronym";   for (i = 1; i <= a; i++) print acr_rows[i] }
                }')
        [[ -z "$matches" ]] && continue
        maybe_pause "$found"
        name="$(basename "$site_dir")"
        local mode rows tag=""
        mode="${matches%%$'\n'*}"   # first line: match mode
        rows="${matches#*$'\n'}"    # remaining lines: the plugin rows
        [[ "$mode" == acronym ]] && tag=" \033[2m(acronym)\033[0m"
        echo -e "\033[36m== [$idx/$total] $name ==\033[0m$tag"
        echo "name,status,version,update_version" | cat - <(echo "$rows") | column -t -s, | sed 's/^/  /'
        found=1
    done
    (( found )) || echo "No site has a plugin matching '$needle'."
}

get_themes() {
    local fmt=(--fields=name,status,version,update_version)
    [[ -n "$FORMAT" ]] && fmt=(--format="$FORMAT")
    for_each_site theme list "${fmt[@]}"
}

get_core() {
    collect_site_dirs
    local total=${#SITE_DIRS[@]} idx=0 site_dir name version update
    for site_dir in "${SITE_DIRS[@]}"; do
        (( ++idx ))
        maybe_pause $(( idx - 1 ))
        name="$(basename "$site_dir")"
        echo -e "\033[36m== [$idx/$total] $name ==\033[0m"
        if ! $WP_CLI_PATH --path="$site_dir" core is-installed &>/dev/null; then
            echo -e "  \033[31mnot installed or broken\033[0m"
            continue
        fi
        version=$($WP_CLI_PATH --path="$site_dir" core version 2>/dev/null || true)
        update=$($WP_CLI_PATH --path="$site_dir" core check-update --field=version 2>/dev/null | grep -v '^Success' | xargs || true)
        if [[ -n "$update" ]]; then
            echo -e "  $version \033[33m(update available: $update)\033[0m"
        else
            echo -e "  $version (up to date)"
        fi
    done
}

get_url() {
    collect_site_dirs
    local total=${#SITE_DIRS[@]} idx=0 site_dir name siteurl home
    for site_dir in "${SITE_DIRS[@]}"; do
        (( ++idx ))
        maybe_pause $(( idx - 1 ))
        name="$(basename "$site_dir")"
        siteurl=$($WP_CLI_PATH --path="$site_dir" option get siteurl 2>/dev/null || echo "?")
        home=$($WP_CLI_PATH --path="$site_dir" option get home 2>/dev/null || echo "?")
        printf '\033[36m%s\033[0m\n  siteurl: %s\n  home:    %s\n' "$name" "$siteurl" "$home"
    done
}

# Per-site license applied-status. show_values=1 also reveals configured keys.
get_license() {
    local show_values="${1:-0}"
    collect_site_dirs
    local total=${#SITE_DIRS[@]} idx=0
    local site_dir name cfg mark
    for site_dir in "${SITE_DIRS[@]}"; do
        (( ++idx ))
        maybe_pause $(( idx - 1 ))
        name="$(basename "$site_dir")"
        cfg="$site_dir/wp-config.php"
        echo -e "\033[36m[$idx/$total] $name\033[0m"
        if grep -q "ACF_PRO_LICENSE" "$cfg" 2>/dev/null; then mark="\033[32mapplied\033[0m"; else mark="\033[33mnot applied\033[0m"; fi
        echo -e "  ACF Pro:     $mark"
        if grep -q "WPMDB_LICENCE" "$cfg" 2>/dev/null; then mark="\033[32mapplied\033[0m"; else mark="\033[33mnot applied\033[0m"; fi
        echo -e "  WP Migrate:  $mark"
        if grep -q "AKEEBA_DOWNLOAD_ID" "$cfg" 2>/dev/null \
           || [[ -n "$(${WP_CLI_PATH} --path="$site_dir" option get akeeba_download_id 2>/dev/null || true)" ]]; then
            mark="\033[32mapplied\033[0m"; else mark="\033[33mnot applied\033[0m"; fi
        echo -e "  Akeeba:      $mark"
        echo
    done
    if [[ "$show_values" == "1" ]]; then
        echo "Configured license values (from ~/.keys / .env):"
        echo "  ACF_PRO_LICENSE    = ${ACF_PRO_LICENSE:-<not set>}"
        echo "  WPMDB_LICENCE      = ${WPMDB_LICENCE:-<not set>}"
        echo "  AKEEBA_DOWNLOAD_ID = ${AKEEBA_DOWNLOAD_ID:-<not set>}"
    fi
}

get_status() {
    collect_site_dirs
    local total=${#SITE_DIRS[@]} idx=0 site_dir name version update
    for site_dir in "${SITE_DIRS[@]}"; do
        (( ++idx ))
        maybe_pause $(( idx - 1 ))
        name="$(basename "$site_dir")"
        echo -e "\033[36m================================\n  [$idx/$total] $name\n================================\033[0m"
        if ! $WP_CLI_PATH --path="$site_dir" core is-installed &>/dev/null; then
            echo -e "\033[31mWP ERR — not installed or broken\033[0m"
            continue
        fi
        version=$($WP_CLI_PATH --path="$site_dir" core version 2>/dev/null || true)
        update=$($WP_CLI_PATH --path="$site_dir" core check-update --field=version 2>/dev/null | grep -v '^Success' | xargs || true)
        if [[ -n "$update" ]]; then
            echo -e "\033[32mWP OK\033[0m  $version \033[33m(update available: $update)\033[0m"
        else
            echo -e "\033[32mWP OK\033[0m  $version (up to date)"
        fi
        echo -e "\033[33mPlugins:\033[0m"
        $WP_CLI_PATH --path="$site_dir" plugin list --fields=name,status,version,update_version 2>/dev/null || echo "  (failed to list plugins)"
        echo -e "\033[33mThemes:\033[0m"
        $WP_CLI_PATH --path="$site_dir" theme list --fields=name,status,version,update_version 2>/dev/null || echo "  (failed to list themes)"
    done
}

# get db "SQL" — run a query on each selected site. `get` is read-only by intent,
# so warn (but proceed) when the statement is not an obvious read.
get_db() {
    local sql="${1:-}"
    if [[ -z "$sql" ]]; then
        log_error "Usage: webwerk get db \"SQL\" [-s sites]"
        exit 1
    fi
    if ! [[ "$sql" =~ ^[[:space:]]*([Ss][Ee][Ll][Ee][Cc][Tt]|[Ss][Hh][Oo][Ww]|[Dd][Ee][Ss][Cc]|[Ee][Xx][Pp][Ll][Aa][Ii][Nn])[[:space:]] ]]; then
        log_warning "Query is not a SELECT/SHOW/DESCRIBE/EXPLAIN — 'get' is meant for reading. Running anyway."
    fi
    for_each_site db query "$sql"
}

# Brief overview: core version + plugin/theme update counts per site.
# BRIEF_FILTER: all (default) | errors (only broken) | outdated (only with updates)
get_brief() {
    local filter="${BRIEF_FILTER:-all}"
    collect_site_dirs
    local site_dir name version update p_total p_upd t_total t_upd shown=0 err_msg
    for site_dir in "${SITE_DIRS[@]}"; do
        name="$(basename "$site_dir")"
        err_msg=""
        if ! $WP_CLI_PATH --path="$site_dir" core is-installed &>/dev/null; then
            err_msg="WP ERR — not installed or broken"
        elif [[ ! -d "$site_dir/wp-content" || -z "$(find "$site_dir/wp-content" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
            version=$($WP_CLI_PATH --path="$site_dir" core version 2>/dev/null || true)
            err_msg="WP ${version:-?} — wp-content EMPTY (no plugins/themes, site broken)"
        fi
        if [[ -n "$err_msg" ]]; then
            if [[ "$filter" != "outdated" ]]; then
                maybe_pause "$shown"
                echo -e "\033[31m$name   $err_msg\033[0m"; shown=1
            fi
            continue
        fi
        [[ "$filter" == "errors" ]] && continue
        version=$($WP_CLI_PATH --path="$site_dir" core version 2>/dev/null || true)
        update=$($WP_CLI_PATH --path="$site_dir" core check-update --field=version 2>/dev/null | grep -v '^Success' | xargs || true)
        p_total=$($WP_CLI_PATH --path="$site_dir" plugin list --format=count 2>/dev/null || echo 0)
        p_upd=$($WP_CLI_PATH --path="$site_dir" plugin list --update=available --format=count 2>/dev/null || echo 0)
        t_total=$($WP_CLI_PATH --path="$site_dir" theme list --format=count 2>/dev/null || echo 0)
        t_upd=$($WP_CLI_PATH --path="$site_dir" theme list --update=available --format=count 2>/dev/null || echo 0)
        if [[ "$filter" == "outdated" && -z "$update" && "$p_upd" -eq 0 && "$t_upd" -eq 0 ]]; then
            continue
        fi
        maybe_pause "$shown"
        if [[ -n "$update" ]]; then
            echo -e "\033[36m$name\033[0m   WP $version \033[33m(update: $update)\033[0m"
        else
            echo -e "\033[36m$name\033[0m   WP $version (up to date)"
        fi
        if [[ "$p_upd" -gt 0 ]]; then
            echo -e "  plugins: $p_total total, \033[33m$p_upd can be updated\033[0m"
        else
            echo "  plugins: $p_total total, all up to date"
        fi
        if [[ "$t_upd" -gt 0 ]]; then
            echo -e "  themes:  $t_total total, \033[33m$t_upd can be updated\033[0m"
        else
            echo "  themes:  $t_total total, all up to date"
        fi
        echo
        shown=1
    done
    if [[ "$shown" -eq 0 ]]; then
        case "$filter" in
            errors)   echo "No sites with errors." ;;
            outdated) echo "All sites up to date." ;;
            *)        echo "No WordPress sites found." ;;
        esac
    fi
}

# Remote URL(s) for each site's wp-content repo. filter: "" (both, labeled) | fetch | push.
get_remote() {
    local filter="${1:-}"
    case "$filter" in
        ""|fetch|push) ;;
        *) log_error "get remote: unknown filter '$filter'. Use: fetch, push (or omit for both)."; exit 1 ;;
    esac
    collect_site_dirs
    local total=${#SITE_DIRS[@]} idx=0
    local site_dir name repo remotes r fetch push
    for site_dir in "${SITE_DIRS[@]}"; do
        (( ++idx ))
        maybe_pause $(( idx - 1 ))
        name="$(basename "$site_dir")"
        repo="$site_dir/wp-content"
        if ! git -C "$repo" rev-parse --is-inside-work-tree &>/dev/null; then
            echo -e "\033[33m[$idx/$total] $name   no git repo in wp-content\033[0m"
            continue
        fi
        echo -e "\033[36m[$idx/$total] $name\033[0m"
        remotes=$(git -C "$repo" remote 2>/dev/null || true)
        if [[ -z "$remotes" ]]; then
            echo "  <none>"
        else
            while read -r r; do
                [[ -z "$r" ]] && continue
                case "$filter" in
                    fetch)
                        fetch=$(git -C "$repo" remote get-url "$r" 2>/dev/null || echo '?')
                        echo "  $r: $fetch" ;;
                    push)
                        push=$(git -C "$repo" remote get-url --push "$r" 2>/dev/null || echo '?')
                        echo "  $r: $push" ;;
                    *)
                        fetch=$(git -C "$repo" remote get-url "$r" 2>/dev/null || echo '?')
                        push=$(git -C "$repo" remote get-url --push "$r" 2>/dev/null || echo '?')
                        if [[ "$fetch" == "$push" ]]; then
                            echo "  $r: $fetch"
                        else
                            echo "  $r:"
                            echo "    fetch: $fetch"
                            echo "    push:  $push"
                        fi ;;
                esac
            done <<< "$remotes"
        fi
        echo
    done
}

# List branches in each site's wp-content repo.
# BRANCH_SCOPE: both (default) | local (-l) | remote (-r).
get_branch() {
    collect_site_dirs
    local total=${#SITE_DIRS[@]} idx=0 site_dir name repo
    # keep an unreachable remote from hanging a read command
    local BRANCH_FETCH_TIMEOUT=""
    if command -v timeout &>/dev/null; then BRANCH_FETCH_TIMEOUT="timeout 10"; fi
    for site_dir in "${SITE_DIRS[@]}"; do
        (( ++idx ))
        maybe_pause $(( idx - 1 ))
        name="$(basename "$site_dir")"
        repo="$site_dir/wp-content"
        echo -e "\033[36m== [$idx/$total] $name ==\033[0m"
        if ! git -C "$repo" rev-parse --is-inside-work-tree &>/dev/null; then
            echo -e "  \033[33mno git repo in wp-content\033[0m"
            continue
        fi
        # Refresh the remote-tracking refs first, otherwise "remote:" shows the
        # state at clone time, not what is on origin now. Only refs/remotes is
        # touched — no local branch, no working tree, no site state. --no-fetch
        # (or -l, which needs no remote data) skips it.
        if [[ "$BRANCH_FETCH" == "1" && "$BRANCH_SCOPE" != "local" ]] \
           && git -C "$repo" remote | grep -q .; then
            if ! GIT_TERMINAL_PROMPT=0 $BRANCH_FETCH_TIMEOUT git -C "$repo" fetch --prune --quiet origin 2>/dev/null; then
                echo -e "  \033[33mfetch failed — remote list may be stale\033[0m"
            fi
        fi
        if [[ "$BRANCH_SCOPE" != "remote" ]]; then
            echo -e "  \033[33mlocal:\033[0m"
            git -C "$repo" branch 2>/dev/null | sed 's/^/  /' || echo "    (none)"
        fi
        if [[ "$BRANCH_SCOPE" != "local" ]]; then
            echo -e "  \033[33mremote:\033[0m"
            git -C "$repo" branch -r 2>/dev/null | sed 's/^/  /' || echo "    (none)"
        fi
    done
}

#===============================================================================
# HELP
#===============================================================================

# show_help [target] — generic help, or focused help for a single get target.
show_help() {
    local topic="${1:-}"
    case "$topic" in
        plugins|themes)
            local one="${topic%s}"   # plugins -> plugin
            cat <<EOF
webwerk get $topic — list ${topic} per site

Lists every $one (name, status, version, available update) for each selected
site. Read-only.

Usage:
  webwerk get $topic [-s sites | -a] [--format FORMAT]

Options:
  -s, --sites SITES    Comma-separated site names under the base dir
  -a, --all-sites      All sites, pausing between each so you can read it
  -A, --all-sites-auto All sites, no pause (also the default when -s omitted)
  --format FORMAT      table (default) | csv | json | count | yaml

Examples:
  webwerk get $topic
  webwerk get $topic -s acme
  webwerk get $topic --format count
EOF
            ;;
        plugin)
            cat <<EOF
webwerk get plugin — find which sites have a plugin

Searches each selected site for a plugin whose slug OR human title contains
NAME (case-insensitive substring), so 'anti-spam' finds the plugin with slug
'akismet'. If a site has no substring hit, NAME (2+ chars) is tried as an
acronym of the title's initials, so 'acf' finds 'Advanced Custom Fields'.
Only sites with a match are printed, with the plugin's status, version and
available update. Read-only.

Usage:
  webwerk get plugin NAME [-s sites | -a]

Examples:
  webwerk get plugin woocommerce -s acme
  webwerk get plugin anti-spam
  webwerk get plugin acf -a
EOF
            ;;
        core)
            cat <<EOF
webwerk get core — WordPress core version per site

Shows each site's core version and whether an update is available. Broken or
uninstalled sites are flagged. Read-only.

Usage:
  webwerk get core [-s sites | -a]
EOF
            ;;
        status)
            cat <<EOF
webwerk get status — full per-site status

Per site: core version (+ available update), then the full plugin and theme
lists. The verbose view; use 'get brief' for a condensed one. Read-only.

Usage:
  webwerk get status [-s sites | -a]
EOF
            ;;
        brief)
            cat <<EOF
webwerk get brief — condensed per-site overview

Per site: core version plus plugin/theme totals and how many can be updated.
Broken installs (and DB-installed sites with an empty wp-content) are flagged.

Usage:
  webwerk get brief [-s sites | -a] [--errors | --outdated]

Options:
  --errors     Only sites that are broken
  --outdated   Only sites with available updates
EOF
            ;;
        remote)
            cat <<EOF
webwerk get remote — remote URL(s) of each site's wp-content repo

Per site: each remote's URL (fetch/push shown together, or separately when
they differ). Add 'fetch' or 'push' to show only that one. Sites whose
wp-content is not a git repo are noted. Read-only.

Usage:
  webwerk get remote [fetch|push] [-s sites | -a]
EOF
            ;;
        profiles|profile)
            cat <<EOF
webwerk get profiles - list the git profiles

A profile names a git account: git user/organisation, host and protocol. It is
the only source of clone URLs - nothing about the account is hardcoded.

Shown per profile: name, git user, host, protocol. The default (GIT_PROFILE,
used when install runs without -G) is marked with *.

Profiles are stored in the .env in use (project .env, else ~/.env), so they are
yours and are not part of the ww-wpms repository. Read-only; to change them:
  webwerk set profile add|edit|rm|default

Usage:
  webwerk get profiles
EOF
            ;;
        branch)
            cat <<EOF
webwerk get branch — list branches in each site's wp-content repo

Per site, lists the branches in wp-content. With no flag both local and remote
branches are shown; -l restricts to local, -r to remote. Read-only.

Before listing, the remote refs are refreshed (git fetch --prune), so branches
created on origin after your clone do show up. That only updates refs/remotes —
no local branch, no working tree, no site state is touched. --no-fetch skips it
(and -l never fetches, since local branches need no remote data).

To work on one of those branches, use 'webwerk set branch NAME' (or
'set branch all' to bring them all in); to merge, 'webwerk set branch merge [NAME]'.

Usage:
  webwerk get branch [-l | -r] [--no-fetch] [-s sites | -a]
EOF
            ;;
        url)
            cat <<EOF
webwerk get url — site URLs per site

Shows the 'siteurl' and 'home' options for each selected site. Read-only.

Usage:
  webwerk get url [-s sites | -a]
EOF
            ;;
        license)
            cat <<EOF
webwerk get license — per-site license applied-status

Per site: is ACF Pro / WP Migrate DB Pro / Akeeba applied? -x/--values also
prints the configured keys from ~/.keys/.env. Read-only. To apply a license,
use 'webwerk set site license <acf|wpmdb|akeeba|all>'.

Usage:
  webwerk get license [-x] [-s sites | -a]
EOF
            ;;
        db)
            cat <<EOF
webwerk get db — run a read query per site

Runs the given SQL on each selected site's database. 'get' is read-only by
intent, so a non-SELECT/SHOW/DESCRIBE/EXPLAIN statement warns but still runs.

Usage:
  webwerk get db "SQL" [-s sites | -a]

Example:
  webwerk get db "SELECT post_title FROM wp_posts LIMIT 5" -s acme
EOF
            ;;
        *)
            cat <<EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Read-only retrieval/query for existing WordPress sites. (For changes, use
\`webwerk set\`.)

Usage:
  webwerk get <what> [OPTIONS]
  webwerk get <what> help     Show help for a single target

WHAT:
  plugins              List plugins per site
  plugin NAME          Find which sites have a plugin matching NAME
  themes               List themes per site
  core                 Core version (+ update available) per site
  status               Full per-site status (core + plugins + themes)
  brief                Brief overview: core version + plugin/theme update counts
  remote [fetch|push]  Remote URL(s) of each site's wp-content repo
  branch               List branches in each site's wp-content repo (-l/-r)
  url                  siteurl / home per site
  license [-x]         Per-site license applied-status (-x also shows keys)
  db "SQL"             Run a query per site (warns on non-SELECT)

OPTIONS:
  -s, --sites SITES    Comma-separated site names (under the base dir)
  -a, --all-sites      All sites, pausing between each so you can read it
  -A, --all-sites-auto All sites, no pause (also the default when -s omitted)
  -l, --local          branch: list only local branches
  -r, --remote         branch: list only remote branches (default: both)
  --format FORMAT      Output format for plugins/themes (table|csv|json|count|yaml)
  --errors             brief: only sites that are broken
  --outdated           brief: only sites with available updates
  -x, --values         license: also print the configured key values
  -h, --help           Show this help

EXAMPLES:
  webwerk get plugins
  webwerk get plugin woocommerce -a
  webwerk get plugins -s acme --format json
  webwerk get brief --outdated
  webwerk get url -a
  webwerk get db "SELECT post_title FROM wp_posts LIMIT 5" -s acme
EOF
            ;;
    esac
}

#===============================================================================
# ARGUMENT PARSING
#===============================================================================

main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local what="" positionals=() want_help=0
    BRIEF_FILTER="all"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help|help)
                # defer: remember the target parsed so far -> per-target help
                want_help=1; shift ;;
            -s|--sites)
                if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
                    # bare -s: interactive numbered picker (names or numbers)
                    local _csv; _csv="$(select_sites_interactive "$WORDPRESS_BASE_DIR")" || exit 1
                    IFS=',' read -ra sites <<< "$_csv"; shift
                else
                    IFS=',' read -ra sites <<< "$2"; shift 2
                fi ;;
            -a|--all-sites)
                sites=(); pause_between=1; shift ;;
            -A|--all-sites-auto)
                sites=(); pause_between=0; shift ;;
            -l|--local)
                BRANCH_SCOPE="local"; shift ;;
            -r|--remote)
                BRANCH_SCOPE="remote"; shift ;;
            --no-fetch)
                BRANCH_FETCH=0; shift ;;
            --format)
                require_arg "$1" "${2:-}"
                FORMAT="$2"; shift 2 ;;
            --format=*)
                FORMAT="${1#*=}"; shift ;;
            --errors)
                BRIEF_FILTER="errors"; shift ;;
            --outdated)
                BRIEF_FILTER="outdated"; shift ;;
            -x|--values)
                LICENSE_VALUES=1; shift ;;
            --debug)
                set -x; shift ;;
            -*)
                log_error "Unknown option: $1"; exit 1 ;;
            *)
                if [[ -z "$what" ]]; then what="$1"; else positionals+=("$1"); fi
                shift ;;
        esac
    done

    if (( want_help )); then
        show_help "$what"   # generic when no target, focused otherwise
        exit 0
    fi

    case "$what" in
        plugins) get_plugins ;;
        plugin)  get_plugin "${positionals[0]:-}" ;;
        themes)  get_themes ;;
        core)    get_core ;;
        status)  get_status ;;
        brief)   get_brief ;;
        remote)  get_remote "${positionals[0]:-}" ;;
        branch)  get_branch ;;
        url)     get_url ;;
        license) get_license "${LICENSE_VALUES:-0}" ;;
        db)      get_db "${positionals[0]:-}" ;;
        profiles|profile) gp_list ;;
        "")      show_help; exit 0 ;;
        *)
            log_error "Unknown target: '$what'. Use: plugins, plugin, themes, core, status, brief, remote, branch, url, license, db, profiles."
            exit 1 ;;
    esac
}

main "$@"
