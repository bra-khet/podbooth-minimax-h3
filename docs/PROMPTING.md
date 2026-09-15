# Prompting MiniMax H3 (I2V / FL2VA)

Official shape, from [MiniMax-H3 `VIDEO_PROMPT_WRITING_GUIDE_base_en.md`](https://huggingface.co/MiniMaxAI/MiniMax-H3/blob/main/docs/VIDEO_PROMPT_WRITING_GUIDE_base_en.md). The first line is a **fixed alignment instruction**, then one blank line, then three core fields.

The start still is the contract. Describe **motion, camera, and sound**. Do not re-describe the whole character if the first frame already is the character.

## I2VA (first frame only)

Picture 1 is the start frame the handler attached. Always use this opening line:

```
For the target video, at 0.00 seconds into the target video, <Picture 1> (from [Shot 1]) is fully referenced.

integrated_multimodal_description: [Shot 1] [style], the subject from Picture 1 holds the opening pose. Preserve appearance, clothing, and the scene from the first frame. The camera [static shot / push in with small amplitude at slow speed] as they [action]. End on [pose].

overall_soundscape: [room tone / footsteps / fabric]. No extra crowd.

non_diegetic_music: N/A
```

Shape: **first-frame anchor → action onset → continuous development → result or reaction**.

Keep wardrobe, face, and setting out of the prompt unless you *want* them to change. H3 will drift if you rewrite the person in text.

First-frame images are **stretched** to the canvas (aspect not preserved). Match the still's aspect to `width`×`height` when you can.

## FL2VA (first + last frame)

Picture 1 opens. Picture 2 closes. `S.SS` is the clip duration to two decimal places (5.00 / 10.00 / 15.00). Prefer a **single shot**.

```
How the reference pictures align with the target video — Picture 1 (from Shot 1) aligns with the 0.00-second mark of the target video; Picture 2 (from Shot 1) aligns with the S.SS-second mark of the target video.

integrated_multimodal_description: [Shot 1] [style], the subject begins in the pose, framing, and lighting established by Picture 1. The camera [move] as they [action that connects the two stills]. Toward the end the differences narrow until they land on the exact pose, spacing, and composition established by Picture 2.

overall_soundscape: [room tone]. Fabric and body motion stay audible.

non_diegetic_music: N/A
```

Shape: **first-frame state → observable intermediate changes → progressively narrowing differences → last-frame state**.

The last frame is **cropped to cover** the canvas (aspect preserved). Copying an I2VA prompt and attaching a second image is the fastest way to have the end frame ignored.

## Camera

Write camera as a natural English action: **motion type + amplitude + speed**. Medium amplitude and normal speed can be omitted.

Examples: `The camera pushes in with small amplitude at slow speed.` / `The camera holds a static shot.` / `The camera pans right with large amplitude at fast speed.`

## Sound

- `overall_soundscape`: ambient + physical + non-verbal human sounds. Use `N/A` only for complete silence.
- `non_diegetic_music`: score the characters cannot hear. `N/A` means no score.
- Dialogue (optional): `(S1) says: <d>[English] line here.</d>`

## What not to do

- Do not dump a full character sheet into I2VA. That is Ref2VA work.
- Do not rely on a negative prompt. The native node has no negative slot; the worker will only append `Avoid: …` if you send one.
- Do not promise 4-step turbo quality as the default. Turbo is an optional volume LoRA you name in `loras`.
- Do not put OC trigger words in this worker repo. Those belong in the parent GUI (`h3_fl2va_gui.py` / `run-fl2va.ps1`).

## R2V (later)

Ref2VA wants labelled structure (`subject_definitions`, `summary`, `retention_analysis`, `detailed_description`, `overall_soundscape`) and `<Picture N>` / `<Video N>` / `<Audio N>` tags that match upload order. Vague “use these images” prompts waste Ref2VA. The v1 worker will not run that graph yet.
