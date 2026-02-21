# Appendix A: API Reference

## Purpose
This appendix captures the canonical API reference available in repository sources for Aidy MVP. It is intended for backend engineers, frontend/widget integrators, QA, and operations teams that need exact request/response contracts, auth boundaries, error behavior, and versioning constraints without introducing non-canonical endpoints.

## Scope
In scope:
- Canonical **internal tool APIs** (Agent-Computer Interface contracts) from `docs/canonical/tools.md` and `docs/canonical/tools_schemas.json`.
- Canonical auth/error/versioning constraints relevant to API consumers.
- Canonical webhook and channel security behavior implied by schema and error registry.

Out of scope:
- Defining non-canonical HTTP route inventory not explicitly present in canonical artifacts.
- Defining SDK-specific wrappers or client convenience abstractions.
- Defining response schemas beyond what canonical artifacts provide.

Canonical boundaries this document cannot override:
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/schema.md`
- `docs/canonical/errors.md`
- `docs/canonical/locked_decisions.md`
- `docs/canonical/rls.md`

## Non-Goals
- Inventing or extending REST/WS endpoint paths.
- Adding request or response fields not present in canonical tool contracts.
- Redefining auth/session model beyond Supabase Auth + JWT + RLS constraints.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/schema.md`
- `docs/canonical/errors.md`
- `docs/canonical/locked_decisions.md`
- `docs/canonical/rls.md`
- `docs/canonical/env_vars.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `agents` (`tools_enabled`, `models`, `routing_rules`, `config_version`)
- `conversations` (`status`, `mode`, `cart_state`, `confirm_state`, `channel`)
- `messages` (`tool_name`, `tool_args`, `tool_result`, `channel_message_id`, model/token/latency fields)
- `products` and `product_variants` (tool read paths for search/stock/cart validation)
- `orders` and `order_items` (create/read order tool outcomes)
- `audit_log` (tool/action traceability)
- `channel_connections` (webhook/security credential context)
- `tenants` (tenant ownership/budget boundaries)

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
- Status: `active`, `escalated`, `resolved`, `abandoned`
- Modes: `ai`, `manual`, `ai_whisper`
- Cart states: `empty`, `has_items`, `summary_shown`, `confirmed`, `order_created`

### Error codes referenced
- Auth/access: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
- Tool contract/flow: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `CONFIRM_REQUIRED`, `CART_EMPTY`, `INVALID_QUANTITY`, `OUT_OF_STOCK`, `DUPLICATE_ORDER`, `PRODUCT_NOT_FOUND`, `ORDER_NOT_FOUND`, `VARIANT_NOT_FOUND`
- Runtime/channel: `RATE_LIMITED`, `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `MODEL_ERROR`, `SYNC_IN_PROGRESS`, `BUDGET_EXCEEDED`, `INTERNAL_ERROR`

## Design

### API inventory from canonical sources
Canonical artifacts provide two concrete API categories:

1. **Internal Tool APIs (canonical and explicit):**
   - Fully named and argument-defined in `docs/canonical/tools.md`.
   - JSON schema-aligned via `docs/canonical/tools_schemas.json`.

2. **Public HTTP/WS APIs (canonical paths not explicitly enumerated):**
   - Canonical artifacts establish webhook signature/dedup semantics and channel connection models.
   - Canonical endpoint path/method registry is not explicitly present in `docs/canonical/*`.
   - Therefore, this appendix does not assert specific public/internal route paths beyond canonical facts.

### Internal tool API contracts (canonical)

#### `search_products`
- Request fields:
  - `query?: string` (max 200 chars)
  - `category?: string`
  - `color?: string`
  - `size?: string`
  - `brand?: string`
  - `price_max?: number`
  - `in_stock_only?: boolean` (default true)
  - `limit?: integer` (1-20, default 5)
- Response shape:
  - `Array<{ product_id, variant_id, name, description, category, brand, price, size, color, stock, image_url }>`
- Constraints:
  - Tenant-scoped, read-only hybrid retrieval path.

#### `check_stock`
- Request fields:
  - `product_id: UUID`
  - `variant_id?: UUID`
- Response shape:
  - `{ in_stock: bool, quantity: int, variants: Array<{ variant_id, size, color, stock }> }`

#### `add_to_cart`
- Request fields:
  - `product_id: UUID`
  - `variant_id?: UUID`
  - `quantity: integer` (1-99)
- Response shape:
  - Updated cart object `{ items: [...], item_count, subtotal }`
- Side effects:
  - Writes `conversations.cart_state` only.

#### `remove_from_cart`
- Request fields:
  - `product_id: UUID`
  - `variant_id?: UUID`
- Response shape:
  - Updated cart object.

#### `calculate_total`
- Request fields:
  - `conversation_id: UUID` (context-injected)
- Response shape:
  - `{ items: [{ name, qty, unit_price, line_total }], subtotal, delivery_fee, total }`
