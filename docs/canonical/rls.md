> ⚠️ Canonical Spec File — Read-Only. Modify only through canonical-first change control.

# Tenant Isolation and RLS

All tables live in Supabase PostgreSQL. Every table has tenant_id (except tenants itself). RLS on all tables.

RLS: Owners can read/write their own tenant. Service role for creation.

RLS: Scoped by tenant_id. Unique constraint: (tenant_id, phone) and (tenant_id, email).

Multi-tenancy decision: Shared DB, tenant_id on every table, Supabase RLS. Defense-in-depth. Every query filtered by JWT. Automated isolation tests in CI.

## TODO (ambiguities from canonical source)

- TODO: Canonical source does not enumerate per-table SQL policy names/USING/WITH CHECK clauses beyond the high-level statements above (Aidy_Master_Reference.docx section 2 intro, 2.1 tenants note, 2.3 customers note).

<!-- Rationale note (Aidy_Technical_Spec_v3.docx §5 + Day 1 build plan): v3 explains tenant isolation as a mandatory security baseline and references CI red-team checks. -->
