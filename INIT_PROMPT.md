# INIT PROMPT — PodBooth MiniMax H3
# Paste this entire file into a new coding agent session as the first message.
# Source of truth for the *pattern*: https://github.com/bra-khet/podbooth-wan
# Destination: this directory (`podbooth-minimax-h3`), or a new GitHub repo with the same name.

You are building **PodBooth MiniMax H3**: a RunPod Serverless worker + Python client + local control UI for MiniMax Hailuo H3 video, cloned in *architecture* from `bra-khet/podbooth-wan` (Wan 2.2 I2V/FLF2V). Do not invent a new product shape. Mirror that repo’s split and rewrite only what H3 actually changes.

**2026-09-16 sibling split:** Ref2VA is **not** a second graph in this repo. It is `bra-khet/podbooth-minimax-h3-ref2va` / `brakhet/podbooth-minimax-h3-ref2va`, same Japan volume, separate image so each worker stays lightweight. Ignore later sections of this INIT that still say “same worker” or “add h3_r2v_api.json here.”

Read `https://github.com/bra-khet/podbooth-wan` in full before writing a single file: `README.md`, `Dockerfile`, `entrypoint.sh`, `handler.py`, `generate_video_client.py`, `extra_model_paths.yaml`, `.runpod/hub.json`, `new_Wan22_api.json`, `new_Wan22_flf2v_api.json`. Those files are the template. This prompt tells you what to keep, what to delete, and what H3-specific behavior to add.

---

## 0. Product intent

The operator already runs a forked Wan 2.2 serverless worker from `bra-khet/podbooth-wan` on RunPod, with a **network volume** shared across pods. They almost never do text-to-video. They feed **finished stills** as a first frame and/or as identity references, sometimes with a last frame, and they want the same “booth” sitting ready: submit a job with the right knobs, poll RunPod, get an mp4 back.

H3 is **two diffusion checkpoints**, not one Wan-style dual-noise pair:

| Mode | Checkpoint family | When to use |
|---|---|---|
| I2V / first+last frame | **FL2VA** (`MiniMaxH3ImageToVideo`) | Start image required. Optional end image. Closest analog to Wan I2V + FLF2V. **Build this first.** |
| Reference-to-video | **Ref2VA** (`MiniMaxH3ReferenceToVideo`) | Pack of refs: up to 9 images, 3 videos, 3 audio / 12 mixed. **Direct sibling worker** `podbooth-minimax-h3-ref2va` (same volume, separate image) so each Docker image stays lightweight. |
| T2V | FL2VA with no keyframes | Out of scope for v1. Do not spend time on it. A hidden path that reuses the I2V graph with no image attached is fine later; do not advertise it. |

Official Comfy templates (pin and copy node graphs from these, do not freehand a graph):

- I2V: https://github.com/Comfy-Org/workflow_templates/blob/main/templates/video_minimax_h3_i2v.json
- R2V: https://github.com/Comfy-Org/workflow_templates/blob/main/templates/video_minimax_h3_r2v.json
- T2V (reference only): https://github.com/Comfy-Org/workflow_templates/blob/main/templates/video_minimax_h3_t2v.json
- Day-0 notes: https://blog.comfy.org/p/minimax-h3-day-0-support-in-comfyui
- Weights: https://huggingface.co/Comfy-Org/MiniMax-H3 and/or official `MiniMaxAI/MiniMax-H3`
- Self-host notes: https://platform.minimax.io/docs/guides/local-deploy-h3.md

H3 native output is typically **768p, 24 fps, 5 / 10 / 15 seconds, stereo audio in the same pass**. That replaces Wan’s `length=81` / 16-ish fps mental model.

---

## 1. Non-negotiable architecture (copy from Wan booth)

Keep this exact runtime shape:

```
local machine or cheap CPU pod
  Gradio/booth UI  ──►  generate_video_client.py  ──►  RunPod /v2/{id}/run
                                                          │
RunPod Serverless worker (GPU)
  entrypoint.sh  →  ComfyUI :8188  +  handler.py (runpod.serverless)
  handler loads a baked API-format workflow JSON
  patches node inputs from job["input"]
  waits on Comfy websocket
  returns {"video": "<base64 mp4>"} or {"error": "..."}
```

Network volume is mounted at `/runpod-volume` (RunPod default). Models and LoRAs live **there**, not in the Docker image.

**Do not bake MiniMax H3 weights into the image.** The Wan Dockerfile wget’d fp8 Wan checkpoints because they were small enough. H3 is not. A baked H3 image will be hundreds of GB and will make serverless deploys miserable. The image only contains:

- CUDA/Comfy base
- ComfyUI + H3-capable custom nodes
- `runpod`, `websocket-client`, `requests`
- handler, entrypoint, workflow JSONs, extra_model_paths

