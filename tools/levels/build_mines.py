"""Железные копи (§8.13): за мёртвой деревней Кузнеца — рудный двор с копром, шахты, затопленный штрек,
глубокая выработка, где пол провалился в жар (дальше — Пекло, следующий шаг). Врагов пока нет.

Вход — дверь на восточном краю мёртвой деревни, открыта после победы над Кузнецом. Спуск с двора — подъёмником
(Lift: встал на площадку — поехала; на остановках рычаги вызова). Ниже — лестницы, наклонный рельсовый спуск.
Черновик истории: железо копали для кузни, и чем глубже — тем лучше руда; на самой глубине руда пошла тёплая,
а под забоем открылась пустота. Оттуда проклятие и поднялось.

Высоты: ноль двора — земля мёртвой деревни; галерея под копром — на 12 м ниже (ноль шахт), штрек и выработка —
ещё на 9 м ниже (их ноль). Каждая комната в своём нуле: ниже глобального y = −15 герой гибнет (Player.KILL_Y),
настоящая глубина — на карте (WorldMap.ROOMS).
Запуск из корня проекта: python tools/levels/build_mines.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from scenery import Scene, v3  # noqa: E402
import backdrop as bd  # noqa: E402
import build_graveyard as bg  # noqa: E402

G, D, O = "Geometry", "Decor", "Objects"
PULL = 0

## Двор — пепельные сумерки мёртвой деревни; под землёй — полутьма: светят фонари забойщиков и свечи.
YARD = {"bg": (0.03, 0.03, 0.035), "amb": (0.32, 0.31, 0.34), "amb_e": 0.34, "fog": (0.15, 0.15, 0.17), "fog_d": 0.026}
SKY_YARD = ((0.025, 0.025, 0.03), (0.19, 0.18, 0.19))
MINE = {"bg": (0.0, 0.0, 0.0), "amb": (0.38, 0.35, 0.32), "amb_e": 0.34, "fog": (0.03, 0.026, 0.022), "fog_d": 0.02}
DEEP = {"bg": (0.0, 0.0, 0.0), "amb": (0.46, 0.3, 0.24), "amb_e": 0.3, "fog": (0.06, 0.025, 0.015), "fog_d": 0.022}
LAMP = (1.0, 0.6, 0.28)
HEAT = (1.0, 0.32, 0.1)
PATH_ASH = (0.06, 0.06, 0.07)
PATH_MINE = (0.06, 0.05, 0.04)


def save(scene):
    Path(f"world/rooms/{scene.room_id}.tscn").write_text(scene.text(), encoding="utf-8")


def new_room(name, room_id, left, right, env, sun_energy=0.0):
    s = Scene(name, room_id, right - left, env, (0.55, 0.52, 0.5), sun_energy)
    s.use("candle", "Script", "res://world/common/wall_candle.gd")
    s.use("sayline", "Script", "res://world/common/say_line.gd")
    s.use("lift", "Script", "res://world/common/lift.gd")
    s.use("spinner", "Script", "res://world/common/spinner.gd")
    s.wall("WallLeft", (left - 0.5, 4.0, 0), (1, 40, 4.4))
    s.wall("WallRight", (right + 0.5, 4.0, 0), (1, 40, 4.4))
    return s


# ---------------------------------------------------------------- помощники
def land(s, name, x0, x1, top, bottom, mat="stone_dark"):
    s.box(G, name, ((x0 + x1) / 2, (top + bottom) / 2, 0), (x1 - x0, top - bottom, 4.4), mat, True)


def ramp(s, name, x0, y0, x1, y1, mat="stone_dark", thick=1.6):
    """Склон в плоскости героя: верх от (x0, y0) к (x1, y1), x0 < x1."""
    a = math.atan2(y1 - y0, x1 - x0)
    ln = math.hypot(x1 - x0, y1 - y0) + 0.1
    cx, cy = (x0 + x1) / 2 + math.sin(a) * thick / 2, (y0 + y1) / 2 - math.cos(a) * thick / 2
    s.box(G, name, (cx, cy, 0), (ln, thick, 4.4), mat, True, rot=(0, 0, round(a, 4)))
    return a


def rails(s, name, x0, y0, x1, y1, z=-1.0):
    """Рельсы вагонеток по полу или по уклону."""
    a = math.atan2(y1 - y0, x1 - x0)
    ln = math.hypot(x1 - x0, y1 - y0)
    for i, dz in enumerate((-0.35, 0.35)):
        s.box(D, f"{name}Rail{i}", ((x0 + x1) / 2, (y0 + y1) / 2 + 0.06, z + dz), (ln, 0.08, 0.08), "iron", rot=(0, 0, round(a, 4)))
    n = int(ln / 1.2)
    for i in range(n):
        f = (i + 0.5) / n
        s.box(D, f"{name}Tie{i}", (round(x0 + (x1 - x0) * f, 3), round(y0 + (y1 - y0) * f + 0.02, 3), z), (0.22, 0.06, 1.1), "wood_dark",
              rot=(0, 0, round(a, 4)))


def cart(s, name, x, y, z=-1.0, tilt=0.0, ore=True, collide=False, parent=None):
    """Вагонетка: короб на колёсах, в коробе руда."""
    parent = parent or (G if collide else D)
    s.box(parent, f"{name}Box", (x, y + 0.7, z), (1.6, 0.9, 1.1), "rust", collide, rot=(0, 0, tilt) if tilt else None)
    for i, dx in enumerate((-0.5, 0.5)):
        s.cyl(D, f"{name}Wheel{i}", (x + dx, y + 0.2, z + 0.58), 0.2, 0.08, "iron", rot=(math.pi / 2, 0, 0), sides=8)
    if ore:
        s.sphere(D, f"{name}Ore", (x, y + 1.15, z), 0.55, "stone_dark")


def timber_set(s, name, x, y, h=4.2, z=-1.9):
    """Крепь штрека: две стойки и верхняк."""
    for i, dx in enumerate((-1.2, 1.2)):
        s.box(D, f"{name}Post{i}", (x + dx, y + h / 2, z), (0.28, h, 0.28), "wood_dark", rot=(0, 0, dx * -0.02))
    s.box(D, f"{name}Cap", (x, y + h, z), (3.0, 0.3, 0.32), "wood_dark")


def hanging_lamp(s, name, x, y, z=-0.8, energy=2.0, rng=9.5, lit=True):
    """Фонарь забойщика на крюке: горит — тёплый свет; погас — тёмное стекло."""
    s.box(D, f"{name}Hook", (x, y + 0.5, z), (0.04, 0.6, 0.04), "iron")
    s.box(D, f"{name}Lamp", (x, y, z), (0.26, 0.38, 0.26), "lantern" if lit else "char")
    if lit:
        s.light(D, f"{name}Light", (x, y - 0.3, z + 1.0), LAMP, energy, rng)


def rock_back(s, name, x0, x1, y0, y1, z=-2.4, veins=0):
    """Стена выработки позади героя; veins — сколько рудных жил (ржавые полосы)."""
    s.box(D, name, ((x0 + x1) / 2, (y0 + y1) / 2, z), (x1 - x0, y1 - y0, 0.4), "stone_dark")
    for i in range(veins):
        f = (i * 0.618) % 1.0
        x = x0 + 2.0 + (x1 - x0 - 4.0) * f
        y = y0 + 1.0 + ((i * 37) % 7) / 7.0 * max(0.5, y1 - y0 - 2.0)
        s.box(D, f"{name}Vein{i}", (round(x, 2), round(y, 2), z + 0.22), (2.6, 0.18, 0.05), "rust", rot=(0, 0, round(((i * 13) % 7 - 3) * 0.12, 3)))


def mines_surface(k, left, right, fog, ground=0.0):
    """Рудный двор: позади мёртвая деревня и лес, отвалы пустой породы, копры соседних шахт на холмах."""
    k.far_ground(left, right, ground)
    k.firs(left - bd.FAR_PAD, right + bd.FAR_PAD, -44, -56, 12, 22, step=(2.2, 4.0), base=ground)
    k.hills(left - 30, right + 40, -28, ground - 1, 3, 6, mat="earth")
    for i, x in enumerate((left - 18.0, left + 22.0, right + 16.0)):
        h = 14.0 + i * 3.0
        for side in (-1, 1):
            k.put("Backdrop", "Headframe", "box", "sil", (x + side * h * 0.16, ground + h / 2, -34.0 - i * 3), (0.5, h, 0.5), tilt=side * 0.16)
        k.put("Backdrop", "HeadWheel", "ball", "sil", (x, ground + h, -34.0 - i * 3), (2.4, 2.4, 0.3))
    x = left - 30.0
    while x < right + 30.0:
        h = k.rng.uniform(3.0, 7.0)
        k.put("Backdrop", "SlagHeap", "cone", "earth", (x, ground + h / 2 - 0.5, k.rng.uniform(-14.0, -22.0)), (h * 2.6, h, h * 1.6))
        x += k.rng.uniform(10.0, 18.0)
    k.haze(left, right, ground + 2.5, -13, 7, fog, 0.3)
    k.haze(left, right, ground + 4, -27, 14, fog, 0.45)
    k.haze(left, right, ground + 8, -40, 24, fog, 0.55)


# ---------------------------------------------------------------- 1. Рудный двор
def mine_yard():
    """Двор над главной шахтой: отвалы, вагонетки на рельсах, барак забойщиков, остывшая плавильня, где Кузнец
    брал железо. Шахта — у подножия скалы, над ней копёр; подъёмник везёт на 12 м вниз, в галерею под скалой."""
    s = new_room("MineYard", "mine_yard", -28, 28, YARD, sun_energy=0.2)
    land(s, "Yard", -58, 12, 0, -14, "mud")
    land(s, "Cliff", 16, 58, 9, -6)
    land(s, "GalleryFloor", 12, 58, -12, -14)
    # Подъёмник в шахте 12…16: наверху рычаг на дворе, внизу — в галерее.
    s.node("Lift", 'type="Node3D"', O, [f"position = {v3((14.0, -12.0, 0.0))}", 'script = ExtResource("lift")', "travel = 12.0",
                                        "start_top = true", "size = Vector3(3.6, 0.4, 2.4)", "call_top_x = -3.4", "call_bottom_x = 3.4"])
    bg.say(s, "ShaftLine", 10.5, 0.0, "«Шахта. Из глубины тянет теплом — в копях так не бывает.»", size=(3, 3, 4))
    # Копёр над шахтой: ноги-укосины, площадка, колесо.
    for i, (x, t) in enumerate(((12.4, 0.12), (16.4, -0.12))):
        s.box(D, f"HeadframeLeg{i}", (x, 7.0, -2.0), (0.4, 14.0, 0.4), "wood_dark", rot=(0, 0, t))
    s.box(D, "HeadframeBrace", (14.4, 7.0, -2.0), (4.4, 0.25, 0.25), "wood_dark")
    s.box(D, "HeadframeTop", (14.4, 13.8, -2.0), (5.0, 0.4, 0.8), "wood_dark")
    s.cyl(D, "HeadWheel", (14.4, 15.0, -2.0), 1.6, 0.25, "wood_dark", rot=(math.pi / 2, 0, 0), sides=14)
    s.box(D, "ShaftCollar", (14.0, 0.1, -1.9), (5.0, 0.3, 0.6), "wood_dark")
    rock_back(s, "GalleryBack", 12, 28, -12, -6, veins=3)
    hanging_lamp(s, "GalleryLamp", 22.0, -8.0)
    s.box(D, "GalleryMouth", (28.0, -9.0, -2.2), (2.2, 3.6, 0.1), "char")
    # Двор: рельсы, вагонетки, отвалы, барак, плавильня.
    rails(s, "YardRails", -24.0, 0.0, 11.0, 0.0, z=-1.4)
    cart(s, "Cart0", -6.0, 0.0, z=0.0, collide=True)
    cart(s, "Cart1", 5.0, 0.0, z=-1.4)
    cart(s, "Cart2", -17.0, 0.0, z=-1.4, ore=False, tilt=0.25)
    for i, (x, h, z) in enumerate(((-21.0, 3.0, -4.5), (-9.5, 4.2, -5.5), (2.0, 2.6, -4.0))):
        s.cyl(D, f"Slag{i}", (x, h / 2 - 0.2, z), h * 1.1, h, "earth_dark", sides=9, cone=True)
    s.box(D, "BarrackWall", (-14.0, 1.8, -6.5), (8.0, 3.6, 3.0), "wood_dark")
    s.roof(D, "BarrackRoof", (-14.0, 4.6, -6.5), (9.0, 2.2, 3.6), "thatch")
    s.box(D, "BarrackWindow", (-12.0, 2.2, -4.96), (0.8, 0.8, 0.06), "char")
    s.box(D, "Smelter", (-2.5, 2.0, -3.4), (2.6, 4.0, 2.4), "stone")
    s.box(D, "SmelterMouth", (-2.5, 0.8, -2.18), (1.0, 0.9, 0.06), "char")
    s.cyl(D, "SmelterStack", (-2.5, 5.5, -3.4), 0.5, 3.0, "stone_dark", sides=8)
    s.box(D, "Pickaxe", (8.0, 0.5, -0.9), (0.06, 1.1, 0.06), "wood", rot=(0, 0, 0.6))
    s.box(D, "PickHead", (7.7, 0.95, -0.9), (0.7, 0.08, 0.06), "iron", rot=(0, 0, 0.6))
    s.lantern_post(D, "YardLamp", -10.0, -1.2, side=1)
    s.note("ForemanBoard", -20.0, 0.0, "Доска десятника", [
        "«Кузнецу — железо. Глубже — лучше железо».",
        "«На сороковой сажени руда пошла тёплая. Брать».",
        "Ниже углём: «Под забоем пусто. Кто-то там кашляет. Смену не спускать»."])
    k = bd.Kit(s)
    k.sky(-28, 28, *SKY_YARD)
    mines_surface(k, -28, 28, YARD["fog"])
    s.marker("FromVillage", (-25.0, 0.1, 0))
    s.marker("FromShafts", (25.0, -11.9, 0))
    s.door("DoorToVillage", -26.5, 0, "cursed_village", "Spawns/FromMines", "Назад, в мёртвую деревню")
    s.door("DoorToShafts", 26.5, -12, "mine_shafts", "Spawns/FromYard", "Вглубь, в шахты")
    k.foreground("dead", -28, 12)
    k.near_ground(-58, 12, -0.25, pad=0)
    k.path_light(-28, 12, 0.0, PATH_ASH)
    k.path_light(12, 28, -12.0, PATH_MINE)
    save(s)


# ---------------------------------------------------------------- 2. Шахты
def mine_shafts():
    """Очистная выработка под землёй: с галереи — по наклонному рельсовому спуску к полке с осколком,
    по лестнице — на нижний горизонт и к штреку. Над спуском — рудоспуск на лесах с сундуком:
    до него через пропасть выработки — только крюком (кольцо на балке)."""
    s = new_room("MineShafts", "mine_shafts", -26, 26, MINE)
    land(s, "Gallery", -56, -12, 0, -14)
    a = ramp(s, "Incline", -12, 0, 0, -4.5, thick=5.0)
    land(s, "Ledge", -1, 10, -4.5, -14)
    land(s, "Lower", 10, 56, -9, -14)
    land(s, "Ceiling", -56, 56, 14, 12)
    s.ladder("LowerLadder", 10.6, -9.0, 4.5, -1.0)
    s.ladder_look("Lower", 10.6, -9.0, 4.5)
    # Наверху: уступ на западе (лестница с галереи), рудоспуск на лесах за пропастью — сундук; кольцо «притянуть».
    land(s, "HighLedge", -56, -18, 5, 4)
    s.ladder("HighLadder", -17.4, 0.0, 5.0, -1.0)
    s.ladder_look("High", -17.4, 0.0, 5.0)
    bg.platform(s, "Chute", -9, -2, 5.0)
    s.hook_point("RingPull", (-13.0, 10.6, 0.0), PULL)
    s.box(D, "RingBeam", (-13.0, 11.6, -0.6), (12.0, 0.35, 0.35), "wood_dark")
    s.box(D, "ChuteBox", (-5.5, 7.6, -1.3), (3.0, 4.6, 1.8), "wood_dark")
    s.chest("ChuteChest", (-4.0, 5.0, -0.6), 160, "mine_chute_chest", ("tempered_glass", "throwing_axe", "throwing_axe"))
    # Рельсы и вагонетки на уклоне, крепь, фонари.
    rails(s, "InclineRails", -12.0, 0.0, 0.0, -4.5)
    cart(s, "InclineCart", -14.0, 0.0)
    cart(s, "LowerCart", 18.0, -9.0, ore=False)
    rails(s, "LowerRails", 10.0, -9.0, 26.0, -9.0)
    for i, x in enumerate((-22.0, -8.0, 4.0, 15.0, 22.0)):
        timber_set(s, f"Set{i}", x, -9.0 if x > 10 else (-4.5 if x > -1 else 0.0))
    rock_back(s, "Back", -26, 26, -9, 12, veins=8)
    hanging_lamp(s, "LampGallery", -20.0, 3.2)
    hanging_lamp(s, "LampLedge", 5.0, -1.4)
    hanging_lamp(s, "LampLower", 20.0, -5.6, lit=False)
    s.box(D, "Winch", (6.0, -3.6, -1.6), (1.6, 0.9, 1.0), "wood_dark")
    s.cyl(D, "WinchDrum", (6.0, -2.9, -1.6), 0.4, 1.2, "wood", rot=(math.pi / 2, 0, 0), sides=10)
    s.shard("MirrorShard", 3.0, -4.5)
    s.note("HewerNote", 7.5, -4.5, "Записка забойщика", [
        "«Третий день вода прибывает в штреке. Насос качает сам — никто к нему не подходит».",
        "«Десятник велел молчать про кашель внизу».",
        "«Если не вернусь — мой кайло в выработке, у тёплой стены»."])
    s.marker("FromYard", (-24.0, 0.1, 0))
    s.marker("FromDrift", (23.0, -8.9, 0))
    s.door("DoorToYard", -24.5, 0, "mine_yard", "Spawns/FromShafts", "Наверх, к копру")
    s.door("DoorToDrift", 24.5, -9, "flooded_drift", "Spawns/FromShafts", "В штрек")
    k = bd.Kit(s)
    k.path_light(-26, -12, 0.0, PATH_MINE)
    k.path_light(-1, 10, -4.5, PATH_MINE)
    k.path_light(10, 26, -9.0, PATH_MINE)
    k.path_light(-9, -2, 5.0, PATH_MINE)
    save(s)


# ---------------------------------------------------------------- 3. Затопленный штрек
def flooded_drift():
    """Длинный штрек в воде: зумпф по пояс (вода вязкая, как болотная грязь), насосное колесо крутится само,
    завал посередине — через него поверху. Свечи в нишах — для фонаря из катакомб; без него — полутьма фонарей."""
    s = new_room("FloodedDrift", "flooded_drift", -28, 28, MINE)
    s.use("mud", "Script", "res://world/common/mud_zone.gd")
    land(s, "FloorWest", -58, -12, 0, -6)
    ramp(s, "SumpIn", -12, 0, -9.5, -2.5, thick=2.0)
    land(s, "SumpFloor", -9.5, -6.5, -2.5, -6, "mud")
    ramp(s, "SumpOut", -6.5, -2.5, -4, 0, thick=2.0)
    land(s, "FloorMid", -4, 6, 0, -6)
    ramp(s, "RubbleUp", 6, 0, 10, 1.4, "earth_dark", thick=2.0)
    land(s, "RubbleTop", 10, 12, 1.4, -6, "earth_dark")
    ramp(s, "RubbleDown", 12, 1.4, 14, 0, "earth_dark", thick=2.0)
    land(s, "FloorEast", 14, 58, 0, -6)
    land(s, "Ceiling", -58, 58, 7.0, 5.5)
    s.node("Sump", 'type="Area3D"', O, [f"position = {v3((-8.0, -2.5, 0.0))}", 'script = ExtResource("mud")', "size = Vector3(8.6, 1.9, 4.4)",
                                        "look_color = Color(0.03, 0.045, 0.05, 1)"])
    s.box(D, "SumpWater", (-8.0, -0.85, 0.0), (8.6, 0.05, 4.4), "water")
    s.box(D, "SeepWater", (12.0, 0.03, -1.6), (60.0, 0.04, 0.8), "water")
    for i in range(6):
        s.rocks(D, f"Rubble{i}", 7.0 + i * 1.2, 0.6 + (i % 3) * 0.3, -1.4 + (i % 2) * 0.4)
    # Насосное колесо крутится само.
    s.node("PumpWheel", 'type="Node3D"', D, [f"position = {v3((-20.0, 2.4, -2.0))}", 'script = ExtResource("spinner")', "speed = 0.15"])
    s.cyl(f"{D}/PumpWheel", "Axle", (0, 0, 0), 0.2, 0.6, "iron", rot=(math.pi / 2, 0, 0), sides=8)
    for i in range(8):
        a_ = i * math.tau / 8
        s.box(f"{D}/PumpWheel", f"Spoke{i}", (math.cos(a_) * 1.0, math.sin(a_) * 1.0, 0), (2.0, 0.1, 0.1), "wood_dark", rot=(0, 0, round(a_, 4)))
        s.box(f"{D}/PumpWheel", f"Bucket{i}", (math.cos(a_) * 2.1, math.sin(a_) * 2.1, 0), (0.4, 0.4, 0.5), "wood", rot=(0, 0, round(a_, 4)))
    s.box(D, "PumpTrough", (-17.5, 4.5, -1.9), (5.0, 0.3, 0.6), "wood_dark", rot=(0, 0, -0.05))
    for i, x in enumerate((-24.0, -15.0, -1.0, 4.0, 18.0, 24.0)):
        timber_set(s, f"Set{i}", x, 0.0)
    rock_back(s, "Back", -28, 28, -2.5, 5.5, veins=5)
    hanging_lamp(s, "LampWest", -24.0, 3.6)
    hanging_lamp(s, "LampEast", 21.0, 3.6, lit=False)
    hanging_lamp(s, "LampMid", 3.0, 3.6)
    for name, x in (("CandleSump", -13.5), ("CandleMid", 1.5), ("CandleEast", 17.0)):
        bg.candle(s, name, x, 0.0)
    s.marker("FromShafts", (-25.0, 0.1, 0))
    s.marker("FromGallery", (25.0, 0.1, 0))
    s.door("DoorToShafts", -26.5, 0, "mine_shafts", "Spawns/FromDrift", "Назад, к шахтам")
    s.door("DoorToGallery", 26.5, 0, "deep_gallery", "Spawns/FromDrift", "Глубже, к забою")
    k = bd.Kit(s)
    for x0, x1, y in ((-28, -12, 0.0), (-4, 6, 0.0), (14, 28, 0.0)):
        k.path_light(x0, x1, y, PATH_MINE)
    save(s)


# ---------------------------------------------------------------- 4. Глубокая выработка
def deep_gallery():
    """Самый глубокий забой: высокая камера, жилы руды тлеют красным, в полу трещины — оттуда жар.
    Посреди — провал, забитый досками: снизу красное зарево. Спуститься туда можно, подняться нельзя — пока
    ворот в Пекле (build_inferno.py) не опустит клеть. За провалом — молельня забойщиков у тёплой стены."""
    s = new_room("DeepGallery", "deep_gallery", -24, 24, DEEP)
    land(s, "FloorWest", -54, 10, 0, -6)
    land(s, "FloorEast", 16, 54, 0, -6)
    land(s, "Ceiling", -54, 54, 14, 12)
    # Провал, забитый досками: снизу жар.
    for i in range(5):
        s.box(G, f"Plank{i}", (round(10.6 + i * 1.2, 2), -0.12, round(((i * 3) % 5 - 2) * 0.08, 2)), (1.25, 0.24, 2.6), "wood",
              True, rot=(0, round(((i * 7) % 5 - 2) * 0.04, 3), round(((i * 11) % 5 - 2) * 0.03, 3)))
    s.box(D, "BreachGlow", (13.0, -9.0, 0.0), (5.8, 0.1, 3.6), "hot_vein")
    s.light(D, "BreachLight", (13.0, -1.5, 0.6), HEAT, 2.2, 10.0)
    s.veil(D, "BreachHeat", (13.0, 2.5, -0.6), (6.0, 6.0), "dust_veil")
    bg.say(s, "BreachLine", 9.0, 0.0, "«Доски над провалом. Снизу жар и красное зарево. Спуститься можно — подняться нельзя.»",
           size=(3, 3, 4))
    # Тлеющие жилы и трещины.
    rock_back(s, "Back", -24, 24, 0, 12, veins=6)
    for i, (x, y, ln, t) in enumerate(((-16.0, 4.0, 3.0, 0.4), (-6.0, 7.5, 4.0, -0.3), (4.0, 3.0, 2.6, 0.9), (20.0, 5.0, 3.4, -0.6))):
        s.box(D, f"HotVein{i}", (x, y, -2.16), (ln, 0.3, 0.04), "hot_vein", rot=(0, 0, t))
        s.box(D, f"HotVeinFork{i}", (x + ln * 0.3, y + 0.35, -2.17), (ln * 0.45, 0.16, 0.04), "hot_vein", rot=(0, 0, t + 0.6))
    for i, x in enumerate((-12.0, 1.0, 21.0)):
        s.box(D, f"Crack{i}", (x, 0.02, -0.8), (2.2, 0.03, 0.16), "hot_vein", rot=(0, 0.4 * (i - 1), 0))
    # Молельня забойщиков у тёплой стены: свечи, кайло, подношения.
    s.box(D, "ShrineStone", (20.0, 0.6, -1.8), (1.6, 1.2, 0.8), "stone")
    s.box(D, "ShrineCross", (20.0, 2.0, -1.9), (0.14, 1.6, 0.14), "wood_dark")
    s.box(D, "ShrineBar", (20.0, 2.4, -1.9), (0.9, 0.12, 0.14), "wood_dark")
    s.box(D, "OldPick", (18.6, 0.5, -1.2), (0.06, 1.1, 0.06), "wood", rot=(0, 0, -0.5))
    for name, x in (("CandleWest", -18.0), ("CandleShrine", 22.0)):
        bg.candle(s, name, x, 0.0)
    for i, x in enumerate((-20.0, -10.0, 2.0)):
        timber_set(s, f"Set{i}", x, 0.0, h=6.0)
    hanging_lamp(s, "LampWest", -15.0, 5.0, lit=False)
    s.note("LastShift", -4.0, 0.0, "Последняя смена", [
        "«Забой тёплый, как печь. Кайло не держится в руке».",
        "«Под ногами гул. Не вода. Дышит».",
        "«Доски положили. Никто не спускается. Никто»."])
    s.marker("FromDrift", (-21.0, 0.1, 0))
    s.marker("FromInferno", (8.0, 0.1, 0))
    s.door("DoorToDrift", -22.5, 0, "flooded_drift", "Spawns/FromGallery", "Назад, в штрек")
    s.door("DoorToInferno", 13.0, 0, "inferno_breach", "Spawns/FromMines", "Спуститься в провал",
           ["door_size = Vector3(1.8, 0.2, 0.15)", "door_color = Color(0.25, 0.17, 0.11, 1)"])
    k = bd.Kit(s)
    for x0, x1 in ((-24, 10), (16, 24)):
        k.path_light(x0, x1, 0.0, PATH_MINE, strength=0.8)
    save(s)


if __name__ == "__main__":
    mine_yard()
    mine_shafts()
    flooded_drift()
    deep_gallery()
    print("ok")
