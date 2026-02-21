# Glossary

| Term | Definition |
| --- | --- |
| Tenant | A paying customer (merchant/business) on the Aidy platform. Has one agent, one or more channels. |
| Agent | The AI entity that converses with a tenant’s customers. Defined by the agent configuration object. |
| Customer | An end-user chatting with a tenant’s agent. NOT a Supabase Auth user. Identified by phone or email. |
| Conversation | A message thread between one customer and one agent on one channel. |
| BYOK | Bring Your Own Key. Each merchant uses their own WhatsApp Business API account, not a shared platform account. |
| COD | Cash on Delivery. Morocco’s default payment method. Customer pays when goods arrive. |
| Darija | Moroccan Arabic dialect. Written in Arabic script or Arabizi (Latin script with numerals: 3=ع, 7=ح, 9=ق). |
| Arabizi | Latin-script transliteration of Darija. e.g. “bghit nchouf” means “I want to see.” |
| MSA | Modern Standard Arabic. Formal Arabic used in news/education. Darija speakers notice and dislike MSA in casual chat. |
| RLS | Row Level Security. Supabase/PostgreSQL feature that filters all queries by tenant_id automatically via JWT. |
| ACI | Agent-Computer Interface. Tool interface design (schemas, descriptions, examples). Analogous to HCI but for AI agents. |
| Prompt Chain | Sequential LLM calls with programmatic gates (code validation) between each step. Not free-form looping. |
| Heuristic Router | Keyword/regex-based message classifier that routes to specialized handlers. No LLM call needed. |
| Golden Conversation | A scripted test interaction that must pass on every deploy. Used for regression testing. |
| Hybrid Retrieval | SQL filters → lexical search (pg_trgm) → semantic rerank. Used for product catalog. Pure RAG is for unstructured docs only. |
| Idempotency Key | Unique string per write operation. Prevents duplicate execution on retries. Stored in DB, checked before execution. |
| Confirm Gate | conversations.confirm_state must be true before create_order executes. Set only by explicit customer confirmation. |
| Fast Path | Simple text message → cheap model → response. No tools, no vision, no voice. Target: <2s P95. |
| Widget | Embeddable chat component for tenant websites. Single JS file. WebSocket connection to backend. |
| Handoff | Merchant takes control of a conversation from the AI. Sets conversation.mode = manual. |
| AI Whisper | While merchant is manually typing, AI suggests responses in a sidebar. |
