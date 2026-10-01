#!/usr/bin/env python3
"""Ship a build: archive → export → upload → TestFlight → App Store review.

Runs after `sync_upstream.py --bump` has set the new version in project.yml
and the smoke test has passed. Everything talks to App Store Connect through
`asc.py`; nothing needs a person.

Steps:
  1. xcodebuild archive (Release) + export (app-store-connect) + altool
     validate + upload. Signing is automatic: xcodebuild gets the ASC API key
     (-authenticationKey…) so it can fetch/create provisioning profiles, and
     the Apple Distribution certificate must already be in a keychain
     (the workflow imports it from a secret).
  2. Wait until App Store Connect reports the build VALID (processing done).
  3. TestFlight: put the build in the external "public link" group with the
     What's New text as "What to Test".
  4. App Store: find an editable version (PREPARE_FOR_SUBMISSION /
     DEVELOPER_REJECTED / REJECTED / METADATA_REJECTED / INVALID_BINARY) and
     retitle it, or create a new one if the latest is live. If a version is
     waiting for or in review, leave the store alone this week (TestFlight
     still got the build) and say so in the summary. Otherwise set What's New,
     attach the build, create a review submission and submit.
  5. Append a Markdown summary to --report.

Usage:
  python3 scripts/release.py --marketing-version 1.0.1 --build-number 10 \
      --whats-new whatsnew.txt --report sync-report.md \
      [--dry-run] [--skip-submit] [--skip-build]
Env: ASC_API_KEY_ID, ASC_API_ISSUER_ID, ASC_API_KEY_PATH (.p8). Falls back to
the asc.py defaults and ~/.appstoreconnect/private_keys/.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
APP_DIR = ROOT / "AirwindowsAUv3"
APP_ID = "6775213422"
BUNDLE_ID = "com.terrordisco.airwindows.consolidated"
TEAM_ID = "CV7UBF55FQ"
EDITABLE_STATES = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}
IN_FLIGHT_STATES = {"WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE", "PENDING_APPLE_RELEASE", "PROCESSING_FOR_APP_STORE", "WAITING_FOR_EXPORT_COMPLIANCE"}


def sh(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    print("$", " ".join(cmd), flush=True)
    return subprocess.run(cmd, text=True, **kw)


def api(method: str, path: str, body=None, expect=(200, 201, 204)):
    status, out = asc.call(method, path, body)
    if status not in expect:
        raise RuntimeError(f"{method} {path} -> {status}: {str(out)[:800]}")
    return out


# ---------------------------------------------------------------------------
# 1. build + upload
# ---------------------------------------------------------------------------

def build_and_upload(build_number: str, key_path: Path, key_id: str, issuer: str) -> Path:
    build = APP_DIR / "build"
    build.mkdir(exist_ok=True)
    archive = build / f"Airwindows{build_number}.xcarchive"
    export = build / f"export{build_number}"
    plist = build / "ExportOptions.plist"
    plist.write_text(f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>method</key><string>app-store-connect</string>
    <key>teamID</key><string>{TEAM_ID}</string>
    <key>signingStyle</key><string>automatic</string>
    <key>uploadSymbols</key><true/>
    <key>destination</key><string>export</string>
</dict></plist>
""")
    auth = ["-allowProvisioningUpdates", "-authenticationKeyPath", str(key_path),
            "-authenticationKeyID", key_id, "-authenticationKeyIssuerID", issuer]
    sh(["xcodegen", "generate"], cwd=APP_DIR, check=True)
    r = sh(["xcodebuild", "archive", "-project", str(APP_DIR / "AirwindowsAUv3.xcodeproj"), "-scheme", "AirwindowsApp",
            "-configuration", "Release", "-destination", "generic/platform=iOS", "-archivePath", str(archive), *auth],
           capture_output=True)
    if r.returncode != 0:
        print("\n".join(l for l in r.stdout.splitlines() if "error" in l.lower())[-4000:]); raise SystemExit("archive failed")
    r = sh(["xcodebuild", "-exportArchive", "-archivePath", str(archive), "-exportPath", str(export),
            "-exportOptionsPlist", str(plist), *auth], capture_output=True)
    if r.returncode != 0:
        print(r.stdout[-4000:], r.stderr[-2000:]); raise SystemExit("export failed")
    ipa = next(export.glob("*.ipa"))
    for verb in ("--validate-app", "--upload-app"):
        r = sh(["xcrun", "altool", verb, "-f", str(ipa), "-t", "ios", "--apiKey", key_id, "--apiIssuer", issuer], capture_output=True)
        print(r.stdout[-1500:])
        if r.returncode != 0:
            print(r.stderr[-2000:]); raise SystemExit(f"altool {verb} failed")
    return ipa


# ---------------------------------------------------------------------------
# 2. wait for processing
# ---------------------------------------------------------------------------

def wait_for_build(build_number: str, timeout_s: int = 2700) -> str:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        out = api("GET", f"builds?filter[app]={APP_ID}&filter[version]={build_number}&fields[builds]=version,processingState&limit=5")
        for b in out.get("data", []):
            st = b["attributes"]["processingState"]
            if st == "VALID":
                return b["id"]
            if st in ("FAILED", "INVALID"):
                raise SystemExit(f"build {build_number} processing {st}")
        print(f"  waiting for build {build_number} to process…", flush=True)
        time.sleep(60)
    raise SystemExit("timed out waiting for build processing")


# ---------------------------------------------------------------------------
# 3. TestFlight
# ---------------------------------------------------------------------------

