// The whiteboard of the focused Claude session. Markdown and mermaid render through filer-pro's preview, vendored in ./vendor/filer-pro.
import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex, TextView, Textarea, TextareaState, Popover, ScrollHandle } from "gpui-base";
import { focused, panes, agents, terminals, shared, exec, hc, readTextFile, writeTextFile, theme, settings, appHome, home, props, openOverlay, closeOverlay } from "herdr";
import * as fs from "fs/promises";
import * as preview from "./vendor/filer-pro/preview/index.js";
import { safeLink } from "./vendor/filer-pro/preview/prepare.js";
import { boxy } from "./vendor/filer-pro/boxy.js";
import { splitTasks, toggleTask } from "./tasks.js";
import { splitBlocks, replaceBlock } from "./blocks.js";
import { sectionOf, formatMessage } from "./comments.js";

// The plugin's SessionStart hook writes boards here, and one pointer file per terminal in .terminals/.
const BOARDS = `${home()}/.claude/whiteboards`;
// Herdr's PATH has no fnm Node; the vendored renderer tries `node` and Homebrew's when this is missing.
const FNM_NODE = `${home()}/.local/share/fnm/aliases/default/bin/node`;

// Document links are untrusted: only web links open, and only on a click.
// on_size_change and mouse positions are in window px; sizes the mod sets are scaled by Herdr's zoom.
const uiZoom = () => Number(settings().zoom) || 1;

// Part of a diagram that panning always leaves in the zoom dialog's view, px.
const KEEP = 80;

// Comments one board can hold unsent; it also bounds the message that carries them.
const MAX_QUEUE = 20;
// The queue's list: the height at which it starts to scroll, and the space between two comments, px.
const QUEUE_MAX_H = 360, QUEUE_GAP = 6;

// Icon paths start at Herdr's home, where install.sh copies the mod.
const COMMENT_ICON = "mods/claude-whiteboard/comment.svg";
const TRASH_ICON = "mods/claude-whiteboard/trash.svg";

// Why hc refused a send: it reports `{"error":{"message"}}` on stderr when no person reads it.
const refusal = (stderr) => {
  try { return JSON.parse(stderr).error.message; } catch { return stderr.trim().split("\n")[0] || "herdr-core refused"; }
};

// A link click stays with the link, so the block around it does not open for editing.
const onLink = (url, cx) => { cx.stop_propagation(); const target = safeLink(url); if (target) cx.open_url(target); };


export default class Whiteboard extends View {
  init(_props, cx) {
    if (props()?.view === "zoom") {
      this.zoomed = props(); this.zoom = "page"; this.acc = 0; this.viewW = 0; this.viewH = 0;
      return;
    }
    this.seen = null; // last focused terminal
    this.terminal = null; // terminal whose board is shown
    this.path = null;
    this.text = null;
    this.doc = null;
    this.width = 0;
    this.queues = new Map(); // terminal → { path, items }: comments on that terminal's board, not sent yet
    this.scroll = ScrollHandle.new(); // the board's scroll position, to bring a queued comment's block into view
    this.refresh(cx);
    // shortcut: polls focus and re-reads the pointer and board each tick (two small reads); move to
    // watchFolder if the polling ever shows up as a cost.
    cx.timer.every(500, (cx) => {
      const terminal = focused()?.terminal ?? null;
      if (terminal) this.seen = terminal;
      this.refresh(cx);
      if (this.doc?.diagrams && this.colorKey !== preview.colorKey(theme())) this.renderDiagrams(cx);
    });
  }

  // Shows the focused terminal's board; a terminal without one (a shell, this pane) keeps the last board.
  // Before any board is shown, the terminals of the focused tab are tried, so a pane opened beside a session finds it.
  // Paused while a block is edited or commented on, so the block keeps its place; a save checks the file instead.
  refresh(cx) {
    if (this.busy || (this.editing && !this.editing.saved) || this.commenting) return;
    this.busy = true;
    const tab = focused()?.tab;
    const candidates = this.seen ? [this.seen] : this.path ? [] : panes().filter((p) => p.tab === tab && p.terminal).map((p) => p.terminal);
    cx.spawn(async (cx) => {
      try { await this.load(cx, candidates); } finally { this.busy = false; }
    });
  }

