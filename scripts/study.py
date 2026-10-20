#!/usr/bin/env python3
"""Portable study-workspace utilities. Python 3.9+, standard library only."""
import argparse
import html
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from urllib.parse import unquote, urlsplit

KIT = Path(__file__).resolve().parents[1]


def initialize(destination, subject):
    destination = Path(destination).expanduser()
    if not subject.strip() or any(c in subject for c in "\n\r\t"):
        raise ValueError("Subject must be a non-empty, single-line name.")
    if destination.exists() or destination.is_symlink():
        raise ValueError("Destination already exists; nothing was changed.")
    destination = destination.resolve()
    if destination == KIT or KIT in destination.parents:
        raise ValueError("Create the subject outside the kit folder.")
    # Copy the reusable kit only, even when run from an active subject workspace.
    destination.mkdir(parents=True)
    for name in ["AGENTS.md", "agent.md", "README.md", ".agents", "scripts",
                 "templates", "assets", "tests", "evals"]:
        source = KIT / name
        if source.is_dir():
            shutil.copytree(source, destination / name, ignore=shutil.ignore_patterns(
                "__pycache__", ".DS_Store", "*.pyc"))
        else:
            shutil.copyfile(source, destination / name)
    for template in (destination / "templates/workspace").glob("*.md"):
        (destination / template.name).write_text(
            template.read_text(encoding="utf-8").replace("{{SUBJECT}}", subject),
            encoding="utf-8")
    for folder in ["sources/notes", "sources/textbooks", "sources/exercises",
                   "lessons", "reference", "learning-records", "notes-pdf",
                   "solutions", "anki"]:
        (destination / folder).mkdir(parents=True, exist_ok=True)
    shutil.copyfile(destination / "templates/preamble.tex",
                    destination / "notes-pdf/preamble.tex")
    (destination / "anki/cards.json").write_text("[]\n", encoding="utf-8")


class Page(HTMLParser):
    """Small HTML inventory; checks structure, not browser layout or accuracy."""
    VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input",
            "link", "meta", "param", "source", "track", "wbr"}

    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.nodes = []
        self.stack = []
        self.ids = set()
        self.duplicates = set()
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        node = {"tag": tag, "attrs": attrs, "parent": self.stack[-1] if self.stack else None,
                "children": [], "text": "", "line": self.getpos()[0]}
        node["classes"] = set((attrs.get("class") or "").split())
        if node["parent"] is not None:
            node["parent"]["children"].append(node)
        self.nodes.append(node)
        ident = attrs.get("id")
        if ident:
            if ident in self.ids:
                self.duplicates.add(ident)
            self.ids.add(ident)
        if tag not in self.VOID:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in self.VOID:
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        for index in range(len(self.stack) - 1, -1, -1):
            if self.stack[index]["tag"] == tag:
                del self.stack[index:]
                break

    def handle_data(self, data):
        for node in self.stack:
            node["text"] += data


def check(root):
    root = Path(root).resolve()
    errors = []
    pages = {}
    for folder in ["lessons", "reference"]:
        for path in sorted((root / folder).rglob("*.html")):
            if not path.resolve().is_relative_to(root):
                errors.append(f"{path.name}: outside workspace")
                continue
            text = path.read_text(encoding="utf-8")
            pages[path.resolve()] = Page(text)
            if re.search(r"\{\{[^{}]+\}\}", text):
                errors.append(f"{path.name}: unfilled template token")
    for path, page in pages.items():
        for ident in sorted(page.duplicates):
            errors.append(f"{path.name}: duplicate id {ident}")
        for node in page.nodes:
            prefix = f"{path.relative_to(root)}:{node['line']}"
            for attr in ["href", "src"]:
                value = node["attrs"].get(attr)
                if not value:
                    continue
                url = urlsplit(value)
                if url.scheme or url.netloc:
                    continue  # external links are never fetched
                target = (path.parent / unquote(url.path)).resolve() if url.path else path
                if not target.is_relative_to(root):
                    errors.append(f"{prefix}: link outside workspace: {value}")
                elif not target.exists():
                    errors.append(f"{prefix}: missing target: {value}")
                elif url.fragment and target.suffix.lower() == ".html":
                    if target not in pages:
                        pages_target = Page(target.read_text(encoding="utf-8"))
                    else:
                        pages_target = pages[target]
                    if unquote(url.fragment) not in pages_target.ids:
                        errors.append(f"{prefix}: missing anchor: {value}")
            if "sourcequote" in node["classes"]:
                siblings = node["parent"]["children"] if node["parent"] else [
                    n for n in page.nodes if n["parent"] is None]
                index = next(i for i, n in enumerate(siblings) if n is node)
                if index + 1 == len(siblings) or "plain" not in siblings[index + 1]["classes"]:
                    errors.append(f"{prefix}: sourcequote needs an adjacent plain box")
            if "recall" in node["classes"]:
                descendants = descendants_of(node)
                if not any("ref" in n["classes"] and "#" in (n["attrs"].get("href") or "")
                           for n in descendants):
                    errors.append(f"{prefix}: recall needs an anchored ref link")
                if not any(n["tag"] == "blockquote" and n["text"].strip() for n in descendants):
                    errors.append(f"{prefix}: recall needs a full-statement blockquote")
            if "q" in node["classes"]:
                descendants = descendants_of(node)
                opts = [n for n in descendants if "opt" in n["classes"]]
                answer = node["attrs"].get("data-answer") or ""
                if not answer.isdigit() or not 0 <= int(answer) < len(opts):
                    errors.append(f"{prefix}: invalid data-answer (zero-based option index)")
                if any(not (n["attrs"].get("data-fb") or "").strip() for n in opts):
                    errors.append(f"{prefix}: every option needs data-fb feedback")
                if not any("fb" in n["classes"] for n in descendants):
                    errors.append(f"{prefix}: question needs an fb feedback element")
    return errors


