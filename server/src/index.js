// Recall license server: a Cloudflare Worker in front of Dodo Payments' license API.
//
// Dodo Payments creates license keys, emails them to buyers, enforces the activation limit
// (set on the product in the Dodo dashboard) and disables keys on refunds. This Worker adds what
// Dodo doesn't: a token signed with Ed25519 and tied to one Mac, which the app checks offline, so a
// copied license file doesn't work on another Mac.
//
// The app talks to it only when someone activates or deactivates Pro, and about once a month
// afterwards to re-check. It sends the license key and an anonymous device ID (a hash), nothing else.
//
//   POST /v1/activate    {key, device} -> {token}
//   POST /v1/validate    {key, device} -> {token}
//   POST /v1/deactivate  {key, device} -> {ok}
//
// It also serves the app's downloads from the R2 bucket RELEASES (only these names, nothing else):
//   GET /appcast.xml                 Sparkle update feed (raegent.com/recall/appcast.xml proxies it)
//   GET /download/latest             redirects to the newest Recall-<version>.dmg
//   GET /download/Recall-<v>.dmg     the DMG (supports Range, so interrupted downloads resume)
//
// Counting (anonymous, a number per day, nothing about the person): each DMG download and each
// update check (by app version, from Sparkle's User-Agent). GET /v1/stats with
// "Authorization: Bearer <STATS_TOKEN>" returns those counts plus Pro activation numbers.
//
// Errors the app acts on: invalid_key (404), revoked (403), not_activated (403), device_limit (409).
// Any Dodo outage becomes upstream_error (502), which the app ignores (Pro keeps working).
//
// Tokens are "<base64url(JSON payload)>.<base64url(Ed25519 signature of the first part)>".

const RECHECK_SECONDS = 30 * 24 * 3600;
const DEVICE_RE = /^[0-9a-f]{64}$/;
const DODO_TIMEOUT_MS = 10_000;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    try {
      if (request.method === "POST") {
        switch (url.pathname) {
          case "/v1/activate": return await activate(request, env);
          case "/v1/validate": return await validate(request, env);
          case "/v1/deactivate": return await deactivate(request, env);
        }
      } else if (request.method === "GET" || request.method === "HEAD") {
        if (url.pathname === "/") return json({ ok: true, service: "recall-license" });
        if (url.pathname === "/v1/stats") return await stats(request, env);
        const download = await serveRelease(request, env, url, ctx);
        if (download) return download;
      }
      return json({ error: "not_found" }, 404);
    } catch (err) {
      if (err instanceof UpstreamError) return json({ error: "upstream_error" }, 502);
      console.error(err);
      return json({ error: "server_error" }, 500);
    }
  },
};

// MARK: - Downloads

const DMG_RE = /^Recall-\d+(\.\d+){1,3}\.dmg$/;

async function serveRelease(request, env, url, ctx) {
  if (!env.RELEASES) return null;
  if (url.pathname === "/download/latest") {
    const latest = await latestDmg(env);
    if (!latest) return json({ error: "not_found" }, 404);
    return new Response(null, { status: 302, headers: { Location: `${url.origin}/download/${latest}`, "Cache-Control": "no-store" } });
  }
  let key = null, type = "", cache = "";
  if (url.pathname === "/appcast.xml") {
    key = "appcast.xml"; type = "application/xml; charset=utf-8"; cache = "public, max-age=300";
  } else if (url.pathname.startsWith("/download/") && DMG_RE.test(url.pathname.slice(10))) {
    key = url.pathname.slice(10); type = "application/x-apple-diskimage"; cache = "public, max-age=31536000, immutable";
  }
  if (!key) return null;
  const range = parseRange(request.headers.get("Range"));
  const object = request.method === "HEAD"
    ? await env.RELEASES.head(key)
    : await env.RELEASES.get(key, range ? { range } : {});
  if (!object) return json({ error: "not_found" }, 404);
  if (request.method === "GET" && ctx) {
    if (key === "appcast.xml") {
      const v = /Recall\/([\d.]+)/.exec(request.headers.get("User-Agent") ?? "")?.[1] ?? "unknown";
      ctx.waitUntil(count(env, `update_check:${v}`));
    } else if (!range || (range.offset ?? -1) === 0) {
      ctx.waitUntil(count(env, `download:${key.slice(7, -4)}`)); // first chunk only, so resumes don't double count
    }
  }
  const headers = new Headers({ "Content-Type": type, "Cache-Control": cache, "Accept-Ranges": "bytes", ETag: object.httpEtag });
  if (type.startsWith("application/x-apple")) headers.set("Content-Disposition", `attachment; filename="${key}"`);
  if (range && object.range && request.method !== "HEAD") {
    const start = object.range.offset ?? 0;
    const length = object.range.length ?? object.size - start;
    headers.set("Content-Range", `bytes ${start}-${start + length - 1}/${object.size}`);
    headers.set("Content-Length", String(length));
    return new Response(object.body, { status: 206, headers });
  }
  headers.set("Content-Length", String(object.size));
  return new Response(request.method === "HEAD" ? null : object.body, { headers });
}

