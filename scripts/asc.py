#!/usr/bin/env python3
"""Tiny App Store Connect API client (no third-party deps).

Signs an ES256 JWT with openssl using the team's API key and issues GET /
POST / PATCH requests. Used for release automation: checking build
processing, attaching a build to an App Store version, submitting for review.

Usage:  python3 scripts/asc.py GET  "builds?filter[app]=6775213422&limit=3"
        python3 scripts/asc.py POST reviewSubmissions '{"data": {...}}'
        python3 scripts/asc.py PATCH appStoreVersions/<id> '{"data": {...}}'
Credentials never live in this (public) repo. Key ID and issuer ID come from
env ASC_KEY_ID / ASC_ISSUER_ID (ASC_API_KEY_ID / ASC_API_ISSUER_ID also work,
that's what the GitHub workflow sets), else from ~/.appstoreconnect/asc.json:

    {"key_id": "XXXXXXXXXX", "issuer_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"}

The .p8 private key lives at ~/.appstoreconnect/private_keys/AuthKey_<KEY>.p8
(or wherever ASC_API_KEY_PATH points).
"""
import base64, json, os, subprocess, sys, time, urllib.request, urllib.error

_CONFIG = os.path.expanduser("~/.appstoreconnect/asc.json")


def _credential(env_names: tuple[str, ...], config_key: str) -> str:
    for name in env_names:
        if os.environ.get(name):
            return os.environ[name]
    if os.path.exists(_CONFIG):
        with open(_CONFIG) as f:
            value = json.load(f).get(config_key)
        if value:
            return value
    sys.exit(f"asc.py: no {config_key} — set {env_names[0]} or add it to {_CONFIG}")


KEY = _credential(("ASC_KEY_ID", "ASC_API_KEY_ID"), "key_id")
ISS = _credential(("ASC_ISSUER_ID", "ASC_API_ISSUER_ID"), "issuer_id")
P8 = os.environ.get("ASC_API_KEY_PATH") or os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY}.p8")
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
