#!/bin/bash
#
# WordPress Site Retrieval Script v2.0
# Part of Webwerk WordPress Management Suite
#
# Description: Read-only retrieval/query for existing WordPress sites.
#   This is the "get" half of the read/write split: it only reads from sites
#   (list plugins/themes/core, site URLs, db queries). Anything that *changes*
#   a site lives in `webwerk mod`.
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

#===============================================================================
# CONFIGURATION
#===============================================================================

sites=()
WORDPRESS_BASE_DIR="${WORDPRESS_BASE_DIR:-$PWD}"
WP_CLI_PATH="${WP_CLI_PATH:-wp}"
FORMAT=""   # optional --format passthrough for `wp ... list`
pause_between=0   # -a pauses between sites so each can be read; -A / default stream

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
# under WORDPRESS_BASE_DIR when nothing is selected. (Mirrors wpmod.sh.)
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

# Git overview for each site's wp-content repo: remote, branch/upstream, dirty count.
get_git() {
    collect_site_dirs
    local total=${#SITE_DIRS[@]} idx=0
    local site_dir name repo remote branch upstream ahead behind dirty
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
        remote=$(git -C "$repo" remote -v 2>/dev/null || true)
        if [[ -n "$remote" ]]; then
            echo "  remote:"; echo "$remote" | sed 's/^/    /'
        else
            echo "  remote: <none>"
        fi
        branch=$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null || true)
        if [[ -z "$branch" ]]; then
            echo "  branch: (detached HEAD)"
        elif ! git -C "$repo" rev-parse --verify -q HEAD >/dev/null 2>&1; then
            echo "  branch: $branch (no commits yet)"
        else
            upstream=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
            if [[ -n "$upstream" ]]; then
                read -r behind ahead < <(git -C "$repo" rev-list --left-right --count "$upstream"...HEAD 2>/dev/null || echo "0 0")
                echo "  branch: $branch → $upstream (ahead ${ahead:-0}, behind ${behind:-0})"
            else
                echo "  branch: $branch (no upstream)"
            fi
        fi
        dirty=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l || true)
        if [[ "$dirty" -gt 0 ]]; then
            echo -e "  status: \033[33m$dirty uncommitted change(s)\033[0m"
        else
            echo "  status: clean"
        fi
        echo
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
        git)
            cat <<EOF
webwerk get git — git overview of each site's wp-content repo

Per site: remote(s), branch/upstream with ahead/behind, and uncommitted-change
count. Sites whose wp-content is not a git repo are noted. Read-only.

Usage:
  webwerk get git [-s sites | -a]
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
\`webwerk mod\`.)

Usage:
  webwerk get <what> [OPTIONS]
  webwerk get <what> help     Show help for a single target

WHAT:
  plugins              List plugins per site
  themes               List themes per site
  core                 Core version (+ update available) per site
  status               Full per-site status (core + plugins + themes)
  brief                Brief overview: core version + plugin/theme update counts
  git                  Git overview of each site's wp-content repo
  url                  siteurl / home per site
  db "SQL"             Run a query per site (warns on non-SELECT)

OPTIONS:
  -s, --sites SITES    Comma-separated site names (under the base dir)
  -a, --all-sites      All sites, pausing between each so you can read it
  -A, --all-sites-auto All sites, no pause (also the default when -s omitted)
  --format FORMAT      Output format for plugins/themes (table|csv|json|count|yaml)
  --errors             brief: only sites that are broken
  --outdated           brief: only sites with available updates
  -h, --help           Show this help

EXAMPLES:
  webwerk get plugins
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
            --format)
                require_arg "$1" "${2:-}"
                FORMAT="$2"; shift 2 ;;
            --format=*)
                FORMAT="${1#*=}"; shift ;;
            --errors)
                BRIEF_FILTER="errors"; shift ;;
            --outdated)
                BRIEF_FILTER="outdated"; shift ;;
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
        themes)  get_themes ;;
        core)    get_core ;;
        status)  get_status ;;
        brief)   get_brief ;;
        git)     get_git ;;
        url)     get_url ;;
        db)      get_db "${positionals[0]:-}" ;;
        "")      show_help; exit 0 ;;
        *)
            log_error "Unknown target: '$what'. Use: plugins, themes, core, status, brief, git, url, db."
            exit 1 ;;
    esac
}

main "$@"
