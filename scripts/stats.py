"""Formats the JSON from the license Worker's /v1/stats (read from stdin). Used by scripts/stats.sh."""
import json
import sys

d = json.load(sys.stdin)
totals = {r["name"]: r["total"] for r in d["totals"]}

downloads = {k.split(":", 1)[1]: v for k, v in totals.items() if k.startswith("download:")}
print(f"Downloads, all time: {sum(downloads.values())}")
for version, n in sorted(downloads.items()):
    print(f"  {version:>10}  {n}")

checks = {k.split(":", 1)[1]: v for k, v in totals.items() if k.startswith("update_check:")}
print(f"Update checks, all time: {sum(checks.values())}  (people with update checks on, or who clicked Check for Updates)")
for version, n in sorted(checks.items()):
    print(f"  {version:>10}  {n}")

pro = d["pro"]
print(f"Pro: {pro['licenses']} licenses, {pro['activations']} Macs activated, "
      f"{pro['active_macs_35d'] or 0} Macs seen in the last 35 days")

days = {}
for r in d["last_30_days"]:
    kind = r["name"].split(":", 1)[0]
    days.setdefault(r["day"], {}).setdefault(kind, 0)
    days[r["day"]][kind] += r["value"]
print("Last 7 days:")
for day in sorted(days)[-7:]:
    v = days[day]
    print(f"  {day}  downloads {v.get('download', 0):>4}   update checks {v.get('update_check', 0):>4}")
