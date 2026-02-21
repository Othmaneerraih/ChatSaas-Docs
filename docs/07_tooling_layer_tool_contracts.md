# 07 Tooling Layer & Tool Contracts

## Purpose
This document specifies the MVP tooling layer contract for Aidy, including tool invocation lifecycle, contract validation, state/precondition gates, idempotent write behavior, and execution guarantees. It is intended for backend engineers, QA, and operations responsible for reliable tool orchestration and policy enforcement.

## Scope
In scope:
- Canonical tool inventory and lifecycle from request planning through tool result persistence.
- Validation boundaries using canonical tool schemas and contract constraints.
- Confirmation and state gates for cart/order flows.
- Idempotency and side-effect guarantees for write tools.
- Canonical error handling for tool execution paths.

Out of scope:
- Introducing new tools, arguments, return payload fields, or execution frameworks.
- Defining post-MVP orchestration frameworks or non-canonical agent patterns.
- Replacing canonical state-machine or schema constraints.

Canonical boundaries this document cannot override:
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/state_machine.md`
- `docs/canonical/schema.md`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`
- `docs/canonical/locked_decisions.md`

## Non-Goals
- Defining UI behavior for merchant-facing tool traces.
- Defining new moderation/safety classes outside canonical contracts.
- Re-specifying database schema beyond canonical references.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/schema.md`
- `docs/canonical/state_machine.md`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`
- `docs/canonical/locked_decisions.md`
- `docs/canonical/env_vars.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `agents` (`tools_enabled` allowlist, model/provider settings)
- `conversations` (`mode`, `status`, `cart_state`, `confirm_state`)
- `messages` (`tool_name`, tool arguments/results in message lifecycle)
- `orders` (`idempotency_key`, order write outcomes)
- `order_items` (side effects from `create_order`)
- `products`, `product_variants` (read dependencies for search/stock/cart validation)
- `audit_log` (`tool_name`, `tool_args`, `tool_result`, actor trace)

### Tools referenced
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
- Modes: `ai`, `manual`, `ai_whisper`
- Status transitions relevant to tooling side effects: `active -> escalated`, `escalated -> active`, `resolved -> active`
- Cart states and operations:
  - `empty` -> `add_to_cart`
  - `has_items` -> `add_to_cart`, `remove_from_cart`, `calculate_total`
  - `summary_shown` -> `confirm`, `modify`, `abandon`
  - `confirmed` -> `create_order`
  - `order_created` -> `get_order_status`

### Error codes referenced (if any)
- Tool/policy validation: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`
- Cart/order preconditions and write safety: `CART_EMPTY`, `CONFIRM_REQUIRED`, `INVALID_QUANTITY`, `CART_FULL`, `OUT_OF_STOCK`, `DUPLICATE_ORDER`, `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`, `ORDER_NOT_FOUND`
- Access/control boundary: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
- Runtime path: `MODEL_ERROR`, `RATE_LIMITED`, `INTERNAL_ERROR`

## Design

### Tool lifecycle
1. **Context resolution**: resolve tenant, customer, conversation, and agent context.
2. **Eligibility gate**: confirm requested tool is in `agents.tools_enabled`.
3. **Schema/constraint validation**: validate required/optional fields and canonical constraints from `tools.md` and `tools_schemas.json`.
4. **State/precondition checks**: enforce mode, cart-state, and confirmation requirements before execution.
5. **Execution**:
   - Read-only tools (`search_products`, `check_stock`, `get_order_status`) return tenant-scoped data.
   - Deterministic compute tool (`calculate_total`) executes without LLM involvement.
   - Write tools (`add_to_cart`, `remove_from_cart`, `create_order`, `escalate_to_human`) apply controlled side effects.
   - Vision tool (`analyze_image`) calls configured model and validates result structure.
6. **Persistence and trace**: persist tool call/result in message stream and audit log.
7. **Post-conditions**: ensure state transitions and side effects remain canonical.

### Validation model
Validation is deterministic and must occur before side effects:
- Required fields must be present per canonical table/contract definitions.
- Type and boundary constraints must match canonical constraints (e.g., `quantity` 1-99, `limit` 1-20).
- Cross-entity checks must remain tenant-scoped (product/variant/order ownership).
- For write flows, validation failure returns canonical 4xx tool/business errors and performs no partial writes.

### Idempotency and confirmation gates
- `create_order` is guarded by `conversations.confirm_state = true`; otherwise return `CONFIRM_REQUIRED`.
- `orders.idempotency_key` uniqueness is the duplicate-write guard; replay attempts return `DUPLICATE_ORDER`.
- Cart/order flow respects canonical cart transitions and cannot bypass the `confirmed` precondition for order creation.

