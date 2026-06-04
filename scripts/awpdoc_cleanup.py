#!/usr/bin/env python3
"""Strip airwindows.com website crud out of scraped awpdoc descriptions.

A handful of the longform descriptions were scraped from airwindows.com blog
posts by ``fetch_missing_descriptions.py`` rather than coming from Chris's
upstream awpdoc files. The scrape pulled in the whole post body, including
website chrome that has no place in a plugin description:

  - Leading metadata: a ``TL;DW:`` one-liner, ``Foo.zip (518k) standalone(...)``
    download blurbs, ``Foo in Airwindows Consolidated ... (CLAP, AU, ...)``
    cross-links, and ``github.com/.../releases`` links.
  - A trailing download block: ``Airwindows Consolidated Download``,
    ``download 64 Bit Windows VSTs.zip`` ... ``Mediafire Backup of all
    downloads``, the ``All this is free and open source under the MIT
    license...`` line, and the ``Date / Author / Category / Tag / Comments``
    WordPress footer.

``clean_description`` removes both. The ``TL;DW:`` summary, when present, is the
only genuinely useful leading line, so it's promoted to a ``# `` heading to
match the convention of the upstream awpdoc files (see EffectDescriptionText,
which renders a leading ``# `` line as a heading).

Upstream awpdoc files all open with ``# `` and are left untouched; the scraped
files are exactly those that do not. Run from the project root to clean them in
place:

    python3 scripts/awpdoc_cleanup.py            # clean the awpdoc directory
    python3 scripts/awpdoc_cleanup.py --check     # report, change nothing
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
AWPDOC_DIR = REPO_ROOT / "AirwindowsAUv3" / "AirwindowsDSP" / "Documentation" / "awpdoc"

# The download/footer block starts at the first line matching any of these.
# That line and everything after it is dropped.
_FOOTER_MARKERS: tuple[re.Pattern[str], ...] = (
    re.compile(r"^Airwindows Consolidated Download\s*$", re.IGNORECASE),
    re.compile(r"^Most recent VCV Rack Module\s*$", re.IGNORECASE),
    re.compile(r"^download .*\.(zip|dmg)\b", re.IGNORECASE),
    re.compile(r"^Mediafire Backup\b", re.IGNORECASE),
    re.compile(r"^All this is free and open source under the MIT licen", re.IGNORECASE),
)

# Individual crud lines dropped wherever they appear (they only ever show up in
# the leading metadata of these posts). Anchored so they match the metadata
# lines without catching prose that merely mentions the same phrases.
_CRUD_LINE: tuple[re.Pattern[str], ...] = (
    re.compile(r"^github\.com/\S+/releases\s*$", re.IGNORECASE),
    re.compile(r"^\S+\.zip \(\d.*standalone\(", re.IGNORECASE),
    re.compile(r"in Airwindows Consolidated\b.*\((CLAP|AU, VST3)", re.IGNORECASE),
)

_TLDW = re.compile(r"^TL;D[WR]:\s*(.+?)\s*$", re.IGNORECASE)


def _metadata_footer_index(lines: list[str]) -> int:
    """Index of the WordPress ``Date / Author / Chris / Category / ...`` footer
    block, or ``len(lines)`` if absent. Posts without a download block (e.g.
    Density3) end with this metadata instead. Matched as a standalone ``Date``
    line shortly followed by a standalone ``Author`` line, so prose that merely
    contains the word "Date" is never mistaken for the footer."""
    stripped = [line.strip() for line in lines]
    for i, value in enumerate(stripped):
        if value == "Date" and "Author" in stripped[i + 1 : i + 8]:
            return i
    return len(lines)


def clean_description(text: str) -> str:
    """Return ``text`` with leading metadata and the trailing download block
    removed, and a ``TL;DW:`` summary promoted to a ``# `` heading."""
    lines = text.replace("\r\n", "\n").split("\n")

    # 1) Cut the footer at the first download/boilerplate marker, or at the
    #    WordPress metadata block if that comes first (posts without downloads).
    cut = _metadata_footer_index(lines)
    for i, line in enumerate(lines):
        stripped = line.strip()
        if any(rx.search(stripped) for rx in _FOOTER_MARKERS):
            cut = min(cut, i)
            break
    lines = lines[:cut]

    # 2) Drop crud lines; lift a leading TL;DW summary into a heading.
    heading: str | None = None
    kept: list[str] = []
    for line in lines:
        stripped = line.strip()
        match = _TLDW.match(stripped)
        if match and heading is None and not kept:
            heading = match.group(1)
            continue
        if any(rx.search(stripped) for rx in _CRUD_LINE):
            continue
        kept.append(line.rstrip())

    # 3) Collapse blank runs and trim.
    body_lines: list[str] = []
    pending_blank = False
    for line in kept:
        if line.strip():
            if pending_blank and body_lines:
                body_lines.append("")
            body_lines.append(line)
            pending_blank = False
        else:
            pending_blank = True
    body = "\n".join(body_lines).strip()

    if heading:
        return f"# {heading}\n\n{body}".strip() if body else f"# {heading}"
    return body


def is_scraped(text: str) -> bool:
    """Upstream awpdoc files open with a ``# `` heading; scraped ones don't."""
    return not text.lstrip().startswith("# ")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="report which files would change without writing them",
    )
    args = parser.parse_args()

    if not AWPDOC_DIR.exists():
        sys.exit(f"awpdoc directory not found at {AWPDOC_DIR}")

    changed: list[str] = []
    for path in sorted(AWPDOC_DIR.glob("*.txt")):
        original = path.read_text(encoding="utf-8")
        if not is_scraped(original):
            continue
        cleaned = clean_description(original)
        if cleaned and cleaned + "\n" != original:
            changed.append(path.stem)
            if not args.check:
                path.write_text(cleaned + "\n", encoding="utf-8")

    verb = "Would clean" if args.check else "Cleaned"
    print(f"{verb} {len(changed)} scraped description(s): {changed}")


if __name__ == "__main__":
    main()
