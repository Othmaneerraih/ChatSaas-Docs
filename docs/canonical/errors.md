# Error Code Registry

All errors returned as JSON: { error: { code: string, message: string, details?: any } }. HTTP status codes follow REST conventions.

| Code | HTTP | Message | When |
| --- | --- | --- | --- |
| AUTH_REQUIRED | 401 | Authentication required | No JWT or expired JWT |
| AUTH_INVALID | 401 | Invalid credentials | Wrong password or token |
| FORBIDDEN | 403 | Access denied | User not owner of this tenant |
| TENANT_NOT_FOUND | 404 | Tenant not found | Invalid tenant_id or slug |
| CONVERSATION_NOT_FOUND | 404 | Conversation not found | Invalid conversation_id or wrong tenant |
| PRODUCT_NOT_FOUND | 404 | Product not found | Invalid product_id or not in tenant catalog |
| ORDER_NOT_FOUND | 404 | Order not found | Invalid order_id or wrong tenant/customer |
| DOCUMENT_NOT_FOUND | 404 | Document not found |  |
| VARIANT_NOT_FOUND | 404 | Product variant not found |  |
| DUPLICATE_ORDER | 409 | Order already exists | Idempotency key already used |
| CART_EMPTY | 422 | Cart is empty | Attempted create_order with empty cart |
| CONFIRM_REQUIRED | 422 | Customer confirmation required | create_order called without confirm_state = true |
| OUT_OF_STOCK | 422 | Product is out of stock | add_to_cart for product with stock = 0 |
| INVALID_QUANTITY | 422 | Invalid quantity | qty < 1 or qty > 99 |
| CART_FULL | 422 | Cart limit reached | More than 50 items |
| TOOL_NOT_ALLOWED | 403 | Tool not enabled for this agent | Agent called a tool not in tools_enabled |
| TOOL_VALIDATION_FAILED | 422 | Invalid tool arguments | Tool args don’t match JSON schema |
| RATE_LIMITED | 429 | Too many requests | Per-tenant or per-user rate limit exceeded |
| WEBHOOK_SIGNATURE_INVALID | 401 | Invalid webhook signature | Meta HMAC verification failed |
| WEBHOOK_DUPLICATE | 200 | Message already processed | Duplicate channel_message_id (returns 200 to prevent retry) |
| MODEL_ERROR | 502 | AI model unavailable | LLM API returned error or timeout |
| SYNC_IN_PROGRESS | 409 | Product sync already running | Concurrent sync attempt |
| BUDGET_EXCEEDED | 402 | Monthly budget exceeded | Tenant’s monthly_budget_mad reached |
| INTERNAL_ERROR | 500 | Internal server error | Unexpected error. Logged in Sentry. |