If Comfy is older than **0.30.0**, native `MiniMaxH3ImageToVideo` / `MiniMaxH3ReferenceToVideo` nodes will not exist. Pin a new enough Comfy.

---

## 2. Target file tree

Create this repo (working name `podbooth-minimax-h3`):

```
podbooth-minimax-h3/
  README.md
  Dockerfile
  entrypoint.sh
  extra_model_paths.yaml
  handler.py
  generate_video_client.py
  booth_ui.py                  # local Gradio control panel (new; Wan repo did not ship this)
  requirements-client.txt      # client + Gradio only
  .gitignore
  .runpod/hub.json
  workflows/
    h3_i2v_api.json            # FL2VA, first frame + optional last frame
    h3_r2v_api.json            # Ref2VA
  docs/
    NETWORK_VOLUME.md          # exact folder layout + filenames to download
    API.md                     # job input/output contract
    PROMPTING.md               # H3 I2V vs R2V prompt shape
```

No example 5 MB png in git. No character LoRAs. No `zeta_tina`. Public worker stays generic.

---

## 3. Dockerfile rules

Start from a current NVIDIA CUDA + Python image that can run Comfy 0.30+ with Sage Attention if available. Do **not** keep `wlsdml1114/engui_genai-base_blackwell:1.1` unless you verify it still exists and already has a new-enough Comfy; that pin is a Wan leftover.

Install:

- ComfyUI @ a commit / tag that includes MiniMax H3 nodes (≥ 0.30.0)
- ComfyUI-Manager
- ComfyUI-VideoHelperSuite
- Any extra nodes the official H3 templates actually import (inspect the JSON; do not clone the entire Wan node zoo)
- `runpod`, `websocket-client`

Do **not** clone WanVideoWrapper, wanBlockswap, GGUF-FantasyTalking, AdaptiveWindowSize, etc. Those are Wan-only.

Do **not** `wget` FL2VA / Ref2VA / text-encoder / VAE weights in the Dockerfile.

Copy repo files to `/` the same way Wan does. `CMD ["/entrypoint.sh"]`.

`.runpod/hub.json`:

- title: `PodBooth MiniMax H3`
- type: serverless
- `containerDiskInGb`: 40–80 is enough if weights are on the volume (not 180)
- `gpuIds`: prefer 48 GB+ (`ADA_48`, `L40S`, `H100`, etc.). 24 GB can run pruned INT8 I2V at ~0.9 MP; do not advertise 24 GB as the Ref2VA 15s 768p target
- allowed CUDA: match the base image

---

## 4. extra_model_paths.yaml

H3 and Wan will share one network volume. Keep Wan’s `/runpod-volume/loras/` convention and add H3 model roots.

```yaml
comfyui:
    base_path: /ComfyUI/
    is_default: true
    checkpoints: models/checkpoints/
    clip: models/clip/
    clip_vision: models/clip_vision/
    configs: models/configs/
    controlnet: models/controlnet/
    diffusion_models: |
        models/diffusion_models
        models/unet
        /runpod-volume/models/diffusion_models
        /runpod-volume/models/
    text_encoders: |
        models/text_encoders
        /runpod-volume/models/text_encoders
    loras: |
        models/loras/
        /runpod-volume/loras/
        /runpod-volume/models/loras/
    vae: |
        models/vae
        /runpod-volume/models/vae
    audio_encoders: |
        models/audio_encoders
        /runpod-volume/models/audio_encoders
```

Document the on-volume layout in `docs/NETWORK_VOLUME.md` as:

```
/runpod-volume/
  models/
    diffusion_models/     # FL2VA + Ref2VA (pruned INT8 ConvRot preferred for 24–48 GB)
    text_encoders/        # whatever the Comfy H3 templates name
    vae/
    loras/                # optional second home
    audio_encoders/       # if the template needs one
  loras/                  # SAME folder the Wan booth already uses
  inputs/                 # optional large stills / ref packs
  outputs/                # optional if we later write to volume instead of base64
```

List **exact Hugging Face filenames** the operator must download. Prefer Comfy-Org converted / pruned INT8 files that the official templates expect. Call out that FL2VA and Ref2VA are **not interchangeable**.

---

## 5. entrypoint.sh

Same as Wan:

1. Start `python /ComfyUI/main.py --listen` (add `--use-sage-attention` only if the base image actually has it; make it env-gated: `COMFY_EXTRA_ARGS`).
2. Wait until `http://127.0.0.1:8188/` answers. Default max wait **300s** (H3 node import + first model touch is slower than Wan). Make the cap an env var `COMFY_WAIT_SECONDS`.
3. `exec python handler.py`

