// Adapted from herdr-files-plus by jjongkwann (https://github.com/jjongkwann/herdr-files-plus, MIT).
//
// The preview module: the views for a prepared document and the header buttons. main.js loads this
// folder only with import(), so deleting mods/my-filer-pro/preview/ leaves the mod working without a preview.
// Everything in here may import its own files statically; the folder is the unit of removal.
import { div, image, svg } from "gpui-kit";
import { v_flex, h_flex, TextView } from "gpui-base";
import { safeLink, noteText, PREVIEW_MAX_CHARS } from "./prepare.js";
import { fit } from "./images.js";
import { pageLabel, turnTargets, canZoom, SPREAD_GAP } from "./zoom.js";
import { ACTIONS, PDF_CONTEXT } from "../lib/pdfkeys.js";
import { BASE } from "../lib/icons.js";
import { boxy } from "../boxy.js";

export { prepare, prepareAsync } from "./prepare.js";
export { createDiagrams } from "./diagrams.js";
export { createImages } from "./images.js";
export { clearLoads, loadDir, previewJob, loadOutcome, resolveFile } from "./images.js";
export { createPdfs } from "./pdf.js";
export { colorKey } from "./mermaid.js";
export { layout, renderSize, zoomStep, presetOf, canZoom, spreadPages, spreadStart, wheelZoom, RENDER_TIERS, pageLabel, turnTargets } from "./zoom.js";

export const WIDTH_STEP = 32;

// The look of the PDF header controls in one place: glyph files (Lucide, beside main.js), tooltips (also the accessibility
// labels), the icon button (as ui/edit.js: a 14px glyph in a compact box, ../boxy.js) and the segmented controls (joined
// boxes, the chosen one active).
const PDF_UI = {
  glyph: { prev: "chevron-left", next: "chevron-right", out: "minus", in: "plus", single: "rectangle-vertical", spread: "two-pages" },
  tip: { prev: "Previous page", next: "Next page", out: "Zoom out", in: "Zoom in", single: "Single page", spread: "Two pages",
    page: "Fit page", width: "Fit width", actual: "Actual size" },
  label: { page: "Page", width: "Width", actual: "100 %" },
  box: 20, boxPx: 5, glyphSize: 14, gap: 2, textSize: 11,
  // Segmented controls: faces 20px high, icon items px 6 with a 13px glyph, text items px 7.
  seg: { h: 20, iconPx: 6, glyph: 13, textPad: 7 },
  divider: { w: 1, h: 16 },
  counter: { panel: 34, full: 52 }, // min widths, so the buttons around the counter do not move while turning
};

// Document links are untrusted: only web links open, and only on a click.
const onLink = (url, cx) => { const target = safeLink(url); if (target) cx.open_url(target); };

const text = (kind, id, body) => {
  const el = kind === "html" ? TextView.html(id, body) : TextView.markdown(id, body);
  return el.on_link_click(onLink).selectable(true);
};

function diagram(p, i, t, font, width) {
  const d = p.diagram ?? {};
  if (d.path && d.width && d.height) {
    const w = Math.min(d.width, Math.max(80, (width ?? d.width + 32) - 32));
    return div().id(`diagram-${i}`).flex_none().child(image(d.path).w(w).h(w * d.height / d.width));
  }
  return v_flex().id(`diagram-${i}`).flex_none().gap(4).p(10).rounded(6).border_1().border_color(t.border)
    .child(div().text_size(11).text_color(d.error ? t.ansi1 : t.dim).child(d.error ? `Mermaid: ${d.error}` : "Rendering diagram…"))
    .when(Boolean(d.error), (el) => el.child(div().text_size(12).font_family(font).text_color(t.muted).child(p.text)));
}

// One image from the cache (doc.path is relative to the app folder, as image() wants it): as wide as the view minus
// its padding, never wider than the image itself, and the width is reported in steps like the diagram view.
function picture(doc, width, onWidth) {
  const { w, h } = fit(doc.width, doc.height, width);
  return v_flex().id("files-preview").flex_1().min_h(0).overflow_y_scrollbar().px(16).py(10)
    .on_size_change((size, cx) => onWidth(Math.floor(size.width / WIDTH_STEP) * WIDTH_STEP, cx))
    .child(div().id("files-image").flex_none().mx_auto().w(w).child(image(doc.path).w(w).h(h)));
}

