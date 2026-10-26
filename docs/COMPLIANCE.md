# Regulatory mapping

Mosaic is a portfolio system. This maps design decisions to the rules that
motivated them; it is not legal advice.

| Requirement | Source | Implementation |
| --- | --- | --- |
| Right to erasure | GDPR art. 17 | Per subject DEK destroyed (`Patients::API.shred!`), free text scrubbed, `EraseSubjectJob` with resumable steps, request tracked in `erasure_requests` |
| Erasure must hold for backups | GDPR art. 17 with supervisory authority guidance on backups | Control plane `erasure_ledger`; `compliance:reapply_erasures` runs after every restore; covered by `erasure_test.rb` |
| Data minimisation | GDPR art. 5(1)(c) | Events and invoices carry ids, not PII; triage decisions keep labels only |
| Security of processing | GDPR art. 32 | AES 256 GCM with authenticated context, keyed blind index, KEK in KMS in production, PII filtered from logs |
| Data residency for health data | Customer contracts and national health data rules | Regional shards, pinned requests and jobs, statement level residency guard |
| Integrity of records | Accountability, GDPR art. 5(2) | Hash chained, append only audit log (trigger) with nightly verification |
| Record keeping for automated decisions | EU AI Act logging and human oversight logic | `triage_decisions`: model, prompt hash, confidence, reviewer, override |
| Transparency to people interacting with AI | EU AI Act transparency obligations | Automation notice returned with every triaged message; `disclosed` stored per decision |

High risk AI obligations under Annex III were provisionally postponed to
December 2027 by the 2026 omnibus agreement; check the final text before
relying on dates.
