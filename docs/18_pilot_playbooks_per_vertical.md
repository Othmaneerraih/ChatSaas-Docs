# 18 Pilot Playbooks (Per Vertical)
Spec Version: 1.0.0 — Generated against canonical SPEC_VERSION

## Purpose
This document defines MVP pilot playbooks by business vertical for Aidy using canonical constraints only. It gives implementation-grade rollout guidance for onboarding, configuration presets, KPI tracking, risk controls, and success criteria while preserving canonical tool contracts, state transitions, and architecture limits.

## Scope
In scope:
- Pilot onboarding workflow reusable across tenant types.
- Vertical-specific configuration presets built from canonical agent/config/channel/schema capabilities.
- KPI model for pilot validation using canonical tables, tool outcomes, and error signals.
- Rollout risk controls and go/no-go criteria constrained to canonical behavior.
- Success criteria and exit criteria for pilot acceptance.

Out of scope:
- Introducing non-canonical vertical feature sets or custom domain modules.
- Defining new schemas, tools, states, payment methods, or channel behaviors per vertical.
- Defining non-canonical outbound campaign systems or unsupported WhatsApp flows.

Canonical boundaries this document cannot override:
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/tools.md`
- `docs/canonical/tools_schemas.json`
- `docs/canonical/state_machine.md`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`
- `docs/canonical/env_vars.md`
- `docs/canonical/glossary.md`

## Non-Goals
- Defining vertical-specific product logic that bypasses canonical tool contracts.
- Replacing shared-tenant/RLS model with dedicated per-vertical infrastructure.
- Defining pricing/billing plans by vertical beyond canonical budget primitives.

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
- `docs/canonical/glossary.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `tenants` (`plan`, `settings`, `monthly_budget_mad`, `is_active`)
- `agents` (`identity`, `models`, `tools_enabled`, `routing_rules`, `business_rules`, `config_version`, `is_active`)
- `customers` (tenant-scoped customer identity + metadata)
- `conversations` (`channel`, `status`, `mode`, `cart_state`, `confirm_state`, `language_detected`)
- `messages` (`role`, `message_type`, tool/model/token/latency fields)
- `products` and `product_variants` (catalog + stock for commerce pilots)
- `orders` and `order_items` (order conversion and checkout correctness)
- `audit_log` (action traceability for onboarding, tool usage, and handoff events)
- `channel_connections` and `ecommerce_connections` (integration activation and sync status)

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
- Onboarding/auth/boundary: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`
- Data/config readiness: `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`, `DOCUMENT_NOT_FOUND`, `SYNC_IN_PROGRESS`
- Commerce/tool controls: `TOOL_NOT_ALLOWED`, `TOOL_VALIDATION_FAILED`, `CONFIRM_REQUIRED`, `CART_EMPTY`, `INVALID_QUANTITY`, `OUT_OF_STOCK`, `DUPLICATE_ORDER`
- Reliability/channel controls: `RATE_LIMITED`, `MODEL_ERROR`, `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `INTERNAL_ERROR`
- Budget control: `BUDGET_EXCEEDED`

## Design

### Shared pilot onboarding sequence (all verticals)
1. **Tenant activation**
   - Create/validate tenant and owner auth context.
   - Set baseline `tenants.settings`, `plan`, and `monthly_budget_mad`.
2. **Channel and commerce connection setup**
   - Configure BYOK WhatsApp/web widget and verify webhook path.
   - Configure ecommerce connector where applicable and validate sync health.
3. **Agent baseline configuration**
   - Populate `agents.identity`, `models`, `tools_enabled`, and baseline `routing_rules`/`business_rules`.
   - Increment `config_version` on each change.
4. **Catalog and tool readiness checks**
   - Validate product and variant availability for tool flows.
   - Validate deterministic commerce paths (`calculate_total`, confirm gate before `create_order`).
5. **Pilot acceptance smoke run**
   - Execute scripted conversations that cover browse, cart, order, and escalation paths.
   - Confirm audit traceability and canonical error behavior.

### Vertical presets
Vertical playbooks are preset bundles over canonical fields only; they do not introduce new features.

#### Apparel & footwear pilot
- **Onboarding focus**: variant-heavy catalog quality (`size`, `color`, stock completeness) and language/tone setup for customer-facing agent persona.
- **Configuration preset**:
  - Emphasize `search_products` + `check_stock` + cart tools.
  - Routing favors fast path for simple browse intents and escalation for ambiguous size/fit disputes.
- **KPIs**:
  - Search-to-cart conversion rate.
  - Variant mismatch rate (`VARIANT_NOT_FOUND`, `OUT_OF_STOCK`).
  - Confirmed-cart to order conversion and duplicate-order suppression quality.
- **Rollout risks**:
  - Incomplete variant mapping leads to stock errors and abandoned conversations.
  - High browse volume increases `RATE_LIMITED` risk.
- **Success criteria**:
  - Stable browse and cart flow with low validation errors.
  - Predictable escalation handling for edge sizing cases.

#### Beauty & personal care pilot
- **Onboarding focus**: clear product descriptions, ingredient/care guidance in catalog/docs, and image-assisted query handling where relevant.
- **Configuration preset**:
  - Enable `analyze_image` for visual product-identification support when customer sends images.
  - Keep order flow identical to canonical commerce sequence.
- **KPIs**:
  - Resolution rate without manual takeover.
  - Image-tool usefulness proxy via successful follow-up actions (search/cart progress after `analyze_image`).
  - Tool-validation failure rate.
- **Rollout risks**:
  - Media quality or URL problems reduce vision-path utility.
  - Overuse of model-heavy paths may pressure budget controls.
- **Success criteria**:
  - Consistent transition from visual inquiry to valid product/cart actions.
  - Budget and latency remain within agreed pilot envelope.

#### Electronics & accessories pilot
- **Onboarding focus**: spec-rich catalog quality, stock reliability, and clear checkout confirmation messaging.
- **Configuration preset**:
  - Prioritize structured retrieval + stock checks before recommendations.
  - Tight guardrail enforcement for order creation (confirmation/idempotency).
- **KPIs**:
  - Stock-check accuracy proxy (`OUT_OF_STOCK` and post-order correction incidents).
  - Checkout completion rate after `calculate_total`.
  - Escalation frequency for complex compatibility questions.
- **Rollout risks**:
  - Frequent stock changes increase stale-response risk.
  - High support complexity may increase manual takeover load.
- **Success criteria**:
  - Low order-creation guard failures.
  - Stable human handoff loop with valid state/mode transitions.

### KPI framework
Pilot KPI calculations must use canonical telemetry/data only:
- Conversation funnel: status/mode transitions in `conversations`.
- Tool quality: tool-call success/failure patterns from `messages` + `audit_log`.
- Commerce quality: cart-to-order outcomes and idempotency behavior in `orders`/`order_items`.
- Reliability quality: canonical error-code distribution and latency signals.
- Cost governance: budget pressure and token/model usage signals.

No non-canonical analytics schema is defined.

### Rollout risk controls
- Use tenant-scoped phased rollout (small pilot tenant cohort before broader expansion).
- Keep escalation path available (`escalate_to_human`) for unresolved/unsafe scenarios.
- Block promotion when drift checks or critical guardrails fail.
- Use canonical duplicate and signature controls on inbound channels.
- Do not disable RLS/auth constraints to accelerate pilots.

### Success and exit criteria
Pilot is successful when:
- Core canonical flows pass for target vertical presets (browse, cart, confirm, order, handoff).
- Error profile is stable (no sustained critical runtime failures).
- Tenant isolation and policy guardrails hold in live traffic.
- Business acceptance criteria (agreed KPI targets) are met for the pilot window.

Pilot exits (rollback or reconfiguration) when:
- Critical guardrail errors recur and cannot be mitigated quickly.
- Budget or reliability constraints materially degrade service quality.
- State/tool drift is detected against canonical contracts.

## Interfaces
Operational interfaces used in pilot execution:
- Canonical tool-call interfaces for all listed tools.

Auth/authorization assumptions:
- Pilot operators act under valid tenant-scoped auth.
- RLS and route/service authorization checks remain mandatory for all pilot traffic.

## Invariants
- Vertical presets are configuration-only overlays on canonical schema/tools/states/errors.
- All pilots remain tenant-scoped with JWT + RLS isolation.
- `create_order` always requires explicit confirmation and idempotency controls.
- Manual takeover/handoff behavior follows canonical mode transitions (including disallowed transitions).
- Error responses remain limited to canonical error registry.
- BYOK/inbound-only WhatsApp constraints remain unchanged during pilots.

## Failure Modes
- **Onboarding/auth misconfiguration**
  - Errors: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`
  - Detection: setup workflow failures and unauthorized access events.
  - Mitigation: correct tenant ownership/auth configuration and rerun onboarding checklist.

