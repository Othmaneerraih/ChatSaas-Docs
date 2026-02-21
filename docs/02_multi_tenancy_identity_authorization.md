# 02 Multi-Tenancy, Identity, and Authorization Model

## Purpose
This document defines the implementation model for tenant isolation, identity, authentication, and authorization in the Aidy MVP. It is intended to be used by backend engineers, frontend engineers, QA, and security reviewers as an execution contract aligned to canonical schema and RLS constraints.

## Scope
In scope:
- Tenant isolation boundaries across persistence, API access, and tool execution.
- Identity model for tenant owners and end-customers.
- Authentication flows for dashboard, widget, and webhook entry points.
- Authorization model combining JWT context, RLS, and route/service checks.
- Failure handling for identity and authorization errors.

Out of scope:
- Any new identity providers, new role models, or non-canonical auth schemes.
- Per-table SQL policy definitions not explicitly enumerated in canonical artifacts.
- Non-MVP IAM features (team RBAC, cross-tenant sharing, delegated org roles).

Canonical boundaries this document cannot override:
- Locked architecture and auth decisions in `docs/canonical/locked_decisions.md`.
- Schema and tenant ownership fields in `docs/canonical/schema.md`.
- RLS model in `docs/canonical/rls.md`.
- Endpoint and auth expectations in canonical API registry (`docs/canonical/schema.md`).
- Error semantics in `docs/canonical/errors.md`.

## Non-Goals
- Defining custom token issuance or replacing Supabase Auth.
- Introducing new authorization enums, roles, or policy states.
- Defining non-canonical webhook auth schemes.
- Expanding authorization decisions beyond canonical tenant ownership and tool enablement checks.

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
- `tenants` (owner linkage, plan, active status)
- `agents` (tenant-scoped agent config and enabled tools)
- `customers` (end-user record, tenant-scoped)
- `conversations` (tenant/customer/channel context, mode/status)
- `messages` (tenant-scoped message and channel dedup context)
- `orders`, `order_items` (tenant/customer-bound commerce records)
- `documents`, `document_chunks` (tenant-scoped retrieval corpus)
- `channel_connections`, `ecommerce_connections` (tenant credential/config records)
- `audit_log` (security-relevant action traceability)

### Tools referenced (if any)
- Authorization-governed tool set:
  - `search_products`, `check_stock`, `add_to_cart`, `remove_from_cart`, `calculate_total`, `create_order`, `get_order_status`, `analyze_image`, `escalate_to_human`
- Tool access gate:
  - Tool name must be present in `agents.tools_enabled`; otherwise `TOOL_NOT_ALLOWED`.

### States/modes referenced (if any)
- Conversation status: `active`, `escalated`, `resolved`, `abandoned` (plus `(new)` transition source).
- Conversation mode: `ai`, `manual`, `ai_whisper`.
- Cart/confirm states relevant to authorization-like guards on write actions:
  - `confirmed` cart state and `conversations.confirm_state = true` for `create_order`.

