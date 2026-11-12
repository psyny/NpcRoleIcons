"""
Generates the NpcRoleIcons drawn icon sets (128x128 32-bit TGA).

Usage:  python make_icons.py [icons_dir] [preview_png]
Needs Pillow. Every icon is drawn from simple shapes, so the sets are fully ours.
Writes one folder per style (see STYLES) plus Border_Ring.tga, the ring drawn
around the circle-cut Warcraft icon sets.
"""
import colorsys
import math
import os
import struct
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 1024          # working resolution (supersampled)
OUT = 128         # final icon size


def P(x, y):
    return (x * S, y * S)


def box(x1, y1, x2, y2):
    return [x1 * S, y1 * S, x2 * S, y2 * S]


def W(w):
    return max(1, int(w * S))


# ---------------------------------------------------------------- primitives

def circle(d, cx, cy, r, fill=255):
    d.ellipse(box(cx - r, cy - r, cx + r, cy + r), fill=fill)


def ring(d, cx, cy, r, w, fill=255):
    d.ellipse(box(cx - r, cy - r, cx + r, cy + r), outline=fill, width=W(w))


def line(d, pts, w, fill=255):
    d.line([P(*p) for p in pts], fill=fill, width=W(w), joint="curve")
    for p in (pts[0], pts[-1]):
        circle(d, p[0], p[1], w / 2, fill)


def poly(d, pts, fill=255):
    d.polygon([P(*p) for p in pts], fill=fill)


def rrect(d, x1, y1, x2, y2, r, fill=255):
    d.rounded_rectangle(box(x1, y1, x2, y2), radius=W(r), fill=fill)


