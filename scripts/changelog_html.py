#!/usr/bin/env python3
"""Renders one CHANGELOG.md section as an HTML fragment for Sparkle's release notes.

    changelog_html.py <version> [CHANGELOG.md]

Prints nothing when the version has no section. Handles what the changelog uses: `###` headings,
`-` bullets (with indented continuation lines), **bold** and `inline code`. No CSS on purpose: Sparkle
shows a fragment in the system font and follows light and dark mode by itself.
"""
import html
import re
import sys


def section_lines(path: str, version: str) -> list[str]:
    lines, found = [], False
    with open(path, encoding="utf-8") as handle:
        for line in handle.read().splitlines():
            if line.startswith("## "):
                if found:
                    break
                found = line[3:].strip() == version
                continue
            if found:
                lines.append(line)
    return lines


def inline(text: str) -> str:
    escaped = html.escape(text, quote=False)
    escaped = re.sub(r"`([^`]+)`", r"<code>\1</code>", escaped)
    return re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", escaped)


def render(version: str, lines: list[str]) -> str:
    body: list[str] = []
    items: list[str] = []

    def flush() -> None:
        if items:
            body.append("<ul>" + "".join(f"<li>{inline(item)}</li>" for item in items) + "</ul>")
            items.clear()

    for line in lines:
        if line.startswith("### "):
            flush()
            body.append(f"<h3>{inline(line[4:].strip())}</h3>")
        elif line.startswith("- "):
            items.append(line[2:].strip())
        elif line.startswith(" ") and items:
            items[-1] += " " + line.strip()
    flush()
    return f"<h2>Version {html.escape(version)}</h2>" + "".join(body) if body else ""


if __name__ == "__main__":
    version = sys.argv[1]
    changelog = sys.argv[2] if len(sys.argv) > 2 else "CHANGELOG.md"
    print(render(version, section_lines(changelog, version)), end="")
