# Modernisation path

Mosaic ships in its end state. This document is the playbook for getting a
real legacy Rails monolith there without a feature freeze, one reversible stage
at a time. Each stage is a series of small PRs, deployable on its own.

| Stage | Goal | Done when |
| --- | --- | --- |
| v0 baseline | Measure before changing anything | Baseline numbers recorded: Packwerk violations, p95/p99 of key endpoints, job failure and duplicate rates, CI time |
| v1 boundaries | Packs with enforced dependencies and privacy | `bin/packwerk check` green with a `package_todo.yml` baseline; ratchet in CI |
| v2 jobs | Sidekiq and Redis replaced by Solid Queue; long jobs resumable | Redis removed; 50 deploys during an import lose and duplicate nothing |
| v3 residency | Tenant data in regional shards | Residency test in CI; no cross region writes in production reports for 30 days |
| v4 extraction | First service extracted behind an outbox | Notifications served by the new service; old code path deleted |
| v5 compliance | Crypto shredding, tamper evident audit, AI decision log | Erasure and restore drill passes; nightly chain verification green |

## v1: boundaries

1. Add `packs-rails`, `packwerk`, `packwerk-extensions`. Create packs for
   domains, move files with `git mv` only (no behaviour change in the PR).
2. `bin/packwerk update-todo` records every existing violation. Set the ratchet
   baseline (`bin/packwerk_ratchet --update`).
3. For each pack, introduce `app/public/<pack>/api.rb` and move callers over.
   Every PR that removes violations lowers the baseline automatically.
4. Break cycles with events (`Rails.event` or the outbox), not with "shared"
   packs that become the new monolith.

## v2: Sidekiq to Solid Queue

1. Add Solid Queue with its own database. Route **one low risk queue** to it
   (`queue_adapter` per job class), keep Sidekiq for the rest.
2. Make each job idempotent before moving it (unique keys, `insert ...
   unique_by`, "already done" checks). Retries plus a different adapter will
   expose every hidden assumption.
3. Rewrite long jobs as continuations with explicit steps and cursors.
4. Move queues one by one; let Sidekiq drain each before removing its routing.
5. Move cron entries to `config/recurring.yml`. Remove Redis last.

## v3: regional shards

1. Add the shard databases and `TenantRecord`. New tables go to shards from day one.
2. For each existing table: create it on the shards, backfill per tenant (batched,
   idempotent, resumable), then dual write behind a flag, compare, switch reads,
   stop writing the old table.
3. Turn the residency guard on in `:report` mode in production first; move to
   `:raise` in CI immediately.

## v4: extract notifications

1. Route the side effect through the outbox inside the monolith first.
2. Stand up the service consuming the same events in shadow mode (it records
   but does not send). Compare outputs.
3. Flip sending to the service; delete the in monolith code path.

## v5: compliance

1. Introduce subject keys and encrypt new writes; backfill existing rows per
   tenant with a continuation job.
2. Add the erasure ledger and the restore drill to the runbook before
   advertising erasure as complete.
3. Add the audit chain and the nightly verification job.
