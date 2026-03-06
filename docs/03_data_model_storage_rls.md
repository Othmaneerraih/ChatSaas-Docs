# 03 Data Model & Storage (Supabase/Postgres) + RLS Specification
Spec Version: 1.0.0 — Generated against canonical SPEC_VERSION

## Purpose
This document defines the implementation contract for Aidy MVP data storage on Supabase/PostgreSQL, including schema usage, storage/index strategy, extension requirements, migration constraints, and tenant-isolation enforcement through RLS. It is intended for backend engineers, data engineers, and security reviewers.

## Scope
In scope:
- Canonical schema usage across tenant, conversation, commerce, retrieval, integration, and audit tables.
- Supabase/PostgreSQL configuration assumptions for extensions, primary keys, timestamp handling, and indexing.
- RLS integration model and enforcement patterns consistent with canonical constraints.
- Migration and rollout guardrails that prevent drift from canonical schema and enums/constants.

Out of scope:
- Any new tables, columns, constraints, enums, tools, or endpoints.
- Any alternate database technology or tenancy model.
- Non-canonical SQL policy clause authoring not present in canonical artifacts.

Canonical boundaries this document cannot override:
- `docs/canonical/schema.md`
- `docs/canonical/rls.md`
- `docs/canonical/locked_decisions.md`
- `docs/canonical/errors.md`

## Non-Goals
- Re-specifying canonical tables in altered form.
- Introducing custom enum types (canonical mandates TEXT + CHECK constraints model).
- Defining a custom migration framework independent of canonical architecture constraints.
- Designing non-MVP data partitioning/sharding models.

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

### Tables referenced
- `tenants`
- `agents`
- `customers`
- `conversations`
- `messages`
- `products`
- `product_variants`
- `orders`
- `order_items`
- `documents`
- `document_chunks`
- `audit_log`
- `channel_connections`
- `ecommerce_connections`

### Tools referenced (if any)
- Storage-impacting tools:
  - `add_to_cart`, `remove_from_cart` (write `conversations.cart_state`)
  - `create_order` (creates `orders` + `order_items`, resets cart state)
  - `calculate_total` (reads cart and price context)
  - `search_products`, `check_stock`, `get_order_status`, `analyze_image`, `escalate_to_human` (read/control paths against canonical tables)

### States/modes referenced (if any)
- Conversation status values: `active`, `escalated`, `resolved`, `abandoned` (+ `(new)` transition source)
- Conversation mode values: `ai`, `manual`, `ai_whisper`
- Cart flow states: `empty`, `has_items`, `summary_shown`, `confirmed`, `order_created`

