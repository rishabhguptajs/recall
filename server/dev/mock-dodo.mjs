// Local stand-in for Dodo Payments' public license API, for testing without a Dodo account.
// Responses match what test.dodopayments.com returns (checked against the real endpoint).
//
//   node server/dev/mock-dodo.mjs            # listens on http://127.0.0.1:8788
//   set DODO_API_BASE=http://127.0.0.1:8788 in server/.dev.vars, then `wrangler dev`
//
// Test helpers (not part of Dodo):
//   POST /mock/keys {limit}        -> {key}      new active key (like a purchase)
//   POST /mock/disable {key}                     like a refund
//   POST /mock/remove-instance {id}              like removing a device in the dashboard
//   GET  /mock/state                             everything, for checking
import { createServer } from "node:http";
import { randomUUID } from "node:crypto";

const keys = new Map(); // key -> {id, status, limit, instances: Map(id -> name)}
const notFound = { code: "NOT_FOUND", message: "The requested resource could not be found." };
const badBody = { code: "INVALID_REQUEST_BODY", message: "A field in the request body has an invalid value." };

const routes = {
  "POST /licenses/activate": ({ license_key, name }) => {
    if (typeof license_key !== "string" || typeof name !== "string") return [422, badBody];
    const k = keys.get(license_key);
    if (!k) return [404, notFound];
    if (k.status !== "active") return [403, { code: "FORBIDDEN", message: "License key is not active" }];
    if (k.instances.size >= k.limit) return [422, { code: "LIMIT_REACHED", message: "Activation limit reached" }];
    const id = "lki_" + randomUUID().slice(0, 8);
    k.instances.set(id, name);
    return [201, {
      id, business_id: "bus_mock", name, license_key_id: k.id, created_at: new Date().toISOString(),
      product: { product_id: "pdt_mock", name: "Recall Pro" },
      customer: { customer_id: "cus_mock", name: "Test Buyer", email: "buyer@example.com", phone_number: null },
    }];
  },
  "POST /licenses/validate": ({ license_key, license_key_instance_id }) => {
    if (typeof license_key !== "string") return [422, badBody];
    const k = keys.get(license_key);
    const valid = !!k && k.status === "active" &&
      (license_key_instance_id == null || k.instances.has(license_key_instance_id));
    return [200, { valid }];
  },
  "POST /licenses/deactivate": ({ license_key, license_key_instance_id }) => {
    const k = keys.get(license_key);
    if (!k || !k.instances.has(license_key_instance_id)) return [404, notFound];
    k.instances.delete(license_key_instance_id);
    return [200, {}];
  },
  "POST /mock/keys": ({ limit = 3 }) => {
    const key = randomUUID();
    keys.set(key, { id: "lic_" + randomUUID().slice(0, 8), status: "active", limit, instances: new Map() });
    return [200, { key }];
  },
  "POST /mock/disable": ({ key }) => {
    const k = keys.get(key);
    if (k) k.status = "disabled";
    return [200, { ok: !!k }];
  },
  "POST /mock/remove-instance": ({ id }) => {
    for (const k of keys.values()) k.instances.delete(id);
    return [200, { ok: true }];
  },
  "GET /mock/state": () => [200, Object.fromEntries([...keys].map(([key, k]) =>
    [key, { ...k, instances: Object.fromEntries(k.instances) }]))],
};

createServer(async (req, res) => {
  let raw = "";
  for await (const chunk of req) raw += chunk;
  let body = {};
  try { body = raw ? JSON.parse(raw) : {}; } catch { /* keep {} */ }
  const route = routes[`${req.method} ${req.url}`];
  const [status, out] = route ? route(body) : [404, notFound];
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(out));
}).listen(8788, "127.0.0.1", () => console.log("mock Dodo on http://127.0.0.1:8788"));
