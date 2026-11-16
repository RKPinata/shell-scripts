// The whiteboard of the focused Claude session. Markdown and mermaid render through filer-pro's preview, vendored in ./vendor/filer-pro.
import { View, div, image } from "gpui-kit";
import { v_flex, h_flex, TextView } from "gpui-base";
import { focused, panes, shared, exec, readTextFile, theme, settings, appHome, home, props, openOverlay, closeOverlay } from "herdr";
import * as fs from "fs/promises";
import * as preview from "./vendor/filer-pro/preview/index.js";
import { safeLink } from "./vendor/filer-pro/preview/prepare.js";
import { boxy } from "./vendor/filer-pro/boxy.js";

// The plugin's SessionStart hook writes boards here, and one pointer file per terminal in .terminals/.
const BOARDS = `${home()}/.claude/whiteboards`;
// Herdr's PATH has no fnm Node; the vendored renderer tries `node` and Homebrew's when this is missing.
const FNM_NODE = `${home()}/.local/share/fnm/aliases/default/bin/node`;

// Document links are untrusted: only web links open, and only on a click.
// on_size_change and mouse positions are in window px; sizes the mod sets are scaled by Herdr's zoom.
const uiZoom = () => Number(settings().zoom) || 1;

// Part of a diagram that panning always leaves in the zoom dialog's view, px.
const KEEP = 80;

const onLink = (url, cx) => { const target = safeLink(url); if (target) cx.open_url(target); };


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
  refresh(cx) {
    if (this.busy) return;
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
      if (pointer) { this.terminal = terminal; this.path = pointer; break; }
    }
    if (!this.path) return;
    const path = this.path, text = await readTextFile(path);
    if (text === this.text && path === this.shownPath && (this.doc || !text)) return;
    this.text = text; this.shownPath = path;
    this.doc = text
      ? await preview.prepareAsync(text, { kind: "markdown", mermaid: true }, { sleep: () => cx.sleep(1), alive: () => this.text === text })
      : null;
    if (this.doc?.diagrams) this.renderDiagrams(cx);
    cx.notify();
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
    return v_flex().id("board").flex_1().min_h(0).overflow_y_scrollbar().px(16).py(10).gap(10)
      .on_size_change((size, cx) => { const w = Math.floor(size.width / uiZoom() / 32) * 32; if (w !== this.width) { this.width = w; cx.notify(); } })
      .children(this.doc.parts.map((p, i) => p.kind === "mermaid"
        ? this.diagram(p, i, t)
        : TextView.markdown(`board-${i}`, p.text).on_link_click(onLink).selectable(true)));
  }

  diagram(p, i, t) {
    const d = p.diagram ?? {};
    if (!(d.path && d.width && d.height)) {
      return v_flex().id(`diagram-${i}`).flex_none().gap(4).p(10).rounded(6).border_1().border_color(t.border)
        .child(div().text_size(11).text_color(d.error ? t.ansi1 : t.dim).child(d.error ? `Mermaid: ${d.error}` : "Rendering diagram…"))
        .when(Boolean(d.error), (el) => el.child(div().text_size(12).font_family(settings().font_family).text_color(t.muted).child(p.text)));
    }
    const w = Math.min(d.width, Math.max(80, (this.width || d.width + 32) - 32));
    const title = this.path.slice(BOARDS.length + 1);
    return v_flex().id(`diagram-${i}`).flex_none().gap(4)
      .child(h_flex().flex_none().justify_end().gap(4)
        .child(boxy(t, `diagram-${i}-zoom`, "Zoom", { h: 18, px: 6, size: 11, onClick: () => this.openZoom(d, title) })))
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
    return v_flex().size_full().bg(t.surface).text_size(13)
      .child(h_flex().flex_none().px(12).py(6).gap(8).border_b_1().border_color(t.border)
        .child(div().flex_1().truncate().text_color(t.muted).child(name))
        .child(div().text_color(t.dim).child(this.terminal ?? "")))
      .child(this.body(t));
  }
}
