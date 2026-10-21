# Portable study workflow

A self-contained, source-led teaching kit for **any subject or topic**. It preserves
the concrete-first method, source fidelity, retrieval, evidence-based progress,
linked HTML lessons, grayscale source-note explainers and flashcards. It contains
no original course notes, textbooks, learner history or subject-specific lessons.

## Set up the workshop

You do not need to install Git, Python, Node.js/npm or Codex beforehand. The setup
script installs missing tools for you.

### Quick setup commands

These commands download and immediately run the setup script from GitHub. Review
and trust the script before running it. Use your normal account, not an elevated
terminal.

**Windows — Command Prompt (not PowerShell; without administrator privileges):**

```cmd
curl.exe -fL --retry 3 --connect-timeout 20 --max-time 180 "https://raw.githubusercontent.com/AlMashreqi/LearningSystem/refs/heads/master/install-workshop.bat" -o "%TEMP%\install-workshop.bat" && call "%TEMP%\install-workshop.bat"
```

This uses Windows' `curl.exe` with download retries and runs setup only if the
download succeeds. Certificate verification stays enabled. If your network blocks
GitHub or a proxy causes certificate errors, ask IT rather than disabling verification.

**macOS — Terminal (without `sudo`):**

```bash
curl -fL "https://raw.githubusercontent.com/AlMashreqi/LearningSystem/refs/heads/master/install-workshop.sh" -o "$TMPDIR/install-workshop.sh" && bash "$TMPDIR/install-workshop.sh"
```

These commands install the tools only; download and extract the kit below to get
the study pipeline, instructions and templates.

### Download the kit (or run setup manually)

1. [Download the workshop ZIP](https://github.com/AlMashreqi/LearningSystem/archive/refs/heads/master.zip)
   (or choose **Code → Download ZIP** on GitHub).
2. Extract the ZIP: on macOS, double-click it; on Windows, right-click it and choose
   **Extract All**. Open the extracted `LearningSystem-master` folder.
3. Run the setup script for your system:
   - **macOS:** open Terminal, type `bash` followed by a space, drag
     `install-workshop.sh` from the extracted folder into Terminal, then press Enter.
   - **Windows:** double-click `install-workshop.bat` inside the extracted folder.
     Do not run it from inside the ZIP.

The scripts keep working installations and set up:

| Tool | When missing |
|---|---|
| Git | Apple Command Line Tools on macOS; Git for Windows 2.56.0.2 on Windows |
| Python 3.9+ | Python 3.13.16 from Python.org |
| Node.js and npm | Node.js 24.22.0 LTS from nodejs.org, including npm |
| Codex | The official OpenAI installer |
| LaTeX (optional) | TinyTeX 2026.10 and the packages used by the PDF template |

Choose **y** at **Set up LaTeX for PDFs now?** to enable the PDF command, or press
Enter to skip it. TinyTeX is smaller than a full TeX installation but still adds
download time and disk usage. An existing LaTeX installation is kept and checked
for the template packages; missing packages must be repaired separately. Node/npm
and Git support workshop coding tasks, but the study scripts themselves use only
Python's standard library.

Run setup from your normal user account, without `sudo` or **Run as administrator**.
Internet access and an operating system supported by the downloaded tools are
required. On macOS, complete the Apple, Python and Node.js installer windows when
they appear, then return to Terminal. On Windows, complete the Node.js installer
when it opens. Some installers require an administrator's approval; managed college
machines may need IT assistance. Reopen your terminal after setup for PATH changes
to take effect. Codex sign-in requires an account with Codex access.

The setup creates a `Codex-Workshop` folder and offers to open Codex there. To use
repo-specific instructions and skills, launch Codex from your new subject folder
as described below.

Installer downloads for Python, Node.js, Git for Windows and TinyTeX use pinned
versions with SHA-256 checks. Maintainers must update both the version and checksum
when upgrading them. Codex uses OpenAI's current installer. Test setup on clean
macOS and Windows machines before a workshop; offline regression tests do not
exercise real installations or operating-system permission prompts.

## Start a subject

Keep this folder as a clean kit. Python 3.9+ is required for the study commands.
After running the workshop setup, run this from inside the kit (on Windows, use
`python` if `python3` is unavailable):

```sh
python3 scripts/study.py init ../economics-study --subject "Economics"
```

The destination must be new and outside this kit. Paths with spaces should be
quoted. The command copies only reusable kit files, creates fresh mission/source/
coverage records and empty study folders, and leaves the original kit unchanged.
It works from an initialized subject too: it **does not copy that subject's
sources, learning records or progress** into the next subject.

Then launch Codex from the new folder:

```sh
cd ../economics-study
codex
```

The new folder includes `AGENTS.md` and the skills in `.agents/skills/`; no separate
global skill installation is needed. In Codex, say:

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
install-workshop.sh/.bat    Git, Python, Node/npm, Codex setup; optional LaTeX
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
- **PDF:** optional `pdflatex` and packages listed in `templates/preamble.tex`;
  choose LaTeX during workshop setup to install TinyTeX and these packages.
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