  async load(cx, candidates) {
    for (const terminal of candidates) {
      const pointer = (await readTextFile(`${BOARDS}/.terminals/${terminal}`))?.trim();
      if (!pointer) continue;
      // A terminal's new session has a new board; the comments on the old one go with it.
      if (this.queues.get(terminal)?.path !== pointer) this.queues.delete(terminal);
      this.terminal = terminal; this.path = pointer;
      break;
    }
    if (!this.path) return;
    const path = this.path, text = await readTextFile(path);
    if (text === this.text && path === this.shownPath && (this.doc || !text)) return;
    this.text = text; this.shownPath = path; this.error = null;
    this.doc = text ? await this.prepare(text, cx) : null;
    if (this.text !== text) return;
    if (this.editing?.saved) this.stopEdit(cx);
    if (this.doc?.diagrams) this.renderDiagrams(cx);
    cx.notify();
  }

  // { blocks, parts, diagrams }: each block of splitBlocks with its prepared parts, and all parts in order.
  // Each task gets its position among all tasks of the board, which is its position in the file:
  // mermaid parts are fences there, so they hold no tasks. Null when another text replaced this one.
  async prepare(text, cx) {
    const blocks = splitBlocks(text), parts = [];
    let diagrams = 0, n = 0;
    for (const b of blocks) {
      const d = await preview.prepareAsync(b.text, { kind: "markdown", mermaid: true }, { sleep: () => cx.sleep(1), alive: () => this.text === text });
      if (!d) return null;
      b.parts = d.parts; diagrams += d.diagrams;
      for (const p of d.parts) {
        parts.push(p);
        if (p.kind !== "markdown") continue;
        p.runs = splitTasks(p.text);
        for (const r of p.runs) if (r.kind === "task") r.n = n++;
      }
    }
    return { blocks, parts, diagrams };
  }

  renderDiagrams(cx) {
    const doc = this.doc, t = theme(), key = preview.colorKey(t);
    this.colorKey = key;
    this.diagrams ??= preview.createDiagrams({ exec, readTextFile, writeFile: fs.writeFile, mkdir: fs.mkdir, unlink: fs.unlink, appHome, now: Date.now });
    cx.spawn(async (cx) => {
      const node = shared("filer-pro.settings")?.config?.node_path || (await fs.exists(FNM_NODE) ? FNM_NODE : "");
      await this.diagrams.renderAll(doc.parts, t, () => this.doc === doc && this.colorKey === key, () => cx.notify(), { node });
      cx.notify();
    });
  }

  body(t) {
    if (!this.path) return div().p(16).text_color(t.dim).child("Focus a Claude session to see its whiteboard.");
    if (!this.text) return div().p(16).text_color(t.dim).child("This session has no whiteboard yet.");
    if (!this.doc) return TextView.markdown(`board-${this.path}`, this.text).selectable(true).scrollable(true).flex_1().min_h(0).px(16).py(10);
    const blocks = this.doc.blocks, ed = this.editing, isNew = ed && !blocks.includes(ed.block);
    // A composer whose block a reload replaced as it opened goes below the blocks.
    const com = this.commenting, loose = com && !blocks.includes(com.block);
    // A list item right after another sits close to it, as in one list.
    const gap = (i) => i === 0 ? 0 : blocks[i].list && blocks[i - 1].list ? 2 : 8;
    const end = this.text.split("\n").length;
    return v_flex().id("board").flex_1().min_h(0).overflow_y_scrollbar().track_scroll(this.scroll).px(10).py(10)
      .on_size_change((size, cx) => { const w = Math.floor(size.width / uiZoom() / 32) * 32; if (w !== this.width) { this.width = w; cx.notify(); } })
      .children(blocks.map((b, i) => ed?.block === b ? this.editor(t, gap(i)) : com?.block === b ? this.composer(t, gap(i)) : this.block(b, i, gap(i), t)))
      .when(Boolean(loose), (el) => el.child(this.composer(t, 8)))
      .child(isNew ? this.editor(t, 8)
        : h_flex().id("add-block").flex_none().mt(8).px(6).py(4).rounded(4).cursor_pointer().text_size(12).text_color(t.dim)
          .hover((s) => s.bg(t.hover).text_color(t.muted)).child("+ Add a block")
          .on_click((_e, cx) => this.edit({ start: end, end, text: "", list: false, parts: [] }, cx)));
  }

