// node --test tests/comments.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { splitBlocks } from "../mod/blocks.js";
import { sectionOf, formatMessage } from "../mod/comments.js";

const blocks = splitBlocks([
  "Intro",            // 0
  "",
  "## Flow ",         // 1
  "- one",            // 2
  "",
  "```sh",            // 3
  "# not a heading",
  "```",
  "### Open questions", // 4
  "last",             // 5
].join("\n"));

test("section is the nearest heading at or before the block", () => {
  assert.deepEqual(blocks.map((_b, i) => sectionOf(blocks, i)), ["", "Flow", "Flow", "Flow", "Open questions", "Open questions"]);
});

test("message quotes each block under its section", () => {
  assert.equal(formatMessage([
    { section: "Flow", text: "- one", comment: " why?\nsecond line " },
    { section: "", text: "Intro", comment: "ok" },
  ]), [
    "Comments on your whiteboard:",
    "",
    '1. Section "Flow", block:',
    "   > - one",
    "   Comment: why?",
    "   second line",
    "",
    "2. Block:",
    "   > Intro",
    "   Comment: ok",
  ].join("\n"));
});

test("a long quote is cut after 8 lines", () => {
  const text = Array.from({ length: 10 }, (_v, i) => (i === 1 ? "" : `l${i}`)).join("\n");
  const lines = formatMessage([{ section: "", text, comment: "c" }]).split("\n");
  assert.deepEqual(lines.slice(3, 13), ["   > l0", "   >", "   > l2", "   > l3", "   > l4", "   > l5", "   > l6", "   > l7", "   > …", "   Comment: c"]);
});
