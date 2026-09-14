# PodBooth MiniMax H3

RunPod Serverless worker + Python client + local Gradio panel for **MiniMax Hailuo H3** image-to-video.

Architecture is a clone of [bra-khet/podbooth-wan](https://github.com/bra-khet/podbooth-wan) (Wan 2.2 I2V / FLF2V). The product shape is the same booth: submit a job with the right knobs, poll RunPod, get an mp4 back. H3 replaces Wan’s dual-noise pair with **FL2VA** (`MiniMaxH3ImageToVideo`).

**v1 scope: I2V / first+last frame (FL2VA) only.** Ref2VA and T2V are out of scope. Do not advertise them.

```
local machine
  booth_ui.py  ──►  generate_video_client.py  ──►  RunPod /v2/{id}/run
                                                      │
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

- CUDA 13 + ComfyUI ≥ 0.30 (this repo starts `FROM huchukato/comfyui-qwenvl-runpod:cu13-mmh3`, which already has Comfy 0.34.x and Sage Attention)
- `runpod`, `websocket-client`, `requests`
- `handler.py`, `entrypoint.sh`, `workflows/h3_i2v_api.json`, `extra_model_paths.yaml`

Exact filenames and on-volume paths: [`docs/NETWORK_VOLUME.md`](docs/NETWORK_VOLUME.md).

v1 I2V stack (Comfy-Org pruned INT8 ConvRot) is **~40 GB** on the volume:

| File | Folder |
|---|---|
| `minimax_h3_fl2va_pruned_int8_convrot.safetensors` | `models/diffusion_models/` |
| `qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors` | `models/text_encoders/` |
| `minimax_h3_video_vae_fp16.safetensors` | `models/vae/` |
| `minimax_h3_audio_vae_fp32.safetensors` | `models/vae/` |

FL2VA and Ref2VA are **not interchangeable**. Do not point this graph at a `ref2va_*` file.

## Attach the existing network volume

1. In the RunPod console, open the serverless endpoint → Storage.
2. Attach the **same** network volume the Wan booth already uses (or a new one in a **legal** datacenter — see license below).
3. Serverless mounts it at `/runpod-volume`. Download the four I2V files there, not into the container disk.
4. Keep `/runpod-volume/loras/` as the Wan booth already uses it. H3 LoRAs can live there too.

## Suggested endpoint settings (testing)

| Setting | Value |
|---|---|
| GPU | 48 GB+ (`ADA_48`, L40S, 6000 Ada). 24 GB can run pruned INT8 I2V at ~0.9 MP; do not treat it as the 15 s 768p target |
| Workers | min **0** / max **1** while testing |
| Execution timeout | **1200–1800 s** |
| Flashboot | optional; a warm volume helps more than flashboot |
| Container disk | **40–80 GB** (hub.json uses 60). Weights are on the volume |
| CUDA | 12.8 / 13.x to match `cu13-mmh3` |

Client wait default is 2700 s.

## Python client

```python
from generate_video_client import GenerateVideoClient

client = GenerateVideoClient(
    runpod_endpoint_id="your-endpoint-id",
    runpod_api_key="your-runpod-api-key",
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

`booth_ui.py` is client-side. It does not run on the GPU worker.

```bash
export RUNPOD_ENDPOINT_ID=...
export RUNPOD_API_KEY=...
python booth_ui.py --server-port 7864
```

Default port is **7864** so it can sit next to the Wan GUIs (7860 / 7862 / 7863). The parent `podbooth` repo will get a `run-fl2va.ps1` launcher later; do not start this with bare `python` on the Windows workstation — use that launcher or a project venv.

## Build notes (do this on a machine with disk, or on RunPod)

The base image is ~9.5 GB compressed. **Do not pull it onto a disk-constrained workstation unless you have ~30 GB free** for the uncompressed layers.

Windows can author this repo. A CUDA image build is Linux (`linux/amd64`). Options:

1. Docker Desktop on Windows / WSL Ubuntu (this machine already has both)
2. Build on a cheap RunPod CPU/GPU pod and push to Docker Hub

```bash
docker build --platform linux/amd64 -t brakhet/podbooth-minimax-h3:i2v .
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
- Base image used for v1: `huchukato/comfyui-qwenvl-runpod:cu13-mmh3`
