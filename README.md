# Portable study workflow

A self-contained, source-led teaching kit for **any subject or topic**. It preserves
the concrete-first method, source fidelity, retrieval, evidence-based progress,
linked HTML lessons, grayscale source-note explainers and flashcards. It contains
no original course notes, textbooks, learner history or subject-specific lessons.

## Start a subject

Keep this folder as a clean kit. From inside it, run:

```sh
python3 scripts/study.py init ../economics-study --subject "Economics"
```

The destination must be new and outside this kit. Paths with spaces should be
quoted. The command copies only reusable kit files, creates fresh mission/source/
coverage records and empty study folders, and leaves the original kit unchanged.
It works from an initialized subject too: it **does not copy that subject's
sources, learning records or progress** into the next subject.

Open the new folder in your assistant and say:

> Read AGENTS.md and the bundled skills. I want to study [topic] for [goal].
> My sources are [files/links]. Help me agree the scope, locate my current level,
> and begin with one useful unit.

For course revision, specify the last lecture delivered. For self-study, agree
the desired boundary. Put source material in `sources/` or register its existing
location in `RESOURCES.md`; no need to move original files.

## What's included

```text
AGENTS.md / agent.md        Agent instructions and alternate entry point
.agents/skills/
  study-workflow/           Setup, source roles, order, evidence, retention
  concrete-first-tutor/     Explain concretely, then practise one question at a time
  study-materials/          Artifact formats and local source-reading guidance
assets/                    Shared styling, retrieval quiz, statement hover previews
templates/                 Workspace records, lesson, recall, reference, TeX, cards
scripts/study.py            Init, HTML checks, Anki export, PDF compilation
tests/                     Standard-library regression tests
evals/                     Cross-subject prompts for optional teaching review
```

Initialized subjects also contain:

```text
MISSION.md                 Why, boundary, success criteria, constraints
RESOURCES.md               Source inventory, editions, roles and provenance
NOTES.md                   Coverage + evidence, next step and session log
sources/                   Notes, textbooks and assigned exercises
lessons/                   Numbered HTML lessons, in creation order
reference/                 Compact rules, glossary entries and milestone indexes
learning-records/          Dated answer evidence, diagnoses and tested repairs
notes-pdf/                 One grayscale explainer per original note file
solutions/                 Worked assigned problems with problem IDs
anki/cards.json            Plain-text card source (initially empty)
```

The templates are **scaffolds**, not finished study material. Replace every
`{{TOKEN}}` before publishing an artifact. Skills live locally and require no
global installation. Tools without automatic discovery can read the skill files
directly through `AGENTS.md`/`agent.md`.

## Teaching loop

1. Notes/syllabus set scope and order; an authoritative source supplies content.
2. Check prior evidence. Ask a prerequisite probe only when needed.
3. Fully worked concrete case → another case → labelled parts → precise claim.
4. Explain first, then one live question at a time. Define unfamiliar terminology.
5. Separate confusable ideas with an explicit distinguishing test.
6. Close with retrieval, a compact reference aid, a state line and the next step.
7. Update coverage and answer evidence separately. **Built is not mastered.**

In humanities, concrete-first means actual passages/events/cases—not forcing
numbers onto every subject. In self-study, the agreed scope replaces the lecturer's
boundary. No fixed chapter list, number of lessons or number of PDFs is imposed.

## Commands

From an initialized subject's root:

```sh
python3 scripts/study.py check .
python3 scripts/study.py anki anki/cards.json anki/deck.txt
python3 scripts/study.py pdf notes-pdf/01-introduction.tex
python3 -m unittest discover -s tests -v
```

`anki` and `pdf` refuse to replace outputs unless you add `--overwrite`. They do
not modify card sources or original notes. The PDF command compiles twice in a
temporary directory with shell escape disabled, replacing the target only on
success. Review TeX before compiling: disabling shell escape is not a full sandbox.

For Anki use **Basic**, Tab, HTML enabled, Front/Back/Tags. Choose your deck in
Anki. Hierarchical tags are tags, not automatically generated subdecks. Cards use
plain text; the script escapes HTML and converts newlines to line breaks.

To preview local lessons if `file://` iframe previews are blocked:

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory .
```

Visit `http://127.0.0.1:8000/lessons/` and stop with Ctrl+C. Serve only a folder
you are comfortable exposing to local processes. Quiz scores are temporary and
are not saved as learning evidence automatically.

## Dependencies and limits

- **Core scripts:** Python 3.9+, standard library only; no pip packages or MCP required.
- **HTML:** a modern browser. No external fonts, CDN, framework or math renderer.
  Plain HTML/Unicode handles simple notation; add an appropriate local renderer
  if your subject needs complex mathematical typesetting.
- **PDF:** optional `pdflatex` and packages listed in `templates/preamble.tex`.
  Check packages with `kpsewhich`; do not assume a specific machine's TeX setup.
  The Latin Modern template is Latin-script oriented; other scripts may need
  Unicode TeX/fonts or browser printing. The CLI supports pdfLaTeX only.
- **Reading PDFs / inspecting output:** optional Poppler (`pdfinfo`, `pdftotext`,
  `pdftoppm`) or the host's PDF/image tools. See the bundled source-file guide.
- **Tests:** structural and regression checks do not verify subject correctness,
  exact quotations, teaching quality, browser layout, PDF readability or actual
  Anki import. Review those separately. `evals/` provides optional teaching prompts;
  do not report them as passed without actual model runs and human review.

## Sharing

Share this clean kit, not an initialized subject containing private records or
copyrighted sources. Do not install the originating course's content or global
coding-agent skills; neither is a runtime dependency. Changing the kit does not
automatically update previously created subjects.