  // A block as rendered. A click edits it, and the pointer over it shows a Comment button; a diagram block has
  // Comment and Edit buttons instead, so a click on the diagram still zooms. An accent bar marks a block with a queued comment.
  block(b, i, gap, t) {
    const diagram = b.parts.some((p) => p.kind === "mermaid"), queued = this.queue().some((q) => q.text === b.text);
    return v_flex().id(`block-${i}`).relative().flex_none().gap(10).mt(gap).px(6).py(2).rounded(4)
      .when(!diagram, (el) => el.cursor_text().hover((s) => s.bg(t.hover)).on_click((_e, cx) => this.edit(b, cx))
        .on_hover((over, cx) => {
          const next = over ? i : this.hover === i ? null : this.hover;
          if (next !== this.hover) { this.hover = next; cx.notify(); }
        }))
      .children(b.parts.map((p, k) => p.kind === "mermaid" ? this.diagram(p, `${i}-${k}`, t, b) : this.markdown(p, `${i}-${k}`, t)))
      .when(queued, (el) => el.child(div().absolute().left(0).top(2).bottom(2).w(2).rounded(1).bg(t.accent)))
      .when(!diagram && this.hover === i, (el) => el.child(boxy(t, `block-${i}-comment`, svg(COMMENT_ICON).size(13).text_color(queued ? t.accent : t.muted),
        { h: 20, px: 5, onClick: (_e, cx) => { cx.stop_propagation(); this.comment(b, cx); } })
        .absolute().top(0).right(4).tooltip(queued ? "Edit comment" : "Comment").accessibility_label(queued ? "Edit the comment on this block" : "Comment on this block")));
  }

  // The comments queued for the shown board.
  queue() {
    const q = this.queues.get(this.terminal);
    return q?.path === this.path ? q.items : [];
  }

  // Whether the board's session waits for input, so a message becomes its next turn. A working agent would
  // stack the message in its own queue, and a terminal whose agent quit would run it in its shell.
  ready() {
    const status = agents().find((a) => a.address === this.terminal && a.app)?.status;
    return status === "idle" || status === "done" ? status : null;
  }

  // The block being commented on: an accent frame around the block as rendered, a textarea for the comment, and buttons
  // to queue it or to send it alone. On a queued comment, the queue button saves the new text and Send takes it out of the queue.
  composer(t, gap) {
    const c = this.commenting, terminal = this.terminal, btn = { h: 18, px: 6, size: 11 };
    const empty = !c.state.value().trim(), full = !c.item && this.queue().length >= MAX_QUEUE, ready = this.ready();
    const [status, color] = this.sending ? ["Sending…", t.muted]
      : full ? ["Queue full: send or remove one", t.ansi1]
      : ready ? [`⌘↵ ${c.item ? "saves" : "queues"} · Esc cancels`, t.accent]
      : ["The session is not waiting for input: queue the comment", t.muted];
    return v_flex().id("commenting").flex_none().mt(gap).gap(6).p(6).rounded(6).border_1().border_color(t.border).bg(t.raised)
      .on_key_down((e, cx) => { if (e.key === "escape") { cx.stop_propagation(); this.stopComment(cx); } })
      // The block reads as a quote, dimmed behind a bar; the comment is typed in a field of its own.
      .child(v_flex().flex_none().gap(10).pl(8).border_l(2).border_color(t.border).opacity(0.7)
        .children(c.block.parts.map((p, k) => p.kind === "mermaid" ? this.diagram(p, `c-${k}`, t, null) : this.markdown(p, `c-${k}`, t))))
      .child(h_flex().flex_none().items_start().gap(6).px(8).py(6).rounded(6).border_1().border_color(t.accent).bg(t.background)
        .child(svg(COMMENT_ICON).size(13).flex_none().mt(3).text_color(t.accent))
        .child(Textarea.new(c.state).flex_1().min_w(0).text_size(13)))
      .child(h_flex().flex_none().gap(6).items_center()
        .child(div().flex_1().truncate().text_size(11).text_color(color).child(status))
        .child(boxy(t, "comment-cancel", "Cancel", { ...btn, disabled: this.sending, onClick: (_e, cx) => this.stopComment(cx) }))
        .child(boxy(t, "comment-send", "Send", { ...btn, disabled: empty || !ready || this.sending,
          onClick: (_e, cx) => this.send([this.commentItem()], cx, (cx) => { if (c.item) this.unqueue(terminal, [c.item]); this.stopComment(cx); }) }))
        .child(boxy(t, "comment-queue", c.item ? "Save" : "Queue", { ...btn, kind: "primary", disabled: empty || full || this.sending, onClick: (_e, cx) => this.enqueue(cx) })));
  }

