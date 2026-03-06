# Consistency Checklist

Use this checklist before merging any documentation, design note, or implementation spec.

## Canonical Consistency Rules

- [ ] **No schema drift:** all schema references must match `docs/canonical/schema.md` exactly (table names, columns, constraints, and meanings).
- [ ] **No tool drift:** all tool names, arguments, and constraints must match `docs/canonical/tools.md` and `docs/canonical/tools_schemas.json`.
- [ ] **No state drift:** all lifecycle/mode/cart transitions and guards must match `docs/canonical/state_machine.md`.
- [ ] **No error drift:** all error references must match `docs/canonical/errors.md` (code, intent, and usage context).
- [ ] **Architecture lock:** architectural and stack decisions must respect `docs/canonical/locked_decisions.md`.

## Review Guidance

- If overlap exists with non-canonical documents, canonical files win.
- Do not invent fields, enums, states, tools, endpoints, or constraints.
- If canonical text is ambiguous, add a TODO with exact canonical citation location.
