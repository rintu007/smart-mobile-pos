# Assets

Diagrams, wireframes and exported images referenced by the documentation.

## Rules

- **Prefer Mermaid, inline in the Markdown.** Mermaid is text: it diffs, it reviews, it merges, and
  it cannot drift out of sync unnoticed. Binary diagrams rot the moment the system changes, because
  nobody can see that they are wrong.
- Binary assets are acceptable only for things Mermaid genuinely cannot express — wireframes,
  photographs, printed receipt scans, screenshots of physical hardware.
- Every binary asset is referenced by at least one document. Unreferenced assets are deleted.
- Naming: `<phase>-<subject>.<ext>` — for example `10-receipt-58mm-wireframe.png`.
- Where a source file exists (design tool export), record where it lives so the asset can be
  regenerated rather than recreated.
