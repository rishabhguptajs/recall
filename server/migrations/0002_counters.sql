-- Anonymous daily counters: downloads per version and update checks per app version.
-- No IPs, device IDs or anything else about the person is stored, only a count per day.
CREATE TABLE counters (
  day   TEXT NOT NULL,          -- YYYY-MM-DD (UTC)
  name  TEXT NOT NULL,          -- e.g. download:0.1.0, update_check:0.1.0
  value INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (day, name)
);
