#!/usr/bin/env python3
"""Verify generated frames with the installed Plymouth decoder, without a display."""
import argparse
import ctypes
import ctypes.util
import hashlib
import json
from pathlib import Path
import sys

from PIL import Image


def check(root):
    manifest = json.loads((root / "manifest.json").read_text())
    expected = {f"{phase}-{n}.bmp" for phase in ("intro", "loop")
                for n in range(manifest[f"{phase}_frames"])}
    if set(manifest["frames"]) != expected or {p.name for p in root.glob("*.bmp")} != expected:
        raise ValueError("Incomplete or unexpected frame sequence")
    size = (manifest["width"], manifest["height"])
    name = ctypes.util.find_library("ply-splash-graphics")
    if not name:
        raise RuntimeError("Install Plymouth to verify its actual image decoder")
    lib = ctypes.CDLL(name)
    lib.ply_image_new.argtypes = [ctypes.c_char_p]
    lib.ply_image_new.restype = ctypes.c_void_p
    for function, result in (("ply_image_load", ctypes.c_bool),
                             ("ply_image_get_width", ctypes.c_long),
                             ("ply_image_get_height", ctypes.c_long),
                             ("ply_image_get_data", ctypes.c_void_p),
                             ("ply_image_free", None)):
        getattr(lib, function).argtypes = [ctypes.c_void_p]
        getattr(lib, function).restype = result
    for filename in sorted(expected):
        path = root / filename
        if hashlib.sha256(path.read_bytes()).hexdigest() != manifest["frames"][filename]:
            raise ValueError(f"Frame checksum mismatch: {filename}")
        handle = lib.ply_image_new(bytes(path))
        if not handle:
            raise RuntimeError(f"Plymouth could not allocate {filename}")
        try:
            if not lib.ply_image_load(handle):
                raise ValueError(f"Plymouth cannot load {filename}")
            if (lib.ply_image_get_width(handle), lib.ply_image_get_height(handle)) != size:
                raise ValueError(f"Plymouth decoded the wrong dimensions: {filename}")
            data = ctypes.string_at(lib.ply_image_get_data(handle), size[0] * size[1] * 4)
            mode = "BGRA" if sys.byteorder == "little" else "ARGB"
            decoded = Image.frombytes("RGBA", size, data, "raw", mode)
            with Image.open(path) as reference:
                if decoded.tobytes() != reference.convert("RGBA").tobytes():
                    raise ValueError(f"Plymouth pixel mismatch: {filename}")
        finally:
            lib.ply_image_free(handle)
    print(json.dumps({"decoder": name, "frames_verified": len(expected),
                      "dimensions": size, "format": manifest["frame_format"]}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("theme", type=Path)
    check(parser.parse_args().theme.resolve())
