# ADR 0004: Transactional outbox and an idempotent consumer

**Status:** accepted

## Context

Booking a slot must notify the patient. Calling the notifications system inside
the request couples latency and availability. Enqueueing a job after commit can
lose the event if the process dies between commit and enqueue; enqueueing
before commit can send a notification for a booking that rolled back.

## Decision

* `Platform::Outbox.publish!` writes an `outbox_events` row **in the same
  transaction and the same regional shard** as the booking. It refuses to run
  outside a transaction.
* `Platform::OutboxRelayJob` (Solid Queue recurring task, every 2 s) relays due
  events per shard with `FOR UPDATE SKIP LOCKED`, so several workers can relay
  in parallel without double sending, with exponential backoff on failure.
* Delivery is at least once. The notifications service stores
  `(source, event_id)` under a unique index and acknowledges ids it holds, so
  processing is effectively once.
* Events carry ids and times, never PII, so the consumer needs no decryption
  key and erasure needs no cross service coordination.

## Consequences

* "Booked but never notified" and "notified about a booking that does not
  exist" are both impossible.
* The relay adds up to about 2 s of notification latency, acceptable for this
  domain.
