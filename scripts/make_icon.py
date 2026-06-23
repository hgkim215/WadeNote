#!/usr/bin/env python3
"""Render WadeNote app icon (1024x1024) from the design's glyph geometry.
Light + dark masters. Glyph: white note page + masked •••• dots + blue lock badge.
The glyph is drawn on a 4x supersampled layer and downscaled (LANCZOS) for smooth,
antialiased edges, then composited onto the gradient background."""
from PIL import Image, ImageDraw
import os

S = 1024
SS = 4                 # supersample factor for the glyph layer
L = S * SS
SC = L / 24.0          # glyph viewBox is 0..24, drawn at supersampled scale

def lerp(a, b, t): return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

def gradient(c0, c1):
    img = Image.new("RGB", (S, S), c0)
    px = img.load()
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2*S)        # ~160deg diagonal blend
            px[x, y] = lerp(c0, c1, t)
    return img

def glyph_layer():
    layer = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    WHITE=(255,255,255,255); INK=(28,28,34,255); BLUE=(61,116,255,255); DOT=(196,196,206,255)

    def rr(x, y, w, h, r, fill):
        d.rounded_rectangle([x*SC, y*SC, (x+w)*SC, (y+h)*SC], radius=r*SC, fill=fill)
    def circle(cx, cy, r, fill):
        d.ellipse([(cx-r)*SC, (cy-r)*SC, (cx+r)*SC, (cy+r)*SC], fill=fill)
    def half_disc(cx, cy, r, fill):          # top semicircle (∩), filled
        d.pieslice([(cx-r)*SC, (cy-r)*SC, (cx+r)*SC, (cy+r)*SC], start=180, end=360, fill=fill)
    def rect(x0, y0, x1, y1, fill):
        d.rectangle([x0*SC, y0*SC, x1*SC, y1*SC], fill=fill)

    rr(4.6, 3.3, 14.8, 17.4, 3.3, WHITE)     # note body
    rr(7.2, 6.9, 7.0, 1.7, 0.85, INK)        # title line
    rr(7.2, 10.6, 9.0, 1.5, 0.75, BLUE)      # blue line
    for cx in (7.9, 10.1, 12.3):             # masked dots
        circle(cx, 14.7, 0.9, DOT)
    rr(12.6, 12.8, 8.4, 8.4, 2.7, BLUE)      # lock badge
    rr(14.75, 16.75, 4.1, 3.05, 0.7, WHITE)  # lock body

    # Lock shackle (∩) as a filled half-annulus + legs that merge into the body.
    # Outer white block (half-disc + legs), then carve the inner opening with the
    # badge blue down to the body top so the legs blend seamlessly into the body.
    lw = 0.82
    sx0, sx1 = 15.55, 18.05
    cx = (sx0 + sx1) / 2.0
    ar = (sx1 - sx0) / 2.0
    spring = 15.85
    body_top = 16.75
    leg_bottom = 17.25
    ro, ri = ar + lw/2.0, ar - lw/2.0
    half_disc(cx, spring, ro, WHITE)                       # outer arch
    rect(cx-ro, spring, cx+ro, leg_bottom, WHITE)          # outer legs (into body)
    half_disc(cx, spring, ri, BLUE)                        # carve inner arch
    rect(cx-ri, spring, cx+ri, body_top, BLUE)             # carve inner gap (stop at body)

    return layer.resize((S, S), Image.LANCZOS)

def make(bg0, bg1, path):
    base = gradient(bg0, bg1).convert("RGBA")
    base.alpha_composite(glyph_layer())
    base.convert("RGB").save(path)
    print("wrote", path)

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "..", "WadeNote", "Assets.xcassets", "AppIcon.appiconset")
os.makedirs(out, exist_ok=True)
make((236,238,243), (215,219,229), os.path.join(out, "icon-1024-light.png"))
make((44,44,52), (14,14,17), os.path.join(out, "icon-1024-dark.png"))