- **Catalog/connectivity readiness failure**
  - Errors: `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`, `SYNC_IN_PROGRESS`
  - Detection: sync failures and elevated catalog lookup errors.
  - Mitigation: pause pilot expansion, repair sync/catalog integrity, validate before resume.

- **Commerce guardrail violation**
  - Errors: `CONFIRM_REQUIRED`, `CART_EMPTY`, `INVALID_QUANTITY`, `OUT_OF_STOCK`, `DUPLICATE_ORDER`, `TOOL_VALIDATION_FAILED`
  - Detection: failing checkout/order path checks and guardrail error spikes.
  - Mitigation: block invalid operations, reinforce confirmation/idempotency gates.

- **Channel integrity or abuse events**
  - Errors: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`, `RATE_LIMITED`
  - Detection: signature failures, duplicate volume spikes, throttling events.
  - Mitigation: verify webhook credentials/dedup logic and enforce throttling controls.

- **Runtime/cost degradation**
  - Errors: `MODEL_ERROR`, `BUDGET_EXCEEDED`, `INTERNAL_ERROR`
  - Detection: provider failures, budget breaches, runtime incident spikes.
  - Mitigation: fail safely, escalate to human when needed, adjust pilot volume/configuration.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are specified inputs but unavailable in this environment; confirm source export path.
- TODO: Canonical artifacts do not define official vertical taxonomy or preset templates; confirm approved vertical list and naming convention.
- TODO: Canonical artifacts do not define KPI target thresholds per pilot stage; confirm owner-defined success thresholds.
- TODO: Canonical artifacts do not define standard pilot duration/ramp schedule per vertical; confirm rollout cadence policy.
- TODO: Canonical artifacts do not define formal rollback SLO trigger thresholds for pilot suspension; confirm incident policy.

## Change Log
- 2026-02-21 — Codex: Initial Pilot Playbooks (Per Vertical) specification generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
