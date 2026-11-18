#!/usr/bin/env python3
"""Genera icono, icono adaptativo y splash en assets/brand/.
La llama se define con las mismas curvas que usa lib/core/widgets/brand_mark.dart.
Uso: python -X utf8 tools/gen_brand.py
"""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "brand")
os.makedirs(OUT, exist_ok=True)

# Paleta del escudo de los Bomberos Voluntarios de Cali: negro, rojo y amarillo.
GOLD = (255, 194, 14, 255)
RED = (200, 16, 46, 255)
ASH = (248, 246, 241, 255)
CHAR = (18, 18, 18, 255)
EMBER, AMBER, RUST = GOLD, GOLD, CHAR

# Curvas cubicas en un cuadro de 100x100: (inicio, c1, c2, fin)
FLAME = [
    ((50, 10), (62, 28), (82, 42), (82, 64)),
    ((82, 64), (82, 80), (68, 92), (50, 92)),
    ((50, 92), (32, 92), (18, 80), (18, 64)),
    ((18, 64), (18, 52), (26, 44), (32, 36)),
    ((32, 36), (34, 46), (40, 50), (44, 50)),
    ((44, 50), (42, 36), (44, 22), (50, 10)),
]
INNER = [
    ((50, 56), (58, 64), (66, 70), (66, 78)),
    ((66, 78), (66, 86), (58, 90), (50, 90)),
    ((50, 90), (42, 90), (34, 86), (34, 78)),
    ((34, 78), (34, 70), (44, 66), (50, 56)),
]

def bez(seg, n=24):
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = seg
    pts = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * t * (1 - t) ** 2, 3 * t * t * (1 - t), t ** 3
        pts.append((a * x0 + b * x1 + c * x2 + d * x3, a * y0 + b * y1 + c * y2 + d * y3))
    return pts

def poly(segs):
    pts = []
    for s in segs:
        pts += bez(s)
    return pts

def draw_flame(img, cx, cy, size, outer=GOLD, inner=RED):
    """Dibuja la llama centrada en (cx,cy) ocupando `size` px de alto."""
    k = size / 100.0
    ox, oy = cx - 50 * k, cy - 51 * k
    d = ImageDraw.Draw(img)
    d.polygon([(ox + x * k, oy + y * k) for x, y in poly(FLAME)], fill=outer)
    d.polygon([(ox + x * k, oy + y * k) for x, y in poly(INNER)], fill=inner)

def stripes(img, color, width, gap, angle_px):
    """Franjas diagonales tipo cinta reflectiva en la esquina inferior."""
    w, h = img.size
    d = ImageDraw.Draw(img)
    x = -h
    while x < w * 2:
        d.polygon([(x, h), (x + width, h), (x + width + angle_px, h - angle_px * 0 - h * 0.18),
                   (x + angle_px, h - h * 0.18)], fill=color)
        x += width + gap

S = 1024
# Icono legacy: fondo negro, franja inferior amarilla con rayas negras, llama
# amarilla con el centro rojo.
icon = Image.new("RGBA", (S, S), CHAR)
band = Image.new("RGBA", (S, S), (0, 0, 0, 0))
bd = ImageDraw.Draw(band)
bd.rectangle([0, int(S * 0.82), S, S], fill=GOLD)
stripes(band, CHAR, 70, 70, 120)
icon.alpha_composite(band)
draw_flame(icon, S / 2, S * 0.46, S * 0.62, GOLD, RED)
icon.save(os.path.join(OUT, "icon.png"))

# Adaptativo: solo la llama dentro de la zona segura (66%).
fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
draw_flame(fg, S / 2, S / 2, S * 0.5, GOLD, RED)
fg.save(os.path.join(OUT, "icon_foreground.png"))

def splash(name, bg, outer, inner, size=1152, flame=0.5):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_flame(im, size / 2, size / 2, size * flame, outer, inner)
    im.save(os.path.join(OUT, name))

# Fondo claro: llama roja con el centro amarillo. Fondo oscuro: al reves.
splash("splash.png", None, RED, GOLD, 768, 0.62)
splash("splash_dark.png", None, GOLD, RED, 768, 0.62)
splash("splash_android12.png", None, RED, GOLD, 1152, 0.42)
splash("splash_android12_dark.png", None, GOLD, RED, 1152, 0.42)
print("brand ok")
