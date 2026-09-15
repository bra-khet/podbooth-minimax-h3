#!/bin/bash
# PodBooth MiniMax H3 worker entrypoint.
# Starts ComfyUI, waits until :8188 answers, then execs the RunPod handler.
set -euo pipefail

PYTHON="${COMFY_PYTHON:-python3}"
if ! command -v "${PYTHON}" >/dev/null 2>&1; then
    PYTHON="python"
fi

COMFY_DIR="${COMFY_DIR:-/ComfyUI}"
# CHANGED: Sage is detected at boot instead of hard-coded from the old huchukato image.
# WHY: This CUDA 12.8 base installs sageattention if a wheel exists; otherwise Comfy uses default attention.
if [ -z "${COMFY_EXTRA_ARGS+x}" ]; then
    if "${PYTHON}" -c "import sageattention" >/dev/null 2>&1; then
        COMFY_EXTRA_ARGS="--use-sage-attention --disable-auto-launch"
    else
        COMFY_EXTRA_ARGS="--disable-auto-launch"
    fi
fi
COMFY_WAIT_SECONDS="${COMFY_WAIT_SECONDS:-300}"

echo "Starting ComfyUI from ${COMFY_DIR} with: ${PYTHON} main.py --listen ${COMFY_EXTRA_ARGS}"
# shellcheck disable=SC2086
"${PYTHON}" "${COMFY_DIR}/main.py" --listen ${COMFY_EXTRA_ARGS} &

echo "Waiting for ComfyUI on http://127.0.0.1:8188/ (max ${COMFY_WAIT_SECONDS}s)..."
wait_count=0
while [ "${wait_count}" -lt "${COMFY_WAIT_SECONDS}" ]; do
    if curl -sf http://127.0.0.1:8188/ >/dev/null 2>&1; then
        echo "ComfyUI is ready after ${wait_count}s"
        break
    fi
    echo "Waiting for ComfyUI... (${wait_count}/${COMFY_WAIT_SECONDS})"
    sleep 2
    wait_count=$((wait_count + 2))
done

if [ "${wait_count}" -ge "${COMFY_WAIT_SECONDS}" ]; then
    echo "Error: ComfyUI failed to start within ${COMFY_WAIT_SECONDS} seconds"
    exit 1
fi

echo "Starting the handler..."
exec "${PYTHON}" /handler.py
