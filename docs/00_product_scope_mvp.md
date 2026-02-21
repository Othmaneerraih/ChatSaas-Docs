# 00 Product Scope (MVP)

## Purpose
This document defines the MVP product scope for Aidy in a way that is directly implementable and reviewable against canonical constraints. It is intended for engineering, product, QA, and operations teams as a scope control artifact for build and release decisions.

## Scope
In scope for this MVP:
- Multi-tenant AI commerce agent platform with one agent per tenant.
- Core commerce conversation flow: customer messaging, product discovery, cart operations, deterministic total calculation, and order creation with confirmation/idempotency controls.
- Supported channel and dashboard capabilities that are already defined in canonical endpoint and schema artifacts.
- Tenant-isolated data model and RLS-governed access model.

Canonical boundaries this document cannot override:
- Locked architecture, stack, and MVP non-negotiables.
- Canonical schema/tables/constraints.
- Canonical tool contracts and tool invariants.
- Canonical state/mode/cart transitions.
- Canonical error code registry.

## Non-Goals
- Defining any new schema fields, tools, enum values, endpoints, state transitions, or error codes beyond canonical files.
- Replacing the locked architecture with alternative frameworks or hosting patterns.
- Defining post-MVP roadmap commitments that are not represented in canonical artifacts.
- Expanding payment handling beyond canonical COD-first constraints and order creation boundaries.

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

### Specific tables referenced
- `tenants`, `agents`, `customers`, `conversations`, `messages`
- `products`, `product_variants`
- `orders`, `order_items`
- `documents`, `document_chunks`
- `audit_log`
- `channel_connections`, `ecommerce_connections`

### Specific tools referenced
- `search_products`
- `check_stock`
- `add_to_cart`
- `remove_from_cart`
- `calculate_total`
- `create_order`
- `get_order_status`
- `analyze_image`
- `escalate_to_human`

### Specific states/modes referenced
- Conversation status flow: `(new)`, `active`, `escalated`, `resolved`, `abandoned`
- Conversation mode flow: `ai`, `manual`, `ai_whisper`
- Cart states: `empty`, `has_items`, `summary_shown`, `confirmed`, `order_created`

### Specific error codes referenced
- `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`
- `CONVERSATION_NOT_FOUND`, `PRODUCT_NOT_FOUND`, `ORDER_NOT_FOUND`, `VARIANT_NOT_FOUND`, `DOCUMENT_NOT_FOUND`
- `DUPLICATE_ORDER`, `CART_EMPTY`, `CONFIRM_REQUIRED`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`
- `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`
- `RATE_LIMITED`, `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`
- `MODEL_ERROR`, `SYNC_IN_PROGRESS`, `BUDGET_EXCEEDED`, `INTERNAL_ERROR`

## Design
The MVP product design follows locked decisions:
- **Architecture:** modular FastAPI monolith with clear route/service/repository boundaries.
- **Data/security:** Supabase PostgreSQL with RLS, tenant isolation by `tenant_id`, UUID PKs, and timestamptz fields.
- **Agent execution model:** routing + prompt chaining + parallel guardrails, without LangChain/LangGraph for MVP.
- **Commerce behavior:** tool-mediated flow with deterministic `calculate_total` and confirm-gated `create_order`.
- **Payments:** COD-first operational model where the agent creates orders but does not process money.

Rejected alternatives for MVP (per locked constraints):
- Self-hosted LLM stacks.
- Framework-driven agent orchestration complexity for initial release.
- Product-catalog-as-RAG approach (catalog retrieval remains hybrid SQL/lexical/rerank; RAG reserved for unstructured docs).

## Interfaces
This MVP scope depends on canonical interfaces:

- **Webhooks**
  - `POST /api/v1/webhooks/whatsapp/{tenant_id}`
  - `GET /api/v1/webhooks/whatsapp/{tenant_id}`
  - `POST /api/v1/webhooks/ecommerce/{tenant_id}`

- **Widget**
  - `WS /api/v1/ws/chat/{tenant_id}`
  - `POST /api/v1/widget/messages`
  - `GET /api/v1/widget/config/{tenant_id}`

- **Dashboard API (JWT-scoped by tenant RLS)**
  - Auth: signup/login/google/magic-link/me
  - Conversations: list/detail/messages/takeover/release/manual send/update
  - Products: list/create/update/delete/import/export/variants
  - Orders: list/detail/status update
  - Knowledge base: list/upload/scrape/faq/delete
  - Agent config: get/update/history
  - Analytics: summary/conversations/top-queries/costs
  - Settings: channels, widget, embed-code, ecommerce connect/sync

Authentication/authorization assumptions remain canonical:
- Supabase JWT for dashboard APIs.
- Signature verification for webhooks.
- Tenant key/public access behavior for widget endpoints as defined canonically.

## Invariants
- Tenant isolation must hold across all tenant-scoped tables and all runtime operations.
- Every non-`tenants` business table remains tenant-attributed and RLS-governed.
- Tool invocation must remain within `agents.tools_enabled` and canonical tool schemas.
- `create_order` executes only when `conversations.confirm_state = true`.
- Order creation must preserve idempotency semantics through `idempotency_key` uniqueness.
- Cart mutation side effects are constrained to `conversations.cart_state` for cart tools.
- Conversation status/mode/cart transitions must only follow canonical transition rules and guards.
- Error responses must use canonical error codes and semantics.

## Failure Modes
- **Auth/session failures:** `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`.
- **Tenant/resource lookup failures:** `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`, `PRODUCT_NOT_FOUND`, `ORDER_NOT_FOUND`, `DOCUMENT_NOT_FOUND`, `VARIANT_NOT_FOUND`.
- **Commerce guard failures:** `CART_EMPTY`, `CONFIRM_REQUIRED`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`, `DUPLICATE_ORDER`.
- **Tool governance failures:** `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`.
- **Integration/control-plane failures:** `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `RATE_LIMITED`, `MODEL_ERROR`, `SYNC_IN_PROGRESS`, `BUDGET_EXCEEDED`, `INTERNAL_ERROR`.

Detection/mitigation baseline:
- Log tool and action traces via `audit_log`.
- Return canonical error payload shape and HTTP status behavior.
- Keep webhook dedup and idempotency controls active to prevent duplicate side effects.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` was provided as an input path but is not present in this environment; confirm source availability requirements for future doc generation runs.
- TODO: `/sources/Aidy_Technical_Spec_v3.md` was provided as an input path but is not present in this environment; confirm whether markdown exports are mandatory or docx extraction is the expected fallback.
- TODO: If product-level MVP acceptance criteria require pilot-specific quantitative targets beyond canonical constants (e.g., client count, launch gates), provide canonical location or designate non-canonical owner doc.

## Change Log
- 2026-02-21 — Codex: Initial version of MVP product scope generated from canonical docs and template, with explicit dependency mapping and consistency audit.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs `locked_decisions.md`: **PASS**
