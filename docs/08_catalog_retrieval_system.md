# 08 Catalog & Retrieval System

## Purpose
This document defines the canonical MVP catalog and retrieval architecture for Aidy, including catalog/document data sources, indexing strategy, retrieval flow, freshness controls, cache boundaries, and failure handling. It is intended for engineers implementing retrieval services, QA validating relevance/guard behavior, and operations teams monitoring sync and retrieval health.

## Scope
In scope:
- Tenant-scoped product catalog retrieval used by tool contracts (`search_products`, `check_stock`).
- Document retrieval substrate for unstructured knowledge (`documents`, `document_chunks`).
- Canonical indexing and query strategy (SQL filters, lexical `pg_trgm`, vector support for documents).
- Freshness and synchronization touchpoints present in canonical schema.
- Failure behavior tied to canonical errors and locked architecture decisions.

Out of scope:
- Defining non-canonical retrieval engines, external search clusters, or alternate vector stores.
- Changing tool argument/return contracts.
- Introducing new ranking algorithms, evaluation pipelines, or cache APIs not present in canonical references.

Canonical boundaries this document cannot override:
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`

## Non-Goals
- Rewriting canonical schema/table definitions.
- Specifying merchandising business policy not encoded in canonical artifacts.
- Defining post-MVP retrieval architecture variants.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`
- `docs/canonical/env_vars.md`
- `docs/canonical/state_machine.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `products` (catalog metadata, searchable text fields, activation status)
- `product_variants` (size/color/stock variant constraints)
- `ecommerce_connections` (sync metadata including `last_sync_at`, `sync_status`)
- `documents` (unstructured source metadata and processing status)
- `document_chunks` (embedded chunks for vector retrieval)
- `conversations` (cart state context intersecting retrieval-driven cart flows)
- `messages` (conversation context that drives retrieval tool calls)
- `agents` (`tools_enabled` controls retrieval-tool availability)

### Tools referenced (if any)
- `search_products`
- `check_stock`
- `add_to_cart` (depends on prior search validity constraint)
- `analyze_image` (can suggest product UUIDs that map back to catalog retrieval)

### States/modes referenced (if any)
- Mode context where retrieval may execute: `ai`, `ai_whisper` (AI-managed response paths)
- Cart progression constraints linked to retrieval outputs:
  - `empty` -> `add_to_cart` (product must exist in tenant catalog)
  - `has_items` -> `add_to_cart`, `remove_from_cart`, `calculate_total`

### Error codes referenced (if any)
- Catalog/resource lookup: `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
- Tool and validation gates: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`
- Stock/business constraints: `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`
- Sync/runtime resilience: `SYNC_IN_PROGRESS`, `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`

## Design

### Data sources
The retrieval layer consumes two canonical source classes:
1. **Structured catalog source**
   - `products` + `product_variants` are authoritative for commerce retrieval.
   - Variant dimensions (`size`, `color`) and stock fields are query constraints, not inferred attributes.
2. **Unstructured knowledge source**
   - `documents` + `document_chunks` support FAQ/policy-style retrieval.
   - Canonical scope explicitly distinguishes this from product catalog retrieval.

### Indexing strategy
Indexing follows canonical schema constraints:
- PostgreSQL extensions: `pg_trgm` and `pgvector` are enabled.
- Catalog indexes:
  - `products`: tenant/category, tenant/brand, GIN on tags, `pg_trgm` on name.
  - `product_variants`: tenant/product and tenant/size/color.
- Document retrieval indexes:
  - `document_chunks.embedding` uses HNSW index with tenant scoping.

### Retrieval strategy
Retrieval architecture must remain aligned to locked decision: **SQL filters -> lexical (`pg_trgm`) -> optional semantic rerank**.
- For `search_products`:
  1. Apply deterministic tenant/category/brand/price/stock filters.
  2. Apply lexical matching (`pg_trgm`) for fuzzy query relevance.
  3. Apply optional semantic rerank within the bounded candidate set.
- For `check_stock`:
  - Resolve product/variant in tenant scope and return stock/variant view without heuristic ranking.
- For document knowledge:
  - Use chunk embeddings for tenant-scoped vector retrieval over unstructured document corpus only.

### Freshness policies
Canonical freshness signals are schema-based:
- Catalog freshness is tied to source-of-truth updates in `products`/`product_variants` plus channel sync metadata in `ecommerce_connections.last_sync_at` and `sync_status`.
- Document freshness is tied to `documents.status`, `chunk_count`, and chunk generation lifecycle.
- No non-canonical SLA/TTL values are defined in canonical references; unresolved operational thresholds are tracked in Open Questions.

### Caching
Canonical platform decisions include Upstash Redis as system cache/lock infrastructure, but canonical artifacts do not define retrieval-specific cache key formats, TTLs, or invalidation contracts.
Accordingly, retrieval correctness must not depend on undocumented cache semantics; cache optimization policy details remain an explicit open item.

## Interfaces
Retrieval-relevant interfaces are canonical tool contracts:
- `search_products(query?, category?, color?, size?, brand?, price_max?, in_stock_only?, limit?)`
- `check_stock(product_id, variant_id?)`

Related interfaces that feed retrieval pathways:
- `POST /api/v1/webhooks/whatsapp/{tenant_id}`
- `POST /api/v1/webhooks/ecommerce/{tenant_id}`
- `WS /api/v1/ws/chat/{tenant_id}`
- `POST /api/v1/widget/messages`

All interfaces operate under tenant-auth context and canonical RLS constraints.

## Invariants
- Catalog retrieval is always tenant-scoped and RLS-compatible.
- Product retrieval strategy remains SQL filters -> lexical `pg_trgm` -> optional semantic rerank.
- Unstructured document retrieval remains separate from product catalog retrieval.
- Retrieval tools execute only when allowed by `agents.tools_enabled`.
- `add_to_cart` product references must map to valid prior retrieval context and tenant catalog rows.
- Retrieval paths do not introduce non-canonical schemas, tools, or state transitions.

## Failure Modes
- **Catalog entity missing or out of scope**
  - Errors: `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
  - Mitigation: fail request before cart/order side effects.

- **Tool authorization/validation failure**
  - Errors: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`
  - Mitigation: reject tool execution, preserve current conversation/cart state.

- **Stock or cart guard violations from retrieval-driven actions**
  - Errors: `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`
  - Mitigation: block write path and return canonical guard error.

- **Concurrent sync/rate/runtime degradation**
  - Errors: `SYNC_IN_PROGRESS`, `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`
  - Mitigation: short-circuit affected operation and rely on observability/retry policy where defined.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are specified inputs but unavailable in this environment; confirm required source-export workflow.
- TODO: Canonical docs do not define retrieval cache key/TTL/invalidation policy for catalog queries; confirm the authoritative operational policy source.
- TODO: Canonical docs define hybrid retrieval order but do not specify concrete rerank model/threshold parameters for production tuning; confirm where these are governed.

## Change Log
- 2026-02-21 — Codex: Initial Catalog & Retrieval System specification generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
