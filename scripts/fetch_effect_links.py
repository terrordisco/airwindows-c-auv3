#!/usr/bin/env python3
"""Build effect_links.json mapping each Airwindows effect name to its
blog post URL on airwindows.com and (when present) its YouTube video URL.

Reads effect names from AirwindowsDSP/Airwin/ModuleAdd.h.
Fetches the WordPress sitemap and matches slugs to effect names.
Fetches each matched post once to extract the first youtube.com/embed iframe.

Run from the project root:
    python3 scripts/fetch_effect_links.py

Outputs:
    AirwindowsAUv3/AirwindowsDSP/Resources/effect_links.json
"""
from __future__ import annotations

import json
import re
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.error import HTTPError, URLError

REPO_ROOT = Path(__file__).resolve().parent.parent
MODULE_ADD = REPO_ROOT / "AirwindowsAUv3" / "AirwindowsDSP" / "Airwin" / "ModuleAdd.h"
OUTPUT = REPO_ROOT / "AirwindowsAUv3" / "AirwindowsDSP" / "Resources" / "effect_links.json"

SITEMAP_URL = "https://www.airwindows.com/wp-sitemap-posts-post-1.xml"
USER_AGENT = "AirwindowsAUv3-link-fetcher/1.0 (+https://github.com/airwindows)"
REQUEST_TIMEOUT = 30
# Conservative: airwindows.com is hosted on shared infra and starts returning
# 503s above ~5 concurrent connections / fast cadence. Slower run takes a few
# minutes but is reliable.
THROTTLE_SECONDS = 0.4
CONCURRENT_FETCHES = 3
RETRY_ATTEMPTS = 4
RETRY_BACKOFF_SECONDS = 2.0

EFFECT_NAME_RE = re.compile(r'registerAirwindow\(\{"([^"]+)"')
SITEMAP_LOC_RE = re.compile(r"<loc>([^<]+)</loc>")
YOUTUBE_EMBED_RE = re.compile(
    r"youtube(?:-nocookie)?\.com/embed/([A-Za-z0-9_-]{11})"
)
YOUTUBE_WATCH_RE = re.compile(
    r"youtube\.com/watch\?(?:[^\"'\s]*&)?v=([A-Za-z0-9_-]{11})"
)
YOUTU_BE_RE = re.compile(r"youtu\.be/([A-Za-z0-9_-]{11})")


def load_effect_names() -> list[str]:
    text = MODULE_ADD.read_text()
    names = EFFECT_NAME_RE.findall(text)
    if not names:
        sys.exit("No effect names found in ModuleAdd.h")
    return names


def fetch(url: str) -> str:
    """GET with retry on 503 (rate-limit) — airwindows.com is sensitive to
    burst traffic. Each retry waits longer than the last."""
    last_error: Exception | None = None
    for attempt in range(RETRY_ATTEMPTS):
        req = urllib.request.Request(
            url, headers={"User-Agent": USER_AGENT, "Accept": "text/html,*/*"}
        )
        try:
            with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
                return resp.read().decode("utf-8", errors="replace")
        except HTTPError as exc:
            last_error = exc
            if exc.code != 503 or attempt == RETRY_ATTEMPTS - 1:
                raise
            time.sleep(RETRY_BACKOFF_SECONDS * (attempt + 1))
        except URLError as exc:
            last_error = exc
            if attempt == RETRY_ATTEMPTS - 1:
                raise
            time.sleep(RETRY_BACKOFF_SECONDS * (attempt + 1))
    # Should be unreachable — the loop either returns or raises.
    raise last_error if last_error else RuntimeError("fetch loop exited without result")


def fetch_sitemap_slugs() -> set[str]:
    print(f"Fetching sitemap: {SITEMAP_URL}")
    xml = fetch(SITEMAP_URL)
    slugs: set[str] = set()
    for url in SITEMAP_LOC_RE.findall(xml):
        # e.g. https://www.airwindows.com/highpass/
        m = re.match(r"https?://www\.airwindows\.com/([^/]+)/?$", url)
        if m:
            slugs.add(m.group(1).lower())
    print(f"  {len(slugs)} post slugs found")
    return slugs


def camel_to_kebab(name: str) -> str:
    # DualMonoVerbs -> dual-mono-verbs ; ToTape9 -> to-tape9
    # Insert hyphen between lower->upper, digit->upper, and upper->upper+lower
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1-\2", name)
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1-\2", s)
    return s.lower()


# Console/variant suffixes. Many variants share a single post with the
# base effect (e.g. AtmosphereBuss -> /atmosphere/, ConsoleXBuss -> /consolex/).
VARIANT_SUFFIXES = (
    "LiteBuss", "LiteChannel",
    "BussHype", "BussIn", "BussOut",
    "ChannelHype", "ChannelIn", "ChannelOut",
    "SubHype", "SubIn", "SubOut",
    "DarkCh", "DarkChannel",
    "Buss", "Channel", "Pre", "Ch",
)

