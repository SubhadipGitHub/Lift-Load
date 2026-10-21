"""Turns `flutter test --reporter json` output into GitHub error annotations.

Usage: python3 tool/ci/report_failures.py test-results.json
Exits 1 if any test failed or errored, 0 otherwise.
"""
import json
import sys

names, failed, errors = {}, set(), {}
with open(sys.argv[1], encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        t = e.get("type")
        if t == "testStart":
            names[e["test"]["id"]] = e["test"]["name"]
        elif t == "error":
            errors.setdefault(e["testID"], []).append((e.get("error", "") + "\n" + e.get("stackTrace", ""))[:1800])
        elif t == "testDone" and e.get("result") != "success" and not e.get("hidden"):
            failed.add(e["testID"])

for tid in sorted(failed):
    msg = "\n".join(errors.get(tid, ["(no error text)"]))
    msg = msg.replace("%", "%25").replace("\r", "").replace("\n", "%0A")
    title = names.get(tid, str(tid)).replace(",", " ").replace(":", " ")
    print(f"::error title={title}::{msg}")
print(f"{len(failed)} failed")
sys.exit(1 if failed else 0)
