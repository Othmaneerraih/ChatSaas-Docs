# 11 Web Widget Integration Spec

## Purpose
This document defines the canonical MVP web widget integration for Aidy, including embed model, session and conversation handling, authentication boundaries, UI contract constraints, configuration surfaces, and failure behavior. It is intended for frontend/backend engineers, QA, and operations teams implementing and validating widget channel behavior.

## Scope
In scope:
- Script-embed model and runtime isolation for the web widget channel.
- Widget session-to-conversation linkage and tenant-scoped message handling.
- Authentication and tenant boundary assumptions for widget interactions.
- Canonical widget interfaces and configuration read paths.
- Failure behavior and recovery within canonical error/state constraints.

Out of scope:
- Non-canonical widget frameworks or bundle formats.
- UI feature classes not defined by canonical artifacts.
- Replacing canonical messaging/state/tool contracts.

Canonical boundaries this document cannot override:
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/state_machine.md`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`
- `docs/canonical/tools.md`

## Non-Goals
- Defining visual brand systems beyond canonical tenant settings metadata.
- Introducing custom authentication mechanisms outside Supabase-auth-aligned boundaries.
- Defining unsupported widget-origin trust or cross-tenant data sharing behavior.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/state_machine.md`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`
- `docs/canonical/tools.md`
- `docs/canonical/env_vars.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `tenants` (`settings` metadata includes widget-related configuration fields)
- `customers` (widget-origin contact identity, including optional email)
- `conversations` (channel = `web_widget`, status/mode/cart state)
- `messages` (channel message stream and `channel_message_id` dedup behavior)
- `agents` (tool allowlist and behavior settings that affect widget interactions)
- `channel_connections` (`channel = web_widget`, activation state)
- `audit_log` (channel event and action traceability)

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
- Status lifecycle: `(new) -> active`, `active -> escalated`, `escalated -> active`, `active -> resolved`, `resolved -> active`, `active -> abandoned`
- Mode lifecycle: `ai`, `manual`, `ai_whisper` with canonical transition constraints
- Cart lifecycle used in widget commerce flow: `empty`, `has_items`, `summary_shown`, `confirmed`, `order_created`

### Error codes referenced (if any)
- Auth/tenant/channel scope: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
- Tool and business constraints: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`, `CART_EMPTY`, `CONFIRM_REQUIRED`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`, `DUPLICATE_ORDER`, `ORDER_NOT_FOUND`
- Runtime/channel protection: `RATE_LIMITED`, `WEBHOOK_DUPLICATE`, `MODEL_ERROR`, `INTERNAL_ERROR`

## Design

### Embed model
- Canonical widget implementation is a standalone React component bundled as a single JS payload (<50KB) embedded via `<script>` tag.
- Runtime isolation is provided by Shadow DOM, preventing host-page CSS/DOM interference.
- Widget transport uses backend WebSocket channel for interactive messaging.

### Session and conversation handling
1. Widget initializes in tenant context and loads configuration through canonical widget config endpoint.
2. Session identity is mapped to conversation context and message metadata (`widget_session` in channel-specific metadata).
3. Inbound widget messages create/append canonical `messages` rows under tenant-scoped `conversations`.
4. `messages.channel_message_id` uniqueness and tenant scoping prevent duplicate side effects.
5. Conversation status/mode/cart progression follows canonical state machine without channel-specific state variants.

### Authentication and authorization
- Tenant/channel access is constrained by canonical tenant isolation and RLS boundaries.
- Widget configuration retrieval and messaging endpoints must enforce tenant scoping and CORS boundary controls.
- Canonical auth errors apply when credentials or context are missing/invalid.
- No non-canonical client secret handling is allowed; server-side credentials remain protected.

### UI contract
The canonical UI contract is intentionally narrow:
- Embedded chat surface rendered in Shadow DOM.
- Real-time message exchange through widget WebSocket and message post endpoint.
- Conversation continuity through canonical status/mode semantics.
- Tool-driven commerce/support behavior constrained by canonical tool contracts.

Unsupported UI capabilities are out of scope unless added to canonical artifacts.

### Configuration options
Canonical config sources:
- `tenants.settings` contains tenant-level widget-related settings metadata.
- `GET /api/v1/widget/config/{tenant_id}` is the canonical read interface for widget runtime config.
- Environment constraints such as `CORS_ORIGINS` govern allowed frontend origins.

Canonical artifacts do not enumerate a complete typed widget-config schema; unresolved details are tracked in Open Questions.

## Interfaces
Widget integration interfaces:
- `WS /api/v1/ws/chat/{tenant_id}`
- `POST /api/v1/widget/messages`
- `GET /api/v1/widget/config/{tenant_id}`

Related service interfaces that can influence widget conversation state:
- Dashboard takeover/release controls (mode transitions)
- Channel-agnostic tool contracts executed within conversation orchestration

## Invariants
- Widget communication is always tenant-scoped and RLS-compatible.
- Embed/runtime model remains script-based React widget with Shadow DOM isolation.
- Conversation and cart transitions from widget traffic remain canonical.
- Tool execution from widget conversations remains allowlist + schema validated.
- Duplicate message handling cannot create duplicate side effects.
- Cross-tenant conversation/message leakage is never permitted.

## Failure Modes
- **Tenant/auth context failure**
  - Errors: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
  - Mitigation: reject request before conversation/tool side effects.

- **Tool contract or business-rule failure in widget flow**
  - Errors: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`, `CART_EMPTY`, `CONFIRM_REQUIRED`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`, `DUPLICATE_ORDER`, `ORDER_NOT_FOUND`
  - Mitigation: fail fast with canonical errors; preserve prior consistent state.

- **Rate/runtime and transport degradation**
  - Errors: `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`
  - Mitigation: degrade safely; avoid invalid transitions and partial writes.

- **Duplicate widget message delivery**
  - Error: `WEBHOOK_DUPLICATE` (canonical duplicate-processing semantic)
  - Mitigation: deduplicate by `channel_message_id` and suppress duplicate side effects.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are declared inputs but unavailable in this environment; confirm required source-export workflow.
- TODO: Canonical artifacts mention widget-related tenant settings but do not define a complete typed widget configuration schema (keys, defaults, validation); confirm authoritative source.
- TODO: Canonical artifacts do not define explicit widget session expiration/rotation policy for `widget_session` metadata; confirm lifecycle policy source.

## Change Log
- 2026-02-21 — Codex: Initial Web Widget Integration specification generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
