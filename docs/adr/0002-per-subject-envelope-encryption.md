# ADR 0002: Per subject envelope encryption and an erasure ledger

**Status:** accepted

## Context

GDPR article 17 requires erasing a person's data on request. Personal data in a
real system leaks into many places: rows, denormalised copies, caches, job
payloads, logs, search indexes, backups. Deleting rows misses most of them.

Active Record Encryption encrypts columns, but with application wide keys: it
protects data at rest, yet cannot make one person's data unreadable while
keeping everyone else's.

## Decision

1. **One data encryption key (DEK) per data subject**, generated at patient
   creation, stored only wrapped by a key encryption key (KEK) in `subject_keys`.
   In production the KEK lives in a KMS; `Patients::KeyRing` is the seam.
2. **All PII columns are AES 256 GCM ciphertext** under the subject's DEK, with
   the table, column and row id as authenticated data, so a ciphertext copied to
   another row or column fails to decrypt (`Patients::Crypto::Envelope`).
3. **Exact match search uses a keyed blind index** (HMAC SHA 256 of the
   normalised email), never the plaintext.
4. **Erasure = destroy the wrapped DEK.** Every ciphertext for that person,
   wherever it was copied, becomes noise at once. Free text that was never
   encrypted (booking notes, triage message bodies) is scrubbed by
   `Compliance::EraseSubjectJob`.
5. **Backups:** crypto shredding alone does not survive a restore, because the
   backup still holds the wrapped DEK. Every shredded key is recorded in the
   control plane `erasure_ledger` (separate database, separate backups), and
   `bin/rails compliance:reapply_erasures` must run after any shard restore,
   before the shard takes traffic. `erasure_test.rb` simulates exactly this.

## Consequences

* Erasure is O(1) for encrypted data and auditable (ledger + audit log).
* PII cannot be queried with SQL (no `WHERE name ILIKE`). Search by name would
  need a dedicated, encrypted search index; deliberately out of scope.
* Measured cost on one core: about 129k field encryptions and 194k decryptions
  per second (docs/BENCHMARKS.md), negligible next to a database round trip.