// The PDF view (panel and dialog): one page or a spread at the sizes main.js computed (layout() in zoom.js), scrolling both ways.
// The row is centered with mx_auto, NOT with items_center/justify_center on the container: free space is then 0 when the
// pages are wider than the view and the left edge stays reachable by scrolling. The wrapper (as large as the view at least)
// takes the cmd + wheel anywhere in the view; the container's own scrolling is stopped only for cmd. The exact width is
// reported (floored): the fit presets must fill the view without a stray scrollbar; the height gives "page" its room. items: [{ path, w, h }].
function pages(items, handlers, focus) {
  const total = items.reduce((a, i) => a + i.w, 0) + SPREAD_GAP * (items.length - 1), height = Math.max(...items.map((i) => i.h));
  const row = h_flex().id("files-image").flex_none().mx_auto().w(total).h(height).gap(SPREAD_GAP)
    .children(items.map((i) => image(i.path).w(i.w).h(i.h).flex_none()));
  const wrap = v_flex().id("files-pages").flex_none().min_w_full().min_h_full()
    .on_scroll_wheel((e, cx) => { if (!e.modifiers?.platform) return; cx.stop_propagation(); handlers.onWheel(e, cx); })
    .child(row);
  return v_flex().id("files-preview").flex_1().min_h(0).overflow_scrollbar().px(16).py(10)
    .key_context(PDF_CONTEXT)
    .when(Boolean(focus), (el) => el.track_focus(focus))
    .on_action(ACTIONS.in, (_e, cx) => handlers.onZoom("in", cx))
    .on_action(ACTIONS.out, (_e, cx) => handlers.onZoom("out", cx))
    .on_action(ACTIONS.page, (_e, cx) => handlers.onZoom("page", cx))
    .on_size_change((size, cx) => handlers.onWidth(Math.floor(size.width), cx, Math.floor(size.height)))
    .child(wrap);
}

const note = (t, doc) => div().flex_none().text_size(11).text_color(t.dim).child(noteText(doc.limit ?? PREVIEW_MAX_CHARS));

/**
 * The element for a prepared document. `width` is the last reported width (in 32 px steps); `onWidth(width, cx)`
 * is called only for documents with diagrams and images, and only when the step changes.
 */
export function view(doc, { t, font, file, width, pdf }, handlers) {
  const { onWidth } = handlers;
  if (doc.kind === "pdf" && pdf) return pages(pdf.items, handlers, pdf.focus);
  if (doc.kind === "image" || doc.kind === "pdf") return picture(doc, width, onWidth);
  if (!doc.diagrams) {
    const part = doc.parts[0] ?? { kind: doc.kind, text: "" };
    return v_flex().id("files-preview").flex_1().min_h(0).px(16).py(10).gap(6)
      .child(text(part.kind, `preview-${file}`, part.text).scrollable(true).flex_1().min_h(0))
      .when(doc.truncated, (el) => el.child(note(t, doc)));
  }
  return v_flex().id("files-preview").flex_1().min_h(0).overflow_y_scrollbar().px(16).py(10).gap(10)
    .on_size_change((size, cx) => onWidth(Math.floor(size.width / WIDTH_STEP) * WIDTH_STEP, cx))
    .children(doc.parts.map((p, i) => (p.kind === "mermaid" ? diagram(p, i, t, font, width) : text("markdown", `preview-${file}-${i}`, p.text))))
    .when(doc.truncated, (el) => el.child(note(t, doc)));
}

/** The header buttons: Preview/Source (names the view you switch to) and Open in browser (local HTML only). */
const button = (id, label, t, onClick) => boxy(t, id, label, { h: 20, px: 7, size: 11, onClick });

// One icon button of the PDF header. A dimmed button (nothing to do) has no click; `active` marks a switched-on toggle.
function iconButton(t, id, key, tip, { enabled = true, active = false } = {}, onClick = null) {
  const u = PDF_UI;
  return boxy(t, id, svg(`${BASE}/${u.glyph[key]}.svg`).size(u.glyphSize).flex_none(),
    { kind: active ? "active" : "secondary", h: u.box, px: u.boxPx, disabled: !enabled, onClick: enabled ? (_e, cx) => onClick(cx) : null })
    .tooltip(tip).accessibility_label(tip);
}

