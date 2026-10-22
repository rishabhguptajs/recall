-- Which Dodo Payments activation instance belongs to which Mac.
-- Only a SHA-256 hash of the license key is stored, and `device` is an anonymous hash.
CREATE TABLE activations (
  key_hash TEXT NOT NULL,
  device TEXT NOT NULL,
  instance_id TEXT NOT NULL,      -- Dodo's lki_… id, needed to deactivate
  license_key_id TEXT NOT NULL,   -- Dodo's lic_… id, put in the signed token
  activated_at INTEGER NOT NULL,
  last_seen INTEGER NOT NULL,
  PRIMARY KEY (key_hash, device)
);
