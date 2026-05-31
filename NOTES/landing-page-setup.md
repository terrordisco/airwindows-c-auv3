# Beta signup landing page

Single-file static page at `docs/index.html` that captures tester emails before revealing the TestFlight invite link. Hosted via GitHub Pages on the `main` branch from the `/docs` folder. The page is reachable at `https://terrordisco.github.io/airwindows-c-auv3/` once Pages is enabled.

We capture emails ourselves because Apple's public TestFlight link doesn't expose tester identities — without our own gate, we'd have no way to email beta-2 announcements, ship updates, or close the loop with people who actually showed up.

Discord is offered alongside, never required.

## Form backend — Cloudflare Worker

The form POSTs to a Cloudflare Worker at `https://airwindows-beta-signup.svei.workers.dev/signup`. Source lives in `signup-worker/` at the repo root.

**Why a self-hosted Worker rather than Formspree / Netlify Forms / EmailOctopus:**

- Free third-party form services cap free tiers at 50–100 submissions/month — generous in theory, awkward in practice once a beta gets traction.
- The Worker has effectively no cap (Cloudflare's free tier covers 100K requests/day).
- Submissions live in a KV namespace we own, not in someone else's CSV exporter.

**Architecture:**

- `POST /signup` — body `{ email }`. Validates, stores in KV with the lowercased email as the key. Returns `{ ok: true }`.
- `GET /export?key=…` — gated by the `EXPORT_KEY` secret. Returns CSV of all signups.

`signup-worker/src/index.js` is the entire Worker — ~80 lines including comments.

## TestFlight URL

The page hides the public TestFlight URL behind the form submission. After a valid email is captured, JS reveals the link. The URL itself is a placeholder (`REPLACE_WITH_TESTFLIGHT_URL`) until Apple approves the build for external testing — at that point, edit `docs/index.html` line ~323 and replace the `href`.

## Hosting

GitHub Pages, served from `main` branch, `/docs` folder.

Enable via:

```
GitHub repo → Settings → Pages → Build and deployment
  Source:  Deploy from a branch
  Branch:  main / /docs
```

The `airwindows_logo.jpg` lives alongside `index.html` and `privacy.html` inside `docs/`, so the relative `src="airwindows_logo.jpg"` references resolve cleanly.

## Privacy policy

`docs/privacy.html` is the required URL for App Store Connect (Settings → App Information → Privacy Policy URL). It declares no data collection — true for the plugin itself; the landing-page form's stored emails are administrative use only.

## Local preview

```bash
cd docs
python3 -m http.server 8080
# open http://localhost:8080/
```

The form will work against the live Worker even in local dev — CORS allows any origin.

## Re-deploying the Worker

```bash
cd signup-worker
wrangler deploy
```

Secret rotation:

```bash
wrangler secret put EXPORT_KEY     # prompts for value
```

Browsing signups:

```bash
wrangler kv key list --namespace-id 25ad6a4616544215af5912411738d15c --remote
# Or via the Cloudflare dashboard → Workers & Pages → KV → SIGNUPS
```
