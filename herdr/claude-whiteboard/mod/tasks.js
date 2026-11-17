// Task-list items ("- [ ] text") of a board, so the panel can draw them as checkboxes and tick them in the file.
// Pure; tasks.test.mjs runs it under Node.

const TASK = /^(\s*(?:[-*+]|\d+[.)])\s+)\[([ xX])\]\s+(.*)$/;
const LIST = /^\s*(?:[-*+]|\d+[.)])\s/;
const OPEN_FENCE = /^ {0,3}(`{3,}|~{3,})/;
const CLOSE_FENCE = /^ {0,3}(`{3,}|~{3,})[ \t]*$/;

/**
 * Splits markdown into runs of { kind: "markdown", text } and { kind: "task", done, text, indent, line }, in order.
 * `line` is the task's line index in `text`. Task lines inside code fences stay markdown. Indented lines right after
 * a task join its text, as its continuation.
 */
export function splitTasks(text) {
  const out = [];
  let md = [], fence = null, last = null;
  const flush = () => { if (md.length) { out.push({ kind: "markdown", text: md.join("\n") }); md = []; } };
  text.split("\n").forEach((line, i) => {
    if (fence) {
      const c = CLOSE_FENCE.exec(line);
      if (c && c[1][0] === fence[0] && c[1].length >= fence.length) fence = null;
      md.push(line);
      return;
    }
    const f = OPEN_FENCE.exec(line);
    if (f) { fence = f[1]; last = null; md.push(line); return; }
    const m = TASK.exec(line);
    if (m) {
      flush();
      last = { kind: "task", done: m[2] !== " ", text: m[3], indent: m[1].search(/\S/), line: i };
      out.push(last);
      return;
    }
    if (last && line.trim() && !LIST.test(line) && line.search(/\S/) > last.indent) { last.text += " " + line.trim(); return; }
    last = null;
    md.push(line);
  });
  flush();
  return out;
}

/**
 * The source with its n-th task (zero-based, in file order) ticked or unticked. `seen` is the task as the panel shows it:
 * when the file's n-th task has another state or text, the file changed underneath, and the result is null.
 */
export function toggleTask(source, n, seen) {
  const task = splitTasks(source).filter((s) => s.kind === "task")[n];
  if (!task || task.done !== seen.done || task.text !== seen.text) return null;
  const lines = source.split("\n");
  lines[task.line] = lines[task.line].replace(/\[[ xX]\]/, task.done ? "[ ]" : "[x]");
  return lines.join("\n");
}
