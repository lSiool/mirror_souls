"""Ромб ячейки расходника для крестовины HUD (§8.12) — заглушка из референса автора.

Источник — art/ui_source/quick_cross_v1.png: крестовина из четырёх ромбов на сером фоне, в двух ромбах
нарисованы предметы. Берём пустой правый ромб: внутри ромба (по манхэттенскому радиусу) всё остаётся,
на кромке, где торчат шипы, серый фон убирается по яркости. В HUD четыре ячейки собираются из этого
одного ромба. Чистый лист автора (PNG с прозрачностью, крупнее) заменит заглушку с тем же именем.
Пишет assets/ui/hud/painted/quick_cell.png.
Запуск из корня проекта: python tools/ui/cut_quick_cross.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

SOURCE = Path("art/ui_source/quick_cross_v1.png")
OUT = Path("assets/ui/hud/painted/quick_cell.png")
CENTER = (231, 136)  # (x, y) пустого правого ромба
SOLID = 57           # до этого радиуса — рамка и тёмная середина целиком
EDGE = 62            # дальше — уже соседние ромбы и фон
BG_TOL = 14          # насколько пиксель шипа должен отличаться от фона
SCALE = 2            # заглушку увеличиваем: в HUD она крупнее листа


def main():
    rgb = np.asarray(Image.open(SOURCE).convert("RGB")).astype(np.int16)
    cx, cy = CENTER
    half = EDGE + 1
    part = rgb[cy - half:cy + half + 1, cx - half:cx + half + 1]
    size = part.shape[0]
    yy, xx = np.mgrid[0:size, 0:size]
    radius = np.abs(xx - half) + np.abs(yy - half)
    # Фон у ромба: медиана кольца за кромкой (серый с лёгкой текстурой).
    ring = (radius > EDGE - 3) & (radius <= EDGE)
    lum = part.mean(axis=2)
    bg = np.median(lum[ring])
    spread = part.max(axis=2) - part.min(axis=2)
    thorn = (np.abs(lum - bg) > BG_TOL) | (spread > 12)
    alpha = np.where(radius <= SOLID, 1.0, np.where((radius <= EDGE) & thorn, 1.0, 0.0))
    # Мягкий спад к самой кромке.
    fade = (radius > EDGE - 3) & (alpha > 0)
    alpha[fade] = 0.6
    out = np.dstack([part.clip(0, 255), (alpha * 255).astype(np.int16)]).astype(np.uint8)
    image = Image.fromarray(out, "RGBA").resize((size * SCALE, size * SCALE), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print("quick cell:", OUT, image.size)


if __name__ == "__main__":
    main()
