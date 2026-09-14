# Job contract — PodBooth MiniMax H3 v1

Worker input is the RunPod `{"input": {…}}` body. Output is `{"video": "<base64 mp4>"}` or `{"error": "…"}`.

v1 implements **I2V / FL2VA** only. A reference pack or `mode: "r2v"` returns an error.

## I2V / first–last

```json
{
  "input": {
    "mode": "i2v",
    "prompt": "The subject from Picture 1 turns toward camera. Soft room tone.",
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
      {"name": "minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors", "strength": 1.0}
    ]
  }
}
```

### Image slots

Use **one** of `_path` / `_url` / `_base64` per slot.

| Slot | Keys | Required |
|---|---|---|
| Start frame | `image_path`, `image_url`, `image_base64` | **yes** |
| End frame | `end_image_path`, `end_image_url`, `end_image_base64` | no |

- `_path` is a path the **worker** can read (`/runpod-volume/…`). Prefer this when the file is already on the volume.
- `_url` is downloaded on the worker.
- `_base64` is decoded to a temp file. Use this for local-machine uploads. Do not send huge stills this way if a volume path exists.
- There is **no** default `example_image.png`. Missing start image is an error.

End frame present → handler wires `MiniMaxH3ImageToVideo.last_frame`. Same graph, not a second Wan-style workflow file.

### Generation knobs

| Key | Default | Notes |
|---|---|---|
| `prompt` | required | Motion + audio. See `docs/PROMPTING.md`. |
| `negative_prompt` | `""` | H3 I2V has no native negative. Non-empty values are appended as `Avoid: …`. |
| `width` / `height` | `768` / `1152` | Snapped to a **multiple of 32**. Native short edge is 768; official landscape default is 1344×768. |
| `duration` | `5` | Seconds. Converted to frame `length` on the 17k+5 grid at 24 fps: 5→124, 10→243, 15→362. Allowed operator set is `{5,10,15}`. |
| `fps` | `24` | Used only to convert duration. CreateVideo is baked at 24. |
| `steps` | `20` | Official non-turbo default. 8 or 4 if you attach a turbo LoRA. |
| `seed` | `42` | Integer. |
| `sampler` | `res_multistep` | Patched onto `KSamplerSelect` when set. |
| `cfg` | ignored | Official graph uses `BasicGuider` (no CFG). Unknown keys are ignored. |
| `disable_audio` | `false` | If true, the CreateVideo node is run without the audio input. |
| `loras` | `[]` | Flat list `{name, strength}`. Not Wan high/low pairs. Files must exist under `/runpod-volume/loras/` or `/runpod-volume/models/loras/`. |

Optional overrides if the volume uses different filenames: `unet_name`, `clip_name`, `video_vae_name`, `audio_vae_name`.

### Timeouts

H3 15 s 768p on a 48 GB card can run several minutes. Client default wait is **2700 s**. Set the RunPod endpoint execution timeout to **1200–1800 s**. Handler does not kill the worker early.

## Output

Success:

```json
{ "video": "<base64 mp4>" }
```

Failure:

```json
{ "error": "H3 v1 requires a start image (image_path | image_url | image_base64)." }
```

The handler reads Comfy history from `videos` **and** `gifs` (SaveVideo vs older VHS keys).

## R2V (not v1)

Documented so the next sprint does not invent a new shape:

```json
{
  "input": {
    "mode": "r2v",
    "prompt": "subject_definitions: …",
    "reference_images": [{"path": "/runpod-volume/inputs/face.png"}],
    "reference_videos": [],
    "reference_audios": [],
    "duration": 10,
    "fps": 24,
    "steps": 16,
    "seed": 42,
    "loras": []
  }
}
```

Cap later: 9 images / 3 videos / 3 audio / 12 mixed. v1 returns an error instead of running FL2VA.
