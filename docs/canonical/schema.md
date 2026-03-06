> ⚠️ Canonical Spec File — Read-Only. Modify only through canonical-first change control.

# Database Schema

All tables live in Supabase PostgreSQL. Every table has tenant_id (except tenants itself). RLS on all tables. UUIDs for all primary keys. Timestamps use timestamptz.

Extensions required: uuid-ossp, pgvector, pg_trgm

## 2.1 tenants

Root entity. One row per paying customer (merchant).

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK, DEFAULT uuid_generate_v4() |  |
| name | TEXT | NOT NULL | Business name |
| slug | TEXT | UNIQUE, NOT NULL | URL-safe identifier (e.g. shoe-palace) |
| owner_id | UUID | FK auth.users(id), NOT NULL | Supabase Auth user who owns this tenant |
| plan | TEXT | NOT NULL, DEFAULT 'free' | Enum: free, starter, pro, enterprise |
| settings | JSONB | NOT NULL, DEFAULT '{}' | WhatsApp phone, widget colors, domain |
| monthly_budget_mad | INT | DEFAULT 1000 | Spend cap for AI API calls |
| is_active | BOOLEAN | DEFAULT true | Soft delete / suspension |
| created_at | TIMESTAMPTZ | DEFAULT now() |  |
| updated_at | TIMESTAMPTZ | DEFAULT now() | Updated via trigger |
RLS: Owners can read/write their own tenant. Service role for creation.

## 2.2 agents

One agent per tenant (MVP). Config object defines all behavior.

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK |  |
| tenant_id | UUID | FK tenants(id), NOT NULL, UNIQUE | One agent per tenant (MVP) |
| name | TEXT | NOT NULL | Agent display name (e.g. Ayoub, Fatima) |
| identity | JSONB | NOT NULL | { persona_prompt, tone, language_prefs } |
| models | JSONB | NOT NULL | { chat, reasoning, vision, embedding, stt } — model IDs per role |
| tools_enabled | TEXT[] | NOT NULL, DEFAULT '{}' | Array of tool names this agent can call |
| routing_rules | JSONB | DEFAULT '{}' | { escalation_triggers, complexity_keywords } |
| business_rules | JSONB | DEFAULT '{}' | { discount_max_pct, refund_days, hours, min_order, cod_only } |
| system_prompt_override | TEXT | NULLABLE | Full override if merchant customizes |
| config_version | INT | NOT NULL, DEFAULT 1 | Incremented on every config change |
| is_active | BOOLEAN | DEFAULT true |  |
| created_at | TIMESTAMPTZ | DEFAULT now() |  |
| updated_at | TIMESTAMPTZ | DEFAULT now() |  |
## 2.3 customers

End-users (the people chatting with the agent). NOT Supabase Auth users.

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK |  |
| tenant_id | UUID | FK tenants(id), NOT NULL |  |
| phone | TEXT | NULLABLE | WhatsApp number (E.164 format) |
| email | TEXT | NULLABLE | From web widget if provided |
| name | TEXT | NULLABLE | Extracted from conversation or provided |
| external_id | TEXT | NULLABLE | WooCommerce/Shopify customer ID |
| metadata | JSONB | DEFAULT '{}' | Language pref, address, notes |
| first_seen_at | TIMESTAMPTZ | DEFAULT now() |  |
| last_seen_at | TIMESTAMPTZ | DEFAULT now() | Updated on every message |
| created_at | TIMESTAMPTZ | DEFAULT now() |  |
RLS: Scoped by tenant_id. Unique constraint: (tenant_id, phone) and (tenant_id, email).

