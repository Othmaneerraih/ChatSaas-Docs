# 16 Model Layer & Deployment Strategy

## Purpose
This document defines the MVP model-layer and deployment strategy for Aidy using canonical constraints only. It provides implementation-grade guidance for model role assignment, routing behavior, deployment topology, fallback handling, scaling controls, and cost/performance tradeoffs for engineering, QA, and operations.

## Scope
In scope:
- Canonical model role usage across chat, reasoning, vision, embedding, and STT fields.
- Runtime routing behavior for model/tool execution in the modular monolith architecture.
- Deployment topology for model-integrated services using canonical hosting decisions.
- Fallback and degradation behavior for model-provider failures.
- Scaling and cost/performance controls that remain inside canonical platform and error constraints.

Out of scope:
- Introducing non-canonical orchestration frameworks (e.g., LangChain/LangGraph for MVP).
- Defining self-hosted model serving, custom inference clusters, or multi-region HA topologies.
- Defining provider-specific SLAs, price tables, or orchestration layers not in canonical artifacts.

Canonical boundaries this document cannot override:
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/state_machine.md`
- `docs/canonical/errors.md`
- `docs/canonical/env_vars.md`
- `docs/canonical/rls.md`

## Non-Goals
- Defining post-MVP model governance workflows not present in canonical references.
- Defining non-canonical prompt-management systems or model registry products.
- Defining autonomous model retraining/fine-tuning pipelines.

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
- `agents` (`models`, `tools_enabled`, `routing_rules`, `config_version`, `is_active`)
- `messages` (`model_used`, `tokens_in`, `tokens_out`, `latency_ms`, tool metadata)
- `conversations` (`status`, `mode`, `language_detected`, `cart_state`, `confirm_state`)
- `audit_log` (tool and action traceability for model-path decisions)
- `tenants` (`monthly_budget_mad`, `is_active`)
- `documents` and `document_chunks` (embedding/vector retrieval dependency for knowledge responses)

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
- Cart states affecting model/tool routing: `empty`, `has_items`, `summary_shown`, `confirmed`, `order_created`

### Error codes referenced (if any)
- Model/runtime path: `MODEL_ERROR`, `INTERNAL_ERROR`, `RATE_LIMITED`, `BUDGET_EXCEEDED`
- Tool guard path: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `CONFIRM_REQUIRED`, `DUPLICATE_ORDER`
- Access/scope path: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
- Channel/replay path: `WEBHOOK_DUPLICATE`, `WEBHOOK_SIGNATURE_INVALID`

## Design

### Model selection strategy
Model selection is canonical role-based and tenant-configurable via `agents.models`:
- **chat** role for primary conversational response generation.
- **reasoning** role for higher-complexity decision paths when routing rules require deeper reasoning.
- **vision** role for `analyze_image` tool workflows.
- **embedding** role for document chunk embedding and retrieval support.
- **stt** role for voice input processing when voice messages are in use.

No non-canonical model roles are introduced.

### Routing strategy
Routing follows canonical orchestration constraints:
- FastAPI service logic performs routing and guard checks directly (no LangChain/LangGraph in MVP).
- Router combines conversation context (`status`, `mode`, cart/confirmation state), `agents.routing_rules`, and tool availability (`tools_enabled`).
- Deterministic tool operations remain deterministic (`calculate_total`) and are not replaced by model inference.
- Guardrails enforce schema validation and tool allowlist before execution.

### Deployment topology
Canonical deployment topology for model layer:
- Single backend deployable (modular monolith) on Railway.
- Supabase PostgreSQL + RLS as persistent data and authorization boundary.
- Upstash Redis for session state, conversation locks, and rate limiting counters.
- External model providers accessed via configured API keys (Groq, DeepInfra, Google AI, OpenAI).
- Sentry for runtime monitoring and failure visibility.

No self-hosted model runtime, dedicated inference cluster, or cross-region orchestration is defined.

### Fallback strategies
Fallbacks must preserve canonical behavior:
- On model-provider error (`MODEL_ERROR`), stop unsafe execution and preserve conversation integrity.
- For unresolved or high-risk flows, use canonical `escalate_to_human` path and mode transition rules.
- Retries are bounded and must not bypass tool validation, confirmation, RLS, or budget constraints.
- Duplicate webhook deliveries are handled idempotently via canonical duplicate behavior.

### Scaling strategy
Scaling must stay within canonical platform constraints:
- Vertical and service-level optimization within the Railway-hosted monolith.
- Redis-backed locking and rate-limit counters prevent contention and uncontrolled concurrency.
- Tenant-scoped throttling returns `RATE_LIMITED` instead of allowing cross-tenant performance bleed.
- Workload pressure is monitored using message latency/token/model signals and error patterns.

Canonical artifacts do not define autoscaling policies or multi-region failover behavior.

### Cost/performance tradeoffs
Model-layer tradeoffs are handled by canonical signals and controls:
- Provider/model selection in `agents.models` determines capability vs. cost profile.
- Track consumption through `messages.tokens_in`, `messages.tokens_out`, and `model_used`.
- Respect tenant budget cap via `tenants.monthly_budget_mad` and `BUDGET_EXCEEDED` enforcement.
- Prefer deterministic tool paths where available to reduce unnecessary model-token usage.
- Keep fallback behavior predictable and safe rather than maximizing output at all costs.

## Interfaces
Core interfaces and dependencies impacted by model strategy:
- `POST /api/v1/webhooks/whatsapp/{tenant_id}`
- `POST /api/v1/webhooks/ecommerce/{tenant_id}`
- `WS /api/v1/ws/chat/{tenant_id}`
- `POST /api/v1/widget/messages`
- Canonical tool-call interface for all listed tools.
- Provider integrations via canonical environment variables:
  - `GROQ_API_KEY`, `DEEPINFRA_API_KEY`, `GOOGLE_AI_API_KEY`, `OPENAI_API_KEY`

Authentication/authorization assumptions:
- JWT and tenant scoping are mandatory for protected operations.
- Tool execution authorization is bound to `agents.tools_enabled` and canonical schema validation.

## Invariants
- Model orchestration remains direct FastAPI orchestration for MVP (no framework substitution).
- Tenant isolation via JWT + tenant_id + RLS is preserved across all model and tool paths.
- Deterministic tool behavior remains deterministic (`calculate_total`) and cannot be delegated to LLM inference.
- Confirmation/idempotency guards (`confirm_state`, `idempotency_key`) are mandatory before order creation.
- Canonical error vocabulary and state/mode transitions remain unchanged under fallback or failure.
- Budget controls (`monthly_budget_mad`, `BUDGET_EXCEEDED`) remain tenant-scoped and enforced.

## Failure Modes
- **Model provider timeout/unavailability**
  - Errors: `MODEL_ERROR`, `INTERNAL_ERROR`
  - Detection: elevated provider failure/timeout and 5xx patterns.
  - Mitigation: bounded retry, preserve conversation state, route to human escalation when required.

- **Excessive request pressure**
  - Error: `RATE_LIMITED`
  - Detection: high 429 rates and lock contention metrics.
  - Mitigation: tenant-scoped throttling, contention control, and safe rejection.

- **Budget cap reached during model-heavy flows**
  - Error: `BUDGET_EXCEEDED`
  - Detection: budget-threshold breaches per tenant.
  - Mitigation: block budgeted model path and return canonical error without cross-tenant impact.

- **Tool routing/guard violations**
  - Errors: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `CONFIRM_REQUIRED`, `DUPLICATE_ORDER`
  - Detection: increase in tool guard failures or duplicate-order conflicts.
  - Mitigation: reject invalid calls, enforce preconditions, keep state machine integrity.

- **Auth/scope mismatch on model-triggering interfaces**
  - Errors: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
  - Detection: spikes in 401/403/404 on protected interfaces.
  - Mitigation: deny access, verify JWT and tenant mapping, preserve isolation boundaries.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are specified inputs but unavailable in this environment; confirm source export path.
- TODO: Canonical artifacts define role keys in `agents.models` but do not define mandatory fallback ordering between providers per role; confirm policy.
- TODO: Canonical artifacts do not define numeric routing thresholds for switching between chat and reasoning models; confirm heuristic governance.
- TODO: Canonical artifacts do not define autoscaling/load-shedding envelopes for Railway deployment tiers; confirm operations baseline.
- TODO: Canonical artifacts define budget and token signals but do not define canonical per-model pricing schedule for runtime tradeoff automation; confirm source of truth.

## Change Log
- 2026-02-21 — Codex: Initial Model Layer & Deployment Strategy specification generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
