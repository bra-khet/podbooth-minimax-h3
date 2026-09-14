# Workflows

| File | Mode | Status |
|---|---|---|
| `h3_i2v_api.json` | FL2VA — first frame required, optional last frame | **v1** |
| `h3_r2v_api.json` | Ref2VA — up to 9 images / 3 videos / 3 audio | deferred |

`h3_i2v_api.json` is Comfy **API format** (`{ "NODE_ID": { "class_type", "inputs" } }`), flattened from the official UI template:

https://github.com/Comfy-Org/workflow_templates/blob/main/templates/video_minimax_h3_i2v.json

The handler looks up nodes by `class_type` (and `_meta.title` when two loaders share a type). Do not hard-code the numeric ids in new code.

Ref2VA is out of scope for v1. A job that sends `reference_images` / `mode=r2v` is rejected until that graph ships.
