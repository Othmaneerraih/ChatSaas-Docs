# 19 Implementation Plan & Milestones

## Purpose
This document defines an implementation-grade MVP execution plan and milestone framework for Aidy, aligned strictly with canonical architecture, schema, tool contracts, state machine behavior, and error semantics. It is intended for engineering, QA, and operations teams coordinating delivery sequencing, dependency management, and release acceptance.

## Scope
In scope:
- Phase-based rollout plan aligned to canonical architecture and system boundaries.
- Dependency mapping across identity, data model, tools, channels, retrieval, observability, and QA checks.
- Critical path definition for achieving production-ready pilot delivery.
- Milestone deliverables and acceptance criteria tied to canonical contracts.
- Operational go/no-go criteria for progression between phases.

Out of scope:
- Introducing non-canonical platforms, orchestration layers, or infrastructure products.
- Defining post-MVP roadmap items that require new schema/tools/states/errors.
- Rewriting canonical decisions with alternative stack or sequencing assumptions.

Canonical boundaries this document cannot override:
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/rls.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/state_machine.md`
- `docs/canonical/errors.md`
- `docs/checks/consistency_checklist.md`
- `docs/checks/drift_rules.md`

## Non-Goals
- Defining detailed sprint calendars, staffing plans, or budget approvals.
- Defining custom milestones that bypass canonical validation gates.
- Defining non-canonical deployment topologies or HA patterns.

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
- `docs/checks/consistency_checklist.md`
- `docs/checks/drift_rules.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `tenants` (tenant lifecycle, plan/budget constraints, activation gating)
- `agents` (model/tool/routing configuration and versioned rollout changes)
- `customers` (tenant-scoped customer identity baseline)
- `conversations` (state/mode/cart lifecycle validation)
- `messages` (runtime behavior, tool/model usage, latency/tokens)
- `products` and `product_variants` (catalog readiness and stock-aware flows)
- `orders` and `order_items` (checkout/order correctness and idempotency outcomes)
- `documents` and `document_chunks` (retrieval readiness and embedding path)
- `audit_log` (traceability for configuration/tool/handoff events)
- `channel_connections` and `ecommerce_connections` (integration readiness and sync state)

### Tools referenced (if any)
- `search_products`
- `check_stock`
- `add_to_cart`
- `remove_from_cart`
- `calculate_total`
- `create_order`
- `get_order_status`
- `analyze_image`
- `escalate_to_human`

### States/modes referenced (if any)
- Status states: `active`, `escalated`, `resolved`, `abandoned`
- Mode states: `ai`, `manual`, `ai_whisper`
- Cart states: `empty`, `has_items`, `summary_shown`, `confirmed`, `order_created`

### Error codes referenced (if any)
- Access/isolation gating: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
- Tool/workflow gating: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `CONFIRM_REQUIRED`, `DUPLICATE_ORDER`, `CART_EMPTY`, `INVALID_QUANTITY`, `OUT_OF_STOCK`
- Integration/reliability gating: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `RATE_LIMITED`, `MODEL_ERROR`, `SYNC_IN_PROGRESS`, `INTERNAL_ERROR`
- Cost gating: `BUDGET_EXCEEDED`

## Design

### Phased rollout plan

#### Phase 0 — Canonical baseline lock and readiness
**Objective:** Ensure all implementation work is anchored to canonical artifacts before feature rollout.

**Deliverables:**
- Canonical docs and drift-check references finalized and linked in implementation epics.
- Environment variable inventory validated for required runtime services.
- Definition of done includes schema/tool/state/error drift checks.

**Acceptance criteria:**
- No unresolved canonical conflicts across architecture, schema, tools, state machine, and errors.
- Drift checklist and drift rules are integrated into review workflow.

#### Phase 1 — Foundation: auth, tenant boundaries, and core data paths
**Objective:** Establish secure tenant-scoped baseline and data persistence paths.

**Deliverables:**
- Supabase Auth + JWT path integrated with tenant-scoped access checks.
- RLS-aligned data-access layer across core tables (`tenants`, `agents`, `customers`, `conversations`, `messages`).
- Audit logging baseline for security and operational traceability.

**Acceptance criteria:**
- Tenant isolation tests pass with no cross-tenant reads/writes.
- Canonical auth and boundary errors are returned correctly for negative cases.

#### Phase 2 — Conversation engine and tooling layer
**Objective:** Enable canonical conversation lifecycle and tool execution framework.

**Deliverables:**
- Status/mode/cart state transitions implemented per canonical state machine.
- Canonical tool contracts wired with schema validation and allowlist checks.
- Deterministic tool execution preserved for `calculate_total`; order-confirmation gate enforced for `create_order`.

**Acceptance criteria:**
- State-transition tests pass for allowed/disallowed transitions.
- Tool validation, confirmation, and idempotency guards pass positive and negative tests.

#### Phase 3 — Channel and commerce integrations
**Objective:** Activate canonical inbound channels and commerce synchronization for pilot use.

**Deliverables:**
- WhatsApp BYOK inbound webhook path with signature validation and dedup behavior.
- Web widget message ingress path and tenant-scoped session handling.
- Ecommerce connection activation and sync workflow with conflict handling.

**Acceptance criteria:**
- Webhook signature and duplicate tests pass (`WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`).
- Sync contention and readiness tests pass (`SYNC_IN_PROGRESS` handling).

#### Phase 4 — Retrieval, observability, and reliability controls
**Objective:** Complete retrieval path and production safety controls required for pilot readiness.

