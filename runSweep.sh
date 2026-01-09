#!/usr/bin/env bash
set -euo pipefail

#rm -rf /tmp/bybroa_state

N="${1:-4}"
SCRIPT="${2:-DeckCoherenceSweep.m}"
SCRIPT="${SCRIPT%.m}"
HERE="$(pwd)"

MATLAB="$HOME/matlab/launch_matlab.sh"
PIDS=()

cleanup() {
  echo "Stopping MATLAB workers..."
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait || true
  exit 0
}

trap cleanup SIGINT SIGTERM

for i in $(seq 1 "$N"); do
  WORKER_ID="w${i}" "$MATLAB" -nodisplay -nosplash -r \
    "try, cd('$HERE'); run('${SCRIPT}.m'); catch ME, disp(getReport(ME,'extended')); end; exit" \
    > "worker_${i}.out" 2>&1 &
  PIDS+=("$!")
done

wait
