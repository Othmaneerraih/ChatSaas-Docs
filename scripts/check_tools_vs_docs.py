#!/usr/bin/env python3
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
docs = sorted((root / "docs").glob("*.md"))
canonical = json.loads((root / "docs/canonical/tools_schemas.json").read_text())
canon_tools = set(canonical.get("tools", {}).keys())

# collect tool references found in docs
found_tools = set()
unknown_tool_like = []
for p in docs:
    text = p.read_text()
    for tok in re.findall(r"`([a-z][a-z0-9_]{2,})`", text):
        if tok in canon_tools:
            found_tools.add(tok)
            continue
        # likely tool-like candidate: snake_case verbs
        if "_" in tok and any(tok.startswith(v) for v in ("get_", "search_", "create_", "add_", "remove_", "check_", "analyze_", "escalate_", "update_", "delete_", "list_")):
            unknown_tool_like.append((p.relative_to(root), tok))

missing = sorted(canon_tools - found_tools)

if unknown_tool_like or missing:
    print("TOOLS VS DOCS CHECK: FAIL")
    if missing:
        print("Missing canonical tools in docs/*.md:")
        for m in missing:
            print(f"  - {m}")
    if unknown_tool_like:
        print("Unknown tool-like references in docs/*.md:")
        for p, t in unknown_tool_like:
            print(f"  - {p}: `{t}`")
    raise SystemExit(1)

print("TOOLS VS DOCS CHECK: PASS")
