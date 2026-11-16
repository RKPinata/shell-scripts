# scripts

Shell helpers and terminal configuration for this machine.

## Two shells

The macOS login shell is zsh, so `~/.zshrc` runs in Terminal, IDE terminals, and
anything that inherits the login shell. Ghostty is set to launch fish directly
(`command = direct:/opt/homebrew/bin/fish` in `~/.config/ghostty/config`), so fish
config runs there and `~/.zshrc` does not.

Anything you want in both places has to be written twice — once in
`config/fish/config.fish`, once in `~/.zshrc` or `shell-integration.zsh`.

## Commands

| Command | What it does | Defined in |
| --- | --- | --- |
| `gmcm` | Guided commit (gum) | `gum_commit.sh` |
| `gmbr` | Guided branch creation (gum) | `gum_create_branch.sh` |
| `gpso` | Push and set upstream; opens a draft PR on `resolve/` and `merge-master-to-*` branches | `git_push_set_origin.sh` |
| `grflight` | Pick a worktree and a flight branch, merge master into the flight on a `resolve/` branch in that worktree, and start Claude there in the same terminal. On approval Claude runs `resolve_flight_finish.sh`: commit, `gpso`, back to the worktree's branch | `gum_resolve_flight.sh` |
| `showlocalhost` | Pick servers on `local.respond.io` ports and kill them; `-a` lists every listener | `gum_local_servers.sh` |
| `cloc [name...\|all] [-- args]` | Start Claude with plugins loaded from local checkouts; no names opens a picker | `claude_local.sh` |
| `cloc add [dir]`, `cloc delete [name...]`, `cloc list` | Manage the plugins in `config/claude/local-plugins` | `claude_local.sh` |
| `cloc install-test [name]` | Install a plugin from a throwaway copy of its marketplace, to try the install flow | `claude_local.sh` |
| `tree` | Menu over create / switch / delete worktree | `worktree/` |
| `create-tree`, `cd-tree`, `del-tree` | The three worktree actions directly | `worktree/` |
| `y` | yazi; on quit, the shell follows the directory yazi was left in | `config/fish/functions/y.fish` |
| `cdweb`, `cdtest`, `cdscripts` | Jump to the web, testing and scripts repos | `config/shell/aliases.sh` |
| `cd- <name>` | Jump to a target from `config/shell/cd-targets`, with tab completion | `shell-integration.zsh`, `config/fish/config.fish` |
| `cd- add` | Browse to a directory in yazi, name it, and add it as a target | `config/shell/cd_add.sh` |
| `cd- delete [name...]` | Remove one or more targets | `config/shell/cd_delete.sh` |

`gm` is `git merge` in fish. Worktree helpers are zsh scripts; fish runs them in a
zsh subprocess and copies the resulting directory back into the fish process.

## cloc

`cloc` passes `--plugin-dir <path>` to `claude` for each plugin you pick, so
Claude loads the plugin from your checkout. Edits show up after
`/reload-plugins`, with no version bump or publish. `config/claude/local-plugins`
lists the plugins, one per line: name, one space, path.

`cloc add` reads the name from `.claude-plugin/plugin.json` in the directory.
Pass extra flags to `claude` after `--`, e.g. `cloc dynamic-interview -- --resume`.

`--plugin-dir` skips the install step, so it never shows the configure dialog
or reads the plugin's `marketplace.json` entry. `cloc install-test <name>` covers
that. It copies the marketplace that holds the plugin to a temp folder, renames
it `<marketplace>-dev`, adds it, and starts Claude on the install screen for
`<name>@<marketplace>-dev`. Changes made after launch are not in the copy. When Claude exits, the script
removes the dev marketplace, which uninstalls the plugin and deletes its options
and data. The real marketplace and its installs are not touched.

Tab completion for `cloc` reads `local-plugins` in three places: `_cloc` in
`shell-integration.zsh`, `complete -c cloc` in `config/fish/config.fish`, and the
inshellisense spec `config/inshellisense/specs/cloc.js`.

## cd-

