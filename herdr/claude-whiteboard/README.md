# claude-whiteboard

Each Claude session gets a markdown whiteboard. Claude rewrites it when an explanation is
worth keeping in view, and the Whiteboard panel in Herdr shows the focused session's board,
with mermaid diagrams drawn.

```
Claude session ──SessionStart hook──▶ board.sh ─▶ ~/.claude/whiteboards/<repo>/<session-id>.md
      │                                          ~/.claude/whiteboards/.terminals/<HC_TERMINAL_ID>  (holds the board path)
      └─ context: board path; the whiteboard skill, loaded on demand, says how to write it

Herdr panel (mod) ── every 500 ms: focused terminal ─▶ pointer ─▶ board ─▶ render
```

## Install

```sh
./install.sh
```

It copies `mod/` to `~/.config/herdr-app/mods/claude-whiteboard`, then adds this folder as
the `claude-whiteboard` marketplace and installs the plugin. Run it again after editing
either part.

The plugin loads in place from `plugin/`, so an edit there takes effect at the next session start or after `/reload-plugins`. The mod needs `./install.sh` again.

## The board path

`plugin/skills/whiteboard/board.sh [session-id] [cwd]` prints the board path, creates its folder and writes the `.terminals` link. It defaults to `$CLAUDE_CODE_SESSION_ID` and `$PWD`. The SessionStart hook calls it, and the skill tells Claude to run it when the session has no "Your whiteboard file:" line, as after `/reload-plugins`.

The mod is copied, not linked: Herdr resolves a symlinked mod to its real path, so it never
hot-reloads it.

## The panel

The `danish` layout has a `whiteboard` block in the `panel-body` stack, and
`my-annotator-tabs` draws its Whiteboard button from that block. Both files live in
`~/.config/herdr-app`, outside this repo.

The panel shows the board of the focused terminal. A terminal with no board, such as a
plain shell or the panel itself, leaves the last board on screen.

The board is editable. A click on a block (a paragraph, a heading, a top-level list item, a
table) swaps it for a textarea of its markdown, in an accent frame; a diagram has an Edit
button. ⌘↵, Esc or Save writes it back; Cancel drops it. "+ Add a block" appends one. The
panel stops reloading while a block is open. A save finds the block in the file as it is
then, and refuses when the block is gone or appears twice (`mod/blocks.js`).

Task-list items (`- [ ]`, `- [x]`) show as checkboxes. A click writes the new state into
the board file (`mod/tasks.js`). When the file's item no longer matches what the panel
shows, nothing is saved and the panel header says why.

A block takes comments for the session. The pointer over a block shows a Comment button; a
diagram has one beside Edit. It opens a comment box under the block. Queue, or ⌘↵, keeps the
comment in the board's queue, and the header counts them; a click on the count lists them,
each with Edit and a delete button. Edit, or the Comment button of a block that has a queued
comment, opens the box on that comment, and Save replaces it. Send, in the box for one
comment or in the list for all, pastes one
message into the session's terminal with `hc send`. The message quotes each block and names
its section (`mod/comments.js`).

Send is off unless the session's agent is idle or done. A working agent would stack the
message in its own queue, and a terminal whose agent quit would run it in its shell.

The queues live in the panel's memory, one per terminal, 20 comments at most. A queue goes
when its comments are sent, when its terminal starts a new session or closes, and when
Herdr restarts.

Tests: `node --test tests/*.test.mjs`.

Zoom, or a click on a diagram, opens it in a dialog with filer-pro's zoom steps: −, +,
Fit, Width, 100 % and cmd + scroll, which zooms at the pointer. Drag or scroll to move the
diagram in any direction; 80px of it always stays in view. Esc closes the dialog.

## Rendering

`mod/vendor/filer-pro` is a copy of the preview code from the `my-filer-pro` mod: markdown
through gpui-kit's `TextView`, and mermaid through beautiful-mermaid, which runs in Node
(`bin/render-mermaid.mjs`). Herdr does not let one mod import another mod's files, so the
code is copied. `lib/icons.js` sets `BASE` to the copy's path; keep that line when you
refresh the copy.

Herdr's `PATH` has no fnm Node, so the mod passes fnm's default Node to the renderer. The
filer-pro `node_path` setting overrides it.
