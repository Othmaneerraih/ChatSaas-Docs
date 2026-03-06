# Engineering Task Breakdown

## Epic 1 — Platform Foundation & Data Isolation

### Task E1-T1: Provision Supabase/Postgres baseline
- **Doc + section reference:** `docs/03_data_model_storage_rls.md` → `### 1) Supabase/Postgres configuration baseline`
- **Acceptance criteria:**
  - Postgres instance has required extensions enabled and reachable from backend runtime.
  - Tenant-scoped schema tables can be created without type errors.
- **Dependencies:** Cloud project bootstrap, secrets provisioning.
- **Test criteria:**
  - Migration dry-run succeeds.
  - Extension checks return expected values.

### Task E1-T2: Implement canonical table set
- **Doc + section reference:** `docs/03_data_model_storage_rls.md` → `### 2) Schema usage model (verbatim canonical application)`
- **Acceptance criteria:**
  - All canonical tables are present with canonical columns.
  - No non-canonical tables/columns are introduced.
- **Dependencies:** E1-T1.
- **Test criteria:**
  - Schema introspection snapshot matches canonical table/column inventory.

### Task E1-T3: Add indexes and retrieval-specific performance paths
- **Doc + section reference:** `docs/03_data_model_storage_rls.md` → `### 3) Index and performance model (canonical)`
- **Acceptance criteria:**
  - Canonical indexes exist for conversation retrieval, dedup, lexical retrieval, and vector retrieval.
- **Dependencies:** E1-T2.
- **Test criteria:**
  - Index presence checks pass.
  - Representative queries use expected index plans.

### Task E1-T4: Enforce RLS and tenant isolation policies
- **Doc + section reference:** `docs/03_data_model_storage_rls.md` → `### 6) RLS patterns and enforcement`
- **Acceptance criteria:**
  - Cross-tenant read/write attempts are denied.
  - Service-role-only operations are constrained to backend-only contexts.
- **Dependencies:** E1-T2.
- **Test criteria:**
  - Positive/negative tenant isolation tests pass in CI.

### Task E1-T5: Wire migration/change-control pipeline
- **Doc + section reference:** `docs/03_data_model_storage_rls.md` → `### 5) Migrations and change management`
- **Acceptance criteria:**
  - Canonical-first migration workflow is documented and executable.
  - Drift checks are required in migration PRs.
- **Dependencies:** E1-T2, E1-T4.
- **Test criteria:**
  - CI fails on unapplied migration drift.

---

## Epic 2 — Conversation Engine & State Governance

### Task E2-T1: Build conversation orchestrator skeleton
- **Doc + section reference:** `docs/05_conversation_engine_state_machine.md` → `### 1) Engine responsibilities`
- **Acceptance criteria:**
  - Orchestrator handles inbound message intake, tool dispatch, and outbound response sequencing.
- **Dependencies:** E1-T2.
- **Test criteria:**
  - End-to-end smoke flow from inbound message to outbound reply passes.

### Task E2-T2: Implement message lifecycle persistence
- **Doc + section reference:** `docs/05_conversation_engine_state_machine.md` → `### 2) Message lifecycle`
- **Acceptance criteria:**
  - Message write path captures role/type/tool metadata and timing fields per canonical structure.
- **Dependencies:** E2-T1.
- **Test criteria:**
  - Integration tests validate lifecycle writes and retrieval order.

### Task E2-T3: Enforce status transitions
- **Doc + section reference:** `docs/05_conversation_engine_state_machine.md` → `### 3) Status transitions (exact canonical behavior)`
- **Acceptance criteria:**
  - Only canonical transition edges are accepted.
  - Invalid transitions are blocked with canonical error behavior.
- **Dependencies:** E2-T1.
- **Test criteria:**
  - Transition matrix test suite passes (valid + invalid edges).

### Task E2-T4: Enforce mode transitions including disallowed edges
- **Doc + section reference:** `docs/05_conversation_engine_state_machine.md` → `### 4) Mode handling (exact canonical behavior)`
- **Acceptance criteria:**
  - `manual -> ai_whisper` remains disallowed.
  - Takeover/release mode effects are deterministic.
- **Dependencies:** E2-T3.
- **Test criteria:**
  - Mode transition tests pass including explicit negative case.

### Task E2-T5: Implement cart guards and control gates
- **Doc + section reference:**
  - `docs/05_conversation_engine_state_machine.md` → `### 5) Cart transitions and guards (exact canonical behavior)`
  - `docs/05_conversation_engine_state_machine.md` → `### 6) Control gates and sequencing`
- **Acceptance criteria:**
  - `create_order` requires explicit confirm gate.
  - Quantity/cart-size/idempotency constraints are enforced.
- **Dependencies:** E2-T2, E3-T3.
- **Test criteria:**
  - Commerce guardrail tests pass for all canonical failure modes.

---

## Epic 3 — Tooling Runtime & Contract Validation

### Task E3-T1: Implement tool registry and dispatch
- **Doc + section reference:** `docs/07_tooling_layer_tool_contracts.md` → `### Tool lifecycle`
- **Acceptance criteria:**
  - Tool invocation pipeline resolves only canonical tool identifiers.
- **Dependencies:** E2-T1.
- **Test criteria:**
  - Unknown tool invocation fails with canonical error.

