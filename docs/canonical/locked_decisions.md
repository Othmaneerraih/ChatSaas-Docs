> ⚠️ Canonical Spec File — Read-Only. Modify only through canonical-first change control.

# Locked Architecture Decisions
**SPEC_VERSION:** `1.0.0`


These decisions are final. No downstream document may contradict them.

| Decision | Choice | Rationale |
|---|---|---|
| Architecture type | Modular monolith (FastAPI) | Single deployable. Modules: auth, messaging, products, orders, agents, retrieval, tools, channels. Clean boundaries for future extraction. |
| Code structure | 3-layer: routes → services → repositories | Routes handle HTTP. Services hold business logic. Repositories handle Supabase queries. No skipping layers. |
| Database | Supabase (PostgreSQL 15 + pgvector + RLS) | Auth + DB + vectors + realtime in one service. RLS enforces tenant isolation at DB level. |
| Backend language | Python 3.12+ | AI/ML ecosystem: every LLM SDK, embedding lib, NLP model (DarijaLID, MoulSot) is Python-first. |
| Backend framework | FastAPI | Async-native. Auto OpenAPI docs. Type hints. Handles long-running agent loops. |
| Frontend | Next.js 14 + Shadcn/ui + Tailwind CSS | SSR dashboard. Shadcn = copy-paste components, no lock-in. Open-source admin template as scaffold. |
| Widget | Standalone React component, bundled as single JS (<50KB) | Embedded via <script> tag. WebSocket to backend. Shadow DOM isolation. |
| Auth | Supabase Auth (email+password, Google OAuth, magic link) | Built-in JWT. Integrates with RLS. Zero custom auth code. |
| Multi-tenancy | Shared DB, tenant_id on every table, Supabase RLS | Defense-in-depth. Every query filtered by JWT. Automated isolation tests in CI. |
| LLM approach | Open-weight models via API (Groq, DeepInfra). No self-hosting. | 25-30x cheaper than proprietary. Provider-agnostic interface for swapping. |
| No LangChain/LangGraph | Direct FastAPI orchestration for MVP | Simplicity. Add LangGraph only if workflow complexity justifies it (Phase 3+). |
| WhatsApp | BYOK: merchant’s own WhatsApp Business API account. Inbound-only. | No Tech Provider verification. No cold outbound. Free tier for pilots. |
| Payments | COD by default. Agent creates orders, never touches money. | Morocco standard. Merchant provides own payment link if online payment needed. |
| Product retrieval | Hybrid: SQL filters → lexical (pg_trgm) → semantic rerank | Pure RAG fails on exact constraints (size, color, stock). RAG only for unstructured docs. |
| Hosting: backend | Railway (Starter, $5/mo) | Containerized Python. Auto-deploy from GitHub. |
| Hosting: frontend | Vercel (Free) | Next.js native. Auto-deploy from GitHub. |
| Cache | Upstash Redis (Free, serverless) | Session state. Conversation locks. Rate limiting counters. |
| Monitoring | Sentry (Free tier) | Error tracking + performance. |
| Agent design pattern | Routing + Prompt Chaining + Parallel Guardrails (per Anthropic guide) | Composable patterns, not frameworks. Heuristic router. Programmatic gates between chain steps. |

## MVP constraints and non-negotiables

- All downstream documents MUST reference this canonical source. No improvisation.
- Every schema, endpoint, tool contract, state, enum, and error code is canonical here.

<!-- Rationale note (Aidy_Technical_Spec_v3.docx §2): v3 explains the design principle as "start simple, add complexity only when measurably needed" and reinforces direct FastAPI orchestration over frameworks for MVP. -->
