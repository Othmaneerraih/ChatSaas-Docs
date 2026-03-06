# Delivery Epics

## Epic 1 — Platform Foundation & Data Isolation
**Outcome:** Secure, tenant-isolated data/storage foundation with canonical schema and RLS enforcement.

### Features
1. **Canonical schema deployment baseline**
   - Source references:
     - `docs/03_data_model_storage_rls.md` → `### 1) Supabase/Postgres configuration baseline`
     - `docs/03_data_model_storage_rls.md` → `### 2) Schema usage model (verbatim canonical application)`
2. **RLS policy enforcement and tenant boundaries**
   - Source references:
     - `docs/03_data_model_storage_rls.md` → `### 6) RLS patterns and enforcement`
     - `docs/01_system_architecture_overview.md` → `#### 1.2 Data plane (Supabase PostgreSQL + pgvector + RLS)`
3. **Migration/change control workflow**
   - Source references:
     - `docs/03_data_model_storage_rls.md` → `### 5) Migrations and change management`
     - `docs/19_implementation_plan_milestones.md` → `#### Phase 1 — Foundation: auth, tenant boundaries, and core data paths`

---

## Epic 2 — Conversation Engine & State Governance
**Outcome:** Deterministic conversation lifecycle and mode/cart transitions with guardrails.

### Features
1. **Conversation orchestrator and lifecycle control**
   - Source references:
     - `docs/05_conversation_engine_state_machine.md` → `### 1) Engine responsibilities`
     - `docs/05_conversation_engine_state_machine.md` → `### 2) Message lifecycle`
2. **Status/mode/cart transition enforcement**
   - Source references:
     - `docs/05_conversation_engine_state_machine.md` → `### 3) Status transitions (exact canonical behavior)`
     - `docs/05_conversation_engine_state_machine.md` → `### 4) Mode handling (exact canonical behavior)`
     - `docs/05_conversation_engine_state_machine.md` → `### 5) Cart transitions and guards (exact canonical behavior)`
3. **Control gates and failure recovery**
   - Source references:
     - `docs/05_conversation_engine_state_machine.md` → `### 6) Control gates and sequencing`
     - `docs/05_conversation_engine_state_machine.md` → `## Failure Modes`

---

## Epic 3 — Tooling Runtime & Contract Validation
**Outcome:** Tool invocation system that is schema-validated, gated, auditable, and deterministic where required.

### Features
1. **Tool lifecycle execution pipeline**
   - Source references:
     - `docs/07_tooling_layer_tool_contracts.md` → `### Tool lifecycle`
2. **Tool input validation and enablement checks**
   - Source references:
     - `docs/07_tooling_layer_tool_contracts.md` → `### Validation model`
3. **Idempotency, confirmation, and execution guarantees**
   - Source references:
     - `docs/07_tooling_layer_tool_contracts.md` → `### Idempotency and confirmation gates`
     - `docs/07_tooling_layer_tool_contracts.md` → `### Execution guarantees`
4. **Tool failure routing and observability hooks**
   - Source references:
     - `docs/07_tooling_layer_tool_contracts.md` → `### Error handling behavior`

---

## Epic 4 — Channel Integration: WhatsApp BYOK
**Outcome:** Production-ready inbound WhatsApp integration with verification, dedup, and compliance controls.

### Features
1. **Webhook ingestion and dedup pipeline**
   - Source references:
     - `docs/10_whatsapp_byok_spec.md` → `### Webhook flows`
2. **Auth/signature enforcement and tenant scoping**
   - Source references:
     - `docs/10_whatsapp_byok_spec.md` → `### Authentication and authorization`
3. **Rate-limit, retry, and policy boundaries**
   - Source references:
     - `docs/10_whatsapp_byok_spec.md` → `### Rate limits and retries`
     - `docs/10_whatsapp_byok_spec.md` → `### Compliance constraints`

---

## Epic 5 — Architecture Assembly, Release Readiness & Milestones
**Outcome:** End-to-end system assembled in canonical phase order with measurable completion gates.

### Features
1. **Component integration by architecture planes**
   - Source references:
     - `docs/01_system_architecture_overview.md` → `### 1) Component breakdown`
     - `docs/01_system_architecture_overview.md` → `### 2) Data flow`
     - `docs/01_system_architecture_overview.md` → `### 3) Control flow`
2. **Deployment topology and config/secrets hardening**
   - Source references:
     - `docs/01_system_architecture_overview.md` → `### 4) Deployment topology`
3. **Phased delivery governance**
   - Source references:
     - `docs/19_implementation_plan_milestones.md` → `### Phased rollout plan`
     - `docs/19_implementation_plan_milestones.md` → `### Dependency map`
     - `docs/19_implementation_plan_milestones.md` → `### Critical path`
     - `docs/19_implementation_plan_milestones.md` → `### Acceptance criteria model`
