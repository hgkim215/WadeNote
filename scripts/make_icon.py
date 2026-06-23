#!/usr/bin/env python3
"""Render WadeNote app icon (1024x1024) from the design's SVG glyph geometry.
Light + dark masters. Glyph: white note page + masked •••• dots + blue lock badge."""
from PIL import Image, ImageDraw
import os

S = 1024
SC = S / 24.0  # SVG viewBox is 0..24

def lerp(a, b, t): return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

def gradient(c0, c1):
    img = Image.new("RGB", (S, S), c0)
    px = img.load()
    for y in range(S):
        for x in range(S):
            # 160deg diagonal-ish: blend by (x+y)
            t = (x + y) / (2*S)
            px[x, y] = lerp(c0, c1, t)
    return img

def rr(d, x, y, w, h, r, **kw):
    d.rounded_rectangle([x*SC, y*SC, (x+w)*SC, (y+h)*SC], radius=r*SC, **kw)

def circle(d, cx, cy, r, fill):
    d.ellipse([(cx-r)*SC, (cy-r)*SC, (cx+r)*SC, (cy+r)*SC], fill=fill)

def draw_glyph(img):
    d = ImageDraw.Draw(img)
    # 인앱 글리프(WadeNoteGlyph.swift)와 동일한 좌표·색.
    WHITE=(255,255,255); INK=(28,28,34); BLUE=(61,116,255); DOT=(196,196,206)
    rr(d, 4.6, 3.3, 14.8, 17.4, 3.3, fill=WHITE)          # note body
    rr(d, 7.2, 6.9, 7.0, 1.7, 0.85, fill=INK)             # title line
    rr(d, 7.2, 10.6, 9.0, 1.5, 0.75, fill=BLUE)           # blue line
    for cx in (7.9, 10.1, 12.3):                          # masked dots
        circle(d, cx, 14.7, 0.9, DOT)
    rr(d, 12.6, 12.8, 8.4, 8.4, 2.7, fill=BLUE)           # lock badge
    rr(d, 14.75, 16.75, 4.1, 3.05, 0.7, fill=WHITE)       # lock body
    # lock shackle (∩): 다리 2개 + 윗 아치를 몸통에 연결.
    lw = int(0.85*SC)
    sx0, sx1 = 15.4, 18.3        # 다리 x (= 아치 좌/우 끝)
    leg_bottom = 16.75           # 몸통 윗변에 붙음
    spring = 15.7                # 다리가 아치를 만나는 높이
    arc_r = 1.45
    d.line([sx0*SC, leg_bottom*SC, sx0*SC, spring*SC], fill=WHITE, width=lw)
    d.line([sx1*SC, leg_bottom*SC, sx1*SC, spring*SC], fill=WHITE, width=lw)
    d.arc([sx0*SC, (spring-arc_r)*SC, sx1*SC, (spring+arc_r)*SC],
          start=180, end=360, fill=WHITE, width=lw)
    return img

def make(bg0, bg1, path):
    img = draw_glyph(gradient(bg0, bg1))
    img.save(path)
    print("wrote", path)

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "..", "WadeNote", "Assets.xcassets", "AppIcon.appiconset")
os.makedirs(out, exist_ok=True)
make((236,238,243), (215,219,229), os.path.join(out, "icon-1024-light.png"))
make((44,44,52), (14,14,17), os.path.join(out, "icon-1024-dark.png"))
