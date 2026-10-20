---
name: study-materials
description: Create and verify source-led HTML lessons, compact reference aids, grayscale notes per source-note file, worked solutions, and Anki exports for any subject. Use when turning study material into reusable artifacts, adding exact-statement citations and hover previews, or validating the resulting files.
---

# Reusable study materials

Read `references/formats.md` before authoring an artifact. It is the shared format
contract; templates and scripts implement it. Read `references/source-files.md`
when ingesting PDFs, images or scanned notes. Everything is local and bundled;
optional system tools are described there rather than assumed installed.

## Choose the right artifact

| Request | Artifact |
|---|---|
| Explain one question | Chat; do not manufacture a complete course |
| Teach/revise a concept cluster in a reusable lesson | `lessons/NNNN-slug.html` from `templates/lesson.html` |
| Keep the central idea handy | `reference/slug.html` from `templates/reference.html` |
| Explain the original lecture notes as printable notes | One `notes-pdf/NN-slug.tex` + PDF per source-note file, from `templates/notes.tex` |
| Work through assigned problems | `solutions/` with reasoning and source problem IDs; PDF only if needed |
| Make flashcards | `anki/cards.json` → `anki/deck.txt` |
| Consolidate a milestone | Review lesson + compact index of already-taught claims |

Numbers follow creation order, not necessarily curriculum order. Determine the
next unused number from files; do not overwrite a lesson with a new topic.
Keep a source-item mapping in `NOTES.md`.

## Authoring sequence

1. Confirm scope and read the actual source section; do not copy another subject's content.
2. Work the examples and verify the reasoning independently.
3. Build the explanation concrete-first; quote only assessed statements and add
   genuine plain explanations. Define every unfamiliar term.
4. Add stable IDs to citable statements. At each use of a prior fact, quote its
   complete statement in a recall box and link to the actual statement ID.
5. Add retrieval with specific feedback and confusable-idea discriminators.
6. Add/update the companion reference aid. Flashcards and PDFs follow the selected
   output request, not an automatic requirement to create every artifact.

## Checks

Run `python3 scripts/study.py check .` from the subject root. It checks local
lesson/reference HTML links and assets, anchor IDs, duplicate IDs, unresolved
template tokens, adjacent `.plain` boxes after `.sourcequote`, recall-box shape,
and quiz answer/feedback markup. It does not check prose truth, citation accuracy,
quote equality, browser rendering, accessibility or PDF contents. Review those manually.

For Anki, run `python3 scripts/study.py anki anki/cards.json anki/deck.txt`.
Rebuild with `--overwrite` only after reviewing the source changes.

For PDFs, first inspect trusted TeX, then run
`python3 scripts/study.py pdf notes-pdf/NN-slug.tex` (add `--overwrite` to rebuild).
Visually inspect every page. Compilation alone does not prove readable layout.
For browser changes verify narrow/wide layouts, quiz feedback and hover/focus
citations in a real browser when tools are available; otherwise disclose the gap.

Do not silently retrofit earlier lessons when format rules change. Record the rule,
apply it going forward and ask before a bulk conversion.
