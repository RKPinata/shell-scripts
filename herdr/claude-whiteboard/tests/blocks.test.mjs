// node --test tests/blocks.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { splitBlocks, replaceBlock } from "../mod/blocks.js";

const board = [
  "# Plan",          // 0
  "Intro line one",  // 1
  "line two",        // 2
  "",                // 3
  "- [ ] P1",        // 4
  "  - [ ] nested",  // 5
  "- [x] P2",        // 6
  "",                // 7
  "```mermaid",      // 8
  "flowchart LR",    // 9
  "",                // 10
  "A --> B",         // 11
  "```",             // 12
  "| a | b |",       // 13
  "|---|---|",       // 14
].join("\n");

test("splits into blocks", () => {
  assert.deepEqual(splitBlocks(board).map((b) => [b.start, b.end, b.list]), [
    [0, 1, false], [1, 3, false], [4, 6, true], [6, 7, true], [8, 13, false], [13, 15, false],
  ]);
  assert.equal(splitBlocks(board)[4].text.split("\n").length, 5);
});

test("replaces a block by its lines", () => {
  const p1 = splitBlocks(board)[2];
  const next = replaceBlock(board, board, p1, "- [ ] P1 edited\n");
  assert.deepEqual(next.split("\n").slice(4, 6), ["- [ ] P1 edited", "- [x] P2"]);
});

test("removes a block and one blank line", () => {
  const intro = splitBlocks(board)[1];
  assert.deepEqual(replaceBlock(board, board, intro, "  ").split("\n").slice(0, 3), ["# Plan", "", "- [ ] P1"]);
});

test("appends a new block", () => {
  assert.equal(replaceBlock("# A\n", "# A\n", { start: 1, end: 1, text: "" }, "new"), "# A\n\nnew\n");
  assert.equal(replaceBlock("", "", { start: 0, end: 0, text: "" }, "new"), "new\n");
});

test("finds the block again after the file changed", () => {
  const p2 = splitBlocks(board)[3];
  const moved = "Claude added this\n\n" + board;
  assert.equal(replaceBlock(moved, board, p2, "- [x] P2 done").split("\n")[8], "- [x] P2 done");
  assert.equal(replaceBlock(board.replace("- [x] P2", "- [x] changed"), board, p2, "x"), null);
  assert.equal(replaceBlock(board + "\n- [x] P2", board, p2, "x"), null);
});
