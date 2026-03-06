# 15 Security & Compliance
Spec Version: 1.0.0 — Generated against canonical SPEC_VERSION

## Purpose
This document defines the MVP Security & Compliance specification for Aidy using only canonical architecture, schema, RLS, error, and environment-variable artifacts. It is intended for backend engineers, security reviewers, QA, and operations teams responsible for protecting tenant data, enforcing access controls, handling incidents, and maintaining auditable security posture.

## Scope
In scope:
- Data protection controls implied by canonical schema, environment variables, and hosting model.
- Secrets management requirements for API keys, tokens, and encryption material.
- Tenant isolation guarantees across application, JWT, and Supabase RLS boundaries.
- Audit logging requirements for traceability and incident forensics.
- Security incident response expectations based on canonical monitoring and error surfaces.
- Compliance considerations that can be stated from canonical artifacts without inventing unsupported controls.

Out of scope:
- Defining non-canonical cryptographic standards, key-management products, or SIEM tooling.
- Defining formal legal certification claims (e.g., ISO/SOC/GDPR attestation) not present in canonical artifacts.
- Defining unsupported auth providers, access models, or data residency architecture.

Canonical boundaries this document cannot override:
- `docs/canonical/locked_decisions.md`
- `docs/canonical/rls.md`
- `docs/canonical/schema.md`
- `docs/canonical/errors.md`
- `docs/canonical/env_vars.md`
- `docs/canonical/state_machine.md`
- `docs/canonical/tools.md`

## Non-Goals
- Creating new security primitives outside canonical stack decisions.
- Replacing Supabase Auth + JWT + RLS with custom auth models.
- Defining outbound compliance obligations for channels beyond canonical BYOK/inbound constraints.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/locked_decisions.md`
- `docs/canonical/rls.md`
- `docs/canonical/schema.md`
- `docs/canonical/errors.md`
- `docs/canonical/env_vars.md`
- `docs/canonical/state_machine.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `tenants` (ownership boundary, activation status, budget guardrail)
- `customers` (tenant-scoped PII fields and uniqueness constraints)
- `conversations` (tenant-scoped lifecycle with channel metadata)
- `messages` (conversation content, tool call/result payloads, model/token metadata)
- `orders` and `order_items` (customer delivery/payment data and immutable order record path)
- `documents` and `document_chunks` (tenant-scoped knowledge content and vector data)
- `audit_log` (append-only security and operational trace)
- `channel_connections` (encrypted channel credentials and webhook verification material)
- `ecommerce_connections` (encrypted commerce connector credentials)

### Tools referenced (if any)
- `escalate_to_human` (security/operational takeover control)
- `create_order` (confirmation and idempotency gate protection)
- `get_order_status` (customer/tenant scope checks)
- `search_products`, `check_stock`, `add_to_cart`, `remove_from_cart`, `calculate_total`, `analyze_image` (tenant-bounded execution under tool allowlist and schema validation)

### States/modes referenced (if any)
- Status: `active`, `escalated`, `resolved`, `abandoned`
- Modes: `ai`, `manual`, `ai_whisper`
- Cart states: `empty`, `has_items`, `summary_shown`, `confirmed`, `order_created`

