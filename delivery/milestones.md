# Delivery Milestones

## M0 — Spec Baseline & Planning Freeze
- **References:**
  - `docs/19_implementation_plan_milestones.md` → `#### Phase 0 — Canonical baseline lock and readiness`
  - `docs/01_system_architecture_overview.md` → `## Invariants`
- **Includes:**
  - Finalize epic/feature/task breakdown.
  - Confirm canonical scope boundaries and invariants.
- **Exit criteria:**
  - Delivery plan approved.
  - No unresolved contradictions against canonical docs.

## M1 — Foundation Complete (Data + RLS)
- **References:**
  - `docs/19_implementation_plan_milestones.md` → `#### Phase 1 — Foundation: auth, tenant boundaries, and core data paths`
  - `docs/03_data_model_storage_rls.md` → `### 6) RLS patterns and enforcement`
- **Includes:** E1-T1..E1-T5
- **Dependencies:** M0
- **Exit criteria:**
  - Canonical schema present.
  - RLS isolation tests passing.
  - Migration/change-control checks passing.

## M2 — Conversation + Tooling Engine Complete
- **References:**
  - `docs/19_implementation_plan_milestones.md` → `#### Phase 2 — Conversation engine and tooling layer`
  - `docs/05_conversation_engine_state_machine.md` → `### 3) Status transitions (exact canonical behavior)`
  - `docs/07_tooling_layer_tool_contracts.md` → `### Validation model`
- **Includes:** E2-T1..E2-T5, E3-T1..E3-T4
- **Dependencies:** M1
- **Exit criteria:**
  - State/mode/cart transition matrix tests pass.
  - Tool schema validation + gating tests pass.

## M3 — WhatsApp BYOK Channel Integration Complete
- **References:**
  - `docs/19_implementation_plan_milestones.md` → `#### Phase 3 — Channel and commerce integrations`
  - `docs/10_whatsapp_byok_spec.md` → `### Webhook flows`
- **Includes:** E4-T1..E4-T4
- **Dependencies:** M2
- **Exit criteria:**
  - Webhook verification, ingestion, dedup, and retry tests pass.
  - BYOK compliance constraints enforced.

## M4 — Architecture Assembly & Deployment Readiness
- **References:**
  - `docs/01_system_architecture_overview.md` → `### 4) Deployment topology`
  - `docs/19_implementation_plan_milestones.md` → `#### Phase 4 — Retrieval, observability, and reliability controls`
- **Includes:** E5-T1..E5-T3
- **Dependencies:** M3
- **Exit criteria:**
  - End-to-end architecture flow validated.
  - Deployment topology and secrets posture verified.

## M5 — Pilot Release Gate
- **References:**
  - `docs/19_implementation_plan_milestones.md` → `#### Phase 5 — Pilot launch readiness and gated release`
  - `docs/19_implementation_plan_milestones.md` → `### Acceptance criteria model`
- **Includes:** E5-T4
- **Dependencies:** M4
- **Exit criteria:**
  - All phase gates green.
  - Pilot launch checklist complete.
