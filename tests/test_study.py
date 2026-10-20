"""Run from the kit root: python3 -m unittest discover -s tests -v."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

KIT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("study", KIT / "scripts/study.py")
study = importlib.util.module_from_spec(spec)
spec.loader.exec_module(study)


class StudyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_init_is_portable_and_refuses_existing_destination(self):
        dest = self.root / "history"
        study.initialize(dest, "Modern History")
        self.assertIn("Modern History", (dest / "MISSION.md").read_text())
        for path in ["AGENTS.md", "agent.md", "scripts/study.py",
                     ".agents/skills/concrete-first-tutor/SKILL.md",
                     ".agents/skills/study-workflow/SKILL.md",
                     ".agents/skills/study-materials/SKILL.md",
                     "assets/ref-preview.js", "notes-pdf/preamble.tex"]:
            self.assertTrue((dest / path).is_file(), path)
        self.assertEqual(study.check(dest), [])
        with self.assertRaises(ValueError):
            study.initialize(dest, "Overwrite")
        with self.assertRaises(ValueError):
            study.initialize(KIT / "nested-subject", "Nested")

    def test_new_subject_does_not_inherit_previous_subject_content(self):
        first, second = self.root / "first", self.root / "second"
        study.initialize(first, "First subject")
        (first / "sources/notes/private.txt").write_text("Private source")
        (first / "learning-records/0001-private.md").write_text("Private answer")
        (first / "lessons/0001-private.html").write_text("Old lesson")
        (first / "anki/cards.json").write_text('[{"front":"Old question"}]')
        with patch.object(study, "KIT", first):
            study.initialize(second, "Second subject")
        self.assertFalse((second / "sources/notes/private.txt").exists())
        self.assertFalse((second / "learning-records/0001-private.md").exists())
        self.assertFalse((second / "lessons/0001-private.html").exists())
        self.assertEqual(json.loads((second / "anki/cards.json").read_text()), [])
        self.assertIn("Second subject", (second / "MISSION.md").read_text())

    def test_init_refuses_a_dangling_symlink_without_creating_its_target(self):
        target, link = self.root / "target", self.root / "link"
        link.symlink_to(target, target_is_directory=True)
        with self.assertRaises(ValueError):
            study.initialize(link, "Subject")
        self.assertFalse(target.exists())

    def test_links_decode_paths_and_validate_fragments_and_duplicates(self):
        lessons = self.root / "lessons"
        lessons.mkdir()
        (lessons / "source page.html").write_text('<div id="rule">Rule</div>')
        citing = lessons / "0001-test.html"
        citing.write_text('<a href="source%20page.html#rule">Source</a>')
        self.assertEqual(study.check(self.root), [])
        citing.write_text('<a href="source%20page.html#absent">Source</a>'
                          '<p id="x"></p><p id="x"></p>')
        errors = "\n".join(study.check(self.root))
        self.assertIn("absent", errors)
        self.assertIn("duplicate id", errors)

    def test_quote_needs_adjacent_plain_box_and_quiz_needs_valid_answer(self):
        lessons = self.root / "lessons"
        lessons.mkdir()
        page = lessons / "0001-test.html"
        page.write_text('<blockquote class="sourcequote">Quote</blockquote>'
                        '<p>Not a simplification box</p>'
                        '<div class="q" data-answer="3">'
                        '<button class="opt" data-fb="Why">A</button>'
                        '<p class="fb"></p></div>')
        errors = "\n".join(study.check(self.root))
        self.assertIn("plain", errors)
        self.assertIn("data-answer", errors)
        page.write_text('<blockquote class="sourcequote">Quote</blockquote>'
                        '<div class="plain">Plain words</div>')
        self.assertEqual(study.check(self.root), [])

    def test_missing_assets_escape_links_and_unfilled_templates_fail(self):
        lessons = self.root / "lessons"
        lessons.mkdir()
        (lessons / "0001-test.html").write_text(
            '<script src="../assets/missing.js"></script>'
            '<a href="../../outside.html">Escape</a><p>{{TITLE}}</p>')
        errors = "\n".join(study.check(self.root))
        self.assertIn("missing.js", errors)
        self.assertIn("outside workspace", errors)
        self.assertIn("unfilled", errors)

    def test_recall_requires_anchored_link_and_full_statement_markup(self):
        lessons = self.root / "lessons"
        lessons.mkdir()
        page = lessons / "0001-test.html"
        page.write_text('<aside class="recall">Vague recap</aside>')
        errors = "\n".join(study.check(self.root))
        self.assertIn("anchored ref", errors)
        self.assertIn("full-statement", errors)
        page.write_text('<p id="rule">A rule</p><aside class="recall">'
                        '<a class="ref" href="#rule">Earlier rule</a>'
                        '<blockquote>A rule</blockquote></aside>')
        self.assertEqual(study.check(self.root), [])

    def test_anki_escapes_text_and_preserves_existing_output_on_invalid_input(self):
        source, output = self.root / "cards.json", self.root / "deck.txt"
        cards = [{"front": "Why x < 3?", "back": "A & B\nSecond line",
                  "tags": ["Topic::Unit1", "trap"]}]
        source.write_text(json.dumps(cards))
        study.export_anki(source, output)
        text = output.read_text()
        self.assertIn("x &lt; 3", text)
        self.assertIn("A &amp; B<br>Second line", text)
        self.assertIn("Topic::Unit1 trap", text)
        with self.assertRaises(ValueError):
            study.export_anki(source, output)
        source.write_text(json.dumps(cards + cards))
        with self.assertRaises(ValueError):
            study.export_anki(source, output, overwrite=True)
        self.assertEqual(output.read_text(), text)

    def test_anki_rejects_bad_types_tags_and_fields(self):
        source = self.root / "cards.json"
        for card in [{"front": "", "back": "Answer", "tags": []},
                     {"front": "Q", "back": 2, "tags": []},
                     {"front": "Q", "back": "A", "tags": ["two tags"]},
                     {"front": "Q", "back": "A", "tags": "tag"},
                     {"front": "Q\tQ", "back": "A", "tags": []}]:
            source.write_text(json.dumps([card]))
            with self.subTest(card=card), self.assertRaises(ValueError):
                study.export_anki(source, self.root / "deck.txt")

    def test_pdf_failure_does_not_replace_existing_pdf(self):
        source = self.root / "notes.tex"
        source.write_text("Not valid TeX")
        output = source.with_suffix(".pdf")
        output.write_bytes(b"existing PDF")
        with patch.object(study.shutil, "which", return_value="pdflatex"), \
             patch.object(study.subprocess, "run") as run:
            run.return_value.returncode = 1
            run.return_value.stdout = "compile failed"
            with self.assertRaises(ValueError):
                study.build_pdf(source, overwrite=True)
        self.assertEqual(output.read_bytes(), b"existing PDF")


if __name__ == "__main__":
    unittest.main()
