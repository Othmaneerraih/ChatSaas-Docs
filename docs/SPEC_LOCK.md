# SPEC_LOCK Policy
Spec Version: 1.0.0 — Generated against canonical SPEC_VERSION

## Canonical-first change control
- Any change to product behavior, schema, tools, states, or errors MUST modify `docs/canonical/*` first.
- Downstream documents in `docs/*.md` are derived artifacts and MUST NOT introduce behavior that is absent from canonical sources.

## Regeneration requirement
- After any canonical change, all downstream docs MUST be regenerated and re-audited for drift before merge.
- Drift checks MUST pass against canonical sources for schema, tools, states, errors, and locked architecture decisions.

## CI enforcement
- CI runs `scripts/check_docs_drift.py` on pull requests.
- If a PR modifies any file under `docs/canonical/*`, CI fails unless all top-level `docs/*.md` files are updated in the same PR (regeneration gate).
- If a PR modifies `docs/*.md`, CI validates references against canonical artifacts and fails on non-canonical references.
- CI runs `scripts/check_api_vs_docs.py` to fail on `/api/...` endpoint path references in top-level docs unless/ until a canonical endpoint registry exists.
- CI runs `scripts/check_tools_vs_docs.py` to fail on unknown tool-like references and missing canonical tool references in top-level docs.

## Lock scope
- `docs/canonical/*` is the authoritative source of truth.
- Treat canonical files as read-only during downstream-only edits.
