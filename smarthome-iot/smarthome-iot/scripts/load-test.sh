#!/bin/bash
# load-test.sh — Load test untuk demonstrasi auto-scaling Cloud Run
# Membutuhkan: k6 (https://k6.io/docs/get-started/installation/)
# Penggunaan: bash scripts/load-test.sh [CLOUDRUN_URL]

set -euo pipefail

CLOUDRUN_URL="${1:-$(terraform -chdir=terraform output -raw cloudrun_service_url 2>/dev/null || echo '')}"
PROJECT_ID=$(terraform -chdir=terraform output -raw project_id 2>/dev/null || echo "cloud-computing-495107")
PUBSUB_TOPIC=$(terraform -chdir=terraform output -raw pubsub_sensor_topic 2>/dev/null || echo "iot-topic")

if [ -z "$CLOUDRUN_URL" ]; then
  echo "Error: CLOUDRUN_URL tidak ditemukan. Jalankan: bash scripts/load-test.sh <URL>"
  exit 1
fi

echo "========================================"
echo " SmartHome IoT — Load Test"
echo " Target: $CLOUDRUN_URL"
echo " Waktu: $(date)"
echo "========================================"

# Cek apakah k6 tersedia
if ! command -v k6 &>/dev/null; then
  echo "[WARN] k6 tidak ditemukan. Menggunakan simulasi load dengan curl..."
  
  # Simulasi load: kirim 100 pesan dalam batch
  echo "[INFO] Mengirim 100 pesan sensor ke Pub/Sub untuk simulasi beban..."
  SUCCESS=0; FAIL=0
  for i in $(seq 1 100); do
    TEMP=$(python3 -c "import random; print(round(random.uniform(20,45),1))" 2>/dev/null || echo "28.5")
    MSG=$(gcloud pubsub topics publish "$PUBSUB_TOPIC" \
      --project="$PROJECT_ID" \
      --message="{\"device_id\":\"load-test-$(printf '%03d' $i)\",\"sensor_type\":\"temperature\",\"value\":$TEMP,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
      --format="value(messageIds[0])" 2>/dev/null || echo "")
    if [ -n "$MSG" ]; then ((SUCCESS++)); else ((FAIL++)); fi
    # Tampilkan progress setiap 10 pesan
    [ $((i % 10)) -eq 0 ] && echo "[INFO] Progress: $i/100 (OK: $SUCCESS, FAIL: $FAIL)"
  done
  
  echo ""
  echo "========================================"
  echo " Hasil Load Test (Simulasi)"
  echo "   Total pesan  : 100"
  echo "   Berhasil     : $SUCCESS"
  echo "   Gagal        : $FAIL"
  echo "   Success rate : $(echo "scale=1; $SUCCESS * 100 / 100" | bc)%"
  echo ""
  echo " Monitor auto-scaling di:"
  echo " https://console.cloud.google.com/run/detail/asia-southeast2/sensor-processor/metrics"
  echo "========================================"
  exit 0
fi

# k6 load test script
cat > /tmp/k6-smarthome.js << 'K6SCRIPT'
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '30s', target: 10 },   // Ramp-up: 0 → 10 VU dalam 30 detik
    { duration: '60s', target: 10 },   // Steady: 10 VU selama 1 menit
    { duration: '30s', target: 30 },   // Spike: naik ke 30 VU
    { duration: '60s', target: 30 },   // Steady: 30 VU selama 1 menit
    { duration: '30s', target: 0 },    // Ramp-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],  // 95% request < 2 detik
    errors: ['rate<0.05'],              // Error rate < 5%
  },
};

const CLOUDRUN_URL = __ENV.CLOUDRUN_URL;
const TOKEN = __ENV.GCP_TOKEN || '';

export default function () {
  const sensorData = JSON.stringify({
    device_id: `load-test-${Math.floor(Math.random() * 50)}`,
    sensor_type: Math.random() > 0.5 ? 'temperature' : 'motion',
    value: Math.round((20 + Math.random() * 20) * 10) / 10,
    timestamp: new Date().toISOString(),
  });

  const res = http.post(`${CLOUDRUN_URL}/`, sensorData, {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${TOKEN}`,
    },
  });

  const ok = check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 2s': (r) => r.timings.duration < 2000,
  });

  errorRate.add(!ok);
  sleep(0.1);
}
K6SCRIPT

echo "[INFO] Menjalankan k6 load test..."
GCP_TOKEN=$(gcloud auth print-identity-token 2>/dev/null || echo "") \
CLOUDRUN_URL="$CLOUDRUN_URL" \
k6 run /tmp/k6-smarthome.js

echo ""
echo "[INFO] Cek hasil di Cloud Monitoring dashboard:"
echo "  https://console.cloud.google.com/monitoring/dashboards"
