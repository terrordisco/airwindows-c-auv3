#!/usr/bin/env python3
"""Fill in missing awpdoc descriptions and find lazy-loaded YouTube videos
that the original fetch_effect_links.py missed.

For each effect that:
  - Has a matched blog post on airwindows.com (per effect_links.json), AND
  - Does not have a corresponding awpdoc/<Effect>.txt file,
this script fetches the blog post, extracts the article body, strips HTML,
trims footer boilerplate, and writes the result to awpdoc/<Effect>.txt.

Also re-extracts YouTube video IDs from the same fetched HTML using a wider
set of patterns (Rocket Lazy Load on airwindows.com stores the video ID in
data-id="..." which the original iframe/watch/youtu.be regex chain misses).
The augmented results overwrite effect_links.json — but only video URLs are
added, never removed.

Run from the project root:
    python3 scripts/fetch_missing_descriptions.py
"""
from __future__ import annotations

import html as html_mod
import json
import re
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.error import HTTPError, URLError

# Shared crud stripper (download blocks, leading metadata, WordPress footer).
# Both files live in scripts/, which is sys.path[0] when this is run directly.
from awpdoc_cleanup import clean_description

REPO_ROOT = Path(__file__).resolve().parent.parent
LINKS_JSON = REPO_ROOT / "AirwindowsAUv3" / "AirwindowsDSP" / "Resources" / "effect_links.json"
AWPDOC_DIR = REPO_ROOT / "AirwindowsAUv3" / "AirwindowsDSP" / "Documentation" / "awpdoc"

USER_AGENT = "AirwindowsAUv3-link-fetcher/1.0 (+https://github.com/airwindows)"
REQUEST_TIMEOUT = 30
THROTTLE_SECONDS = 0.15
CONCURRENT_FETCHES = 6
MAX_DESCRIPTION_CHARS = 4000

# Video ID extraction. First three are existing patterns; data-id is the
# Rocket Lazy Load fallback that BitGlitter (and others) need.
VIDEO_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"youtube(?:-nocookie)?\.com/embed/([A-Za-z0-9_-]{11})"),
    re.compile(r"youtube\.com/watch\?(?:[^\"'\s]*&)?v=([A-Za-z0-9_-]{11})"),
    re.compile(r"youtu\.be/([A-Za-z0-9_-]{11})"),
    re.compile(r'data-id="([A-Za-z0-9_-]{11})"'),
)

# Boilerplate cutoffs — descriptions in WordPress posts typically end before
# the "subscribe / appreciate Airwindows" footer. Anything from these markers
# onward is dropped.
BOILERPLATE_MARKERS = (
    "If you appreciate Airwindows",
    "Subscribe to Airwindows",
    "Support Airwindows on Patreon",
    "Listen and subscribe",
    "Get the plugin at",
    "Donate to Airwindows",
)

# airwindows.com uses the "Pure & Simple" WordPress theme — body lives in
# <div class="post-content">. The trailing pattern matches whatever closes
# the article (a footer block or the article tag itself).
POST_CONTENT_RE = re.compile(
    r'<div[^>]*class="[^"]*\bpost-content\b[^"]*"[^>]*>(.*?)</article>',
    re.DOTALL,
)
POST_CONTENT_LOOSE_RE = re.compile(
    r'<div[^>]*class="[^"]*\bpost-content\b[^"]*"[^>]*>(.*)',
    re.DOTALL,
)
# The first <header>...</header> inside post-content holds the post title and
# date — drop it so the description starts at the first real paragraph.
HEADER_BLOCK_RE = re.compile(r"<header[^>]*>.*?</header>", re.DOTALL | re.IGNORECASE)
TAG_RE = re.compile(r"<[^>]+>")
SCRIPT_STYLE_RE = re.compile(
    r"<(script|style|noscript)[^>]*>.*?</\1>",
    re.DOTALL | re.IGNORECASE,
)
WHITESPACE_RE = re.compile(r"[ \t\r\f\v]+")


