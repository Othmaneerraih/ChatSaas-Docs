# 05 Conversation Engine & State Machine

## Purpose
This document specifies the Aidy MVP conversation engine behavior and its canonical state machine contract, including message lifecycle, status/mode transitions, cart transitions, and guard conditions. It is intended for backend engineers, dashboard engineers, QA, and support operations.

## Scope
In scope:
- Conversation engine responsibilities from inbound message ingestion through response emission.
- Canonical conversation lifecycle transitions (`status`).
- Canonical responder ownership transitions (`mode`).
- Canonical cart progression and order-precondition guards.
- Runtime invariants and failure handling tied to canonical error semantics.

Out of scope:
- Introduction of new conversation states, modes, or transitions.
- Non-canonical routing frameworks or orchestration model changes.
- Alteration of canonical tool contracts, endpoint contracts, or schema fields.

Canonical boundaries this document cannot override:
- `docs/canonical/state_machine.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/errors.md`
- `docs/canonical/locked_decisions.md`

## Non-Goals
- Defining UX copy/content for message responses.
- Replacing canonical control guards (confirm gate, cart limits, idempotency behavior).
- Defining new channel-specific conversation states.
- Specifying post-MVP orchestration evolution.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/state_machine.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`
- `docs/canonical/env_vars.md`
- `docs/canonical/glossary.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `conversations` (status, mode, cart_state, confirm_state, lifecycle timestamps)
- `messages` (ordered conversation events; tool call/result trace)
- `customers` (conversation identity linkage)
- `agents` (tool enablement and behavior configuration)
- `orders`, `order_items` (order creation outcomes)
- `audit_log` (tool/action traceability)

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

### States/modes referenced
- **Status transitions** (canonical):
  - `(new) -> active`
  - `active -> escalated`
  - `escalated -> active`
  - `active -> resolved`
  - `active -> abandoned`
  - `escalated -> resolved`
  - `resolved -> active`
- **Mode transitions** (canonical):
  - `ai -> manual`
  - `manual -> ai`
  - `ai -> ai_whisper`
  - `ai_whisper -> manual`
  - `manual -> ai_whisper` is explicitly not allowed
- **Cart states** (canonical):
  - `empty`
  - `has_items`
  - `summary_shown`
  - `confirmed`
  - `order_created`

### Error codes referenced (if any)
- Conversation/runtime scoping: `CONVERSATION_NOT_FOUND`, `FORBIDDEN`, `AUTH_REQUIRED`, `AUTH_INVALID`, `TENANT_NOT_FOUND`
- Tool and cart/order guards: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `CART_EMPTY`, `CONFIRM_REQUIRED`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`, `DUPLICATE_ORDER`, `ORDER_NOT_FOUND`, `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`
- Platform/integration/runtime: `RATE_LIMITED`, `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `MODEL_ERROR`, `INTERNAL_ERROR`

## Design

### 1) Engine responsibilities
The conversation engine is responsible for:
1. Accepting inbound events from webhook/widget/dashboard pathways.
2. Resolving tenant and conversation context with canonical isolation constraints.
3. Persisting message events in order and maintaining conversation metadata (`last_message_at`, status/mode state).
4. Orchestrating tool-enabled handling under canonical tool gating and schema validation.
5. Enforcing canonical state and guard conditions before side-effecting actions.
6. Persisting outbound responses and operational traces.

### 2) Message lifecycle
1. **Ingress**: message arrives via canonical endpoint/channel path.
2. **Context resolution**: tenant, customer, and conversation are resolved/created per canonical schema.
3. **Persistence**: inbound message persisted to `messages`; conversation timestamps updated.
4. **Routing/orchestration**: engine chooses path and optionally invokes canonical tools.
5. **Guard checks**: validate mode/state/cart/confirm constraints before writes.
6. **Side effects**:
   - Cart mutations update `conversations.cart_state`.
   - Order creation writes `orders` + `order_items` and resets cart state.
   - Escalation sets `conversations.mode = 'manual'`.
7. **Emission**: outbound response written and delivered; audit/log records captured.

### 3) Status transitions (exact canonical behavior)
- `(new) -> active`: trigger is first customer message received.
- `active -> escalated`: trigger is `escalate_to_human` tool call OR merchant Take Over.
- `escalated -> active`: trigger is merchant Release.
- `active -> resolved`: trigger is merchant marks resolved OR 24h inactivity with no pending order.
- `active -> abandoned`: trigger is 72h inactivity.
- `escalated -> resolved`: trigger is merchant marks resolved.
- `resolved -> active`: trigger is customer sends new message.

