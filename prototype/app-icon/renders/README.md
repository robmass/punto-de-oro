# Stroke-weight test — the court icon (#11)

Settles whether the court's original stroke weights survive the small icon sizes.
Claimed during the first pass that they did not; the renders show they do.

- `bthin.svg` — the court as first drawn (centre service line, strokes 2–3.5). **Winner.**
- `bmid.svg` — thinnest strokes nudged to 2.5, net 4, ball r 7.5. Indistinguishable from thin.
- `bthick.svg` — centre line dropped, strokes 3.5–6, ball r 9. **Rejected** — reads as a striped ladder, not a court.

`*_small_x.png` ≈ 48px icon, `*_big_x.png` ≈ 88px icon, each upscaled 8×/5× nearest-neighbour
so individual pixels are visible.

Reproduce (macOS, no image tooling required):

    qlmanage -t -s 82 -o . bthin.svg      # ≈48px icon; -s 150 for ≈88px
    python3 -c "import sys;sys.path.insert(0,'.');from png import *;w,h,p=read_png('bthin.svg.png');write_png('out.png',w*8,h*8,upscale(p,8))"

`png.py` is a dependency-free PNG decoder/encoder + nearest-neighbour upscaler, written
for this test because the machine had no rasteriser or PIL.