// A segmented control: one group of joined boxes, each seam one line. segs: [{ id, tip, glyph | label, on, click }].
function segmented(t, id, segs) {
  const g = PDF_UI.seg, on = segs.findIndex((s) => s.on), last = segs.length - 1;
  return h_flex().id(id).flex_none().items_center()
    .children(segs.map((s, i) => boxy(t, s.id, s.glyph ? svg(`${BASE}/${PDF_UI.glyph[s.glyph]}.svg`).size(g.glyph).flex_none() : s.label, {
      kind: s.on ? "active" : "secondary", h: g.h, px: s.glyph ? g.iconPx : g.textPad, size: PDF_UI.textSize, onClick: (_e, cx) => s.click(cx),
      l: i === 0 || i === on, r: i !== on - 1, rl: i === 0, rr: i === last,
    }).tooltip(s.tip).accessibility_label(s.tip)));
}

// A thin vertical line between the header groups of the dialog.
const divider = (t) => div().w(PDF_UI.divider.w).h(PDF_UI.divider.h).flex_none().bg(t.border);

/**
 * The header buttons of a document. PDF model: { page, pages, full (the dialog), spread, percent (effective), preset
 * ("page" | "width" | "actual" | null) }; handlers: onPage(n, cx), onZoom("in" | "out" | "page" | "width" | "actual", cx),
 * onLayout(spread, cx). The layout and zoom controls belong to the dialog only; the panel has the page buttons.
 */
export function tools(doc, { mode, canOpen, page, pages, full, spread, percent, preset }, t, { onToggle, onOpen, onPage, onZoom, onLayout }) {
  if (doc.kind === "image") return [];
  if (doc.kind === "pdf") {
    // Previous · "3 / 12" · Next; a button at its end is dimmed and has no click. main.js owns page and pages.
    const two = Boolean(full && spread), to = turnTargets(page, pages, two), u = PDF_UI;
    const out = [
      iconButton(t, "files-page-prev", "prev", u.tip.prev, { enabled: to.prev > 0 }, (cx) => onPage(to.prev, cx)),
      div().id("files-page-count").flex_none().min_w(full ? u.counter.full : u.counter.panel).text_center().text_size(u.textSize).text_color(t.muted).child(pageLabel(page, pages, two)),
      iconButton(t, "files-page-next", "next", u.tip.next, { enabled: to.next > 0 }, (cx) => onPage(to.next, cx)),
    ];
    if (full) {
      const can = canZoom(percent), pre = (key) => ({ id: `files-zoom-${key}`, tip: u.tip[key], label: u.label[key], on: preset === key, click: (cx) => onZoom(key, cx) });
      out.push(
        divider(t),
        segmented(t, "files-layout", [
          { id: "files-layout-single", tip: u.tip.single, glyph: "single", on: !spread, click: (cx) => onLayout(false, cx) },
          { id: "files-layout-spread", tip: u.tip.spread, glyph: "spread", on: Boolean(spread), click: (cx) => onLayout(true, cx) },
        ]),
        divider(t),
        segmented(t, "files-zoom-presets", [pre("page"), pre("width"), pre("actual")]),
        h_flex().id("files-zoom-tools").flex_none().gap(u.gap).items_center().children([
          iconButton(t, "files-zoom-out", "out", u.tip.out, { enabled: can.out }, (cx) => onZoom("out", cx)),
          div().id("files-zoom-level").flex_none().min_w(u.counter.panel).text_center().text_size(u.textSize).text_color(t.muted).child(`${percent} %`),
          iconButton(t, "files-zoom-in", "in", u.tip.in, { enabled: can.in }, (cx) => onZoom("in", cx)),
        ]),
      );
    }
    return out;
  }
  const out = [button("files-mode", mode === "preview" ? "Source" : "Preview", t, (_e, cx) => onToggle(cx))];
  if (doc.kind === "html" && canOpen) out.push(button("files-browser", "Open in browser", t, (_e, cx) => onOpen(cx)));
  return out;
}

/** The hint for a file over the size limit, with the Load button (main.js lifts the limit on a click). */
export function largeNote(text, t, onLoad) {
  return v_flex().id("files-preview").flex_1().min_h(0).p(12).gap(8).items_start()
    .child(div().text_color(t.dim).child(text))
    .child(button("files-load", "Load", t, (_e, cx) => onLoad(cx)));
}
