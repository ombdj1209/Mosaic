# ADR 0001: Modular monolith with enforced boundaries before services

**Status:** accepted

## Context

The scheduling product grew as one Rails app: models reach into each other,
callbacks chain across domains, and any change risks a distant regression. The
reflex answer is microservices. The cost is network failure modes, distributed
transactions, duplicated infrastructure and a long migration with no feature
work, before anyone knows where the real seams are.

## Decision

Split the monolith into **packs** first, enforce the boundaries mechanically,
and extract a service only where a boundary has proven stable and the
operational case is real.

* `packs-rails` gives each domain its own `app/` tree.
* Packwerk enforces **dependencies** (`package.yml` lists what a pack may use)
  and, with `packwerk-extensions`, **privacy**: other packs may only call
  constants under `app/public` (`Patients::API`, `Scheduling::API`, ...).
* `bin/packwerk_ratchet` lets legacy violations exist in `package_todo.yml`
  but fails CI if their number grows. Debt can only go down.
* The dependency graph is acyclic by policy. When `ai_triage` needed to tell
  `compliance` about a review, it emits a `Rails.event` instead of calling
  `Compliance`, because `compliance` already depends on `ai_triage`.

```
platform <── identity
   ▲
   ├── patients ◀── scheduling ──▶ billing
   │                  ▲
   ├── ai_triage ◀── compliance ──▶ patients, scheduling, identity
```

## Consequences

* Boundary violations are build failures, not code review opinions.
* The first extraction (`services/notifications`) needed no refactoring inside
  Mosaic: the outbox was already the only way events left the scheduling pack.
* Packs still share one deploy and one process. That is the point: modularity
  without paying the distributed systems tax until it is worth it.
