# 17 Evaluation & QA Framework
Spec Version: 1.0.0 — Generated against canonical SPEC_VERSION

## Purpose
This document defines the MVP Evaluation & QA Framework for Aidy, grounded in canonical architecture, schema, tools, state machine, and error contracts. It provides implementation-grade guidance for offline evaluation, online monitoring, regression testing, quality gates, and release criteria for engineering, QA, and operations teams.

## Scope
In scope:
- Evaluation of model/tool orchestration quality within canonical routing and guardrail constraints.
- Offline and online quality validation using canonical signals from tables, interfaces, and errors.
- Regression testing for schema/tool/state/error drift and critical commerce/conversation paths.
- Pre-release and post-release quality gates compatible with modular monolith deployment.
- Release criteria tied to canonical invariants and failure handling.

Out of scope:
- Introducing non-canonical ML evaluation platforms or custom orchestration frameworks.
- Defining formal benchmark datasets or metrics not represented by canonical artifacts.
- Defining non-canonical CI/CD products or deployment pipelines.

Canonical boundaries this document cannot override:
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/state_machine.md`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`
- `docs/checks/consistency_checklist.md`
- `docs/checks/drift_rules.md`

## Non-Goals
- Defining new tools, states, enums, endpoints, or error codes for QA purposes.
- Defining autonomous retraining/evaluation loops outside canonical runtime architecture.
- Replacing canonical drift checks with custom non-canonical compliance rules.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/state_machine.md`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`
- `docs/canonical/env_vars.md`
- `docs/checks/consistency_checklist.md`
- `docs/checks/drift_rules.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `messages` (response quality proxies: `latency_ms`, `model_used`, `tokens_in`, `tokens_out`, tool metadata)
- `conversations` (status/mode/cart progression validation and handoff behavior)
- `audit_log` (tool/action traceability for QA replay and incident diagnosis)
- `orders` and `order_items` (commerce flow correctness and idempotency outcomes)
- `products` and `product_variants` (search/filter/stock correctness in tool flows)
- `tenants` (tenant-scoped budget and isolation context)
- `channel_connections` and `ecommerce_connections` (integration-path validation)

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
- Core quality/routing/runtime signals: `MODEL_ERROR`, `RATE_LIMITED`, `INTERNAL_ERROR`, `BUDGET_EXCEEDED`
- Contract and workflow checks: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `CONFIRM_REQUIRED`, `DUPLICATE_ORDER`
- Data/resource correctness checks: `PRODUCT_NOT_FOUND`, `ORDER_NOT_FOUND`, `VARIANT_NOT_FOUND`, `DOCUMENT_NOT_FOUND`
- Access and boundary checks: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
- Channel integrity checks: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`

## Design

### Offline evaluation
Offline evaluation validates deterministic and replayable behavior against canonical artifacts:
- Run doc-level drift validation using canonical checklist/rules before implementation sign-off.
- Execute fixture-based conversation replays that cover canonical mode/status/cart transitions.
- Validate tool-call payloads against canonical tool schemas and allowlist constraints.
- Verify commerce preconditions (`confirm_state`, idempotency key behavior, stock/quantity constraints).
- Confirm tenant isolation behavior in read/write scenarios using tenant-scoped test fixtures.

Offline evaluation outputs are pass/fail against canonical contracts, not free-form quality scoring.

### Online monitoring
Online monitoring uses canonical runtime signals already available in system records:
- Track error-rate and error-code distribution by tenant and interface.
- Track message latency, token usage, model usage, and tool-call outcomes.
- Monitor transition correctness (unexpected state/mode/cart patterns).
- Monitor webhook integrity failures and duplicate suppression behavior.
- Monitor budget pressure (`BUDGET_EXCEEDED`) as a quality-of-service limiter.

Sentry and DB traces (`messages`, `audit_log`) are the canonical observability base for QA operations.

### Regression test strategy
Regression coverage prioritizes canonical contract stability:
- **Schema regression**: ensure table/column/constraint references remain canonical.
- **Tool regression**: ensure tool names/args/guards remain canonical and validation fails correctly.
- **State regression**: ensure transitions exactly match canonical state machine rules.
- **Error regression**: ensure failure paths emit canonical error codes only.
- **Routing regression**: ensure direct FastAPI orchestration and deterministic-tool boundaries remain intact.

