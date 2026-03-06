# 01 System Architecture Overview
Spec Version: 1.0.0 — Generated against canonical SPEC_VERSION

## Purpose
This document defines the implementation-grade architecture baseline for the Aidy MVP. It translates canonical architecture decisions into concrete system decomposition, runtime flows, and deployment topology so backend, frontend, and operations teams execute against the same contract.

## Scope
In scope:
- End-to-end system architecture for MVP across backend, data, agent execution, channels, dashboard, and observability.
- Component breakdown and ownership boundaries consistent with modular monolith + 3-layer service design.
- Data flow and control flow for inbound messaging, tool orchestration, cart/order lifecycle, and escalation.
- Deployment topology for Railway (backend), Vercel (frontend), Supabase (data/auth/realtime/vector), Upstash Redis (cache/locks), and Sentry (monitoring).

Out of scope:
- New schema/tool/state/error definitions.
- Post-MVP architecture variants (microservices extraction, framework migration).
- Vendor replacements not already allowed by canonical constraints.

Canonical boundaries this document cannot override:
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md` + `docs/canonical/tools_schemas.json`
- `docs/canonical/state_machine.md`
- `docs/canonical/errors.md`

## Non-Goals
- Defining internal class-level implementation details for each module.
- Redesigning canonical APIs, tool contracts, state transitions, or error semantics.
- Introducing self-hosted model infrastructure or non-canonical orchestration frameworks.
- Replacing canonical hosting and security posture.

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
- Core tenancy/config: `tenants`, `agents`
- Identity/channel actor records: `customers`, `channel_connections`, `ecommerce_connections`
- Conversation runtime: `conversations`, `messages`
- Commerce catalog/ordering: `products`, `product_variants`, `orders`, `order_items`
- Knowledge retrieval: `documents`, `document_chunks`
- Traceability/operations: `audit_log`

### Tools referenced (if any)
- `search_products`, `check_stock`
- `add_to_cart`, `remove_from_cart`, `calculate_total`
- `create_order`, `get_order_status`
- `analyze_image`, `escalate_to_human`

### States/modes referenced (if any)
- Status: `(new)`, `active`, `escalated`, `resolved`, `abandoned`
- Mode: `ai`, `manual`, `ai_whisper`
- Cart states: `empty`, `has_items`, `summary_shown`, `confirmed`, `order_created`

### Error codes referenced (if any)
- Access/auth: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`
- Lookup/not found: `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`, `PRODUCT_NOT_FOUND`, `ORDER_NOT_FOUND`, `DOCUMENT_NOT_FOUND`, `VARIANT_NOT_FOUND`
- Commerce/tool guards: `DUPLICATE_ORDER`, `CART_EMPTY`, `CONFIRM_REQUIRED`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`, `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`
- Integration/platform: `RATE_LIMITED`, `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `MODEL_ERROR`, `SYNC_IN_PROGRESS`, `BUDGET_EXCEEDED`, `INTERNAL_ERROR`

## Design

### 1) Component breakdown

#### 1.1 Backend (FastAPI modular monolith)
Canonical module boundaries:
- `auth`: JWT-authenticated dashboard access and tenant context resolution.
- `messaging`: message ingestion, persistence, ordering, and channel dedup linkage.
- `products`: typed catalog and variant reads/writes for retrieval + inventory checks.
- `orders`: confirm-gated order creation with idempotency enforcement.
- `agents`: tenant-scoped config, tool enablement, and model role configuration.
- `retrieval`: hybrid product retrieval and vector lookup for document chunks.
- `tools`: canonical tool contract execution and validation.
- `channels`: webhook and widget transport handling.

Internal layering (must not be skipped):
- `routes` handle transport and auth context.
- `services` enforce business rules and orchestration.
- `repositories` perform Supabase/PostgreSQL interactions.

#### 1.2 Data plane (Supabase PostgreSQL + pgvector + RLS)
- Shared multi-tenant schema with `tenant_id` scoping on all business tables except `tenants`.
- RLS policy model enforces tenant isolation at DB layer.
- Structured commerce entities stored in typed relational tables.
- Unstructured knowledge stored as `documents` and vectorized `document_chunks`.

#### 1.3 Agent execution plane
- Tool-enabled agent runtime driven by canonical contracts.
- Routing + prompt chaining + parallel guardrails pattern.
- Deterministic pricing path via `calculate_total` (no LLM involvement).
- Explicit confirmation gate before `create_order`.

#### 1.4 Frontend plane
- Dashboard: Next.js + Shadcn/Tailwind for tenant operations UI.
- Widget: standalone React bundle (<50KB) served for embed use.

#### 1.5 Support/ops plane
- Upstash Redis: session/cache/lock usage.
- Sentry: error and performance telemetry.

### 2) Data flow

#### 2.1 Inbound customer message flow
1. Channel ingress via webhook/widget endpoint.
2. Tenant resolution and dedup checks using canonical message/channel fields.
3. Conversation and message persistence in tenant-scoped tables.
4. Router selects handling path (standard/tool/vision/escalation as permitted by canonical tools).
5. Tool calls produce structured results persisted in message/audit records.
6. Outbound response stored and emitted via channel transport.

