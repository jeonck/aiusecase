#!/usr/bin/env python3
"""Render command/output lines as a dark terminal PNG.

usage: render_terminal.py OUT.png < lines.txt
       render_terminal.py OUT.png --lines "$ kubectl get nodes" "node1 Ready"

Colors: lines starting with '$' green, '//' '==' '#' orange, FAIL/error/✗ red, else light gray.
Fonts: Menlo for ASCII lines, Nanum Gothic (assets/opengraph in this repo) for lines with Korean.
"""
import sys, os, re
from PIL import Image, ImageDraw, ImageFont

def main():
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    out = sys.argv[1]
    if "--lines" in sys.argv:
        lines = sys.argv[sys.argv.index("--lines") + 1:]
    else:
        lines = [l.rstrip("\n") for l in sys.stdin]
    repo = os.popen("git rev-parse --show-toplevel 2>/dev/null").read().strip() or "."
    mono = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 20)
    ko_path = os.path.join(repo, "assets/opengraph/NanumGothic-Regular.ttf")
    ko = ImageFont.truetype(ko_path, 21) if os.path.exists(ko_path) else mono
    W = 1500; H = 40 + len(lines) * 30 + 30
    im = Image.new("RGB", (W, H), (24, 24, 32)); d = ImageDraw.Draw(im)
    for i, l in enumerate(lines):
        f = ko if any(ord(c) > 127 for c in l) else mono
        if l.startswith("$") or l.startswith("PASS"): col = (130, 220, 150)
        elif l.startswith(("//", "==", "#")): col = (255, 200, 120)
        elif re.search(r"FAIL|error|Error|✗|timed out|exceeded", l): col = (255, 120, 120)
        else: col = (220, 220, 225)
        d.text((28, 30 + i * 30), l[:122], fill=col, font=f)
    im.save(out, optimize=True); print(out)

if __name__ == "__main__":
    main()
