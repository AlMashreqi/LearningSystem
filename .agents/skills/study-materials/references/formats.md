# Artifact format contract

Paths below are relative to the **subject workspace root**, not this guide.

## HTML lessons

Start from `templates/lesson.html`; it is an authoring scaffold, not a finished lesson.
Replace every `{{TOKEN}}`. Use shared `assets/style.css`, `assets/quiz.js`, and
`assets/ref-preview.js`; no CDN or build system is required.
Escape literal text and attribute values correctly for HTML, especially quotations
in `data-fb`. Do not paste scripts or active markup from source material into a lesson.

- Header: source unit/items, source title/edition, section/pages, one attainable win.
- Recall block: relevant preceding material, only if it actually exists.
- Body: fully worked concrete cases → named parts → general statement → conditions,
  reasoning and applications. Do not reduce the source section to a list of claims.
- Assessed source statements: `.sourcequote` with verified exact wording and citation,
  directly followed by `.plain` with a genuine beginner-level explanation. Give each
  citable statement a short stable kebab-case `id` at creation time.
- At the exact point a previous fact justifies a step, insert `.recall`: full exact
  statement in a `blockquote`, why it applies, and an `<a class="ref"
  href="NNNN-slug.html#statement-id">Lesson NNNN</a>`. Verify both the target file
  and ID. Split citations across actual sources if one theorem was taught in pieces.
- Every inline mention of a built earlier lesson is linked; a statement citation
  goes to its anchor. General footer navigation can link to the file itself.
- Forward material stays explicitly marked as unbuilt; do not create fake links.
- End with retrieval (free recall plus distinguishing cases), summary, compact
  reference aid link, and the next step. Answers belong in collapsed `details` or
  interactive feedback, not immediately underneath the question in full view.

### Citation previews

`.ref` links and `ref-preview.js` load the real cited page in a 9:16 portrait iframe
in a clear left/right gutter only. A fragment highlights the real statement using
`:target`. Do not add duplicate JSON snippets or overlay the reading column.
When no gutter fits, clicking still works; there is no hover fallback over the text.
Local `file://` iframe restrictions vary. If needed, serve only the workspace on
loopback: `python3 -m http.server 8000 --bind 127.0.0.1 --directory .` and visit
`http://127.0.0.1:8000/lessons/`. Stop the server when finished. Do not expose it
publicly or serve a directory containing secrets.

### Quiz markup

Inside `[data-quiz]`, each `.q` has `data-answer` as a zero-based correct option
index, `.opt` buttons with their own `data-fb` explanation, and an empty `.fb`
element with `aria-live="polite"`. Answers are locked after the first choice;
reload to retry. Scores are ephemeral: no automatic learning-record updates,
storage, network, or tracking. Ask for actual answers before diagnosing mastery.

## Reference aids and milestone reviews

Keep reference aids compact: claim, when to use it, necessary conditions,
distinguishing test, one small example, and anchored source lesson link. For
theorem/rule/argument indexes include exact assessed wording, a plain restatement,
purpose and discriminator. Interpretive subjects can index arguments or analytical
tools rather than pretending every claim is a theorem. Review only already-taught
content. Interleave retrieval across topics instead of testing them in list order.

## Printable source-note explainers

Create **one PDF per original source-note file**, covering that file's full scoped
range in its original order. Do not hard-code five PDFs or use one PDF per HTML lesson.

- Use `templates/notes.tex` with the shared grayscale `preamble.tex`.
- Explain in original, accessible language. Read the content authority for accuracy,
  but do not include textbook quotations or textbook citation boxes in these notes.
  Record source provenance separately in `RESOURCES.md` and `NOTES.md`.
- Finish incomplete explanations, derivations, proofs or arguments; mark additions
  using `\fillbox`. Keep correction subordinate to understanding, not an audit spine.
- Add freshly written worked problems in the source's style using `\examplebox`;
  do not copy textbook problem wording. Distinguish them from actual assigned problems.
- Use `\notebox` for explanations, `\keybox` for takeaways, `\warnbox` only when needed.
- Black/white/gray only. HTML citation/recall styling does not carry over.
- Boxes are unbreakable: keep them short, split long proofs across boxes or regular
  paragraphs. Render every page to detect clipped content and overflowing boxes.
- `pdflatex` requires TeX packages, not Python dependencies. Check new packages with
  `kpsewhich package.sty`; do not assume another machine shares the original setup.
  Avoid optional `enumerate[...]` unless the required package is actually present.
- The supplied Latin Modern/pdfLaTeX template is primarily Latin-script. For other
  writing systems choose an appropriate Unicode TeX engine/fonts or print the HTML;
  the bundled PDF command does not silently install or switch engines.

## Flashcards

`anki/cards.json` is the editable source; generated TSV is not. Schema:

```json
[
  {
    "front": "One clear retrieval question",
    "back": "Answer, key condition, and distinguishing test if useful.",
    "tags": ["Subject::Unit1", "trap"]
  }
]
```

Use plain text, not HTML. The exporter escapes `<`, `>`, `&` and quotation marks;
newlines become `<br>`. Tabs, blank fields, duplicate fronts and tags containing
whitespace are rejected. Stable fronts allow updates on re-import. Changing a
front creates a different note unless manually reconciled in Anki.

Import the exported `deck.txt` as **Basic**, separator **Tab**, HTML enabled,
Front/Back/Tags in columns 1/2/3. Choose the deck manually. Hierarchical tags such
as `Subject::Unit1` organise tags, **not automatic subdecks**. Study one unit at a
time; use `trap` and `key` for cross-cutting passes. Review the duplicate/update
options before re-importing. The utility does not connect to Anki or schedule cards.