**Deliverables:**
- Hybrid retrieval path functional for product queries (SQL + lexical + optional semantic rerank).
- Document ingestion/chunking/embedding readiness for unstructured knowledge support.
- Monitoring and runtime protection baselines active (Sentry, rate limits, budget controls).

**Acceptance criteria:**
- Retrieval and catalog flows pass canonical regression scenarios.
- Runtime guardrails trigger canonical errors under controlled failure injection.

#### Phase 5 — Pilot launch readiness and gated release
**Objective:** Validate end-to-end readiness and execute controlled rollout.

**Deliverables:**
- End-to-end pilot runbook execution across selected tenant cohort.
- QA framework completion for offline/online checks and release gates.
- Final go/no-go signoff against canonical consistency audit dimensions.

**Acceptance criteria:**
- Critical path scenarios pass with no blocking drift findings.
- Pilot cohort meets agreed success thresholds within defined observation window.

### Dependency map
Implementation dependencies and ordering constraints:
- **Auth/RLS precedes all business features** (tenant isolation is foundational).
- **Schema and repositories precede service-level tool orchestration**.
- **Conversation state machine and tool guardrails precede channel rollout**.
- **Channel ingress precedes pilot-scale operational validation**.
- **Observability/reliability controls precede production pilot expansion**.

### Critical path
Critical path to first production pilot:
1. Canonical lock + drift checks integrated.
2. Tenant-scoped auth/RLS enforcement validated.
3. Core conversation + tooling path validated (including confirmation/idempotency).
4. Inbound channel and ecommerce sync paths validated.
5. Reliability/monitoring/budget guardrails validated.
6. Pilot runbook execution and release criteria pass.

Any delay in tenant isolation, tool-guard correctness, or channel integrity blocks downstream milestones.

### Milestone deliverables
- **M1: Foundation Ready** — Auth, RLS, and core tables verified.
- **M2: Conversation + Tooling Ready** — Canonical state machine and tools operational.
- **M3: Channel + Commerce Ready** — Webhook/widget/ecommerce paths stable.
- **M4: Reliability Ready** — Monitoring, throttling, and budget/runtime controls active.
- **M5: Pilot Ready** — End-to-end QA gates and pilot go-live criteria satisfied.

### Acceptance criteria model
Acceptance criteria for each milestone follow common rules:
- All relevant drift checks PASS.
- Required positive-path and negative-path tests PASS.
- Canonical errors are emitted for guarded failure cases.
- No unresolved critical issues in tenant isolation, tool safety, or channel integrity.
- Open ambiguities are documented with explicit owner/decision follow-up.

## Interfaces
Interfaces covered by milestone execution and validation:
- `POST /api/v1/webhooks/whatsapp/{tenant_id}`
- `POST /api/v1/webhooks/ecommerce/{tenant_id}`
- `WS /api/v1/ws/chat/{tenant_id}`
- `POST /api/v1/widget/messages`
- Canonical tool-call interfaces for all listed tools.
- Data/access interfaces through Supabase (RLS-bound tables) and Redis coordination.

Authentication/authorization assumptions:
- Protected operations require valid JWT and tenant context.
- Repository and service calls must preserve RLS and tenant scoping throughout rollout.

## Invariants
- Milestones cannot bypass canonical architecture decisions (FastAPI modular monolith, Supabase, Redis, Sentry).
- Tenant isolation and RLS enforcement remain mandatory in every phase.
- Tool schemas and allowlist checks remain mandatory before any tool execution.
- State/mode/cart transitions must remain canonical throughout implementation.
- Confirmation/idempotency gates remain mandatory before order creation.
- Release gating always includes canonical drift and regression checks.

## Failure Modes
- **Canonical drift introduced during implementation**
  - Errors/signals: drift check failures; non-canonical identifiers detected.
  - Detection: consistency checklist/rule checks in review and CI.
  - Mitigation: block merge/release until canonical alignment restored.

- **Tenant-boundary regression**
  - Errors: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`
  - Detection: isolation/auth test failures.
  - Mitigation: halt phase promotion and fix auth/RLS enforcement.

- **Workflow guardrail regressions**
  - Errors: `TOOL_VALIDATION_FAILED`, `TOOL_NOT_ALLOWED`, `CONFIRM_REQUIRED`, `DUPLICATE_ORDER`
  - Detection: failing conversation/commerce regression suites.
  - Mitigation: restore validation/allowlist/confirmation/idempotency controls before progression.

- **Channel integrity and integration instability**
  - Errors: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `SYNC_IN_PROGRESS`
  - Detection: webhook/sync test failures and operational alert spikes.
  - Mitigation: freeze rollout, fix signature/dedup/sync locking logic, revalidate.

- **Runtime reliability/cost failure during rollout**
  - Errors: `RATE_LIMITED`, `MODEL_ERROR`, `BUDGET_EXCEEDED`, `INTERNAL_ERROR`
  - Detection: elevated runtime incident rates and degraded pilot KPIs.
  - Mitigation: reduce rollout scope, apply recovery runbook, resume only after stability criteria pass.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are specified inputs but unavailable in this environment; confirm source export path.
- TODO: Canonical artifacts do not define target durations per phase/milestone; confirm timeline owners and planning cadence.
- TODO: Canonical artifacts do not define numeric go/no-go thresholds for runtime and business KPIs; confirm release governance thresholds.
- TODO: Canonical artifacts do not define explicit staffing/ownership matrix per milestone; confirm accountable owners and escalation chain.
- TODO: Canonical artifacts do not define mandatory pilot cohort size for launch readiness; confirm rollout policy.

## Change Log
- 2026-02-21 — Codex: Initial Implementation Plan & Milestones specification generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
