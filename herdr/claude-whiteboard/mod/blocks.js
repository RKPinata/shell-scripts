// The blocks of a board that the panel edits one at a time: paragraphs, headings, top-level list items, tables,
// fences. Pure; tests/blocks.test.mjs runs it under Node.

const OPEN_FENCE = /^ {0,3}(`{3,}|~{3,})/;
const CLOSE_FENCE = /^ {0,3}(`{3,}|~{3,})[ \t]*$/;
const HEADING = /^ {0,3}#{1,6}(?:\s|$)/;
const LIST_ITEM = /^(?:[-*+]|\d+[.)])\s/;

/**
 * Splits markdown into blocks of { start, end, text, list }: the lines [start, end) of `text`, and whether the block
 * is a list item. Blank lines between blocks belong to none.
 */
export function splitBlocks(text) {
  const lines = text.split("\n"), blocks = [];
  let cur = null, fence = null;
  const close = (i) => { if (cur) { cur.end = i; cur.text = lines.slice(cur.start, i).join("\n"); blocks.push(cur); cur = null; } };
  lines.forEach((line, i) => {
    if (fence) {
      const c = CLOSE_FENCE.exec(line);
      if (c && c[1][0] === fence[0] && c[1].length >= fence.length) { fence = null; close(i + 1); }
      return;
    }
    if (!line.trim()) { close(i); return; }
    const f = OPEN_FENCE.exec(line);
    if (f) { close(i); fence = f[1]; cur = { start: i, list: false }; return; }
    if (HEADING.test(line)) { close(i); cur = { start: i, list: false }; close(i + 1); return; }
    if (LIST_ITEM.test(line)) { close(i); cur = { start: i, list: true }; return; }
    cur ??= { start: i, list: false };
  });
  close(lines.length);
  return blocks;
}

const trimEnd = (s) => s.replace(/\s+$/, "");

/**
 * `source` with `block` (from splitBlocks of `base`) replaced by `value`. An empty value removes the block; a block with
 * start === end is new and goes at the end. When the file changed since `base`, the block's old text must appear in
 * `source` exactly once, as whole lines; otherwise the result is null.
 */
export function replaceBlock(source, base, block, value) {
  const next = trimEnd(value);
  if (block.start === block.end) return next ? `${trimEnd(source)}${source.trim() ? "\n\n" : ""}${next}\n` : source;
  const lines = source.split("\n"), old = block.text.split("\n");
  let at = source === base ? block.start : -1;
  if (at < 0) {
    const hits = [];
    for (let i = 0; i + old.length <= lines.length; i++) if (old.every((l, k) => lines[i + k] === l)) hits.push(i);
    if (hits.length !== 1) return null;
    at = hits[0];
  }
  lines.splice(at, old.length, ...(next ? next.split("\n") : []));
  // A removed block leaves its two blank neighbours; keep one.
  if (!next && at > 0 && !lines[at - 1]?.trim() && !lines[at]?.trim() && at < lines.length) lines.splice(at, 1);
  return lines.join("\n");
}
