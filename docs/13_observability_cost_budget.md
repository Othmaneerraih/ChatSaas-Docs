# 13 Observability, Cost Accounting, and Budget Controls
Spec Version: 1.0.0 — Generated against canonical SPEC_VERSION

## Purpose
This document defines the canonical MVP observability and cost-control model for Aidy, including operational metrics/logging surfaces, tenant-scoped cost attribution signals, budget enforcement behavior, alerting boundaries, and reporting expectations. It is intended for backend engineers, QA, and operations teams responsible for runtime reliability and spend governance.

## Scope
In scope:
- Canonical logging and traceability surfaces from message/tool execution.
- Metrics signals available in canonical schema and platform decisions.
- Tenant-scoped cost attribution inputs and budget-cap enforcement.
- Canonical alert/error pathways for budget and runtime degradation.
- Reporting expectations based on canonical fields.

Out of scope:
- Introducing new billing primitives, invoices, or non-canonical charge models.
- Defining finance workflows beyond canonical spend cap behavior.
- Replacing canonical error or state semantics.

Canonical boundaries this document cannot override:
- `docs/canonical/schema.md`
- `docs/canonical/errors.md`
- `docs/canonical/locked_decisions.md`
- `docs/canonical/tools.md`
- `docs/canonical/rls.md`
- `docs/canonical/state_machine.md`

## Non-Goals
- Defining external accounting-system integrations.
- Defining non-canonical token-pricing tables.
- Defining post-MVP billing/subscription plans.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/schema.md`
- `docs/canonical/errors.md`
- `docs/canonical/locked_decisions.md`
- `docs/canonical/tools.md`
- `docs/canonical/rls.md`
- `docs/canonical/state_machine.md`
- `docs/canonical/env_vars.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `tenants` (`monthly_budget_mad` spend cap and tenant ownership boundary)
- `messages` (`model_used`, `tokens_in`, `tokens_out`, channel/message timeline)
- `audit_log` (append-only action/tool trace with actor attribution)
- `conversations` (operational context for workload and escalation/resolution outcomes)
- `agents` (configured model roles influencing provider usage patterns)
- `orders` (business outcomes that may be correlated with AI usage costs)

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
- Status states used for operational slicing: `active`, `escalated`, `resolved`, `abandoned`
- Mode states used for workload attribution: `ai`, `manual`, `ai_whisper`

### Error codes referenced (if any)
- Budget and throttling: `BUDGET_EXCEEDED`, `RATE_LIMITED`
- Runtime/provider failures: `MODEL_ERROR`, `INTERNAL_ERROR`
- Access/control context: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
- Background contention context: `SYNC_IN_PROGRESS`

## Design

### Metrics model
Canonical observable signals are derived from stored runtime facts:
- `messages.tokens_in` and `messages.tokens_out` for token-volume tracking.
- `messages.model_used` for provider/model distribution.
- Conversation lifecycle (`status`, `mode`) for workload composition and escalation volume.
- Tool usage traces in `audit_log` and message tool fields for execution-path frequency.

No additional non-canonical telemetry schema is defined here.

### Logging and traceability
- `audit_log` is the authoritative append-only operational log for significant actions (`tool_call`, `order_created`, `escalation`, `config_change`, etc.) with actor attribution (`agent`, `merchant`, `system`).
- Message-level traces (`messages`) provide request/response chronology, model usage, and token counters.
- Sentry is the canonical monitoring platform for error tracking/performance at runtime.

### Tracing boundaries
Canonical artifacts imply distributed tracing through existing app-level records rather than a separate tracing primitive:
- Correlate by `tenant_id`, `conversation_id`, `customer_id`, timestamps, and tool names.
- Use message + audit records as the canonical cross-step execution trace.
- Avoid introducing non-canonical trace IDs unless added to canonical schema.

### Cost attribution per tenant
Tenant-level cost attribution is constrained to canonical data points:
1. Scope all accounting by `tenant_id`.
2. Aggregate token volume from `messages.tokens_in` and `messages.tokens_out`.
3. Segment by `messages.model_used` and action/tool context from `audit_log`.
4. Compare inferred consumption trends against tenant spend cap (`tenants.monthly_budget_mad`).

Canonical docs do not define explicit per-token price tables or persisted monthly spend accumulator fields; those gaps are tracked in Open Questions.

### Budget enforcement
- Canonical budget control primitive is `tenants.monthly_budget_mad` with enforcement surfaced by `BUDGET_EXCEEDED`.
- When budget cap is reached, AI-cost-incurring operations must fail with canonical budget error behavior.
- Budget enforcement must remain tenant-scoped and cannot affect other tenants.

### Alerts
Canonical alert conditions are error-driven:
- `BUDGET_EXCEEDED` for spend-cap breach.
- `RATE_LIMITED` for traffic throttling.
- `MODEL_ERROR` / `INTERNAL_ERROR` for runtime/provider issues.

Alert delivery channel, thresholds, and escalation policy beyond these canonical events are not fully specified in canonical artifacts.

### Reporting
Canonical reporting outputs are derived from existing tables:
- Tenant-level usage summaries from message token fields and model distribution.
- Operational incident summaries from audit and canonical errors.
- Conversation-level reliability slices by status/mode transitions.

No separate canonical reporting schema is defined; reports are generated from existing canonical tables.

## Interfaces
Relevant operational interfaces and surfaces:
- Runtime message/channel interfaces:
- Tool interfaces producing cost and audit signals:
  - `search_products`, `check_stock`, `add_to_cart`, `remove_from_cart`, `calculate_total`, `create_order`, `get_order_status`, `analyze_image`, `escalate_to_human`
- Monitoring/config interfaces:
  - Sentry integration via canonical runtime setup
  - Environment/provider keys in `docs/canonical/env_vars.md`

## Invariants
- All observability and budget computations are tenant-scoped.
- Budget enforcement uses canonical spend-cap primitive (`monthly_budget_mad`) and canonical budget error (`BUDGET_EXCEEDED`).
- No non-canonical billing primitives or pricing objects are introduced.
- Audit and message records remain the authoritative trace of actions and model/token usage.
- Error and alert semantics remain canonical.

## Failure Modes
- **Budget cap reached**
  - Error: `BUDGET_EXCEEDED`
  - Mitigation: block budgeted AI execution path for that tenant and surface actionable error.

- **Traffic and provider stress**
  - Errors: `RATE_LIMITED`, `MODEL_ERROR`
  - Mitigation: fail safely, preserve state integrity, and alert operations.

- **Unexpected runtime failure**
  - Error: `INTERNAL_ERROR`
  - Mitigation: capture in Sentry, preserve tenant/state isolation, and follow incident workflow.

- **Auth/scope mismatch in reporting or controls**
  - Errors: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
  - Mitigation: deny cross-tenant access and prevent incorrect attribution.

- **Concurrent integration contention**
  - Error: `SYNC_IN_PROGRESS`
  - Mitigation: reject conflicting sync operation and preserve existing sync integrity.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are specified inputs but unavailable in this environment; confirm source-export workflow.
- TODO: Canonical artifacts provide `monthly_budget_mad` and `BUDGET_EXCEEDED` but do not define canonical persisted monthly spend accumulator/reset cadence; confirm source of truth.
- TODO: Canonical artifacts provide token/model fields but do not define canonical per-model price schedule for MAD attribution; confirm authoritative pricing governance.
- TODO: Canonical artifacts identify Sentry for monitoring but do not specify alert routing/escalation thresholds by severity; confirm operational policy source.

## Change Log
- 2026-02-21 — Codex: Initial Observability, Cost Accounting, and Budget Controls specification generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
