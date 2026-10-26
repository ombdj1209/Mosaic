# ADR 0003: Regional shards and a residency guard

**Status:** accepted

## Context

German clinics require patient data to stay in Germany; Dutch clinics prefer the
Netherlands. A single database in one region fails the first requirement; one
app per country multiplies operations.

## Decision

* One control plane database (tenants, API keys, erasure ledger) and one data
  database per region (`eu_de`, `eu_nl`), using Rails horizontal sharding
  (`TenantRecord.connects_to shards:`).
* `Mosaic::TenantShard` middleware resolves the tenant (API key or subdomain),
  pins the request to the tenant's shard with `connected_to`, and wraps it in
  `prohibit_shard_swapping` so application code cannot switch region mid request.
  Unknown tenants get a 404 before any tenant table is touched.
* Jobs including `Platform::TenantJob` get the same pinning from their
  `tenant_id` argument.
* `Compliance::ResidencyGuard` subscribes to `sql.active_record` and checks
  every INSERT, UPDATE and DELETE **in the subscriber's start callback, before
  the statement executes**: the target database must equal the tenant's region,
  and a write to a shard with no tenant in scope is a violation. It raises in
  development and test (CI fails) and reports in production.

## Consequences

* Residency is enforced in three independent layers: routing, swap prohibition,
  and a statement level guard that does not trust call sites.
* Cross tenant analytics need an explicit pipeline (per region aggregation),
  which is the correct friction for health data.
* Moving a tenant between regions is a migration with its own runbook
  (`region` is `attr_readonly`).