def star(cx, cy, R, r, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        rad = R if i % 2 == 0 else r
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    return pts


def mirror(pts):
    return [(1 - x, y) for x, y in pts]


# ---------------------------------------------------------------- glyphs

def g_crosshair(d):
    ring(d, 0.5, 0.5, 0.22, 0.065)
    circle(d, 0.5, 0.5, 0.075)
    for a, b in (((0.5, 0.18), (0.5, 0.33)), ((0.5, 0.67), (0.5, 0.82)),
                 ((0.18, 0.5), (0.33, 0.5)), ((0.67, 0.5), (0.82, 0.5))):
        line(d, [a, b], 0.065)


def sword(d, flip=False):
    f = (lambda p: (1 - p[0], p[1])) if flip else (lambda p: p)
    line(d, [f((0.24, 0.24)), f((0.62, 0.62))], 0.095)
    line(d, [f((0.53, 0.71)), f((0.71, 0.53))], 0.075)
    line(d, [f((0.62, 0.62)), f((0.74, 0.74))], 0.065)
    c = f((0.775, 0.775))
    circle(d, c[0], c[1], 0.05)


def g_swords(d):
    sword(d)
    sword(d, True)


def g_x(d):
    line(d, [(0.31, 0.31), (0.69, 0.69)], 0.12)
    line(d, [(0.69, 0.31), (0.31, 0.69)], 0.12)


def g_bar(d):
    line(d, [(0.28, 0.5), (0.72, 0.5)], 0.13)


def g_check(d):
    line(d, [(0.27, 0.52), (0.44, 0.69), (0.74, 0.33)], 0.12)


def g_star(d):
    poly(d, star(0.5, 0.53, 0.32, 0.135))


def g_elite(d):
    line(d, [(0.28, 0.50), (0.5, 0.30), (0.72, 0.50)], 0.1)
    line(d, [(0.28, 0.72), (0.5, 0.52), (0.72, 0.72)], 0.1)


def g_skull(d):
    d.ellipse(box(0.26, 0.20, 0.74, 0.64), fill=255)
    rrect(d, 0.36, 0.52, 0.64, 0.80, 0.05)
    circle(d, 0.405, 0.45, 0.075, 0)
    circle(d, 0.595, 0.45, 0.075, 0)
    poly(d, [(0.5, 0.53), (0.465, 0.61), (0.535, 0.61)], 0)
    for x in (0.45, 0.5, 0.55):
        d.line([P(x, 0.68), P(x, 0.81)], fill=0, width=W(0.022))


def g_flame(d):
    poly(d, [(0.50, 0.15), (0.59, 0.31), (0.69, 0.44), (0.74, 0.58), (0.71, 0.71),
             (0.62, 0.80), (0.50, 0.84), (0.38, 0.80), (0.29, 0.71), (0.26, 0.58),
             (0.31, 0.44), (0.39, 0.52), (0.41, 0.38), (0.46, 0.27)])
    poly(d, [(0.50, 0.50), (0.57, 0.62), (0.58, 0.72), (0.50, 0.77), (0.42, 0.72), (0.44, 0.62)], 0)


def g_eye(d):
    pts = []
    for i in range(41):
        t = math.pi * i / 40
        pts.append((0.5 - 0.32 * math.cos(t), 0.5 - 0.19 * math.sin(t)))
    for i in range(41):
        t = math.pi * i / 40
        pts.append((0.5 + 0.32 * math.cos(t), 0.5 + 0.19 * math.sin(t)))
    poly(d, pts)
    circle(d, 0.5, 0.5, 0.135, 0)
    circle(d, 0.5, 0.5, 0.075)


def g_sparkle(d):
    poly(d, star(0.47, 0.53, 0.31, 0.075, n=4))
    poly(d, star(0.74, 0.27, 0.12, 0.035, n=4))


def g_tapped(d):
    ring(d, 0.5, 0.5, 0.24, 0.075)
    line(d, [(0.33, 0.33), (0.67, 0.67)], 0.075)


def g_paw(d):
    d.ellipse(box(0.34, 0.48, 0.66, 0.78), fill=255)
    for cx, cy in ((0.27, 0.42), (0.40, 0.29), (0.60, 0.29), (0.73, 0.42)):
        d.ellipse(box(cx - 0.07, cy - 0.085, cx + 0.07, cy + 0.085), fill=255)


def g_bag(d):
    d.ellipse(box(0.22, 0.38, 0.78, 0.84), fill=255)
    poly(d, [(0.39, 0.27), (0.61, 0.27), (0.57, 0.43), (0.43, 0.43)])
    d.ellipse(box(0.32, 0.17, 0.68, 0.31), fill=255)
    d.line([P(0.38, 0.40), P(0.62, 0.40)], fill=0, width=W(0.04))


def g_anvil(d):
    poly(d, [(0.14, 0.33), (0.82, 0.33), (0.82, 0.47), (0.67, 0.51), (0.62, 0.61),
             (0.71, 0.70), (0.71, 0.79), (0.29, 0.79), (0.29, 0.70), (0.38, 0.61),
             (0.34, 0.51), (0.27, 0.47), (0.14, 0.40)])


def g_book(d):
    poly(d, [(0.16, 0.28), (0.47, 0.35), (0.47, 0.78), (0.16, 0.71)])
    poly(d, mirror([(0.16, 0.28), (0.47, 0.35), (0.47, 0.78), (0.16, 0.71)]))
    for y in (0.45, 0.54, 0.63):
        d.line([P(0.22, y - 0.02), P(0.41, y + 0.025)], fill=0, width=W(0.022))
        d.line([P(0.78, y - 0.02), P(0.59, y + 0.025)], fill=0, width=W(0.022))


def g_mug(d):
    d.ellipse(box(0.52, 0.40, 0.82, 0.70), outline=255, width=W(0.07))
    rrect(d, 0.24, 0.32, 0.62, 0.82, 0.05)
    circle(d, 0.31, 0.31, 0.08)
    circle(d, 0.44, 0.26, 0.095)
    circle(d, 0.57, 0.31, 0.08)
    for x in (0.37, 0.49):
        d.line([P(x, 0.44), P(x, 0.74)], fill=0, width=W(0.028))


def g_horseshoe(d):
    cx, cy, r, w = 0.5, 0.47, 0.245, 0.11
    d.arc(box(cx - r - w / 2, cy - r - w / 2, cx + r + w / 2, cy + r + w / 2), 145, 395, fill=255, width=W(w))
    for ang in (165, 215, 270, 325, 375):
        a = math.radians(ang)
        circle(d, cx + r * math.cos(a), cy + r * math.sin(a), 0.022, 0)
    for ang in (145, 395):
        a = math.radians(ang)
        circle(d, cx + r * math.cos(a), cy + r * math.sin(a), w / 2)


def g_wings(d):
    wing = [(0.47, 0.48), (0.12, 0.28), (0.18, 0.40), (0.10, 0.45), (0.20, 0.54),
            (0.16, 0.61), (0.30, 0.66), (0.45, 0.62)]
    poly(d, wing)
    poly(d, mirror(wing))
    d.ellipse(box(0.45, 0.36, 0.55, 0.72), fill=255)


def g_chest(d):
    rrect(d, 0.18, 0.28, 0.82, 0.52, 0.10)
    rrect(d, 0.18, 0.46, 0.82, 0.80, 0.03)
    d.line([P(0.18, 0.49), P(0.82, 0.49)], fill=0, width=W(0.035))
    rrect(d, 0.43, 0.40, 0.57, 0.60, 0.025, 0)
    rrect(d, 0.455, 0.425, 0.545, 0.575, 0.015)
    circle(d, 0.5, 0.49, 0.022, 0)


def g_gavel(d):
    a = math.radians(-45)
    cx, cy, hw, hh = 0.40, 0.38, 0.19, 0.085
    pts = []
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        x, y = sx * hw, sy * hh
        pts.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
    poly(d, pts)
    line(d, [(0.45, 0.43), (0.72, 0.70)], 0.065)
    rrect(d, 0.50, 0.76, 0.86, 0.85, 0.03)


def g_shirt(d):
    poly(d, [(0.34, 0.20), (0.43, 0.20), (0.50, 0.29), (0.57, 0.20), (0.66, 0.20),
             (0.85, 0.35), (0.77, 0.48), (0.68, 0.42), (0.68, 0.81), (0.32, 0.81),
             (0.32, 0.42), (0.23, 0.48), (0.15, 0.35)])


def g_scissors(d):
    line(d, [(0.43, 0.60), (0.67, 0.18)], 0.075)
    line(d, [(0.57, 0.60), (0.33, 0.18)], 0.075)
    ring(d, 0.35, 0.71, 0.095, 0.05)
    ring(d, 0.65, 0.71, 0.095, 0.05)
    circle(d, 0.5, 0.47, 0.025, 0)


def g_shield(d):
    poly(d, [(0.5, 0.16), (0.79, 0.27), (0.77, 0.52), (0.67, 0.70), (0.5, 0.84),
             (0.33, 0.70), (0.23, 0.52), (0.21, 0.27)])
    d.line([P(0.5, 0.27), P(0.5, 0.75)], fill=0, width=W(0.045))
    d.line([P(0.30, 0.44), P(0.70, 0.44)], fill=0, width=W(0.045))


def g_flag(d):
    line(d, [(0.30, 0.18), (0.30, 0.84)], 0.055)
    poly(d, [(0.32, 0.20), (0.78, 0.28), (0.63, 0.39), (0.78, 0.51), (0.32, 0.52)])


def g_halo(d):
    d.ellipse(box(0.30, 0.13, 0.70, 0.29), outline=255, width=W(0.045))
    circle(d, 0.5, 0.45, 0.12)
    d.pieslice(box(0.24, 0.60, 0.76, 1.04), 180, 360, fill=255)


def g_arrow_up(d):
    poly(d, [(0.5, 0.16), (0.80, 0.48), (0.62, 0.48), (0.62, 0.82), (0.38, 0.82),
             (0.38, 0.48), (0.20, 0.48)])


def g_portal(d):
    d.ellipse(box(0.25, 0.16, 0.75, 0.84), outline=255, width=W(0.065))
    d.ellipse(box(0.35, 0.30, 0.65, 0.70), outline=255, width=W(0.05))
    d.ellipse(box(0.44, 0.43, 0.56, 0.57), fill=255)


def g_envelope(d):
    rrect(d, 0.18, 0.30, 0.82, 0.72, 0.03)
    d.line([P(0.20, 0.32), P(0.5, 0.55), P(0.80, 0.32)], fill=0, width=W(0.04), joint="curve")


# ---------------------------------------------------------------- catalog
# key -> (glyph, badge color, metal used by the Brown and Metal style)

ICONS = {
    "quest_objective": (g_crosshair, "#E8A800", "gold"),
    "attackable":      (g_swords, "#B03A2E", "silver"),
    "hostile":         (g_x, "#D32F2F", "white"),
    "neutral":         (g_bar, "#D9A520", "gold"),
    "friendly":        (g_check, "#2E9E44", "white"),
    "rare":            (g_star, "#8FA3BF", "silver"),
    "elite":           (g_elite, "#C08A2B", "gold"),
    "boss":            (g_skull, "#7A1C1C", "gold"),
    "in_combat":       (g_flame, "#E8641B", "white"),
    "targeting_you":   (g_eye, "#B71C1C", "white"),
    "caster":          (g_sparkle, "#7E57C2", "silver"),
    "tapped":          (g_tapped, "#6D6D6D", "silver"),
    "battle_pet":      (g_paw, "#3E9C8F", "silver"),
    "vendor":          (g_bag, "#B8860B", "gold"),
    "repair":          (g_anvil, "#6F8592", "silver"),
    "trainer":         (g_book, "#1E78D2", "silver"),
    "innkeeper":       (g_mug, "#8D6E63", "gold"),
    "stable_master":   (g_horseshoe, "#6D4C41", "silver"),
    "flight_master":   (g_wings, "#2A9FD6", "silver"),
    "banker":          (g_chest, "#4E6A78", "gold"),
    "auctioneer":      (g_gavel, "#A8742A", "gold"),
    "transmog":        (g_shirt, "#D63C78", "silver"),
    "barber":          (g_scissors, "#26A69A", "silver"),
    "battlemaster":    (g_shield, "#B52A2A", "silver"),
    "guild":           (g_flag, "#3F51B5", "gold"),
    "spirit_healer":   (g_halo, "#3BA7D9", "white"),
    "item_upgrade":    (g_arrow_up, "#4CAF50", "gold"),
    "portal":          (g_portal, "#9032B0", "silver"),
    "mail":            (g_envelope, "#5A8FD8", "silver"),
}


# ---------------------------------------------------------------- rendering

def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def shade(rgb, f):
    if f >= 0:
        return tuple(int(c + (255 - c) * f) for c in rgb)
    return tuple(int(c * (1 + f)) for c in rgb)


def disk_mask(r):
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).ellipse(box(0.5 - r, 0.5 - r, 0.5 + r, 0.5 + r), fill=255)
    return m


