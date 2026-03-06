-- Generated schema migration stubs from docs/canonical/schema.md
-- NOTE: This file is a scaffold. Validate constraints/indexes/RLS before execution.
BEGIN;

-- Table: tenants
CREATE TABLE IF NOT EXISTS tenants (
  id uuid DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  slug text NOT NULL,
  owner_id uuid NOT NULL,
  plan text NOT NULL DEFAULT 'free',
  settings jsonb NOT NULL DEFAULT '{}',
  monthly_budget_mad integer DEFAULT 1000,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for tenants from canonical schema notes.

-- Table: agents
CREATE TABLE IF NOT EXISTS agents (
  id uuid,
  tenant_id uuid NOT NULL,
  name text NOT NULL,
  identity jsonb NOT NULL,
  models jsonb NOT NULL,
  tools_enabled text[] NOT NULL DEFAULT '{}',
  routing_rules jsonb DEFAULT '{}',
  business_rules jsonb DEFAULT '{}',
  system_prompt_override text,
  config_version integer NOT NULL DEFAULT 1,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for agents from canonical schema notes.

-- Table: customers
CREATE TABLE IF NOT EXISTS customers (
  id uuid,
  tenant_id uuid NOT NULL,
  phone text,
  email text,
  name text,
  external_id text,
  metadata jsonb DEFAULT '{}',
  first_seen_at timestamptz DEFAULT now(),
  last_seen_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for customers from canonical schema notes.

-- Table: conversations
CREATE TABLE IF NOT EXISTS conversations (
  id uuid,
  tenant_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  channel text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  mode text NOT NULL DEFAULT 'ai',
  cart_state jsonb DEFAULT '{"items":[]}',
  confirm_state boolean DEFAULT false,
  language_detected text,
  metadata jsonb DEFAULT '{}',
  started_at timestamptz DEFAULT now(),
  last_message_at timestamptz DEFAULT now(),
  resolved_at timestamptz,
  created_at timestamptz DEFAULT now()
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for conversations from canonical schema notes.

-- Table: messages
CREATE TABLE IF NOT EXISTS messages (
  id uuid,
  tenant_id uuid NOT NULL,
  conversation_id uuid NOT NULL,
  role text NOT NULL,
  content text,
  message_type text NOT NULL DEFAULT 'text',
  structured_data jsonb,
  media_url text,
  tool_name text,
  tool_args jsonb,
  tool_result jsonb,
  model_used text,
  tokens_in integer,
  tokens_out integer,
  latency_ms integer,
  channel_message_id text,
  created_at timestamptz DEFAULT now()
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for messages from canonical schema notes.

-- Table: products
CREATE TABLE IF NOT EXISTS products (
  id uuid,
  tenant_id uuid NOT NULL,
  external_id text,
  name text NOT NULL,
  description text,
  category text,
  subcategory text,
  brand text,
  price DECIMAL(10,2) NOT NULL,
  compare_at_price DECIMAL(10,2),
  currency text DEFAULT 'MAD',
  image_url text,
  image_urls text[] DEFAULT '{}',
  tags text[] DEFAULT '{}',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for products from canonical schema notes.

-- Table: product_variants
CREATE TABLE IF NOT EXISTS product_variants (
  id uuid,
  tenant_id uuid NOT NULL,
  product_id uuid NOT NULL,
  size text,
  color text,
  sku text,
  stock integer NOT NULL DEFAULT 0,
  price_override DECIMAL(10,2),
  is_active boolean DEFAULT true,
  updated_at timestamptz DEFAULT now()
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for product_variants from canonical schema notes.

-- Table: orders
CREATE TABLE IF NOT EXISTS orders (
  id uuid,
  tenant_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  conversation_id uuid,
  idempotency_key text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  subtotal DECIMAL(10,2) NOT NULL,
  delivery_fee DECIMAL(10,2) DEFAULT 0,
  total DECIMAL(10,2) NOT NULL,
  payment_method text DEFAULT 'cod',
  payment_status text DEFAULT 'pending',
  delivery_name text,
  delivery_phone text,
  delivery_address text,
  delivery_city text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for orders from canonical schema notes.

-- Table: order_items
CREATE TABLE IF NOT EXISTS order_items (
  id uuid,
  tenant_id uuid NOT NULL,
  order_id uuid NOT NULL,
  product_id uuid NOT NULL,
  variant_id uuid,
  product_name text NOT NULL,
  variant_label text,
  quantity integer NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  line_total DECIMAL(10,2) NOT NULL
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for order_items from canonical schema notes.

-- Table: documents
CREATE TABLE IF NOT EXISTS documents (
  id uuid,
  tenant_id uuid NOT NULL,
  title text NOT NULL,
  source_type text NOT NULL,
  source_url text,
  content_text text,
  file_path text,
  chunk_count integer DEFAULT 0,
  status text DEFAULT 'processing',
  created_at timestamptz DEFAULT now()
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for documents from canonical schema notes.

-- Table: document_chunks
CREATE TABLE IF NOT EXISTS document_chunks (
  id uuid,
  tenant_id uuid NOT NULL,
  document_id uuid NOT NULL,
  chunk_index integer NOT NULL,
  content text NOT NULL,
  embedding vector(1536) NOT NULL,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for document_chunks from canonical schema notes.

-- Table: audit_log
CREATE TABLE IF NOT EXISTS audit_log (
  id uuid,
  tenant_id uuid NOT NULL,
  conversation_id uuid,
  customer_id uuid,
  action text NOT NULL,
  tool_name text,
  tool_args jsonb,
  tool_result jsonb,
  actor text NOT NULL,
  ip_address text,
  created_at timestamptz DEFAULT now()
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for audit_log from canonical schema notes.

-- Table: channel_connections
CREATE TABLE IF NOT EXISTS channel_connections (
  id uuid,
  tenant_id uuid NOT NULL,
  channel text NOT NULL,
  phone_number text,
  phone_number_id text,
  waba_id text,
  access_token_encrypted text,
  webhook_verify_token text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for channel_connections from canonical schema notes.

-- Table: ecommerce_connections
CREATE TABLE IF NOT EXISTS ecommerce_connections (
  id uuid,
  tenant_id uuid NOT NULL,
  platform text NOT NULL,
  store_url text,
  consumer_key_encrypted text,
  consumer_secret_encrypted text,
  shopify_access_token_encrypted text,
  last_sync_at timestamptz,
  sync_status text DEFAULT 'pending',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);
-- TODO: apply PK/FK/UNIQUE/CHECK constraints and indexes for ecommerce_connections from canonical schema notes.

COMMIT;
