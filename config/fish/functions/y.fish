# yazi, exiting into the directory it was left in.
function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    command yazi $argv --cwd-file="$tmp"

    if read -z cwd <"$tmp"
        set cwd (string trim -r -c \n -- $cwd)
        if [ "$cwd" != "$PWD" ]; and test -d "$cwd"
            builtin cd -- "$cwd"
        end
    end

    command rm -f -- "$tmp"
end
