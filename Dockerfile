# PodBooth MiniMax H3 — RunPod Serverless worker
#
# Base is the existing H3-capable Comfy image the operator already found:
#   huchukato/comfyui-qwenvl-runpod:cu13-mmh3
# (~9.5 GB compressed, ComfyUI 0.34.x at /ComfyUI, venv at /opt/comfyui-env,
# Sage Attention, CUDA 13). It is a *pod* template image; we replace its
# start.sh (Jupyter / FileBrowser / first-boot model fetch) with our
# serverless entrypoint.
#
# Do NOT wget MiniMax H3 checkpoints here. FL2VA/Ref2VA/text-encoder/VAE
# live on the network volume. A baked H3 image is hundreds of GB.
#
# Do NOT clone WanVideoWrapper / wanBlockswap / GGUF-FantasyTalking.

FROM huchukato/comfyui-qwenvl-runpod:cu13-mmh3

ENV PATH="/opt/comfyui-env/bin:${PATH}"
ENV VIRTUAL_ENV=/opt/comfyui-env
ENV PYTHONUNBUFFERED=1
ENV COMFY_DIR=/ComfyUI
ENV COMFY_PYTHON=/opt/comfyui-env/bin/python
# Kill any first-boot model provisioning the pod template might honor.
ENV download_minimax_h3=false
ENV DOWNLOAD_MODELS=false

WORKDIR /

RUN /opt/comfyui-env/bin/pip install --no-cache-dir \
        "runpod>=1.7.0" \
        "websocket-client>=1.7.0" \
        "requests>=2.31.0"

COPY handler.py /handler.py
COPY h3_graph.py /h3_graph.py
COPY extra_model_paths.yaml /ComfyUI/extra_model_paths.yaml
COPY workflows /workflows
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && mkdir -p /ComfyUI/input /ComfyUI/output /ComfyUI/temp

# Serverless: ComfyUI + handler only. Do not run the pod template start.sh.
CMD ["/entrypoint.sh"]
