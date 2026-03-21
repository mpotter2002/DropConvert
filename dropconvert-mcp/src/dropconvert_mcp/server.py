#!/usr/bin/env python3
import asyncio
import shutil
import subprocess
from pathlib import Path

import mcp.types as types
from mcp.server import Server
from mcp.server.stdio import stdio_server

# Optional dependencies — we check at runtime and give clear errors if missing
try:
    from PIL import Image
    import pillow_heif
    pillow_heif.register_heif_opener()
    HAS_PILLOW = True
except ImportError:
    HAS_PILLOW = False

try:
    from pdf2image import convert_from_path
    HAS_PDF2IMAGE = True
except ImportError:
    HAS_PDF2IMAGE = False

HAS_FFMPEG = shutil.which("ffmpeg") is not None

IMAGE_EXTS = {"heic", "heif", "jpg", "jpeg", "png"}
VIDEO_EXTS = {"mov", "mp4"}

server = Server("dropconvert")


@server.list_tools()
async def list_tools() -> list[types.Tool]:
    return [
        types.Tool(
            name="convert_file",
            description=(
                "Convert a file to a different format locally on this machine. "
                "Supported conversions: HEIC/JPG/PNG → jpg or png, MOV/MP4 → mp4, PDF → jpg or png. "
                "Output is saved next to the input file with the new extension."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "input_path": {
                        "type": "string",
                        "description": "Absolute path to the file to convert",
                    },
                    "output_format": {
                        "type": "string",
                        "enum": ["jpg", "png", "mp4"],
                        "description": "Target format",
                    },
                },
                "required": ["input_path", "output_format"],
            },
        )
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list[types.TextContent]:
    if name != "convert_file":
        raise ValueError(f"Unknown tool: {name}")

    input_path = Path(arguments["input_path"])
    output_format = arguments["output_format"]

    if not input_path.exists():
        raise ValueError(f"File not found: {input_path}")

    ext = input_path.suffix.lower().lstrip(".")
    output_path = input_path.with_suffix(f".{output_format}")

    if ext in IMAGE_EXTS and output_format in ("jpg", "png"):
        _convert_image(input_path, output_path, output_format)

    elif ext in VIDEO_EXTS and output_format == "mp4":
        _convert_video(input_path, output_path)

    elif ext == "pdf" and output_format in ("jpg", "png"):
        _convert_pdf(input_path, output_path, output_format)

    else:
        raise ValueError(
            f"Unsupported conversion: {ext} → {output_format}. "
            "Supported: HEIC/JPG/PNG → jpg/png, MOV/MP4 → mp4, PDF → jpg/png"
        )

    return [types.TextContent(type="text", text=f"Converted successfully. Output: {output_path}")]


def _convert_image(input_path: Path, output_path: Path, output_format: str) -> None:
    if not HAS_PILLOW:
        raise RuntimeError(
            "Pillow is not installed. Run: pip install pillow pillow-heif"
        )
    img = Image.open(input_path)
    if output_format == "jpg":
        img = img.convert("RGB")
        img.save(output_path, "JPEG", quality=92)
    else:
        img.save(output_path, "PNG")


def _convert_video(input_path: Path, output_path: Path) -> None:
    if not HAS_FFMPEG:
        raise RuntimeError(
            "ffmpeg is not installed. "
            "Linux: sudo apt install ffmpeg | Mac: brew install ffmpeg"
        )
    result = subprocess.run(
        ["ffmpeg", "-i", str(input_path), "-y", str(output_path)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg failed: {result.stderr.strip()}")


def _convert_pdf(input_path: Path, output_path: Path, output_format: str) -> None:
    if not HAS_PDF2IMAGE:
        raise RuntimeError(
            "pdf2image is not installed. Run: pip install pdf2image\n"
            "Also requires poppler: Linux: sudo apt install poppler-utils | Mac: brew install poppler"
        )
    fmt = "JPEG" if output_format == "jpg" else "PNG"
    images = convert_from_path(input_path, dpi=200)
    if not images:
        raise RuntimeError("Could not read PDF — no pages found")
    images[0].save(output_path, fmt)


async def _main() -> None:
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options(),
        )


def main() -> None:
    asyncio.run(_main())


if __name__ == "__main__":
    main()
