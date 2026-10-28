#!/usr/bin/env python3
"""Build a one-shot Nahj intro and a cyclic, glow-free Plymouth background.

All frames are decoded from the supplied video. The loop contains only frames
after the glow has settled, with an overlapping dissolve across its boundary.
No frame-rate reduction, palette quantization, reversal, or AI redraw is used.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
SOURCE = HERE / "source" / "nahj.mp4"
SOURCE_SHA256 = "7e62194861a2ce7f6c7e3fa56d66d4b26f827354d2fc3e656253f4dff7cdfa08"
FPS = 24
SIZE = (1280, 720)
SOURCE_FRAMES = 240
QUIET_START = 108  # 4.5s; both the sweep and full glow have finished.
OVERLAP = 24       # One second; no glow frames enter the wrap dissolve.
INTRO_FRAMES = QUIET_START + OVERLAP
LOOP_FRAMES = SOURCE_FRAMES - INTRO_FRAMES
MARKER = ".nahj-generated"


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def sha256(path: Path) -> str:
    return hashlib.file_digest(path.open("rb"), "sha256").hexdigest()


def read_frame(directory: Path, number: int) -> Image.Image:
    with Image.open(directory / f"source-{number}.png") as image:
        if image.size != SIZE:
            raise ValueError(f"Unexpected source dimensions: {image.size}")
        return image.convert("RGB")


def generate_frames(decoded: Path, output: Path) -> None:
    for number in range(INTRO_FRAMES):
        shutil.copyfile(decoded / f"source-{number}.png", output / f"intro-{number}.png")

    # The first loop frame immediately follows the last intro frame. Following
    # the dissolve, the next cycle immediately follows the clean head segment.
    plain_frames = SOURCE_FRAMES - OVERLAP - INTRO_FRAMES
    for number in range(plain_frames):
        shutil.copyfile(
            decoded / f"source-{INTRO_FRAMES + number}.png",
            output / f"loop-{number}.png",
        )
    for number in range(OVERLAP):
        tail = read_frame(decoded, SOURCE_FRAMES - OVERLAP + number)
        head = read_frame(decoded, QUIET_START + number)
        t = number / (OVERLAP - 1)
        weight = t * t * (3 - 2 * t)  # Smooth derivative at both dissolve ends.
        Image.blend(tail, head, weight).save(output / f"loop-{plain_frames + number}.png")


def make_preview(output: Path, preview: Path) -> None:
    preview.mkdir(parents=True, exist_ok=True)
    # Deliberately a clean still: this image is also used by the installer.
    shutil.copyfile(output / "loop-0.png", preview / "nahj-background.png")
    selected = [
        ("intro-0.png", "0.0s — intro begins"),
        ("intro-24.png", "1.0s — feather sweep"),
        ("intro-84.png", "3.5s — full glow"),
        ("intro-120.png", "5.0s — glow has settled"),
        ("loop-0.png", "5.5s — background loop"),
        ("loop-107.png", "10.0s — wrap to moving background"),
    ]
    sheet = Image.new("RGB", (960, 3 * 300), "#0b1e28")
    draw = ImageDraw.Draw(sheet)
    for index, (filename, label) in enumerate(selected):
        with Image.open(output / filename) as frame:
            thumb = frame.resize((480, 270), Image.Resampling.LANCZOS)
        x, y = (index % 2) * 480, (index // 2) * 300
        sheet.paste(thumb, (x, y))
        draw.text((x + 10, y + 277), label, fill="#e4f3f7")
    sheet.save(preview / "animation-preview.jpg", quality=93)

    # Three loop repetitions make the wrap and absence of repeated glow visible.
    with tempfile.TemporaryDirectory(prefix="nahj-preview-") as temporary:
        concat = Path(temporary) / "frames.ffconcat"
        with concat.open("w", encoding="utf-8") as handle:
            handle.write("ffconcat version 1.0\n")
            sequence = [output / f"intro-{n}.png" for n in range(INTRO_FRAMES)]
            sequence += [output / f"loop-{n}.png" for _ in range(3) for n in range(LOOP_FRAMES)]
            for frame in sequence:
                # ffconcat is a file format, not shell code. Quote its path syntax.
                escaped = str(frame).replace("'", "'\\''")
                handle.write(f"file '{escaped}'\nduration {1 / FPS:.12f}\n")
            escaped = str(sequence[-1]).replace("'", "'\\''")
            handle.write(f"file '{escaped}'\n")
        run("ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-safe", "0", "-i", str(concat),
            "-r", str(FPS), "-frames:v", str(len(sequence)), "-c:v", "libx264", "-preset", "medium",
            "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an",
            str(preview / "nahj-boot-preview.mp4"))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="Plymouth theme output directory")
    parser.add_argument("--preview-dir", type=Path, help="Optional review artifacts outside the source tree")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists() and not (output / MARKER).is_file():
        raise SystemExit(f"Refusing to replace an unmarked directory: {output}")
    if sha256(SOURCE) != SOURCE_SHA256:
        raise SystemExit("The supplied video checksum does not match; refusing altered input")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="nahj-frames-") as temporary:
        decoded = Path(temporary)
        run("ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(SOURCE),
            "-map", "0:v:0", "-vf", f"fps={FPS}", "-frames:v", str(SOURCE_FRAMES),
            "-start_number", "0", "-pix_fmt", "rgb24", str(decoded / "source-%d.png"))
        if len(list(decoded.glob("source-*.png"))) != SOURCE_FRAMES:
            raise SystemExit("Input did not decode into the expected 240 source frames")
        with tempfile.TemporaryDirectory(prefix=".nahj-theme-", dir=output.parent) as stage_name:
            stage = Path(stage_name)
            generate_frames(decoded, stage)
            shutil.copyfile(HERE / "nahj.plymouth", stage / "nahj.plymouth")
            script = (HERE / "nahj.script.in").read_text()
            for key, value in {"FPS": FPS, "INTRO_FRAMES": INTRO_FRAMES, "LOOP_FRAMES": LOOP_FRAMES,
                               "WIDTH": SIZE[0], "HEIGHT": SIZE[1]}.items():
                script = script.replace(f"@{key}@", str(value))
            (stage / "nahj.script").write_text(script)
            manifest = {
                "source_sha256": SOURCE_SHA256, "fps": FPS, "width": SIZE[0], "height": SIZE[1],
                "intro_frames": INTRO_FRAMES, "loop_frames": LOOP_FRAMES,
                "quiet_source_start_frame": QUIET_START, "crossfade_frames": OVERLAP,
                "frame_bytes": sum(frame.stat().st_size for frame in stage.glob("*.png")),
                "frames": {frame.name: sha256(frame) for frame in sorted(stage.glob("*.png"))},
            }
            (stage / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
            (stage / MARKER).write_text(SOURCE_SHA256 + "\n")
            if output.exists():
                shutil.rmtree(output)
            shutil.copytree(stage, output)
    print(json.dumps({key: value for key, value in manifest.items() if key != "frames"}, indent=2))
    if args.preview_dir:
        make_preview(output, args.preview_dir.resolve())


if __name__ == "__main__":
    main()
