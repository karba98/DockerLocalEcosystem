#!/bin/bash
set -euo pipefail
cd /app/fooocus

attempt() {
  echo "[Fooocus] Launching with CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-<unset>}"
  python launch.py --listen 0.0.0.0 --port 8084 || return 1
  return 0
}

if attempt; then
  exit 0
fi

echo "[Fooocus] First attempt failed. Checking for unsupported architecture..."
# We cannot call docker logs from inside container; detect by stderr pattern quickly re-running a tiny torch check.
python - <<'PY'
import torch, sys
try:
    if torch.cuda.is_available():
        # Force a simple op to load kernels
        a=torch.tensor([1.0]).cuda()
        print('CUDA_OK')
    else:
        print('NO_CUDA')
except Exception as e:
    print('CUDA_ERROR:', e)
PY

if grep -qi 'CUDA_ERROR:' <<<"$(tail -n 20 /root/.cache/pip/log/debug.log 2>/dev/null || true)"; then
  echo "[Fooocus] Detected CUDA related error, retrying on CPU."
  export CUDA_VISIBLE_DEVICES=""
  attempt || { echo "[Fooocus] Failed also on CPU."; exit 1; }
else
  echo "[Fooocus] Could not determine a CUDA architecture error. Not forcing CPU automatically."; exit 1
fi
