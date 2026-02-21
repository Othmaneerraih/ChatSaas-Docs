# Drift Rules (Automated Checks)

This document defines string/regex-oriented checks for documentation and spec drift detection.

## 1) Endpoint Drift Check

**Rule:** All `/api/` endpoints referenced anywhere must exist in the canonical API endpoint registry in `docs/canonical/schema.md`.

### Suggested extraction patterns
- Endpoint candidate regex: ``/api/v\d+/[A-Za-z0-9_\-/{}/.]+``
- Method+path candidate regex: ``\b(GET|POST|PUT|PATCH|DELETE|WS)\s+(/api/v\d+/[A-Za-z0-9_\-/{}/.]+)``

### Check logic
1. Build canonical endpoint set from the API registry section in `docs/canonical/schema.md`.
2. Scan target docs/specs for endpoint candidates.
3. Fail if any endpoint candidate is not in canonical set.

## 2) Enum Drift Check

**Rule:** All enum values referenced in docs/specs must be declared in canonical enums/constants.

### Suggested extraction patterns
- Enum-like list regex (quoted values): ``'([a-z0-9_\-]+)'`` or ``"([a-z0-9_\-]+)"``
- Enum declaration sources: canonical enum listings in `docs/canonical/schema.md`.

### Check logic
1. Extract canonical enum domains and value sets from canonical enums section.
2. Extract enum-like values from target docs in enum contexts.
3. Fail when value is used for a known enum domain but not present in canonical set.

## 3) Tool Drift Check

**Rule:** All tools referenced must exist in `docs/canonical/tools_schemas.json`.

### Suggested extraction patterns
- Tool invocation/name regex: ``\b(search_products|check_stock|add_to_cart|remove_from_cart|calculate_total|create_order|get_order_status|analyze_image|escalate_to_human)\b`` (or generic token extraction, then membership check).
- JSON key extraction for tool names under orchestrator/tool-call contexts.

### Check logic
1. Parse canonical tool names from `docs/canonical/tools_schemas.json` (`tools` object keys).
2. Scan target files for tool references.
3. Fail if any referenced tool is not in canonical tool set.

## Output and Enforcement

- Each check should output: file path, line number, offending token, and expected canonical source.
- CI should fail on any drift violation.
- Where canonical source is ambiguous, emit warning and require TODO with exact citation before merge.
