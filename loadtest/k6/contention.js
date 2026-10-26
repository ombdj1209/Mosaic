// 500 clients race for the same 30 minute slot. Exactly one may win.
//   k6 run -e BASE=http://localhost:3000 -e TOKEN=mos_... -e RESOURCE=<uuid> -e PATIENT=<uuid> loadtest/k6/contention.js
import http from "k6/http";
import { check } from "k6";
import { Counter } from "k6/metrics";

const created = new Counter("bookings_created");
const conflicts = new Counter("bookings_conflict");

export const options = {
  scenarios: { race: { executor: "per-vu-iterations", vus: 500, iterations: 1, maxDuration: "30s" } },
  thresholds: { bookings_created: ["count==1"], checks: ["rate==1"] },
};

export default function () {
  const res = http.post(
    `${__ENV.BASE}/api/v1/bookings`,
    JSON.stringify({ booking: { resource_id: __ENV.RESOURCE, patient_id: __ENV.PATIENT, starts_at: __ENV.STARTS || "2027-01-15T10:00:00Z", ends_at: __ENV.ENDS || "2027-01-15T10:30:00Z" } }),
    { headers: { "content-type": "application/json", authorization: `Bearer ${__ENV.TOKEN}`, "idempotency-key": `race-${__VU}` } }
  );
  if (res.status === 201) created.add(1);
  if (res.status === 409) conflicts.add(1);
  check(res, { "201 or 409 only": (r) => r.status === 201 || r.status === 409 });
}
