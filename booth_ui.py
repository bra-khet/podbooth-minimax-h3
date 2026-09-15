#!/usr/bin/env python3
"""Thin sidecar panel for the PodBooth MiniMax H3 worker.

The daily-driver booth lives in the parent repo: `h3_fl2va_gui.py` via `.\run-fl2va.ps1`
on port **7864**. This file stays as a worker-repo convenience and defaults to 7865
so it cannot collide with the parent GUI.
"""

from __future__ import annotations

import argparse
import os
import time
from datetime import datetime
from pathlib import Path

import gradio as gr
from dotenv import load_dotenv

from generate_video_client import GenerateVideoClient

APP_DIR = Path(__file__).resolve().parent
load_dotenv(APP_DIR / ".env")
os.environ.setdefault("GRADIO_ANALYTICS_ENABLED", "False")

OUTPUT_DIR = APP_DIR / "outputs"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

DEFAULT_PROMPT = (
    "The subject from Picture 1 begins to move. Camera holds on the opening frame, "
    "then a slow push-in. Soft room tone, no dialogue."
)


def _client() -> GenerateVideoClient:
    endpoint = os.getenv("RUNPOD_ENDPOINT_ID", "").strip()
    api_key = os.getenv("RUNPOD_API_KEY", "").strip()
    if not endpoint or not api_key:
        raise gr.Error("Set RUNPOD_ENDPOINT_ID and RUNPOD_API_KEY in the environment or .env")
    return GenerateVideoClient(endpoint, api_key)


def _parse_loras(lora_text: str) -> list[dict]:
    items: list[dict] = []
    for raw in (lora_text or "").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "," in line:
            name, strength = line.split(",", 1)
            items.append({"name": name.strip(), "strength": float(strength.strip())})
        else:
            items.append({"name": line, "strength": 1.0})
    return items


def submit_i2v(
    start_image,
    end_image,
    prompt: str,
    negative_prompt: str,
    duration: int,
    steps: int,
    seed: int,
    width: int,
    height: int,
    lora_text: str,
    disable_audio: bool,
    volume_start: str,
    volume_end: str,
):
    log_lines = []

    def log(message: str) -> None:
        stamp = datetime.now().strftime("%H:%M:%S")
        log_lines.append(f"[{stamp}] {message}")

    try:
        client = _client()
        start_src = (volume_start or "").strip() or start_image
        if not start_src:
            raise gr.Error("Start image is required (upload or /runpod-volume path).")
        end_src = (volume_end or "").strip() or end_image or None
        loras = _parse_loras(lora_text)
        log(f"Submitting I2V duration={duration}s {width}x{height} steps={steps} seed={seed}")
        if end_src:
            log("End frame attached — FL2VA last-frame path.")
        if loras:
            log(f"LoRAs: {', '.join(item['name'] for item in loras)}")
        started = time.time()
        result = client.create_video_i2v(
            image_path=start_src,
            end_image_path=end_src,
            prompt=prompt,
            negative_prompt=negative_prompt or None,
            duration=int(duration),
            steps=int(steps),
            seed=int(seed),
            width=int(width),
            height=int(height),
            loras=loras,
            disable_audio=bool(disable_audio),
        )
        elapsed = time.time() - started
        if result.get("status") != "COMPLETED":
            log(f"Failed after {elapsed:.0f}s: {result.get('error') or result.get('status')}")
            return None, "\n".join(log_lines)
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        out_path = str(OUTPUT_DIR / f"h3_i2v_{stamp}.mp4")
        if not client.save_video_result(result, out_path):
            log("Job completed but saving the mp4 failed.")
            return None, "\n".join(log_lines)
        log(f"Done in {elapsed:.0f}s → {out_path}")
        return out_path, "\n".join(log_lines)
    except Exception as exc:
        log(str(exc))
        return None, "\n".join(log_lines)


def build_app() -> gr.Blocks:
    with gr.Blocks(title="PodBooth MiniMax H3") as demo:
        gr.Markdown("# PodBooth MiniMax H3")
        gr.Markdown(
            "Local control panel for the RunPod serverless worker. "
            "v1 is **I2V / first–last (FL2VA)** only. Ref2Vid is not wired yet."
        )
        with gr.Tabs():
            with gr.Tab("I2V / First–Last"):
                with gr.Row():
                    start_image = gr.Image(label="Start frame", type="filepath")
                    end_image = gr.Image(label="End frame (optional)", type="filepath")
                with gr.Row():
                    volume_start = gr.Textbox(
                        label="Or start path on the volume",
                        placeholder="/runpod-volume/inputs/start.png",
                    )
                    volume_end = gr.Textbox(
                        label="Or end path on the volume",
                        placeholder="/runpod-volume/inputs/end.png",
                    )
                prompt = gr.Textbox(label="Prompt", value=DEFAULT_PROMPT, lines=8)
                negative_prompt = gr.Textbox(
                    label="Negative prompt (folded into the prompt; H3 has no native negative slot)",
                    lines=2,
                )
                with gr.Row():
                    duration = gr.Dropdown(choices=[5, 10, 15], value=5, label="Duration (seconds)")
                    steps = gr.Slider(minimum=4, maximum=30, value=20, step=1, label="Steps")
                    seed = gr.Number(value=42, precision=0, label="Seed")
                with gr.Row():
                    width = gr.Number(value=768, precision=0, label="Width (multiple of 32)")
                    height = gr.Number(value=1152, precision=0, label="Height (multiple of 32)")
                    disable_audio = gr.Checkbox(value=False, label="Disable native audio")
                lora_text = gr.Textbox(
                    label="LoRAs (one per line: filename.safetensors, strength)",
                    placeholder="minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors, 1.0",
                    lines=3,
                )
                submit = gr.Button("Generate", variant="primary")
                status = gr.Textbox(label="Status log", lines=10)
                video = gr.Video(label="Result")
                submit.click(
                    submit_i2v,
                    inputs=[
                        start_image,
                        end_image,
                        prompt,
                        negative_prompt,
                        duration,
                        steps,
                        seed,
                        width,
                        height,
                        lora_text,
                        disable_audio,
                        volume_start,
                        volume_end,
                    ],
                    outputs=[video, status],
                )
            with gr.Tab("Ref2Vid"):
                gr.Markdown(
                    "Ref2VA is **not in v1**. Same worker will grow a second graph once "
                    "`workflows/h3_r2v_api.json` is exported from the official R2V template."
                )
    return demo


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="PodBooth MiniMax H3 local UI")
    parser.add_argument("--server-name", default="0.0.0.0")
    parser.add_argument("--server-port", type=int, default=7865)
    parser.add_argument("--share", action="store_true")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    build_app().queue(default_concurrency_limit=1).launch(
        server_name=args.server_name,
        server_port=args.server_port,
        share=args.share,
    )