# Hand-curated overrides where slug naming doesn't follow a clean rule.
# Confirmed against the WordPress sitemap.
MANUAL_OVERRIDES: dict[str, str] = {
    "ADClip7": "adclip-7",
    "BussColors4": "busscolors-4",
    "C5RawBuss": "c5rawconsole",
    "C5RawChannel": "c5rawconsole",
    "NCSeventeen": "nc-17",
    "PDBuss": "pdconsole",
    "PDChannel": "pdconsole",
    "RawGlitters": "rawglitters-redux",
    "SubTight": "subtight-redux",
    "UltrasonicLite": "ultrasonic-lite-and-medium",
    "UltrasonicMed": "ultrasonic-lite-and-medium",
    "ZRegion": "zregion2",
    "uLawDecode": "ulaw",
    "uLawEncode": "ulaw",
    "Console8BussHype": "console8hype",
    "Console8ChannelHype": "console8hype",
    "Console8SubHype": "console8hype",
    "Console8LiteBuss": "console8lite",
    "Console8LiteChannel": "console8lite",
    "Console8BussIn": "console8-updates-and-more",
    "Console8BussOut": "console8-updates-and-more",
    "Console8ChannelIn": "console8-updates-and-more",
    "Console8ChannelOut": "console8-updates-and-more",
    "Console8SubIn": "console8-updates-and-more",
    "Console8SubOut": "console8-updates-and-more",
}


def strip_variant_suffix(name: str) -> str | None:
    for suffix in VARIANT_SUFFIXES:
        if name.endswith(suffix) and len(name) > len(suffix):
            return name[: -len(suffix)]
    return None


def candidate_slugs(name: str) -> list[str]:
    """Produce slug candidates in preference order."""
    out: list[str] = []

    def add(variants: list[str]) -> None:
        for s in variants:
            if s and s not in out:
                out.append(s)

    def slugs_for(word: str) -> list[str]:
        lower = word.lower()
        kebab = camel_to_kebab(word)
        # Also try 'adclip-7'-style: trailing number preceded by a dash.
        dash_num = re.sub(r"([a-z])(\d+)$", r"\1-\2", lower)
        # Chris often publishes a newer "-vst" / "-vst3" / "-redux" follow-up
        # post when an older effect is rebuilt for the Consolidated framework.
        # Those posts have better TL;DW summaries and usually embed a video,
        # so try them first, then fall back to the original slug.
        followups: list[str] = []
        for base in (lower, kebab, dash_num):
            for suffix in ("-vst3", "-vst", "-redux"):
                followups.append(f"{base}{suffix}")
        return [*followups, lower, kebab, kebab.replace("-", ""), dash_num]

    if name in MANUAL_OVERRIDES:
        add([MANUAL_OVERRIDES[name]])

    add(slugs_for(name))

    # Fallback: variants like AtmosphereBuss often share the base effect's post
    base = name
    while True:
        stripped = strip_variant_suffix(base)
        if not stripped:
            break
        add(slugs_for(stripped))
        base = stripped

    # Fallback: versioned effects often share their predecessor's post
    # (e.g. Density3 -> density2 -> density). Walk trailing digit down to 0.
    m = re.match(r"^(.+?)(\d+)$", name)
    if m:
        root, num = m.group(1), int(m.group(2))
        for n in range(num - 1, 0, -1):
            add(slugs_for(f"{root}{n}"))
        add(slugs_for(root))

    return out


def match_slugs(names: list[str], slugs: set[str]) -> dict[str, str]:
    matched: dict[str, str] = {}
    unmatched: list[str] = []
    for name in names:
        for cand in candidate_slugs(name):
            if cand in slugs:
                matched[name] = cand
                break
        else:
            unmatched.append(name)
    print(
        f"Matched {len(matched)} / {len(names)} effects to blog slugs. "
        f"{len(unmatched)} unmatched."
    )
    if unmatched:
        sample = unmatched[:20]
        print(f"  unmatched sample: {sample}")
    return matched


def extract_video_id(html: str) -> str | None:
    for rx in (YOUTUBE_EMBED_RE, YOUTUBE_WATCH_RE, YOUTU_BE_RE):
        m = rx.search(html)
        if m:
            return m.group(1)
    return None


def fetch_post(name: str, slug: str) -> tuple[str, str, str | None]:
    url = f"https://www.airwindows.com/{slug}/"
    try:
        html = fetch(url)
    except (HTTPError, URLError) as exc:
        print(f"  [warn] {name} ({url}): {exc}")
        return name, url, None
    time.sleep(THROTTLE_SECONDS)
    return name, url, extract_video_id(html)


def main() -> None:
    effect_names = load_effect_names()
    print(f"Loaded {len(effect_names)} effect names from ModuleAdd.h")

    slugs = fetch_sitemap_slugs()
    matched = match_slugs(effect_names, slugs)

    links: dict[str, dict[str, str]] = {}
    print(f"Fetching {len(matched)} posts (concurrency={CONCURRENT_FETCHES})...")
    with ThreadPoolExecutor(max_workers=CONCURRENT_FETCHES) as pool:
        futures = [
            pool.submit(fetch_post, name, slug) for name, slug in matched.items()
        ]
        for i, fut in enumerate(as_completed(futures), 1):
            name, post_url, video_id = fut.result()
            entry: dict[str, str] = {"post": post_url}
            if video_id:
                entry["video"] = f"https://www.youtube.com/watch?v={video_id}"
            links[name] = entry
            if i % 25 == 0:
                print(f"  ...{i}/{len(matched)}")

    with_video = sum(1 for v in links.values() if "video" in v)
    print(
        f"Done. {len(links)} posts, {with_video} with videos, "
        f"{len(effect_names) - len(links)} effects with no post."
    )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(links, indent=2, sort_keys=True) + "\n")
    print(f"Wrote {OUTPUT.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
