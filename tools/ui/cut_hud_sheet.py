"""Нарезка нарисованного листа HUD (§8.12) на текстуры для Godot.

Источник — art/ui_source/hud_sheet_v1.jpg (лист автора: части на сером фоне, подписи рядом).
Скрипт убирает серый фон и нарисованную шахматку и кладёт PNG с прозрачностью в assets/ui/hud/painted/:
заливки и жёлоб полос, медальон, флакон, кружок числа, рамку баффа, треугольники. Рамки полос HP и
выносливости теперь режет tools/ui/cut_hud_bars.py из листа с прозрачностью.
Координаты — под этот лист; новый лист другой раскладки — поправить BOXES.
Запуск из корня проекта: python tools/ui/cut_hud_sheet.py
"""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

SOURCE = Path("art/ui_source/hud_sheet_v1.jpg")
OUT = Path("assets/ui/hud/painted")
BG = np.array([53, 53, 52])
BG_TOL = 5

# Части листа: (x0, y0, x1, y1).
BOXES = {
    "hp_fill": (205, 290, 655, 318),
    "groove": (690, 290, 1165, 318),
    "st_fill": (215, 354, 1040, 380),
    "medallion": (122, 424, 386, 697),
    "flask": (432, 495, 533, 642),
    "badge": (598, 516, 728, 642),
    "buff_frame": (824, 543, 922, 642),
    "tri_up_green": (1183, 553, 1225, 586),
    "tri_down_red": (1240, 598, 1282, 632),
}


def load():
    return np.asarray(Image.open(SOURCE).convert("RGB")).astype(np.int16)


def bg_distance(rgb):
    return np.abs(rgb - BG).max(axis=2)


def flood(passable, seeds):
    """Заливка от точек по разрешённым пикселям; возвращает маску залитого."""
    h, w = passable.shape
    seen = np.zeros_like(passable, dtype=bool)
    queue = deque()
    for y, x in seeds:
        if 0 <= y < h and 0 <= x < w and passable[y, x] and not seen[y, x]:
            seen[y, x] = True
            queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and passable[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                queue.append((ny, nx))
    return seen


def border_seeds(h, w, step=3):
    seeds = []
    for x in range(0, w, step):
        seeds += [(0, x), (h - 1, x)]
    for y in range(0, h, step):
        seeds += [(y, 0), (y, w - 1)]
    return seeds


def cut(rgb, extra_holes=None):
    """RGBA: серый фон, связанный с краем, — прозрачный; кромка мягкая.
    extra_holes — маска того, что ещё убрать (внутренность рамки, шахматка)."""
    d = bg_distance(rgb)
    h, w = d.shape
    hole = flood(d <= BG_TOL, border_seeds(h, w))
    if extra_holes is not None:
        hole |= extra_holes
    alpha = np.where(hole, 0.0, 1.0)
    # Мягкая кромка: пиксели рядом с дырой, близкие к фону, — полупрозрачные.
    near = np.zeros_like(hole)
    near[1:] |= hole[:-1]; near[:-1] |= hole[1:]; near[:, 1:] |= hole[:, :-1]; near[:, :-1] |= hole[:, 1:]
    soft = near & ~hole
    alpha[soft] = np.clip((d[soft] - BG_TOL) / 18.0, 0.25, 1.0)
    out = np.dstack([rgb.clip(0, 255), (alpha * 255).astype(np.int16)]).astype(np.uint8)
    return out


def crop(img, box):
    x0, y0, x1, y1 = box
    return img[y0:y1, x0:x1]


def save(name, arr):
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr).save(OUT / f"{name}.png")


def main():
    sheet = load()
    parts = {name: crop(sheet, box) for name, box in BOXES.items()}

    for name in ("hp_fill", "groove", "st_fill"):
        part = parts[name]
        save(name, np.dstack([part.clip(0, 255), np.full(part.shape[:2], 255, np.int16)]).astype(np.uint8))

    # Медальон: середина — нарисованная шахматка; убираем светлое внутри кольца и подпись сверху справа.
    med = parts["medallion"]
    h, w = med.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    cy, cx = 563 - BOXES["medallion"][1], 255 - BOXES["medallion"][0]
    rr = np.hypot(yy - cy, xx - cx)
    light = (med.min(axis=2) > 150) & ((med.max(axis=2) - med.min(axis=2)) < 22)
    checker = (rr < 74) | ((rr < 90) & light)
    # Подпись «МЕДАЛЬОН И ЗЕЛЬЕ» заходит в угол выреза справа сверху.
    label = (yy < 34) & (xx > 165)
    save("medallion", cut(med, checker | label))

    save("flask", cut(parts["flask"]))
    for name in ("badge", "buff_frame"):
        part = parts[name]
        ph, pw = part.shape[:2]
        inside = flood(bg_distance(part) <= BG_TOL + 6, [(ph // 2, pw // 2)])
        save(name, cut(part, inside))
    for name in ("tri_up_green", "tri_down_red"):
        save(name, cut(parts[name]))
    print("painted:", sorted(p.name for p in OUT.glob("*.png")))


if __name__ == "__main__":
    main()
