# PodBooth MiniMax H3

RunPod Serverless worker + Python client + local Gradio panel for **MiniMax Hailuo H3** image-to-video.

Architecture is a clone of [bra-khet/podbooth-wan](https://github.com/bra-khet/podbooth-wan) (Wan 2.2 I2V / FLF2V). The product shape is the same booth: submit a job with the right knobs, poll RunPod, get an mp4 back. H3 replaces Wan’s dual-noise pair with **FL2VA** (`MiniMaxH3ImageToVideo`).

**This image is I2V / first+last frame (FL2VA) only.** Ref2VA is a **direct sibling** worker (`bra-khet/podbooth-minimax-h3-ref2va`) so each Docker image stays lightweight: one DiT, one graph, one endpoint. T2V is still out of scope.

```
local machine
  parent h3_fl2va_gui.py (run-fl2va.ps1 :7864)
    ──►  RunPod /v2/{id}/run
sidecar booth_ui.py is a convenience panel on :7868, not the daily driver.

RunPod Serverless worker (GPU)
  entrypoint.sh  →  ComfyUI :8188  +  handler.py
  handler loads workflows/h3_i2v_api.json
  patches node inputs from job["input"] by class_type
  waits on Comfy websocket
  returns {"video": "<base64 mp4>"} or {"error": "..."}
```

## Features

- First-frame I2V with optional last frame on the **same** FL2VA graph
- Path / URL / Base64 per image slot (prefer `/runpod-volume/…` when the file is already on the volume)
- Flat LoRA list (not Wan high/low pairs)
- Native stereo audio in the same pass; `disable_audio` to drop it
- Duration in **seconds** `{5, 10, 15}` at 24 fps, snapped onto H3’s 17k+5 frame grid
- Canvas snapped to a multiple of **32** (not Wan’s 16)
- No default example PNG — missing start image is an error
- Weights stay on the network volume. The image does **not** wget FL2VA / text-encoder / VAE files

H3 native output is typically **768p, 24 fps, 5 / 10 / 15 seconds, stereo audio**.

## Do not download H3 weights into the image

H3 is not Wan-sized. A baked checkpoint image is hundreds of GB and makes serverless deploys miserable. The Docker image only contains:

- CUDA **12.8** + PyTorch (`runpod/pytorch:1.2.0-cu1281-torch280-ubuntu2404`) + ComfyUI **v0.35.2** (native `MiniMaxH3ImageToVideo`)
- ffmpeg, ComfyUI-Manager
- `runpod`, `websocket-client`, `requests`
- `handler.py`, `entrypoint.sh`, `workflows/h3_i2v_api.json`, `extra_model_paths.yaml`

`huchukato/comfyui-qwenvl-runpod:cu13-mmh3` is a **reference** for a working H3 Comfy box, not the base image. Jupyter, FileBrowser, auto-download, and QwenVL prompt-enhancer stay out.

Exact filenames and on-volume paths: [`docs/NETWORK_VOLUME.md`](docs/NETWORK_VOLUME.md).

v1 I2V stack (Comfy-Org pruned INT8 ConvRot) is **~40 GB** on the volume:

| File | Folder |
|---|---|
| `minimax_h3_fl2va_pruned_int8_convrot.safetensors` | `models/diffusion_models/` |
| `qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors` | `models/text_encoders/` |
| `minimax_h3_video_vae_fp16.safetensors` | `models/vae/` |
| `minimax_h3_audio_vae_fp32.safetensors` | `models/vae/` |

FL2VA and Ref2VA are **not interchangeable**. Do not point this graph at a `ref2va_*` file. The sibling image loads `minimax_h3_ref2va_pruned_int8_convrot.safetensors` from the same volume.

## Network volume (Japan only)

v1 is pinned to **AP-JP-1**. Do not attach an EU / US / UK / KR volume. Serverless mounts the volume at `/runpod-volume`. Download the four I2V files there with `scripts/provision-volume.sh` **on a pod in AP-JP-1** — never onto the laptop.

H3 LoRAs, if any, go in `/runpod-volume/loras/` (same convention as the Wan booth, different volume).

## Suggested endpoint settings (testing)

| Setting | Value |
|---|---|
| Datacenter | **AP-JP-1 only** |
| GPU | H100 SXM (`NVIDIA H100 80GB HBM3`, pool `ADA_80_PRO`). H200 SXM is allowed as a fallback; H100 PCIe/NVL is allowed if it appears in this DC. One card. |
| CUDA | **12.8** |
| Workers | min **0** / max **1** while testing |
| Execution timeout | **1200–1800 s** |
| Flashboot | off while testing |
| Container disk | **60 GB**. Weights are on the volume |

Client wait default is 2700 s.

## Python client

```python
import os
from generate_video_client import GenerateVideoClient

client = GenerateVideoClient(
    runpod_endpoint_id=os.environ["RUNPOD_ENDPOINT_ID"],
    runpod_api_key=os.environ["RUNPOD_API_KEY"],
)

result = client.create_video_i2v(
    image_path="/runpod-volume/inputs/start.png",  # sent as image_path, not base64
    prompt="The subject from Picture 1 turns toward camera. Soft room tone.",
    end_image_path="/runpod-volume/inputs/end.png",  # optional
    width=768,
    height=1152,
    duration=5,
    steps=20,
    seed=42,
    loras=[{"name": "some_h3_lora.safetensors", "strength": 0.8}],
)

if result.get("status") == "COMPLETED":
    client.save_video_result(result, "./output_video.mp4")
else:
    print(result.get("error"))
```

Local files that are **not** on `/runpod-volume` are base64-encoded. Paths that start with `/runpod-volume` are sent as paths.

Full contract: [`docs/API.md`](docs/API.md). Prompt shape: [`docs/PROMPTING.md`](docs/PROMPTING.md).

## Local Gradio panel

`booth_ui.py` is client-side. It does not run on the GPU worker. `RUNPOD_API_KEY` is read from `.env` only and is never a Gradio field.

```bash
export RUNPOD_ENDPOINT_ID=...
export RUNPOD_API_KEY=...
python booth_ui.py --server-port 7864
```

Default port is **7864** so it can sit next to the Wan GUIs (7860 / 7862 / 7863). The parent `podbooth` repo will get a `run-fl2va.ps1` launcher later; do not start this with bare `python` on the Windows workstation — use that launcher or a project venv.

## Build notes (do this on a machine with disk, or on RunPod)

Windows can author this repo. The CUDA image build is Linux (`linux/amd64`). Docker Desktop or WSL both work. Do not pull H3 checkpoints onto the workstation.

```bash
docker build --platform linux/amd64 -t brakhet/podbooth-minimax-h3:v0.1.1-i2v-cu128 .
```

Do not add `wget` lines for H3 checkpoints.

## License — territory restrictions

MiniMax H3 weights are under the **MiniMax H3 Community License**. Excluded territories currently include the **European Union, United Kingdom, Republic of Korea, and United States**. The operator must pick a legal RunPod datacenter and is responsible for compliance. This repo does not grant extra rights.

Commercial products must attribute “MiniMax H3”. Organizations above the license’s revenue threshold need MiniMax’s written authorization.

## Credits

- MiniMax — [MiniMax-H3](https://huggingface.co/MiniMaxAI/MiniMax-H3)
- Comfy-Org — native nodes, [repackaged weights](https://huggingface.co/Comfy-Org/MiniMax-H3), [I2V template](https://github.com/Comfy-Org/workflow_templates/blob/main/templates/video_minimax_h3_i2v.json)
- ComfyUI
- Booth pattern: [bra-khet/podbooth-wan](https://github.com/bra-khet/podbooth-wan) ← [wlsdml1114/generate_video](https://github.com/wlsdml1114/generate_video)
- CUDA/torch base: `runpod/pytorch:1.2.0-cu1281-torch280-ubuntu2404`. H3 Comfy reference (not used as FROM): `huchukato/comfyui-qwenvl-runpod:cu13-mmh3`
