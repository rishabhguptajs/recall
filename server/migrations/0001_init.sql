-- Licenses: only a hash of each key is stored, never the key itself.
CREATE TABLE licenses (
  id TEXT PRIMARY KEY,
  key_hash TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL,
  max_devices INTEGER NOT NULL DEFAULT 3,
  status TEXT NOT NULL DEFAULT 'active', -- 'active' | 'revoked'
  created_at INTEGER NOT NULL,
  note TEXT
);
CREATE INDEX licenses_email ON licenses(email);

-- One row per Mac using a license. `device` is an anonymous hash, not a hardware serial.
CREATE TABLE activations (
  license_id TEXT NOT NULL REFERENCES licenses(id) ON DELETE CASCADE,
  device TEXT NOT NULL,
  activated_at INTEGER NOT NULL,
  last_seen INTEGER NOT NULL,
  PRIMARY KEY (license_id, device)
);
