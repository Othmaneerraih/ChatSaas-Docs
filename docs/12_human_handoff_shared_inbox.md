# 12 Human Handoff / Takeover + Shared Inbox Spec
Spec Version: 1.0.0 — Generated against canonical SPEC_VERSION

## Purpose
This document specifies canonical MVP behavior for human handoff and shared-inbox conversation operations, including takeover/release flows, permissions boundaries, mode/status transitions, audit logging, AI whisper behavior, and recovery handling. It is intended for backend/dashboard engineers, QA, and operations teams implementing or validating agent-to-merchant control transfer.

## Scope
In scope:
- Merchant takeover and release behavior for active conversations.
- Shared inbox operating model for conversation triage and human response control.
- Canonical `status` and `mode` transition rules during handoff.
- Audit requirements for control transfer and message actions.
- Recovery behavior for failed transitions or degraded runtime.

Out of scope:
- Introducing new takeover modes or transition edges.
- Defining non-canonical staffing/assignment frameworks.
- Replacing canonical tool, schema, or error contracts.

Canonical boundaries this document cannot override:
- `docs/canonical/state_machine.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`
- `docs/canonical/locked_decisions.md`

## Non-Goals
- Defining CRM workflows outside canonical conversation controls.
- Defining non-canonical role hierarchies or permission classes.
- Adding post-MVP collaboration capabilities not specified in canonical artifacts.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/state_machine.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`
- `docs/canonical/locked_decisions.md`
- `docs/canonical/env_vars.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `conversations` (`status`, `mode`, `last_message_at`, cart/confirm fields tied to control flow)
- `messages` (ordered conversation transcript, human vs AI output trail)
- `customers` (identity context for shared-inbox rows)
- `agents` (tools/model settings that still govern AI behavior when AI is active)
- `audit_log` (`action`, `tool_name`, `actor`, args/results trace for takeover/release/escalation)
- `tenants` (owner scope and isolation boundary)

### Tools referenced (if any)
- `escalate_to_human`
- `search_products`
- `check_stock`
- `add_to_cart`
- `remove_from_cart`
- `calculate_total`
- `create_order`
- `get_order_status`
- `analyze_image`

### States/modes referenced
- Status transitions:
  - `(new) -> active`
  - `active -> escalated`
  - `escalated -> active`
  - `active -> resolved`
  - `active -> abandoned`
  - `escalated -> resolved`
  - `resolved -> active`
- Mode transitions:
  - `ai -> manual` (Take Over)
  - `manual -> ai` (Release)
  - `ai -> ai_whisper` (merchant viewing while AI active)
  - `ai_whisper -> manual` (Take Over)
  - `manual -> ai_whisper` is not allowed

### Error codes referenced (if any)
- Auth/scope/lookup: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
- Tool/policy/runtime: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`
- Flow/resource guards occasionally surfaced in handoff context: `ORDER_NOT_FOUND`, `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`

## Design

### Shared inbox operating model
- Shared inbox is the tenant-scoped operational surface over canonical `conversations` + `messages`.
- Conversations are triaged by canonical lifecycle status (`active`, `escalated`, `resolved`, `abandoned`) and responder ownership mode (`ai`, `manual`, `ai_whisper`).
- Merchant actions in inbox (view, take over, release, resolve) mutate only canonical state fields and must preserve transition rules.

### Takeover flow
1. Merchant opens conversation while AI is active.
2. Optional observer path: `ai -> ai_whisper` when entering view without takeover.
3. Take Over action triggers mode transition to `manual`; AI response generation pauses.
4. Status may move to `escalated` per canonical trigger semantics (tool or manual takeover event).
5. Merchant sends replies directly; message trail remains ordered and tenant-scoped.

### Release/recovery-to-AI flow
1. Merchant clicks Release while in `manual` mode.
2. Mode transitions `manual -> ai` only.
3. AI resumes with conversation summary context as defined by canonical mode effect.
4. `manual -> ai_whisper` direct transition remains forbidden.

### Escalation pathways
- Programmatic escalation uses `escalate_to_human` tool, which sets conversation mode to `manual` and notifies merchant.
- Manual dashboard takeover is an equivalent control-plane path resulting in canonical takeover state effects.
- Escalated conversations may return to `active` only through Release, or be closed with `resolved` by merchant action.

### Permissions and enforcement
- All inbox operations are tenant-owner scoped and enforced by canonical auth/RLS constraints.
- Cross-tenant conversation access is denied (`FORBIDDEN` / not-found semantics).
- Tool usage during AI-active phases remains constrained by `agents.tools_enabled` and canonical validation rules.

### Audit logging
- Every significant control action (takeover, release, escalation, status update, manual response send, tool side effects) is recorded in `audit_log` with canonical actor semantics (`agent`, `merchant`, `system`).
- Audit entries provide incident and compliance traceability for control transfer decisions.

### Agent and agent-whisper behavior
- In `ai` mode: AI produces responses and may invoke allowed tools.
- In `ai_whisper` mode: AI keeps responding while suggestions are visible to the merchant.
- In `manual` mode: merchant is the active responder; AI does not auto-respond.
- Transition constraints are authoritative; any unsupported path is rejected and logged.

### Recovery flows
- If control operation fails due to auth/scope errors, state remains unchanged and canonical error is returned.
- If runtime/model failures occur during AI phases, system returns canonical runtime errors without illegal mode transitions.
- Duplicate or retried control events must be idempotent at state-machine level (no invalid extra transition side effects).

## Interfaces
Handoff/shared-inbox relevant interfaces:
- Dashboard conversation controls (take over, release, resolve, message send)
- Conversation list/detail/messages reads in tenant scope
- `escalate_to_human(reason, conversation_id)` tool path for programmatic handoff
- Channel ingress surfaces that feed inbox state:

## Invariants
- Mode/status transitions strictly follow canonical transition tables.
- `manual -> ai_whisper` transition is never allowed.
- Handoff actions are tenant-scoped and RLS-compatible.
- Audit trail exists for all significant control and escalation events.
- AI tool execution remains governed by canonical allowlist + schema constraints while AI is active.
- Recovery/error paths do not leave conversation in a non-canonical mode/state.

## Failure Modes
- **Unauthorized or cross-tenant inbox actions**
  - Errors: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
  - Mitigation: reject operation before state mutation.

- **Invalid transition attempts**
  - Errors: canonical rejection via policy/validation controls (commonly `FORBIDDEN` or validation failure path)
  - Mitigation: block unsupported edge (for example `manual -> ai_whisper`) and preserve existing mode/state.

- **Escalation/tool policy failures**
  - Errors: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`
  - Mitigation: no tool side effects; retain safe conversation control state.

- **Runtime degradation during AI-managed phases**
  - Errors: `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`
  - Mitigation: fail safely, keep valid control ownership, continue manual fallback if needed.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are required inputs but unavailable in this environment; confirm source-export workflow.
- TODO: Canonical artifacts define owner-level tenant boundaries but do not enumerate a detailed multi-merchant permission matrix for shared inbox actions; confirm authoritative access-control specification.
- TODO: Canonical artifacts define transition edges but do not define explicit retry-idempotency keys for repeated dashboard takeover/release clicks; confirm control-plane idempotency contract.

## Change Log
- 2026-02-21 — Codex: Initial Human Handoff / Takeover + Shared Inbox specification generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