### Task E3-T2: Enforce JSON-schema argument validation
- **Doc + section reference:** `docs/07_tooling_layer_tool_contracts.md` → `### Validation model`
- **Acceptance criteria:**
  - Tool args are schema-validated pre-execution.
  - Non-conforming args are rejected.
- **Dependencies:** E3-T1.
- **Test criteria:**
  - Contract tests per tool include valid/invalid argument sets.

### Task E3-T3: Implement idempotency/confirmation preconditions
- **Doc + section reference:** `docs/07_tooling_layer_tool_contracts.md` → `### Idempotency and confirmation gates`
- **Acceptance criteria:**
  - Order creation path enforces idempotency key uniqueness and confirmation precondition.
- **Dependencies:** E1-T2, E2-T5.
- **Test criteria:**
  - Duplicate and unconfirmed order scenarios fail with canonical errors.

### Task E3-T4: Add execution guarantees + audit trails
- **Doc + section reference:**
  - `docs/07_tooling_layer_tool_contracts.md` → `### Execution guarantees`
  - `docs/07_tooling_layer_tool_contracts.md` → `### Error handling behavior`
- **Acceptance criteria:**
  - Deterministic tool steps remain non-LLM.
  - Tool call/result traces are persisted for debugging/audit.
- **Dependencies:** E3-T1.
- **Test criteria:**
  - Audit log assertions pass for tool success/failure paths.

---

## Epic 4 — Channel Integration: WhatsApp BYOK

### Task E4-T1: Implement webhook verification + ingestion flow
- **Doc + section reference:** `docs/10_whatsapp_byok_spec.md` → `### Webhook flows`
- **Acceptance criteria:**
  - Verification and inbound ingestion paths process canonical events and dedup on channel message identity.
- **Dependencies:** E2-T2, E1-T4.
- **Test criteria:**
  - Replay/dedup tests pass.

### Task E4-T2: Add signature validation and tenant authz boundaries
- **Doc + section reference:** `docs/10_whatsapp_byok_spec.md` → `### Authentication and authorization`
- **Acceptance criteria:**
  - Invalid signatures are rejected.
  - Tenant/channel context is enforced before side effects.
- **Dependencies:** E4-T1, E1-T4.
- **Test criteria:**
  - Signature negative tests pass; unauthorized tenant access blocked.

### Task E4-T3: Implement retry/rate-limit safety controls
- **Doc + section reference:** `docs/10_whatsapp_byok_spec.md` → `### Rate limits and retries`
- **Acceptance criteria:**
  - Retries are bounded and idempotent.
  - Rate-limited behavior maps to canonical error handling.
- **Dependencies:** E4-T1.
- **Test criteria:**
  - Synthetic burst tests trigger expected throttling behavior.

### Task E4-T4: Enforce compliance/channel scope constraints
- **Doc + section reference:**
  - `docs/10_whatsapp_byok_spec.md` → `### BYOK integration model`
  - `docs/10_whatsapp_byok_spec.md` → `### Compliance constraints`
- **Acceptance criteria:**
  - Integration remains inbound-only BYOK with no unsupported outbound expansion.
- **Dependencies:** E4-T1.
- **Test criteria:**
  - Policy checks confirm unsupported channel actions are blocked.

---

## Epic 5 — Architecture Assembly, Release Readiness & Milestones

### Task E5-T1: Assemble modular monolith boundaries
- **Doc + section reference:** `docs/01_system_architecture_overview.md` → `#### 1.1 Backend (FastAPI modular monolith)`
- **Acceptance criteria:**
  - Route/service/repository layering implemented for core modules.
- **Dependencies:** E1-T2, E2-T1, E3-T1.
- **Test criteria:**
  - Architecture conformance checks pass (no layer skipping in core flows).

### Task E5-T2: Integrate data/control flow end-to-end
- **Doc + section reference:**
  - `docs/01_system_architecture_overview.md` → `### 2) Data flow`
  - `docs/01_system_architecture_overview.md` → `### 3) Control flow`
- **Acceptance criteria:**
  - Ingress-to-order and ingress-to-resolution flows operate end-to-end with canonical state transitions.
- **Dependencies:** E2-T5, E3-T4, E4-T2.
- **Test criteria:**
  - End-to-end scenario tests cover message, escalation, cart, confirm, and order paths.

### Task E5-T3: Apply deployment and config-secrets posture
- **Doc + section reference:** `docs/01_system_architecture_overview.md` → `### 4) Deployment topology`
- **Acceptance criteria:**
  - Runtime components deployed in canonical topology with required secrets and isolation boundaries.
- **Dependencies:** E5-T1.
- **Test criteria:**
  - Environment smoke checks and secret presence checks pass.

### Task E5-T4: Execute phased rollout gates
- **Doc + section reference:**
  - `docs/19_implementation_plan_milestones.md` → `### Phased rollout plan`
  - `docs/19_implementation_plan_milestones.md` → `### Acceptance criteria model`
- **Acceptance criteria:**
  - Each phase exit criteria is satisfied before next phase starts.
- **Dependencies:** All previous epic tasks by phase order.
- **Test criteria:**
  - Phase gate checklist is green with linked evidence for each deliverable.
