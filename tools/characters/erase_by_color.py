#!/usr/bin/env python3
"""Стереть предмет с концепта на ровном фоне — например, оружие из руки перед TRELLIS (модель без оружия,
оружие — отдельной моделью в руке, правило «оружие всегда в руке»).

Запуск:
    python -I tools/characters/erase_by_color.py <вход.png> <выход.png> <x0,y0,x1,y1> [--protect=x0,y0,x1,y1] [--keep-skin] [--tol=18]

В прямоугольнике всё, что заметно отличается от фона (цвет фона — по углам картинки), заливается фоном.
--protect — прямоугольник, который не трогается совсем (кулак на рукояти); --keep-skin бережёт светлую
розоватую кожу (затенённые пальцы правило не ловит — для кисти надёжнее --protect). Край маски
расширяется на 2 пикселя, чтобы не оставалось ореола. Пример — Полудница без серпа:
    ... poludnitsa_front_v01.png poludnitsa_nosickle.png 0,575,272,830 --protect=134,545,194,650 --tol=14
"""

import sys

import numpy as np
from PIL import Image, ImageFilter


def main():
    src, dst, box = sys.argv[1], sys.argv[2], [int(v) for v in sys.argv[3].split(",")]
    opts = dict(a[2:].split("=", 1) if "=" in a else (a[2:], "1") for a in sys.argv[4:] if a.startswith("--"))
    tol = float(opts.get("tol", 18))
    img = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    h, w, _ = img.shape
    corners = np.array([img[2, 2], img[2, w - 3], img[h - 3, 2], img[h - 3, w - 3]])
    bg = corners.mean(axis=0)
    x0, y0, x1, y1 = box
    region = np.zeros((h, w), bool)
    region[y0:y1, x0:x1] = True
    if "protect" in opts:
        px0, py0, px1, py1 = (int(v) for v in opts["protect"].split(","))
        region[py0:py1, px0:px1] = False
    diff = np.abs(img - bg).max(axis=2)
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    skin = np.zeros((h, w), bool)
    if "keep-skin" in opts:
        skin = (lum > 115) & (r > g) & (g >= b - 6) & (r - b > 12) & (r - b < 90)
    mask = region & (diff > tol) & ~skin
    grown = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
    mask = region & (mask | (grown & ~skin))
    out = img.copy()
    rng = np.random.default_rng(0)
    out[mask] = bg + rng.normal(0, 0.8, (mask.sum(), 3))
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(dst)
    print(f"фон {bg.round(1)}, стёрто {mask.sum()} пикс.")


if __name__ == "__main__":
    main()
