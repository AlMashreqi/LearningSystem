---
name: study-workflow
description: Set up or continue source-led revision or self-study for any subject. Use for a folder of notes, syllabus, textbook, course catch-up, study planning, resuming progress, or adapting teaching from observed answers. Maintains scope, source roles, coverage, and evidence without treating written lessons as mastery.
---

# Source-led study workflow

## 1. Establish the mission

Read `MISSION.md`, `RESOURCES.md`, `NOTES.md` and relevant recent learning records.
If they do not exist, use the templates in `templates/workspace/`. Ask only for
missing information that affects the immediate next step, one question at a time.

Establish: subject, practical goal, course-revision or self-study, source of scope,
authoritative content source, current boundary, and what observable success means.
Do not invent an exam, professional application or complete-course ambition.
An isolated question needs a useful explanation, not a mandatory course map.

For a fresh workspace use:

```sh
python3 scripts/study.py init ../new-subject --subject "Subject name"
```

Then work inside that new folder. It includes this kit and fresh record templates.
The destination must not already exist. No global installation is required.

## 2. Assign sources their roles

| Source | Role |
|---|---|
| Learner's notes, lecture sequence, syllabus | Scope, order, notation, emphasis |
| Chosen textbook, primary sources, official documentation | Definitions, claims, evidence, worked examples |
| Tutor | Explain and connect, simplify without losing conditions |
| Supplementary material | A second explanation for a specific sticking point, not a parallel curriculum |

Inspect only relevant pages/sections. Read handwritten work visually when extraction
loses notation. Record source location, edition/version and printed-vs-file page
mapping in `RESOURCES.md`; verify the mapping rather than guessing.

Read the learner's own work for seams: cryptic transitions, omitted conditions,
unfinished derivations, unsupported interpretations. Treat these as hypotheses,
not proof of inability. Detailed copied or borrowed notes are not proficiency evidence.
Where sources disagree, explain the disagreement and which source the course expects;
do not erase scholarly disagreement or teach an objectively false claim as fact.

## 3. Build the smallest useful map

For a whole course or substantial collection, index items in **source order**.
Use stable item IDs and source/page references. If a prerequisite is missing,
insert a short bridge and name the departure; do not silently reorganise the course.
For self-study with no source order, agree a dependency order first.

Keep these separate in `NOTES.md`:

- **Coverage:** source item → lesson/reference aid → not built / built.
- **Proficiency:** unknown / shaky / demonstrated, with dated answer evidence.
- **Creation sequence:** lesson IDs follow creation order, even after jumps.
- **Next step:** the next scoped unit and required prerequisites.

A demonstrated mechanical skill usually needs a compact card and retrieval, not
another full lesson. Do not hard-code lesson counts, a subject's chapter numbers,
or another learner's diagnoses. If several tables would drift, keep one coverage
table with separate build and evidence columns.

## 4. Teach one useful unit

Read `../concrete-first-tutor/SKILL.md`. Default to one concept cluster or roughly
one lecture per sitting, adjusted to evidence. Start with one relevant recall
question only when there is genuine earlier material. Explain concretely, generalise,
then ask one question. Follow the source's actual claims and examples, not just its headings.

If asked to create a complete lesson artifact, include the full explanation and
retrieval questions in the artifact; the one-question-per-turn rule concerns live
conversation, not a prohibition on a written quiz.

Read `../study-materials/SKILL.md` for output formats. Do not generate every format
for every request. A topic explanation can stay in chat; a substantial taught idea
earns a small reference aid, and a requested artifact should use the supplied template.

## 5. Diagnose from answers

Separate a missing concept from two known ideas being merged. For a confusion:

1. Name the two ideas and what each answers.
2. Identify the different evidence or condition each uses.
3. Teach a distinguishing case, then test a fresh case where they disagree.

Do not place a one-sided warning immediately before an oppositely framed question;
test both directions or separate them. Do not claim a repair worked until an answer
shows it. Capture actual wording and hints in a numbered learning record using
`templates/learning-record.md`. Generalise only across repeated evidence.

## 6. Close and retain

- Summarise the single win and give a compact, visible state line: demonstrated,
  hints needed, untouched material, next step.
- Include retrieval practice in lesson files; offer a few recall prompts in chat.
- Create or update a reference aid for a substantial new idea. Add Anki cards when
  requested or when the workspace's agreed retention plan calls for them.
- Update coverage and next step. Update proficiency only with evidence. Record new
  teaching preferences without erasing the previous reason for them.
- At natural milestones, consolidate already-taught claims in an index: exact
  statement where examinable, plain restatement, what it is for, discriminator,
  and link to its original teaching. Interleave retrieval across the range.

## Finish gate

Check scope, source order, notation, prerequisites, exact conditions and citations.
Name anything skipped. Verify file links **and anchors**; do not link to an unbuilt
lesson. A clean validator result is structural evidence only, never mastery or
source verification. Do not quietly retrofit older artifacts without permission.
