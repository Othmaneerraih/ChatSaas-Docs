# Document Template

## Purpose
- Explain why this document exists and the decision or implementation outcome it supports.
- State the audience and expected use (engineering, QA, operations, support, etc.).

## Scope
- Define what is in scope for this document.
- Explicitly name systems/components/processes covered.
- List any canonical boundaries this document cannot override.

## Non-Goals
- List what this document does not attempt to define.
- Exclude implementation details that belong in other docs.

## Canonical Dependencies (tables, tools, states, errors)
- **Tables/Schema dependencies:** cite exact canonical tables/columns from `docs/canonical/schema.md`.
- **Tool dependencies:** cite exact canonical tools/contracts from `docs/canonical/tools.md` and `docs/canonical/tools_schemas.json`.
- **State dependencies:** cite exact canonical conversation/cart/mode transitions from `docs/canonical/state_machine.md`.
- **Error dependencies:** cite exact canonical error codes from `docs/canonical/errors.md`.
- **Architecture constraints:** cite governing decisions from `docs/canonical/locked_decisions.md`.

## Design
- Describe the high-level design and reasoning.
- Separate canonical facts from implementation-specific choices.
- Note alternatives considered (if any) and why they were rejected.

## Interfaces
- List interfaces this design uses or exposes (API routes, webhooks, events, tool calls, DB reads/writes).
- For every interface, link to canonical dependency entries.
- Include authentication/authorization assumptions where relevant.

## Invariants
- List properties that must always remain true.
- Tie each invariant to canonical dependencies where applicable.
- Include data integrity, tenant isolation, and idempotency invariants if relevant.

## Failure Modes
- Enumerate expected failure paths and related canonical errors.
- Include detection/observability and recovery/mitigation strategy per failure mode.

## Open Questions
- Track unresolved items blocking implementation or sign-off.
- Include owners and decision deadlines.
- If ambiguity exists in canonical references, add TODO with exact source citation.

## Change Log
- Record date, author, and summary of updates.
- Include references to related PRs/issues.
