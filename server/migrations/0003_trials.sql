-- One row per Mac that has started the 14-day Pro trial. `device` is the anonymous device hash,
-- so reinstalling or deleting the app's files can't start a second trial on the same Mac.
CREATE TABLE trials (
  device TEXT NOT NULL PRIMARY KEY,
  started_at INTEGER NOT NULL
);
