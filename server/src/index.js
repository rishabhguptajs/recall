// Recall license server: a Cloudflare Worker with a D1 database.
//
// The app talks to it only when someone activates or deactivates Pro, and about once a month
// afterwards to re-check. It sends the license key and an anonymous device ID (a hash), nothing else.
//
// App endpoints:
//   POST /v1/activate    {key, device} -> {token}   (uses one of the license's device slots)
//   POST /v1/validate    {key, device} -> {token}   (monthly re-check; fresh token)
//   POST /v1/deactivate  {key, device} -> {ok}      (frees the slot)
// Admin endpoints (Authorization: Bearer $ADMIN_TOKEN):
//   POST /v1/admin/licenses       {email, max_devices?, note?} -> {id, key}
//   GET  /v1/admin/licenses?email=…                           -> licenses with their devices
//   POST /v1/admin/revoke         {key} or {id}               (refunds, chargebacks)
//   POST /v1/admin/reset-devices  {key} or {id}               (frees every slot)
//
// Tokens are "<base64url(JSON payload)>.<base64url(Ed25519 signature of the first part)>".
// The app checks the signature with the public key it ships with, so tokens can't be forged.

const RECHECK_SECONDS = 30 * 24 * 3600;
const DEFAULT_MAX_DEVICES = 3;
const DEVICE_RE = /^[0-9a-f]{64}$/;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    try {
      if (request.method === "POST") {
        switch (url.pathname) {
          case "/v1/activate": return await activate(request, env);
          case "/v1/validate": return await validate(request, env);
          case "/v1/deactivate": return await deactivate(request, env);
          case "/v1/admin/licenses": return await admin(request, env, createLicense);
          case "/v1/admin/revoke": return await admin(request, env, revoke);
          case "/v1/admin/reset-devices": return await admin(request, env, resetDevices);
        }
      } else if (request.method === "GET" && url.pathname === "/v1/admin/licenses") {
        return await admin(request, env, (_, env) => listLicenses(url, env));
      } else if (request.method === "GET" && url.pathname === "/") {
        return json({ ok: true, service: "recall-license" });
      }
      return json({ error: "not_found" }, 404);
    } catch (err) {
      console.error(err);
      return json({ error: "server_error" }, 500);
    }
  },
};

// MARK: - App endpoints

async function activate(request, env) {
  const input = await readClientInput(request);
  if (input.error) return json(input, 400);
  const license = await findLicense(env, input.key);
  if (!license) return json({ error: "invalid_key" }, 404);
  if (license.status !== "active") return json({ error: "revoked" }, 403);

  const now = nowSeconds();
  const existing = await env.DB.prepare(
    "SELECT 1 FROM activations WHERE license_id = ? AND device = ?"
  ).bind(license.id, input.device).first();
  if (existing) {
    await touch(env, license.id, input.device, now);
  } else {
    // Insert only while the license still has a free slot (one statement, so two Macs
    // activating at the same moment can't both squeeze past the limit).
    const result = await env.DB.prepare(
      `INSERT INTO activations (license_id, device, activated_at, last_seen)
       SELECT ?1, ?2, ?3, ?3
       WHERE (SELECT COUNT(*) FROM activations WHERE license_id = ?1) < ?4`
    ).bind(license.id, input.device, now, license.max_devices).run();
    if (!result.meta.changes) {
      return json({ error: "device_limit", max_devices: license.max_devices }, 409);
    }
  }
  return json({ token: await signToken(env, license, input.device, now) });
}

async function validate(request, env) {
  const input = await readClientInput(request);
  if (input.error) return json(input, 400);
  const license = await findLicense(env, input.key);
  if (!license) return json({ error: "invalid_key" }, 404);
  if (license.status !== "active") return json({ error: "revoked" }, 403);
  const now = nowSeconds();
  const updated = await touch(env, license.id, input.device, now);
  if (!updated) return json({ error: "not_activated" }, 403);
  return json({ token: await signToken(env, license, input.device, now) });
}

async function deactivate(request, env) {
  const input = await readClientInput(request);
  if (input.error) return json(input, 400);
  const license = await findLicense(env, input.key);
  if (!license) return json({ error: "invalid_key" }, 404);
  await env.DB.prepare("DELETE FROM activations WHERE license_id = ? AND device = ?")
    .bind(license.id, input.device).run();
  return json({ ok: true });
}

// MARK: - Admin endpoints

async function admin(request, env, handler) {
  const expected = env.ADMIN_TOKEN;
  if (!expected) return json({ error: "admin_disabled" }, 503);
  const given = (request.headers.get("Authorization") || "").replace(/^Bearer /, "");
  if (!timingSafeEqual(given, expected)) return json({ error: "unauthorized" }, 401);
  return handler(request, env);
}