def ring_mask(r, w):
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).ellipse(box(0.5 - r, 0.5 - r, 0.5 + r, 0.5 + r), outline=255, width=W(w))
    return m


def gradient(top, bottom, y1=0.0, y2=1.0):
    g = Image.new("RGBA", (1, S))
    for y in range(S):
        t = min(1.0, max(0.0, (y / (S - 1) - y1) / (y2 - y1)))
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return g.resize((S, S))


def solid(rgb, alpha):
    img = Image.new("RGBA", (S, S), rgb + (0,))
    img.putalpha(alpha)
    return img


def masked(img, alpha):
    img = img.copy()
    img.putalpha(alpha)
    return img


METALS = {
    "gold":   ((255, 240, 170), (190, 135, 40)),
    "silver": ((255, 255, 255), (140, 150, 162)),
    "white":  ((255, 255, 255), (222, 214, 200)),
}


def glyph_mask(glyph):
    mask = Image.new("L", (S, S), 0)
    glyph(ImageDraw.Draw(mask))
    return mask


def add_glyph(img, mask, fill, outline_rgb=(20, 14, 8), shadow=0.7, outline_width=11):
    """Drop shadow, dark outline, then the glyph filled with a color or an RGBA image."""
    outline = mask.filter(ImageFilter.GaussianBlur(outline_width)).point(lambda v: min(255, v * 4))
    shade_mask = ImageChops.offset(outline, 0, 16).filter(ImageFilter.GaussianBlur(8)).point(lambda v: v * shadow)
    img.alpha_composite(solid((0, 0, 0), shade_mask))
    img.alpha_composite(solid(outline_rgb, outline.point(lambda v: v * 0.9)))
    if isinstance(fill, tuple):
        img.alpha_composite(solid(fill, mask))
    else:
        img.alpha_composite(masked(fill, mask))