#### 2.2 Commerce cart/order flow
1. Catalog retrieval (`search_products`) and stock inquiry (`check_stock`).
2. Cart mutations via `add_to_cart`/`remove_from_cart` on `conversations.cart_state`.
3. Totals computed via deterministic `calculate_total`.
4. `create_order` permitted only when `conversations.confirm_state = true`.
5. Order and order items persisted; cart reset; status accessible via `get_order_status`.

#### 2.3 Knowledge/vision flow
1. Knowledge assets are stored in `documents` and chunked into `document_chunks`.
2. Retrieval combines tenant scoping and vector search for knowledge response context.
3. Image analysis uses `analyze_image`, then injects validated result into response path.

### 3) Control flow

#### 3.1 Conversation lifecycle control
- Status transitions follow canonical lifecycle table only.
- Mode transitions enforce takeover/release semantics and `ai_whisper` constraints.
- Cart state transitions enforce max-item/max-quantity and confirm guard.

#### 3.2 Error/control handling
- Validation, guard, and lookup failures map to canonical error codes.
- Duplicate webhook and duplicate order paths are handled with canonical semantics.
- Tool authorization failures use `TOOL_NOT_ALLOWED` and schema mismatch uses `TOOL_VALIDATION_FAILED`.

### 4) Deployment topology

#### 4.1 Runtime topology
- Backend API + orchestration: Railway.
- Frontend dashboard: Vercel.
- Data/auth/realtime/vector: Supabase PostgreSQL + Auth + pgvector.
- Cache/locks: Upstash Redis.
- Monitoring: Sentry.

#### 4.2 Integration edges
- WhatsApp/ecommerce webhooks terminate at backend webhook endpoints.
- Widget connects via WebSocket endpoint with HTTP fallback path.
- Backend interacts with model providers through configured API keys and orchestrator controls.

#### 4.3 Config and secrets posture
- Runtime variables are environment-managed (not in client bundles/code).
- Required env footprint follows canonical env var registry.

## Interfaces
Canonical interfaces used by this architecture:

- **Webhooks**

- **Widget**

- **Dashboard API groups**
  - Auth, Conversations, Products, Orders, Knowledge Base, Agent Config, Analytics, Settings

Tool interfaces:
- `search_products`, `check_stock`, `add_to_cart`, `remove_from_cart`, `calculate_total`, `create_order`, `get_order_status`, `analyze_image`, `escalate_to_human`

Data interfaces:
- Read/write operations to canonical tables under route/service/repository layering with RLS-scoped tenant access.

## Invariants
- Architecture remains modular monolith FastAPI with 3-layer boundary enforcement.
- Multi-tenancy remains shared DB + `tenant_id` scoping + RLS enforcement.
- Tool contract usage remains bounded to canonical tool names/arguments and enabled-tool policy.
- Conversation lifecycle/mode/cart behavior remains constrained to canonical transition tables.
- `create_order` precondition (`confirm_state=true`) and idempotency key semantics remain mandatory.
- Structured product search remains hybrid SQL/lexical/rerank; product catalog is not shifted to unstructured-only RAG.
- Error contract shape and canonical codes remain stable across all modules.

## Failure Modes
- **Auth and tenancy context failures:** `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`.
- **Resource consistency failures:** `CONVERSATION_NOT_FOUND`, `PRODUCT_NOT_FOUND`, `ORDER_NOT_FOUND`, `DOCUMENT_NOT_FOUND`, `VARIANT_NOT_FOUND`.
- **Commerce flow guard failures:** `CART_EMPTY`, `CONFIRM_REQUIRED`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`, `DUPLICATE_ORDER`.
- **Tool control failures:** `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`.
- **Transport/provider/runtime failures:** `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `RATE_LIMITED`, `MODEL_ERROR`, `SYNC_IN_PROGRESS`, `BUDGET_EXCEEDED`, `INTERNAL_ERROR`.

Detection and mitigation:
- Persist tool/action traces in `audit_log`.
- Preserve idempotency and dedup controls for write-safety.
- Use canonical error payloads and HTTP statuses for recoverable client behavior.
- Route unhandled failures to Sentry for operational triage.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` was specified as an input but is not present in this environment; confirm whether this pipeline should require markdown exports or continue using `docs/canonical/*` as source-of-truth inputs.
- TODO: `/sources/Aidy_Technical_Spec_v3.md` was specified as an input but is not present in this environment; confirm whether intent notes must be pulled from this path or from existing canonical rationale comments.
- TODO: RLS canonical artifact describes policy intent but not per-table SQL policy clauses; confirm where architecture-level policy clause detail should be sourced for implementation docs.

## Change Log
- 2026-02-21 — Codex: Created initial system architecture overview from canonical template and canonical docs, including component/data/control/deployment coverage and consistency audit.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