---

## 6. handler.py — rewrite the workflow patching, keep the I/O spine

Keep from Wan handler:

- `process_input` for path / url / base64
- HTTP wait then websocket wait
- `queue_prompt` / `get_history` / read output mp4 from Comfy history (`gifs` fullpath **and** any `videos` / `audio` output the H3 save node actually uses — inspect the template, do not assume Wan’s `gifs` key)
- return `{"video": base64}` or `{"error": ...}`
- `runpod.serverless.start({"handler": handler})`

Delete all Wan node-id patching (`244`, `541`, `135`, `279`/`553` high-low LoRAs, `617` end image, `834` steps, etc.). Those IDs are meaningless on H3 graphs.

### 6.1 Mode selection

```
if job has any of: references, reference_images, reference_videos, reference_audios
    → load workflows/h3_r2v_api.json   (Ref2VA)
elif job has start image (image_path | image_url | image_base64)
    → load workflows/h3_i2v_api.json   (FL2VA)
    if end_image_* present, wire the last-frame input
else
    → return error "H3 v1 requires a start image (I2V) or a reference pack (R2V)"
```

Do not silently fall back to `/example_image.png`. That Wan default is a footgun.

### 6.2 Job input contract (I2V)

```json
{
  "input": {
    "mode": "i2v",
    "prompt": "…",
    "negative_prompt": "",
    "image_path": "/runpod-volume/inputs/start.png",
    "end_image_path": "/runpod-volume/inputs/end.png",
    "width": 768,
    "height": 1152,
    "duration": 10,
    "fps": 24,
    "steps": 16,
    "seed": 42,
    "cfg": null,
    "sampler": null,
    "disable_audio": false,
    "loras": [
      {"name": "some_h3_lora.safetensors", "strength": 0.8}
    ]
  }
}
```

Image fields also accept `_url` and `_base64` variants, same as Wan. Use only one per slot.

Notes:

- `duration` is **seconds**, allowed set `{5, 10, 15}` unless the loaded graph proves otherwise. Convert to frame count internally (`duration * fps`).
- Snap width/height to whatever the H3 node requires (often multiples of 16 or 64 — read the node, do not copy Wan’s “nearest 16” blindly).
- LoRAs are a **flat list**. H3 is not Wan 2.2 high/low dual noise. One `PowerLoraLoader` / native H3 LoRA slot, not pairs.
- `disable_audio`: if true, strip or mute audio in the save node / post with ffmpeg. Default keep native audio.
- Ignore unknown keys; do not crash.

### 6.3 Job input contract (R2V)

```json
{
  "input": {
    "mode": "r2v",
    "prompt": "subject_definitions: …",
    "reference_images": [
      {"path": "/runpod-volume/inputs/tina_face.png"},
      {"url": "https://…"},
      {"base64": "…"}
    ],
    "reference_videos": [],
    "reference_audios": [],
    "duration": 10,
    "fps": 24,
    "steps": 16,
    "seed": 42,
    "disable_audio": false,
    "loras": []
  }
}
```

Cap at 9 images / 3 videos / 3 audio / 12 mixed, matching H3. Resolve each ref to a local file before patching the graph. Order is part of the prompt contract (`Picture 1`, `Video 1`, …) — preserve list order.

### 6.4 Workflow JSON rules

- Store **API-format** graphs (the same format Wan’s `new_Wan22_api.json` uses: `{ "NODE_ID": {"inputs":..., "class_type":...} }`).
- Export them from the official Comfy templates after opening in Comfy 0.30+.
- In `handler.py`, find nodes by `class_type` (and a stable title if needed), **not** by hard-coded numeric IDs. H3 templates will change. A tiny helper `find_nodes(prompt, class_type)` is required.
- Wire: first image, optional last image, prompt text, seed, steps, duration/frames, lora names, reference slots.

### 6.5 Timeouts

H3 15s 768p on a 48 GB card can run minutes. Client default wait should be **30–45 min**, not Wan’s 1800s-if-you’re-lucky-on-a-fast-card assumption only. Handler itself should not time out the RunPod worker early; set endpoint execution timeout in README (suggest 1200–1800s).

---

## 7. generate_video_client.py

Same class shape as Wan (`submit_job`, `wait_for_completion`, `save_video_result`) with new methods:

- `create_video_i2v(...)` — start image required, end image optional, flat `loras`
- `create_video_r2v(...)` — reference lists
- Keep `encode_file_to_base64`
- Prefer **network-volume paths** when the caller already has files on `/runpod-volume`. Only base64-encode when the file is local to the client machine and not on the volume. Add a flag `use_volume_path: bool` / auto-detect paths starting with `/runpod-volume`.
- `wait_for_completion(..., max_wait_time=2700)`
- Do not keep Wan defaults like `prompt="running man, grab the gun"`, `width=480`, `height=832`, `length=81`, `cfg=2.0`.

