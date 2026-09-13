#!/usr/bin/env python3
"""Pixelate regions of a PNG and optionally crop.

usage: mask.py IN.png OUT.png [--box x0,y0,x1,y1 ...] [--crop x0,y0,x1,y1] [--k 14]
Coordinates are in the input image's pixels. --k is the pixelation factor.
"""
import sys
from PIL import Image

def main():
    a = sys.argv[1:]
    if len(a) < 2: print(__doc__); sys.exit(1)
    src, dst = a[0], a[1]; boxes = []; crop = None; k = 14
    i = 2
    while i < len(a):
        if a[i] == "--box": boxes.append(tuple(int(v) for v in a[i+1].split(","))); i += 2
        elif a[i] == "--crop": crop = tuple(int(v) for v in a[i+1].split(",")); i += 2
        elif a[i] == "--k": k = int(a[i+1]); i += 2
        else: i += 1
    im = Image.open(src).convert("RGB")
    for b in boxes:
        r = im.crop(b)
        r = r.resize((max(1, r.width // k), max(1, r.height // k)), Image.BILINEAR).resize(r.size, Image.NEAREST)
        im.paste(r, b)
    if crop: im = im.crop(crop)
    im.save(dst, optimize=True); print(dst, im.size)

if __name__ == "__main__":
    main()
