#!/usr/bin/env python3
"""Renders one CHANGELOG.md section as an HTML fragment for Sparkle's release notes.

    changelog_html.py <version> [CHANGELOG.md]

Prints nothing when the version has no section. Handles what the changelog uses: `###` headings,
`-` bullets (with indented continuation lines) and `inline code`.
"""
import html
import re
import sys

STYLE = (
    "<style>:root{color-scheme:light dark}"
    "body{font:13px/1.45 -apple-system,system-ui,sans-serif;margin:12px 16px}"
    "h3{font-size:13px;margin:14px 0 6px}ul{padding-left:18px;margin:0}li{margin:4px 0}"
    "code{font:12px ui-monospace,Menlo,monospace;background:rgba(127,127,127,.18);"
    "padding:1px 4px;border-radius:4px}</style>"
)


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
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(text, quote=False))


def render(lines: list[str]) -> str:
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
    return STYLE + "".join(body) if body else ""


if __name__ == "__main__":
    version = sys.argv[1]
    changelog = sys.argv[2] if len(sys.argv) > 2 else "CHANGELOG.md"
    print(render(section_lines(changelog, version)), end="")
