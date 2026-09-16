# Workflows

| File | Mode | Status |
|---|---|---|
| `h3_i2v_api.json` | FL2VA — first frame required, optional last frame | **v1** |
| `h3_r2v_api.json` | (not in this repo) | Sibling worker `podbooth-minimax-h3-ref2va` |

`h3_i2v_api.json` is Comfy **API format** (`{ "NODE_ID": { "class_type", "inputs" } }`), flattened from the official UI template:

https://github.com/Comfy-Org/workflow_templates/blob/main/templates/video_minimax_h3_i2v.json

The handler looks up nodes by `class_type` (and `_meta.title` when two loaders share a type). Do not hard-code the numeric ids in new code.

Ref2VA is a **sibling image**, not a second graph here. A job that sends `reference_images` / `mode=r2v` is rejected so the two booths cannot cross-wire.
