# inshellisense matches specs by the literal command name. It ignores the
# --wraps fish puts on an alias function and does not read the alias body, so
# its git spec never matches and argument suggestions (branches, files) stay
# empty. Expanding each shortcut in the buffer gives the spec the command it
# needs. The alias functions remain for non-interactive use.
#
# The list comes from config/shell/aliases.sh so a git shortcut is written in
# one place.

for line in (string match --regex --entire "^alias [a-zA-Z0-9_-]+='git(?: |')" <$HOME/scripts/config/shell/aliases.sh)
    set -l name (string replace --regex "^alias ([a-zA-Z0-9_-]+)=.*" '$1' -- $line)
    set -l body (string replace --regex "^alias [a-zA-Z0-9_-]+='(.*)'\$" '$1' -- $line)
    abbr --add $name --position command (string split ' ' -- $body)
end

# git alias: co = checkout
abbr --add co --command git checkout
