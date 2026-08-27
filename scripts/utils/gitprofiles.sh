#!/bin/bash
#
# Git profiles - part of the Webwerk WordPress Management Suite
#
# A profile names a git account: which user/organisation, on which host, over
# which protocol. It is the only source of clone URLs; nothing is hardcoded.
#
#     GIT_PROFILE_<name>="USER HOST PROTO"
#     GIT_PROFILE=<name>                     # used when -G is not given
#
# Profiles live in the .env in use (project .env, else ~/.env), never in this
# repository, so they are not handed out when someone clones ww-wpms.
#
# With PROTO=ssh, HOST is usually a Host alias from ~/.ssh/config (hostname and
# key live there):    GIT_PROFILE_privat="ojnickel privat ssh"
#                     -> privat:ojnickel/<repo>.git
# With PROTO=https, HOST is the real hostname:
#                     GIT_PROFILE_gh="ojnickel github.com https"
#                     -> https://github.com/ojnickel/<repo>.git

# Logging: use the dispatcher's loggers when they are present, otherwise print
# plainly. Resolved per call, because sub-scripts inherit the exported gp_*
# functions without necessarily inheriting the loggers.
gp_err()  { if declare -F log_error   >/dev/null 2>&1; then log_error   "$*"; else echo "ERROR: $*" >&2; fi; }
gp_say()  { if declare -F log_info    >/dev/null 2>&1; then log_info    "$*"; else echo "INFO: $*"; fi; }
gp_ok()   { if declare -F log_success >/dev/null 2>&1; then log_success "$*"; else echo "OK: $*"; fi; }
gp_warn() { if declare -F log_warning >/dev/null 2>&1; then log_warning "$*"; else echo "WARN: $*" >&2; fi; }

# Can we actually prompt? -r /dev/tty passes even with no controlling terminal,
# so the only honest test is trying to open it.
gp_have_tty() {
    [[ -t 0 ]] && return 0
    { : < /dev/tty; } 2>/dev/null
}

# The .env that profiles are read from and written to
gp_env_file() {
    if [[ -n "${WEBWERK_ENV_FILE:-}" ]]; then
        echo "$WEBWERK_ENV_FILE"
        return 0
    fi
    if [[ -n "${WEBWERK_DIR:-}" && -f "${WEBWERK_DIR}/.env" ]]; then
        echo "${WEBWERK_DIR}/.env"
        return 0
    fi
    echo "$HOME/.env"
}

gp_names() {
    local f
    f="$(gp_env_file)"
    {
        compgen -v 2>/dev/null | sed -n 's/^GIT_PROFILE_//p'
        [[ -f "$f" ]] && sed -n 's/^GIT_PROFILE_\([A-Za-z0-9_]*\)=.*/\1/p' "$f"
    } | sed '/^$/d' | sort -u || true
}

gp_valid_name() {
    [[ "${1:-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

# NAME -> "USER HOST PROTO" on stdout; 1 if the profile does not exist
gp_get() {
    local name="${1:-}" var spec f line
    [[ -z "$name" ]] && return 1
    gp_valid_name "$name" || return 1

    var="GIT_PROFILE_${name}"
    spec="${!var:-}"

    if [[ -z "$spec" ]]; then
        f="$(gp_env_file)"
        if [[ -f "$f" ]]; then
            line="$(sed -n "s/^GIT_PROFILE_${name}=//p" "$f" | tail -1)"
            line="${line%\"}"; line="${line#\"}"
            line="${line%\'}"; line="${line#\'}"
            spec="$line"
        fi
    fi

    [[ -z "$spec" ]] && return 1
    echo "$spec"
}

# NAME FIELD(user|host|proto) -> value
gp_field() {
    local spec user host proto
    spec="$(gp_get "${1:-}")" || return 1
    read -r user host proto <<<"$spec"
    case "${2:-}" in
        user)  echo "$user" ;;
        host)  echo "$host" ;;
        proto) echo "${proto:-ssh}" ;;
        *)     return 1 ;;
    esac
}

