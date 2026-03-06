# Validation Report

## Inputs
- docs/canonical/schema.md
- docs/canonical/tools_schemas.json
- docs/appendix_a_api_reference.md

## Output Artifacts
- contracts/openapi.yaml
- contracts/tools.schemas.json
- contracts/schema_migrations.sql

## Validation Results
- APIs in docs match openapi.yaml: **PASS**
  - endpoint references in appendix: 0
  - endpoint paths in openapi: 0
- Tool references match JSON Schemas: **PASS**
  - referenced tools: 9
  - missing tools in compiled schema: []
- No schema elements missing from SQL stubs: **PASS**
  - missing tables in stubs: []
  - missing appendix-referenced columns in stubs: []

## Notes
- Canonical docs do not define concrete public HTTP/WS endpoint paths; openapi.yaml intentionally keeps `paths: {}` and models tool contracts via `x-tool-contracts`.
- SQL is scaffold-level and preserves table/column coverage while leaving detailed constraints/indexes/RLS as TODOs for migration authoring.
