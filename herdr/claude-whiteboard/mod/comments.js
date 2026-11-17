// Comments on blocks of a board, and the message that carries them to the session.
// Pure; tests/comments.test.mjs runs it under Node.

const HEADING = /^ {0,3}#{1,6}\s+(.*?)\s*$/;
// Lines of a block that the message quotes; the session has the whole board on disk.
const QUOTE_LINES = 8;

/** The text of the nearest heading block at or before blocks[i], without its #s; "" when there is none. */
export function sectionOf(blocks, i) {
  for (let k = i; k >= 0; k--) {
    const m = HEADING.exec(blocks[k].text);
    if (m) return m[1];
  }
  return "";
}

/** The message for comments of { section, text, comment }: each quotes its block, `text`, and names its section. */
export function formatMessage(items) {
  const one = ({ section, text, comment }, n) => {
    const lines = text.split("\n");
    const quote = lines.length > QUOTE_LINES ? [...lines.slice(0, QUOTE_LINES), "…"] : lines;
    return [
      `${n + 1}. ${section ? `Section "${section}", block` : "Block"}:`,
      ...quote.map((l) => `   > ${l}`.trimEnd()),
      `   Comment: ${comment.trim().replace(/\n/g, "\n   ")}`,
    ].join("\n");
  };
  return `Comments on your whiteboard:\n\n${items.map(one).join("\n\n")}`;
}
