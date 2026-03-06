# AGENTS.md

## Project goal
Maintain a **canonical-first documentation system** for an AI commerce platform: canonical specs define truth, downstream docs/contracts/delivery plans are generated or derived, and CI prevents drift.

## Source-of-truth hierarchy
1. `docs/canonical/*` (authoritative product/architecture/schema/tool/state/error truth)
2. `docs/SPEC_LOCK.md` (change-control policy)
3. `contracts/*` (compiled artifacts derived from canonical)
4. `docs/*.md` (downstream narrative/spec docs derived from canonical)
5. `delivery/*` (execution planning derived from docs/canonical + docs/*)
6. `.github/workflows/docs_ci.yml` + `scripts/*` (enforcement tooling)

## Hard rules
- **Canonical-first:** any behavior/schema/tool/state/error change must update `docs/canonical/*` first.
- Do not introduce non-canonical `/api/...` endpoint paths in top-level `docs/*.md` unless canonical endpoint registry is added first.
- Keep downstream docs aligned to canonical terminology/tokens/tool names/error codes.
- If canonical files change, regenerate all top-level `docs/*.md` in the same PR.
- Do not treat `contracts/*` as independent truth; regenerate from canonical/doc sources.

## Build/update order
1. Update `docs/canonical/*` (if requirements changed).
2. Regenerate/update `docs/*.md` and appendices.
3. Regenerate/update `contracts/*`.
4. Regenerate/update `delivery/*` (if scope/milestones/tasks changed).
5. Update policy/check docs (`docs/checks/*`, `docs/SPEC_LOCK.md`) if enforcement semantics changed.

## Required validation checks
Run before commit/PR:
- `python scripts/check_docs_drift.py --base <base_ref> --head HEAD`
- `python scripts/check_api_vs_docs.py`
- `python scripts/check_tools_vs_docs.py`
- If contracts changed: review `contracts/validation_report.md` and ensure regenerated artifacts are consistent.

## Working style expectations
- Keep edits minimal, explicit, and repo-specific.
- Prefer updating scripts/workflows over manual one-off fixes when a rule should be repeatable.
- When canonical ambiguity exists, add TODO/Open Questions rather than inventing facts.
- Preserve spec-version/header conventions used across docs.