def badge(img, top, bottom, rim=(12, 12, 12), inner_rgb=None, gloss=60):
    img.alpha_composite(solid(rim, disk_mask(0.485)))
    img.alpha_composite(masked(gradient(top, bottom), disk_mask(0.44)))
    if gloss:
        g = Image.new("L", (S, S), 0)
        ImageDraw.Draw(g).ellipse(box(0.16, 0.08, 0.84, 0.52), fill=gloss)
        g = ImageChops.multiply(g.filter(ImageFilter.GaussianBlur(30)), disk_mask(0.44))
        img.alpha_composite(solid((255, 255, 255), g))
    if inner_rgb:
        inner = ring_mask(0.435, 0.012).point(lambda v: v * 0.35)
        img.alpha_composite(solid(inner_rgb, inner))


def metal_ring(img, r, w, top, bottom):
    img.alpha_composite(masked(gradient(top, bottom), ring_mask(r, w)))


# ---------------------------------------------------------------- styles

# The thick metal rim of the Brown and Metal style, shared by the badge styles.
GOLD_RIM = ((240, 205, 120), (120, 80, 28))
SILVER_RIM = ((248, 250, 255), (112, 120, 132))


def rim(img, colors):
    metal_ring(img, 0.462, 0.034, *colors)


def style_bright(glyph, color, metal, key=None):
    rgb = hex_rgb(color)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    badge(img, shade(rgb, 0.22), shade(rgb, -0.38))
    rim(img, SILVER_RIM)
    add_glyph(img, glyph_mask(glyph), (250, 248, 240))
    return img


