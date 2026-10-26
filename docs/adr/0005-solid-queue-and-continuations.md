# ADR 0005: Solid Queue and Active Job Continuations instead of Sidekiq and Redis

**Status:** accepted

## Context

The legacy stack ran Sidekiq on Redis: another stateful system to operate and
back up, and long jobs (calendar imports, erasures) that restarted from scratch
whenever a deploy stopped a worker, or worse, partially re ran.

## Decision

* Solid Queue (jobs in their own Postgres database), Solid Cache and Solid
  Cable. Recurring tasks replace sidekiq-cron.
* Long jobs use Active Job Continuations (Rails 8.1): explicit `step`s with a
  persisted cursor (`step.advance! from: row.id`). An interrupted job resumes at
  the last checkpoint on the new container.
* Steps are also idempotent on their own (`applied_booking_id`, the shredded key
  check, `insert ... unique_by`), so a resume from a slightly stale cursor
  cannot duplicate work.

Migration from Sidekiq (docs/MODERNISATION.md, stage v2) runs both adapters side
by side per queue, drains Sidekiq queue by queue, and removes Redis last.

## Consequences

* One less stateful system; job state is in the same backup and point in time
  recovery story as everything else.
* `scripts/deploy_under_load.sh` is the acceptance test: 50 deploys during a
  100k row import, then a check that every row was applied exactly once.