`cd- <name>` jumps to a directory listed in `config/shell/cd-targets`. Each line
is a name, one space, then the path. The path may contain spaces. Lines starting
with `#` are skipped. Edit the file by hand to rename a target.

`cd- add` opens yazi at `~/Repo`. Browse to the directory and press `q` to pick
it, or `Q` to cancel. A gum prompt then asks you to confirm the path; its default
is No. Last, gum asks for a name, with the folder name as the default. It rejects `add`,
`delete`, names already in the file, and names with characters other than
letters, digits, `.`, `_` or `-`.

`cd- delete <name...>` removes the named targets. With no names, it lists the
targets in a gum filter: tab marks each one to delete, and enter finishes. It then
prints the chosen lines and asks to confirm, with No as the default. An unknown
name stops it before anything is removed. Only the lines in `cd-targets` go; the
directories stay.

Tab completion comes from three places, and all three read `cd-targets`:

- zsh: `_cd-` in `shell-integration.zsh`
- fish: `complete -c cd-` in `config/fish/config.fish`
- the inshellisense popup: `config/inshellisense/specs/cd-.js`

`inshellisense complete "cd- "` crashes. That subcommand skips specs from
`specs.path`, so test the spec in a live shell.

## showlocalhost

`showlocalhost` lists the servers you can reach at `local.respond.io`. The hosts
file points that name at `127.0.0.1`, so a server shows up when it listens on
`127.0.0.1` or on all interfaces. A server bound only to `::1` does not show up.
The webchat's webpack is one; its proxy on the same port does show.

Each row shows the port, the PID, the command, and the directory the process runs
in. The directory tells you which worktree a vite server belongs to. Press space
to mark rows, enter to kill them, and esc to leave without killing anything.

The script sends `SIGTERM` and waits up to 3 seconds. It then asks whether to send
`SIGKILL` to any process still running.

By default only processes whose directory matches `respond-io` are listed, so
apps like Raycast stay off the list. `showlocalhost -a` lists every listener.
`LOCAL_SERVERS_MATCH` sets a different `grep -E` pattern for the directory.

## claude-whiteboard

`herdr/claude-whiteboard/` gives each Claude session a markdown whiteboard, shown in a
Herdr panel. See its README.

## yazi

`F` opens the hovered or selected files in FluxMarkdown. `O` on a markdown file
lists FluxMarkdown as a choice. `Enter` still opens `$EDITOR`.

Placeholders are `%s` and flags come before `--` (`shell -- open -a … %s`). The
older `"$@"` opener form does not work on yazi 26.

## Editors

fish sets `EDITOR` to `fresh` when `GHOSTTY_RESOURCES_DIR` is set, and to
`zed --wait` otherwise. `~/.zshrc` sets `fresh` unconditionally.

## Tracked config

These live in the repo and are symlinked into place:

| Repo path | Link |
| --- | --- |
| `config/fish/config.fish` | `~/.config/fish/config.fish` |
| `config/fish/functions/y.fish` | `~/.config/fish/functions/y.fish` |
| `config/yazi/yazi.toml` | `~/.config/yazi/yazi.toml` |
| `config/yazi/keymap.toml` | `~/.config/yazi/keymap.toml` |
| `config/inshellisense/rc.toml` | `~/.config/inshellisense/rc.toml` |

On a new machine:

```sh
ln -s ~/scripts/config/fish/config.fish          ~/.config/fish/config.fish
ln -s ~/scripts/config/fish/functions/y.fish     ~/.config/fish/functions/y.fish
ln -s ~/scripts/config/yazi/yazi.toml            ~/.config/yazi/yazi.toml
ln -s ~/scripts/config/yazi/keymap.toml          ~/.config/yazi/keymap.toml
ln -s ~/scripts/config/inshellisense/rc.toml     ~/.config/inshellisense/rc.toml
```

`~/.zshrc`, `~/.config/ghostty/config`, and the `config.fish.*` backups in
`~/.config/fish` are not tracked here.

Worktree scripts have their own README in `worktree/`; the Linear bugfix launcher
has one in `linear/`.
