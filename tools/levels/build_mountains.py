"""Подвесной перевал и Пепельные Пики (§8.13): от мельницы в Полях — по старому мосту к скале, дальше
разрушенная дорога над пропастью: пролёты обрушены, перейти можно только крюком на цепи (награда за Пугало;
пока крюк выдаёт F5). За перевалом — Пепельные Пики: чёрные хребты, пепел, кости дракона. Врагов пока нет.

Высоты: мост перевала — на 17 м выше поля (ноль комнаты — его настил), Пики — ещё на 6 м выше.
Кольца крюка повторяют проверенные на полигоне (build_hook.py) расстояния, только в другую сторону: герой идёт на запад.
Запуск из корня проекта: python tools/levels/build_mountains.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from scenery import v3  # noqa: E402
import backdrop as bd  # noqa: E402
from build_fields import G, D, O, PULL, SWING, WALL, back, land, new_room, ramp, save  # noqa: E402

PASS = {"bg": (0.03, 0.035, 0.05), "amb": (0.36, 0.4, 0.5), "amb_e": 0.42, "fog": (0.22, 0.24, 0.3), "fog_d": 0.016}
PEAKS = {"bg": (0.03, 0.028, 0.03), "amb": (0.4, 0.37, 0.36), "amb_e": 0.4, "fog": (0.2, 0.18, 0.18), "fog_d": 0.022}
SKY_PASS = ((0.05, 0.06, 0.09), (0.3, 0.33, 0.4))
SKY_PEAKS = ((0.04, 0.035, 0.04), (0.28, 0.22, 0.2))
## За хребтом Пиков тлеет зарево: там что-то до сих пор горит.
EMBER_GLOW = (0.6, 0.22, 0.08, 0.35)
PATH_COLD = (0.06, 0.07, 0.09)
PATH_ASH = (0.07, 0.06, 0.055)


def chain(s, name, top, bottom, z=-0.2):
    """Цепь от точки top вниз до кольца: звенья — маленькие коробки."""
    n = max(2, int((top[1] - bottom[1]) / 0.32))
    for i in range(n):
        f = (i + 0.5) / n
        x, y = top[0] + (bottom[0] - top[0]) * f, top[1] + (bottom[1] - top[1]) * f
        s.box(D, f"{name}{i}", (round(x, 3), round(y, 3), z), (0.08, 0.26, 0.08), "iron", rot=(0, (i % 2) * 1.57, 0))


def parapet(s, name, x0, x1, y=0.0, step=4.5):
    """Остатки парапета у края настила, перед героем: обломанные зубцы и верёвка между ними (передний план моста)."""
    x, i = x0 + 1.0, 0
    while x < x1 - 0.5:
        h = 0.55 + (i * 37 % 5) * 0.08
        s.box(D, f"{name}{i}", (round(x, 2), y + h / 2, 1.95), (0.7, h, 0.45), "stone", rot=(0, 0, round(((i * 13) % 5 - 2) * 0.04, 3)))
        x += step
        i += 1
    s.box(D, f"{name}Rope", ((x0 + x1) / 2, y + 0.45, 1.95), (x1 - x0 - 1.0, 0.05, 0.05), "rope")


# ---------------------------------------------------------------- Подвесной перевал
def pass_bridge():
    """Мост на перевал: целый первый пролёт от мельницы; дальше обрыв — кольцо «притянуть» на цепи между
    обломками башен; опора с руинами надвратной башни; второй обрыв — кольцо «качели» под уцелевшей аркой;
    последний пролёт упирается в скалу — кольцо на её кромке перебрасывает наверх, к Пепельным Пикам.
    Без крюка дальше первого обрыва не пройти: кольца видно, но они не светятся."""
    s = new_room("PassBridge", "pass_bridge", -42, 42, PASS, (0.6, 0.66, 0.8), 0.35)
    land(s, "SpanA", 18, 72, 0, -3, "stone")
    land(s, "PierB", -2, 9, 0, -3, "stone")
    land(s, "SpanC", -26, -16, 0, -3, "stone")
    land(s, "Crag", -74, -26, 6, -14, "stone_dark")
    # Опоры уходят в пропасть; обломки на краях пролётов.
    for i, (x, w) in enumerate(((30.0, 4.0), (3.5, 5.0), (-21.0, 4.0))):
        s.box(D, f"Pier{i}", (x, -21.0, 0), (w, 36.0, 3.6), "stone")
    for i, (x, side) in enumerate(((18.0, -1), (9.0, 1), (-2.0, -1), (-16.0, 1))):
        s.box(D, f"Broken{i}", (x + side * 0.6, -0.9, 0.6), (1.4, 1.2, 2.6), "stone", rot=(0, 0, side * 0.35))
    # Обрыв 1: кольцо «притянуть» на цепи между обломками башен.
    for i, (x, h) in enumerate(((19.0, 9.5), (8.0, 8.0))):
        s.box(D, f"Tower{i}", (x, h / 2, -1.8), (2.0, h, 1.6), "stone")
    s.box(D, "SpanChain", (13.5, 9.1, -1.0), (11.0, 0.1, 0.1), "iron", rot=(0, 0, -0.04))
    chain(s, "PullChain", (13.0, 8.9), (13.0, 6.0))
    s.hook_point("RingPull", (13.0, 5.6, 0.0), PULL)
    # Опора с надвратной башней; обрыв 2 — кольцо «качели» под уцелевшей аркой.
    s.box(D, "GateTowerL", (-1.0, 5.5, -2.8), (2.4, 11.0, 2.4), "stone")
    s.box(D, "GateTowerR", (7.5, 4.0, -2.8), (2.4, 8.0, 2.4), "stone")
    for i in range(7):
        a = math.pi * (i + 0.5) / 7
        s.box(D, f"Arch{i}", (round(-9.0 - math.cos(a) * 7.5, 3), round(10.5 + math.sin(a) * 3.0, 3), -1.4), (2.4, 0.9, 1.2), "stone",
              rot=(0, 0, round(-math.cos(a) * 0.6, 3)))
    chain(s, "SwingChain", (-9.0, 13.2), (-9.0, 6.8))
    s.hook_point("RingSwing", (-9.0, 6.4, 0.0), SWING)
    # Скала на западе: кольцо на кромке.
    s.hook_point("RingWall", (-25.7, 6.3, 0.0), WALL)
    s.box(D, "CragFace", (-50.0, 18.0, -6.0), (50.0, 24.0, 6.0), "stone_dark")
    s.hanging_cage(D, "Cage", 26.0, 3.6, -1.4)
    s.box(D, "CageChain", (26.0, 7.2, -1.4), (0.05, 3.6, 0.05), "iron")
    s.box(D, "CageBeam", (26.0, 9.0, -1.6), (3.0, 0.3, 0.3), "wood_dark")
    s.box(D, "CagePost", (27.4, 4.5, -1.6), (0.3, 9.0, 0.3), "wood_dark")
    s.lantern_post(D, "Lamp", 38.0, -1.4)
    # Передний план моста — обломки парапета и верёвки, а не земля: под мостом пропасть.
    parapet(s, "ParapetA", 18, 42)
    parapet(s, "ParapetB", -2, 9)
    parapet(s, "ParapetC", -26, -16)
    s.node("GapLine", 'type="Area3D"', O, [f"position = {v3((21.0, 0.0, 0.0))}", 'script = ExtResource("sayline")',
                                           'text = "«Пролёт обрушился. Над пропастью на цепи висит кольцо — рукой не достать.»"',
                                           "size = Vector3(4, 4, 4)"])
    back(s, "BackCrag", -74, -26, 6, depth=20.0, mat="stone_dark")
    k = bd.Kit(s)
    k.sky(-42, 42, *SKY_PASS)
    bd.pass_view(k, -42, 42, PASS["fog"])
    s.marker("FromMill", (39.0, 0.1, 0))
    s.marker("FromPeaks", (-39.0, 6.1, 0))
    s.door("DoorToMill", 40.5, 0, "mill", "Spawns/FromPass", "Назад, к мельнице")
    s.door("DoorToPeaks", -40.5, 6, "ash_peaks", "Spawns/FromPass", "В Пепельные Пики")
    for x0, x1, y in ((18, 42, 0), (-2, 9, 0), (-26, -16, 0), (-42, -26, 6)):
        k.path_light(x0, x1, y, PATH_COLD)
    save(s)


# ---------------------------------------------------------------- Пепельные Пики
def ash_peaks():
    """Первая комната Пиков: от перевала — по выжженному склону к обгорелой сторожевой башне (осколок у её подножия,
    с башни видно хребты), дальше над пропастью — по хребту дракона, рёбра аркой над головой; на западной террасе —
    драконий череп, из глазниц тянет теплом. Пепел в воздухе, снег наверху. Дальше Пики — позже, с врагами."""
    s = new_room("AshPeaks", "ash_peaks", -40, 40, PEAKS, (0.75, 0.6, 0.55), 0.3)
    land(s, "EastLedge", 24, 70, 0, -10, "stone_dark")
    land(s, "SlopeFill", 10, 24, 0, -10, "stone_dark")
    ramp(s, "Slope", 10, 4, 24, 0, "stone_dark", thick=2.0)
    land(s, "Plateau", -6, 10, 4, -10, "stone_dark")
    land(s, "WestTerrace", -74, -24, 4, -14, "stone_dark")
    # Сторожевая башня: каменный низ, обгорелый верх, площадка с лестницей.
    s.box(D, "TowerBase", (3.0, 6.0, -2.9), (4.4, 4.0, 3.2), "stone")
    for i, x in enumerate((1.2, 4.8)):
        s.box(D, f"TowerBeam{i}", (x, 9.2, -2.6), (0.4, 6.4, 0.4), "char", rot=(0, 0, (i - 0.5) * 0.1))
    s.box(G, "TowerTop", (3.0, 11.8, 0), (6.0, 0.4, 2.4), "char", True)
    s.box(D, "TowerRoofStub", (2.0, 13.6, -1.6), (3.0, 0.3, 2.2), "char", rot=(0, 0, 0.5))
    s.ladder("TowerLadder", 6.6, 4.0, 8.0, -1.0)
    s.ladder_look("Tower", 6.6, 4.0, 8.0, mat="char")
    s.note("WatchLog", 1.5, 12.0, "Журнал сторожа перевала", [
        "«Третью ночь небо над хребтом красное. Пепел ложится на снег, снег не тает».",
        "«Мост держали цепи. Цепи держат до сих пор — а камень нет».",
        "Последняя запись: «Оно не летает. Оно лежит. И дышит»."])
    s.shard("MirrorShard", -3.0, 4.0)
    # Хребет дракона над пропастью: позвонки — мост, рёбра — арка позади героя.
    x, i = -24.0, 0
    while x < -6.0:
        w = 1.8
        s.box(G, f"Vertebra{i}", (round(x + w / 2, 2), 3.5 - (i % 2) * 0.05, 0), (w + 0.05, 1.0 - (i % 2) * 0.1, 2.0), "bone", True)
        s.box(D, f"Spinous{i}", (round(x + w / 2, 2), 4.6, -1.3), (0.35, 1.6 + (i % 3) * 0.4, 0.3), "bone", rot=(0, 0, -0.25))
        x += w
        i += 1
    # Рёбра — арки по эллипсу над хребтом: звенья по касательной, к вершине тоньше.
    for r in range(6):
        cx, rx, ry = -21.5 + r * 3.0, 1.5, 5.2 - abs(r - 2.5) * 0.5
        for k_ in range(9):
            a = math.pi * (k_ + 0.5) / 9
            px, py = cx - math.cos(a) * rx, 3.8 + math.sin(a) * ry
            tangent = math.atan2(ry * math.cos(a), rx * math.sin(a))
            seg = math.hypot(rx * math.sin(a), ry * math.cos(a)) * math.pi / 9 + 0.35
            s.box(D, f"Rib{r}_{k_}", (round(px, 3), round(py, 3), -2.4), (0.3, round(seg, 3), 0.3), "bone",
                  rot=(0, 0, round(-tangent + math.pi / 2, 3)))
    # Драконий череп на западной террасе: челюсти раскрыты, в глазницах тлеет.
    sx = -33.0
    s.sphere(D, "Cranium", (sx, 9.0, -5.5), 4.2, "bone")
    s.box(D, "UpperJaw", (sx + 5.5, 7.4, -5.0), (7.0, 1.6, 4.0), "bone", rot=(0, 0, 0.12))
    s.box(D, "LowerJaw", (sx + 5.0, 4.8, -5.0), (6.6, 1.2, 3.6), "bone", rot=(0, 0, -0.18))
    for i in range(6):
        s.cyl(D, f"Tooth{i}", (sx + 3.4 + i * 1.0, 6.3, -3.4), 0.22, 1.0, "bone", rot=(math.pi, 0, 0), sides=6, cone=True)
    for i, dz in enumerate((-3.0, -3.1)):
        s.sphere(D, f"Socket{i}", (sx + 2.0 + i * 0.2, 10.0 - i * 0.1, dz + i * 0.05), 0.9 - i * 0.35, "char" if i == 0 else "ember")
    s.light(D, "SocketGlow", (sx + 2.2, 9.8, -2.0), (0.9, 0.35, 0.12), 0.9, 6.0)
    s.node("SkullLine", 'type="Area3D"', O, [f"position = {v3((-27.0, 4.0, 0.0))}", 'script = ExtResource("sayline")',
                                             'text = "«Череп. Из глазниц тянет теплом — внутри ещё что-то тлеет.»"', "size = Vector3(5, 4, 4)"])
    for i, (x, w) in enumerate(((-38.0, 4.0), (-29.0, 3.0), (-19.0, 2.4))):
        s.box(D, f"Snow{i}", (x, 4.02 if x < -24 else 4.0, -1.5), (w, 0.06, 1.6), "statue")
    for i, x in enumerate((30.0, 14.0)):
        s.dead_tree(D, f"BurntTree{i}", x, -3.2, 6.0, ground=0.0 if x > 24 else 4.0 - (x - 10) * 4 / 14, r=0.22, mat="char")
    for i, (x, y, w) in enumerate(((28.0, 0.0, 5.0), (0.0, 4.0, 6.0), (-40.0, 4.0, 8.0))):
        s.veil(D, f"Ash{i}", (x, y + 3.0, -1.6), (w * 2, 6.0), "fog_veil")
    back(s, "BackEast", 10, 70, 0, depth=10.0, mat="stone_dark")
    back(s, "BackPlateau", -6, 10, 4, depth=14.0, mat="stone_dark")
    back(s, "BackWest", -74, -24, 4, depth=18.0, mat="stone_dark")
    k = bd.Kit(s)
    k.sky(-40, 40, *SKY_PEAKS, glow=EMBER_GLOW, glow_x=0.2, glow_y=0.55, glow_size=0.18)
    bd.peaks(k, -40, 40, PEAKS["fog"], ground=4.0)
    s.marker("FromPass", (37.0, 0.1, 0))
    s.door("DoorToPass", 38.5, 0, "pass_bridge", "Spawns/FromPeaks", "Назад, на перевал")
    k.foreground("peaks", -40, 40, ground=lambda x: 0.0 if x > 24 else 4.0, skip=((-25, -5), (9, 25)))
    k.near_ground(24, 70, -0.25, pad=0)
    k.near_slope(10, 4, 24, 0)
    k.near_ground(-6, 10, 3.75, pad=0)
    k.near_ground(-74, -24, 3.75, pad=0)
    for x0, x1, y in ((24, 40, 0), (-6, 10, 4), (-40, -24, 4), (0, 6, 12)):
        k.path_light(x0, x1, y, PATH_ASH)
    save(s)


pass_bridge()
ash_peaks()
print("ok")