### Error codes referenced (if any)
- Access/authn/authz: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`.
- Tenant/resource scope failures: `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`, `PRODUCT_NOT_FOUND`, `ORDER_NOT_FOUND`, `DOCUMENT_NOT_FOUND`, `VARIANT_NOT_FOUND`.
- Tool/authz guard failures: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`.
- Commerce write guard failures tied to scoped state: `CONFIRM_REQUIRED`, `DUPLICATE_ORDER`, `CART_EMPTY`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`.
- Integration/auth boundary failures: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `RATE_LIMITED`, `INTERNAL_ERROR`.

## Design

### 1) Tenant isolation model
- Multi-tenancy is implemented as shared PostgreSQL with `tenant_id` on all business tables except `tenants`.
- Isolation is enforced at database layer with RLS and JWT-derived tenant context.
- Service and repository layers must not bypass tenant scoping assumptions; DB is the final enforcement boundary.
- Cross-tenant reads/writes are prohibited by design and should fail through canonical not-found/forbidden paths depending on context.

### 2) Identity model
- **Tenant owner identity**
  - Backed by Supabase Auth user identity.
  - `tenants.owner_id` references `auth.users(id)`.
  - Owners can read/write their own tenant context (per canonical RLS statement).
- **Customer identity**
  - Customers are not Supabase Auth users.
  - Customer records are tenant-scoped business identities represented in `customers` and linked to `conversations`.
  - `customers` uniqueness constraints on `(tenant_id, phone)` and `(tenant_id, email)` prevent cross-identity collision within a tenant.

### 3) Authentication flows

#### 3.1 Dashboard authentication (JWT)
- Canonical dashboard auth endpoints:
  - `POST /api/v1/auth/signup`
  - `POST /api/v1/auth/login`
  - `POST /api/v1/auth/google`
  - `POST /api/v1/auth/magic-link`
  - `GET /api/v1/auth/me`
- Requests use Supabase JWT in `Authorization` header.
- JWT context is used to derive tenant scope and enforce access through RLS and service checks.

#### 3.2 Webhook authentication
- Webhook endpoints do not use JWT.
- Authentication boundary is signature verification:
  - WhatsApp webhook signature check.
  - Ecommerce webhook secret verification.
- Signature failures map to `WEBHOOK_SIGNATURE_INVALID`.

#### 3.3 Widget authentication
- WebSocket and fallback widget message paths use tenant public API key semantics as defined canonically.
- Widget config read endpoint is documented as public in canonical registry.
- Tenant scoping for resulting conversation/message writes still resolves through tenant-bound records and DB policy.

### 4) Authorization model
- Authorization is a layered model:
  1. **Route-layer auth boundary:** validates required credential type by interface (JWT, signature, tenant key/public).
  2. **Service-layer policy checks:** verifies operation preconditions (ownership, enabled tools, confirm/idempotency guards).
  3. **Repository/DB boundary:** RLS and tenant scoping enforce final data access constraints.
- Authorization outcomes:
  - Missing/invalid principal credential → `AUTH_REQUIRED` or `AUTH_INVALID`.
  - Authenticated but out-of-scope tenant ownership/access → `FORBIDDEN`.
  - Tenant-scoped missing resources → canonical `*_NOT_FOUND` codes.

### 5) RLS integration
- RLS is mandatory for tenant tables and treated as non-optional enforcement.
- Service logic must pass tenant context consistently; it must never rely on client-submitted tenant identifiers without auth-derived context validation.
- RLS complements, not replaces, application checks:
  - Tool enablement (`agents.tools_enabled`) is app-level authorization.
  - Order creation confirm/idempotency is app-level guard logic.
- CI isolation validation is expected per locked decisions.

## Interfaces
Authentication and authorization-relevant canonical interfaces:

- **Dashboard JWT interfaces**
  - Auth endpoints under `/api/v1/auth/*` and all dashboard resource groups requiring Supabase JWT.

- **Webhook interfaces (signature-verified)**
  - `POST /api/v1/webhooks/whatsapp/{tenant_id}`
  - `GET /api/v1/webhooks/whatsapp/{tenant_id}`
  - `POST /api/v1/webhooks/ecommerce/{tenant_id}`

- **Widget interfaces**
  - `WS /api/v1/ws/chat/{tenant_id}`
  - `POST /api/v1/widget/messages`
  - `GET /api/v1/widget/config/{tenant_id}`

- **Tool call interfaces under authorization policy**
  - All canonical tools in `docs/canonical/tools.md` constrained by `agents.tools_enabled` and argument schema validation.

## Invariants
- Supabase Auth is the only canonical dashboard identity provider.
- Tenant owner linkage remains `tenants.owner_id -> auth.users(id)`.
- Every tenant-scoped table access is constrained by RLS and tenant context.
- Customers remain business identities (not Supabase Auth identities).
- Tool calls outside `agents.tools_enabled` are denied (`TOOL_NOT_ALLOWED`).
- `create_order` cannot execute unless `conversations.confirm_state = true` (`CONFIRM_REQUIRED` when violated).
- Webhook processing requires valid signature checks before side effects.
- Authorization and scoping errors map to canonical error codes only.

## Failure Modes
- **Missing/invalid dashboard credentials**
  - Codes: `AUTH_REQUIRED`, `AUTH_INVALID`.
  - Mitigation: reject before business operation, return canonical error payload.

- **Authenticated principal accessing wrong tenant scope**
  - Code: `FORBIDDEN`.
  - Mitigation: enforce owner/tenant context checks at service layer + rely on RLS boundary.

- **Tenant/resource scoping mismatch**
  - Codes: `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`, `PRODUCT_NOT_FOUND`, `ORDER_NOT_FOUND`, `DOCUMENT_NOT_FOUND`, `VARIANT_NOT_FOUND`.
  - Mitigation: strict tenant-filtered queries and canonical not-found handling.

- **Unauthorized or invalid tool invocation**
  - Codes: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`.
  - Mitigation: validate tool membership in `agents.tools_enabled` and request against canonical schemas.

- **Guarded write operation failure in scoped context**
  - Codes: `CONFIRM_REQUIRED`, `DUPLICATE_ORDER`, `CART_EMPTY`, `OUT_OF_STOCK`, `INVALID_QUANTITY`, `CART_FULL`.
  - Mitigation: enforce preconditions before persistence and preserve idempotency semantics.

- **Webhook auth boundary failures**
  - Codes: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`.
  - Mitigation: reject invalid signatures; short-circuit duplicates with canonical behavior.

- **Runtime/system failures impacting authz path**
  - Codes: `RATE_LIMITED`, `INTERNAL_ERROR`.
  - Mitigation: apply canonical rate limits and audit/monitor failures.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` were provided as inputs but are not present in this environment; confirm if markdown source exports are required for generation runs.
- TODO: Canonical RLS file states policy intent but not full per-table SQL policy clauses; confirm authoritative location for exact `USING`/`WITH CHECK` policy definitions.
- TODO: Canonical docs define owner-level tenant access; if multi-user tenant access is expected post-MVP, identify non-canonical owner document and timing (outside this MVP model).

## Change Log
- 2026-02-21 — Codex: Initial multi-tenancy, identity, and authorization model generated from canonical template and canonical source files.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