### Execution guarantees
- Tool side effects are constrained to canonical write surfaces documented in `tools.md`.
- `add_to_cart` modifies cart state only and does not directly mutate catalog stock records.
- `calculate_total` is deterministic and free of LLM variability.
- `escalate_to_human` sets mode to `manual` and triggers merchant notification behavior.
- All tool execution remains inside modular-monolith layering and tenant/RLS boundaries.

### Error handling behavior
- Authorization or schema violations fail fast (`TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`).
- Business guard failures return canonical errors (`OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`, `CART_EMPTY`, `CONFIRM_REQUIRED`).
- Missing or mis-scoped resources return canonical not-found/access errors.
- Runtime failures surface canonical operational errors (`MODEL_ERROR`, `RATE_LIMITED`, `INTERNAL_ERROR`) with no non-canonical fallback mechanisms.

## Interfaces
Tooling-layer interfaces rely on canonical tool call contracts embedded in orchestrator prompts and validated prior to execution.

System interfaces that can trigger tooling workflows:
- `POST /api/v1/webhooks/whatsapp/{tenant_id}`
- `POST /api/v1/webhooks/ecommerce/{tenant_id}`
- `WS /api/v1/ws/chat/{tenant_id}`
- `POST /api/v1/widget/messages`

Tool-call interface inventory:
- `search_products(query?, category?, color?, size?, brand?, price_max?, in_stock_only?, limit?)`
- `check_stock(product_id, variant_id?)`
- `add_to_cart(product_id, variant_id?, quantity)`
- `remove_from_cart(product_id, variant_id?)`
- `calculate_total(conversation_id)`
- `create_order(conversation_id, delivery_name, delivery_phone, delivery_address, delivery_city, notes?, idempotency_key)`
- `get_order_status(order_id)`
- `analyze_image(image_url, conversation_summary, task)`
- `escalate_to_human(reason, conversation_id)`

## Invariants
- Only canonical tools are invocable.
- A tool call executes only if tool allowlist and argument validation both pass.
- All tool data access and writes remain tenant-scoped and RLS-compatible.
- Write side effects follow canonical state/cart/confirmation gates.
- `create_order` remains idempotent under `idempotency_key` uniqueness.
- Tool results and side effects are traceable in canonical message/audit surfaces.
- No runtime path can introduce non-canonical tool names or fields.

## Failure Modes
- **Tool not enabled for agent**
  - Error: `TOOL_NOT_ALLOWED`
  - Detection: allowlist check against `agents.tools_enabled` fails.
  - Mitigation: block execution; keep conversation state unchanged.

- **Argument contract mismatch**
  - Error: `TOOL_VALIDATION_FAILED`
  - Detection: schema/type/constraint checks fail.
  - Mitigation: reject tool call pre-execution; request corrected arguments.

- **Cart/order guard violations**
  - Errors: `CART_EMPTY`, `CONFIRM_REQUIRED`, `INVALID_QUANTITY`, `CART_FULL`, `OUT_OF_STOCK`, `DUPLICATE_ORDER`
  - Detection: precondition checks and unique-constraint outcome.
  - Mitigation: no partial writes; preserve canonical cart/order consistency.

- **Resource scope or lookup failures**
  - Errors: `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`, `ORDER_NOT_FOUND`, `CONVERSATION_NOT_FOUND`, `TENANT_NOT_FOUND`, `FORBIDDEN`
  - Detection: tenant-scoped lookup miss or auth boundary violation.
  - Mitigation: abort tool call with canonical error response.

- **Runtime or provider failures**
  - Errors: `MODEL_ERROR`, `RATE_LIMITED`, `INTERNAL_ERROR`
  - Detection: provider/API/runtime failure during execution.
  - Mitigation: fail safely without illegal state transition; capture trace in logs/monitoring.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are declared inputs but are not available in this environment; confirm whether markdown exports are required for authoritative citation workflow.
- TODO: Canonical `tools.md` specifies response examples but does not define full response JSON schemas in `tools_schemas.json`; confirm whether response-schema enforcement is out of scope or specified elsewhere.
- TODO: Canonical docs specify `idempotency_key` generation as `conv_id + timestamp hash` but do not define collision/retry policy details; confirm operational standard source.

## Change Log
- 2026-02-21 — Codex: Initial Tooling Layer & Tool Contracts specification generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