# NAME REPO -> clone URL
gp_url() {
    local name="${1:-}" repo="${2:-}" user host proto
    user="$(gp_field "$name" user)" || return 1
    host="$(gp_field "$name" host)"
    proto="$(gp_field "$name" proto)"
    if [[ -z "$user" || -z "$host" ]]; then
        gp_err "Profile '$name' is incomplete: user='$user' host='$host'"
        return 1
    fi
    case "$proto" in
        https) echo "https://${host}/${user}/${repo}.git" ;;
        ssh|"") echo "${host}:${user}/${repo}.git" ;;
        *)
            gp_err "Profile '$name': unknown protocol '$proto' (use ssh or https)"
            return 1 ;;
    esac
}

gp_list() {
    local names n user host proto mark
    names="$(gp_names)"
    if [[ -z "$names" ]]; then
        echo "No git profiles defined in $(gp_env_file)"
        echo "Add one with: webwerk set profile add"
        return 1
    fi
    printf "%-16s %-24s %-20s %s\n" "PROFILE" "GIT USER" "HOST" "PROTO"
    printf "%-16s %-24s %-20s %s\n" "-------" "--------" "----" "-----"
    while read -r n; do
        [[ -z "$n" ]] && continue
        read -r user host proto <<<"$(gp_get "$n")"
        mark="$n"
        [[ "$n" == "${GIT_PROFILE:-}" ]] && mark="$n *"
        printf "%-16s %-24s %-20s %s\n" "$mark" "$user" "$host" "${proto:-ssh}"
    done <<<"$names"
    if [[ -n "${GIT_PROFILE:-}" ]]; then
        echo ""
        echo "* default (GIT_PROFILE=${GIT_PROFILE}), used when -G is not given"
    fi
    echo ""
    echo "File: $(gp_env_file)"
    return 0
}

# KEY VALUE -> write a plain KEY=VALUE into the .env in use (replacing any
# existing line for KEY). Shared with the base-URL prompt below.
gp_env_set() {
    local key="$1" value="$2" f
    f="$(gp_env_file)"
    if [[ ! -f "$f" ]]; then
        touch "$f" && chmod 600 "$f"
        gp_say "Created $f"
    fi
    if grep -q "^${key}=" "$f" 2>/dev/null; then
        sed -i "/^${key}=/d" "$f"
    fi
    printf '%s=%s\n' "$key" "$value" >> "$f"
    export "${key}=${value}"
}

# NAME USER HOST PROTO -> persist to the .env in use
gp_write() {
    local name="$1" user="$2" host="$3" proto="$4" f
    f="$(gp_env_file)"
    if [[ ! -f "$f" ]]; then
        touch "$f" && chmod 600 "$f"
        gp_say "Created $f"
    fi
    if grep -q "^GIT_PROFILE_${name}=" "$f" 2>/dev/null; then
        sed -i "/^GIT_PROFILE_${name}=/d" "$f"
    fi
    printf 'GIT_PROFILE_%s="%s %s %s"\n' "$name" "$user" "$host" "$proto" >> "$f"
    export "GIT_PROFILE_${name}=${user} ${host} ${proto}"
    gp_ok "Profile '$name' saved to $f: ${user} @ ${host} (${proto})"
}

# NAME -> make it the default (GIT_PROFILE)
gp_set_default() {
    local name="$1" f
    gp_get "$name" >/dev/null || { gp_err "Unknown profile: '$name'"; gp_list >&2; return 1; }
    f="$(gp_env_file)"
    [[ -f "$f" ]] || { touch "$f" && chmod 600 "$f"; }
    sed -i "/^GIT_PROFILE=/d" "$f"
    printf 'GIT_PROFILE=%s\n' "$name" >> "$f"
    export GIT_PROFILE="$name"
    gp_ok "Default profile is now '$name'"
}

gp_rm() {
    local name="${1:-}" f cur
    if [[ -z "$name" ]]; then
        gp_err "set profile rm NAME  (webwerk get profiles lists them)"
        return 1
    fi
    gp_get "$name" >/dev/null || { gp_err "Unknown profile: '$name'"; gp_list >&2; return 1; }
    f="$(gp_env_file)"
    if ! grep -q "^GIT_PROFILE_${name}=" "$f" 2>/dev/null; then
        gp_err "Profile '$name' is set in the environment but not in $f - nothing to remove"
        return 1
    fi
    sed -i "/^GIT_PROFILE_${name}=/d" "$f"
    cur="$(sed -n 's/^GIT_PROFILE=//p' "$f" | tail -1)"
    if [[ "$cur" == "$name" ]]; then
        sed -i "/^GIT_PROFILE=/d" "$f"
        unset GIT_PROFILE
        gp_warn "'$name' was the default profile; the default was removed too"
    fi
    unset "GIT_PROFILE_${name}"
    gp_ok "Profile '$name' removed from $f"
}

