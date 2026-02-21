# Environment Variables

All stored in Railway. Never in code or client bundles.

| Variable | Required | Example | Notes |
| --- | --- | --- | --- |
| SUPABASE_URL | Yes | https://xxx.supabase.co |  |
| SUPABASE_ANON_KEY | Yes | eyJ... | Public key for client auth |
| SUPABASE_SERVICE_ROLE_KEY | Yes | eyJ... | Backend only. Never expose. |
| GROQ_API_KEY | Yes | gsk_... | Primary chat model provider |
| DEEPINFRA_API_KEY | Yes | di_... | Reasoning model provider |
| GOOGLE_AI_API_KEY | Yes | AI... | Vision model (Gemini) |
| OPENAI_API_KEY | Yes | sk-... | Embeddings (text-embedding-3-small) |
| UPSTASH_REDIS_URL | Yes | redis://... | Session cache + locks |
| UPSTASH_REDIS_TOKEN | Yes |  |  |
| SENTRY_DSN | Yes | https://...@sentry.io/... | Error tracking |
| RESEND_API_KEY | Yes | re_... | Transactional email |
| FIRECRAWL_API_KEY | No | fc-... | Website scraping for knowledge base |
| ENCRYPTION_KEY | Yes | 32-byte hex | For encrypting channel/ecommerce tokens in DB |
| JWT_SECRET | Yes |  | Should match Supabase JWT secret |
| CORS_ORIGINS | Yes | https://app.aidy.ma,https://*.aidy.ma | Allowed frontend origins |
| ENVIRONMENT | Yes | production | production, staging, development |
