#!/usr/bin/env python3
"""Tiny App Store Connect API client (no third-party deps).

Signs an ES256 JWT with openssl using the team's API key and issues GET /
POST / PATCH requests. Used for release automation: checking build
processing, attaching a build to an App Store version, submitting for review.

Usage:  python3 scripts/asc.py GET  "builds?filter[app]=6775213422&limit=3"
        python3 scripts/asc.py POST reviewSubmissions '{"data": {...}}'
        python3 scripts/asc.py PATCH appStoreVersions/<id> '{"data": {...}}'
Key/issuer come from env ASC_KEY_ID / ASC_ISSUER_ID or the defaults below;
the .p8 lives at ~/.appstoreconnect/private_keys/AuthKey_<KEY>.p8.
"""
import base64, json, os, subprocess, sys, time, urllib.request, urllib.error

KEY = os.environ.get("ASC_KEY_ID", "23QZ996SQM")
ISS = os.environ.get("ASC_ISSUER_ID", "e5d9a5e4-37a2-4caa-8c77-6da3ac0f84c0")
P8 = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY}.p8")
BASE = "https://api.appstoreconnect.apple.com/v1/"

def b64(b): return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

def token():
    hdr = b64(json.dumps({"alg": "ES256", "kid": KEY, "typ": "JWT"}).encode())
    now = int(time.time())
    pay = b64(json.dumps({"iss": ISS, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}).encode())
    msg = f"{hdr}.{pay}".encode()
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", P8], input=msg, check=True, capture_output=True).stdout
    i = 2; assert der[0] == 0x30 and der[i] == 0x02
    l = der[i + 1]; r = der[i + 2:i + 2 + l]; i = i + 2 + l
    assert der[i] == 0x02; l = der[i + 1]; s = der[i + 2:i + 2 + l]
    raw = r[-32:].rjust(32, b"\0") + s[-32:].rjust(32, b"\0")
    return f"{hdr}.{pay}.{b64(raw)}"

def call(method, path, body=None):
    url = path if path.startswith("http") else BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:
            text = resp.read().decode()
            return resp.status, (json.loads(text) if text else {})
    except urllib.error.HTTPError as e:
        text = e.read().decode()
        try: return e.code, json.loads(text)
        except Exception: return e.code, {"raw": text}

if __name__ == "__main__":
    method, path = sys.argv[1], sys.argv[2]
    raw = sys.argv[3] if len(sys.argv) > 3 else None
    # "@path" reads the JSON body from a file (sidesteps shell quoting).
    body = json.load(open(raw[1:])) if raw and raw.startswith("@") else (json.loads(raw) if raw else None)
    status, out = call(method, path, body)
    print(status); print(json.dumps(out, indent=2))