---

## 8. booth_ui.py (the “waiting for me” panel)

The public Wan repo does **not** include Gradio. Build a small local Gradio app that wraps the client so a browser tab can drive the endpoint.

- Env: `RUNPOD_ENDPOINT_ID`, `RUNPOD_API_KEY`
- Two tabs: **I2V / First–Last** and **Ref2Vid**
- I2V tab: start image upload, optional end image, prompt, negative, duration dropdown (5/10/15), steps, seed, width/height, lora text box (filename + strength, repeatable), disable-audio checkbox, submit, status log, video player + download
- R2V tab: up to 9 image uploads, up to 3 video, up to 3 audio, big prompt box, same gen knobs
- Never log the API key
- `if __name__ == "__main__":` launch `0.0.0.0` port 7860
- This UI is **client-side**. It does not run inside the GPU worker.

---

## 9. Prompting doc (docs/PROMPTING.md)

Short, operator-facing:

**I2V:** describe the *motion* and camera. Do not re-describe the whole character if the start frame already is the character. The still is the contract.

**R2V:** use H3’s labelled structure. Minimum:

```
subject_definitions:
<Subject 1> is the woman matching Picture 1.
<Subject 2> is the motion / camera from Video 1. Do not copy Video 1's actor, wardrobe, or setting.

summary:
[reference generation] <one-sentence shot>

retention_analysis:
<Subject 1> (appears throughout): fully_preserved from Picture 1.

detailed_description:
At 00:00.000 the video matches Picture 1. Then …

overall_soundscape:
…
```

Tell the operator that vague “use these images” prompts waste Ref2VA.

Do not put OC-specific triggers (`zeta_tina`, character sheets) in this repo.

---

## 10. README

Rewrite Wan’s README. Keep the same sections (features, client usage, API tables, network volume, methods, credits). Replace every Wan 2.2 / high-low LoRA pair / length=81 example with H3 I2V + R2V examples.

Must include:

- How to attach the existing network volume to the new serverless endpoint
- “Do not download H3 weights into the image”
- FL2VA vs Ref2VA file names and that both must be on the volume if you want both modes
- Suggested endpoint settings: GPU, exec timeout, flashboot off or on with a warm volume, workers min 0 / max 1 while testing
- MiniMax H3 Community License + **territory restrictions** — operator must pick a legal RunPod datacenter
- Credit: MiniMax, Comfy-Org, ComfyUI, original Wan booth pattern (`bra-khet/podbooth-wan` ← `wlsdml1114/generate_video`)

---

## 11. What you must not do

- Do not keep Wan workflows, Wan wget lines, or Wan node IDs “just in case.”
- Do not build a multi-model mega-worker that also loads Wan 2.2.
- Do not add auth, a database, Discord bots, or a public SaaS wrapper.
- Do not train or vendor character LoRAs.
- Do not promise 4-step turbo quality as default. Turbo LoRAs are optional volume files the operator can name in `loras`.
- Do not implement T2V as a first-class tab.
- Do not write models into `/ComfyUI/models` at runtime if they already exist on `/runpod-volume`.

---

## 12. Implementation order

1. Scaffold repo + README + NETWORK_VOLUME.md + extra_model_paths + entrypoint + Dockerfile (no weights).
2. Export / adapt official I2V API workflow → `workflows/h3_i2v_api.json`.
3. handler.py I2V only. Prove path / url / base64 / optional end frame / flat LoRA.
4. Client I2V methods + booth_ui I2V tab.
5. Export official R2V API workflow → `workflows/h3_r2v_api.json`.
6. handler + client + UI for R2V.
7. API.md + PROMPTING.md. Sanity-check node lookup by class_type, not IDs.
8. Stop. Do not “also add T2V / upscaler / prompt enhancer LLM.”

---

## 13. Done when

- A reader of `bra-khet/podbooth-wan` recognizes the same bones.
- `handler.py` has zero Wan node IDs and zero `WanVideo*` class types.
- Docker build does not download H3 weights.
- I2V job with `image_path` on `/runpod-volume/...` plus a prompt returns `{video: base64}`.
- Same job with `end_image_path` uses the last-frame input on the FL2VA graph.
- R2V job with two reference images uses Ref2VA, not FL2VA.
- Gradio booth can submit both and play the result.
- README states exact volume filenames and endpoint timeout/GPU guidance.

If a required H3 filename or node input name is uncertain, look it up from the Comfy-Org template and Hugging Face repo. Do not guess and ship a broken graph.
}