async function createLicense(request, env) {
  const body = await readJSON(request);
  const email = typeof body.email === "string" ? body.email.trim().slice(0, 254) : "";
  if (!email) return json({ error: "email_required" }, 400);
  const max = Number.isInteger(body.max_devices) && body.max_devices > 0 ? body.max_devices : DEFAULT_MAX_DEVICES;
  const key = newKey();
  const id = crypto.randomUUID();
  await env.DB.prepare(
    `INSERT INTO licenses (id, key_hash, email, max_devices, status, created_at, note)
     VALUES (?, ?, ?, ?, 'active', ?, ?)`
  ).bind(id, await sha256Hex(normalizeKey(key)), email, max, nowSeconds(),
         typeof body.note === "string" ? body.note.slice(0, 500) : null).run();
  return json({ id, key, email, max_devices: max });
}

async function listLicenses(url, env) {
  const email = url.searchParams.get("email");
  const licenses = email
    ? await env.DB.prepare("SELECT * FROM licenses WHERE email = ? ORDER BY created_at DESC").bind(email).all()
    : await env.DB.prepare("SELECT * FROM licenses ORDER BY created_at DESC LIMIT 100").all();
  const out = [];
  for (const l of licenses.results) {
    const devices = await env.DB.prepare(
      "SELECT device, activated_at, last_seen FROM activations WHERE license_id = ?"
    ).bind(l.id).all();
    const { key_hash, ...rest } = l;
    out.push({ ...rest, devices: devices.results });
  }
  return json({ licenses: out });
}

async function revoke(request, env) {
  const license = await licenseFromAdminBody(request, env);
  if (!license) return json({ error: "not_found" }, 404);
  await env.DB.prepare("UPDATE licenses SET status = 'revoked' WHERE id = ?").bind(license.id).run();
  return json({ ok: true, id: license.id });
}

async function resetDevices(request, env) {
  const license = await licenseFromAdminBody(request, env);
  if (!license) return json({ error: "not_found" }, 404);
  await env.DB.prepare("DELETE FROM activations WHERE license_id = ?").bind(license.id).run();
  return json({ ok: true, id: license.id });
}

async function licenseFromAdminBody(request, env) {
  const body = await readJSON(request);
  if (typeof body.id === "string") {
    return env.DB.prepare("SELECT * FROM licenses WHERE id = ?").bind(body.id).first();
  }
  if (typeof body.key === "string") return findLicense(env, body.key);
  return null;
}

// MARK: - Helpers

async function readClientInput(request) {
  const body = await readJSON(request);
  const key = typeof body.key === "string" ? normalizeKey(body.key) : "";
  const device = typeof body.device === "string" ? body.device.toLowerCase() : "";
  if (!key || key.length > 64) return { error: "bad_key" };
  if (!DEVICE_RE.test(device)) return { error: "bad_device" };
  return { key, device };
}

async function readJSON(request) {
  try {
    const body = await request.json();
    return body && typeof body === "object" ? body : {};
  } catch {
    return {};
  }
}

async function findLicense(env, key) {
  return env.DB.prepare("SELECT * FROM licenses WHERE key_hash = ?")
    .bind(await sha256Hex(normalizeKey(key))).first();
}

async function touch(env, licenseId, device, now) {
  const r = await env.DB.prepare("UPDATE activations SET last_seen = ? WHERE license_id = ? AND device = ?")
    .bind(now, licenseId, device).run();
  return r.meta.changes > 0;
}

async function signToken(env, license, device, now) {
  const payload = { v: 1, lid: license.id, dev: device, plan: "pro", iat: now, chk: now + RECHECK_SECONDS };
  const body = base64url(new TextEncoder().encode(JSON.stringify(payload)));
  const key = await signingKey(env);
  const sig = await crypto.subtle.sign({ name: "Ed25519" }, key, new TextEncoder().encode(body));
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

// Keys look like RCL-XXXXX-XXXXX-XXXXX-XXXXX (Crockford base32, 100 random bits).
function newKey() {
  const alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
  const bytes = crypto.getRandomValues(new Uint8Array(20));
  const chars = Array.from(bytes, (b) => alphabet[b & 31]).join("");
  return `RCL-${chars.match(/.{5}/g).join("-")}`;
}

function normalizeKey(key) {
  return key.trim().toUpperCase().replace(/\s+/g, "");
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

function timingSafeEqual(a, b) {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] || 0) ^ (y[i] || 0);
  return diff === 0;
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