  // Opens the composer on a block, with the block's queued comment when it has one. A click while a block is
  // edited saves that one instead. A composer with unsaved text stays where it is.
  comment(b, cx, item = this.queue().find((q) => q.text === b.text)) {
    const c = this.commenting;
    if (!this.doc || this.saving || this.sending || (c && c.state.value().trim() !== (c.item?.comment ?? ""))) return;
    if (this.editing) { this.commit(cx); return; }
    c?.state.release();
    const state = TextareaState.new({ placeholder: "Comment on this block", value: item?.comment ?? "", rows: 1 });
    if (item) state.set_value(item.comment);
    state.set_auto_grow(1, 12);
    state.on("submit", (e, cx) => { if (e.secondary && !e.shift) this.enqueue(cx); });
    // The buttons are off while the comment is empty.
    state.on("change", (_e, cx) => cx.notify());
    this.commenting = { block: b, item, section: item?.section ?? sectionOf(this.doc.blocks, this.doc.blocks.indexOf(b)), state };
    this.error = null;
    state.focus();
    cx.notify();
  }

  // Opens the composer on a queued comment and brings it into view. A block that the board no longer holds
  // is shown as it was, below the blocks.
  editQueued(item, cx) {
    const blocks = this.doc?.blocks ?? [], i = blocks.findIndex((b) => b.text === item.text);
    this.comment(i < 0 ? item.block : blocks[i], cx, item);
    if (this.commenting?.item !== item) return;
    this.queueOpen = false;
    this.scroll.scroll_to_item(i < 0 ? blocks.length : i);
  }

  // The composer's comment as the queue keeps it; `block` is the block as rendered when the comment was written.
  commentItem() {
    const c = this.commenting;
    return { section: c.section, text: c.block.text, comment: c.state.value().trim(), block: c.block };
  }

  // Puts the composer's comment in the board's queue, in place of the queued comment it was opened on.
  // Queues of terminals that are gone leave the Map here, so it holds no more queues than there are terminals.
  enqueue(cx) {
    const c = this.commenting;
    if (!c || this.sending) return;
    const item = this.commentItem(), terminal = this.terminal;
    if (!item.comment) return;
    if (c.item && this.queue().includes(c.item)) { c.item.comment = item.comment; this.stopComment(cx); return; }
    if (this.queue().length >= MAX_QUEUE) return;
    const live = new Set(terminals().map((x) => x.address));
    if (live.size) for (const k of [...this.queues.keys()]) if (k !== terminal && !live.has(k)) this.queues.delete(k);
    const q = this.queues.get(terminal);
    if (q?.path === this.path) q.items.push(item);
    else this.queues.set(terminal, { path: this.path, items: [item] });
    this.stopComment(cx);
  }

  // Takes comments out of a terminal's queue; an empty queue leaves the Map.
  unqueue(terminal, gone) {
    const q = this.queues.get(terminal);
    if (!q) return;
    q.items = q.items.filter((x) => !gone.includes(x));
    if (!q.items.length) { this.queues.delete(terminal); this.queueOpen = false; }
  }

  stopComment(cx) {
    this.commenting?.state.release();
    this.commenting = null;
    cx.notify();
  }

