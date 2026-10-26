# notifications

The first service extracted from the Mosaic monolith (stage v4, the strangler
step). It consumes booking events from Mosaic's transactional outbox and sends
patient notifications.

Contract: `POST /events` with `{"events": [{id, tenant_id, event_type, payload, ...}]}`.
The response lists every id it has durably stored, including ids it had already
seen: `{"accepted": [1, 2, 3]}`. Delivery from Mosaic is at least once; this
service makes it effectively once with a unique index on `(source, event_id)`.

It owns its own database and shares no tables with Mosaic. Notification
content is rendered from the event payload, which carries ids and times but no
patient PII, so this service never needs a decryption key.
