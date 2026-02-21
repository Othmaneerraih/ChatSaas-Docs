# 06 Routing, Policies, and Guardrails

## Purpose
This document defines the canonical routing behavior, policy enforcement points, and guardrail constraints for Aidy MVP message handling. It is intended for backend engineers, QA, and operations teams implementing or validating runtime safety and control behavior.

## Scope
In scope:
- Request/message routing decisions across conversation lifecycle and responder modes.
- Canonical policy enforcement gates before tool execution and write side effects.
- Canonical safety and guardrail constraints for cart/order, tenant boundaries, and channel integrity.
- Fallback behavior when routing or execution fails.

Out of scope:
- Defining new policy classes, moderation frameworks, or non-canonical safety subsystems.
- Adding new tools, states, endpoints, or schema fields.
- Replacing canonical state machine or error semantics.

Canonical boundaries this document cannot override:
- `docs/canonical/locked_decisions.md`
- `docs/canonical/state_machine.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/schema.md`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`

## Non-Goals
- Defining prompt wording or response style for customer-facing messages.
- Specifying non-canonical risk scoring or custom policy taxonomies.
- Introducing additional escalation states beyond canonical mode/status transitions.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/rls.md`
- `docs/canonical/state_machine.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/errors.md`
- `docs/canonical/env_vars.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `conversations` (status, mode, cart_state, confirm_state, timestamps)
- `messages` (message stream, tool call/result linkage)
- `agents` (`tools_enabled`, model/provider configuration)
- `orders`, `order_items` (order side effects gated by confirmation/idempotency)
- `customers` (tenant-scoped identity linkage)
- `audit_log` (policy and tool action trace)
- `channel_connections` (channel activation and credential context)

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
- Status: `active`, `escalated`, `resolved`, `abandoned` (plus `(new) -> active` initialization)
- Mode: `ai`, `manual`, `ai_whisper`
- Cart states: `empty`, `has_items`, `summary_shown`, `confirmed`, `order_created`

### Error codes referenced (if any)
- Auth/tenant scope: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
- Tool/policy gates: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`
- Cart/order guards: `CART_EMPTY`, `CONFIRM_REQUIRED`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`, `DUPLICATE_ORDER`, `ORDER_NOT_FOUND`, `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`
- Channel/runtime resilience: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`

## Design

### Routing logic
Routing follows canonical modular-monolith orchestration (routes -> services -> repositories) with tenant-scoped context resolution first. Runtime route selection is constrained by conversation state and mode:
1. Resolve tenant, customer, conversation context.
2. Persist inbound message.
3. Determine responder path by `conversations.mode`:
   - `ai`: AI response path with tool eligibility checks.
   - `manual`: merchant-owned path; AI response path paused.
   - `ai_whisper`: AI continues response path while merchant receives suggestions.
4. Apply state/mode/cart guard checks before side effects.
5. Persist outputs and audit records.

### Policy enforcement
Policy enforcement is implemented as deterministic gates around canonical contracts:
- **Tenant/identity policy**: all reads/writes must be tenant-scoped and RLS-compatible.
- **Tool authorization policy**: tool name must be present in `agents.tools_enabled`.
- **Tool schema policy**: tool args must satisfy canonical schema constraints.
- **State transition policy**: status/mode transitions only on canonical edges and triggers.
- **Order creation policy**: `create_order` requires `confirm_state = true` and idempotency key semantics.

### Guardrails and safety constraints
Guardrails are canonical business and platform constraints, not optional heuristics:
- `manual -> ai_whisper` transition remains disallowed.
- Cart limits remain enforced (max 50 items, max quantity 99 each).
- `create_order` blocked unless confirmation precondition is met.
- Webhook signature and duplicate-message protections gate channel ingress.
- Rate limits and model/runtime errors terminate or degrade processing without unsafe side effects.

### Fallback behavior
Fallback behavior is deterministic and error-driven:
- On tool authorization/validation failure, return canonical tool errors and skip side effects.
- On stock/cart/order guard failure, return canonical 422/409 errors and preserve prior consistent state.
- On model unavailability, return `MODEL_ERROR`; processing may retry by operational policy but cannot bypass guards.
- On unrecoverable internal failure, return `INTERNAL_ERROR` and rely on audit/Sentry observability.

## Interfaces
Routing and policy-relevant canonical interfaces:
- `POST /api/v1/webhooks/whatsapp/{tenant_id}`
- `GET /api/v1/webhooks/whatsapp/{tenant_id}`
- `POST /api/v1/webhooks/ecommerce/{tenant_id}`
- `WS /api/v1/ws/chat/{tenant_id}`
- `POST /api/v1/widget/messages`
- `GET /api/v1/widget/config/{tenant_id}`

Control-plane interfaces (dashboard conversation control) rely on canonical mode/status transitions for takeover, release, and resolution workflows.

Tool-call interfaces are the canonical tool contracts listed in `docs/canonical/tools.md` with argument conformance governed by `docs/canonical/tools_schemas.json`.

## Invariants
- Every routed operation is tenant-scoped and compatible with canonical RLS isolation.
- Tool execution cannot proceed unless both tool authorization and schema validation pass.
- State/mode/cart transitions never bypass canonical transition tables.
- `manual -> ai_whisper` is never permitted.
- `create_order` never executes unless `confirm_state = true`.
- Duplicate webhook events and duplicate order writes do not create duplicate side effects.
- Failures return canonical error codes and do not mutate state outside allowed transitions.

## Failure Modes
- **Tenant/auth context missing or invalid**
  - Errors: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
  - Mitigation: reject before business logic writes.

- **Tool policy violations**
  - Errors: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`
  - Mitigation: block tool invocation; request-correction path only.

- **Business guard failures during cart/order operations**
  - Errors: `CART_EMPTY`, `CONFIRM_REQUIRED`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`, `DUPLICATE_ORDER`, `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`, `ORDER_NOT_FOUND`
  - Mitigation: no partial writes; preserve consistent cart/order state.

- **Ingress integrity and runtime failures**
  - Errors: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`
  - Mitigation: halt/degrade processing safely, emit observability signals, avoid invalid transitions.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are listed as inputs but are not present in this environment; confirm whether markdown exports are required for generation traceability.
- TODO: Canonical docs define routing constraints and guards but do not define retry/backoff policy for `MODEL_ERROR` across providers; confirm operational policy source.
- TODO: Canonical docs define webhook duplicate handling but do not specify canonical retention TTL for dedup keys; confirm source of truth.

## Change Log
- 2026-02-21 — Codex: Initial Routing, Policies, and Guardrails document generated from canonical artifacts and template.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