# Ask for the four fields. NAME may be given; existing values are offered as
# defaults, so this doubles as the edit prompt.
gp_prompt() {
    local name="${1:-}" spec="" def_user="" def_host="" def_proto="ssh"
    local in_name="" in_user="" in_host="" in_proto=""

    if ! gp_have_tty; then
        gp_err "No terminal available to ask for profile details"
        return 1
    fi

    if [[ -n "$name" ]] && spec="$(gp_get "$name")"; then
        read -r def_user def_host def_proto <<<"$spec"
        def_proto="${def_proto:-ssh}"
    fi

    while [[ -z "$name" ]]; do
        read -r -p "Profile name (e.g. arbeit, privat): " in_name < /dev/tty
        if gp_valid_name "$in_name"; then
            name="$in_name"
        else
            gp_err "Use letters, digits and underscore only (must not start with a digit)"
        fi
    done

    while :; do
        read -r -p "Git user/organisation${def_user:+ [$def_user]}: " in_user < /dev/tty
        in_user="${in_user:-$def_user}"
        [[ -n "$in_user" ]] && break
        gp_err "The git user cannot be empty"
    done

    while :; do
        read -r -p "Host - SSH alias from ~/.ssh/config, or hostname for https${def_host:+ [$def_host]}: " in_host < /dev/tty
        in_host="${in_host:-$def_host}"
        [[ -n "$in_host" ]] && break
        gp_err "The host cannot be empty"
    done

    while :; do
        read -r -p "Protocol ssh/https [${def_proto}]: " in_proto < /dev/tty
        in_proto="${in_proto:-$def_proto}"
        case "$in_proto" in
            ssh|https) break ;;
            *) gp_err "Enter 'ssh' or 'https'" ;;
        esac
    done

    echo ""
    gp_say "Profile '$name': $(gp_field_preview "$in_user" "$in_host" "$in_proto")"
    gp_write "$name" "$in_user" "$in_host" "$in_proto"

    GP_LAST_NAME="$name"
    return 0
}

# Show what a profile will produce, using the current directory as the repo name
gp_field_preview() {
    local user="$1" host="$2" proto="$3" repo
    repo="$(basename "$PWD")"
    case "$proto" in
        https) echo "https://${host}/${user}/${repo}.git" ;;
        *)     echo "${host}:${user}/${repo}.git" ;;
    esac
}

# add [NAME] [USER] [HOST] [PROTO] - prompts for whatever is missing
gp_add() {
    local name="${1:-}" user="${2:-}" host="${3:-}" proto="${4:-}"

    if [[ -n "$name" ]] && ! gp_valid_name "$name"; then
        gp_err "Invalid profile name '$name' - letters, digits and underscore only"
        return 1
    fi
    if [[ -n "$name" ]] && gp_get "$name" >/dev/null; then
        gp_err "Profile '$name' already exists - use 'set profile edit $name'"
        return 1
    fi

    if [[ -n "$name" && -n "$user" && -n "$host" ]]; then
        proto="${proto:-ssh}"
        case "$proto" in
            ssh|https) ;;
            *) gp_err "Protocol must be ssh or https (got '$proto')"; return 1 ;;
        esac
        gp_write "$name" "$user" "$host" "$proto"
        GP_LAST_NAME="$name"
    else
        gp_prompt "$name" || return 1
    fi

    # First profile? Make it the default, otherwise nothing would use it.
    if [[ -z "${GIT_PROFILE:-}" ]]; then
        gp_set_default "${GP_LAST_NAME}"
    fi
    return 0
}