Regression tests must include negative-path assertions (e.g., disallowed tool, missing confirmation, duplicate order).

### Quality gates
Quality gates before release:
1. Drift checks pass for schema/tool/state/error/architecture constraints.
2. Core path regressions pass:
   - customer message ingestion,
   - product discovery + stock check,
   - cart update + total calculation,
   - explicit confirmation + order creation,
   - human escalation and release loop.
3. No unresolved critical-severity runtime failures (`INTERNAL_ERROR` spikes, sustained `MODEL_ERROR` storms) in candidate validation window.
4. Tenant isolation checks pass with no cross-tenant data exposure evidence.

### Release criteria
A release is considered QA-acceptable only if:
- Canonical drift status is PASS across schema/tools/state/errors/architecture.
- Critical workflow regressions pass in both positive and negative paths.
- Monitoring baseline is stable relative to prior accepted release (within agreed operational envelope).
- Open canonical ambiguities that affect correctness are tracked and explicitly accepted by owners.

Canonical artifacts do not define numeric SLO/error thresholds; threshold ownership remains an open question.

## Interfaces
Interfaces under QA evaluation scope:
- Canonical tool invocation interfaces for all listed tools.
- Drift-check interfaces and sources:
  - `docs/checks/consistency_checklist.md`
  - `docs/checks/drift_rules.md`

Authentication/authorization assumptions:
- Protected interfaces require valid JWT and tenant scoping.
- QA verification must include RLS-boundary checks and forbidden-access paths.

## Invariants
- QA contracts are canonical-first; no non-canonical acceptance criteria can override canonical facts.
- Every release candidate must pass drift checks for schema, tools, state machine, and errors.
- Tool contract validation and allowlist checks remain mandatory in all test suites.
- State/mode/cart transitions must remain exactly canonical in both live and replay tests.
- Tenant isolation verification is mandatory for all integration and regression suites.
- Incident and regression diagnosis must remain traceable through canonical logs/tables.

## Failure Modes
- **Schema/tool/state/error drift introduced by changes**
  - Errors/signals: failed drift checks; canonical mismatch findings.
  - Detection: automated checklist/rule validation failures.
  - Mitigation: block release, reconcile docs/implementation with canonical sources.

- **Model/runtime instability during candidate validation**
  - Errors: `MODEL_ERROR`, `INTERNAL_ERROR`, `RATE_LIMITED`
  - Detection: elevated runtime error rates and latency degradation.
  - Mitigation: pause promotion, investigate provider/traffic conditions, rerun validation.

- **Workflow integrity regression in commerce/conversation paths**
  - Errors: `CONFIRM_REQUIRED`, `DUPLICATE_ORDER`, `TOOL_VALIDATION_FAILED`, `TOOL_NOT_ALLOWED`
  - Detection: failing regression cases for confirmation/idempotency/tool-guard scenarios.
  - Mitigation: block release and restore canonical guards.

- **Access-control or tenant-isolation regression**
  - Errors: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
  - Detection: failed auth/boundary tests or cross-tenant data assertions.
  - Mitigation: halt release, fix auth/RLS enforcement, rerun isolation suite.

- **Channel integrity regression**
  - Errors: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`
  - Detection: webhook signature-verification failures or duplicate-processing misbehavior.
  - Mitigation: restore signature/duplication controls and revalidate webhook path.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are specified inputs but unavailable in this environment; confirm source export path.
- TODO: Canonical artifacts do not define numeric quality thresholds (latency/error-rate/SLO) for promotion gates; confirm owners and target values.
- TODO: Canonical artifacts do not define a mandatory regression test matrix (minimum fixture set by channel/language/tool path); confirm baseline.
- TODO: Canonical artifacts do not define release-window policy for acceptable `MODEL_ERROR`/`RATE_LIMITED` variance; confirm operational criteria.
- TODO: Canonical artifacts do not specify long-term retention windows for QA evidence and test artifacts; confirm policy.

## Change Log
- 2026-02-21 — Codex: Initial Evaluation & QA Framework specification generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