def fetch(url: str) -> str:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": USER_AGENT, "Accept": "text/html,*/*"},
    )
    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
        return resp.read().decode("utf-8", errors="replace")


def extract_video_id(html: str) -> str | None:
    for rx in VIDEO_PATTERNS:
        m = rx.search(html)
        if m:
            return m.group(1)
    return None


def extract_description(html: str) -> str:
    """Pull the article body out of WordPress HTML and reduce it to plain text.

    WordPress on airwindows.com renders the post body inside a
    <div class="entry-content">...</div>. We strip script/style blocks,
    flatten remaining tags, decode entities, and truncate at known footer
    boilerplate."""
    m = POST_CONTENT_RE.search(html) or POST_CONTENT_LOOSE_RE.search(html)
    if not m:
        return ""

    body = m.group(1)
    body = SCRIPT_STYLE_RE.sub("", body)
    body = HEADER_BLOCK_RE.sub("", body)
    body = TAG_RE.sub("\n", body)
    body = html_mod.unescape(body)

    # Collapse whitespace per line, then drop blank lines and re-join with
    # double newlines for paragraph separation.
    lines = [WHITESPACE_RE.sub(" ", ln).strip() for ln in body.split("\n")]
    paragraphs: list[str] = []
    current: list[str] = []
    for ln in lines:
        if ln:
            current.append(ln)
        elif current:
            paragraphs.append(" ".join(current))
            current = []
    if current:
        paragraphs.append(" ".join(current))

    text = "\n\n".join(paragraphs).strip()

    # Trim at boilerplate marker.
    cut = len(text)
    for marker in BOILERPLATE_MARKERS:
        idx = text.find(marker)
        if idx != -1 and idx < cut:
            cut = idx
    text = text[:cut].rstrip()

    if len(text) > MAX_DESCRIPTION_CHARS:
        text = text[:MAX_DESCRIPTION_CHARS].rstrip() + "…"

    return text


def fetch_post(name: str, post_url: str) -> tuple[str, str | None, str | None]:
    try:
        html = fetch(post_url)
    except (HTTPError, URLError) as exc:
        print(f"  [warn] {name} ({post_url}): {exc}")
        return name, None, None
    time.sleep(THROTTLE_SECONDS)
    # Strip website chrome (download lists, leading metadata, WordPress footer)
    # the raw extraction leaves behind. See scripts/awpdoc_cleanup.py.
    return name, clean_description(extract_description(html)), extract_video_id(html)


def main() -> None:
    if not LINKS_JSON.exists():
        sys.exit(f"effect_links.json not found at {LINKS_JSON}")
    if not AWPDOC_DIR.exists():
        sys.exit(f"awpdoc directory not found at {AWPDOC_DIR}")

    links: dict[str, dict[str, str]] = json.loads(LINKS_JSON.read_text())
    existing_docs = {p.stem for p in AWPDOC_DIR.glob("*.txt")}

    # Effects that have a blog post but no awpdoc — the description fill-in
    # candidates. We also re-fetch effects already in links to pick up
    # lazy-loaded video IDs that the original run missed.
    needs_description = sorted(
        name for name in links if name not in existing_docs
    )
    print(f"Effects needing long description: {len(needs_description)}")
    print(f"  {needs_description}")
    needs_video = sorted(
        name for name, entry in links.items() if "video" not in entry
    )
    print(f"Effects missing a video URL (will retry with wider regex): {len(needs_video)}")

    targets = sorted(set(needs_description) | set(needs_video))
    print(f"Total posts to refetch: {len(targets)}")

    written_docs = 0
    added_videos = 0
    with ThreadPoolExecutor(max_workers=CONCURRENT_FETCHES) as pool:
        futures = {
            pool.submit(fetch_post, name, links[name]["post"]): name
            for name in targets
        }
        for i, fut in enumerate(as_completed(futures), 1):
            name, description, video_id = fut.result()

            if (
                name in needs_description
                and description
                and len(description) > 40
            ):
                out = AWPDOC_DIR / f"{name}.txt"
                out.write_text(description + "\n")
                written_docs += 1

            if video_id and "video" not in links[name]:
                links[name]["video"] = f"https://www.youtube.com/watch?v={video_id}"
                added_videos += 1

            if i % 20 == 0:
                print(f"  ...{i}/{len(targets)}")

    print(
        f"Done. Wrote {written_docs} new awpdoc files; "
        f"added {added_videos} previously-missed video URLs."
    )

    LINKS_JSON.write_text(json.dumps(links, indent=2, sort_keys=True) + "\n")
    print(f"Updated {LINKS_JSON.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