### Error codes referenced (if any)
- Auth/access/isolation: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
- Channel/webhook security: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`
- Tool and workflow enforcement: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `CONFIRM_REQUIRED`, `DUPLICATE_ORDER`
- Abuse and runtime protection: `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`

## Design

### Data protection model
Canonical data protection is enforced through layered controls:
1. **Tenant scoping at rest**: `tenant_id` present on tenant-scoped tables with RLS enforcement.
2. **Auth-bound access**: Supabase Auth JWT determines tenant ownership and service access boundary.
3. **Schema-level constraints**: uniqueness and check constraints reduce accidental data corruption and mixed-tenant collisions.
4. **Credential encryption fields**: channel/ecommerce tokens are stored in encrypted columns (`*_encrypted`) with `ENCRYPTION_KEY` configured in runtime environment.
5. **Operational logging**: security-relevant actions and tool usage are captured in append-only `audit_log`.

No non-canonical DLP, vault, or external key service is introduced.

### Secrets management
Secrets are managed through canonical environment-variable controls:
- All secrets are stored in Railway environment variables, never in code or client bundles.
- High-risk secrets include `SUPABASE_SERVICE_ROLE_KEY`, provider API keys, `JWT_SECRET`, and `ENCRYPTION_KEY`.
- Service-role and secret keys are backend-only and must not be exposed to web widget/frontend contexts.
- Channel and commerce credentials persisted in DB must remain encrypted-at-rest via canonical encrypted columns and runtime encryption key.

Canonical artifacts do not define key rotation cadence or secret-scanning workflow; these are captured in Open Questions.

### Tenant isolation guarantees
Tenant isolation follows canonical defense-in-depth:
- Shared database, mandatory `tenant_id` boundary, and Supabase RLS on tenant-scoped tables.
- Every query is filtered by JWT and tenant context.
- Ownership checks enforce that users operate only within their own tenant.
- Isolation must hold under retries, failures, and degraded runtime conditions.

RLS policy SQL details are not fully enumerated in canonical source; implementation must adhere to high-level RLS constraints without extending semantics.

### Access control and authorization
Authorization model uses canonical components only:
- Supabase Auth handles identity issuance and JWT validation.
- Application-layer route/service checks prevent cross-tenant and cross-resource access.
- Tool execution is constrained by `agents.tools_enabled` and validated against canonical tool schemas.
- Workflow-sensitive operations enforce explicit guards (`confirm_state` before `create_order`, idempotency keys for order creation).

### Audit logging and forensics
Audit traceability requirements:
- `audit_log` is append-only and records actor, action, tenant scope, optional conversation/customer IDs, and tool payloads.
- `messages` provide chronological record of conversation content, tool call/result exchanges, and model metadata.
- Security investigations correlate `audit_log` and `messages` by `tenant_id`, `conversation_id`, and timestamps.

### Incident response
Incident response relies on canonical monitoring/error surfaces:
- Sentry is the canonical error/performance monitoring system.
- Security-relevant failures are detected through canonical error codes and logs.
- Initial response priorities: contain scope to tenant boundary, preserve evidence (`audit_log`/`messages`), and restore service without bypassing RLS/auth controls.
- Webhook integrity incidents are handled with signature verification failures (`WEBHOOK_SIGNATURE_INVALID`) and duplicate suppression (`WEBHOOK_DUPLICATE`).

### Compliance considerations
Canonical artifacts support baseline compliance posture considerations but do not provide formal certification claims:
- Data minimization must be applied by limiting use of PII fields to documented operational needs.
- Access control evidence is available through auth and audit records.
- Incident evidence is preserved through append-only audit entries and monitored runtime errors.
- BYOK/inbound-only WhatsApp constraint limits unsupported outbound messaging exposure.

Any formal control mapping to external regulatory frameworks requires additional authoritative inputs.

## Interfaces
Security-critical interfaces and dependencies:
- Tool invocation surface for canonical tools listed above with schema and allowlist enforcement.

Authentication/authorization assumptions:
- JWT validation is mandatory for protected resources.
- Tenant scoping and RLS checks are mandatory at all times.
- Service-role credentials are restricted to backend trusted contexts.

## Invariants
- Tenant isolation (JWT + tenant_id + RLS) is never bypassed.
- Secrets never appear in source code or client bundles.
- Encrypted credential fields remain encrypted at rest and are only processed by backend services.
- Security-sensitive operations remain auditable via append-only logs.
- Tool execution cannot bypass allowlist (`tools_enabled`) or schema validation.
- Canonical error registry is the only externally visible security/error signaling contract.

## Failure Modes
- **Missing/invalid authentication context**
  - Errors: `AUTH_REQUIRED`, `AUTH_INVALID`
  - Detection: repeated 401 responses and failed auth traces.
  - Mitigation: reject requests, preserve no-access default.

- **Unauthorized cross-tenant/resource access attempt**
  - Errors: `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
  - Detection: access-denied spikes by tenant/resource.
  - Mitigation: deny operation, validate JWT/tenant mapping, confirm RLS path.

- **Webhook spoofing or replay**
  - Errors: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`
  - Detection: signature mismatch events, duplicate channel message IDs.
  - Mitigation: reject invalid signature, return duplicate-safe response for replayed events.

- **Tool misuse or unsafe invocation**
  - Errors: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `CONFIRM_REQUIRED`
  - Detection: elevated tool guard failures.
  - Mitigation: enforce allowlist/schema/confirmation gates and block unsafe execution.

- **Unexpected runtime compromise path / internal failure**
  - Errors: `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`
  - Detection: monitoring alerts and Sentry incident spikes.
  - Mitigation: contain blast radius to tenant scope, preserve evidence, apply canonical recovery runbook.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` were specified inputs but are unavailable in this environment; confirm source export path.
- TODO: Canonical artifacts define encrypted credential fields and `ENCRYPTION_KEY` but do not define key rotation cadence or re-encryption process; confirm policy.
- TODO: Canonical artifacts do not define secret-scanning, credential-leak detection, or repository pre-commit enforcement controls; confirm security SDLC baseline.
- TODO: Canonical artifacts define RLS high-level guarantees but do not enumerate per-table SQL policy clauses; confirm authoritative policy source and review process.
- TODO: Canonical artifacts do not define formal regulatory control mapping (e.g., GDPR/ISO/SOC) or data-retention/deletion schedules; confirm compliance ownership.

## Change Log
- 2026-02-21 — Codex: Initial Security & Compliance specification generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
