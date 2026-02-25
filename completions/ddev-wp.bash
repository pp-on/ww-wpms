# Bash completion for "ddev wp"
# Adapts WP-CLI's completion API for use with "ddev wp ..."

_ddev_wp_complete() {
    local OLD_IFS="$IFS"
    local cur=${COMP_WORDS[COMP_CWORD]}

    # Replace "ddev wp" with "wp" for WP-CLI's completions API
    local wp_line="${COMP_LINE/#ddev wp/wp}"
    local wp_point=$(( COMP_POINT - ${#COMP_LINE} + ${#wp_line} ))

    IFS=$'\n'
    local opts="$(ddev wp cli completions --line="$wp_line" --point="$wp_point" 2>/dev/null)"

    if [[ "$opts" =~ \<file\>\s* ]]; then
        COMPREPLY=( $(compgen -f -- "$cur") )
    elif [[ -z "$opts" ]]; then
        COMPREPLY=( $(compgen -f -- "$cur") )
    else
        COMPREPLY=( ${opts[*]} )
    fi

    IFS="$OLD_IFS"
    return 0
}

# Wrap existing ddev completion to add "ddev wp" subcommand support
_ddev_with_wp() {
    if [[ "${COMP_WORDS[1]}" == "wp" ]]; then
        _ddev_wp_complete
    else
        # Call through to DDEV's original completion function
        local orig_func
        orig_func=$(complete -p ddev 2>/dev/null | sed -n 's/.*-F \([^ ]*\) ddev.*/\1/p')
        if [[ -n "$orig_func" && "$orig_func" != "_ddev_with_wp" ]]; then
            "$orig_func"
        fi
    fi
}

complete -o nospace -F _ddev_with_wp ddev
