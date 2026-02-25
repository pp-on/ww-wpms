# Fish completion for "ddev wp"
# Adapts WP-CLI's completion API for use with "ddev wp ..."

function __fish_ddev_wp_complete
    # Get line up to cursor and replace "ddev wp" with "wp" for WP-CLI's API
    set -l cmdline (commandline -cp)
    set -l wp_line (string replace -r '^ddev\s+wp' 'wp' -- $cmdline)
    set -l point (string length -- $wp_line)
    set -l opts (ddev wp cli completions --line=$wp_line --point=$point 2>/dev/null)

    if string match -q "*<file>*" -- $opts
        printf "%s\n" (commandline -ct | string match -e '*')
    else if test -z "$opts"
        return
    else
        printf "%s\n" $opts
    end
end

complete -c ddev -n "__fish_seen_subcommand_from wp" -f -a "(__fish_ddev_wp_complete)"
