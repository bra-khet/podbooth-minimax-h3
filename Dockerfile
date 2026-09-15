# PodBooth MiniMax H3 — RunPod Serverless worker (I2V / FL2VA)
#
# Own CUDA 12.8 Comfy base. huchukato/comfyui-qwenvl-runpod:cu13-mmh3 is a
# *reference* for "what a working H3 Comfy box contains", not a FROM.
# We keep: ComfyUI ≥ 0.30 (native MiniMaxH3ImageToVideo), ffmpeg, Manager,
# extra_model_paths on /runpod-volume. We drop: Jupyter, FileBrowser,
# first-boot model wget, QwenVL prompt-enhancer, TensorRT/RIFE, Wan nodes.
#
# Do NOT wget MiniMax H3 checkpoints. FL2VA + encoder + VAEs live on the
# network volume. A baked H3 image is hundreds of GB.

FROM runpod/pytorch:1.2.0-cu1281-torch280-ubuntu2404

ARG COMFYUI_VERSION=v0.35.2

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV COMFY_DIR=/ComfyUI
ENV COMFY_PYTHON=python3
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        ffmpeg \
        wget \
        curl \
        ca-certificates \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Native H3 nodes shipped in ComfyUI ≥ 0.30.0. Pin a current stable tag.
RUN git clone --depth 1 --branch "${COMFYUI_VERSION}" \
        https://github.com/comfyanonymous/ComfyUI.git /ComfyUI \
    && python3 -m pip install --no-cache-dir -r /ComfyUI/requirements.txt

# Manager is the usual operator toolbox; H3 I2V itself is comfy-core.
RUN git clone --depth 1 \
        https://github.com/Comfy-Org/ComfyUI-Manager.git /ComfyUI/custom_nodes/ComfyUI-Manager \
    && if [ -f /ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt ]; then \
         python3 -m pip install --no-cache-dir -r /ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt; \
       fi

# Serverless I/O spine. Gradio lives on the laptop, not in this image.
RUN python3 -m pip install --no-cache-dir \
        "runpod>=1.7.0" \
        "websocket-client>=1.7.0" \
        "requests>=2.31.0"

# Sage Attention is a speed win on H100 when the wheel exists; fail open if not.
RUN python3 -m pip install --no-cache-dir sageattention \
    || echo "WARN: sageattention wheel not installed; Comfy will use default attention"

COPY handler.py /handler.py
COPY h3_graph.py /h3_graph.py
COPY extra_model_paths.yaml /ComfyUI/extra_model_paths.yaml
COPY workflows /workflows
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && mkdir -p /ComfyUI/input /ComfyUI/output /ComfyUI/temp

# Serverless: ComfyUI + handler only.
CMD ["/entrypoint.sh"]
