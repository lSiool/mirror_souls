"""Рамки полос HP и выносливости из листа автора с прозрачностью (§8.12).

Источник — art/ui_source/hud_bars_v2.png: сверху рамка HP (лево / середина / право), снизу выносливость.
Куски нарисованы на своих местах по высоте, поэтому склеиваются без сдвига: срезаются только тонкие
замыкающие линии на стыках и уголок начала у середины HP, а на стыке куски плавно перетекают
друг в друга на BLEND пикселей. Выносливость — средний кусок целиком (он уже
с торцами); шипастые накладки слева и справа пока не нужны.
Пишет assets/ui/hud/painted/hp_frame_v2.png и stamina_frame_v2.png.
BarFrame (ui/bar_frame.gd) режет рамку по колонкам SEAMS и повторяет середину, чтобы рамка росла с
максимумом. Рельс по длине разного оттенка и местами на пиксель выше, поэтому около каждой колонки
реза рельс плавно сводится к общему профилю — медиане чистого рельса: любые два куска сходятся
одинаково, и шва не видно. SEAMS — те же числа, что head_to, plain_from, plain_to, tail_from
у BarFrame в hud.tscn; поменял одно — поменяй и другое.
Печатает внутренний проём каждой рамки и куски чистого рельса (без шипов): резы ставятся внутри них,
не ближе SEAM_BLEND к шипам.
Запуск из корня проекта: python tools/ui/cut_hud_bars.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

SOURCE = Path("art/ui_source/hud_bars_v2.png")
OUT = Path("assets/ui/hud/painted")

# Куски (x0, y0, x1, y1), x1 не включается. Стыки подобраны по альфе листа.
HP_TOP, HP_BOTTOM = 72, 182
HP_LEFT = (69, 319)       # до замыкающей линии на x 319–322
HP_MIDDLE = (372, 1061)   # после уголка-шеврона начала (x 345–370)
HP_RIGHT = (1078, 1292)   # после линии на x 1075–1077
STAMINA = (340, 210, 1057, 268)
BLEND = 8  # ширина плавного перехода на стыке: рельсы кусков чуть разные по толщине и цвету
# Колонки резов BarFrame: (head_to, plain_from, plain_to, tail_from) — как в hud.tscn.
SEAMS = {"hp_frame_v2": (270, 280, 330, 765), "stamina_frame_v2": (290, 415, 485, 490)}
SEAM_BLEND = 14  # на сколько колонок по обе стороны реза рельс сводится к общему профилю
# Склейка кусков листа, где рельсы разной толщины (у торца HP толще и светлее): тоже к профилю,
# хоть детектор и не считает эти колонки чистым рельсом. Шипов в окне SEAM_BLEND вокруг нет.
GLUES = {"hp_frame_v2": (246,), "stamina_frame_v2": ()}


def inner(alpha, row):
    """Проём рамки по строке row: первый и последний прозрачный пиксель между металлом."""
    solid = alpha[row] > 128
    xs = np.nonzero(solid)[0]
    gaps = np.nonzero(~solid[xs[0]:xs[-1]])[0] + xs[0]
    return int(gaps[0]), int(gaps[-1])


def inner_rows(alpha, col):
    solid = alpha[:, col] > 128
    ys = np.nonzero(solid)[0]
    gaps = np.nonzero(~solid[ys[0]:ys[-1]])[0] + ys[0]
    return int(gaps[0]), int(gaps[-1])


def plain_runs(alpha):
    """Колонки чистого рельса: металл только в полосах рельсов, обе полосы целые. Здесь раму можно
    резать и повторять без шва (BarFrame)."""
    solid = alpha > 100
    h, w = solid.shape
    rows = np.nonzero(solid[:, w // 3: 2 * w // 3].mean(axis=1) > 0.85)[0]
    bands = [(g[0], g[-1]) for g in np.split(rows, np.where(np.diff(rows) != 1)[0] + 1)]
    allowed = np.zeros(h, bool)
    for b0, b1 in bands:
        allowed[max(b0 - 1, 0):b1 + 2] = True
    plain = [not solid[~allowed, x].any() and all(solid[b0:b1 + 1, x].all() for b0, b1 in bands) for x in range(w)]
    xs = np.nonzero(plain)[0]
    runs = np.split(xs, np.where(np.diff(xs) != 1)[0] + 1)
    return [(int(r[0]), int(r[-1])) for r in runs if len(r) >= 20]


def report(name, img):
    alpha = img[..., 3]
    col = img.shape[1] // 2
    y0, y1 = inner_rows(alpha, col)
    x0, x1 = inner(alpha, (y0 + y1) // 2)
    print(f"{name}: {img.shape[1]}x{img.shape[0]}, проём x {x0}..{x1}, y {y0}..{y1}, чистый рельс {plain_runs(alpha)}")


def join(a, b):
    """Склейка с перекрытием BLEND: конец a плавно переходит в начало b."""
    t = np.linspace(0.0, 1.0, BLEND)[None, :, None]

    def premul(x):  # прозрачные пиксели листа белые — смешиваем цвет с учётом альфы, иначе светлая кайма
        x = x.astype(np.float32)
        return np.concatenate([x[..., :3] * x[..., 3:] / 255.0, x[..., 3:]], axis=2)

    mix = premul(a[:, -BLEND:]) * (1 - t) + premul(b[:, :BLEND]) * t
    alpha = mix[..., 3:]
    rgb = np.where(alpha > 0, mix[..., :3] * 255.0 / np.maximum(alpha, 1e-3), 0.0)
    mix = np.concatenate([rgb, alpha], axis=2).clip(0, 255).round().astype(np.uint8)
    return np.concatenate([a[:, :-BLEND], mix, b[:, BLEND:]], axis=1)


def premul(x):
    x = x.astype(np.float32)
    return np.concatenate([x[..., :3] * x[..., 3:] / 255.0, x[..., 3:]], axis=2)


def unpremul(x):
    alpha = x[..., 3:]
    rgb = np.where(alpha > 0, x[..., :3] * 255.0 / np.maximum(alpha, 1e-3), 0.0)
    return np.concatenate([rgb, alpha], axis=2).clip(0, 255).round().astype(np.uint8)


def smooth_seams(img, seams, glues=()):
    """Около колонок реза рельс плавно переходит в общий профиль (медиана чистого рельса по строкам).
    Сводим только колонки чистого рельса: шипы рядом не трогаются. У склеек glues — все колонки окна."""
    runs = plain_runs(img[..., 3])
    plain = np.zeros(img.shape[1], bool)
    for a, b in runs:
        plain[a:b + 1] = True
    pm = premul(img)
    profile = np.median(pm[:, plain], axis=1)
    def window(c):
        weight = np.zeros(img.shape[1], np.float32)
        for x in range(max(c - SEAM_BLEND, 0), min(c + SEAM_BLEND, img.shape[1])):
            # Колонки c-1 и c (по обе стороны реза) — профиль целиком, дальше плавный спад.
            d = abs(x + 0.5 - c) - 1.0
            t = 1.0 if d <= 0.0 else max(0.0, 1.0 - d / (SEAM_BLEND - 1.0))
            weight[x] = t * t * (3.0 - 2.0 * t)
        return weight

    weight = np.zeros(img.shape[1], np.float32)
    for c in seams:
        weight = np.maximum(weight, window(c))
    weight[~plain] = 0.0
    for c in glues:
        weight = np.maximum(weight, window(c))
    w = weight[None, :, None]
    return unpremul(pm * (1.0 - w) + profile[:, None, :] * w)


def main():
    sheet = np.asarray(Image.open(SOURCE).convert("RGBA"))
    parts = [sheet[HP_TOP:HP_BOTTOM, x0:x1] for x0, x1 in (HP_LEFT, HP_MIDDLE, HP_RIGHT)]
    hp = join(join(parts[0], parts[1]), parts[2])
    sx0, sy0, sx1, sy1 = STAMINA
    stamina = sheet[sy0:sy1, sx0:sx1]
    OUT.mkdir(parents=True, exist_ok=True)
    report("hp_frame_v2", hp)
    report("stamina_frame_v2", stamina)
    hp = smooth_seams(hp, SEAMS["hp_frame_v2"], GLUES["hp_frame_v2"])
    stamina = smooth_seams(stamina, SEAMS["stamina_frame_v2"], GLUES["stamina_frame_v2"])
    Image.fromarray(hp).save(OUT / "hp_frame_v2.png")
    Image.fromarray(stamina).save(OUT / "stamina_frame_v2.png")


if __name__ == "__main__":
    main()
