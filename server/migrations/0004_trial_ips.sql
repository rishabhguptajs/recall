-- Per-source cap on new trials per day. The key is a hash of the day plus the connecting address
-- (IPv6 reduced to its /64), so it can't be linked across days; old rows are pruned as new ones arrive.
CREATE TABLE trial_ips (
  day TEXT NOT NULL,
  source TEXT NOT NULL,
  n INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (day, source)
);
