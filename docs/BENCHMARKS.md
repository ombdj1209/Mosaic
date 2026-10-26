# Benchmarks

**Measured** rows state their environment. **Target** rows are acceptance
criteria to measure with the listed command; fill in the result, hardware and
commit when you run them.

## Measured (authoring sandbox)

Environment: 1 vCPU Intel Xeon 2.8 GHz, Ruby 3.2.3, OpenSSL 3.0.13.

| Operation | Result |
| --- | --- |
| Encrypt one PII field (AES 256 GCM, authenticated context) | 128,745 per second |
| Decrypt one PII field | 194,404 per second |
| Unwrap a subject DEK | 181,228 per second |
| Append to the audit hash chain (pure Ruby part) | 19,111 per second |
| Verify a 20,000 entry audit chain | 925 ms |

Rendering a calendar day with 40 bookings costs well under a millisecond of
crypto; the database round trip dominates.

## Targets

| Metric | Target | How |
| --- | --- | --- |
| Booking create p99 at 300 req/s, one 4 vCPU app host | under 150 ms | `k6 run loadtest/k6/bookings.js` |
| 500 concurrent attempts on one slot | exactly 1 created, 499 conflicts | `k6 run loadtest/k6/contention.js` (threshold enforces it) |
| Jobs lost / duplicated across 50 deploys during a 100k row import | 0 / 0 | `scripts/deploy_under_load.sh` |
| Erasure end to end (key, ledger, notes, messages, audit) | under 60 s | `compliance.erasure_completed` event `seconds` |
| Cross region writes | 0 (CI raises) | `test/compliance/residency_test.rb` |
| Packwerk violations | trending to 0, never up | `bin/packwerk_ratchet` |
| `bin/ci` wall time locally | under 5 min | `time bin/ci` |
