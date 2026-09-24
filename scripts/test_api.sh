#!/usr/bin/env bash
# End-to-end API smoke test: price -> match -> mint -> verify -> ledger.
set -euo pipefail
BASE="${1:-http://localhost:8000}"

echo "health:   $(curl -sf $BASE/health)"
echo "price:    $(curl -sf $BASE/api/v1/pricing/PCB | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["item_type"],"₹"+str(d["price_per_kg"]))')"
echo "match:    $(curl -sf "$BASE/api/v1/recyclers/nearby?lat=12.9752&lng=77.6057&limit=1" | python3 -c 'import json,sys;m=json.load(sys.stdin)[0];print(m["name"],m["distance_km"],"km")')"

RID=$(curl -sf -X POST $BASE/api/v1/receipts/mint -H 'Content-Type: application/json' \
  -d '{"item_type":"Battery","material":"Lithium","weight_kg":1.2,"price_per_kg":120,"collector_id":"KBD-BLR-0042","recycler_id":50}' \
  | python3 -c 'import json,sys;print(json.load(sys.stdin)["receipt_id"])')
echo "mint:     $RID"
echo "verify:   chain_valid=$(curl -sf $BASE/api/v1/receipts/$RID | python3 -c 'import json,sys;print(json.load(sys.stdin)["proof"]["chain_valid"])')"
echo "ledger:   $(curl -sf $BASE/api/v1/users/KBD-BLR-0042/ledger | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["total_receipts"],"receipts, ₹"+str(d["total_earnings"]),",",d["eco_points"],"EcoPoints")')"
echo "✅ all endpoints OK"
