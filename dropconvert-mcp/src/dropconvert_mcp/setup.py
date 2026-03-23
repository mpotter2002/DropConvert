#!/usr/bin/env python3
"""
dropconvert-mcp-setup — install system dependencies for DropConvert MCP server.

Installs ffmpeg (video conversion) and poppler (PDF conversion) for your OS.
Run once after pip install dropconvert-mcp.
"""
import platform
import shutil
import subprocess
import sys


def _run(cmd: list[str]) -> bool:
    print(f"  Running: {' '.join(cmd)}")
    result = subprocess.run(cmd)
    return result.returncode == 0


def _check(binary: str) -> bool:
    return shutil.which(binary) is not None


def main() -> None:
    os_name = platform.system()
    print("DropConvert MCP — system dependency setup")
    print(f"Detected OS: {os_name}\n")

    need_ffmpeg = not _check("ffmpeg")
    need_poppler = not _check("pdftoppm")

    if not need_ffmpeg and not need_poppler:
        print("✅ All dependencies already installed! Nothing to do.")
        return

    if need_ffmpeg:
        print("📦 ffmpeg not found — needed for video conversion (MOV/MP4)")
    if need_poppler:
        print("📦 poppler not found — needed for PDF conversion")

    print()

    if os_name == "Darwin":
        # macOS — use Homebrew
        if not _check("brew"):
            print("❌ Homebrew not found. Install it first: https://brew.sh")
            sys.exit(1)
        if need_ffmpeg:
            print("Installing ffmpeg via Homebrew...")
            if _run(["brew", "install", "ffmpeg"]):
                print("✅ ffmpeg installed")
            else:
                print("❌ ffmpeg install failed — try: brew install ffmpeg")
        if need_poppler:
            print("Installing poppler via Homebrew...")
            if _run(["brew", "install", "poppler"]):
                print("✅ poppler installed")
            else:
                print("❌ poppler install failed — try: brew install poppler")

    elif os_name == "Linux":
        # Linux — try apt, then dnf, then pacman
        if _check("apt-get"):
            pkgs = []
            if need_ffmpeg:
                pkgs.append("ffmpeg")
            if need_poppler:
                pkgs.append("poppler-utils")
            print(f"Installing {', '.join(pkgs)} via apt...")
            if _run(["sudo", "apt-get", "install", "-y"] + pkgs):
                print(f"✅ {', '.join(pkgs)} installed")
            else:
                print(f"❌ apt install failed — try: sudo apt install {' '.join(pkgs)}")

        elif _check("dnf"):
            pkgs = []
            if need_ffmpeg:
                pkgs.append("ffmpeg")
            if need_poppler:
                pkgs.append("poppler-utils")
            print(f"Installing {', '.join(pkgs)} via dnf...")
            if _run(["sudo", "dnf", "install", "-y"] + pkgs):
                print(f"✅ {', '.join(pkgs)} installed")
            else:
                print(f"❌ dnf install failed — try: sudo dnf install {' '.join(pkgs)}")

        elif _check("pacman"):
            pkgs = []
            if need_ffmpeg:
                pkgs.append("ffmpeg")
            if need_poppler:
                pkgs.append("poppler")
            print(f"Installing {', '.join(pkgs)} via pacman...")
            if _run(["sudo", "pacman", "-S", "--noconfirm"] + pkgs):
                print(f"✅ {', '.join(pkgs)} installed")
            else:
                print(f"❌ pacman install failed — try: sudo pacman -S {' '.join(pkgs)}")

        else:
            print("❌ No supported package manager found (apt, dnf, pacman).")
            print("   Please install manually:")
            if need_ffmpeg:
                print("   ffmpeg:  https://ffmpeg.org/download.html")
            if need_poppler:
                print("   poppler: https://poppler.freedesktop.org")
            sys.exit(1)

    elif os_name == "Windows":
        print("Windows detected — please install manually:")
        if need_ffmpeg:
            print("  ffmpeg:  https://ffmpeg.org/download.html#build-windows")
        if need_poppler:
            print("  poppler: https://github.com/oschwartz10612/poppler-windows/releases")
        print("\nOr use winget:")
        if need_ffmpeg:
            print("  winget install ffmpeg")
        if need_poppler:
            print("  winget install poppler")
        sys.exit(1)

    else:
        print(f"❌ Unsupported OS: {os_name}")
        sys.exit(1)

    print("\n✅ Setup complete! DropConvert MCP is ready for video and PDF conversion.")


if __name__ == "__main__":
    main()
