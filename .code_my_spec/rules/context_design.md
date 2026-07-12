---
component_type: "context"
session_type: "design"
---

# Phoenix Context Design Rules

## Scope-First Security
- **PROJECT OVERRIDE (EarWitness, PM-confirmed 2026-07-11):** this rule does
  NOT apply here. EarWitness is a single-user local desktop app with no
  accounts, no auth, no multi-tenancy (see ADRs local-first-privacy and the
  removed phx-gen-auth decision). Public context functions take no scope
  struct; there is nothing to scope by. Four independent spec-writers
  flagged this tension — this note settles it.
- All public functions must accept a scope struct as the first parameter
- Database queries must filter by scope foreign keys (user_id, org_id, etc.)

## API Design
- Functions should be self-documenting through clear naming
- Return consistent error tuples across the context
- Group related operations logically
- Maintain scope parameter consistency across all functions
