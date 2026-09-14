# Prompting MiniMax H3 (I2V / FL2VA)

The start still is the contract. Describe **motion, camera, and sound**. Do not re-describe the whole character if the first frame already is the character.

## I2V (first frame only)

Picture 1 is the start frame the handler attached.

```
The subject from Picture 1 holds the opening pose, then [action].
Camera: [hold / slow push-in / slight pan]. No jump cuts unless you want them.
Audio: [room tone / footsteps / no dialogue].
```

Keep wardrobe, face, and setting out of the prompt unless you *want* them to change. H3 will drift if you rewrite the person in text.

First-frame images are **stretched** to the canvas (aspect not preserved). Match the still's aspect to `width`×`height` when you can.

## First + last frame

Picture 1 = first frame (stretched). The last frame is **cropped to cover** the canvas (aspect preserved). Call the last frame out if the shot must land on it:

```
At 00:00 the video matches Picture 1.
The subject [action that connects the two stills].
The last frame matches the end image.
Camera [move]. Audio […].
```

## What not to do

- Do not dump a full character sheet into I2V. That is Ref2VA work.
- Do not rely on a negative prompt. The native node has no negative slot; the worker will only append `Avoid: …` if you send one.
- Do not promise 4-step turbo quality as the default. Turbo is an optional volume LoRA you name in `loras`.
- Do not put OC trigger words (`zeta_tina`, character sheets) in this repo. Those belong in the local parent GUI later.

## R2V (later)

Ref2VA wants labelled structure (`subject_definitions`, `summary`, `retention_analysis`, `detailed_description`, `overall_soundscape`) and `<Picture N>` / `<Video N>` / `<Audio N>` tags that match upload order. Vague “use these images” prompts waste Ref2VA. The v1 worker will not run that graph yet.
