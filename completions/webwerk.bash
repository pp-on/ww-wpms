# Bash completion for webwerk WordPress Management Suite
#
# Install: source this file from ~/.bashrc or drop in /etc/bash_completion.d/

_webwerk() {
    local cur prev words cword
    _init_completion 2>/dev/null || {
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword=$COMP_CWORD
    }

    local commands='install update mod get remove ddev status'
    local update_targets='core plugins plugin themes theme'
    local get_targets='plugins themes core status brief git url db'
    local install_modes='local bare ddev'
    local ddev_subs='install mod update remove'

    # Helper: check if a word exists in the command line
    _webwerk_has_word() {
        local w
        for w in "${words[@]}"; do [[ "$w" == "$1" ]] && return 0; done
        return 1
    }

    # Helper: resolve TOK against WORDS like the dispatcher's resolve_word
    # (exact match wins, else unique prefix: u -> update, dd -> ddev)
    _webwerk_resolve() {
        local tok="$1" w; shift
        local -a m=()
        for w in "$@"; do [[ "$w" == "$tok" ]] && { echo "$w"; return 0; }; done
        for w in "$@"; do [[ "$w" == "$tok"* ]] && m+=("$w"); done
        (( ${#m[@]} == 1 )) && { echo "${m[0]}"; return 0; }
        return 1
    }

    # Helper: complete site dirs (containing wp-content/); comma lists ok
    _webwerk_sites() {
        local prefix='' d
        local -a names=()
        [[ "$cur" == *,* ]] && prefix="${cur%,*},"
        for d in */; do
            [[ -d "${d}wp-content" ]] && names+=("$prefix${d%/}")
        done
        COMPREPLY=( $(compgen -W "${names[*]}" -- "$cur") )
    }

    # Helper: installed plugin/theme names in ./ or ./*/ sites; comma lists ok
    _webwerk_content_names() {
        local kind="$1" prefix='' d
        local -a names=()
        [[ "$cur" == *,* ]] && prefix="${cur%,*},"
        for d in wp-content/"$kind"/*/ */wp-content/"$kind"/*/; do
            [[ -d "$d" ]] || continue
            d="${d%/}"
            names+=("$prefix${d##*/}")
        done
        COMPREPLY=( $(compgen -W "$(printf '%s\n' "${names[@]}" | sort -u)" -- "$cur") )
    }

    # Determine primary subcommand (abbreviations resolve like the dispatcher;
    # legacy 'ddev VERB' resolves to VERB)
    local cmd=''
    local i j sub
    for (( i=1; i<cword; i++ )); do
        [[ "${words[i]}" == -* ]] && continue
        cmd="$(_webwerk_resolve "${words[i]}" install update mod get remove ddev status)" || cmd=''
        if [[ "$cmd" == ddev ]]; then
            for (( j=i+1; j<cword; j++ )); do
                [[ "${words[j]}" == -* ]] && continue
                sub="$(_webwerk_resolve "${words[j]}" install mod update remove)" && cmd="$sub"
                break
            done
        fi
        break
    done

    case "$cmd" in
        '')
            # Top-level: complete commands and global flags
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W '--help --debug' -- "$cur") )
                    ;;
                *)
                    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
                    ;;
            esac
            ;;

        install)
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W '
                        -A -a
                        --db-host --db-user --db-password --db-name
                        --wp-url --base-url --wp-title
                        --wp-admin-user --wp-admin-pass --wp-admin-email --wpu --wpp --wpe --theme
                        --repo-url --git-user --git-protocol --git-host
                        --wp-cli --target-dir
                        --nip-io --lemp --lamp --production
                        --multisite --subdomains -v --verbose --debug --help
                        -b -G -n -h
                        -H -U -P -N -u -t -e -r -g -p -w -d -X -m -s -T
                    ' -- "$cur") )
                    ;;
                *)
                    # Complete mode if not yet given
                    if ! _webwerk_has_word local && ! _webwerk_has_word bare && ! _webwerk_has_word ddev; then
                        COMPREPLY=( $(compgen -W "$install_modes" -- "$cur") )
                    fi
                    ;;
            esac
            ;;

        update)
            case "$prev" in
                -s|--sites) _webwerk_sites; return 0 ;;
                --exclude-plugins|-x) return 0 ;;
                plugin) _webwerk_content_names plugins; return 0 ;;
                theme)  _webwerk_content_names themes;  return 0 ;;
            esac
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W '
                        -a --all-sites
                        -A --all-sites-auto
                        -B --batch
                        -V --progress
                        -s --sites
                        -y --yes-update
                        -c --skip-core
                        -m --minor
                        -g --sum
                        -p --git-push
                        -P --push-only
                        -x --exclude-plugins
                        -h --help
                    ' -- "$cur") )
                    ;;
                *)
                    # Complete target if not yet given
                    local has_target=false
                    for w in "${words[@]}"; do
                        case "$w" in core|plugins|plugin|themes|theme) has_target=true; break ;; esac
                    done
                    if [[ "$has_target" == false ]]; then
                        COMPREPLY=( $(compgen -W "$update_targets" -- "$cur") )
                    fi
                    ;;
            esac
            ;;

        mod)
            case "$prev" in
                -s|--sites) _webwerk_sites; return 0 ;;
                -d|--original-dir|-i|--install-plugin|-y|--copy-plugins) return 0 ;;
                -U|--wp-user|-P|--wp-password|-E|--wp-email|-w|--location-wp) return 0 ;;
                -R|--search-replace) return 0 ;;
                --git) COMPREPLY=( $(compgen -W 'pull log' -- "$cur") ); return 0 ;;
                -x|--wp-debug) COMPREPLY=( $(compgen -W 'on off' -- "$cur") ); return 0 ;;
                theme) COMPREPLY=( $(compgen -W 'webwerk help' -- "$cur") ); return 0 ;;
                plugin) COMPREPLY=( $(compgen -W 'install copy update activate deactivate remove list help' -- "$cur") ); return 0 ;;
                site) COMPREPLY=( $(compgen -W 'license remote url help' -- "$cur") ); return 0 ;;
                license) COMPREPLY=( $(compgen -W 'show set' -- "$cur") ); return 0 ;;
                remote) COMPREPLY=( $(compgen -W 'show add set' -- "$cur") ); return 0 ;;
                url) COMPREPLY=( $(compgen -W 'show set' -- "$cur") ); return 0 ;;
                config) COMPREPLY=( $(compgen -W 'debug errors indexing https htaccess help' -- "$cur") ); return 0 ;;
                debug|indexing) COMPREPLY=( $(compgen -W 'on off' -- "$cur") ); return 0 ;;
                errors) COMPREPLY=( $(compgen -W 'hide show' -- "$cur") ); return 0 ;;
                user) COMPREPLY=( $(compgen -W 'add help' -- "$cur") ); return 0 ;;
                --role) COMPREPLY=( $(compgen -W 'admin editor author contributor subscriber' -- "$cur") ); return 0 ;;
            esac
            COMPREPLY=( $(compgen -W '
                local ddev
                theme plugin site config user
                -a --all-sites
                -A --all-sites-auto
                -s --sites
                -d --original-dir
                -p --print
                -H --health-check
                -C --status
                -B --brief
                -e --errors
                -O --outdated
                -l --list
                -T --themes
                -W --theme-webwerk
                -o --os-detection
                --git -G --git-pull -g --git-status -u --update
                -i --install-plugin
                -y --copy-plugins
                -f --acf-pro-lk
                -m --wp-migrate-db-pro
                -k --akeeba-license --setup-all-licenses
                -n --new-user
                -U --wp-user -P --wp-password -E --wp-email
                -R --search-replace
                -x --wp-debug
                -z --hide-errors
                -r --disable-search-engine-indexing
                --enable-search-engine-indexing
                --htaccess
                -S --force-https
                -w --location-wp
                -h --help
            ' -- "$cur") )
            ;;

        get)
            case "$prev" in
                -s|--sites) _webwerk_sites; return 0 ;;
                --format) return 0 ;;
            esac
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W '-s --sites -a --all-sites --format --errors --outdated -h --help' -- "$cur") )
                    ;;
                *)
                    local has_target=false w
                    for w in "${words[@]}"; do
                        case "$w" in plugins|themes|core|status|brief|git|url|db) has_target=true; break ;; esac
                    done
                    if [[ "$has_target" == false ]]; then
                        COMPREPLY=( $(compgen -W "$get_targets help" -- "$cur") )
                    else
                        COMPREPLY=( $(compgen -W "help" -- "$cur") )
                    fi
                    ;;
            esac
            ;;

        ddev)
            # Check for ddev subcommand
            local ddev_sub=''
            for (( i=2; i<cword; i++ )); do
                case "${words[i]}" in
                    install|mod|update|remove) ddev_sub="${words[i]}"; break ;;
                esac
            done
            if [[ -z "$ddev_sub" ]]; then
                COMPREPLY=( $(compgen -W "$ddev_subs" -- "$cur") )
            fi
            ;;

        remove)
            case "$prev" in
                -s|--sites) _webwerk_sites; return 0 ;;
            esac
            if _webwerk_has_word local; then
                COMPREPLY=( $(compgen -W '-s --sites -a --all-sites -A --all-sites-auto -y --yes' -- "$cur") )
            elif ! _webwerk_has_word ddev; then
                COMPREPLY=( $(compgen -W 'local ddev' -- "$cur") )
            fi
            ;;
    esac
}

complete -F _webwerk webwerk
