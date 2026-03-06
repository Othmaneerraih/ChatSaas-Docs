# Red Team Architecture Review
Spec Version: 1.0.0 — Generated against canonical SPEC_VERSION

## Purpose
This review stress-tests the current specification set from an adversarial systems-architecture perspective. It focuses on whether constraints are justified, where complexity is misplaced, and where operational/security assumptions are fragile.

## Scope reviewed
- `docs/canonical/*`
- `docs/00_*.md` through `docs/19_*.md`
- `docs/appendix_a_api_reference.md`
- `docs/appendix_b_error_codes_runbooks.md`
- `contracts/*`
- CI/spec lock controls in `.github/workflows/docs_ci.yml` and `scripts/*`

## Executive Findings
1. The spec is **highly constrained but unevenly concrete**: canonical schemas are specific, but API/interface contracts are intentionally incomplete. This creates implementation risk hidden behind strong governance language.
2. The architecture is **prematurely rigid in some places** (forced modular monolith, prohibited framework options, fixed hosting choices) while **under-specified in reliability/security operations** (incident process detail, secrets lifecycle, RLS SQL policy specifics).
3. The doc set assumes **MVP scale and traffic shape** without quantitative envelopes (burst rates, P95/P99 targets, token budget growth, operator capacity) but still defines assertive failure semantics.
4. Security posture leans on “RLS + JWT + BYOK” narratives but leaves blind spots in webhook replay hardening, data retention, key rotation, and audit integrity.
5. CI drift controls guard syntax/reference drift, but they can enforce consistency to an incomplete canonical set—i.e., “consistently wrong” remains possible.

---

## 1) Over-complexity hotspots

### 1.1 Documentation governance complexity exceeds implementation maturity
**Issue:**
The process scaffolding (canonical lock, spec versioning, multiple generated docs, CI drift checks, contract exports, delivery plans) is more mature than the runtime guarantees currently specified. This can create a false sense of production readiness.

**Risk:**
- Teams optimize for passing docs CI rather than proving runtime behavior.
- Change latency grows because every canonical edit implies broad regeneration without strong automation.

**Alternative:**
- Keep canonical core, but collapse downstream long-form docs into fewer “implementation binders” per subsystem.
- Add executable conformance tests (state transition matrix, tool schema tests, RLS policy tests) as first-class gate, not just doc drift checks.

**Tradeoff:**
- Less narrative granularity, more verifiable behavior.

### 1.2 Tooling layer may be over-abstracted for one-agent-per-tenant MVP
**Issue:**
A full tool lifecycle/validation/guardrail model plus contract compilation is valuable, but MVP appears to only need a narrow, deterministic commerce core.

**Risk:**
- Significant surface area for bugs in orchestration logic.
- Debug complexity when model outputs and tool validation conflict.

**Alternative:**
- Start with a strict finite “commerce intent engine” where only a subset of tools can execute per conversation phase.
- Defer broad generic tool runtime features until telemetry justifies expansion.

**Tradeoff:**
- Reduced flexibility short-term; increased reliability and easier incident triage.

---

## 2) Unjustified architectural constraints

### 2.1 “No LangChain/LangGraph” as a hard lock is not evidence-based
**Issue:**
The spec hard-codes a prohibition for MVP orchestration frameworks. That may be reasonable initially, but as a non-negotiable it is architectural dogma.

**Risk:**
- Prevents pragmatic reuse if complexity rises (e.g., multi-step retries, human handoff workflows, compensation).

**Alternative:**
- Replace prohibition with guardrail: “Framework use allowed only if it reduces incident rate or delivery time versus baseline.”
- Run an A/B implementation spike on one flow (e.g., escalation path).

**Tradeoff:**
- Slightly higher exploration cost; avoids lock-in to hand-rolled orchestration debt.

### 2.2 Hosting choices specified as canonical architecture
**Issue:**
Railway/Vercel/Upstash/Sentry are locked as choices, but these are deployment preferences, not architecture invariants.

**Risk:**
- Constrains enterprise/security deployments that need region control, private networking, or compliance-specific logging.

**Alternative:**
- Canonicalize capability requirements (container runtime, managed Postgres + vector, low-latency cache, tracing backend) and keep provider examples non-binding.

**Tradeoff:**
- Less prescriptive onboarding, better portability.

### 2.3 One-agent-per-tenant uniqueness may not map to real operations
**Issue:**
Hard uniqueness simplifies data model, but many support/commercial teams require specialized agents (sales/support/returns/language variants).

**Risk:**
- Forces brittle prompt overloading and hidden routing complexity in one agent config.

**Alternative:**
- Keep MVP uniqueness but explicitly design compatibility path for N agents per tenant (agent_type + routing map) without breaking schema.

**Tradeoff:**
- Slight schema planning effort now to avoid expensive migration later.

---

## 3) Missing failure modes

### 3.1 Data consistency and compensation gaps
Missing explicit handling for:
- partial failure: order record created but downstream notification fails;
- duplicate webhook with out-of-order events;
- stale product stock during concurrent cart/checkout actions;
- cross-system divergence (ecommerce sync vs local catalog snapshot).

**Alternative design:**
- Outbox pattern for external side effects.
- Versioned stock snapshot at order creation with post-commit reconciliation.
- Event ordering keys + replay-safe processors.

### 3.2 Operational failure modes under load are underspecified
Missing explicit failure handling for:
- Redis/cache unavailability;
- Supabase degraded latency or statement timeout bursts;
- model provider brownouts across multiple vendors simultaneously;
- long-tail queue backlogs causing message SLA breach.