### Error codes referenced (if any)
- Auth/access and scoping: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`
- Data lookup/mapping failures: `CONVERSATION_NOT_FOUND`, `PRODUCT_NOT_FOUND`, `ORDER_NOT_FOUND`, `DOCUMENT_NOT_FOUND`, `VARIANT_NOT_FOUND`
- Write guard and integrity failures: `DUPLICATE_ORDER`, `CART_EMPTY`, `CONFIRM_REQUIRED`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`
- Tool/data validation: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`
- Integration/runtime: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `RATE_LIMITED`, `SYNC_IN_PROGRESS`, `BUDGET_EXCEEDED`, `INTERNAL_ERROR`

## Design

### 1) Supabase/Postgres configuration baseline
- Database platform is Supabase PostgreSQL 15 with pgvector and RLS enabled.
- Required extensions are canonical and mandatory:
  - `uuid-ossp`
  - `pgvector`
  - `pg_trgm`
- Primary keys are UUIDs across canonical tables.
- Timestamps use `TIMESTAMPTZ` semantics.
- Multi-tenant model is shared database with tenant scoping on all business tables except `tenants`.

### 2) Schema usage model (verbatim canonical application)

#### 2.1 Tenant and identity anchors
- `tenants` is the root paying-customer record and owner linkage anchor.
- `agents` is one-per-tenant (MVP) config state and tool enablement anchor.
- `customers` stores tenant-scoped end-user identities (not Supabase Auth users).

#### 2.2 Conversation and messaging runtime
- `conversations` stores lifecycle state, mode, cart state, confirm flag, language, and timing metadata.
- `messages` stores ordered conversational events and optional tool call/result payload fields.
- Dedup behavior relies on tenant + channel message id uniqueness semantics.

#### 2.3 Commerce data model
- `products` stores typed product attributes for SQL filtering and lexical matching.
- `product_variants` stores variant-level stock and optional price overrides.
- `orders` stores immutable order records with unique `idempotency_key`.
- `order_items` stores line-level snapshot data for pricing and fulfillment traceability.

#### 2.4 Knowledge and retrieval model
- `documents` stores uploaded/scraped/manual content source metadata and processing status.
- `document_chunks` stores chunk text + embedding vectors with tenant-scoped retrieval fields.

#### 2.5 Operational/integration model
- `audit_log` stores append-only tool/action events.
- `channel_connections` stores tenant channel credentials/metadata.
- `ecommerce_connections` stores tenant ecommerce integration credentials/sync status.

### 3) Index and performance model (canonical)
Canonical index usage includes:
- `messages`: `(conversation_id, created_at)` ordered retrieval index; `(tenant_id, channel_message_id)` uniqueness for dedup.
- `products`: `(tenant_id, category)`, `(tenant_id, brand)`, GIN on tags, trigram index on name.
- `product_variants`: `(tenant_id, product_id)` and `(tenant_id, size, color)` for filtered lookups.
- `document_chunks`: HNSW on embeddings with tenant scoping requirement.

Operational implications:
- Query plans must preserve tenant filtering to avoid index misuse and isolation risk.
- Variant and catalog paths should remain typed-SQL-first per hybrid retrieval design.

### 4) Enum/constant storage pattern
- Enums are represented as TEXT columns with CHECK constraints (no PostgreSQL enum type usage).
- Canonical constants (context window, cart limits, embedding dimensions, chunk config, TTLs, target latency values) are treated as runtime invariants and cannot be silently changed through data model drift.

### 5) Migrations and change management
Migration rules for implementation:
1. Canonical-first: schema migration content must match canonical `schema.md` exactly.
2. No bypass of route/service/repository constraints when introducing DB changes.
3. Every migration changing constraints/indexes must include tenant-isolation regression validation.
4. Enum/check updates must preserve canonical values and migration safety posture.
5. Drift checks (schema/tool/state/error/architecture) must pass before release.

### 6) RLS patterns and enforcement
- RLS is mandatory on tenant-scoped tables.
- Canonical explicit RLS statements:
  - Tenant owners can read/write their own tenant; service role used for tenant creation path.
  - `customers` is tenant-scoped with canonical uniqueness constraints.
  - Shared DB + `tenant_id` + RLS is defense-in-depth baseline.
- Application/service patterns:
  - Derive tenant context from authenticated principal or verified channel mapping.
  - Do not trust arbitrary client-provided tenant identifiers.
  - Treat RLS as final enforcement boundary, with service checks as pre-filter/guard.

## Interfaces
Data/storage-relevant interfaces:

- **Dashboard JWT APIs**
  - CRUD/read paths for conversations, products, orders, knowledge, settings, and agent config all operate on tenant-scoped tables under RLS.

- **Webhook interfaces**
  - Ingestion paths write/read conversations/messages and integration records after signature verification.

- **Widget interfaces**
  - Real-time/fallback write paths feed conversation/message persistence under tenant-scoped context.

- **Tool interfaces affecting storage**
  - `add_to_cart` / `remove_from_cart`: update `conversations.cart_state`.
  - `create_order`: persist `orders`/`order_items` with idempotency and confirm gate.
  - Read tools use canonical product/order/knowledge entities without bypassing tenant boundaries.

## Invariants
- No table/column/constraint drift from canonical schema.
- `tenant_id` scoping persists on all business tables except `tenants`.
- RLS remains enabled and effective for tenant-scoped access control.
- UUID PK and TIMESTAMPTZ usage remains canonical.
- Required extensions remain present: `uuid-ossp`, `pgvector`, `pg_trgm`.
- Product retrieval remains typed SQL + lexical + rerank pattern; product catalog is not moved to unstructured-only vector retrieval.
- `orders.idempotency_key` uniqueness is preserved.
- Canonical enum and constant semantics remain stable.

## Failure Modes
- **Tenant context/auth failures**
  - `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`
  - Impact: unauthorized or mis-scoped data access attempt blocked.

- **Tenant-scoped lookup failures**
  - `CONVERSATION_NOT_FOUND`, `PRODUCT_NOT_FOUND`, `ORDER_NOT_FOUND`, `DOCUMENT_NOT_FOUND`, `VARIANT_NOT_FOUND`
  - Impact: missing or cross-tenant inaccessible entity references.

- **Data integrity/guard failures on writes**
  - `DUPLICATE_ORDER`, `CART_EMPTY`, `CONFIRM_REQUIRED`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`
  - Impact: prevented invalid commerce state transitions or duplicate side effects.

- **Tool/data validation failures**
  - `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`
  - Impact: blocked unauthorized or invalid tool-mediated data operations.

- **Integration/runtime failures**
  - `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `RATE_LIMITED`, `SYNC_IN_PROGRESS`, `BUDGET_EXCEEDED`, `INTERNAL_ERROR`
  - Impact: ingestion/control-path disruption or guarded operation short-circuit.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` were specified as inputs but are not present in this environment; confirm required source-of-truth ingestion path for doc generation.
- TODO: Canonical RLS artifact provides policy intent but not complete per-table SQL `USING`/`WITH CHECK` clauses; confirm authoritative policy-definition location.
- TODO: Canonical schema defines indexes but does not include migration file ordering/versioning strategy; confirm migration sequencing policy source.

## Change Log
- 2026-02-21 — Codex: Initial Data Model & Storage + RLS specification generated from canonical template and canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