## 2.4 conversations

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK |  |
| tenant_id | UUID | FK tenants(id), NOT NULL |  |
| customer_id | UUID | FK customers(id), NOT NULL |  |
| channel | TEXT | NOT NULL | Enum: whatsapp, web_widget, instagram |
| status | TEXT | NOT NULL, DEFAULT 'active' | Enum: active, resolved, escalated, abandoned |
| mode | TEXT | NOT NULL, DEFAULT 'ai' | Enum: ai, manual, ai_whisper |
| cart_state | JSONB | DEFAULT '{"items":[]}' | Current cart contents |
| confirm_state | BOOLEAN | DEFAULT false | True only after explicit customer confirmation |
| language_detected | TEXT | NULLABLE | darija, french, english, msa, mixed |
| metadata | JSONB | DEFAULT '{}' | Channel-specific data (wa_message_id, widget_session) |
| started_at | TIMESTAMPTZ | DEFAULT now() |  |
| last_message_at | TIMESTAMPTZ | DEFAULT now() |  |
| resolved_at | TIMESTAMPTZ | NULLABLE |  |
| created_at | TIMESTAMPTZ | DEFAULT now() |  |
## 2.5 messages

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK |  |
| tenant_id | UUID | FK tenants(id), NOT NULL | Denormalized for RLS |
| conversation_id | UUID | FK conversations(id), NOT NULL |  |
| role | TEXT | NOT NULL | Enum: customer, agent, system, tool_call, tool_result |
| content | TEXT | NULLABLE | Text content of message |
| message_type | TEXT | NOT NULL, DEFAULT 'text' | Enum: text, image, voice, product_card, carousel, quick_reply, order_summary, form |
| structured_data | JSONB | NULLABLE | Rich message payload (product cards, buttons, etc.) |
| media_url | TEXT | NULLABLE | URL to image/voice file in storage |
| tool_name | TEXT | NULLABLE | If role=tool_call: which tool was called |
| tool_args | JSONB | NULLABLE | If role=tool_call: arguments passed |
| tool_result | JSONB | NULLABLE | If role=tool_result: what the tool returned |
| model_used | TEXT | NULLABLE | Which LLM model generated this response |
| tokens_in | INT | NULLABLE | Input tokens consumed |
| tokens_out | INT | NULLABLE | Output tokens consumed |
| latency_ms | INT | NULLABLE | Time to generate response |
| channel_message_id | TEXT | NULLABLE | WhatsApp message ID (for dedup) |
| created_at | TIMESTAMPTZ | DEFAULT now() |  |
Index: (conversation_id, created_at) for ordered retrieval. Index: (tenant_id, channel_message_id) UNIQUE for dedup.

## 2.6 products

Structured product data. Typed columns for SQL filtering. NOT chunked/embedded.

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK |  |
| tenant_id | UUID | FK tenants(id), NOT NULL |  |
| external_id | TEXT | NULLABLE | WooCommerce/Shopify product ID |
| name | TEXT | NOT NULL | Product name |
| description | TEXT | NULLABLE | Full product description |
| category | TEXT | NULLABLE | Primary category |
| subcategory | TEXT | NULLABLE |  |
| brand | TEXT | NULLABLE |  |
| price | DECIMAL(10,2) | NOT NULL | Price in MAD |
| compare_at_price | DECIMAL(10,2) | NULLABLE | Original price if on sale |
| currency | TEXT | DEFAULT 'MAD' |  |
| image_url | TEXT | NULLABLE | Primary image URL |
| image_urls | TEXT[] | DEFAULT '{}' | Additional images |
| tags | TEXT[] | DEFAULT '{}' | Searchable tags |
| is_active | BOOLEAN | DEFAULT true |  |
| created_at | TIMESTAMPTZ | DEFAULT now() |  |
| updated_at | TIMESTAMPTZ | DEFAULT now() |  |
Index: (tenant_id, category), (tenant_id, brand). GIN index on tags. pg_trgm index on name for fuzzy search.

## 2.7 product_variants

Size, color, and stock tracked per variant. Products without variants get one default row.

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK |  |
| tenant_id | UUID | FK tenants(id), NOT NULL | Denormalized for RLS |
| product_id | UUID | FK products(id) ON DELETE CASCADE, NOT NULL |  |
| size | TEXT | NULLABLE | e.g. '42', 'M', '1kg' |
| color | TEXT | NULLABLE | e.g. 'black', 'noir' |
| sku | TEXT | NULLABLE |  |
| stock | INT | NOT NULL, DEFAULT 0 | Current stock quantity |
| price_override | DECIMAL(10,2) | NULLABLE | If variant has different price |
| is_active | BOOLEAN | DEFAULT true |  |
| updated_at | TIMESTAMPTZ | DEFAULT now() |  |
Index: (tenant_id, product_id). Index: (tenant_id, size, color) for filtered search.

## 2.8 orders

Immutable once created. Idempotency key prevents duplicates.

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK |  |
| tenant_id | UUID | FK tenants(id), NOT NULL |  |
| customer_id | UUID | FK customers(id), NOT NULL |  |
| conversation_id | UUID | FK conversations(id), NULLABLE | Which conversation created this order |
| idempotency_key | TEXT | UNIQUE, NOT NULL | Prevents duplicate order creation |
| status | TEXT | NOT NULL, DEFAULT 'pending' | Enum: pending, confirmed, preparing, delivering, delivered, cancelled |
| subtotal | DECIMAL(10,2) | NOT NULL | Sum of item prices |
| delivery_fee | DECIMAL(10,2) | DEFAULT 0 |  |
| total | DECIMAL(10,2) | NOT NULL | subtotal + delivery_fee |
| payment_method | TEXT | DEFAULT 'cod' | Enum: cod, online, merchant_link |
| payment_status | TEXT | DEFAULT 'pending' | Enum: pending, paid, failed |
| delivery_name | TEXT | NULLABLE |  |
| delivery_phone | TEXT | NULLABLE |  |
| delivery_address | TEXT | NULLABLE |  |
| delivery_city | TEXT | NULLABLE |  |
| notes | TEXT | NULLABLE | Customer notes |
| created_at | TIMESTAMPTZ | DEFAULT now() |  |
| updated_at | TIMESTAMPTZ | DEFAULT now() |  |
## 2.9 order_items

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK |  |
| tenant_id | UUID | FK tenants(id), NOT NULL |  |
| order_id | UUID | FK orders(id) ON DELETE CASCADE, NOT NULL |  |
| product_id | UUID | FK products(id), NOT NULL |  |
| variant_id | UUID | FK product_variants(id), NULLABLE |  |
| product_name | TEXT | NOT NULL | Snapshot at time of order |
| variant_label | TEXT | NULLABLE | e.g. 'Size 42, Black' |
| quantity | INT | NOT NULL, CHECK (quantity > 0) |  |
| unit_price | DECIMAL(10,2) | NOT NULL | Price at time of order |
| line_total | DECIMAL(10,2) | NOT NULL | quantity * unit_price |
## 2.10 documents

