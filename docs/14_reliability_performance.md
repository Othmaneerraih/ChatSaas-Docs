# 14 Reliability & Performance Engineering

## Purpose
This document defines the MVP reliability and performance engineering approach for Aidy using only canonical architecture constraints and runtime primitives. It provides implementation-level guidance for backend, QA, and operations teams on how to measure, protect, and recover system behavior under load and failure while preserving tenant isolation and canonical workflow correctness.

## Scope
In scope:
- Reliability baselines and service-level indicators derived from canonical interfaces and data model.
- Performance capacity planning inputs based on canonical channels, tools, and state transitions.
- Backpressure, retry, rate-limiting, and caching strategy within canonical platform choices.
- Degradation and incident response behavior aligned with canonical error model.
- Chaos testing approach constrained to canonical architecture.

Out of scope:
- Introducing non-canonical HA topologies or multi-region patterns.
- Introducing new persistence systems, queues, or observability vendors beyond canonical decisions.
- Redefining tool contracts, state machine semantics, or error registry.

Canonical boundaries this document cannot override:
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/state_machine.md`
- `docs/canonical/errors.md`
- `docs/canonical/env_vars.md`

## Non-Goals
- Defining formal business SLO targets not explicitly present in canonical artifacts.
- Defining autoscaling or failover mechanisms not represented in canonical hosting model.
- Defining non-canonical retryable error codes or custom throttling schemas.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/state_machine.md`
- `docs/canonical/errors.md`
- `docs/canonical/env_vars.md`
- `docs/canonical/rls.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `conversations` (status/mode lifecycle and workload transitions)
- `messages` (request/response chronology, model usage, token signals)
- `audit_log` (operation traceability and incident reconstruction)
- `tenants` (tenant scope and budget cap boundary)
- `orders` and `order_items` (commerce critical path under load)
- `products` and `product_variants` (catalog reads and stock checks)
- `channel_connections` and `ecommerce_connections` (integration-path reliability)

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

### Error codes referenced (if any)
- Reliability/performance control: `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`, `SYNC_IN_PROGRESS`
- Workflow integrity under load: `TOOL_VALIDATION_FAILED`, `TOOL_NOT_ALLOWED`, `CONFIRM_REQUIRED`, `DUPLICATE_ORDER`
- Input/state pressure failures: `CART_FULL`, `INVALID_QUANTITY`, `OUT_OF_STOCK`, `CART_EMPTY`
- Boundary/auth context: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`

## Design

### SLIs/SLOs model
Canonical artifacts do not define numeric SLO thresholds. For MVP, reliability is measured with canonical, implementation-safe SLIs:
- Request success rate per interface (`2xx/4xx/5xx` distribution).
- Canonical error-code frequency (`RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`, etc.).
- Tool execution success/failure ratio per canonical tool.
- Conversation transition completion integrity (expected status/mode transitions without invalid edges).
- Commerce flow completion integrity (`add_to_cart` -> `calculate_total` -> confirmation -> `create_order`).

SLO target values are tracked as an open question unless defined in canonical source.

### Capacity planning
Capacity planning follows locked architecture decisions (modular monolith on Railway, Supabase, Upstash Redis):
- Plan capacity by tenant-scoped workload slices (`tenant_id`) and channel distribution.
- Use `messages` volume, tool invocation frequency, and `model_used` mix as primary demand indicators.
- Treat vision (`analyze_image`) and retrieval-heavy operations as higher-cost paths.
- Protect critical commerce path (`check_stock`, `calculate_total`, `create_order`) from starvation by applying bounded concurrency and prioritized execution order at service layer.

### Backpressure and concurrency control
Backpressure must preserve correctness first:
- Enforce per-tenant and per-user throttling with canonical `RATE_LIMITED` behavior.
- Use Upstash Redis locks/counters (canonical cache decision) for conversation-level contention control.
- Reject conflicting operations where canonical errors already exist (`SYNC_IN_PROGRESS`, `DUPLICATE_ORDER`).
- Preserve state-machine validity: no transition shortcuts to “recover performance.”

### Retries and idempotency
Retries are allowed only when they do not violate canonical invariants:
- Inbound webhook duplicate delivery is handled via canonical `WEBHOOK_DUPLICATE` behavior.
- Provider/model transient failures surface as `MODEL_ERROR`; retry policy must be bounded and stop before crossing budget or rate limits.
- Order creation relies on canonical idempotency key semantics; duplicate submission must return `DUPLICATE_ORDER`.
- No retry may bypass confirmation guard (`CONFIRM_REQUIRED`) or tool validation guard (`TOOL_VALIDATION_FAILED`).

