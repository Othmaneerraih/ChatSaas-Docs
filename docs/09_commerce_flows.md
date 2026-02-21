# 09 Commerce Flows

## Purpose
This document specifies the canonical MVP commerce flow behavior for browsing, carting, checkout, order creation, payment handling fields, confirmation controls, and failure/rollback behavior. It is intended for backend engineers, QA, and operations teams validating end-to-end commerce correctness against canonical contracts.

## Scope
In scope:
- Browse and product discovery flow through canonical retrieval tools.
- Add-to-cart, cart modification, total calculation, and confirmation-to-order transition.
- Order creation and status retrieval flows.
- Payment field handling as canonical order metadata (`payment_method`, `payment_status`).
- Edge cases and rollback/no-partial-write behavior under canonical errors.

Out of scope:
- Introducing new payment rails, gateways, or money movement logic.
- Defining non-canonical order or payment status values.
- Altering canonical tool contracts, schema definitions, or state transitions.

Canonical boundaries this document cannot override:
- `docs/canonical/locked_decisions.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/state_machine.md`
- `docs/canonical/schema.md`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`

## Non-Goals
- Defining marketing/UX messaging copy for product recommendation or checkout prompts.
- Specifying accounting/reconciliation processes outside canonical scope.
- Introducing post-MVP commerce orchestration patterns.

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
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `products`, `product_variants` (browse/search and stock constraints)
- `conversations` (`cart_state`, `confirm_state`, status/mode context)
- `messages` (tool call sequencing and conversation event trail)
- `orders` (order creation, status, payment method/status fields, idempotency key)
- `order_items` (line-item snapshot on create_order)
- `customers` (customer ownership scope for order lookups)
- `audit_log` (tool/action trace)

### Tools referenced
- `search_products`
- `check_stock`
- `add_to_cart`
- `remove_from_cart`
- `calculate_total`
- `create_order`
- `get_order_status`
- `escalate_to_human`

### States/modes referenced (if any)
- Cart states and allowed operations:
  - `empty` -> `add_to_cart`
  - `has_items` -> `add_to_cart`, `remove_from_cart`, `calculate_total`
  - `summary_shown` -> `confirm`, `modify`, `abandon`
  - `confirmed` -> `create_order`
  - `order_created` -> `get_order_status`
- Commerce-relevant mode/state context:
  - `ai`, `manual`, `ai_whisper`
  - `active`, `escalated`, `resolved`, `abandoned`

### Error codes referenced (if any)
- Cart/order guardrails: `CART_EMPTY`, `CONFIRM_REQUIRED`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`, `DUPLICATE_ORDER`
- Resource scope/lookup: `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`, `ORDER_NOT_FOUND`, `CONVERSATION_NOT_FOUND`, `TENANT_NOT_FOUND`, `FORBIDDEN`
- Tool/runtime control: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`

## Design

### 1) Browse flow
1. Inbound user intent triggers product discovery in conversation context.
2. `search_products` executes under tenant scope with canonical filters (`category`, `brand`, `size`, `color`, `price_max`, `in_stock_only`, `limit`).
3. Optional `check_stock` validates inventory for a chosen product/variant before cart mutation.
4. Returned product/variant identifiers become the only valid source for downstream `add_to_cart` references in that conversation.

### 2) Add-to-cart and cart modification flow
1. From `cart_state = empty`, `add_to_cart` is allowed only if product exists in tenant catalog.
2. In `has_items`, the system allows repeated `add_to_cart`, `remove_from_cart`, and `calculate_total` while enforcing limits (max 50 items, max qty 99 each).
3. `add_to_cart` side effects are limited to `conversations.cart_state` updates and do not mutate catalog stock directly.
4. Cart mutation failures return canonical guard errors and preserve prior consistent cart state.

### 3) Checkout and confirmation flow
1. `calculate_total` is invoked as deterministic computation over current cart and pricing.
2. Transition to checkout readiness maps to canonical `summary_shown` semantics (total computed, ready for confirmation/modification/abandon).
3. Explicit customer confirmation sets canonical precondition (`confirm_state = true`) required for order creation.
4. If confirmation is absent, `create_order` must fail with `CONFIRM_REQUIRED` and no order rows are created.

### 4) Order creation and payment metadata flow
1. `create_order` executes only from the canonical confirmed path and must include required delivery fields and `idempotency_key`.
2. Successful creation writes `orders` + `order_items`, resets cart, and returns `{ order_id, status: 'pending', summary }`.
3. Canonical payment fields on `orders` are metadata:
   - `payment_method`: `cod`, `online`, `merchant_link`
   - `payment_status`: `pending`, `paid`, `failed`
4. Flow does not authorize direct payment processing by the agent; agent creates orders and merchant controls payment handling per locked decision.

### 5) Post-order status and escalation flow
1. `get_order_status` retrieves canonical order status for the scoped customer/order.
2. If the flow is blocked or requires handoff, `escalate_to_human` moves conversation mode to `manual` under canonical transition rules.

### 6) Edge cases and rollback behavior
- Duplicate submission with same idempotency key returns `DUPLICATE_ORDER`; no duplicate order writes occur.
- Invalid quantity, cart overflow, out-of-stock, or missing entities fail fast with canonical errors; cart/order data remains consistent.
- Tool authorization/validation failure blocks execution prior to side effects.
- Runtime/model failures return canonical operational errors and do not bypass state/cart guards.

## Interfaces
Commerce flow uses canonical tool contracts as the primary interface layer:
- `search_products(query?, category?, color?, size?, brand?, price_max?, in_stock_only?, limit?)`
- `check_stock(product_id, variant_id?)`
- `add_to_cart(product_id, variant_id?, quantity)`
- `remove_from_cart(product_id, variant_id?)`
- `calculate_total(conversation_id)`
- `create_order(conversation_id, delivery_name, delivery_phone, delivery_address, delivery_city, notes?, idempotency_key)`
- `get_order_status(order_id)`
- `escalate_to_human(reason, conversation_id)`

Ingress surfaces that can trigger commerce tool paths:
- `POST /api/v1/webhooks/whatsapp/{tenant_id}`
- `POST /api/v1/webhooks/ecommerce/{tenant_id}`
- `WS /api/v1/ws/chat/{tenant_id}`
- `POST /api/v1/widget/messages`

## Invariants
- Commerce operations are tenant-scoped and RLS-compatible.
- Cart transitions follow canonical allowed operations and guards only.
- `create_order` executes only when `confirm_state = true`.
- Order creation is idempotent via canonical `idempotency_key` uniqueness.
- No non-canonical payment/order states are introduced in flow handling.
- Failures do not produce partial writes that violate cart/order consistency.

## Failure Modes
- **Catalog and inventory inconsistencies at operation time**
  - Errors: `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`, `OUT_OF_STOCK`
  - Mitigation: reject mutation and keep previous cart/order state.

- **Cart and checkout precondition failures**
  - Errors: `INVALID_QUANTITY`, `CART_FULL`, `CART_EMPTY`, `CONFIRM_REQUIRED`
  - Mitigation: block progression to order creation; require corrected input/explicit confirmation.

- **Duplicate or invalid order write attempts**
  - Errors: `DUPLICATE_ORDER`, `ORDER_NOT_FOUND`
  - Mitigation: enforce idempotency guard and scoped lookup validation.

- **Authorization, validation, and runtime failures**
  - Errors: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`, `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`
  - Mitigation: fail fast before unauthorized writes; preserve canonical state integrity.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are required inputs but unavailable in this environment; confirm source-export workflow.
- TODO: Canonical artifacts define payment method/status enums but do not specify lifecycle transition policy for `payment_status`; confirm authoritative process owner and source.
- TODO: Canonical artifacts define order-status enum values but do not define the exact actor/event transition matrix between statuses; confirm source of truth.

## Change Log
- 2026-02-21 — Codex: Initial Commerce Flows specification generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
