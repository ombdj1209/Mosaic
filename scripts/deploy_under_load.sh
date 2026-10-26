#!/usr/bin/env bash
# Proves deploys do not lose or duplicate background work:
#   1. stage an import of IMPORT_ROWS bookings and enqueue it
#   2. redeploy DEPLOYS times while it runs (Kamal stops workers with SIGTERM;
#      Active Job Continuations checkpoint and resume)
#   3. assert every row was applied exactly once
set -euo pipefail
DEPLOYS="${DEPLOYS:-50}"
IMPORT_ROWS="${IMPORT_ROWS:-100000}"
TENANT="${TENANT:-kliniek-amstel}"

IMPORT_ID=$(bin/rails runner "puts Scripts::StageImport.call(tenant_slug: '$TENANT', rows: $IMPORT_ROWS)" | tail -1)
echo "staged import $IMPORT_ID with $IMPORT_ROWS rows"

for i in $(seq 1 "$DEPLOYS"); do
  kamal app boot --roles=job >/dev/null   # new container, old one drained with SIGTERM
  echo "deploy $i/$DEPLOYS done"
done

bin/rails runner "Scripts::CheckImport.call(tenant_slug: '$TENANT', import_id: '$IMPORT_ID')"
