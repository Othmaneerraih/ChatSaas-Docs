# Appendix B: Error Codes Runbooks

## Purpose
This appendix provides operational runbooks for every canonical error code in Aidy MVP. It is intended for engineering, QA, and operations teams to support fast detection, triage, mitigation, and escalation while preserving canonical error semantics.

## Scope
In scope:
- Canonical error codes listed verbatim from the canonical registry.
- Operational runbooks per code: detection, triage, mitigation, escalation.
- Error handling alignment with canonical architecture, auth, RLS, tool contracts, and channel constraints.

Out of scope:
- Defining new error codes or changing canonical error meanings.
- Redefining HTTP semantics outside canonical error registry.
- Defining non-canonical incident platforms or paging stacks.

Canonical boundaries this document cannot override:
- `docs/canonical/errors.md`
- `docs/canonical/locked_decisions.md`
- `docs/canonical/rls.md`
- `docs/canonical/schema.md`

## Non-Goals
- Creating alternative error vocabularies for specific channels/tenants.
- Introducing non-canonical error payload structures.
- Replacing canonical auth, tool, or state guardrails with operational workarounds.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/errors.md`
- `docs/canonical/locked_decisions.md`
- `docs/canonical/rls.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md`
- `docs/canonical/state_machine.md`
- `docs/templates/doc_template.md`

### Error codes referenced
- `AUTH_REQUIRED`
- `AUTH_INVALID`
- `FORBIDDEN`
- `TENANT_NOT_FOUND`
- `CONVERSATION_NOT_FOUND`
- `PRODUCT_NOT_FOUND`
- `ORDER_NOT_FOUND`
- `DOCUMENT_NOT_FOUND`
- `VARIANT_NOT_FOUND`
- `DUPLICATE_ORDER`
- `CART_EMPTY`
- `CONFIRM_REQUIRED`
- `OUT_OF_STOCK`
- `INVALID_QUANTITY`
- `CART_FULL`
- `TOOL_NOT_ALLOWED`
- `TOOL_VALIDATION_FAILED`
- `RATE_LIMITED`
- `WEBHOOK_SIGNATURE_INVALID`
- `WEBHOOK_DUPLICATE`
- `MODEL_ERROR`
- `SYNC_IN_PROGRESS`
- `BUDGET_EXCEEDED`
- `INTERNAL_ERROR`

## Design

### Canonical error registry (verbatim)
The following codes and semantics are canonical and must not be changed:

| Code | HTTP | Message | When |
| --- | --- | --- | --- |
| AUTH_REQUIRED | 401 | Authentication required | No JWT or expired JWT |
| AUTH_INVALID | 401 | Invalid credentials | Wrong password or token |
| FORBIDDEN | 403 | Access denied | User not owner of this tenant |
| TENANT_NOT_FOUND | 404 | Tenant not found | Invalid tenant_id or slug |
| CONVERSATION_NOT_FOUND | 404 | Conversation not found | Invalid conversation_id or wrong tenant |
| PRODUCT_NOT_FOUND | 404 | Product not found | Invalid product_id or not in tenant catalog |
| ORDER_NOT_FOUND | 404 | Order not found | Invalid order_id or wrong tenant/customer |
| DOCUMENT_NOT_FOUND | 404 | Document not found |  |
| VARIANT_NOT_FOUND | 404 | Product variant not found |  |
| DUPLICATE_ORDER | 409 | Order already exists | Idempotency key already used |
| CART_EMPTY | 422 | Cart is empty | Attempted create_order with empty cart |
| CONFIRM_REQUIRED | 422 | Customer confirmation required | create_order called without confirm_state = true |
| OUT_OF_STOCK | 422 | Product is out of stock | add_to_cart for product with stock = 0 |
| INVALID_QUANTITY | 422 | Invalid quantity | qty < 1 or qty > 99 |
| CART_FULL | 422 | Cart limit reached | More than 50 items |
| TOOL_NOT_ALLOWED | 403 | Tool not enabled for this agent | Agent called a tool not in tools_enabled |
| TOOL_VALIDATION_FAILED | 422 | Invalid tool arguments | Tool args don’t match JSON schema |
| RATE_LIMITED | 429 | Too many requests | Per-tenant or per-user rate limit exceeded |
| WEBHOOK_SIGNATURE_INVALID | 401 | Invalid webhook signature | Meta HMAC verification failed |
| WEBHOOK_DUPLICATE | 200 | Message already processed | Duplicate channel_message_id (returns 200 to prevent retry) |
| MODEL_ERROR | 502 | AI model unavailable | LLM API returned error or timeout |
| SYNC_IN_PROGRESS | 409 | Product sync already running | Concurrent sync attempt |
| BUDGET_EXCEEDED | 402 | Monthly budget exceeded | Tenant’s monthly_budget_mad reached |
| INTERNAL_ERROR | 500 | Internal server error | Unexpected error. Logged in Sentry. |

### Operational runbooks by error code

| Code | Detection | Triage | Mitigation | Escalation |
| --- | --- | --- | --- | --- |
| AUTH_REQUIRED | Monitor 401 spikes with missing/expired JWT patterns. | Confirm token absence/expiry and affected interface/channel. | Return canonical 401; prompt re-authentication path; do not allow fallback bypass. | Escalate to auth owner if widespread or sudden baseline shift. |
| AUTH_INVALID | Monitor repeated invalid credential/token events. | Verify credential source, token signature, and issuer mismatch. | Reject request; rotate/reissue credentials where applicable. | Escalate to security owner for suspected abuse or key leakage. |
| FORBIDDEN | Track 403 rate by tenant/resource. | Validate ownership mapping and tenant scope in request context. | Deny access; preserve RLS/service checks; audit offending actor/context. | Escalate if cross-tenant access attempts increase materially. |
| TENANT_NOT_FOUND | Alert on 404 tenant lookup failures. | Check tenant_id/slug integrity and route parameter mapping. | Reject request and correct caller configuration/reference data. | Escalate to onboarding/platform owner if many tenants affected. |
| CONVERSATION_NOT_FOUND | Monitor missing conversation lookups by tenant/channel. | Validate conversation_id and tenant correlation. | Return canonical 404; prevent writes to non-existent conversation. | Escalate to messaging owner if systemic lookup failures appear. |
| PRODUCT_NOT_FOUND | Monitor product lookup failures in tool paths. | Verify product sync status and tenant catalog integrity. | Return 404; refresh/sync catalog references before retry. | Escalate to commerce integration owner if persistent. |
| ORDER_NOT_FOUND | Monitor order status lookup failures. | Validate order_id ownership and customer/tenant scope. | Return 404 and block status mutation on invalid id. | Escalate to orders owner if data integrity anomaly suspected. |
| DOCUMENT_NOT_FOUND | Track missing document references in retrieval flows. | Validate document id, tenant scope, and document lifecycle status. | Return 404; re-index or correct reference origin. | Escalate to retrieval owner if broad indexing/reference drift occurs. |
| VARIANT_NOT_FOUND | Monitor variant resolution failures in stock/cart flows. | Verify variant existence and product-variant relationship. | Return 404; force caller to refresh current variant data. | Escalate to catalog owner if sync/variant mapping drift grows. |
| DUPLICATE_ORDER | Detect duplicate idempotency key conflicts (409). | Confirm request replay vs genuine duplicate submission. | Return canonical 409; keep single order record authoritative. | Escalate if duplicate rate indicates orchestrator/idempotency-key generation bug. |
| CART_EMPTY | Monitor create_order attempts on empty carts. | Validate cart_state before checkout invocation. | Return 422; require cart population before order creation. | Escalate to conversation/tooling owner if guard bypass repeats. |
| CONFIRM_REQUIRED | Track order attempts without confirm_state=true. | Inspect conversation confirmation flow and state transitions. | Return 422; prompt explicit customer confirmation first. | Escalate if confirmation step is skipped by orchestrator logic. |
| OUT_OF_STOCK | Monitor stock validation failures during add_to_cart. | Validate real-time variant/product stock values. | Return 422; request alternative quantity/variant/product. | Escalate if stock sync latency causes sustained mismatch. |
| INVALID_QUANTITY | Detect qty violations (<1 or >99). | Validate upstream UI/tool argument construction. | Return 422 and enforce canonical quantity bounds. | Escalate to client/integration owner if repeated malformed inputs. |
| CART_FULL | Monitor cart limit breaches (>50 items). | Check cart accumulation behavior and item dedup logic. | Return 422 and prevent additional item insertion. | Escalate if cart mutation path ignores configured cap. |
| TOOL_NOT_ALLOWED | Track tool allowlist denials by agent/tenant. | Verify `agents.tools_enabled` and requested tool mapping. | Return 403; block tool execution outside allowlist. | Escalate if agent config rollout introduced incorrect allowlists. |
| TOOL_VALIDATION_FAILED | Monitor schema-validation failures per tool. | Inspect tool args against canonical tool schema. | Return 422; fix caller payload generation/validation gates. | Escalate if schema contract drift suspected. |
| RATE_LIMITED | Monitor 429 rates by tenant/user/channel. | Identify burst source and lock/counter saturation patterns. | Enforce throttling; protect system and tenant fairness. | Escalate when sustained throttling impacts critical workflows. |
| WEBHOOK_SIGNATURE_INVALID | Alert on signature verification failures. | Validate webhook secret/token and signature algorithm path. | Reject payload with 401; never process unverified messages. | Escalate immediately for potential spoofing or credential mismatch. |
| WEBHOOK_DUPLICATE | Track duplicate channel_message_id events. | Confirm dedup key collision corresponds to replayed delivery. | Return canonical success semantics (200) and skip reprocessing. | Escalate if duplicate rate indicates upstream delivery instability. |
| MODEL_ERROR | Monitor provider/API timeout and failure rates. | Identify failing provider/model role and affected flows. | Return 502; apply bounded retries where safe; keep state integrity. | Escalate to on-call if error budget or critical path degraded. |
| SYNC_IN_PROGRESS | Detect concurrent sync conflict frequency. | Check active sync lock lifecycle and stuck-job indicators. | Return 409 for overlapping sync attempts; keep single sync owner. | Escalate if lock release/job completion path is faulty. |
| BUDGET_EXCEEDED | Monitor tenant budget cap hits (`monthly_budget_mad`). | Verify tenant spend accumulation context and budget settings. | Return 402; stop budgeted AI operations for affected tenant. | Escalate to tenant success/ops owner for budget policy action. |
| INTERNAL_ERROR | Monitor 500s and Sentry incident volume. | Triage stack traces, request context, and blast radius. | Return 500 safely; preserve data/tenant integrity; initiate fix. | Escalate immediately to incident commander/on-call engineering. |

## Interfaces
Operational interfaces for applying runbooks:
- API/tool responses using canonical error envelope.
- Monitoring interface through canonical Sentry usage and DB-backed traces.
- Audit and diagnostics interfaces via `audit_log`, `messages`, and related tenant-scoped records.

Authentication/authorization assumptions:
- Error diagnosis workflows respect JWT and tenant scoping.
- Access to logs/traces follows tenant and role boundaries.

## Invariants
- Error codes, HTTP mappings, and messages remain canonical and unchanged.
- Runbooks may extend operations, but not error semantics.
- Tenant isolation and RLS boundaries are never bypassed during mitigation.
- Tool/schema guards remain enforced even in incident conditions.
- Webhook signature and dedup controls remain mandatory.

## Failure Modes
- **Runbook drift from canonical semantics**
  - Detection: mismatch between runbook text and canonical error registry.
  - Mitigation: block update and reconcile with `docs/canonical/errors.md`.

- **Insufficient telemetry for triage**
  - Detection: repeated unresolved incidents with missing context.
  - Mitigation: improve instrumentation usage within canonical observability surfaces.

- **Escalation delays on critical errors**
  - Detection: prolonged `INTERNAL_ERROR`/`MODEL_ERROR` incident windows.
  - Mitigation: enforce escalation thresholds and on-call response expectations.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are specified inputs but unavailable in this environment; confirm source export path.
- TODO: Canonical artifacts do not define explicit severity tiers or paging timelines per error code; confirm incident-response policy source.
- TODO: Canonical artifacts do not define tenant-facing communication templates per error class; confirm support runbook ownership.
- TODO: Canonical artifacts do not define SLO-linked alert thresholds per error code; confirm operational threshold governance.

## Change Log
- 2026-02-21 — Codex: Initial Error Codes Runbooks appendix generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
