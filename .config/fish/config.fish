if status is-interactive && type -q fastfetch
    set -U fish_greeting ""
    fastfetch
    # Commands to run in interactive sessions can go here
end



# Aplicar pywal sequences al iniciar cada shell interactiva
if test -f $HOME/.cache/wal/sequences
    if test -w /dev/tty
        cat $HOME/.cache/wal/sequences > /dev/tty 2>/dev/null
    end
end

