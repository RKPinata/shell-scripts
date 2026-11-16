import { div } from "gpui-kit";
import { h_flex } from "gpui-base";

// A boxed button: 1 px outline, a face, and a 2 px lip along the bottom. Pressing sinks the face 1 px.
// kind: "secondary" (grey lip), "active" (selected toggle: dark outline, accent lip), "primary" (solid face).
// In a segmented group, `l`/`r` say which side edges this box draws and `rl`/`rr` which sides round,
// so each seam is one 1 px line, dark beside the active box.
// Returns the outer element, so callers can chain `.on_mouse_down`, `.flex_1()` and the like.
// The same file lives in every my-* mod that draws buttons; keep the copies identical.
export function boxy(t, id, content, { kind = "secondary", onClick, h = 24, px = 8, size = 12, gap = 5,
  disabled = false, l = true, r = true, rl = true, rr = true } = {}) {
  const [outline, lip, face, text] = {
    secondary: [t.border, t.selected, t.raised, t.foreground],
    active: [t.foreground, t.accent, t.surface, t.foreground],
    primary: [t.foreground, t.foreground, t.solid, t.solid_foreground],
  }[kind];
  return div().id(id).flex().flex_col().flex_none()
    .border_t(1).border_b(1).border_l(l ? 1 : 0).border_r(r ? 1 : 0).border_color(outline).bg(lip).pb(2)
    .when(rl, e => e.rounded_l(6)).when(rr, e => e.rounded_r(6))
    .when(disabled, e => e.opacity(0.5))
    .when(!disabled && Boolean(onClick), e => e.cursor_pointer().active(s => s.pt(1).pb(1)).on_click(onClick))
    .child(h_flex().id(`${id}-face`).h(h).px(px).gap(gap).items_center().justify_center().text_size(size)
      .when(rl, e => e.rounded_tl(5)).when(rr, e => e.rounded_tr(5))
      .bg(face).text_color(text).when(kind !== "secondary", e => e.font_medium())
      .when(kind === "secondary" && !disabled, e => e.hover(s => s.bg(t.hover)))
      .children(Array.isArray(content) ? content : [content]));
}

// A list row drawn as a card while selected: dark outline, surface face, accent lip along the bottom.
// The lip is a bottom piece rounded like the outline's inner curve; a face covers all of it but the last
// 2 px. Call it before the row's other children, so they paint over the face.
// Call it on every row of the list, selected or not: each gets the same 1 px outline, so selecting a row
// doesn't move its content. `radius`: the row's corners.
export function card(t, el, on, radius = 8) {
  const inner = radius - 1;
  return el.relative().border(1).border_color(on ? t.foreground : "#00000000")
    .when(on, e => e.bg(t.surface)
      .child(div().absolute().left(0).right(0).bottom(0).h(inner).bg(t.accent).rounded_b(inner))
      .child(div().absolute().top(0).left(0).right(0).bottom(2).bg(t.surface).rounded_t(inner)));
}
