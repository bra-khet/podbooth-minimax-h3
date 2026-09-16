# Network volume layout — MiniMax H3

Weights stay on the RunPod **network volume**, never in the Docker image.
v1 is pinned to **AP-JP-1** (MiniMax H3 Community License). Do not use an
EU / US / UK / KR volume. Serverless mounts at `/runpod-volume`. A GPU pod
in the same DC can mount the same volume at `/workspace` or `/runpod-volume`.

This volume is **100 GB**. The I2V sibling holds the INT8 FL2VA stack (~41 GB).
The Ref2VA sibling adds `minimax_h3_ref2va_pruned_int8_convrot.safetensors` (~21 GB)
next to it. Do not download BF16. Do not replace the FL2VA file.

H3 LoRAs, if any, go in `/loras/` (same folder convention as the Wan booth,
different volume).

## Folder tree

```
/runpod-volume/
  models/
    diffusion_models/     # FL2VA (+ Ref2VA later). Not interchangeable.
    text_encoders/        # Qwen3-VL MiniMax pack
    vae/                  # video VAE + audio VAE
    loras/                # optional second home for H3 LoRAs
    embeddings/           # optional minimaxh3_* style embeddings
    audio_encoders/       # unused by the official I2V graph
  loras/                  # SAME folder the Wan booth already uses
  inputs/                 # stills / ref packs the client can address by path
  outputs/                # optional; v1 returns base64 mp4 instead
```

## v1 I2V / FL2VA — download these four files

Prefer Comfy-Org **pruned INT8 ConvRot** on the `cu13-mmh3` image (PyTorch cu130).
`fp8_scaled` is the fallback if INT8 ConvRot cannot load.

| Role | Exact filename | Size | Hugging Face |
|---|---|---|---|
| FL2VA diffusion | `minimax_h3_fl2va_pruned_int8_convrot.safetensors` | 19.53 GB | [Comfy-Org/MiniMax-H3](https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors) |
| Text encoder | `qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors` | 14.61 GB | [text_encoders/…](https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors) |
| Video VAE | `minimax_h3_video_vae_fp16.safetensors` | 4.85 GB | [vae/…](https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_fp16.safetensors) |
| Audio VAE | `minimax_h3_audio_vae_fp32.safetensors` | 0.58 GB | [vae/…](https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors) |

**I2V stack total ≈ 39.6 GB.** Do not download this onto the Windows workstation.

On-volume destinations:

```
/runpod-volume/models/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors
/runpod-volume/models/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors
/runpod-volume/models/vae/minimax_h3_video_vae_fp16.safetensors
/runpod-volume/models/vae/minimax_h3_audio_vae_fp32.safetensors
```

Example (run **on the pod / volume**, not locally):

```bash
hf download Comfy-Org/MiniMax-H3 \
  --include "diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors" \
  --include "text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors" \
  --include "vae/minimax_h3_video_vae_fp16.safetensors" \
  --include "vae/minimax_h3_audio_vae_fp32.safetensors" \
  --local-dir /runpod-volume/models
```

If `hf download` writes into `diffusion_models/` under that local-dir, you already have the right layout.

## Optional turbo LoRA (still volume-only)

Official I2V template ships an 8-step turbo LoRA. v1 does **not** enable it unless you name it in `loras`.

| File | Typical steps |
|---|---|
| `minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors` | 8 |
| `minimax_h3_fl2v_turbo_4step_v1.0_768p_comfyui_bf16.safetensors` | 4 |

Drop into `/runpod-volume/loras/` (Wan convention) or `/runpod-volume/models/loras/`.

## Ref2VA (sibling worker)

FL2VA and Ref2VA are **different checkpoints**. Do not point this I2V graph at a `ref2va_*` file.

The sibling image `podbooth-minimax-h3-ref2va` downloads onto this same volume:

- `minimax_h3_ref2va_pruned_int8_convrot.safetensors` (21 GB INT8)

Projected used with both DiTs: ~62 GB of 100 GB. Turbo LoRAs are optional and family-specific (I2V `fl2v` 8-step vs Ref2V `ref2v` 4-step). Do not mix them.

## 24 GB vs 48 GB

| GPU | What v1 will advertise |
|---|---|
| 24 GB (4090) | Pruned INT8 I2V around 0.9 MP / 5–10 s. Tight. |
| 48 GB (L40S / 6000 Ada) | Comfortable 768p 10–15 s I2V. Default target. |
| 32 GB (5090) | Pruned INT8 I2V is the right file; full INT8 is optional. |

Do not advertise 24 GB as the Ref2VA 15 s 768p target.
