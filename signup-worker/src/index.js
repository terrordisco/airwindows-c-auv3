// Cloudflare Worker for the Airwindows AUv3 beta signup form.
//
// Two endpoints:
//   POST /signup       — body: { email }. Stores in KV. Returns { ok: true }.
//   GET  /export?key=… — returns all signups as CSV. Gated by EXPORT_KEY secret.
//
// Storage: a single KV namespace bound as `SIGNUPS`. The key is the lowercased
// email (so duplicate signups overwrite the timestamp instead of accumulating);
// the value is JSON `{ email, timestamp }`.
//
// CORS: the signup endpoint allows POST from any origin, so the form on
// terrordisco.github.io can submit directly.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function json(body, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, ...extraHeaders, "Content-Type": "application/json" },
  });
}

async function handleSignup(request, env) {
  let payload;
  try {
    payload = await request.json();
  } catch {
    return json({ ok: false, error: "invalid_body" }, 400);
  }

  const email = (payload?.email ?? "").trim().toLowerCase();
  if (!EMAIL_RE.test(email)) {
    return json({ ok: false, error: "invalid_email" }, 400);
  }

  const timestamp = new Date().toISOString();
  await env.SIGNUPS.put(email, JSON.stringify({ email, timestamp }));
  return json({ ok: true });
}

async function handleExport(request, env) {
  const url = new URL(request.url);
  const auth = url.searchParams.get("key");
  if (!env.EXPORT_KEY || auth !== env.EXPORT_KEY) {
    return new Response("unauthorized", { status: 401 });
  }

  const rows = ["email,timestamp"];
  let cursor;
  do {
    const page = await env.SIGNUPS.list({ cursor });
    for (const k of page.keys) {
      const raw = await env.SIGNUPS.get(k.name);
      if (!raw) continue;
      try {
        const { email, timestamp } = JSON.parse(raw);
        rows.push(`${email},${timestamp}`);
      } catch {
        // Skip malformed entry rather than fail the whole export.
      }
    }
    cursor = page.list_complete ? null : page.cursor;
  } while (cursor);

  return new Response(rows.join("\n"), {
    headers: { "Content-Type": "text/csv; charset=utf-8" },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    if (url.pathname === "/signup" && request.method === "POST") {
      return handleSignup(request, env);
    }

    if (url.pathname === "/export" && request.method === "GET") {
      return handleExport(request, env);
    }

    return new Response("not found", { status: 404 });
  },
};