def style_black_white(glyph, color, metal, key=None):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    badge(img, (58, 58, 62), (10, 10, 12), rim=(0, 0, 0), gloss=35)
    rim(img, SILVER_RIM)
    add_glyph(img, glyph_mask(glyph), (250, 250, 250), outline_rgb=(0, 0, 0))
    return img


def style_brown_metal(glyph, color, metal, key=None):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    badge(img, (112, 76, 44), (40, 24, 12), rim=(18, 10, 4), gloss=28)
    rim(img, GOLD_RIM)
    top, bottom = METALS[metal]
    add_glyph(img, glyph_mask(glyph), gradient(top, bottom, 0.2, 0.8), outline_rgb=(24, 12, 4))
    return img


def style_no_bg(glyph, color, metal, key=None):
    rgb = hex_rgb(color)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # the glyph alone, scaled up a little to use the space the badge took
    mask = glyph_mask(glyph)
    mask = mask.resize((int(S * 1.18), int(S * 1.18)), Image.LANCZOS)
    off = (mask.size[0] - S) // 2
    mask = mask.crop((off, off, off + S, off + S))
    # lighter than the badge colors so dark ones (skull, chest...) stay readable without a background
    add_glyph(img, mask, gradient(shade(rgb, 0.5), shade(rgb, 0.05), 0.15, 0.85),
              outline_rgb=(8, 6, 4), shadow=0.9, outline_width=14)
    return img


def grow(mask, px):
    """Mask grown (px > 0) or shrunk (px < 0) by about px working pixels."""
    if px < 0:
        return ImageChops.invert(grow(ImageChops.invert(mask), -px))
    return mask.filter(ImageFilter.GaussianBlur(px)).point(lambda v: 255 if v > 10 else 0)


# One neon color per role, spread around the color wheel (set in main()).
NEON_COLORS = {}


