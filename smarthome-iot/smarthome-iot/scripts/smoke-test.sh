#!/bin/bash
# smoke-test.sh — Pengujian cepat end-to-end sistem Smart Home IoT
# Jalankan SETELAH terraform apply selesai
# Penggunaan: bash scripts/smoke-test.sh

set -euo pipefail

CLOUDRUN_URL=$(terraform -chdir=terraform output -raw cloudrun_service_url 2>/dev/null || echo "")
PROJECT_ID=$(terraform -chdir=terraform output -raw project_id 2>/dev/null || echo "cloud-computing-495107")
PUBSUB_TOPIC=$(terraform -chdir=terraform output -raw pubsub_sensor_topic 2>/dev/null || echo "iot-topic")

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

echo "==========================================="
echo " SmartHome IoT — Smoke Test Suite"
echo " $(date)"
echo "==========================================="

# TC-01: Cloud Run Health Check
info "TC-01: Cek Cloud Run /health endpoint..."
if [ -n "$CLOUDRUN_URL" ]; then
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$CLOUDRUN_URL/health" \
    -H "Authorization: Bearer $(gcloud auth print-identity-token 2>/dev/null || echo '')" \
    --max-time 10 || echo "000")
  [ "$STATUS" = "200" ] && pass "Cloud Run /health → HTTP $STATUS" || fail "Cloud Run /health → HTTP $STATUS (expected 200)"
else
  fail "TC-01: CLOUDRUN_URL tidak ditemukan (jalankan terraform output dulu)"
fi

# TC-02: Pub/Sub Publish Test
info "TC-02: Publish pesan sensor test ke Pub/Sub..."
TEST_MSG=$(echo -n '{
  "device_id":"smoke-test-001",
  "sensor_type":"temperature",
  "value":25.5,
  "timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}' | base64)

MSG_ID=$(gcloud pubsub topics publish "$PUBSUB_TOPIC" \
  --project="$PROJECT_ID" \
  --message='{"device_id":"smoke-test-001","sensor_type":"temperature","value":25.5,"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
  --format="value(messageIds[0])" 2>/dev/null || echo "")
[ -n "$MSG_ID" ] && pass "TC-02: Pesan terkirim ke Pub/Sub, messageId: $MSG_ID" || fail "TC-02: Gagal kirim pesan ke Pub/Sub"

# TC-03: Cloud SQL Instance Status
info "TC-03: Cek status Cloud SQL instance..."
SQL_STATE=$(gcloud sql instances describe iot-db --project="$PROJECT_ID" \
  --format="value(state)" 2>/dev/null || echo "UNKNOWN")
[ "$SQL_STATE" = "RUNNABLE" ] && pass "TC-03: Cloud SQL iot-db status RUNNABLE" || fail "TC-03: Cloud SQL status $SQL_STATE (expected RUNNABLE)"

# TC-04: Cloud Storage Bucket Exists
info "TC-04: Cek bucket Cloud Storage..."
BUCKET_NAME="smarthome-sensor-logs-${PROJECT_ID}"
gsutil ls "gs://$BUCKET_NAME" &>/dev/null \
  && pass "TC-04: Bucket gs://$BUCKET_NAME accessible" \
  || fail "TC-04: Bucket gs://$BUCKET_NAME tidak ditemukan"

# TC-05: Cloud Run Alert Threshold (suhu > 35°C)
info "TC-05: Publish pesan anomali (suhu 40°C) untuk uji alert pipeline..."
ALERT_MSG_ID=$(gcloud pubsub topics publish "$PUBSUB_TOPIC" \
  --project="$PROJECT_ID" \
  --message='{"device_id":"smoke-test-002","sensor_type":"temperature","value":40.0,"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
  --format="value(messageIds[0])" 2>/dev/null || echo "")
[ -n "$ALERT_MSG_ID" ] && pass "TC-05: Pesan anomali terkirim (ID: $ALERT_MSG_ID) — cek alert topic" || fail "TC-05: Gagal publish pesan anomali"

echo "==========================================="
echo " Smoke test selesai — cek hasil di atas"
echo " Lihat log detail: gcloud logging read 'resource.type=cloud_run_revision' --limit=20"
echo "==========================================="