Uploaded files for RAG. Policies, FAQs, care guides. NOT product catalogs.

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK |  |
| tenant_id | UUID | FK tenants(id), NOT NULL |  |
| title | TEXT | NOT NULL |  |
| source_type | TEXT | NOT NULL | Enum: upload, firecrawl, manual_faq |
| source_url | TEXT | NULLABLE | If scraped |
| content_text | TEXT | NULLABLE | Full extracted text |
| file_path | TEXT | NULLABLE | Supabase Storage path |
| chunk_count | INT | DEFAULT 0 | Number of chunks created |
| status | TEXT | DEFAULT 'processing' | Enum: processing, ready, failed |
| created_at | TIMESTAMPTZ | DEFAULT now() |  |
## 2.11 document_chunks

Chunked + embedded document content for vector search.

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK |  |
| tenant_id | UUID | FK tenants(id), NOT NULL | Denormalized for RLS + vector search scoping |
| document_id | UUID | FK documents(id) ON DELETE CASCADE, NOT NULL |  |
| chunk_index | INT | NOT NULL | Order within document |
| content | TEXT | NOT NULL | Chunk text (target: 500 tokens, 100 overlap) |
| embedding | vector(1536) | NOT NULL | OpenAI text-embedding-3-small |
| metadata | JSONB | DEFAULT '{}' | Section title, page number, etc. |
| created_at | TIMESTAMPTZ | DEFAULT now() |  |
Index: HNSW index on (embedding) with (tenant_id) filter for scoped vector search.

## 2.12 audit_log

Every tool call and significant action. Append-only.

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK |  |
| tenant_id | UUID | NOT NULL |  |
| conversation_id | UUID | NULLABLE |  |
| customer_id | UUID | NULLABLE |  |
| action | TEXT | NOT NULL | tool_call, order_created, escalation, config_change, login, etc. |
| tool_name | TEXT | NULLABLE |  |
| tool_args | JSONB | NULLABLE |  |
| tool_result | JSONB | NULLABLE |  |
| actor | TEXT | NOT NULL | agent, merchant, system |
| ip_address | TEXT | NULLABLE |  |
| created_at | TIMESTAMPTZ | DEFAULT now() |  |
## 2.13 channel_connections

Stores each tenant’s channel credentials.

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK |  |
| tenant_id | UUID | FK tenants(id), NOT NULL |  |
| channel | TEXT | NOT NULL | Enum: whatsapp, instagram, web_widget |
| phone_number | TEXT | NULLABLE | WhatsApp: E.164 format |
| phone_number_id | TEXT | NULLABLE | Meta Cloud API phone number ID |
| waba_id | TEXT | NULLABLE | WhatsApp Business Account ID |
| access_token_encrypted | TEXT | NULLABLE | Encrypted Meta access token |
| webhook_verify_token | TEXT | NULLABLE | Token for Meta webhook verification |
| is_active | BOOLEAN | DEFAULT true |  |
| created_at | TIMESTAMPTZ | DEFAULT now() |  |
## 2.14 ecommerce_connections

| Column | Type | Constraints | Notes |
| --- | --- | --- | --- |
| id | UUID | PK |  |
| tenant_id | UUID | FK tenants(id), NOT NULL |  |
| platform | TEXT | NOT NULL | Enum: woocommerce, shopify, manual |
| store_url | TEXT | NULLABLE | e.g. https://mystore.com |
| consumer_key_encrypted | TEXT | NULLABLE | WooCommerce consumer key (encrypted) |
| consumer_secret_encrypted | TEXT | NULLABLE | WooCommerce consumer secret (encrypted) |
| shopify_access_token_encrypted | TEXT | NULLABLE |  |
| last_sync_at | TIMESTAMPTZ | NULLABLE |  |
| sync_status | TEXT | DEFAULT 'pending' | Enum: pending, syncing, synced, error |
| is_active | BOOLEAN | DEFAULT true |  |
| created_at | TIMESTAMPTZ | DEFAULT now() |  |