def neon_palette(keys):
    n = len(keys)
    step = 7 if n % 7 else 5  # walk the wheel in big steps so neighbours in the list differ
    for i, key in enumerate(keys):
        hue = ((i * step) % n) / n
        sat = 0.85 if i % 2 else 1.0
        r, g, b = colorsys.hsv_to_rgb(hue, sat, 1.0)
        NEON_COLORS[key] = (int(r * 255), int(g * 255), int(b * 255))


def style_scifi_neon(glyph, color, metal, key=None):
    neon = NEON_COLORS[key]
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    inside = disk_mask(0.465)
    img.alpha_composite(solid((0, 0, 0), disk_mask(0.485)))  # thin black border
    img.alpha_composite(solid((38, 40, 44), inside))         # flat dark grey

    # the glyph contour only: a ring along its edge
    mask = glyph_mask(glyph)
    stroke = ImageChops.subtract(grow(mask, 9), grow(mask, -9))
    stroke = stroke.filter(ImageFilter.GaussianBlur(2))

    # glow, kept inside the badge: long and soft
    glow = ImageChops.multiply(stroke.filter(ImageFilter.GaussianBlur(52)).point(lambda v: min(255, v * 1.1)), inside)
    img.alpha_composite(solid(neon, glow))
    # the inside of the glyph, filled with the neon color at half strength
    img.alpha_composite(solid(neon, mask.point(lambda v: v // 2)))
    img.alpha_composite(solid(neon, stroke))
    # hot core of the tube
    core = stroke.filter(ImageFilter.GaussianBlur(4)).point(lambda v: 255 if v > 200 else v // 3)
    img.alpha_composite(solid(shade(neon, 0.65), core))
    return img


STYLES = {
    "FantasyBright":     style_bright,
    "FantasyBlackWhite": style_black_white,
    "FantasyBrownMetal": style_brown_metal,
    "FantasyNoBG":       style_no_bg,
    "ScifiNeon":         style_scifi_neon,
}


def border_ring():
    """Gold ring with a transparent center, drawn over the circle-cut game icons."""
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.alpha_composite(solid((10, 6, 2), ring_mask(0.468, 0.07)))
    metal_ring(img, 0.462, 0.045, (250, 220, 140), (110, 72, 22))
    img.alpha_composite(solid((40, 26, 8), ring_mask(0.432, 0.012)))
    return img


# ---------------------------------------------------------------- output

def write_tga(img, path):
    w, h = img.size
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    rows = []
    px = img.load()
    for y in range(h - 1, -1, -1):  # bottom-left origin
        row = bytearray()
        for x in range(w):
            r, g, b, a = px[x, y]
            row += bytes((b, g, r, a))
        rows.append(bytes(row))
    with open(path, "wb") as f:
        f.write(header)
        f.write(b"".join(rows))


def final(img):
    return img.resize((OUT, OUT), Image.LANCZOS)


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "Icons")
    preview = sys.argv[2] if len(sys.argv) > 2 else None
    neon_palette(list(ICONS))
    sheets = []
    for style, render in STYLES.items():
        style_dir = os.path.join(out_dir, style)
        os.makedirs(style_dir, exist_ok=True)
        row = []
        for key, (glyph, color, metal) in ICONS.items():
            img = final(render(glyph, color, metal, key))
            write_tga(img, os.path.join(style_dir, key + ".tga"))
            row.append(img)
        sheets.append(row)
        print("wrote", style)
    write_tga(final(border_ring()), os.path.join(out_dir, "Border_Ring.tga"))

    if preview:
        cell = 52
        cols = 16
        rows = (len(ICONS) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * cell + 8, len(sheets) * rows * cell + len(sheets) * 12 + 8), (40, 40, 46, 255))
        y = 8
        for row in sheets:
            for i, img in enumerate(row):
                sheet.alpha_composite(img.resize((48, 48), Image.LANCZOS), (8 + (i % cols) * cell, y + (i // cols) * cell))
            y += rows * cell + 12
        sheet.save(preview)


if __name__ == "__main__":
    main()
