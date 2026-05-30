# Beta signup landing page

Single-file static page that gates the TestFlight invite link behind a tiny email + Discord form. Used to capture the tester list ourselves, since Apple's public TestFlight link doesn't tell you who joined.

## What you need to wire up before publishing

Two placeholder strings inside `index.html`:

1. **`REPLACE_WITH_YOUR_FORM_ENDPOINT`** — a form backend URL that accepts a POST. Easiest options:

   - **[Formspree](https://formspree.io/)** — free tier: 50 submissions/month. Sign up, create a form, paste the `https://formspree.io/f/xxxxxxxx` URL into the `data-endpoint` attribute. You'll get an email per submission and a CSV export in the dashboard.
   - **[Tally](https://tally.so/)** — free, prettier dashboard, unlimited submissions on the free tier. You can either embed a Tally form directly (replace the `<form>` block with their embed) or use Tally's "Webhooks" target with the same `data-endpoint` pattern.
   - **[Netlify Forms](https://docs.netlify.com/forms/setup/)** — free if you host the page on Netlify (you'd swap GitHub Pages for Netlify Pages). Add `netlify` and `data-netlify="true"` to the form tag.

2. **`REPLACE_WITH_TESTFLIGHT_URL`** — the public testflight.apple.com link, available once the first beta build is approved.

Until both are filled in, the form works in a "demo mode": valid email submissions skip the network call and show the reveal card directly, so you can test the visual flow.

## Hosting

The easiest path: **GitHub Pages**.

```
Settings → Pages → Build and deployment
  Source:  Deploy from a branch
  Branch:  main / (root)  →  /landing
```

Once enabled, the page is reachable at `https://terrordisco.github.io/airwindows-c-auv3/`. Note that the `airwindows_logo.jpg` is loaded via relative path from the repo root, so the page expects to be served from the `landing/` directory with the logo one level up — that doesn't work on GitHub Pages by default.

**Fix:** either copy `airwindows_logo.jpg` into `landing/`, or change the `<img>` and Open Graph image references to `../airwindows_logo.jpg`. The simpler move is to just symlink or copy the logo into `landing/`.

If you outgrow GitHub Pages, **Cloudflare Pages** is the next stop — same simplicity, supports redirects and custom domains more cleanly.

## Local preview

```bash
cd landing
python3 -m http.server 8080
# open http://localhost:8080/
```
