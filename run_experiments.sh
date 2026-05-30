#!/usr/bin/env bash
# run_experiments.sh
# Automates Locust benchmarking across 1, 2, 4, and 8 pod replicas.
#
# Usage:
#   export SERVICE_IP=35.223.85.181
#   export SERVICE_PORT=31486
#   bash run_experiments.sh

set -euo pipefail

DEPLOYMENT="cloudeco-deployment"
LOCUST_FILE="./locust/locustfile.py"
SERVICE_IP="${SERVICE_IP:-35.223.85.181}"
SERVICE_PORT="${SERVICE_PORT:-31486}"
HOST="http://${SERVICE_IP}:${SERVICE_PORT}"
RESULTS_DIR="./results"
RAMP_RATE=5
RUN_TIME="90s"

mkdir -p "$RESULTS_DIR"

for PODS in 1 2 4 8; do
  echo "============================================"
  echo "Scaling to $PODS pod(s)..."
  echo "============================================"

  kubectl scale deployment "$DEPLOYMENT" --replicas="$PODS"
  kubectl rollout status deployment/"$DEPLOYMENT" --timeout=180s

  MAX_USERS=$(( PODS * 20 ))
  echo "Running Locust: $MAX_USERS users, ramp $RAMP_RATE/s, duration $RUN_TIME"

  locust \
    -f "$LOCUST_FILE" \
    --host "$HOST" \
    --headless \
    -u "$MAX_USERS" \
    -r "$RAMP_RATE" \
    --run-time "$RUN_TIME" \
    --csv "${RESULTS_DIR}/pods_${PODS}" \
    --html "${RESULTS_DIR}/pods_${PODS}_report.html" \
    --exit-code-on-error 0

  echo "Results saved to ${RESULTS_DIR}/pods_${PODS}*"
  echo ""
done

echo "All experiments complete. Results in: $RESULTS_DIR"
