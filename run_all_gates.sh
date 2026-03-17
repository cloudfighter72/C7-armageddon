#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# run_all_gates.sh
#
# Located in: scripts/
# Coordinates execution of the two gate scripts and produces combined report
# Outputs to: ./scripts-results/run_all_gates[*].json
# ============================================================

# ---------- Inputs (override via env) ----------
REGION="${REGION:-us-east-2}"
INSTANCE_ID="${INSTANCE_ID:-i-0a5d350d674378a71}"
SECRET_ID="${SECRET_ID:-arn:aws:secretsmanager:us-east-2:185196963048:secret:lab_1c/rds/db_secrets07-bF0DYv}"
DB_ID="${DB_ID:-lab-1c-mysql}"

# toggles pass-through
REQUIRE_ROTATION="${REQUIRE_ROTATION:-false}"
CHECK_SECRET_POLICY_WILDCARD="${CHECK_SECRET_POLICY_WILDCARD:-true}"
CHECK_SECRET_VALUE_READ="${CHECK_SECRET_VALUE_READ:-true}"
EXPECTED_ROLE_NAME="${EXPECTED_ROLE_NAME:-}"

CHECK_PRIVATE_SUBNETS="${CHECK_PRIVATE_SUBNETS:-true}"

# output
OUT_JSON="${OUT_JSON:-./scripts-results/run_all_gates.json}"

# ---------- Helpers ----------
now_utc() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

have_file() { [[ -f "$1" ]]; }

badge_color() {
  local status="$1"
  local warnings_count="$2"
  if [[ "$status" == "FAIL" ]]; then echo "RED"; return; fi
  if [[ "$warnings_count" -gt 0 ]]; then echo "YELLOW"; return; fi
  echo "GREEN"
}

# ---------- Preconditions ----------
if [[ -z "$INSTANCE_ID" || -z "$SECRET_ID" || -z "$DB_ID" ]]; then
  echo "ERROR: You must set INSTANCE_ID, SECRET_ID, and DB_ID." >&2
  echo "Example:" >&2
  echo "  REGION=us-east-2 INSTANCE_ID=i-0dd6447b2f3ab96b8 SECRET_ID=arn:aws:secretsmanager:us-east-2:185196963048:secret:db-secret-MKWYB6 DB_ID=db-secret ./run_all-gates.sh" >&2
  exit 1
fi

if ! have_file "./gate_secrets_role.sh" || ! have_file "./gate_network_db.sh"; then
  echo "ERROR: Missing required gate scripts in scripts/ directory." >&2
  echo "Expected:" >&2
  echo "  .gate_secrets_role.sh" >&2
  echo "  .gate_network_db.sh" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found on PATH. Please install jq." >&2
  exit 1
fi

chmod +x ./gate_secrets_role.sh ./gate_network_db.sh || true

# Ensure results directory exists
mkdir -p "./scripts-results"

# ---------- Run Gate 1: Secrets + Role ----------
echo "=== Running Gate 1/2: secrets_role ==="
set +e
OUT_JSON="./run_all_gates_1.json" \
REGION="$REGION" INSTANCE_ID="$INSTANCE_ID" SECRET_ID="$SECRET_ID" \
REQUIRE_ROTATION="$REQUIRE_ROTATION" \
CHECK_SECRET_POLICY_WILDCARD="$CHECK_SECRET_POLICY_WILDCARD" \
EXPECTED_ROLE_NAME="$EXPECTED_ROLE_NAME" \
./gate_secrets_role.sh
rc1=$?
set -e

# ---------- Run Gate 2: Network + DB ----------
echo "=== Running Gate 2/2: network_db ==="
set +e
OUT_JSON="./run_all_gates_2.json" \
REGION="$REGION" INSTANCE_ID="$INSTANCE_ID" DB_ID="$DB_ID" \
CHECK_PRIVATE_SUBNETS="$CHECK_PRIVATE_SUBNETS" \
./gate_network_db.sh
rc2=$?
set -e

# ---------- Determine overall ----------
overall_exit=0
overall_status="PASS"

if [[ "$rc1" -ne 0 || "$rc2" -ne 0 ]]; then
  overall_status="FAIL"
  overall_exit=2
fi

# ---------- Parse warnings count (best-effort heuristic) ----------
warnings_1="$(grep -o '"warnings":[[][^]]*[]]' ./scripts-results/run_all_gates_1.json 2>/dev/null | wc -c | tr -d ' ')"
warnings_2="$(grep -o '"warnings":[[][^]]*[]]' ./scripts-results/run_all_gates_2.json 2>/dev/null | wc -c | tr -d ' ')"

warn_count=0
[[ "${warnings_1:-0}" -gt 15 ]] && warn_count=$((warn_count+1))
[[ "${warnings_2:-0}" -gt 15 ]] && warn_count=$((warn_count+1))

badge="$(badge_color "$overall_status" "$warn_count")"

# ---------- Emit combined JSON ----------
timestamp="$(now_utc)"

jq -n \
  --arg gate "all_gates" \
  --arg ts "$timestamp" \
  --arg region "$REGION" \
  --arg instance_id "$INSTANCE_ID" \
  --arg secret_id "$SECRET_ID" \
  --arg db_id "$DB_ID" \
  --arg badge "$badge" \
  --arg overall_status "$overall_status" \
  --argjson overall_exit "$overall_exit" \
  --argjson rc1 "$rc1" \
  --argjson rc2 "$rc2" \
  '{
    gate: $gate,
    timestamp_utc: $ts,
    region: $region,
    inputs: {
      instance_id: $instance_id,
      secret_id: $secret_id,
      db_id: $db_id
    },
    child_gates: [
      {
        name: "secrets_role",
        script: "gate_secrets_role.sh",
        result_file: "scripts-results/run_all_gates_1.json",
        exit_code: $rc1
      },
      {
        name: "network_db",
        script: "gate_network_db.sh",
        result_file: "scripts-results/run_all_gates_2.json",
        exit_code: $rc2
      }
    ],
    badge: {
      status: $badge,
      meaning: "GREEN=all pass, YELLOW=pass with warnings, RED=one or more failures"
    },
    status: $overall_status,
    exit_code: $overall_exit
  }' > "$OUT_JSON"

# ---------- Console summary ----------
echo ""
echo "===== SEIR Combined Gate Summary ====="
echo "Gate 1 (secrets_and_role) exit: $rc1  -> scripts-results/run_all_gates_1.json"
echo "Gate 2 (network_db)       exit: $rc2  -> scripts-results/run_all_gates_2.json"
echo "--------------------------------------"
echo "BADGE:  $badge"
echo "RESULT: $overall_status"
echo "Wrote:  $OUT_JSON"
echo "======================================"
echo ""

exit "$overall_exit"