function parseRange(header) {
  const m = /^bytes=(\d*)-(\d*)$/.exec(header ?? "");
  if (!m || (m[1] === "" && m[2] === "")) return null;
  if (m[1] === "") return { suffix: Number(m[2]) };
  const offset = Number(m[1]);
  return m[2] === "" ? { offset } : { offset, length: Number(m[2]) - offset + 1 };
}

async function latestDmg(env) {
  const listed = await env.RELEASES.list({ prefix: "Recall-" });
  const names = listed.objects.map((o) => o.key).filter((k) => DMG_RE.test(k));
  const version = (k) => k.slice(7, -4).split(".").map(Number);
  names.sort((a, b) => {
    const x = version(a), y = version(b);
    for (let i = 0; i < Math.max(x.length, y.length); i++) if ((x[i] ?? 0) !== (y[i] ?? 0)) return (x[i] ?? 0) - (y[i] ?? 0);
    return 0;
  });
  return names.at(-1) ?? null;
}

// MARK: - Counters

async function count(env, name) {
  try {
    await env.DB.prepare(
      "INSERT INTO counters (day, name, value) VALUES (?1, ?2, 1) ON CONFLICT (day, name) DO UPDATE SET value = value + 1",
    ).bind(new Date().toISOString().slice(0, 10), name).run();
  } catch (err) {
    console.error("count failed", err); // counting must never break a download
  }
}

async function stats(request, env) {
  const token = env.STATS_TOKEN;
  const auth = request.headers.get("Authorization") ?? "";
  if (!token || !(await timingSafeEqual(auth, `Bearer ${token}`))) return json({ error: "unauthorized" }, 401);
  const now = nowSeconds();
  const totals = await env.DB.prepare("SELECT name, SUM(value) AS total FROM counters GROUP BY name ORDER BY name").all();
  const days = await env.DB.prepare(
    "SELECT day, name, value FROM counters WHERE day >= date('now', '-30 days') ORDER BY day DESC, name",
  ).all();
  const pro = await env.DB.prepare(
    `SELECT COUNT(*) AS activations, COUNT(DISTINCT key_hash) AS licenses,
            SUM(CASE WHEN last_seen >= ?1 THEN 1 ELSE 0 END) AS active_macs_35d
     FROM activations`,
  ).bind(now - 35 * 24 * 3600).first();
  return json({ totals: totals.results, last_30_days: days.results, pro });
}

async function timingSafeEqual(a, b) {
  const [x, y] = await Promise.all([a, b].map((v) => crypto.subtle.digest("SHA-256", new TextEncoder().encode(v))));
  const u = new Uint8Array(x), w = new Uint8Array(y);
  let diff = 0;
  for (let i = 0; i < u.length; i++) diff |= u[i] ^ w[i];
  return diff === 0;
}

// MARK: - Endpoints

async function activate(request, env) {
  const input = await readClientInput(request);
  if (input.error) return json(input, 400);
  const keyHash = await sha256Hex(input.key);
  const now = nowSeconds();

  // Same Mac activating again (reinstall, re-entered key): reuse its Dodo instance instead of
  // creating a new one, which would use up another slot.
  const existing = await findActivation(env, keyHash, input.device);
  if (existing) {
    const valid = await dodoValidate(env, input.key, existing.instance_id);
    if (valid) {
      await touch(env, keyHash, input.device, now);
      return json({ token: await signToken(env, existing.license_key_id, input.device, now) });
    }
    // Instance removed in Dodo (or key disabled): forget it and try a fresh activation below,
    // which reports "revoked" if the key itself is off.
    await deleteActivation(env, keyHash, input.device);
  }

  const res = await dodo(env, "/licenses/activate", {
    license_key: input.key,
    name: `recall-${input.device.slice(0, 16)}`, // anonymous: never the Mac's name
  });
  if (res.status === 404) return json({ error: "invalid_key" }, 404);
  if (res.status === 403) return json({ error: "revoked" }, 403);
  if (res.status === 422) return json({ error: "device_limit" }, 409);
  if (res.status !== 200 && res.status !== 201) throw new UpstreamError(res.status);
  // Only the IDs are kept; the customer details Dodo returns are not stored or logged.
  const instanceId = res.body.id;
  const licenseKeyId = res.body.license_key_id || "dodo";
  if (typeof instanceId !== "string") throw new UpstreamError("no instance id");

  // Dodo's public endpoints accept keys for ANY Dodo merchant's product, so only keys for
  // Recall's own product(s) count. Anything else: undo the activation and refuse the key.
  if (!isOurProduct(env, res.body)) {
    await dodo(env, "/licenses/deactivate", { license_key: input.key, license_key_instance_id: instanceId })
      .catch(() => {});
    return json({ error: "invalid_key" }, 404);
  }

  await env.DB.prepare(
    `INSERT OR REPLACE INTO activations (key_hash, device, instance_id, license_key_id, activated_at, last_seen)
     VALUES (?, ?, ?, ?, ?, ?)`
  ).bind(keyHash, input.device, instanceId, licenseKeyId, now, now).run();
  return json({ token: await signToken(env, licenseKeyId, input.device, now) });
}

