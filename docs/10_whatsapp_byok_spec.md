# 10 WhatsApp (BYOK) Integration Spec

## Purpose
This document defines the canonical WhatsApp BYOK integration model for Aidy MVP, including tenant-owned channel configuration, webhook ingestion/verification behavior, authentication boundaries, rate-limit/retry handling, and compliance constraints. It is intended for backend engineers, QA, and operations teams implementing and validating WhatsApp channel behavior.

## Scope
In scope:
- BYOK channel model using merchant-owned WhatsApp Business API credentials.
- Inbound webhook ingestion and deduplication behavior.
- Authentication and authorization boundaries for channel config and message processing.
- Canonical rate-limit and retry/error handling behavior.
- Compliance constraints derived from locked channel decisions.

Out of scope:
- Non-BYOK WhatsApp provider models.
- Cold outbound campaign flows or unsupported outbound automation classes.
- Non-canonical template catalog design or approval workflows not defined in canonical artifacts.

Canonical boundaries this document cannot override:
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`
- `docs/canonical/state_machine.md`
- `docs/canonical/tools.md`

## Non-Goals
- Defining a new external messaging orchestration subsystem.
- Defining unsupported WhatsApp capabilities not present in canonical references.
- Defining non-canonical SLA values for webhook retries or throughput.

## Canonical Dependencies

### Canonical files used
- `docs/canonical/locked_decisions.md`
- `docs/canonical/schema.md`
- `docs/canonical/errors.md`
- `docs/canonical/rls.md`
- `docs/canonical/state_machine.md`
- `docs/canonical/tools.md`
- `docs/canonical/env_vars.md`
- `docs/templates/doc_template.md`

### Tables referenced (if any)
- `channel_connections` (BYOK credentials and activation status per tenant/channel)
- `messages` (`channel_message_id` dedup anchor, inbound/outbound message trail)
- `conversations` (channel-bound lifecycle and mode transitions)
- `customers` (phone identity linkage in tenant scope)
- `tenants` (owner isolation boundary and settings)
- `audit_log` (channel action traceability)

### Tools referenced (if any)
- `escalate_to_human` (may trigger merchant-facing notification path including optional WhatsApp message)

### States/modes referenced (if any)
- Status transitions involved in WhatsApp servicing:
  - `(new) -> active` on first customer message
  - `active -> escalated` and `escalated -> active` for takeover/release workflows
  - `resolved -> active` on new inbound customer message
- Modes involved in channel servicing:
  - `ai`, `manual`, `ai_whisper`

### Error codes referenced (if any)
- Webhook/channel integrity: `WEBHOOK_SIGNATURE_INVALID`, `WEBHOOK_DUPLICATE`
- Auth and tenant boundary: `AUTH_REQUIRED`, `AUTH_INVALID`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
- Throughput/runtime: `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`

## Design

### BYOK integration model
- Canonical model is merchant-owned WhatsApp Business API credentials stored per tenant in `channel_connections` with encrypted token fields.
- Integration is inbound-first and constrained by locked decision: no cold outbound behavior.
- Channel activation is controlled by `channel_connections.is_active` within tenant scope.

### Webhook flows
1. **Verification flow**
   - WhatsApp webhook verification uses tenant/channel configuration and stored verify token semantics.
   - Verification failures return canonical webhook/auth failures and do not create conversation/message rows.
2. **Inbound message flow**
   - Receive inbound event for tenant channel.
   - Validate signature.
   - Resolve tenant + customer + conversation context in tenant scope.
   - Deduplicate using canonical `messages.channel_message_id` uniqueness semantics.
   - Persist message and continue canonical conversation flow.
3. **Duplicate flow**
   - Duplicate webhook events return canonical `WEBHOOK_DUPLICATE` behavior (HTTP 200 semantics) to suppress provider retries.

### Authentication and authorization
- Channel config operations are tenant-owner scoped and governed by canonical auth/forbidden error behavior.
- Runtime message processing is scoped by tenant context and RLS boundaries.
- Secrets remain encrypted at rest (`access_token_encrypted`) and never exposed to client paths.

### Message templates
- Canonical artifacts do not define a template registry, template lifecycle, or template approval protocol.
- Therefore, template behavior in MVP is limited to what is explicitly supported by provider account configuration and canonical channel constraints.
- Any additional template management behavior must be specified in canonical artifacts before implementation.

### Rate limits and retries
- Canonical rate-limit behavior is represented by `RATE_LIMITED` error handling.
- Webhook duplicate handling is canonicalized through `WEBHOOK_DUPLICATE` and dedup keys.
- Canonical artifacts do not provide numeric retry/backoff policy for WhatsApp delivery or inbound processing retries; these remain operationally unresolved and tracked in Open Questions.

### Compliance constraints
- BYOK ownership and inbound-only operation are non-negotiable channel constraints.
- No cold outbound messaging path is permitted by canonical locked decision.
- Tenant isolation and audit traceability are mandatory for all WhatsApp-related operations.

## Interfaces
Canonical WhatsApp interfaces:
- `GET /api/v1/webhooks/whatsapp/{tenant_id}` (verification)
- `POST /api/v1/webhooks/whatsapp/{tenant_id}` (inbound event ingestion)

Related channel/service interfaces:
- Dashboard conversation controls (takeover/release) affecting mode transitions.
- Tool pathway `escalate_to_human(reason, conversation_id)` for handoff behavior.

## Invariants
- WhatsApp channel configuration is tenant-scoped and cannot cross tenant boundaries.
- Webhook events are signature-validated before mutation.
- Duplicate inbound messages do not produce duplicate side effects.
- BYOK + inbound-only constraints are always preserved.
- Conversation status/mode transitions from WhatsApp traffic remain canonical.
- Channel credentials remain encrypted and server-side only.

## Failure Modes
- **Webhook verification/signature failures**
  - Errors: `WEBHOOK_SIGNATURE_INVALID`, `AUTH_INVALID`
  - Mitigation: reject request, do not mutate conversation/message state.

- **Duplicate message delivery from provider**
  - Error: `WEBHOOK_DUPLICATE`
  - Mitigation: return duplicate-accepted response semantics; skip duplicate writes.

- **Tenant/auth boundary failures**
  - Errors: `AUTH_REQUIRED`, `FORBIDDEN`, `TENANT_NOT_FOUND`, `CONVERSATION_NOT_FOUND`
  - Mitigation: fail before channel or message side effects.

- **Rate/runtime degradation**
  - Errors: `RATE_LIMITED`, `MODEL_ERROR`, `INTERNAL_ERROR`
  - Mitigation: fail safely with canonical errors; avoid invalid state transitions.

## Open Questions
- TODO: `/sources/Aidy_Master_Reference.md` and `/sources/Aidy_Technical_Spec_v3.md` are listed inputs but unavailable in this environment; confirm required source-export workflow.
- TODO: Canonical artifacts do not specify WhatsApp template lifecycle/approval/selection rules; confirm authoritative source or mark explicitly out of MVP scope.
- TODO: Canonical artifacts do not define numeric retry/backoff policy for webhook processing or downstream WhatsApp delivery retries; confirm operational standard source.

## Change Log
- 2026-02-21 — Codex: Initial WhatsApp (BYOK) Integration specification generated from canonical artifacts.

## Consistency Audit
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs canonical/locked_decisions.md: **PASS**