**Alternative design:**
- Define circuit-breaker and queue-shedding policy with clear “degrade to manual” triggers.
- Add platform-wide backpressure states and customer-facing fallback messaging policy.

### 3.3 Human handoff race conditions
Missing explicit arbitration rules when:
- merchant takeover and AI response happen concurrently;
- multiple operators act on same conversation in shared inbox;
- manual actions conflict with pending tool side effects.

**Alternative design:**
- Conversation-level optimistic lock/version checks.
- Explicit “control lease” owner with TTL.

---

## 4) Unrealistic assumptions (scale, cost, LLM behavior)

### 4.1 Cost model likely optimistic
Assumption that open-weight API providers remain consistently cheap and available may not hold under burst, region constraints, or model churn.

**Alternative:**
- Define budget policy with two dimensions: hard tenant cap + global platform burn-rate governor.
- Add model fallback ladder with explicit quality/cost tiers and auto-disable rules.

### 4.2 LLM behavior reliability overestimated
Spec implies schema/tool guards can sufficiently control agent behavior. In practice, model tool-call quality drifts across prompts and providers.

**Alternative:**
- Add deterministic pre-tool intent classifier for high-risk actions.
- Require second-pass policy validator for order-creating intents.

### 4.3 Throughput and latency assumptions are non-quantitative
Without numeric targets, “works for MVP” can hide severe user experience degradation.

**Alternative:**
- Define minimum SLO envelope (example):
  - P95 first response latency,
  - P99 tool roundtrip,
  - max queue depth per tenant,
  - max retry window.

---

## 5) Security blind spots

### 5.1 RLS policy definitions remain conceptual, not executable
High-level RLS claims are present, but per-table SQL policy specifics are unresolved.

**Risk:**
- Policy drift or accidental permissiveness.

**Alternative:**
- Treat RLS SQL policy files as canonical artifacts and CI-verify against schema changes.

### 5.2 Webhook replay and key lifecycle gaps
Spec mentions signature validation and dedup but lacks:
- replay window strategy,
- nonce/timestamp skew enforcement,
- key rotation cadence and emergency revoke process.

**Alternative:**
- Add signed-timestamp replay gate and rotation runbook with measurable RTO.

### 5.3 Audit log tamper-resistance not defined
`audit_log` exists but no integrity guarantees (hash chain, append-only controls, privileged access audit).

**Alternative:**
- Add immutable audit export stream or cryptographic chaining for critical actions.

### 5.4 PII/retention/deletion policy weakly specified
Customer messages/orders imply PII, but retention windows and hard-delete workflows are not strongly specified.

**Alternative:**
- Canonical data lifecycle matrix by table: retention, redaction, delete authority, legal hold conditions.

---

## 6) CI and governance critique

### 6.1 Drift checks are lexical, not semantic
Current checks detect token-level drift but not behavioral contradictions (e.g., two docs can both use canonical tokens yet prescribe incompatible sequencing).

**Alternative:**
- Add semantic conformance tests generated from state/tool rules:
  - transition matrix unit tests,
  - tool precondition contract tests,
  - error mapping tests.

### 6.2 Canonical change blast radius is high
“Change canonical => regenerate all docs” enforces discipline but slows iteration and increases merge conflicts.

**Alternative:**
- Regeneration by impacted domain graph (state/tool/schema/API docs subsets) with a resolver manifest.

---

## 7) Concrete alternative architecture options

## Option A — Deterministic Commerce Core + Assisted AI Edge (recommended MVP-hardening path)
**Design:**
- Deterministic state machine and commerce actions first-class.
- LLM only for language generation and retrieval synthesis.
- High-risk actions require policy/intent gate before tool execution.

**Pros:**
- Lower incident severity for order/cart flows.
- Easier compliance and testability.

**Cons:**
- Less “agentic” flexibility; more rule-writing effort.

## Option B — Event-driven internal workflow spine
**Design:**
- Keep monolith deployable, but route critical side effects through internal event bus/outbox.
- Consumers handle notifications, sync, analytics asynchronously.

**Pros:**
- Better resilience and replay capability.
- Cleaner compensation handling.

**Cons:**
- More moving parts and operational complexity.

## Option C — Multi-agent readiness without immediate rollout
**Design:**
- Preserve one-agent runtime behavior but make schema/routing future-proof (agent profiles + intent routing table).

**Pros:**
- Reduces future migration pain.

**Cons:**
- Slight upfront design cost with no immediate user-visible gain.

---

## 8) Priority remediation plan

### P0 (must address before pilot scale-up)
1. Canonicalize executable RLS SQL policies and CI-check them.
2. Define webhook replay protection + key rotation runbook.
3. Add deterministic safeguards for order creation (intent gate + compensation).
4. Add numeric SLO/SLA/throughput targets and degradation triggers.

### P1 (next iteration)
1. Add semantic conformance test suite from state/tool contracts.
2. Introduce outbox/eventing for non-atomic side effects.
3. Define data retention/redaction/deletion matrix and enforcement jobs.

### P2 (future-proofing)
1. Provider-neutral deployment capability model (instead of host lock).
2. Multi-agent schema compatibility path.
3. Domain-scoped doc regeneration graph to reduce workflow friction.

---

## Conclusion
The spec set is strong on structure and governance but currently over-indexed on documentation rigor relative to runtime-operational rigor. The highest risk is not inconsistency—it is **well-governed incompleteness** in resilience/security behaviors. Moving a subset of canonical statements into executable controls (RLS SQL, conformance tests, replay protection, compensation workflows, numeric SLOs) yields the highest safety gain per engineering effort.