def descendants_of(node):
    result = []
    for child in node["children"]:
        result.append(child)
        result.extend(descendants_of(child))
    return result


def write_output(path, content, overwrite=False):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if not overwrite:
        with path.open("x", encoding="utf-8") as stream:
            stream.write(content)
        return
    # Replace generated files only after the entire new output is ready.
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        temp = Path(stream.name)
        stream.write(content.encode("utf-8"))
    try:
        os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


def export_anki(source, output, overwrite=False):
    source, output = Path(source).resolve(), Path(output).resolve()
    if source == output:
        raise ValueError("Output cannot replace the card source.")
    if output.exists() and not overwrite:
        raise ValueError("Output exists; pass --overwrite to rebuild it.")
    cards = json.loads(source.read_text(encoding="utf-8"))
    if not isinstance(cards, list):
        raise ValueError("cards.json must contain a list.")
    lines = ["#separator:Tab", "#html:true", "#notetype:Basic", "#tags column:3",
             "#columns:Front\tBack\tTags"]
    seen = set()
    for number, card in enumerate(cards, 1):
        if not isinstance(card, dict):
            raise ValueError(f"Card {number}: expected an object.")
        fields = [card.get("front"), card.get("back")]
        if any(not isinstance(f, str) or not f.strip() or "\t" in f for f in fields):
            raise ValueError(f"Card {number}: front/back must be non-empty text without tabs.")
        front = fields[0].strip()
        if front in seen:
            raise ValueError(f"Card {number}: duplicate front: {front}")
        seen.add(front)
        tags = card.get("tags", [])
        if not isinstance(tags, list) or any(
                not isinstance(t, str) or not t or any(c.isspace() for c in t) for t in tags):
            raise ValueError(f"Card {number}: tags must be a list of non-empty, whitespace-free strings.")
        encoded = [html.escape(f.strip()).replace("\r\n", "\n").replace("\r", "\n")
                   .replace("\n", "<br>") for f in fields]
        lines.append("\t".join(encoded + [" ".join(tags)]))
    write_output(output, "\n".join(lines) + "\n", overwrite)
    return len(cards)


def build_pdf(source, overwrite=False):
    source = Path(source).resolve()
    if source.suffix != ".tex" or not source.is_file():
        raise ValueError("Supply an existing .tex file.")
    output = source.with_suffix(".pdf")
    if output.exists() and not overwrite:
        raise ValueError("PDF exists; pass --overwrite to rebuild it.")
    engine = shutil.which("pdflatex")
    if not engine:
        raise ValueError("pdflatex is missing. Install a TeX distribution or print the HTML instead.")
    with tempfile.TemporaryDirectory(prefix="study-pdf-") as directory:
        for _ in range(2):
            result = subprocess.run(
                [engine, "-no-shell-escape", "-interaction=nonstopmode", "-halt-on-error",
                 f"-output-directory={directory}", source.name], cwd=source.parent,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
            if result.returncode:
                raise ValueError("PDF compilation failed; existing output preserved:\n" + result.stdout[-4000:])
        compiled = Path(directory) / output.name
        if not compiled.is_file():
            raise ValueError("Compiler did not produce a PDF.")
        with tempfile.NamedTemporaryFile(dir=output.parent, delete=False) as stream:
            temp = Path(stream.name)
            stream.write(compiled.read_bytes())
        try:
            if not overwrite and output.exists():
                raise ValueError("PDF appeared during compilation; refusing to replace it.")
            os.replace(temp, output)
        finally:
            temp.unlink(missing_ok=True)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    init = commands.add_parser("init", help="Create a new subject workspace; never merges existing files")
    init.add_argument("destination", type=Path)
    init.add_argument("--subject", required=True)
    validate = commands.add_parser("check", help="Check local HTML links, anchors, quotes and quiz markup")
    validate.add_argument("root", type=Path, nargs="?", default=Path.cwd())
    anki = commands.add_parser("anki", help="Export plain-text JSON cards to HTML-safe Anki TSV")
    anki.add_argument("source", type=Path)
    anki.add_argument("output", type=Path)
    anki.add_argument("--overwrite", action="store_true")
    pdf = commands.add_parser("pdf", help="Compile trusted local TeX to a grayscale-note PDF")
    pdf.add_argument("source", type=Path)
    pdf.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "init":
            initialize(args.destination, args.subject)
            print(f"Created {args.destination.resolve()}")
        elif args.command == "check":
            if not args.root.is_dir():
                raise ValueError("Workspace directory does not exist.")
            errors = check(args.root)
            if errors:
                parser.exit(1, "\n".join(errors) + "\n")
            print("HTML checks passed (content accuracy and browser behavior require manual review).")
        elif args.command == "anki":
            print(f"Exported {export_anki(args.source, args.output, args.overwrite)} cards.")
        elif args.command == "pdf":
            print(build_pdf(args.source, args.overwrite))
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        parser.exit(1, f"Error: {error}\n")


if __name__ == "__main__":
    main()