### Rate limiting
Rate-limiting strategy is canonical-error-driven:
- Return `RATE_LIMITED` on threshold breach.
- Scope limits to tenant/user/conversation context as available in canonical auth and schema boundaries.
- Ensure limits do not create cross-tenant coupling.

Canonical artifacts do not define exact numeric limit values; those remain operational policy.

### Caching
Caching is constrained to canonical role of Upstash Redis:
- Cache ephemeral conversation/session context and lock tokens.
- Use cache for rate-limit counters and short-lived coordination primitives.
- Do not treat cache as source of truth for canonical records (orders, messages, products).
- On cache failure, degrade safely by preserving DB truth and returning canonical runtime errors where applicable.

### Degradation strategies
When dependencies degrade, reduce capability without violating canonical behavior:
- On model/provider degradation (`MODEL_ERROR`), preserve message persistence and allow escalation path (`escalate_to_human`) when policy permits.
- Under sustained throttling (`RATE_LIMITED`), prefer protective rejection over queue growth that risks tenant bleed-through.
- Maintain strict tenant isolation and RLS boundaries even in degraded mode.
- Never invent fallback workflows that alter canonical tool contracts or state transitions.

### Chaos testing
Chaos testing validates resilience of canonical flows, not new architecture:
- Inject transient model/provider failures and verify `MODEL_ERROR` handling.
- Inject Redis latency/failure and verify lock/rate-limit degradation behavior.
- Inject Supabase query slowdowns and verify timeout handling without cross-tenant leakage.
- Inject duplicate webhook deliveries and verify idempotent `WEBHOOK_DUPLICATE` outcome.
- Run tests across AI/manual takeover boundaries to ensure state/mode invariants remain intact.

## Interfaces
Primary interfaces under reliability governance:
- `POST /api/v1/webhooks/whatsapp/{tenant_id}`
- `POST /api/v1/webhooks/ecommerce/{tenant_id}`
- `WS /api/v1/ws/chat/{tenant_id}`
- `POST /api/v1/widget/messages`
- Tool invocation interface for canonical tools listed above.
- Data-plane dependencies: Supabase PostgreSQL/RLS, Upstash Redis, external model providers, Sentry.

Authentication/authorization assumptions:
- JWT and tenant scoping remain mandatory for protected paths.
- RLS and service-layer checks remain active under all load/degradation conditions.

## Invariants
- Tenant isolation is never relaxed for throughput reasons.
- Canonical state transitions and mode rules remain enforced under failure and retry conditions.
- Confirmation and idempotency gates remain mandatory in commerce flow.
- Canonical tool schemas remain authoritative; no “fast path” bypasses validation.
- Canonical error registry remains the only externally visible error vocabulary.
- Cache is optional optimization; persistent truth remains in canonical database tables.

## Failure Modes
- **Traffic surge / throttling**
  - Error: `RATE_LIMITED`
  - Detection: elevated 429 rate and Redis counter saturation.
  - Mitigation: enforce strict throttles, preserve per-tenant fairness, avoid unbounded queueing.

- **LLM/provider instability**
  - Error: `MODEL_ERROR`
  - Detection: rising provider failure/timeout rate.
  - Mitigation: bounded retries, fallback to canonical escalation path when appropriate.

- **Unexpected service exceptions**
  - Error: `INTERNAL_ERROR`
  - Detection: Sentry event spikes and elevated 500 rate.
  - Mitigation: isolate fault domain, preserve DB consistency, initiate incident response.

- **Concurrent sync/order conflicts**
  - Errors: `SYNC_IN_PROGRESS`, `DUPLICATE_ORDER`
  - Detection: repeated conflict responses and lock contention signals.
  - Mitigation: enforce lock discipline and idempotency-key semantics.

- **State/validation violations under pressure**
  - Errors: `TOOL_VALIDATION_FAILED`, `CONFIRM_REQUIRED`, `CART_FULL`, `INVALID_QUANTITY`, `OUT_OF_STOCK`, `CART_EMPTY`
  - Detection: spike in 422-class canonical errors by tool and state.
  - Mitigation: reject invalid operations; preserve canonical cart/order invariants.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` were specified inputs but are not available in this environment; confirm source export path.
- TODO: Canonical artifacts do not define numeric SLO targets (latency/error budget/availability); confirm authoritative thresholds.
- TODO: Canonical artifacts do not define explicit retry counts/backoff policy per dependency; confirm operational defaults.
- TODO: Canonical artifacts do not define fixed per-tenant/per-user rate-limit numbers; confirm policy table and ownership.
- TODO: Canonical artifacts lock hosting choices but do not specify formal load-test envelopes for Railway/Supabase tiers; confirm benchmark baseline.

## Change Log
- 2026-02-21 — Codex: Initial Reliability & Performance Engineering specification generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