- Execution model:
  - Deterministic Python function, no LLM involvement.

#### `create_order`
- Request fields:
  - `conversation_id: UUID`
  - `delivery_name: string`
  - `delivery_phone: string`
  - `delivery_address: string`
  - `delivery_city: string`
  - `notes?: string`
  - `idempotency_key: string`
- Preconditions:
  - `conversations.confirm_state` must be `true`.
- Response shape:
  - `{ order_id, status: 'pending', summary }`
- Side effects:
  - Creates `orders` + `order_items`, resets cart state.

#### `get_order_status`
- Request fields:
  - `order_id: UUID`
- Response shape:
  - `{ order_id, status, items, total, created_at, updated_at }`

#### `analyze_image`
- Request fields:
  - `image_url: string`
  - `conversation_summary: string`
  - `task: enum(diagnose|identify_product|visual_search)`
- Response shape:
  - `{ analysis: string, confidence: float, tags: string[], suggested_products: UUID[] }`
- Execution notes:
  - Calls vision model; output validated before chat-context injection.

#### `escalate_to_human`
- Request fields:
  - `reason: string`
  - `conversation_id: UUID`
- Side effects:
  - Sets conversation mode to `manual`; triggers merchant notification pathway.

### Auth requirements
- Canonical auth stack is Supabase Auth with JWT.
- Tenant isolation is mandatory: shared DB with `tenant_id` scoping + RLS.
- Access violations must return canonical auth/access error codes.
- Tool execution authorization depends on `agents.tools_enabled` allowlist and schema validation.

### Error handling contract
- Canonical response envelope for failures:
  - `{ error: { code: string, message: string, details?: any } }`
- HTTP status mapping follows canonical error registry.
- Webhook duplicate handling is explicitly canonical (`WEBHOOK_DUPLICATE` returns success semantics to prevent retries).

### Versioning
- Canonical artifacts do not define a complete public endpoint versioning policy or lifecycle policy.
- Canonical evidence of versioning-like behavior:
  - Agent configuration revisions tracked by `agents.config_version`.
  - Tool contract set is canonical and drift-checked; changes require canonical updates.
- Public API semantic versioning/deprecation policy is unresolved and tracked in Open Questions.

## Interfaces
Canonical API-facing interfaces represented in this appendix:
- Internal tool-call interface (all 9 canonical tools above).
- Auth/session interface assumptions via Supabase JWT boundary.
- Webhook/channel integrity interfaces implied by:
  - channel connection schema,
  - webhook signature verification error,
  - duplicate message idempotency behavior.

Authentication/authorization assumptions:
- Protected operations require valid JWT and tenant scope.
- RLS and service-level checks are always active.
- Service-role credentials are backend-only.

## Invariants
- Tool names/arguments are immutable unless canonical tool artifacts are updated.
- No endpoint path/method may be asserted as canonical unless present in canonical sources.
- Tenant isolation is mandatory for all API and tool operations.
- Tool invocation must respect `tools_enabled` and JSON-schema validation.
- Error responses use canonical error vocabulary and envelope.
- `create_order` must enforce confirmation + idempotency invariants.

## Failure Modes
- **Auth scope failure**
  - Errors: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`
  - Mitigation: reject request; preserve tenant boundary.

- **Tool contract violation**
  - Errors: `TOOL_VALIDATION_FAILED`, `TOOL_NOT_ALLOWED`
  - Mitigation: reject invalid/disallowed tool invocation and log in audit trail.

- **Commerce precondition failure**
  - Errors: `CONFIRM_REQUIRED`, `CART_EMPTY`, `INVALID_QUANTITY`, `OUT_OF_STOCK`, `DUPLICATE_ORDER`
  - Mitigation: enforce guardrails and return canonical contract errors.

- **Webhook integrity failure**
  - Errors: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`
  - Mitigation: reject spoofed payloads; acknowledge duplicates safely.

- **Runtime/provider failure**
  - Errors: `RATE_LIMITED`, `MODEL_ERROR`, `BUDGET_EXCEEDED`, `INTERNAL_ERROR`
  - Mitigation: bounded retries where safe, escalation and safe failure semantics.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are specified inputs but unavailable in this environment; confirm source export path.
- TODO: Canonical artifacts do not include a complete public/internal HTTP/WS endpoint registry (method + path + request/response schema) in `docs/canonical/*`; confirm authoritative API registry source.
- TODO: Canonical artifacts do not define full JSON Schema objects for tool response bodies beyond return-shape examples; confirm authoritative response schema source.
- TODO: Canonical artifacts do not define API lifecycle/versioning/deprecation policy for public interfaces; confirm governance policy.
- TODO: Canonical artifacts do not define pagination/filtering standards for any external HTTP list endpoints; confirm if applicable.

## Change Log
- 2026-02-21 — Codex: Initial API Reference appendix generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
