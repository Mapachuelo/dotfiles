if status is-interactive && type -q fastfetch
    set -U fish_greeting ""
    fastfetch
    # Commands to run in interactive sessions can go here
end
