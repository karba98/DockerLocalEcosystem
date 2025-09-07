#!/bin/sh
# Robust entrypoint for Ollama
set -eu

MODEL="${OLLAMA_AUTO_PULL:-llama2}"
MAX_WAIT="${OLLAMA_MAX_WAIT:-40}"  # segundos

echo "[ollama-entrypoint] Starting ollama server..."
ollama serve &
SERVER_PID=$!

echo "[ollama-entrypoint] Waiting for server readiness (timeout ${MAX_WAIT}s)..."
i=0
until [ $i -ge "$MAX_WAIT" ]; do
	# Intentar listar modelos (devuelve error si todavía no responde)
	if ollama list >/dev/null 2>&1; then
		echo "[ollama-entrypoint] Server is ready."
		break
	fi
	i=$((i+1))
	sleep 1
done

if [ $i -ge "$MAX_WAIT" ]; then
	echo "[ollama-entrypoint][WARN] Server not ready after ${MAX_WAIT}s; continuing anyway."
fi

if [ -n "$MODEL" ] && ! ollama list 2>/dev/null | grep -q "^$MODEL"; then
	echo "[ollama-entrypoint] Pulling model: $MODEL"
	if ! ollama pull "$MODEL"; then
		echo "[ollama-entrypoint][WARN] Could not pull model '$MODEL'." >&2
	fi
else
	echo "[ollama-entrypoint] Model '$MODEL' already present or variable empty; skipping pull."
fi

echo "[ollama-entrypoint] All background tasks set. Handing over control (PID $SERVER_PID)."
wait "$SERVER_PID"
echo "[ollama-entrypoint] Server process exited."
