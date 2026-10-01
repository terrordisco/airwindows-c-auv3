#!/usr/bin/env python3
"""Upload App Store screenshots into an existing screenshot set via the App
Store Connect API: reserve (POST appScreenshots) → PUT the bytes to the
returned upload operations → commit (PATCH uploaded=true + MD5).

Usage: python3 scripts/asc_upload_screenshots.py <screenshotSetId> <png> [<png> …]
Files are uploaded in the order given, which becomes the display order.
"""
import hashlib, json, os, sys, urllib.request
sys.path.insert(0, os.path.dirname(__file__))
import asc

def upload(set_id, path):
    data = open(path, "rb").read()
    name = os.path.basename(path)
    status, res = asc.call("POST", "appScreenshots", {"data": {
        "type": "appScreenshots",
        "attributes": {"fileName": name, "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})
    if status != 201:
        print("reserve failed", name, status, json.dumps(res)[:400]); return False
    shot = res["data"]; sid = shot["id"]
    for op in shot["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"],
                                     headers={h["name"]: h["value"] for h in op["requestHeaders"]})
        with urllib.request.urlopen(req) as r:
            if r.status not in (200, 201, 204): print("chunk failed", r.status); return False
    status, res = asc.call("PATCH", f"appScreenshots/{sid}", {"data": {
        "type": "appScreenshots", "id": sid,
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    ok = status == 200
    print(("ok  " if ok else "FAIL"), name, status if not ok else "")
    return ok

if __name__ == "__main__":
    set_id, files = sys.argv[1], sys.argv[2:]
    all_ok = all(upload(set_id, f) for f in files)
    sys.exit(0 if all_ok else 1)
