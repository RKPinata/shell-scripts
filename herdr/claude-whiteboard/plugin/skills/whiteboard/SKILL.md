---
name: whiteboard
description: Use when an explanation is worth keeping in view beside the session (a flow, a design, the current plan, findings, or anything clearer as a diagram). Not for short answers.
---

# Whiteboard

The user reads the whiteboard file in a Herdr panel beside the session. It is for the user only. It is temporary and is not a source of truth.

## Finding it

If the context has a line that starts with "Your whiteboard file:", that line holds the path.

Otherwise run `bash <base directory>/board.sh`, where `<base directory>` is the "Base directory for this skill" shown above. It prints the path, creates the folder, and links the Herdr pane to the board. Do not build the path yourself.

## Writing it

- Rewrite the whole file with Write each time. Do not append.
- Keep only what is current. Delete what no longer matters.
- Put the main idea first. Use headings and short bullets.
- Draw flows, sequences, states and structures as ```mermaid blocks: `flowchart`,
  `sequenceDiagram`, `stateDiagram-v2`, `classDiagram` or `erDiagram`.
- Keep a diagram under about 15 nodes. Split a bigger one into several.
- Label a node the first time it appears. A node first written bare (`A --> B`) keeps
  the bare name, even if a later line gives it a label.
- Do not announce updates in chat.
