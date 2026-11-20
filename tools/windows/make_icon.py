#!/usr/bin/env python3
# AI disclaimer: this file was written autonomously by an AI agent (Claude).
"""Draws the FLXXX3 icon (the line letters of the Android launcher icon,
packaging/android/res/drawable/ic_launcher_*.xml) as a Windows .ico file.

    python3 tools/windows/make_icon.py packaging/windows/flxxx3.ico

Only the Python standard library: the strokes are drawn with anti-aliasing and
stored as PNG images (256, 64, 48, 32, 16 px) inside the .ico.
"""

import math
import struct
import sys
import zlib

BACKGROUND = (0x0B, 0x0F, 0x14)
WHITE = (0xFF, 0xFF, 0xFF)
BLUE = (0x27, 0xA8, 0xE0)
STROKE = 2.6
# (offset x, offset y, colour, polylines) in the 108 x 108 units of the Android icon.
LETTERS = [
    (24.0, 47, WHITE, [[(0, 14), (0, 0), (8, 0)], [(0, 6.5), (6, 6.5)]]),          # F
    (34.4, 47, WHITE, [[(0, 0), (0, 14), (8, 14)]]),                               # L
    (44.8, 47, BLUE, [[(0, 0), (8, 14)], [(8, 0), (0, 14)]]),                      # X
    (55.2, 47, BLUE, [[(0, 0), (8, 14)], [(8, 0), (0, 14)]]),                      # X
    (65.6, 47, BLUE, [[(0, 0), (8, 14)], [(8, 0), (0, 14)]]),                      # X
    (76.0, 47, WHITE, [[(0, 1), (8, 1), (8, 13), (0, 13)], [(3, 7), (8, 7)]]),     # 3
]
# The letters fill only the middle of the Android icon (it is cut to a circle there):
# on Windows they are drawn larger, the square from 20 to 88 units.
VIEW_MIN, VIEW_MAX = 20.0, 88.0


def segment_distance(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    length2 = dx * dx + dy * dy
    t = 0.0 if length2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length2))
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(px - cx, py - cy)


def render(size):
    scale = size / (VIEW_MAX - VIEW_MIN)
    segments = []
    for ox, oy, colour, lines in LETTERS:
        for line in lines:
            for (x0, y0), (x1, y1) in zip(line, line[1:]):
                segments.append(((ox + x0 - VIEW_MIN) * scale, (oy + y0 - VIEW_MIN) * scale,
                                 (ox + x1 - VIEW_MIN) * scale, (oy + y1 - VIEW_MIN) * scale, colour))
    half = STROKE * scale / 2
    radius = size * 0.18  # rounded corners of the background
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            px, py = x + 0.5, y + 0.5
            # Background with rounded corners.
            cx = min(max(px, radius), size - radius)
            cy = min(max(py, radius), size - radius)
            bg_alpha = max(0.0, min(1.0, radius - math.hypot(px - cx, py - cy) + 0.5))
            r, g, b = BACKGROUND
            for ax, ay, bx, by, colour in segments:
                cover = max(0.0, min(1.0, half - segment_distance(px, py, ax, ay, bx, by) + 0.5))
                if cover > 0:
                    r = r + (colour[0] - r) * cover
                    g = g + (colour[1] - g) * cover
                    b = b + (colour[2] - b) * cover
            row += bytes((round(r), round(g), round(b), round(bg_alpha * 255)))
        rows.append(bytes(row))
    return rows


def png(size, rows):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    raw = b"".join(b"\x00" + r for r in rows)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "flxxx3.ico"
    sizes = [256, 64, 48, 32, 16]
    images = [png(s, render(s)) for s in sizes]
    header = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    entries = b""
    for s, data in zip(sizes, images):
        entries += struct.pack("<BBBBHHII", s % 256, s % 256, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
    with open(out, "wb") as f:
        f.write(header + entries + b"".join(images))
    print("written", out)


if __name__ == "__main__":
    main()
