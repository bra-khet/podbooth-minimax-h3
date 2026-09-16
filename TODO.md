# TODO

## Prospective: share-link friend auth (do not implement now)

- [ ] If this sidecar Gradio (`booth_ui.py`) or the parent `h3_fl2va_gui.py` is shown to friends via `share=True`, use Gradio's built-in `auth=` more creatively than one shared password: issue short-lived per-friend tokens / usernames with a limited number of logins.
- Context: `RUNPOD_API_KEY` is env-only and never a Gradio field, so a raw share link cannot steal the key. Anyone with the URL can still spend RunPod credits. Token logins are the next door when you actually start demoing this.
