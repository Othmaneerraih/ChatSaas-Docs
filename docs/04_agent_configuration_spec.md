# 04 Agent Configuration Specification (Config Schema + Versioning)

## Purpose
This document defines the canonical implementation specification for agent configuration in the Aidy MVP, including schema usage, config validation boundaries, config versioning behavior, rollout controls, backward-compatibility constraints, and migration handling. It is intended for backend engineers, dashboard engineers, QA, and release operators.

## Scope
In scope:
- Canonical storage model for agent configuration fields in `agents`.
- Operational semantics of configuration updates and `config_version` progression.
- Validation rules derived from canonical schema, enums/constants, and tool contracts.
- Rollout and compatibility controls for config changes within MVP constraints.
- Migration strategy for config-related data changes without schema/tool/state/error drift.

Out of scope:
- Introducing non-canonical configuration fields.
- Replacing canonical orchestration pattern or auth/tenant model.
- Defining post-MVP feature-flag systems not present in canonical artifacts.

Canonical boundaries this document cannot override:
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/state_machine.md`
- `docs/canonical/errors.md`

## Non-Goals
- Defining a custom config store outside canonical `agents` table.
- Changing canonical one-agent-per-tenant MVP constraint.
- Introducing new tool names or non-canonical model role keys.
- Redefining endpoint contracts beyond canonical API registry.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/rls.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/state_machine.md`
- `docs/canonical/errors.md`
- `docs/canonical/env_vars.md`
- `docs/canonical/glossary.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `agents` (primary configuration record)
- `tenants` (tenant ownership and one-agent-per-tenant relationship)
- `conversations` (runtime state influenced by agent behavior)
- `messages` (tool call/result and model usage traces)
- `audit_log` (config change and tool-action traceability)

### Tools referenced (if any)
- Canonical tool namespace allowed in `agents.tools_enabled`:
  - `search_products`, `check_stock`, `add_to_cart`, `remove_from_cart`, `calculate_total`, `create_order`, `get_order_status`, `analyze_image`, `escalate_to_human`
- Tool validation dependencies:
  - `agents.tools_enabled` values must remain within canonical tool identifiers.

### States/modes referenced (if any)
- Conversation mode constraints impacted by tools/config:
  - `ai`, `manual`, `ai_whisper`
- Conversation status and cart/confirm gates that config must not bypass:
  - status lifecycle including `active`, `escalated`, `resolved`, `abandoned`
  - confirm gate dependency before `create_order` (`conversations.confirm_state = true`)

### Error codes referenced (if any)
- Auth/access/context: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`
- Config and tool governance: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`
- Runtime integrity and fail-safe behavior: `MODEL_ERROR`, `INTERNAL_ERROR`, `RATE_LIMITED`, `BUDGET_EXCEEDED`
- Conversation/order guard dependencies not bypassable by config: `CONFIRM_REQUIRED`, `DUPLICATE_ORDER`, `CART_EMPTY`

## Design

### 1) Config schema usage (canonical)
Canonical `agents` columns and semantics used for configuration:
- `tenant_id` (UUID, UNIQUE): enforces one agent per tenant in MVP.
- `name` (TEXT): display identity label.
- `identity` (JSONB, NOT NULL): canonical object shape includes `{ persona_prompt, tone, language_prefs }`.
- `models` (JSONB, NOT NULL): canonical object shape includes `{ chat, reasoning, vision, embedding, stt }` role mappings.
- `tools_enabled` (TEXT[], NOT NULL, default `{}`): canonical list of allowed tool identifiers.
- `routing_rules` (JSONB): canonical policy-like routing fields (e.g., escalation/complexity triggers).
- `business_rules` (JSONB): canonical business constraints object (e.g., discount/order/COD boundaries).
- `system_prompt_override` (TEXT, nullable): full prompt override field.
- `config_version` (INT, NOT NULL, default `1`): monotonically incremented on each config update.
- `is_active` and timestamps for lifecycle and operational metadata.

Schema constraints:
- All config is tenant-scoped and subject to canonical shared-DB + RLS model.
- No additional config fields are introduced in this specification.

### 2) Validation rules
Validation must be enforced at update time in service layer before persistence:
1. `tools_enabled` membership must be a subset of canonical tool names from `tools.md`/`tools_schemas.json`.
2. `models` object must only map canonical roles (`chat`, `reasoning`, `vision`, `embedding`, `stt`).
3. `identity`, `routing_rules`, and `business_rules` remain JSONB objects and must not remove required canonical structural intent fields described in schema notes.
4. Config updates must not attempt to alter one-agent-per-tenant invariant.
5. Config cannot disable or bypass canonical runtime guards (e.g., confirm gate for order creation).

Failure mapping:
- Unauthorized tool invocation after config resolution → `TOOL_NOT_ALLOWED`.
- Malformed tool argument contract usage → `TOOL_VALIDATION_FAILED`.
- Auth/tenant context failures on config endpoints → `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`.

### 3) Versioning strategy
Canonical version field behavior:
- `config_version` starts at `1`.
- Every successful config update increments `config_version` by exactly one.
- Config retrieval endpoints expose current config and version history according to canonical API registry (`GET /api/v1/agent/config`, `PUT /api/v1/agent/config`, `GET /api/v1/agent/config/history`).

Operational guidance:
- Treat each version as immutable historical state once superseded.
- Audit trails should capture config-change actions in `audit_log` with actor and timestamp context.

### 4) Rollout strategy
- Rollout unit is tenant-level because config is tenant-scoped and one-agent-per-tenant.
- Update sequence:
  1. Read current config/version.
  2. Validate payload against canonical field/tool/model constraints.
  3. Persist update and increment `config_version` atomically.
  4. Subsequent runtime requests consume latest active version.
- No global broadcast rollout mechanism is defined canonically; rollout remains per-tenant update operation.

### 5) Backward compatibility strategy
- Backward compatibility is maintained by preserving canonical config keys and runtime guard semantics.
- Existing tenants without optional config subfields in JSONB objects remain valid if canonical required structure is preserved.
- Any change requiring non-canonical keys, renamed keys, or altered enum/value sets is out of scope and must be raised as canonical change request.

### 6) Migration strategy
Config-related migrations must follow canonical-first constraints:
1. Database schema changes must remain exactly aligned with canonical `agents` table definitions.
2. Data migrations may normalize JSONB payloads only within canonical keyspace.
3. Tool-list migrations must stay inside canonical tool namespace.
4. Migration rollout must preserve tenant isolation and RLS assumptions.
5. Pre/post migration checks must include drift checks (schema/tool/state/error/architecture).

If migration requires policy details not defined canonically (e.g., per-table SQL RLS clauses), treat as unresolved and track under Open Questions.

## Interfaces
Canonical config interfaces:
- `GET /api/v1/agent/config` — read current tenant agent configuration.
- `PUT /api/v1/agent/config` — update configuration and increment `config_version`.
- `GET /api/v1/agent/config/history` — list prior config versions.

Authorization and storage boundaries:
- Dashboard APIs require Supabase JWT.
- Tenant scoping is enforced via RLS and service-level tenant context checks.
- Config updates affecting tool access are enforced through `agents.tools_enabled` evaluation at runtime tool dispatch.

## Invariants
- One agent per tenant remains enforced via unique `agents.tenant_id`.
- `config_version` increments on every config change.
- Canonical config keyspace in `identity` and `models` remains stable.
- `tools_enabled` contains only canonical tool identifiers.
- Config cannot bypass canonical state/guard logic (`confirm_state` prerequisite for `create_order`).
- Tenant-scoped access to agent config remains RLS-protected.

## Failure Modes
- **Invalid auth or tenant context on config endpoints**
  - `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`
  - Effect: config read/write denied.

- **Non-canonical tool configuration or invocation**
  - `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`
  - Effect: runtime tool execution blocked.

- **Model/provider runtime instability after config update**
  - `MODEL_ERROR`, `RATE_LIMITED`, `BUDGET_EXCEEDED`
  - Effect: degraded or failed response generation path.

- **Unexpected backend failures during config operations**
  - `INTERNAL_ERROR`
  - Effect: update/read failure requiring retry and operator triage.

- **Guard-condition mismatch in commerce flow despite config**
  - `CONFIRM_REQUIRED`, `CART_EMPTY`, `DUPLICATE_ORDER`
  - Effect: write blocked; confirms config cannot bypass canonical order/cart gates.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` were specified inputs but are not present in this environment; confirm whether markdown exports are mandatory for generation.
- TODO: Canonical docs define `config_version` increment semantics but do not define conflict resolution behavior for concurrent `PUT /api/v1/agent/config`; confirm expected concurrency control strategy.
- TODO: Canonical API registry includes config history endpoint but does not specify retention/window policy; confirm retention requirements for version history and audit linkage.

## Change Log
- 2026-02-21 — Codex: Initial Agent Configuration Specification generated from canonical template and canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