# edit NAME [USER] [HOST] [PROTO]
gp_edit() {
    local name="${1:-}" user="${2:-}" host="${3:-}" proto="${4:-}"
    local cur_user cur_host cur_proto

    if [[ -z "$name" ]]; then
        gp_err "set profile edit NAME  (webwerk get profiles lists them)"
        return 1
    fi
    if ! gp_get "$name" >/dev/null; then
        gp_err "Unknown profile: '$name'"
        gp_list >&2
        return 1
    fi

    if [[ -n "$user" || -n "$host" || -n "$proto" ]]; then
        read -r cur_user cur_host cur_proto <<<"$(gp_get "$name")"
        gp_write "$name" "${user:-$cur_user}" "${host:-$cur_host}" "${proto:-${cur_proto:-ssh}}"
    else
        gp_prompt "$name" || return 1
    fi
    return 0
}

# Resolve the profile to use: explicit name, else GIT_PROFILE. If nothing is
# defined at all, offer to create one right here (that is the only way a clone
# ever gets a URL - there is no built-in default account).
gp_resolve() {
    local name="${1:-${GIT_PROFILE:-}}"

    if [[ -n "$name" ]]; then
        if gp_get "$name" >/dev/null; then
            echo "$name"
            return 0
        fi
        gp_err "Unknown git profile: '$name'"
        local known
        known="$(gp_names | tr '\n' ' ')"
        if [[ -n "${known// /}" ]]; then
            gp_err "Known profiles: ${known% }"
        fi
        return 1
    fi

    # Nothing configured
    if [[ -n "$(gp_names)" ]]; then
        gp_err "No default profile set. Pick one with -G NAME, or:"
        gp_err "    webwerk set profile default NAME"
        gp_list >&2
        return 1
    fi

    if ! gp_have_tty; then
        gp_err "No git profiles defined and no terminal to ask"
        gp_err "Add one to $(gp_env_file):"
        gp_err '    GIT_PROFILE_work="your_git_user your_ssh_host ssh"'
        gp_err "    GIT_PROFILE=work"
        return 1
    fi

    gp_warn "No git profiles defined yet - one is needed to clone wp-content"
    local reply=""
    read -r -p "Create a profile now? [Y/n] " reply < /dev/tty
    case "$reply" in
        n|N|no|NO) gp_err "Cannot clone without a profile"; return 1 ;;
    esac
    gp_prompt "" >&2 || return 1
    if [[ -z "${GIT_PROFILE:-}" ]]; then
        gp_set_default "${GP_LAST_NAME}" >&2
    fi
    echo "${GP_LAST_NAME}"
    return 0
}

# Resolve the local base URL (WordPress siteurl = <base>/<dirname>). There is no
# built-in default host: if it is not configured, ask and save it to the .env,
# the same way a missing git profile is handled.
gp_resolve_base_url() {
    local base="${LOCAL_URL_BASE:-}" reply=""

    if [[ -n "$base" ]]; then
        echo "$base"
        return 0
    fi

    if ! gp_have_tty; then
        gp_err "LOCAL_URL_BASE is not set and there is no terminal to ask"
        gp_err "Add it to $(gp_env_file), e.g.:"
        gp_err "    LOCAL_URL_BASE=netcup.local"
        gp_err "or pass it per run: webwerk install -b netcup.local"
        return 1
    fi

    gp_warn "No local base URL configured (LOCAL_URL_BASE)"
    gp_say "The site URL will be <base>/$(basename "$PWD") - it must match an"
    gp_say "existing nginx/apache vhost with PHP-FPM, e.g. netcup.local"

    while :; do
        read -r -p "Base URL: " reply < /dev/tty
        reply="${reply#http://}"
        reply="${reply#https://}"
        reply="${reply%/}"
        [[ -n "$reply" ]] && break
        gp_err "The base URL cannot be empty"
    done

    gp_env_set LOCAL_URL_BASE "$reply"
    gp_ok "LOCAL_URL_BASE=$reply saved to $(gp_env_file)"
    echo "$reply"
    return 0
}

export -f gp_have_tty gp_env_set gp_resolve_base_url
export -f gp_err gp_say gp_ok gp_warn
export -f gp_env_file gp_names gp_valid_name gp_get gp_field gp_url gp_list
export -f gp_write gp_set_default gp_rm gp_prompt gp_field_preview
export -f gp_add gp_edit gp_resolve