  // Sends comments to the board's session as one message, then calls `sent`. Nothing is sent unless the session
  // waits for input. When hc refuses, the comments stay and a retry is safe; when the call fails or runs out
  // of time, the message may still arrive.
  send(items, cx, sent) {
    if (this.sending || !items.length) return;
    const terminal = this.terminal, status = this.ready();
    if (!status) { this.error = `Not sent: no session waits for input in ${terminal}`; cx.notify(); return; }
    this.sending = true; this.error = null;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        // No `--if idle`: herdr-core keeps a finished agent "done" after Herdr shows it as idle, and has no `--if done`.
        // hc still refuses a terminal that became blocked.
        const r = await hc(["send", terminal, formatMessage(items)]);
        if (r.code === 0) sent(cx);
        else this.error = `Not sent: ${refusal(r.stderr)}`;
      } catch {
        this.error = "Delivery not confirmed: check the session before you send again";
      } finally {
        this.sending = false;
      }
      cx.notify();
    });
  }

  // The header's count of queued comments. It opens and closes the queue, which stays open while more comments are written:
  // each comment with its section and the first line of its block, and one Send for all of them.
  queueButton(t) {
    const items = this.queue(), n = items.length, terminal = this.terminal, ready = this.ready(), btn = { h: 18, px: 6, size: 11 };
    const status = this.sending ? "Sending…" : ready ? "" : "The session is not waiting for input";
    // An item not drawn yet counts as a short one.
    const height = Math.min(QUEUE_MAX_H, items.reduce((sum, x) => sum + (x.h ?? 60), 0) + QUEUE_GAP * (n - 1));
    return Popover.new("queue").open(Boolean(this.queueOpen)).overlay_closable(false).anchor("top_right")
      .on_open_change((open, cx) => { this.queueOpen = open; cx.notify(); })
      .trigger(boxy(t, "queue-open", [svg(COMMENT_ICON).size(12), String(n)], { ...btn, kind: this.queueOpen ? "active" : "secondary" })
        .cursor_pointer().tooltip("Queued comments").accessibility_label(`${n} queued comment${n === 1 ? "" : "s"}`))
      .content(v_flex().id("queue").w(300).mt(6).p(8).gap(8).rounded(8).border_1().border_color(t.border).bg(t.popover)
        .text_size(12).text_color(t.foreground)
        .child(div().flex_none().font_medium().child("Comment queue"))
        // overflow_y_scrollbar scrolls only inside a set height, and the surface has none to share. So the list's
        // height is set from its items, each measured as drawn, up to a limit; at the limit it leaves room for the bar.
        .child(v_flex().id("queue-items").flex_none().h(height).overflow_y_scrollbar().gap(QUEUE_GAP).when(height === QUEUE_MAX_H, (el) => el.pr(10))
          .children(items.map((item, k) =>
          v_flex().id(`queue-item-${k}`).flex_none().gap(4).p(6).rounded(6).bg(t.raised)
            .on_size_change((size, cx) => { const h = Math.ceil(size.height / uiZoom()); if (h !== item.h) { item.h = h; cx.notify(); } })
            .child(h_flex().flex_none().gap(4).items_center()
              .child(div().flex_1().min_w(0).truncate().text_size(11).text_color(t.dim).child([item.section, item.text.split("\n")[0]].filter(Boolean).join(" · ")))
              .child(boxy(t, `queue-edit-${k}`, "Edit", { ...btn, disabled: this.sending, onClick: (_e, cx) => { this.editQueued(item, cx); cx.notify(); } }))
              .child(boxy(t, `queue-remove-${k}`, svg(TRASH_ICON).size(12).text_color(t.muted), { ...btn, disabled: this.sending,
                onClick: (_e, cx) => { this.unqueue(terminal, [item]); cx.notify(); } }).tooltip("Delete").accessibility_label("Delete this comment")))
            .child(div().child(item.comment)))))
        .child(h_flex().flex_none().gap(6).items_center()
          .child(div().flex_1().truncate().text_size(11).text_color(t.muted).child(status))
          .child(boxy(t, "queue-send", `Send ${n}`, { ...btn, kind: "primary", disabled: !ready || this.sending,
            onClick: (_e, cx) => this.send([...items], cx, () => this.unqueue(terminal, items)) }))));
  }

  // The block being edited: an accent frame around a textarea of its markdown, with its state and buttons.
  editor(t, gap) {
    const ed = this.editing, btn = { h: 18, px: 6, size: 11 };
    const [status, color] = ed.saved ? ["Saved", t.accent] : this.saving ? ["Saving…", t.muted]
      : ed.conflict ? ["Not saved: the board changed. Copy your text, then Cancel.", t.ansi1]
      : ["Editing · ⌘↵ or Esc saves", t.accent];
    return v_flex().id("editing").flex_none().mt(gap).gap(6).p(6).rounded(6).border_1().border_color(t.accent).bg(t.raised)
      .on_key_down((e, cx) => { if (e.key === "escape") { cx.stop_propagation(); this.commit(cx); } })
      .child(Textarea.new(ed.state).w_full().text_size(13))
      .child(h_flex().flex_none().gap(6).items_center()
        .child(div().flex_1().truncate().text_size(11).text_color(color).child(status))
        .child(boxy(t, "edit-cancel", "Cancel", { ...btn, disabled: this.saving || ed.saved, onClick: (_e, cx) => this.stopEdit(cx) }))
        .child(boxy(t, "edit-save", "Save", { ...btn, kind: "primary", disabled: this.saving || ed.saved || ed.conflict, onClick: (_e, cx) => this.commit(cx) })));
  }

  // Edits a block of the board; a click while another block is open saves that one instead.
  edit(b, cx) {
    if (this.saving || this.commenting) return;
    if (this.editing) { this.commit(cx); return; }
    const state = TextareaState.new({ value: b.text, rows: 1 });
    state.set_value(b.text);
    state.set_auto_grow(1, 30);
    state.on("submit", (e, cx) => { if (e.secondary && !e.shift) this.commit(cx); });
    this.editing = { block: b, base: this.text, state, conflict: false, saved: false };
    this.error = null;
    state.focus();
    cx.notify();
  }

  // Saves the edited block into the file as it is now. The editor stays, marked Saved, until the file is read back.
  // A block that the file no longer holds exactly once is a conflict: the text stays in the editor and nothing is written.
  commit(cx) {
    const ed = this.editing;
    if (!ed || this.saving || ed.saved || ed.conflict) return;
    const value = ed.state.value(), path = this.path;
    if (value.trimEnd() === ed.block.text.trimEnd()) { this.stopEdit(cx); return; }
    this.saving = true;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        const source = (await readTextFile(path)) ?? "";
        const next = replaceBlock(source, ed.base, ed.block, value);
        if (next == null) ed.conflict = true;
        else { await writeTextFile(path, next, source); ed.saved = true; }
      } catch (e) {
        this.error = `Not saved: ${e?.message ?? e}`;
      } finally {
        this.saving = false;
      }
      this.refresh(cx);
      cx.notify();
    });
  }

  stopEdit(cx) {
    this.editing?.state.release();
    this.editing = null;
    cx.notify();
  }

  // A markdown part; its task-list items become checkboxes that tick the item in the board file.
  markdown(p, i, t) {
    const text = (id, md) => TextView.markdown(id, md).on_link_click(onLink);
    if (!p.runs?.some((r) => r.kind === "task")) return text(`board-${i}`, p.text);
    return v_flex().flex_none().gap(4).children(p.runs.map((r, j) => r.kind === "markdown"
      ? text(`board-${i}-${j}`, r.text)
      : h_flex().flex_none().items_start().gap(8).pl(r.indent * 8)
        .child(h_flex().id(`task-${r.n}`).role("check_box").accessibility_label(`${r.done ? "Done" : "To do"}: ${r.text}`)
          .flex_none().mt(3).size(14).rounded(3).border_1().items_center().justify_center().cursor_pointer()
          .text_size(10).border_color(r.done ? t.accent : t.muted).when(r.done, (el) => el.bg(t.accent).text_color(t.accent_foreground).child("✓"))
          .on_click((_e, cx) => { cx.stop_propagation(); this.toggle(r, cx); }))
        .child(text(`board-${i}-${j}`, r.text).flex_1().min_w(0))));
  }

  // Ticks or unticks the task in the board file. The box changes only when the file is read back.
  // writeTextFile rejects when the file no longer matches the text this panel shows.
  toggle(r, cx) {
    if (this.writing || this.editing || this.commenting) return;
    this.writing = true;
    const path = this.path, text = this.text;
    cx.spawn(async (cx) => {
      try {
        const next = toggleTask(text, r.n, r);
        if (next == null) throw new Error("the board changed, try again");
        await writeTextFile(path, next, text);
      } catch (e) {
        this.error = `Not saved: ${e?.message ?? e}`;
      } finally {
        this.writing = false;
      }
      this.refresh(cx);
      cx.notify();
    });
  }

  // A mermaid part of block b, with buttons to comment on b, to edit it and to zoom the diagram.
  // The comment composer passes no block and gets the diagram alone.
  diagram(p, i, t, b) {
    const d = p.diagram ?? {}, btn = { h: 18, px: 6, size: 11 };
    const buttons = (el) => !b ? el : el
      .child(boxy(t, `diagram-${i}-comment`, "Comment", { ...btn, onClick: (_e, cx) => this.comment(b, cx) }))
      .child(boxy(t, `diagram-${i}-edit`, "Edit", { ...btn, onClick: (_e, cx) => this.edit(b, cx) }));
    if (!(d.path && d.width && d.height)) {
      return v_flex().id(`diagram-${i}`).flex_none().gap(4)
        .child(buttons(h_flex().flex_none().justify_end().gap(4)))
        .child(v_flex().flex_none().gap(4).p(10).rounded(6).border_1().border_color(t.border)
          .child(div().text_size(11).text_color(d.error ? t.ansi1 : t.dim).child(d.error ? `Mermaid: ${d.error}` : "Rendering diagram…"))
          .when(Boolean(d.error), (el) => el.child(div().text_size(12).font_family(settings().font_family).text_color(t.muted).child(p.text))));
    }
    const w = Math.min(d.width, Math.max(80, (this.width || d.width + 32) - 32));
    const title = this.path.slice(BOARDS.length + 1);
    return v_flex().id(`diagram-${i}`).flex_none().gap(4)
      .child(buttons(h_flex().flex_none().justify_end().gap(4))
        .when(Boolean(b), (el) => el.child(boxy(t, `diagram-${i}-zoom`, "Zoom", { ...btn, onClick: () => this.openZoom(d, title) }))))
      .child(div().id(`diagram-${i}-image`).flex_none().cursor_pointer().on_click(() => this.openZoom(d, title))
        .child(image(d.path).w(w).h(w * d.height / d.width)));
  }

  openZoom(d, title) {
    openOverlay({ mod: "claude-whiteboard", props: { view: "zoom", path: d.path, width: d.width, height: d.height, title }, kind: "dialog", width: 0.92, height: 0.92 });
  }

  // The zoom dialog: a canvas with one diagram, zoomed with the buttons or cmd + scroll, panned by dragging or scrolling.
  // The diagram is placed at this.pan (its top left in the view); null centers it.
  zoomView(t) {
    const z = this.zoomed, L = this.zoomLayout(this.zoom), item = L.items[0], can = preview.canZoom(L.percent);
    const pos = this.clampPan(this.pan, item);
    // Zooms so the diagram point under (ax, ay), in view px, stays there; the default is the view's center.
    const setZoom = (next, ax = this.viewW / 2, ay = this.viewH / 2) => {
      const f = this.zoomLayout(next).items[0].w / item.w;
      this.pan = { x: ax - (ax - pos.x) * f, y: ay - (ay - pos.y) * f };
      this.zoom = next;
    };
    const btn = (id, label, onClick, { on = false, enabled = true } = {}) => boxy(t, `zoom-${id}`, label,
      { kind: on ? "active" : "secondary", h: 20, px: 7, size: 11, disabled: !enabled, onClick: enabled ? (_e, cx) => { onClick(); cx.notify(); } : null });
    return v_flex().size_full().bg(t.surface)
      .child(h_flex().flex_none().px(12).py(8).gap(6).items_center().border_b_1().border_color(t.border)
        .child(div().flex_1().truncate().text_size(12).text_color(t.muted).child(z.title))
        .child(div().flex_none().text_size(11).text_color(t.dim).child("drag to move · ⌘ scroll to zoom"))
        .child(btn("out", "−", () => setZoom(preview.zoomStep(this.zoom, L.percent, "out")), { enabled: can.out }))
        .child(div().min_w(44).text_center().text_size(11).text_color(t.muted).child(`${L.percent} %`))
        .child(btn("in", "+", () => setZoom(preview.zoomStep(this.zoom, L.percent, "in")), { enabled: can.in }))
        .child(btn("page", "Fit", () => { this.zoom = "page"; this.pan = null; }, { on: this.zoom === "page" }))
        .child(btn("width", "Width", () => { this.zoom = "width"; this.pan = null; }, { on: this.zoom === "width" }))
        .child(btn("actual", "100 %", () => setZoom(100), { on: this.zoom === 100 }))
        .child(btn("close", "Close", () => closeOverlay(z.overlay))))
      .child(div().id("zoom-view").flex_1().min_h(0).relative().overflow_hidden()
        .when(Boolean(this.drag), (el) => el.cursor_grabbing()).when(!this.drag, (el) => el.cursor_grab())
        .on_size_change((size, cx) => {
          const z = uiZoom(), w = Math.floor(size.width / z), h = Math.floor(size.height / z);
          if (w !== this.viewW || h !== this.viewH) { this.viewW = w; this.viewH = h; cx.notify(); }
        })
        .on_mouse_down("left", (e, cx) => { this.drag = { sx: e.position.x, sy: e.position.y, x: pos.x, y: pos.y }; cx.notify(); })
        .on_mouse_move((e, cx) => {
          if (!this.drag) return;
          const z = uiZoom();
          this.pan = this.clampPan({ x: this.drag.x + (e.position.x - this.drag.sx) / z, y: this.drag.y + (e.position.y - this.drag.sy) / z }, item);
          cx.notify();
        })
        .on_mouse_up("left", (_e, cx) => { this.drag = null; cx.notify(); })
        .on_scroll_wheel((e, cx) => {
          cx.stop_propagation();
          if (e.modifiers?.platform) {
            const r = preview.wheelZoom(this.acc, e);
            this.acc = r.acc;
            const at = e.local_position, z = uiZoom();
            if (r.dir) { setZoom(preview.zoomStep(this.zoom, L.percent, r.dir), at ? at.x / z : undefined, at ? at.y / z : undefined); cx.notify(); }
            return;
          }
          // A mouse wheel reports lines, a trackpad pixels.
          const dx = e.delta_lines ? e.delta_lines.x * 40 : e.delta?.x ?? 0, dy = e.delta_lines ? e.delta_lines.y * 40 : e.delta?.y ?? 0;
          this.pan = this.clampPan({ x: pos.x + dx, y: pos.y + dy }, item);
          cx.notify();
        })
        .child(image(z.path).absolute().left(pos.x).top(pos.y).w(item.w).h(item.h)));
  }

  zoomLayout(zoom) {
    return preview.layout([{ width: this.zoomed.width, height: this.zoomed.height }], zoom, this.viewW, this.viewH);
  }

  // Free panning that keeps at least KEEP px of the diagram on screen; no pan yet centers it.
  clampPan(pan, item) {
    const axis = (p, size, view) => {
      if (p == null) return (view - size) / 2;
      const keep = Math.min(KEEP, size);
      return Math.min(view - keep, Math.max(keep - size, p));
    };
    return { x: axis(pan?.x, item.w, this.viewW), y: axis(pan?.y, item.h, this.viewH) };
  }

  render(cx) {
    const t = theme();
    if (this.zoomed) return this.zoomView(t);
    const name = this.path ? this.path.slice(BOARDS.length + 1) : "Whiteboard";
    // The rounded card every panel tab draws itself in: the layout's radius does not clip a mod's content.
    return v_flex().size_full().min_h(0).overflow_hidden().rounded(10).border_1().border_color(t.border).bg(t.background).text_size(13)
      .child(h_flex().flex_none().px(12).py(6).gap(8).border_b_1().border_color(t.border)
        .child(div().flex_1().truncate().text_color(t.muted).child(name))
        .when(Boolean(this.editing), (el) => el.child(div().flex_none().text_color(t.accent).child("● Editing")))
        .when(Boolean(this.error), (el) => el.child(div().flex_none().text_color(t.ansi1).child(this.error)))
        .when(this.queue().length > 0, (el) => el.child(this.queueButton(t)))
        .child(div().text_color(t.dim).child(this.terminal ?? "")))
      .child(this.body(t));
  }
}
