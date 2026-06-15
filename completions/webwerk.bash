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

    local commands='install update u mod ddev status'
    local update_targets='core plugins plugin themes theme'
    local install_modes='full minimal ddev'
    local ddev_subs='install mod update remove'

    # Helper: check if a word exists in the command line
    _webwerk_has_word() {
        local w
        for w in "${words[@]}"; do [[ "$w" == "$1" ]] && return 0; done
        return 1
    }

    # Determine primary subcommand
    local cmd=''
    local i
    for (( i=1; i<cword; i++ )); do
        case "${words[i]}" in
            install|update|u|mod|ddev|status) cmd="${words[i]}"; break ;;
        esac
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
                        --db-host --db-user --db-password --db-name
                        --wp-url --base-url --wp-title
                        --wp-admin-user --wp-admin-pass --wp-admin-email
                        --repo-url --git-user --git-protocol --git-host
                        --wp-cli --target-dir
                        --nip-io --lemp --lamp --production
                        --multisite --subdomains --debug --help
                        -b -G -n -h
                    ' -- "$cur") )
                    ;;
                *)
                    # Complete mode if not yet given
                    if ! _webwerk_has_word full && ! _webwerk_has_word minimal && ! _webwerk_has_word ddev; then
                        COMPREPLY=( $(compgen -W "$install_modes" -- "$cur") )
                    fi
                    ;;
            esac
            ;;

        update|u)
            case "$prev" in
                -s|--sites|--exclude-plugins|-x) return 0 ;;
                plugin)
                    # plugin name required — no completions
                    return 0 ;;
                theme)
                    # theme name required — no completions
                    return 0 ;;
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
                -s|--sites|-d|--original-dir|-i|--install-plugin|-y|--copy-plugins) return 0 ;;
                -U|--wp-user|-P|--wp-password|-E|--wp-email|-w|--location-wp) return 0 ;;
                -R|--search-replace) return 0 ;;
                --git) COMPREPLY=( $(compgen -W 'pull log' -- "$cur") ); return 0 ;;
                -x|--wp-debug) COMPREPLY=( $(compgen -W 'on off' -- "$cur") ); return 0 ;;
            esac
            COMPREPLY=( $(compgen -W '
                wp ddev
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
                -o --os-detection
                --git -G --git-pull -u --update
                -i --install-plugin
                -y --copy-plugins
                -f --acf-pro-lk
                -m --wp-migrate-db-pro
                --akeeba-license --setup-all-licenses
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
    esac
}

complete -F _webwerk webwerk
