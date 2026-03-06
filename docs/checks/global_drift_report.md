# Global Drift Report

## Audit Scope
- Canonical sources: `docs/canonical/schema.md`, `docs/canonical/tools.md`, `docs/canonical/tools_schemas.json`, `docs/canonical/state_machine.md`, `docs/canonical/errors.md`, `docs/canonical/locked_decisions.md`.
- Downstream sources audited: all top-level files in `docs/*.md` (including appendices).

## Inventory
### Tables referenced
- `agents`
- `audit_log`
- `channel_connections`
- `conversations`
- `customers`
- `document_chunks`
- `documents`
- `ecommerce_connections`
- `messages`
- `order_items`
- `orders`
- `product_variants`
- `products`
- `tenants`

### Columns referenced
- `access_token_encrypted`
- `action`
- `actor`
- `brand`
- `business_rules`
- `cart_state`
- `category`
- `channel`
- `channel_message_id`
- `chunk_count`
- `color`
- `embedding`
- `config_version`
- `confirm_state`
- `conversation_id`
- `customer_id`
- `idempotency_key`
- `identity`
- `is_active`
- `language_detected`
- `last_message_at`
- `last_sync_at`
- `latency_ms`
- `message_type`
- `mode`
- `model_used`
- `models`
- `monthly_budget_mad`
- `name`
- `payment_method`
- `payment_status`
- `plan`
- `quantity`
- `role`
- `routing_rules`
- `settings`
- `size`
- `status`
- `sync_status`
- `system_prompt_override`
- `tenant_id`
- `tokens_in`
- `tokens_out`
- `tool_args`
- `tool_name`
- `tool_result`
- `tools_enabled`

### Tools referenced
- `add_to_cart`
- `analyze_image`
- `calculate_total`
- `check_stock`
- `create_order`
- `escalate_to_human`
- `get_order_status`
- `remove_from_cart`
- `search_products`

### Tool input/output fields referenced (inputs)
- `brand`
- `category`
- `color`
- `conversation_id`
- `idempotency_key`
- `in_stock_only`
- `limit`
- `price_max`
- `quantity`
- `size`

### Tool input/output fields referenced (outputs)
- `brand`
- `cart_state`
- `category`
- `color`
- `confirm_state`
- `conversations`
- `name`
- `order_items`
- `pg_trgm`
- `products`
- `quantity`
- `size`

### States/modes/cart states referenced
- `abandoned`
- `active`
- `ai`
- `ai_whisper`
- `confirmed`
- `empty`
- `escalated`
- `has_items`
- `manual`
- `order_created`
- `resolved`
- `summary_shown`

### Error codes referenced
- `AUTH_INVALID`
- `AUTH_REQUIRED`
- `BUDGET_EXCEEDED`
- `CART_EMPTY`
- `CART_FULL`
- `CONFIRM_REQUIRED`
- `CONVERSATION_NOT_FOUND`
- `DOCUMENT_NOT_FOUND`
- `DUPLICATE_ORDER`
- `FORBIDDEN`
- `INTERNAL_ERROR`
- `INVALID_QUANTITY`
- `MODEL_ERROR`
- `ORDER_NOT_FOUND`
- `OUT_OF_STOCK`
- `PRODUCT_NOT_FOUND`
- `RATE_LIMITED`
- `SYNC_IN_PROGRESS`
- `TENANT_NOT_FOUND`
- `TOOL_NOT_ALLOWED`
- `TOOL_VALIDATION_FAILED`
- `VARIANT_NOT_FOUND`
- `WEBHOOK_DUPLICATE`
- `WEBHOOK_SIGNATURE_INVALID`

### API endpoints referenced
- _None_

## Drift Findings (Post-Patch)
- Schema mismatches (tables/columns): **PASS**
- Invented tools: **PASS**
- Tool input/output field mismatches: **PASS**
- State/mode mismatches: **PASS**
- Error code mismatches: **PASS**
- Invented API endpoints: **PASS**

- No mismatches, invented artifacts, missing canonical mappings, or semantic contradictions were found after patching downstream docs.

## Patch Plan and Applied Fixes
| File | Section | Exact change required | Status |
| --- | --- | --- | --- |
| `docs/00_product_scope_mvp.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/01_system_architecture_overview.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/02_multi_tenancy_identity_authorization.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/04_agent_configuration_spec.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/05_conversation_engine_state_machine.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/06_routing_policies_guardrails.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/07_tooling_layer_tool_contracts.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/08_catalog_retrieval_system.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/09_commerce_flows.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/10_whatsapp_byok_spec.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/11_web_widget_spec.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/12_human_handoff_shared_inbox.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/13_observability_cost_budget.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/14_reliability_performance.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/15_security_compliance.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/16_model_layer_deployment_strategy.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/17_evaluation_qa_framework.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/18_pilot_playbooks_per_vertical.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |
| `docs/19_implementation_plan_milestones.md` | `Interfaces` / API listing bullets | Remove non-canonical `/api/...` method+path references and related endpoint-registry claims; keep only canonical contract statements (tools, schema, states, errors). | Applied |

## Re-run Confirmation
- Schema drift: **PASS**
- Tool drift: **PASS**
- State drift: **PASS**
- Error drift: **PASS**
- Architecture drift vs `docs/canonical/locked_decisions.md`: **PASS**
- Endpoint drift (invented `/api/...` paths): **PASS**
- Cross-document semantic contradictions: **PASS**
