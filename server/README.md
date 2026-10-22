# Recall license server

A small Cloudflare Worker in front of **Dodo Payments' license key API**. The free Cloudflare plan is enough.

**Dodo Payments handles:**
- creating license keys
- emailing them to buyers
- the activation limit
- turning keys off on refunds

**This Worker adds** a token signed with Ed25519 and tied to one Mac. The app checks it offline, so copying the
license file to another Mac doesn't share a slot. The Worker keeps one row per activated Mac (a key hash, an
anonymous device hash and Dodo's instance ID). It doesn't keep the customer's name or email.

**When the app calls it:** only on activate and deactivate, and about every 30 days afterwards to re-check. It sends
the license key and the anonymous device hash. Free users never call it.

**When Pro turns off:** if Dodo or the Worker is down, Pro keeps working. Only a refunded or disabled key, or a Mac
removed in the Dodo dashboard, turns Pro off.

## Set up the product in Dodo Payments

1. Create the product (one-time payment), then turn on **License keys** for it.
2. **Activations limit:** 3. **License length:** No expiration.
3. Optional: add an activation message, for example "Open Recall → Settings → License and paste this key."
   Dodo includes it in the email with the key.
4. **To test first:** do all of this in **Test mode**, make a test purchase, and use that key.
   Set `DODO_API_BASE = "https://test.dodopayments.com"` in `wrangler.toml` while you do.

## Deploy (one time)

```bash
npm install -g wrangler
wrangler login
cd server
wrangler d1 create recall-license          # copy the database_id it prints into wrangler.toml
wrangler d1 migrations apply recall-license --remote
openssl pkey -in ../keys/license-signing.pem -outform DER | base64 | wrangler secret put SIGNING_KEY
wrangler deploy                             # prints https://recall-license.<you>.workers.dev
```

Next:
1. Put that URL into `project.yml` (`RECALL_LICENSE_SERVER` under `Release`).
2. Build the DMG with `scripts/make-dmg.sh`.
3. Before going live, set `DODO_API_BASE` back to `https://live.dodopayments.com` and run `wrangler deploy` again.

## Support cases

Everything is done in the Dodo Payments dashboard:
- **Refund:** the key turns off automatically. The buyer's Macs drop to Free at their next monthly re-check.
- **"I got a new Mac and can't deactivate the old one":** remove that activation instance from the key in Dodo.
  It frees the slot, and the old Mac drops to Free at its next re-check.
- **Lost key:** Dodo can resend it, or look it up by the buyer's email.

## Keys you must back up

- `keys/license-signing.pem` signs Pro tokens. The app ships with its public half
  (`Licensing/LicenseToken.swift`).
  - **If it leaks:** anyone can make Pro tokens. Generate a new key and ship an update with its public half.
    Customers then re-enter their key once.
  - **If it's lost:** same fix.
- `keys/recall-signing.p12` and `keys/recall-signing-password.txt` are the code-signing certificate (see the main README).

All of them are git-ignored. Keep them in a password manager or an encrypted backup.

## Local development (no Dodo account needed)

`dev/mock-dodo.mjs` imitates Dodo's license endpoints. Its responses were checked against `test.dodopayments.com`.

`server/.dev.vars` (git-ignored):
```
SIGNING_KEY=<openssl pkey -in ../keys/license-signing.pem -outform DER | base64>
DODO_API_BASE=http://127.0.0.1:8788
```

```bash
node server/dev/mock-dodo.mjs &            # mock Dodo on :8788
cd server
wrangler d1 migrations apply recall-license --local
wrangler dev --port 8787 --ip 127.0.0.1    # Debug builds of the app use this
curl -X POST localhost:8788/mock/keys -d '{"limit":3}'   # a test key, like a purchase
```

To test against real Dodo test mode instead, set `DODO_API_BASE=https://test.dodopayments.com` and use a key from a
test purchase.
