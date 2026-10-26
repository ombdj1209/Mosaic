// Steady booking load across random slots and resources.
//   k6 run -e BASE=http://localhost:3000 -e TOKEN=mos_... -e RESOURCES=<uuid,uuid> -e PATIENT=<uuid> -e RATE=300 loadtest/k6/bookings.js
import http from "k6/http";
import { check } from "k6";

const resources = (__ENV.RESOURCES || "").split(",");

export const options = {
  scenarios: {
    book: { executor: "constant-arrival-rate", rate: Number(__ENV.RATE || 100), timeUnit: "1s", duration: __ENV.DURATION || "1m", preAllocatedVUs: 100, maxVUs: 1000 },
  },
  thresholds: { "http_req_duration{expected_response:true}": ["p(95)<100", "p(99)<150"], checks: ["rate>0.99"] },
};

export default function () {
  const day = 1 + Math.floor(Math.random() * 300);
  const start = new Date(Date.UTC(2027, 0, 1, 8, 0) + day * 86400000 + Math.floor(Math.random() * 40) * 900000);
  const end = new Date(start.getTime() + 900000);
  const res = http.post(
    `${__ENV.BASE}/api/v1/bookings`,
    JSON.stringify({ booking: { resource_id: resources[Math.floor(Math.random() * resources.length)], patient_id: __ENV.PATIENT, starts_at: start.toISOString(), ends_at: end.toISOString() } }),
    { headers: { "content-type": "application/json", authorization: `Bearer ${__ENV.TOKEN}`, "idempotency-key": `${__VU}-${__ITER}-${Date.now()}` } }
  );
  check(res, { "created or conflict": (r) => r.status === 201 || r.status === 409 });
}
