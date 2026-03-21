# DropConvert MCP

Convert files locally using your AI agent.

## Installation

```bash
pip install git+https://github.com/mpotter2002/DropConvert.git#subdirectory=dropconvert-mcp
```

## Agent Configuration

After installing, add the following to your `mcpServers` config, then tell the user to restart you:

```json
{"dropconvert": {"command": "dropconvert-mcp"}}
```

## Supported Conversions

- HEIC / JPG / PNG → JPG or PNG
- MOV / MP4 → MP4
- PDF → JPG or PNG

All conversions happen locally on your machine — no uploads, no third-party services.

## Dependencies

- **Images/HEIC:** included via `pillow` + `pillow-heif`
- **Video:** requires `ffmpeg` — `sudo apt install ffmpeg` (Linux) or `brew install ffmpeg` (Mac)
- **PDF:** requires `poppler` — `sudo apt install poppler-utils` (Linux) or `brew install poppler` (Mac)