async function validate(request, env) {
  const input = await readClientInput(request);
  if (input.error) return json(input, 400);
  const keyHash = await sha256Hex(input.key);
  const activation = await findActivation(env, keyHash, input.device);
  if (!activation) return json({ error: "not_activated" }, 403);
  const valid = await dodoValidate(env, input.key, activation.instance_id);
  // Refunded, disabled or expired key, or this Mac was removed in the Dodo dashboard.
  if (!valid) return json({ error: "revoked" }, 403);
  const now = nowSeconds();
  await touch(env, keyHash, input.device, now);
  return json({ token: await signToken(env, activation.license_key_id, input.device, now) });
}

async function deactivate(request, env) {
  const input = await readClientInput(request);
  if (input.error) return json(input, 400);
  const keyHash = await sha256Hex(input.key);
  const activation = await findActivation(env, keyHash, input.device);
  if (activation) {
    const res = await dodo(env, "/licenses/deactivate", {
      license_key: input.key,
      license_key_instance_id: activation.instance_id,
    });
    // 404: already gone in Dodo. Anything else unexpected: report it, keep the record.
    if (res.status >= 300 && res.status !== 404) throw new UpstreamError(res.status);
    await deleteActivation(env, keyHash, input.device);
  }
  return json({ ok: true });
}

// MARK: - Dodo Payments

/**
 * DODO_PRODUCT_IDS: comma-separated product IDs that unlock Pro (required).
 * DODO_BUSINESS_ID: your business ID (optional extra check).
 * Fails closed: if DODO_PRODUCT_IDS isn't set, no key is accepted.
 */
function isOurProduct(env, body) {
  const allowed = String(env.DODO_PRODUCT_IDS || "").split(",").map((s) => s.trim()).filter(Boolean);
  const product = body && body.product && body.product.product_id;
  if (!allowed.length || !allowed.includes(product)) return false;
  if (env.DODO_BUSINESS_ID && body.business_id !== env.DODO_BUSINESS_ID) return false;
  return true;
}

class UpstreamError extends Error {}

/** Public license endpoints: no API key needed. DODO_API_BASE is test or live. */
async function dodo(env, path, body) {
  const base = (env.DODO_API_BASE || "https://live.dodopayments.com").replace(/\/$/, "");
  let res;
  try {
    res = await fetch(base + path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(DODO_TIMEOUT_MS),
    });
  } catch (err) {
    throw new UpstreamError(String(err));
  }
  let parsed = {};
  try { parsed = await res.json(); } catch { /* empty or non-JSON body */ }
  if (res.status >= 500) throw new UpstreamError(res.status);
  return { status: res.status, body: parsed || {} };
}

/** true / false from Dodo; throws UpstreamError when Dodo can't answer. */
async function dodoValidate(env, key, instanceId) {
  const res = await dodo(env, "/licenses/validate", { license_key: key, license_key_instance_id: instanceId });
  if (res.status !== 200 || typeof res.body.valid !== "boolean") throw new UpstreamError(res.status);
  return res.body.valid;
}

// MARK: - Storage

function findActivation(env, keyHash, device) {
  return env.DB.prepare("SELECT * FROM activations WHERE key_hash = ? AND device = ?").bind(keyHash, device).first();
}

function deleteActivation(env, keyHash, device) {
  return env.DB.prepare("DELETE FROM activations WHERE key_hash = ? AND device = ?").bind(keyHash, device).run();
}

function touch(env, keyHash, device, now) {
  return env.DB.prepare("UPDATE activations SET last_seen = ? WHERE key_hash = ? AND device = ?")
    .bind(now, keyHash, device).run();
}

// MARK: - Helpers

async function readClientInput(request) {
  let body = {};
  try { body = (await request.json()) || {}; } catch { /* bad JSON */ }
  // Dodo keys are case-sensitive, so only surrounding whitespace is removed.
  const key = typeof body.key === "string" ? body.key.trim() : "";
  const device = typeof body.device === "string" ? body.device.toLowerCase() : "";
  if (!key || key.length > 128) return { error: "bad_key" };
  if (!DEVICE_RE.test(device)) return { error: "bad_device" };
  return { key, device };
}

async function signToken(env, licenseId, device, now) {
  const payload = { v: 1, lid: licenseId, dev: device, plan: "pro", iat: now, chk: now + RECHECK_SECONDS };
  const body = base64url(new TextEncoder().encode(JSON.stringify(payload)));
  const sig = await crypto.subtle.sign({ name: "Ed25519" }, await signingKey(env), new TextEncoder().encode(body));
  return `${body}.${base64url(new Uint8Array(sig))}`;
}

let cachedKey;
async function signingKey(env) {
  if (!cachedKey) {
    if (!env.SIGNING_KEY) throw new Error("SIGNING_KEY secret is not set");
    const der = Uint8Array.from(atob(env.SIGNING_KEY), (c) => c.charCodeAt(0));
    cachedKey = await crypto.subtle.importKey("pkcs8", der, { name: "Ed25519" }, false, ["sign"]);
  }
  return cachedKey;
}

async function sha256Hex(s) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function base64url(bytes) {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}