### 4) Mode handling (exact canonical behavior)
- `ai -> manual`: merchant Take Over; AI stops responding and merchant types directly.
- `manual -> ai`: merchant Release; AI resumes with conversation summary.
- `ai -> ai_whisper`: merchant enters conversation view while AI active; AI keeps responding with suggestions shown.
- `ai_whisper -> manual`: merchant Take Over; AI pauses.
- `manual -> ai_whisper`: not allowed; must release to AI first, then re-enter.

### 5) Cart transitions and guards (exact canonical behavior)
- `empty`: allowed operation `add_to_cart`; guard product must exist in tenant catalog.
- `has_items`: allowed operations `add_to_cart`, `remove_from_cart`, `calculate_total`; guard max 50 items and max quantity 99 each.
- `summary_shown`: allowed operations `confirm`, `modify`, `abandon`; guard `calculate_total` must have been called.
- `confirmed`: allowed operation `create_order`; guard `confirm_state = true` and set only by explicit customer confirmation.
- `order_created`: allowed operation `get_order_status`; cart reset and new cart starts empty.

### 6) Control gates and sequencing
- Tool call must be authorized by `agents.tools_enabled` and validated against canonical tool schema.
- `create_order` precondition is mandatory and cannot be bypassed by prompt behavior.
- Idempotency protection must prevent duplicate order creation for repeated write attempts.
- Mode and status transitions are authoritative state controls and must be applied before response dispatch when side effects occur.

## Interfaces
Conversation-engine-relevant canonical interfaces:
- **Webhooks**
  - `POST /api/v1/webhooks/whatsapp/{tenant_id}`
  - `GET /api/v1/webhooks/whatsapp/{tenant_id}`
  - `POST /api/v1/webhooks/ecommerce/{tenant_id}`
- **Widget**
  - `WS /api/v1/ws/chat/{tenant_id}`
  - `POST /api/v1/widget/messages`
  - `GET /api/v1/widget/config/{tenant_id}`
- **Dashboard conversation controls**
  - conversation list/detail/messages
  - takeover/release/manual message send
  - conversation status update

Tool interfaces used by engine:
- `search_products`, `check_stock`, `add_to_cart`, `remove_from_cart`, `calculate_total`, `create_order`, `get_order_status`, `analyze_image`, `escalate_to_human`

## Invariants
- Status and mode values remain within canonical enumerations.
- Status/mode/cart transitions occur only through canonical transition edges and triggers.
- `manual -> ai_whisper` remains disallowed transition path.
- `create_order` executes only with `confirm_state = true`.
- Cart constraints remain enforced (max 50 items, max qty 99 each).
- Tool execution remains bounded by `agents.tools_enabled` and canonical argument schema checks.
- Tenant isolation applies to conversation/message/order operations through canonical scoping and RLS.

## Failure Modes
- **Missing/invalid conversation context or tenant access**
  - `CONVERSATION_NOT_FOUND`, `TENANT_NOT_FOUND`, `FORBIDDEN`, `AUTH_REQUIRED`, `AUTH_INVALID`
  - Effect: engine rejects operation before state mutation.

- **Invalid tool authorization/arguments**
  - `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`
  - Effect: tool call blocked; no state side effects.

- **Cart/order guard violations**
  - `CART_EMPTY`, `CONFIRM_REQUIRED`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`, `DUPLICATE_ORDER`
  - Effect: write flow blocked; state remains consistent.

- **Resource mismatches during commerce flow**
  - `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`, `ORDER_NOT_FOUND`
  - Effect: operation fails without invalid transition.

- **Transport/platform/runtime failures**
  - `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`
  - Effect: message processing degraded/short-circuited with canonical error behavior.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` were specified as inputs but are not present in this environment; confirm whether markdown exports are mandatory for this generation pipeline.
- TODO: Canonical state machine defines transitions and triggers but does not define conflict resolution for concurrent transition attempts (e.g., simultaneous merchant takeover and tool escalation); confirm conflict policy source.
- TODO: Canonical docs specify inactivity-based transitions (24h/72h) but do not specify scheduler/reconciliation implementation contract; confirm operational mechanism source.

## Change Log
- 2026-02-21 — Codex: Initial Conversation Engine & State Machine specification generated from canonical template and canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