def testflight(build_id: str, whats_new: str, dry: bool) -> str:
    groups = api("GET", f"betaGroups?filter[app]={APP_ID}&fields[betaGroups]=name,isInternalGroup,publicLinkEnabled").get("data", [])
    external = [g for g in groups if not g["attributes"]["isInternalGroup"]]
    if dry:
        return f"TestFlight: would add build to {', '.join(g['attributes']['name'] for g in external) or 'no external group'}"
    # What to Test
    locs = api("GET", f"builds/{build_id}/betaBuildLocalizations?fields[betaBuildLocalizations]=locale").get("data", [])
    if locs:
        api("PATCH", f"betaBuildLocalizations/{locs[0]['id']}", {"data": {"type": "betaBuildLocalizations", "id": locs[0]["id"], "attributes": {"whatsNew": whats_new[:4000]}}})
    else:
        api("POST", "betaBuildLocalizations", {"data": {"type": "betaBuildLocalizations", "attributes": {"locale": "en-US", "whatsNew": whats_new[:4000]},
                                                 "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})
    for g in external:
        api("POST", f"betaGroups/{g['id']}/relationships/builds", {"data": [{"type": "builds", "id": build_id}]})
    return f"TestFlight: build added to {', '.join(g['attributes']['name'] for g in external) or 'no external group'} with What to Test set"


# ---------------------------------------------------------------------------
# 4. App Store version + submission
# ---------------------------------------------------------------------------

def app_store(build_id: str, marketing_version: str, whats_new: str, dry: bool, skip_submit: bool) -> str:
    versions = api("GET", f"apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&fields[appStoreVersions]=versionString,appStoreState,releaseType&limit=10").get("data", [])
    in_flight = [v for v in versions if v["attributes"]["appStoreState"] in IN_FLIGHT_STATES]
    if in_flight:
        v = in_flight[0]["attributes"]
        return f"App Store: version {v['versionString']} is {v['appStoreState']} — left alone this week; the build is on TestFlight."
    editable = [v for v in versions if v["attributes"]["appStoreState"] in EDITABLE_STATES]
    if dry:
        return f"App Store: would {'reuse editable version ' + editable[0]['attributes']['versionString'] if editable else 'create version ' + marketing_version}, set What's New, attach build and submit"
    if editable:
        vid = editable[0]["id"]
        if editable[0]["attributes"]["versionString"] != marketing_version:
            api("PATCH", f"appStoreVersions/{vid}", {"data": {"type": "appStoreVersions", "id": vid, "attributes": {"versionString": marketing_version, "releaseType": "AFTER_APPROVAL"}}})
    else:
        vid = api("POST", "appStoreVersions", {"data": {"type": "appStoreVersions", "attributes": {"platform": "IOS", "versionString": marketing_version, "releaseType": "AFTER_APPROVAL"},
                                                 "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})["data"]["id"]
    locs = api("GET", f"appStoreVersions/{vid}/appStoreVersionLocalizations?fields[appStoreVersionLocalizations]=locale").get("data", [])
    for loc in locs:
        api("PATCH", f"appStoreVersionLocalizations/{loc['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": {"whatsNew": whats_new[:4000]}}})
    api("PATCH", f"appStoreVersions/{vid}/relationships/build", {"data": {"type": "builds", "id": build_id}})
    if skip_submit:
        return f"App Store: version {marketing_version} prepared with build attached; submission skipped by flag."
    sub = api("POST", "reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"}, "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})["data"]["id"]
    api("POST", "reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub}}, "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    state = api("PATCH", f"reviewSubmissions/{sub}", {"data": {"type": "reviewSubmissions", "id": sub, "attributes": {"submitted": True}}})["data"]["attributes"].get("state")
    return f"App Store: version {marketing_version} submitted for review ({state}); releases automatically on approval."


# ---------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--marketing-version", required=True)
    ap.add_argument("--build-number", required=True)
    ap.add_argument("--whats-new", type=Path, required=True)
    ap.add_argument("--report", type=Path)
    ap.add_argument("--dry-run", action="store_true", help="no upload, no ASC writes; print what would happen")
    ap.add_argument("--skip-submit", action="store_true", help="TestFlight + version prep only, no review submission")
    ap.add_argument("--skip-build", action="store_true", help="assume the build is already uploaded")
    args = ap.parse_args()

    key_id = os.environ.get("ASC_API_KEY_ID", asc.KEY)
    issuer = os.environ.get("ASC_API_ISSUER_ID", asc.ISS)
    key_path = Path(os.environ.get("ASC_API_KEY_PATH", asc.P8))
    whats_new = args.whats_new.read_text().strip() or "Weekly upstream sync."
    lines = [f"## Release {args.marketing_version} (build {args.build_number})", ""]

    if args.dry_run:
        lines.append("Dry run — nothing uploaded or changed in App Store Connect.")
        build_id = "dry"
    else:
        if not args.skip_build:
            ipa = build_and_upload(args.build_number, key_path, key_id, issuer)
            lines.append(f"- uploaded `{ipa.name}`")
        build_id = wait_for_build(args.build_number)
        lines.append(f"- build {args.build_number} processed (id `{build_id}`)")
    lines.append("- " + testflight(build_id, whats_new, args.dry_run))
    lines.append("- " + app_store(build_id, args.marketing_version, whats_new, args.dry_run, args.skip_submit))
    text = "\n".join(lines) + "\n"
    print(text)
    if args.report:
        with args.report.open("a") as f:
            f.write("\n" + text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
