# claude-whiteboard

Each Claude session gets a markdown whiteboard. Claude rewrites it when an explanation is
worth keeping in view, and the Whiteboard panel in Herdr shows the focused session's board,
with mermaid diagrams drawn.

```
Claude session ──SessionStart hook──▶ ~/.claude/whiteboards/<repo>/<session-id>.md
      │                               ~/.claude/whiteboards/.terminals/<HC_TERMINAL_ID>  (holds the board path)
      └─ context: board path; the whiteboard skill, loaded on demand, says how to write it

Herdr panel (mod) ── every 500 ms: focused terminal ─▶ pointer ─▶ board ─▶ render
```

## Install

```sh
./install.sh
```

It copies `mod/` to `~/.config/herdr-app/mods/claude-whiteboard`, then adds this folder as
the `claude-whiteboard` marketplace and installs the plugin. Run it again after editing
either part. New sessions get a board; running sessions do not.

The mod is copied, not linked: Herdr resolves a symlinked mod to its real path, so it never
hot-reloads it.

## The panel

The `danish` layout has a `whiteboard` block in the `panel-body` stack, and
`my-annotator-tabs` draws its Whiteboard button from that block. Both files live in
`~/.config/herdr-app`, outside this repo.

The panel shows the board of the focused terminal. A terminal with no board, such as a
plain shell or the panel itself, leaves the last board on screen.

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
