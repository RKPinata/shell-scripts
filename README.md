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
| `showlocalhost` | Pick servers on `local.respond.io` ports and kill them; `-a` lists every listener | `gum_local_servers.sh` |
| `tree` | Menu over create / switch / delete worktree | `worktree/` |
| `create-tree`, `cd-tree`, `del-tree` | The three worktree actions directly | `worktree/` |
| `y` | yazi; on quit, the shell follows the directory yazi was left in | `config/fish/functions/y.fish` |
| `cdweb`, `cdtest` | Jump to the web and testing repos | `config/fish/config.fish` |

`gm` is `git merge` in fish. Worktree helpers are zsh scripts; fish runs them in a
zsh subprocess and copies the resulting directory back into the fish process.

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

On a new machine:

```sh
ln -s ~/scripts/config/fish/config.fish          ~/.config/fish/config.fish
ln -s ~/scripts/config/fish/functions/y.fish     ~/.config/fish/functions/y.fish
ln -s ~/scripts/config/yazi/yazi.toml            ~/.config/yazi/yazi.toml
ln -s ~/scripts/config/yazi/keymap.toml          ~/.config/yazi/keymap.toml
```

`~/.zshrc`, `~/.config/ghostty/config`, and the `config.fish.*` backups in
`~/.config/fish` are not tracked here.

Worktree scripts have their own README in `worktree/`; the Linear bugfix launcher
has one in `linear/`.
