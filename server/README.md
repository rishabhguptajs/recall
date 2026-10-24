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

**When the app calls it:** for the 14-day trial (`POST /v1/trial`, device hash only, at first launch and about every 6
hours until the trial ends), on activate and deactivate, and about every 30 days afterwards to re-check. A Mac whose
trial has ended and that has no license never calls it again.

**When Pro turns off:** if Dodo or the Worker is down, Pro keeps working. Only a refunded or disabled key, or a Mac
removed in the Dodo dashboard, turns Pro off.

## Set up the product in Dodo Payments

1. Create the product (one-time payment), then turn on **License keys** for it.
2. **Activations limit:** 3. **License length:** No expiration.
3. Optional: add an activation message, for example "Open Recall → Settings → License and paste this key."
   Dodo includes it in the email with the key.
4. **Required:** copy the product's ID (`pdt_…`) into `DODO_PRODUCT_IDS` in `wrangler.toml`. Copy your business ID
   into `DODO_BUSINESS_ID` too.
   - Dodo's license endpoints accept keys for any Dodo merchant's product, so this is what stops someone using a
     key from another store.
   - If `DODO_PRODUCT_IDS` isn't set, every key is refused.
   - Test mode and live mode have different product IDs; list both if you want, separated by a comma.
5. **To test first:** do all of this in **Test mode**, make a test purchase, and use that key.
   Set `DODO_API_BASE = "https://test.dodopayments.com"` in `wrangler.toml` while you do.

## Deployment

Deployed at **https://recall-license.rishabhgupta4523.workers.dev** (Cloudflare account rishabhgupta4523@gmail.com):
- D1 database `recall-license`
- R2 bucket `recall-releases`
- secrets `SIGNING_KEY` and `STATS_TOKEN`

**Live** with product `pdt_0NqInUfKFr2xPXRo0axLw`. The Worker refuses test-mode Dodo unless `ALLOW_TEST_MODE=1`
(set only in `server/.dev.vars` for `wrangler dev`), because test purchases are free.
`DODO_BUSINESS_ID` is empty until the live business ID is confirmed; the product ID check already binds keys to Recall.

Redeploying after a code change: `cd server && wrangler deploy`. A new migration: `wrangler d1 migrations apply recall-license --remote`.

From scratch, on a new account:

```bash
wrangler login
cd server
wrangler d1 create recall-license          # copy the database_id it prints into wrangler.toml
wrangler d1 migrations apply recall-license --remote
wrangler r2 bucket create recall-releases
openssl pkey -in ../keys/license-signing.pem -outform DER | base64 | wrangler secret put SIGNING_KEY
openssl rand -hex 24 | tee ../keys/stats-token.txt | tr -d '\n' | wrangler secret put STATS_TOKEN
wrangler deploy                             # prints https://recall-license.<you>.workers.dev
```

Then put that URL into `project.yml` (`RECALL_LICENSE_SERVER` under `Release`) and into `RECALL_FILES` in the
website's `next.config.ts`.

## Downloads and numbers

The Worker also serves `GET /appcast.xml`, `GET /download/latest` (redirects to the newest DMG) and
`GET /download/Recall-<version>.dmg` from R2, with Range support. Nothing else in the bucket is reachable.
Upload with `scripts/publish-release.sh`.

It counts, per UTC day:
- `download:<version>`: a full download, or the first chunk of a resumed one;
- `update_check:<app version>`: an appcast fetch, with the version taken from Sparkle's User-Agent.

No IPs or device data are stored. `GET /v1/stats` with `Authorization: Bearer <STATS_TOKEN>` returns the counts plus
Pro activation numbers from `activations`. `scripts/stats.sh` prints them.

## Website videos

The website's videos and poster are in R2 under `media/` and served at `/media/<name>-v<n>.mp4|.jpg` (same Range
support, one-year cache, not counted as downloads). The site loads nothing until Play is pressed. To change one,
upload it under a new version name and update `components/recall-video.tsx` in the website:

```bash
wrangler r2 object put recall-releases/media/recall-short-v2.mp4 --remote --file <file> --content-type video/mp4
```

Now live: `recall-short-v1.mp4` (22.8 s), `recall-film-v1.mp4` (57.6 s), `recall-poster-v1.jpg`.

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
- `keys/sparkle-private-key.txt` signs updates; `keys/stats-token.txt` unlocks the stats endpoint.

All of them are git-ignored. Keep them in a password manager or an encrypted backup.

## Local development (no Dodo account needed)

`dev/mock-dodo.mjs` imitates Dodo's license endpoints. Its responses were checked against `test.dodopayments.com`.

`server/.dev.vars` (git-ignored):
```
SIGNING_KEY=<openssl pkey -in ../keys/license-signing.pem -outform DER | base64>
DODO_API_BASE=http://127.0.0.1:8788
DODO_PRODUCT_IDS=pdt_mock
DODO_BUSINESS_ID=bus_mock
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
