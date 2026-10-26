# Runbook

## Restore a regional shard from backup

1. Restore into a new database; do **not** route traffic yet.
2. `DATABASE_URL_EU_DE=<restored> bin/rails compliance:reapply_erasures`
3. `bin/rails compliance:verify_audit` (a restore from before an incident may
   show the chain ending earlier; it must not show a broken link).
4. Switch `DATABASE_URL_EU_DE` and redeploy.

## Residency violation reported in production

The guard reports instead of raising in production. Find the event
`compliance.residency_violation` (message names tenant, region and SQL). Treat
it as a data incident: identify the rows written, move or delete them in the
wrong shard, and add a failing test before the fix.

## Outbox backlog growing

`SELECT count(*) FROM outbox_events WHERE published_at IS NULL` per shard. Check
`last_error`. Events are retried with backoff (max 5 min); nothing is dropped.
If the notifications service is down for long, no action is needed beyond
restoring it.

## Audit chain broken

`compliance.audit_chain_broken` names tenant, sequence and reason. The trigger
blocks UPDATE and DELETE, so a break means a superuser change or an edited
backup: escalate as a security incident.

## Triage fallbacks spike

`ai_triage.fallback` events rising means the LLM endpoint is failing or
returning invalid output. Messages still reach staff via the review queue; no
patient message is dropped.

## Deploy with long jobs running

Nothing special: continuation jobs checkpoint on SIGTERM and resume. To verify
after a risky release, run `scripts/deploy_under_load.sh` in staging.
