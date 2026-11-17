// node --test tests/tasks.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { splitTasks, toggleTask } from "../mod/tasks.js";

const board = [
  "# Plan",
  "- [ ] **P1** do the checks",
  "- [x] P2 ready",
  "  the rest of P2",
  "- plain item",
  "```md",
  "- [ ] not a task",
  "```",
  "1. [ ] numbered",
].join("\n");

test("splits tasks out of markdown", () => {
  const tasks = splitTasks(board).filter((s) => s.kind === "task");
  assert.deepEqual(tasks.map((t) => [t.done, t.text, t.line]), [
    [false, "**P1** do the checks", 1],
    [true, "P2 ready the rest of P2", 2],
    [false, "numbered", 8],
  ]);
  assert.match(splitTasks(board).at(-2).text, /not a task/);
});

test("toggles the n-th task", () => {
  const next = toggleTask(board, 0, { done: false, text: "**P1** do the checks" });
  assert.equal(next.split("\n")[1], "- [x] **P1** do the checks");
  assert.equal(toggleTask(next, 0, { done: true, text: "**P1** do the checks" }), board);
  assert.equal(toggleTask(board, 1, { done: true, text: "P2 ready the rest of P2" }).split("\n")[2], "- [ ] P2 ready");
});

test("refuses when the file changed", () => {
  assert.equal(toggleTask(board, 0, { done: true, text: "**P1** do the checks" }), null);
  assert.equal(toggleTask(board, 0, { done: false, text: "other" }), null);
  assert.equal(toggleTask(board, 9, { done: false, text: "x" }), null);
});
