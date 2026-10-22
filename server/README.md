# Recall license server

A Cloudflare Worker with a D1 (SQLite) database. It issues license keys, limits each key to
3 Macs, and signs the Pro tokens the app checks offline. Cloudflare's free plan is enough.

The app only calls it when someone activates or deactivates Pro, and about every 30 days afterwards to re-check.
It sends the license key and an anonymous device hash. Free users never call it. If the server can't be reached,
Pro keeps working; only a "revoked" or "not activated" answer turns it off.

## Deploy (one time)

```bash
npm install -g wrangler
wrangler login
cd server
wrangler d1 create recall-license          # copy the database_id it prints into wrangler.toml
wrangler d1 migrations apply recall-license --remote
openssl pkey -in ../keys/license-signing.pem -outform DER | base64 | wrangler secret put SIGNING_KEY
openssl rand -hex 24                        # save this somewhere safe: it's your admin password
wrangler secret put ADMIN_TOKEN             # paste the value from the line above
wrangler deploy                             # prints https://recall-license.<you>.workers.dev
```

Then put that URL into `project.yml` (`RECALL_LICENSE_SERVER` under `Release`), and build the DMG
with `scripts/make-dmg.sh`.

## Issuing and managing keys

```bash
export URL=https://recall-license.<you>.workers.dev
export ADMIN=<your admin token>

# New key for a buyer (3 Macs by default)
curl -X POST $URL/v1/admin/licenses -H "Authorization: Bearer $ADMIN" \
  -H 'Content-Type: application/json' -d '{"email":"buyer@example.com"}'

# Look up a buyer's keys and Macs
curl "$URL/v1/admin/licenses?email=buyer@example.com" -H "Authorization: Bearer $ADMIN"

# Refund or chargeback: turn the key off (apps drop to Free at their next re-check)
curl -X POST $URL/v1/admin/revoke -H "Authorization: Bearer $ADMIN" \
  -H 'Content-Type: application/json' -d '{"key":"RCL-…"}'

# "I got a new Mac and can't deactivate the old one": free all slots
curl -X POST $URL/v1/admin/reset-devices -H "Authorization: Bearer $ADMIN" \
  -H 'Content-Type: application/json' -d '{"key":"RCL-…"}'
```

Only a SHA-256 hash of each key is stored, so the server can't show a key again after creating it.
Keep a copy, or create a new key and revoke the old one.

## Keys you must back up

- `keys/license-signing.pem` signs Pro tokens. The app ships with its public half
  (`Licensing/LicenseToken.swift`).
  - **If it leaks:** anyone can make Pro tokens. Generate a new key, ship an update with the new public key,
    and existing customers re-enter their key once.
  - **If it's lost:** same fix.
- `keys/recall-signing.p12` is the code-signing certificate (see the main README).

Both are git-ignored. Keep them in a password manager or an encrypted backup.

## Local development

`wrangler dev` reads secrets from `server/.dev.vars` (git-ignored):

```
SIGNING_KEY=<openssl pkey -in ../keys/license-signing.pem -outform DER | base64>
ADMIN_TOKEN=<any random string>
```

```bash
cd server
wrangler d1 migrations apply recall-license --local
wrangler dev --port 8787 --ip 127.0.0.1
```

Debug builds of the app talk to `http://127.0.0.1:8787`.

## Not built yet

- **Automatic key delivery after purchase.** Right now you issue keys with the curl command above. Once you pick a
  store (Lemon Squeezy, Paddle, Gumroad…), add a webhook endpoint that verifies the store's signature,
  calls the same code as `/v1/admin/licenses`, and emails the key (or let the store email it).
- **Rate limiting.** Keys carry 100 random bits, so guessing them isn't practical. Cloudflare's rate-limiting
  rules can still be added in the dashboard if needed.
