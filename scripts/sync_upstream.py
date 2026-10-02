#!/usr/bin/env python3
"""Weekly upstream sync, end to end, no human required.

"Upstream" is Paul Walker's airwin2rack (baconpaul/airwin2rack), the
consolidated C++ registry this app is built from. Chris Johnson's own repo
and airwindows.com sit behind it: Chris commits Saturday evening (US
Eastern), Paul's mirror follows within hours, Chris's blog post with the
description and video lands Sunday afternoon. Run this Monday morning and
everything has settled.

What it does, in order:

  1. Update airwin2rack (clone if missing), run its updateToLatest.sh, which
     fast-forwards Chris's repo and regenerates the C++ wrappers + registry.
  2. Mirror the regenerated tree into the app: autogen_airwin (with deletes),
     ModuleAdd.h, and awpdoc descriptions. Upstream awpdoc always wins; our
     scraped descriptions only fill gaps and are never deleted here.
  3. Scrape airwindows.com: blog-post + video links for every effect, then
     descriptions for effects whose awpdoc is still missing, then clean the
     scraped text of website chrome.
  4. Categories: an effect that arrives "Unclassified" gets a category by the
     family rule when a sibling exists (BezEQ4 -> BezEQ3's category,
     ConsoleFooBuss -> Consoles). Anything still Unclassified is listed in
     the report for Sveinbjörn to decide — never shipped under "Unclassified"
     silently. (Effects without a description stay hidden regardless.)
  5. Report (Markdown): new / removed effects, DSP files changed, docs added,
     links added or lost, Unclassified list, suggested What's New text.
  6. Optionally bump versions in project.yml: MARKETING_VERSION 1.0.x -> x+1,
     CURRENT_PROJECT_VERSION +1 (Sveinbjörn's scheme), then xcodegen.

"Changed" is semantic, not "git says the tree is dirty": new or removed
effects, DSP edits to existing effects, descriptions added / updated /
scraped / cleaned, links gained, categories auto-assigned. The scrape is
merge-only — a failed page fetch on the runner can never erase a link we
already had. Anything else git flags afterwards is noise (a scrape that
came back slightly different, a regenerated file with the same meaning):
it is listed in the report and reverted, so a quiet week never pushes a
commit or ships a release.

Exit codes: 0 = changes were made, 10 = nothing changed, 1 = error.

Usage (from the repo root):
  python3 scripts/sync_upstream.py [--airwin2rack repo] [--no-fetch] [--bump]
                                   [--report sync-report.md] [--whats-new whatsnew.txt]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "AirwindowsAUv3"
DSP = APP / "AirwindowsDSP"
AUTOGEN = DSP / "Airwin" / "autogen_airwin"
MODULE_ADD = DSP / "Airwin" / "ModuleAdd.h"
AWPDOC = DSP / "Documentation" / "awpdoc"
OVERRIDES = DSP / "Resources" / "category_overrides.json"
LINKS = DSP / "Resources" / "effect_links.json"
PROJECT_YML = APP / "project.yml"
AIRWIN2RACK_URL = "https://github.com/baconpaul/airwin2rack"

REGISTER_RE = re.compile(
    r'registerAirwindow\(\{"(?P<name>[^"]+)", "(?P<cat>[^"]*)", (?P<ord>-?\d+), (?P<mono>true|false), '
    r'"(?P<what>(?:[^"\\]|\\.)*)", [^,]+, "(?P<date>[^"]*)"'
)


def run(cmd: list[str], cwd: Path | None = None, check: bool = True, quiet: bool = False) -> subprocess.CompletedProcess:
    if not quiet:
        print("$", " ".join(str(c) for c in cmd), flush=True)
    return subprocess.run(cmd, cwd=cwd, check=check, text=True, capture_output=quiet)


def git_head(path: Path) -> str:
    return subprocess.run(["git", "-C", str(path), "rev-parse", "--short", "HEAD"], text=True, capture_output=True).stdout.strip()


def last_commit_date(path: Path) -> date:
    iso = subprocess.run(["git", "-C", str(path), "log", "-1", "--format=%cI"], text=True, capture_output=True).stdout.strip()
    return date.fromisoformat(iso[:10]) if iso else date.today()


def git_log_subjects(path: Path, old: str, new: str) -> list[str]:
    if not old or old == new:
        return []
    out = subprocess.run(["git", "-C", str(path), "log", "--format=%s", f"{old}..{new}"], text=True, capture_output=True).stdout
    return [l for l in out.splitlines() if l.strip()]


def parse_registry(path: Path) -> dict[str, dict]:
    text = path.read_text()
    effects = {}
    for m in REGISTER_RE.finditer(text):
        effects[m["name"]] = {"category": m["cat"], "what": m["what"], "date": m["date"], "mono": m["mono"] == "true"}
    return effects


def load_json(path: Path) -> dict:
    return json.loads(path.read_text()) if path.exists() else {}


def save_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def awpdoc_hashes() -> dict[str, int]:
    """name -> content hash for every description, to spot rewrites by name."""
    return {p.stem: hash(p.read_bytes()) for p in AWPDOC.glob("*.txt")} if AWPDOC.exists() else {}


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, text=True, capture_output=True).stdout


def merge_links(old: dict, new: dict) -> dict:
    """Union of the two scrapes where a value we already had is never dropped.
    airwindows.com rate-limits unfamiliar IPs (GitHub runners included); a
    page that failed to fetch must not look like a post or video vanishing."""
    merged = {name: dict(entry) for name, entry in old.items()}
    for name, entry in new.items():
        merged.setdefault(name, {}).update({k: v for k, v in entry.items() if v})
    return merged


def link_changes(old: dict, new: dict) -> list[str]:
    out = []
    for name in sorted(set(old) | set(new)):
        a, b = old.get(name, {}), new.get(name, {})
        if a == b:
            continue
        bits = [f"{k} {'added' if k not in a else 'changed'}" for k in ("post", "video") if a.get(k) != b.get(k)]
        out.append(f"{name}: {', '.join(bits)}")
    return out


# ---------------------------------------------------------------------------
# 1. upstream
# ---------------------------------------------------------------------------

def update_airwin2rack(repo: Path) -> tuple[str, str, str, str]:
    """Returns (paul_before, paul_after, chris_before, chris_after) short SHAs."""
    if not repo.exists():
        run(["git", "clone", "--recursive", AIRWIN2RACK_URL, str(repo)])
        paul_before = chris_before = ""
    else:
        paul_before = git_head(repo)
        chris_before = git_head(repo / "libs" / "airwindows")
        run(["git", "-C", str(repo), "fetch", "origin"], check=False)
        run(["git", "-C", str(repo), "reset", "--hard", "origin/HEAD"], check=False)
        run(["git", "-C", str(repo), "submodule", "update", "--init"], check=False)
    # Paul's own script: resets libs/airwindows to origin/master and runs configure.pl.
    run(["bash", "scripts/updateToLatest.sh"], cwd=repo, quiet=True)
    return paul_before, git_head(repo), chris_before, git_head(repo / "libs" / "airwindows")


# ---------------------------------------------------------------------------
# 2. mirror
# ---------------------------------------------------------------------------

def mirror(repo: Path) -> dict:
    src_autogen = repo / "src" / "autogen_airwin"
    before = set(p.name for p in AUTOGEN.iterdir()) if AUTOGEN.exists() else set()
    run(["rsync", "-a", "--delete", f"{src_autogen}/", f"{AUTOGEN}/"], quiet=True)
    shutil.copy2(repo / "src" / "ModuleAdd.h", MODULE_ADD)
    # Paul's tree keeps wrapper files for effects that are no longer in his
    # registry (ConsoleX3Buss/Channel/Pre after Chris folded them into
    # ConsoleX3). They would compile as dead code and, worse, show up as
    # "changes" every week. Keep only what ModuleAdd.h registers.
    registered = set(parse_registry(MODULE_ADD))
    pruned = []
    for f in sorted(AUTOGEN.iterdir()):
        if f.suffix in (".cpp", ".h") and re.sub(r"(Proc)?\.(cpp|h)$", "", f.name) not in registered:
            f.unlink()
            pruned.append(f.name)
    after = set(p.name for p in AUTOGEN.iterdir())

    AWPDOC.mkdir(parents=True, exist_ok=True)
    replaced_scraped, added_docs, updated_docs = [], [], []
    for src in sorted((repo / "res" / "awpdoc").glob("*.txt")):
        if src.name.startswith("."):  # upstream ships a stray ".txt" — not an effect
            continue
        dst = AWPDOC / src.name
        new_text = src.read_text(errors="ignore")
        if dst.exists():
            old_text = dst.read_text(errors="ignore")
            if old_text == new_text:
                continue
            # Our scraped files don't start with "# "; upstream's do. Upstream wins.
            (replaced_scraped if not old_text.lstrip().startswith("# ") else updated_docs).append(src.stem)
        else:
            added_docs.append(src.stem)
        shutil.copy2(src, dst)
    return {
        "autogen_added": sorted(after - before),
        "autogen_removed": sorted(before - after),
        "autogen_pruned": pruned,
        "docs_added": added_docs,
        "docs_updated": updated_docs,
        "docs_replaced_scraped": replaced_scraped,
    }


# ---------------------------------------------------------------------------
# 3. scrape
# ---------------------------------------------------------------------------

def scrape() -> None:
    py = sys.executable
    run([py, str(ROOT / "scripts" / "fetch_effect_links.py")], cwd=ROOT, quiet=True)
    run([py, str(ROOT / "scripts" / "fetch_missing_descriptions.py")], cwd=ROOT, quiet=True)
    run([py, str(ROOT / "scripts" / "awpdoc_cleanup.py")], cwd=ROOT, quiet=True)


# ---------------------------------------------------------------------------
# 4. categories
# ---------------------------------------------------------------------------

CONSOLE_SUFFIXES = ("Buss", "Channel", "Pre", "Hype", "In", "Out", "Lite", "Sub")


def effective_category(name: str, registry: dict, overrides: dict) -> str:
    return overrides.get(name) or registry[name]["category"]


def family_rule(name: str, registry: dict, overrides: dict) -> tuple[str | None, str]:
    """Suggest a category for an Unclassified effect from its family.
    Returns (category or None, reason)."""
    # Console families: ConsoleXBuss / ConsoleMDChannel / PurestConsole4Pre ...
    if "Console" in name and any(name.endswith(s) for s in CONSOLE_SUFFIXES):
        return "Consoles", "Console family"
    m = re.match(r"^(.*?)(\d+)$", name)
    if m:
        root, num = m.group(1), int(m.group(2))
        # nearest lower-numbered sibling with a real category, then the root itself
        for n in range(num - 1, -1, -1):
            sib = f"{root}{n}" if n > 0 else root
            if sib in registry and effective_category(sib, registry, overrides) != "Unclassified":
                return effective_category(sib, registry, overrides), f"sibling {sib}"
    return None, "no classified sibling"


def categorise(registry: dict) -> dict:
    data = load_json(OVERRIDES)
    comment = data.pop("_comment", "")
    overrides = dict(data)
    auto, open_list = [], []
    for name, info in sorted(registry.items()):
        if effective_category(name, registry, overrides) != "Unclassified":
            continue
        cat, why = family_rule(name, registry, overrides)
        has_doc = (AWPDOC / f"{name}.txt").exists() or bool(info["what"].strip())
        if cat:
            overrides[name] = cat
            auto.append((name, cat, why, has_doc))
        else:
            open_list.append((name, has_doc))
    if auto:
        comment += f" Auto (sync {date.today().isoformat()}): " + "; ".join(f"{n}->{c} ({w})" for n, c, w, _ in auto) + "."
        out = {"_comment": comment, **{k: overrides[k] for k in sorted(overrides, key=str.lower)}}
        OVERRIDES.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
    return {"auto": auto, "open": open_list}


# ---------------------------------------------------------------------------
# 5. report
# ---------------------------------------------------------------------------

def short_description(name: str, registry: dict) -> str:
    """One line about the effect: the first sentence of Chris's registry text
    (a tagline for older effects, the whole blog post for recent ones), else
    the first sentence of the description file. Empty when there is nothing
    short and clean enough to quote (links, long paragraphs)."""
    sources = [registry.get(name, {}).get("what", "").replace('\\"', '"')]
    doc = AWPDOC / f"{name}.txt"
    if doc.exists():
        sources.append(re.sub(r"^#.*$", "", doc.read_text(errors="ignore"), flags=re.M))
    for text in sources:
        body = " ".join(text.split())
        first = re.split(r"(?<=[.!?])\s", body, maxsplit=1)[0].strip() if body else ""
        if 0 < len(first) <= 160 and "http" not in first:
            return first.rstrip(".")
    return ""


def describe(name: str, registry: dict, overrides: dict, links: dict) -> str:
    cat = effective_category(name, registry, overrides)
    has_doc = (AWPDOC / f"{name}.txt").exists()
    post = bool(links.get(name, {}).get("post"))
    video = bool(links.get(name, {}).get("video"))
    bits = [cat, "documented" if has_doc else "NO DESCRIPTION (hidden)", "post" if post else "no post", "video" if video else "no video"]
    what = short_description(name, registry)
    return f"**{name}**" + (f" — *{what}*" if what else "") + " — " + ", ".join(bits)


def write_report(path: Path | None, ctx: dict) -> str:
    reg_after, reg_before = ctx["reg_after"], ctx["reg_before"]
    overrides = {k: v for k, v in load_json(OVERRIDES).items() if k != "_comment"}
    links_after, links_before = load_json(LINKS), ctx["links_before"]
    new = sorted(set(reg_after) - set(reg_before))
    removed = sorted(set(reg_before) - set(reg_after))
    changed_dsp = sorted(ctx["dsp_changed"])
    links_added = sorted(n for n in links_after if n not in links_before)
    links_lost = sorted(n for n, v in links_before.items() if v.get("post") and not links_after.get(n, {}).get("post"))
    cats = ctx["cats"]

    L = [f"# Upstream sync — {date.today().isoformat()}", ""]
    L.append(f"Paul's airwin2rack: `{ctx['paul_before'] or 'fresh clone'}` → `{ctx['paul_after']}`; Chris's airwindows: `{ctx['chris_before'] or '?'}` → `{ctx['chris_after']}`.")
    if ctx["chris_log"]:
        L += ["", "Chris's commits since last sync:", *[f"- {s}" for s in ctx["chris_log"]]]
    L.append(f"Chris's last commit: {ctx['chris_last']} ({ctx['silent_days']} days ago).")
    L += ["", f"Effects: {len(reg_before)} → {len(reg_after)}.", ""]
    L.append(f"## New effects ({len(new)})")
    L += [f"- {describe(n, reg_after, overrides, links_after)}" for n in new] or ["- none"]
    L += ["", f"## Removed effects ({len(removed)})", *([f"- {n}" for n in removed] or ["- none"])]
    L += ["", f"## DSP changes to existing effects ({len(changed_dsp)} files)", *([f"- {f}" for f in changed_dsp[:40]] or ["- none"])]
    if len(changed_dsp) > 40:
        L.append(f"- … and {len(changed_dsp) - 40} more")
    m = ctx["mirror"]
    if m["autogen_pruned"]:
        L.append(f"- unregistered wrappers dropped from upstream's tree: {', '.join(m['autogen_pruned'])}")
    L += ["", "## Descriptions",
          f"- added from upstream: {', '.join(m['docs_added']) or 'none'}",
          f"- updated from upstream: {', '.join(m['docs_updated']) or 'none'}",
          f"- upstream replaced our scraped text: {', '.join(m['docs_replaced_scraped']) or 'none'}",
          f"- scraped from airwindows.com this run: {', '.join(ctx['scraped_now']) or 'none'}",
          f"- rewritten by cleanup: {', '.join(ctx['docs_rewritten']) or 'none'}"]
    L += ["", "## Links", f"- posts/videos added: {', '.join(links_added) or 'none'}", f"- posts LOST (check!): {', '.join(links_lost) or 'none'}",
          *([f"- {c}" for c in ctx["links_delta"][:40]] or ["- no link values changed"])]
    L += ["", "## Categories"]
    L += [f"- auto (family rule): {n} → {c} ({w})" for n, c, w, _ in cats["auto"]] or ["- no new auto-assignments"]
    if cats["open"]:
        L += ["", "### ⚠️ Unclassified — Sveinbjörn, your call"]
        for n, has_doc in cats["open"]:
            L.append(f"- **{n}** — {'HAS a description and would be visible under “Unclassified”' if has_doc else 'no description yet, hidden until Chris posts'}")
    else:
        L.append("- nothing Unclassified ✔")
    hidden = sorted(n for n, info in reg_after.items() if not (AWPDOC / f"{n}.txt").exists() and not info["what"].strip())
    L += ["", f"## Hidden — no description yet ({len(hidden)})",
          "Chris has committed these but not blogged them; they appear the week a post lands.",
          *([f"- {n} ({effective_category(n, reg_after, overrides)})" for n in hidden] or ["- none"])]
    L += ["", "## Suggested What's New", "", ctx["whats_new"]]
    if ctx["noise"]:
        L += ["", "## Noise reverted (git saw changes with no meaning — nothing released)", "", "```", ctx["noise"].rstrip(), "```"]
    text = "\n".join(L) + "\n"
    if path:
        path.write_text(text)
    return text


def whats_new(new: list[str], changed_dsp_effects: list[str], docs_added: list[str], registry: dict) -> str:
    visible_new = [n for n in new if (AWPDOC / f"{n}.txt").exists() or registry[n]["what"].strip()]
    parts = []
    for n in visible_new:
        what = short_description(n, registry)
        if what.lower().startswith(n.lower()):   # "SoftClock3 is a groove-oriented time reference"
            parts.append(f"New Airwindows effect: {what}.")
        else:
            parts.append(f"New Airwindows effect: {n}" + (f" — {what}." if what else "."))
    if changed_dsp_effects:
        k = len(changed_dsp_effects)
        parts.append(f"Upstream fixes and refinements to {k} existing effect{'s' if k != 1 else ''}.")
    if docs_added:
        parts.append("Fresh descriptions for " + ", ".join(docs_added) + ".")
    if not parts:
        parts.append("Weekly upstream sync: effect catalogue refreshed to match airwindows.com.")
    return " ".join(parts)


# ---------------------------------------------------------------------------
# 6. version bump
# ---------------------------------------------------------------------------

def bump_versions() -> tuple[str, str]:
    text = PROJECT_YML.read_text()
    mv = re.search(r'MARKETING_VERSION: "([^"]+)"', text)
    bv = re.search(r'CURRENT_PROJECT_VERSION: "(\d+)"', text)
    if not mv or not bv:
        raise SystemExit("project.yml: version lines not found")
    parts = mv.group(1).split(".")
    while len(parts) < 3:
        parts.append("0")
    parts[2] = str(int(parts[2]) + 1)
    new_mv = ".".join(parts)
    new_bv = str(int(bv.group(1)) + 1)
    text = text.replace(mv.group(0), f'MARKETING_VERSION: "{new_mv}"').replace(bv.group(0), f'CURRENT_PROJECT_VERSION: "{new_bv}"')
    PROJECT_YML.write_text(text)
    if shutil.which("xcodegen"):
        run(["xcodegen", "generate"], cwd=APP, quiet=True)
    return new_mv, new_bv


# ---------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--airwin2rack", default=str(ROOT / "repo"), help="path to the airwin2rack clone (cloned if missing)")
    ap.add_argument("--no-fetch", action="store_true", help="skip the airwindows.com scrapers")
    ap.add_argument("--bump", action="store_true", help="bump MARKETING_VERSION 1.0.x and CURRENT_PROJECT_VERSION in project.yml")
    ap.add_argument("--report", type=Path, help="write the Markdown report here")
    ap.add_argument("--whats-new", type=Path, help="write the suggested What's New text here")
    ap.add_argument("--github-output", type=Path, help="append key=value lines for GitHub Actions ($GITHUB_OUTPUT)")
    args = ap.parse_args()
    repo = Path(args.airwin2rack).resolve()

    reg_before = parse_registry(MODULE_ADD) if MODULE_ADD.exists() else {}
    links_before = load_json(LINKS)
    docs_before = set(p.stem for p in AWPDOC.glob("*.txt")) if AWPDOC.exists() else set()
    docs_hash_before = awpdoc_hashes()
    autogen_hash_before = {p.name: p.stat().st_size for p in AUTOGEN.iterdir()} if AUTOGEN.exists() else {}

    paul_before, paul_after, chris_before, chris_after = update_airwin2rack(repo)
    chris_log = git_log_subjects(repo / "libs" / "airwindows", chris_before, chris_after)
    chris_last = last_commit_date(repo / "libs" / "airwindows")
    silent_days = (date.today() - chris_last).days

    m = mirror(repo)
    if not args.no_fetch:
        scrape()
        save_json(LINKS, merge_links(links_before, load_json(LINKS)))
    links_after = load_json(LINKS)
    reg_after = parse_registry(MODULE_ADD)
    cats = categorise(reg_after)

    dsp_changed = [n for n, sz in autogen_hash_before.items() if (AUTOGEN / n).exists() and (AUTOGEN / n).stat().st_size != sz]
    # size-equal edits are rare but possible; a git diff name-only catches those too
    diff = git("diff", "--name-only", "--", str(AUTOGEN))
    diffed = {Path(l).name for l in diff.splitlines() if l.strip() and (ROOT / l.strip()).exists()}  # edits, not deletions
    dsp_changed = sorted(set(dsp_changed) | diffed - set(m["autogen_added"]))
    changed_effects = sorted({re.sub(r"(Proc)?\.(cpp|h)$", "", f) for f in dsp_changed})
    scraped_now = sorted(set(p.stem for p in AWPDOC.glob("*.txt")) - docs_before - set(m["docs_added"]))
    new = sorted(set(reg_after) - set(reg_before))
    removed = sorted(set(reg_before) - set(reg_after))
    wn = whats_new(new, changed_effects, m["docs_added"] + scraped_now, reg_after)
    docs_hash_after = awpdoc_hashes()
    already = set(m["docs_added"]) | set(m["docs_updated"]) | set(m["docs_replaced_scraped"]) | set(scraped_now)
    docs_rewritten = sorted(n for n, h in docs_hash_after.items() if n in docs_hash_before and docs_hash_before[n] != h and n not in already)
    links_delta = link_changes(links_before, links_after)

    # Semantic change: something a user could notice. Not "git sees a diff".
    changed = any([new, removed, dsp_changed, m["docs_added"], m["docs_updated"], m["docs_replaced_scraped"],
                   scraped_now, docs_rewritten, links_delta, cats["auto"]])
    noise = ""
    if not changed and git("status", "--porcelain", "--", str(DSP)).strip():
        noise = git("status", "--porcelain", "--", str(DSP)) + git("diff", "--stat", "--", str(DSP))
        git("checkout", "--", str(DSP))
        git("clean", "-fdq", "--", str(DSP))
    if changed and args.bump:
        mv, bv = bump_versions()
        wn_header = f"Version {mv} (build {bv})"
    else:
        mv = bv = ""
        wn_header = ""

    ctx = dict(reg_before=reg_before, reg_after=reg_after, links_before=links_before, mirror=m, cats=cats,
               dsp_changed=dsp_changed, scraped_now=scraped_now, docs_rewritten=docs_rewritten, links_delta=links_delta,
               noise=noise, whats_new=wn, chris_log=chris_log, chris_last=chris_last, silent_days=silent_days,
               paul_before=paul_before, paul_after=paul_after, chris_before=chris_before, chris_after=chris_after)
    report = write_report(args.report, ctx)
    print(report)
    if args.whats_new:
        args.whats_new.write_text(wn + "\n")
    if args.github_output:
        with args.github_output.open("a") as f:
            f.write(f"changed={'true' if changed else 'false'}\n")
            f.write(f"marketing_version={mv}\nbuild_number={bv}\n")
            f.write(f"new_effects={','.join(new)}\n")
            f.write(f"unclassified={','.join(n for n, _ in cats['open'])}\n")
            # Chris usually commits every weekend; the workflow raises a flag
            # after three quiet weeks so Sveinbjörn hears about it.
            f.write(f"chris_last_commit={chris_last.isoformat()}\nsilent_days={silent_days}\n")
    if not changed:
        print("Nothing changed upstream or on airwindows.com.")
        return 10
    print(wn_header)
    return 0


if __name__ == "__main__":
    sys.exit(main())
