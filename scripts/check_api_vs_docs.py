#!/usr/bin/env python3
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
failures = []
for p in sorted((root / "docs").glob("*.md")):
    if p.name == "SPEC_LOCK.md":
        continue
    text = p.read_text()
    endpoints = sorted(set(re.findall(r"/api/[A-Za-z0-9_\-/{}/.]+", text)))
    if endpoints:
        failures.append((p, endpoints))

if failures:
    print("API VS DOCS CHECK: FAIL")
    for p, eps in failures:
        print(f"{p.relative_to(root)} contains non-canonical endpoint references:")
        for e in eps:
            print(f"  - {e}")
    raise SystemExit(1)

print("API VS DOCS CHECK: PASS")
