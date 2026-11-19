"""Поля к западу от деревни (§8.13): скотный двор → ржаное поле → холм со столбом казни → мельница;
нижний путь — овраг и труба под холмом → огороды (погреб, гумно) → вдоль ручья к мельнице. Петля, осколок у мельницы.

Высоты — общие для всей области (м): земля скотного двора 0, поле 0, холм +3…+6, ветряк на холме +6,
низина огородов и мельничный ручей −6.5 (у огородов это их ноль). Враги (Полудница во ржи, Пугало на столбе)
будут позже: здесь только места под них — полосы ржи с прогалинами и плоская вершина холма под арену.
Свет по комнатам: двор — холодный утренний туман, рожь и холм — пыльный полдень (час Полудницы), низина — сумерки.
Запуск из корня проекта: python tools/levels/build_fields.py
"""
import math
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from scenery import Scene, v3  # noqa: E402
import backdrop as bd  # noqa: E402

G, D, O = "Geometry", "Decor", "Objects"
WALL, SWING, PULL = 2, 1, 0

MIST = {"bg": (0.05, 0.055, 0.07), "amb": (0.36, 0.4, 0.48), "amb_e": 0.42, "fog": (0.2, 0.22, 0.26), "fog_d": 0.028}
NOON = {"bg": (0.16, 0.15, 0.13), "amb": (0.5, 0.47, 0.4), "amb_e": 0.42, "fog": (0.34, 0.31, 0.24), "fog_d": 0.012}
DUSK = {"bg": (0.035, 0.035, 0.05), "amb": (0.32, 0.33, 0.4), "amb_e": 0.38, "fog": (0.14, 0.13, 0.17), "fog_d": 0.022}
BARN = {"bg": (0.0, 0.0, 0.0), "amb": (0.5, 0.42, 0.32), "amb_e": 0.55, "fog": (0.05, 0.04, 0.03), "fog_d": 0.008}
## Небо: верх, горизонт; солнце — пятно в небе (цвет и сила, x, y, размер).
SKY_MIST = ((0.06, 0.065, 0.085), (0.26, 0.28, 0.32))
SKY_NOON = ((0.2, 0.19, 0.17), (0.42, 0.38, 0.3))
SUN_NOON = ((1.0, 0.92, 0.7, 0.55), 0.56, 0.16, 0.09)
SKY_DUSK = ((0.03, 0.03, 0.05), (0.2, 0.15, 0.17))
SUN_DUSK = ((0.6, 0.25, 0.12, 0.4), 0.12, 0.62, 0.16)
## Подсвеченный путь (§2.2).
PATH_MIST = (0.06, 0.065, 0.075)
PATH_NOON = (0.035, 0.03, 0.02)
PATH_DUSK = (0.06, 0.06, 0.08)
JACK_LIGHT = (1.0, 0.55, 0.2)
## Флаги истории столба (§8.13): герой увидел пустой столб → вдова рассказала о казни → на столбе Пугало.
SAW_POST = "saw_post"
TALE = "scarecrow_tale"


def save(scene):
    Path(f"world/rooms/{scene.room_id}.tscn").write_text(scene.text(), encoding="utf-8")


def new_room(name, room_id, left, right, env, sun_color, sun_energy):
    s = Scene(name, room_id, right - left, env, sun_color, sun_energy)
    s.use("npc", "Script", "res://world/common/npc.gd")
    s.use("sayline", "Script", "res://world/common/say_line.gd")
    s.use("rye", "Script", "res://world/common/rye_field.gd")
    s.use("sunflowers", "Script", "res://world/common/sunflower_row.gd")
    s.use("flagshown", "Script", "res://world/common/flag_shown.gd")
    s.use("spinner", "Script", "res://world/common/spinner.gd")
    s.wall("WallLeft", (left - 0.5, 6.0, 0), (1, 40, 4.4))
    s.wall("WallRight", (right + 0.5, 6.0, 0), (1, 40, 4.4))
    return s


def seed(s, name):
    return zlib.crc32(f"{s.room_id}/{name}".encode()) % 100000 + 1


# ---------------------------------------------------------------- земля
def land(s, name, x0, x1, top, bottom, mat="stubble"):
    """Земля в плоскости героя: с коллизией, от bottom до top."""
    s.box(G, name, ((x0 + x1) / 2, (top + bottom) / 2, 0), (x1 - x0, top - bottom, 4.4), mat, True)


def back(s, name, x0, x1, top, z0=-2.2, z1=-36.0, mat="stubble", depth=6.0):
    """Земля за плоскостью героя, без коллизии: поле уходит вглубь до дальнего плана."""
    s.box(D, name, ((x0 + x1) / 2, top - depth / 2, (z0 + z1) / 2), (x1 - x0, depth, z0 - z1), mat)


def ramp(s, name, x0, y0, x1, y1, mat="stubble", thick=1.6, behind=True):
    """Склон в плоскости героя: верх идёт от (x0, y0) к (x1, y1), x0 < x1. behind — склон продолжается вглубь."""
    a = math.atan2(y1 - y0, x1 - x0)
    ln = math.hypot(x1 - x0, y1 - y0) + 0.1
    cx, cy = (x0 + x1) / 2 + math.sin(a) * thick / 2, (y0 + y1) / 2 - math.cos(a) * thick / 2
    s.box(G, name, (cx, cy, 0), (ln, thick, 4.4), mat, True, rot=(0, 0, round(a, 4)))
    if behind:
        s.box(D, f"{name}Back", (cx, cy, -19.1), (ln, thick, 33.8), mat, rot=(0, 0, round(a, 4)))


# ---------------------------------------------------------------- культуры и люди поля
def rye(s, name, x0, x1, y, rise=0.0, h=1.3):
    """Полоса ржи (RyeField) от x0 до x1; земля у левого края на высоте y, к правому поднимается на rise."""
    s.node(name, 'type="Node3D"', D, [f"position = {v3(((x0 + x1) / 2, y, 0))}", 'script = ExtResource("rye")',
                                      f"length = {x1 - x0}", f"height = {h}", f"rise = {rise}", f"seed = {seed(s, name)}"])


def sunflowers(s, name, x0, x1, y, z, count, rise=0.0, h=2.4, focus="../PostTop"):
    """Ряд мёртвых подсолнухов (SunflowerRow): головы на столб, после рассказа — на героя."""
    s.node(name, 'type="Node3D"', D, [f"position = {v3((x0, y, z))}", 'script = ExtResource("sunflowers")', f"length = {x1 - x0}",
                                      f"count = {count}", f"height = {h}", f"rise = {rise}", f"seed = {seed(s, name)}",
                                      f'focus = NodePath("{focus}")', f'watch_flag = &"{TALE}"'])


def stook(s, name, x, z, ground=0.0, h=1.7):
    """Копна: снопы стоят шалашом, колосьями вверх, перевязаны посередине."""
    for i, a in enumerate((-0.28, 0.0, 0.28)):
        s.cyl(D, f"{name}{i}", (x - math.sin(a) * h * 0.4, ground + h / 2 - 0.05, z + (0.15 if i == 1 else -0.1)), h * 0.13, h,
              "straw", rot=(0, 0, a), sides=7)
    s.cyl(D, f"{name}Ears", (x, ground + h * 0.98, z), h * 0.2, h * 0.28, "straw", sides=7, cone=True)
    s.box(D, f"{name}Band", (x, ground + h * 0.5, z), (h * 0.3, 0.06, h * 0.3), "rope")


def pumpkin(s, name, x, z, ground=0.0, r=0.38, lit=False):
    """Тыква; lit — вырезанный фонарь: лицо светится, рядом тёплый свет (единственный свет ночного огорода)."""
    s.node(name, 'type="CSGSphere3D"', D, [f"position = {v3((x, ground + r * 0.62, z))}", "scale = Vector3(1.25, 0.8, 1.1)",
                                         f"radius = {r}", "radial_segments = 10", "rings = 6", f"material = {s.mat('pumpkin')}"])
    s.box(D, f"{name}Stem", (x + 0.04, ground + r * 1.28, z), (0.07, 0.2, 0.07), "leaf", rot=(0, 0, 0.3))
    if lit:
        face = z + r * 1.06
        for i, dx in enumerate((-0.13, 0.13)):
            s.box(D, f"{name}Eye{i}", (x + dx, ground + r * 0.75, face), (0.1, 0.08, 0.04), "jack", rot=(0, 0, 0.3 * (1 if i else -1)))
        s.box(D, f"{name}Mouth", (x, ground + r * 0.42, face), (0.3, 0.07, 0.04), "jack")
        s.light(D, f"{name}Light", (x, ground + 0.6, z + 0.9), JACK_LIGHT, 0.9, 4.5)


def turnips(s, name, x0, x1, z, ground=0.0):
    x, i = x0, 0
    while x < x1:
        s.sphere(D, f"{name}{i}", (round(x, 2), ground + 0.06, z), 0.16, "turnip")
        s.tuft(D, f"{name}Leaf{i}", round(x, 2), ground + 0.15, z, mat="leaf", h=0.35)
        x += 0.85
        i += 1


def scarecrow(s, parent, name, x, y, z, k=1.0, pole=True, chain=False):
    """Пугало: крестовина, мешок-голова, драный кафтан, солома из рукавов. Без pole — привязано к чужому столбу.
    chain — на поясе крюк на цепи (награда за Пугало)."""
    if pole:
        s.box(parent, f"{name}Pole", (x, y + 1.5 * k, z), (0.12 * k, 3.0 * k, 0.12 * k), "wood_dark")
        s.box(parent, f"{name}Bar", (x, y + 2.25 * k, z), (1.8 * k, 0.1 * k, 0.1 * k), "wood_dark")
    zf = z + 0.1
    s.box(parent, f"{name}Coat", (x, y + 1.7 * k, zf), (0.7 * k, 1.2 * k, 0.34 * k), "cloth", rot=(0, 0, 0.04))
    for i, side in enumerate((-1, 1)):
        s.box(parent, f"{name}Sleeve{i}", (x + side * 0.62 * k, y + 2.18 * k, zf), (0.62 * k, 0.26 * k, 0.28 * k), "cloth",
              rot=(0, 0, side * -0.12))
        s.tuft(parent, f"{name}Straw{i}", x + side * 1.0 * k, y + 1.95 * k, zf, mat="straw", h=0.3 * k)
    s.sphere(parent, f"{name}Head", (x, y + 2.62 * k, zf), 0.24 * k, "sack")
    s.cyl(parent, f"{name}Brim", (x, y + 2.84 * k, zf), 0.42 * k, 0.04 * k, "wood_dark", sides=10)
    s.cyl(parent, f"{name}Hat", (x + 0.03, y + 3.08 * k, zf), 0.24 * k, 0.48 * k, "wood_dark", sides=8, cone=True, rot=(0, 0, -0.15))
    s.tuft(parent, f"{name}Hem", x, y + 0.95 * k, zf, mat="straw", h=0.35 * k)
    if chain:
        for i in range(5):
            s.box(parent, f"{name}Chain{i}", (x + 0.3 * k, y + (1.3 - i * 0.17) * k, zf + 0.2), (0.07, 0.16, 0.07), "iron", rot=(0, i * 0.8, 0))
        s.box(parent, f"{name}Hook", (x + 0.36 * k, y + 0.4 * k, zf + 0.2), (0.08, 0.36, 0.08), "iron", rot=(0, 0, 0.5))
        s.box(parent, f"{name}HookTip", (x + 0.24 * k, y + 0.26 * k, zf + 0.2), (0.22, 0.07, 0.07), "iron", rot=(0, 0, -0.5))


def beast(s, name, x, z, kind="cow", face=1):
    """Скотина за плетнём — силуэт: корова или овца."""
    if kind == "cow":
        s.box(D, f"{name}Body", (x, 1.05, z), (1.9, 0.9, 0.7), "hide")
        s.box(D, f"{name}Head", (x + face * 1.15, 1.2, z), (0.5, 0.42, 0.38), "hide", rot=(0, 0, face * -0.3))
        legs, h = ((-0.75, 0.75), 0.7)
    else:
        s.box(D, f"{name}Body", (x, 0.68, z), (1.0, 0.6, 0.55), "wool")
        s.box(D, f"{name}Head", (x + face * 0.6, 0.78, z), (0.3, 0.28, 0.24), "char")
        legs, h = ((-0.35, 0.35), 0.42)
    for i, dx in enumerate(legs):
        for j, dz in enumerate((-0.2, 0.2)):
            s.box(D, f"{name}Leg{i}{j}", (x + dx, h / 2, z + dz), (0.13, h, 0.13), "char")


def house(s, name, x, z, w, h, roof_h, ground=0.0, windows=(), mat="wood_dark"):
    s.box(D, f"{name}Wall", (x, ground + h / 2, z), (w, h, 4.0), mat)
    s.roof(D, f"{name}Roof", (x, ground + h + roof_h / 2, z), (w + 1.4, roof_h, 4.8), "shingle")
    for i, (wx, wy) in enumerate(windows):
        s.box(D, f"{name}Window{i}", (x + wx, ground + wy, z + 2.02), (0.8, 1.0, 0.08), "window")


def ground_cover(k, spans, path, color):
    """Ближняя земля перед героем (spans) и подсвеченный путь (path) по ровным участкам: (x0, x1, y)."""
    for x0, x1, y in spans:
        k.near_ground(x0, x1, y - 0.25, pad=0)
    for x0, x1, y in path:
        k.path_light(x0, x1, y, color)


# ---------------------------------------------------------------- 1. Скотный двор
def farmyard():
    """Край деревни (art/concepts/locations/village_farm.png): хлев под чёрной дранкой, скотина за плетнём,
    костёр под котлом — самое яркое пятно, туша на перекладине, колодец, сухое дерево с железными оберегами.
    Справа — улица деревни, слева — ворота в поле. Скотница пугает Полудницей."""
    s = new_room("Farmyard", "farmyard", -26, 26, MIST, (0.6, 0.66, 0.8), 0.3)
    land(s, "Ground", -56, 56, 0, -4, "mud")
    back(s, "BackGround", -86, 86, 0, mat="mud")
    k = bd.Kit(s)
    k.sky(-26, 26, *SKY_MIST)
    bd.fields(k, -26, 26, MIST["fog"], mill_x=-110.0, village=True)
    k.firs(0, 26 + bd.FAR_PAD, -17, -24, 9, 15, step=(2.5, 5.0))
    # Хлев и загон.
    house(s, "Barn", -6.0, -6.6, 14, 4.4, 3.2)
    s.box(D, "BarnDark", (-6.0, 1.8, -4.55), (12, 3.6, 0.1), "char")
    for i, x in enumerate((-12.6, -7.0, -1.4)):
        s.box(D, f"BarnPost{i}", (x, 2.2, -4.45), (0.3, 4.4, 0.3), "wood_dark")
    s.box(D, "BarnLamp", (-3.0, 3.0, -4.35), (0.25, 0.4, 0.25), "lantern")
    s.light(D, "BarnLampLight", (-3.0, 2.8, -3.4), (1.0, 0.6, 0.28), 0.8, 5.0)
    s.fence(D, "Pen", -14, 2, -2.8, step=0.9, mat="wood_dark")
    beast(s, "Cow0", -10.0, -4.0, "cow", 1)
    beast(s, "Cow1", -5.4, -3.9, "cow", -1)
    beast(s, "Sheep0", -2.2, -3.4, "sheep", 1)
    beast(s, "Sheep1", -0.6, -3.7, "sheep", -1)
    # Колодец и стог у ворот в поле.
    s.cyl(D, "WellRing", (-17.0, 0.5, -2.2), 0.9, 1.0, "stone", sides=10)
    for i, dx in enumerate((-0.8, 0.8)):
        s.box(D, f"WellPost{i}", (-17.0 + dx, 1.6, -2.2), (0.14, 2.2, 0.14), "wood_dark")
    s.roof(D, "WellRoof", (-17.0, 3.1, -2.2), (2.4, 0.9, 1.6), "shingle")
    s.cyl(D, "WellBucket", (-16.6, 1.6, -2.2), 0.16, 0.3, "wood", sides=8)
    s.cyl(D, "Haystack", (-21.5, 1.2, -3.2), 1.7, 2.4, "straw", sides=10, cone=True)
    s.box(G, "HayCart", (-19.0, 0.55, 0), (2.4, 1.1, 1.4), "wood", True)
    s.box(D, "HayLoad", (-19.0, 1.35, 0), (2.2, 0.6, 1.2), "straw")
    for i, x in enumerate((-19.9, -18.1)):
        s.cyl(D, f"HayCartWheel{i}", (x, 0.5, 0.8), 0.5, 0.1, "wood_dark", rot=(math.pi / 2, 0, 0), sides=12)
    # Костёр под котлом — самое яркое пятно двора; рядом колода с топором.
    for i, a in enumerate((-0.35, 0.0, 0.35)):
        s.box(D, f"Tripod{i}", (6.0 + a * 1.6, 1.2, -1.6 + (0.4 if i == 1 else 0)), (0.08, 2.5, 0.08), "wood_dark", rot=(0, 0, -a))
    s.cyl(D, "Cauldron", (6.0, 0.75, -1.6), 0.45, 0.6, "iron", sides=10)
    s.box(D, "CauldronFire", (6.0, 0.18, -1.6), (0.7, 0.35, 0.6), "fire")
    s.light(D, "CauldronLight", (6.0, 1.2, -0.6), (1.0, 0.55, 0.22), 2.6, 9.0)
    s.veil(D, "CauldronSmoke", (6.0, 4.2, -1.9), (2.6, 5.5), "fog_veil")
    s.cyl(D, "Block", (4.0, 0.3, -0.8), 0.35, 0.6, "wood", sides=8)
    s.box(D, "AxeHandle", (4.1, 0.85, -0.8), (0.06, 0.7, 0.06), "wood", rot=(0, 0, 0.4))
    s.box(D, "AxeHead", (3.95, 0.62, -0.8), (0.3, 0.18, 0.05), "iron", rot=(0, 0, 0.4))
    # Туша на перекладине и лохань под ней.
    for i, x in enumerate((8.6, 10.8)):
        s.box(D, f"HangPost{i}", (x, 1.6, -2.4), (0.18, 3.2, 0.18), "wood_dark")
    s.box(D, "HangBeam", (9.7, 3.2, -2.4), (2.6, 0.18, 0.18), "wood_dark")
    s.box(D, "Carcass", (9.7, 2.2, -2.4), (0.5, 1.3, 0.4), "rotten")
    s.cyl(D, "Tub", (9.7, 0.3, -2.4), 0.6, 0.6, "wood", sides=10)
    # Амбар на сваях: с ящика — на настил, там сундук.
    s.box(G, "Crate", (11.8, 0.6, 0), (1.2, 1.2, 1.2), "wood", True)
    s.box(G, "Granary", (15.0, 2.4, 0), (4.0, 0.4, 2.4), "wood", True)
    for i, (x, z) in enumerate(((13.3, -0.9), (16.7, -0.9), (13.3, 0.9), (16.7, 0.9))):
        s.box(D, f"GranaryStilt{i}", (x, 1.1, z), (0.2, 2.2, 0.2), "wood_dark")
    s.box(D, "GranaryWall", (15.0, 3.6, -1.3), (4.0, 2.0, 0.2), "wood_dark")
    s.roof(D, "GranaryRoof", (15.0, 5.4, -0.4), (4.8, 1.6, 2.8), "shingle")
    s.chest("GranaryChest", (15.6, 2.6, -0.6), 80, "farmyard_chest", ("throwing_axe",) * 2)
    # Сухое дерево с железными оберегами.
    s.dead_tree(D, "CharmTree", 19.5, -5.0, 9.0, r=0.45)
    for i, (dx, y) in enumerate(((-1.6, 6.2), (-0.9, 5.4), (1.2, 6.8), (2.0, 5.8), (0.4, 7.4))):
        s.box(D, f"CharmChain{i}", (19.5 + dx, y + 0.45, -4.6), (0.03, 0.9, 0.03), "iron")
        s.box(D, f"Charm{i}", (19.5 + dx, y - 0.1, -4.6), (0.32, 0.32, 0.04), "iron", rot=(0, 0, 0.785))
    # Изба у выхода в деревню.
    house(s, "Farmhouse", 23.0, -4.6, 7, 4.4, 3.4, windows=((-1.6, 2.6), (1.6, 2.6)))
    s.light(D, "FarmhouseGlow", (23.0, 2.6, -1.8), (1.0, 0.6, 0.28), 1.2, 7.0)
    s.npc("Cowherd", 2.0, 0.0, "Скотница", [
        "Скотину из поля пригнала затемно. В полдень туда не ходят.",
        "Во ржи кто-то ходит. Колосья клонятся против ветра — значит, она рядом.",
        "Полудница спрашивает загадки. Не ответишь — свернёт шею. Ответишь — всё равно свернёт.",
        "За ржаным полем столб на холме. Вчера там… не хочу говорить. Спроси вдову у мельницы."],
        (0.3, 0.27, 0.22),
        [f'after_flag = &"{TALE}"', 'lines_after = PackedStringArray("Видел его? На столбе? Значит, и он тебя видел.", '
         '"Вороны с холма улетели. Все до одной.")'])
    s.marker("FromStreet", (23.0, 0.1, 0))
    s.marker("FromRye", (-23.0, 0.1, 0))
    s.door("DoorToStreet", 24.5, 0, "village_street", "Spawns/FromFarm", "В деревню")
    s.door("DoorToRye", -24.5, 0, "rye_field", "Spawns/FromFarm", "В поле")
    k.foreground("village", -26, 26)
    ground_cover(k, [(-56, 56, 0)], [(-26, 26, 0)], PATH_MIST)
    save(s)


# ---------------------------------------------------------------- 2. Ржаное поле
def rye_field():
    """Рожь по грудь волнами (дом Полудницы): полосы ржи с прогалинами, придорожный крест, коса в земле.
    На западе тропа поднимается на холм; перед ним овраг — по мосткам над ним, а в дыру у края мостков
    спускается лестница: дно оврага уходит в старую трубу под холмом — нижний путь к огородам.
    Сторожка на сваях с сундуком — кольцо на кромке её настила, без крюка не забраться.
    На жнивье у копён — вороны-сторожа (§8.14): мимо шагом, иначе стая взлетит и позовёт тех, кто во ржи.
    Во ржи на увале прячется Полудница: её видно только по волне в колосьях, встаёт за спиной с серпом."""
    s = new_room("RyeField", "rye_field", -44, 44, NOON, (1.0, 0.92, 0.76), 0.65)
    land(s, "Plateau", -22, 74, 0, -12)
    ramp(s, "SwellUp", 2, 0, 6, 1.0)
    land(s, "SwellTop", 6, 10, 1.0, -1)
    ramp(s, "SwellDown", 10, 1.0, 14, 0)
    ramp(s, "HumpUp", -18, 0, -15, 0.8)
    land(s, "HumpTop", -15, -11, 0.8, -1)
    ramp(s, "HumpDown", -11, 0.8, -8, 0)
    # Овраг и труба под холмом (нижний путь).
    land(s, "GullyFloor", -74, -22, -6.5, -10, "mud")
    land(s, "HillBase", -74, -30, 0, -2)
    land(s, "Hill", -74, -38, 3, 0)
    ramp(s, "HillSlope", -38, 3, -30, 0, thick=2.0)
    s.box(G, "Footbridge", (-26.8, -0.15, 0), (6.4, 0.3, 2.6), "wood", True)
    for i, x in enumerate((-29.4, -24.4)):
        for j, z in enumerate((-1.0, 1.0)):
            s.box(D, f"BridgePost{i}{j}", (x, -3.3, z), (0.2, 6.4, 0.2), "wood_dark")
    s.box(D, "BridgeRail", (-26.8, 0.9, -1.15), (6.4, 0.08, 0.08), "wood_dark")
    s.ladder("GullyLadder", -22.6, -6.5, 6.5, 1.0)
    s.ladder_look("Gully", -22.6, -6.5, 6.5)
    s.box(D, "HatchLid", (-22.9, 0.7, -1.3), (1.4, 0.1, 1.2), "wood", rot=(0.0, 0.0, 1.2))
    s.box(D, "CulvertLintel", (-30.3, -2.5, 0), (0.8, 1.0, 4.6), "stone")
    for i, z in enumerate((-2.0, 2.0)):
        s.box(D, f"CulvertPier{i}", (-30.3, -4.5, z), (0.9, 4.0, 0.6), "stone")
    s.box(D, "CulvertBack", (-37.0, -4.25, -2.4), (14.0, 4.5, 0.3), "stone_dark")
    s.box(D, "Trickle", (-33.0, -6.45, -1.4), (22.0, 0.05, 0.7), "water")
    # Сторожка на сваях: кольцо на кромке настила — вернуться с крюком.
    s.box(G, "Perch", (28.0, 6.8, 0), (4.0, 0.4, 2.4), "wood", True)
    for i, (x, z) in enumerate(((26.3, -0.9), (29.7, -0.9), (26.3, 0.9), (29.7, 0.9))):
        s.box(D, f"PerchStilt{i}", (x, 3.3, z), (0.22, 6.6, 0.22), "wood_dark")
    s.box(D, "PerchBrace", (28.0, 3.4, -0.9), (4.6, 0.14, 0.14), "wood_dark", rot=(0, 0, 0.9))
    s.roof(D, "PerchRoof", (28.0, 10.0, -0.3), (4.8, 1.6, 2.8), "thatch")
    for i, x in enumerate((26.2, 29.8)):
        s.box(D, f"PerchRoofPost{i}", (x, 8.1, -1.0), (0.14, 2.2, 0.14), "wood_dark")
    s.hook_point("PerchRing", (25.5, 7.3, 0.0), WALL)
    s.chest("PerchChest", (28.6, 7.0, -0.6), 150, "rye_perch_chest", ("tempered_glass", "fire_flask", "fire_flask"))
    for i, x in enumerate((27.0, 28.4)):
        s.crow(D, f"PerchCrow{i}", x, 10.75, -0.2)
    # Придорожный крест на прогалине, коса в земле, борона, копны.
    s.box(D, "ShrinePost", (-2.0, 1.6, -1.8), (0.18, 3.2, 0.18), "wood_dark")
    s.box(D, "ShrineBar", (-2.0, 2.6, -1.8), (1.2, 0.14, 0.14), "wood_dark")
    s.roof(D, "ShrineRoof", (-2.0, 3.45, -1.8), (1.0, 0.5, 0.6), "shingle")
    s.box(D, "ShrineIcon", (-2.0, 2.0, -1.66), (0.3, 0.4, 0.04), "candle")
    s.light(D, "ShrineLight", (-2.0, 2.0, -0.9), (1.0, 0.7, 0.35), 0.6, 3.5)
    s.box(D, "ScytheHandle", (-12.6, 1.8, -0.8), (0.07, 1.9, 0.07), "wood", rot=(0, 0, -0.35))
    s.box(D, "ScytheBlade", (-12.1, 0.95, -0.8), (0.9, 0.06, 0.04), "iron", rot=(0, 0, 0.5))
    s.box(D, "ScytheRag", (-12.95, 2.5, -0.75), (0.25, 0.5, 0.03), "cloth", rot=(0, 0, 0.2))
    s.box(D, "Harrow", (19.0, 0.25, -1.4), (2.2, 0.12, 1.2), "wood_dark", rot=(0, 0.3, 0.12))
    for i in range(5):
        s.box(D, f"HarrowTooth{i}", (18.2 + i * 0.4, 0.1, -1.4), (0.05, 0.25, 0.05), "iron")
    for i, (x, z) in enumerate(((21.0, -4.0), (24.0, -5.5), (33.5, -3.6), (37.0, -5.0), (40.0, -3.8))):
        stook(s, f"Stook{i}", x, z)
    s.dead_tree(D, "PearTree", 36.0, -7.0, 7.5, r=0.32)
    # Полудница (§8.13): прячется в ржи на увале; выдаёт её волна — колосья клонятся против ветра.
    s.use("poludnitsa", "PackedScene", "res://actors/enemies/poludnitsa.tscn")
    s.enemy("Poludnitsa", "poludnitsa", (12.0, 0.6, 0))
    # Вороны-сторожа на жнивье между копнами и тропой; сторож — на столбе изгороди у бороны.
    s.crow_flock("CrowFlock", (23.5, 0.0, 0.0), count=8, width=5.0, sentry=(-2.9, 1.3, -1.6), z_near=-1.9, z_far=-3.4)
    # Рожь: полосы с прогалинами (прогалина у креста, сторожка, вход).
    rye(s, "RyeHump", -21, -6, 0, 0)
    rye(s, "RyeSwell", 2, 18, 0, 0)
    rye(s, "RyeHill", -44, -38, 3, 0)
    rye(s, "RyeFar", 34, 44, 0, 0, h=1.1)
    # Земля вглубь, фон.
    back(s, "BackField", -22, 74, 0)
    back(s, "BackGully", -30, -22, -6.5, z1=-9.0, mat="mud")
    back(s, "GullyWall", -30, -22, 0, z0=-9.0, depth=7.0)
    back(s, "BackHill", -74, -30, 3, depth=6.0)
    k = bd.Kit(s)
    k.sky(-44, 44, *SKY_NOON, glow=SUN_NOON[0], glow_x=SUN_NOON[1], glow_y=SUN_NOON[2], glow_size=SUN_NOON[3])
    bd.fields(k, -44, 44, NOON["fog"], mill_x=-95.0, village=True)
    s.marker("FromFarm", (41.0, 0.1, 0))
    s.marker("FromHill", (-41.0, 3.1, 0))
    s.marker("FromCulvert", (-41.0, -6.4, 0))
    s.door("DoorToFarm", 42.5, 0, "farmyard", "Spawns/FromRye", "На скотный двор")
    s.door("DoorToHill", -42.5, 3, "execution_hill", "Spawns/FromRye", "На холм")
    s.door("DoorToCulvert", -42.5, -6.5, "vegetable_patch", "Spawns/FromCulvert", "В трубу под холмом")
    k.foreground("fields", -44, 44, ground=lambda x: 0.0 if x > -22 else -6.5, skip=((-31, -21),))
    ground_cover(k, [(-22, 74, 0), (-74, -22, -6.5)],
                 [(-22, -18, 0), (-8, 2, 0), (14, 44, 0), (6, 10, 1.0), (-15, -11, 0.8), (-44, -38, 3), (-44, -23, -6.5)], PATH_NOON)
    save(s)


# ---------------------------------------------------------------- 3. Холм со столбом
def execution_hill():
    """Лобное место: подсолнухи по склону, плоская вершина (арена Пугала, бой — позже), в середине — столб казни.
    Пока рассказ не услышан — столб пуст: перетёртые верёвки и вороны; герой, подойдя, понимает, что здесь
    кого-то казнили (флаг saw_post). После рассказа вдовы (scarecrow_tale) на столбе висит Пугало, а головы
    подсолнухов поворачиваются за героем."""
    s = new_room("ExecutionHill", "execution_hill", -30, 30, NOON, (1.0, 0.92, 0.76), 0.65)
    land(s, "Foot", 22, 60, 3, -8)
    ramp(s, "Slope", 12, 6, 22, 3, thick=2.0)
    land(s, "SlopeFill", 12, 22, 3, -8)
    land(s, "Top", -60, 12, 6, -8)
    # Столб казни и его состояния.
    px, pz, top = -3.0, -1.6, 6.0
    s.box(D, "PostPole", (px, top + 2.8, pz), (0.34, 5.6, 0.34), "wood_dark")
    s.box(D, "PostBar", (px, top + 4.6, pz), (2.4, 0.26, 0.26), "wood_dark")
    s.box(D, "PostStain", (px, top + 0.02, pz + 0.6), (3.2, 0.04, 2.0), "char")
    s.rocks(D, "PostStones", px - 0.6, top, pz + 0.4)
    s.node("PostTop", 'type="Marker3D"', D, [f"position = {v3((px, top + 4.0, pz))}"])
    s.node("PostEmpty", 'type="Node3D"', D, ['script = ExtResource("flagshown")', f'flag = &"{TALE}"', "shown_when_set = false"])
    for i, dx in enumerate((-1.0, 1.0)):
        s.box(f"{D}/PostEmpty", f"CutRope{i}", (px + dx, top + 4.1, pz + 0.18), (0.05, 0.9, 0.05), "rope", rot=(0, 0, dx * 0.08))
    s.box(f"{D}/PostEmpty", "RopeCoil", (px, top + 3.0, pz + 0.2), (0.4, 0.18, 0.12), "rope")
    for i, dx in enumerate((-0.9, 0.3, 1.05)):
        s.crow(f"{D}/PostEmpty", f"Crow{i}", px + dx, top + 4.73, pz)
    s.node("PostScarecrow", 'type="Node3D"', D, ['script = ExtResource("flagshown")', f'flag = &"{TALE}"', "shown_when_set = true"])
    scarecrow(s, f"{D}/PostScarecrow", "Scarecrow", px, top + 4.6 - 2.25 * 1.15, pz, k=1.15, pole=False, chain=True)
    for i, dx in enumerate((-1.0, 1.0)):
        s.box(f"{D}/PostScarecrow", f"Bind{i}", (px + dx * 0.9, top + 4.6, pz + 0.2), (0.12, 0.3, 0.32), "rope")
    s.node("PostLine", 'type="Area3D"', O, [f"position = {v3((px, top, 0))}", 'script = ExtResource("sayline")',
                                            'text = "«Пустой столб. Верёвки перетёрты, дерево вытерто до блеска — кто-то долго здесь висел.»"',
                                            f'sets_flag = &"{SAW_POST}"', f'until_flag = &"{TALE}"', "size = Vector3(6, 4, 4)"])
    s.node("ScarecrowState", 'type="Node3D"', O, ['script = ExtResource("flagshown")', f'flag = &"{TALE}"', "shown_when_set = true"])
    s.node("ScarecrowLine", 'type="Area3D"', f"{O}/ScarecrowState", [f"position = {v3((px, top, 0))}", 'script = ExtResource("sayline")',
                                                                    'text = "«На столбе кто-то есть. Вчера его здесь не было.»"',
                                                                    "size = Vector3(10, 4, 4)"])
    # Подсолнухи: по склону, вокруг вершины (арена свободна), редкие спереди.
    sunflowers(s, "SunSlope", 12, 22, 6, -2.8, 7, rise=-3.0)
    sunflowers(s, "SunFoot", 22, 30, 3, -2.6, 6)
    sunflowers(s, "SunWest", -30, -17, 6, -3.0, 9)
    sunflowers(s, "SunArena", -16, 11, 6, -4.4, 14, h=2.7)
    sunflowers(s, "SunFrontEast", 14, 20, 5.4, 1.9, 3, rise=-1.8, h=2.0)
    sunflowers(s, "SunFrontWest", -28, -22, 6, 2.0, 3, h=2.0)
    rye(s, "RyeFoot", 22, 30, 3, 0)
    # Гребень холма за столбом: сухое дерево, остатки каменной ограды.
    s.dead_tree(D, "CrestTree", 7.0, -7.0, 10.0, ground=top, r=0.4)
    for i, x in enumerate((-14.0, -12.6, -11.0, 3.5, 5.2)):
        s.box(D, f"Ruin{i}", (x, top + 0.4 + (i % 2) * 0.2, -5.6), (1.2, 0.8 + (i % 2) * 0.4, 0.7), "stone", rot=(0, 0, (i - 2) * 0.05))
    back(s, "BackTop", -60, 12, 6, depth=14.0)
    back(s, "BackFoot", 12, 60, 3, depth=11.0)
    k = bd.Kit(s)
    k.sky(-30, 30, *SKY_NOON, glow=SUN_NOON[0], glow_x=SUN_NOON[1], glow_y=SUN_NOON[2], glow_size=SUN_NOON[3])
    bd.fields(k, -30, 30, NOON["fog"], ground=3.0, mill_x=-48.0, bridge_x=-95.0)
    s.marker("FromRye", (27.0, 3.1, 0))
    s.marker("FromMill", (-27.0, 6.1, 0))
    s.door("DoorToRye", 28.5, 3, "rye_field", "Spawns/FromHill", "Вниз, в рожь")
    s.door("DoorToMill", -28.5, 6, "mill", "Spawns/FromHill", "К мельнице")
    k.foreground("fields", -30, 30, ground=lambda x: 6.0 if x < 12 else 3.0, skip=((11, 23),))
    k.near_slope(12, 6, 22, 3)
    ground_cover(k, [(-60, 12, 6), (22, 60, 3)], [(-30, 12, 6), (22, 30, 3)], PATH_NOON)
    save(s)


# ---------------------------------------------------------------- 4. Мельница
def mill():
    """Ветряк на холме и водяная мельница у ручья внизу. Наверху — осколок и вдова мельника (рассказ о казни);
    с полки на скале — две лестницы вниз, к ручью. За мельницей — запруда: вода стоит выше дороги (позже —
    уровень-забег «прорыв плотины»). С балкона ветряка старый подвесной мост ведёт к скале на западе — там дверь
    на Подвесной перевал (build_mountains.py): дальше пролёты обрушены, без крюка не пройти."""
    s = new_room("Mill", "mill", -32, 32, DUSK, (0.6, 0.56, 0.66), 0.32)
    land(s, "Upper", 4, 62, 6, -1.5)
    land(s, "Valley", -62, 62, -6.5, -10, "mud")
    land(s, "Shelf", -6, 4, 0, -0.6, "stone_dark")
    s.ladder("ShelfLadder", 3.4, 0, 6.0, 1.0)
    s.ladder_look("Shelf", 3.4, 0, 6.0)
    s.ladder("ValleyLadder", -6.6, -6.5, 6.5, 1.0)
    s.ladder_look("Valley", -6.6, -6.5, 6.5)
    # Лицо холма — не ровная плита: подпорная стена из бута с контрфорсами, ряды кладки, травяной край
    # сверху, свисающие корни, валуны у подножия; под холмом — арка прохода к огородам.
    s.box(D, "HillFace", (18.0, 2.25, 2.24), (28.0, 7.5, 0.06), "earth_dark")
    for i, x in enumerate((6.5, 12.0, 17.5, 23.0, 28.5)):
        h = 6.2 - (i % 2) * 0.9
        s.box(D, f"Buttress{i}", (x, 6.0 - h / 2, 2.4), (1.1, h, 0.4), "stone_dark", rot=(0, 0, round((i % 3 - 1) * 0.02, 3)))
        s.box(D, f"ButtressCap{i}", (x, 6.05, 2.45), (1.3, 0.25, 0.5), "stone")
    for i, y in enumerate((0.6, 2.2, 3.9)):
        for j in range(4):
            x0 = 4.6 + j * 7.0 + (i % 2) * 2.4
            s.box(D, f"Course{i}_{j}", (x0 + 2.2, y, 2.3), (4.2, 0.12, 0.08), "stone", rot=(0, 0, round(((i + j) % 3 - 1) * 0.015, 3)))
    s.box(D, "GrassLip", (18.0, 6.02, 2.25), (28.0, 0.14, 0.35), "moss")
    for i, x in enumerate((8.4, 14.6, 20.2, 26.8, 31.0)):
        s.box(D, f"Root{i}", (x, 4.9 - (i % 2) * 0.4, 2.33), (0.07, 2.2 - (i % 3) * 0.5, 0.07), "root", rot=(0, 0, round((i % 3 - 1) * 0.12, 3)))
    for i, (x, r) in enumerate(((5.2, 0.7), (9.8, 0.5), (25.5, 0.8))):
        s.sphere(D, f"Boulder{i}", (x, -1.5 + r * 0.6, 2.0), r, "stone_dark")
    s.box(D, "PassageArch", (6.0, -1.0, 2.3), (4.2, 0.9, 0.5), "stone")
    for i, x in enumerate((4.3, 7.7)):
        s.box(D, f"PassageJamb{i}", (x, -3.75, 2.2), (0.6, 5.5, 0.5), "stone_dark")
    # Ветряк: каменный низ, деревянная башня, шатёр, крылья вращаются за плоскостью героя; балкон спереди.
    mx = 18.0
    s.box(D, "MillBase", (mx, 7.5, -5.5), (5.5, 3.0, 5.0), "stone")
    s.box(D, "MillBody", (mx, 13.5, -5.5), (4.4, 9.0, 4.4), "wood_dark")
    s.roof(D, "MillCap", (mx, 19.5, -5.5), (5.6, 3.0, 5.6), "shingle")
    s.box(D, "MillDoor", (mx, 7.1, -2.95), (1.2, 2.2, 0.1), "window")
    s.box(D, "MillWindow", (mx + 1.0, 12.0, -3.25), (0.5, 0.7, 0.08), "window")
    s.light(D, "MillDoorLight", (mx, 7.6, -1.6), (1.0, 0.6, 0.28), 1.4, 7.0)
    s.node("Sails", 'type="Node3D"', D, [f"position = {v3((mx, 16.5, -2.9))}", 'script = ExtResource("spinner")', "speed = 0.22"])
    s.cyl(f"{D}/Sails", "Hub", (0, 0, 0.1), 0.35, 0.4, "wood_dark", rot=(math.pi / 2, 0, 0), sides=8)
    for i in range(4):
        a = i * math.pi / 2 + 0.3
        c, sn = math.cos(a), math.sin(a)
        s.box(f"{D}/Sails", f"Arm{i}", (c * 4.4, sn * 4.4, 0), (8.6, 0.22, 0.16), "wood_dark", rot=(0, 0, round(a, 4)))
        s.box(f"{D}/Sails", f"Lattice{i}", (c * 5.2 - sn * 0.65, sn * 5.2 + c * 0.65, -0.05), (6.8, 1.25, 0.04), "sack", rot=(0, 0, round(a, 4)))
        s.box(f"{D}/Sails", f"Spar{i}", (c * 5.2 - sn * 1.28, sn * 5.2 + c * 1.28, 0.0), (6.8, 0.1, 0.1), "wood", rot=(0, 0, round(a, 4)))
    s.light(D, "SailsMoon", (mx - 3.0, 18.0, 3.0), (0.62, 0.68, 0.86), 1.1, 12.0)
    s.box(G, "Balcony", (mx, 13.85, 0), (12.0, 0.3, 2.4), "wood", True)
    s.box(D, "BalconyRail", (mx, 14.9, -1.15), (12.0, 0.08, 0.08), "wood_dark")
    for i, x in enumerate((mx - 5.8, mx + 5.8)):
        s.box(D, f"BalconyBracket{i}", (x, 12.6, -1.6), (0.18, 2.6, 0.18), "wood_dark", rot=(0.5, 0, 0))
    s.ladder("BalconyLadder", 24.6, 6.0, 8.0, -1.0)
    s.ladder_look("Balcony", 24.6, 6.0, 8.0)
    s.note("PassSign", 13.5, 14.0, "Дорожный столб", [
        "«На перевал — по мосту к скале, дальше по старой дороге».",
        "Ниже кто-то нацарапал: «Моста нет. Цепи остались»."])
    # Старый подвесной мост от балкона к скале на западе: там дорога на Подвесной перевал.
    ramp(s, "RopeBridge", -26, 17, 12, 14, "wood", thick=0.25, behind=False)
    a = math.atan2(-3.0, 38.0)
    for i, z in enumerate((-1.1, 1.1)):
        s.box(D, f"BridgeRope{i}", (-7.0, 16.6, z), (38.4, 0.06, 0.06), "rope", rot=(0, 0, round(a, 4)))
    for i in range(5):
        x = -20.0 + i * 7.5
        y = 17.0 + (x + 26.0) * math.tan(a)
        s.box(D, f"BridgeHanger{i}", (x, y + 0.5, -1.1), (0.06, 1.0, 0.06), "rope")
    s.box(D, "BridgePinnacle", (-8.0, 1.0, -3.2), (3.0, 30.0, 3.0), "stone_dark", rot=(0, 0, 0.04))
    land(s, "PassLedge", -62, -26, 17, 15, "stone_dark")
    s.box(D, "Cliff", (-40.0, 8.0, -6.0), (24.0, 30.0, 8.0), "stone_dark")
    # Внизу: водяная мельница, колесо, ручей, плотина и запруда.
    house(s, "MillHouse", -17.0, -4.6, 9, 5.0, 3.0, ground=-6.5, windows=((-2.0, 2.6), (2.2, 2.6)))
    s.light(D, "MillHouseGlow", (-17.0, -3.8, -1.8), (1.0, 0.6, 0.28), 1.3, 8.0)
    # Мельничная клеть под навесом, открыта к дороге: жернова, ковш над ними, мешки муки, лампа.
    s.box(D, "MillRoomBack", (-24.6, -4.3, -3.0), (5.2, 4.4, 0.25), "wood_dark")
    s.roof(D, "MillRoomRoof", (-24.6, -1.4, -2.2), (6.0, 1.4, 2.4), "shingle")
    for i, x in enumerate((-27.0, -22.2)):
        s.box(D, f"MillRoomPost{i}", (x, -4.3, -1.1), (0.25, 4.4, 0.25), "wood_dark")
    s.cyl(D, "MillstoneLow", (-24.8, -6.3, -2.2), 0.95, 0.35, "stone", sides=16)
    s.cyl(D, "MillstoneTop", (-24.8, -5.95, -2.2), 0.9, 0.3, "stone_dark", sides=16)
    s.box(D, "Hopper", (-24.8, -4.9, -2.2), (0.9, 0.8, 0.9), "wood", rot=(0, 0.3, 0))
    for i, (x, z) in enumerate(((-26.4, -2.3), (-26.0, -1.6), (-23.0, -2.4))):
        s.box(D, f"FlourSack{i}", (x, -6.15, z), (0.6, 0.7, 0.45), "sack", rot=(0, 0.2 * i, 0))
    s.box(D, "MillRoomLamp", (-23.3, -3.4, -1.6), (0.22, 0.34, 0.22), "lantern")
    s.light(D, "MillRoomLight", (-24.4, -4.4, -0.6), (1.0, 0.62, 0.3), 1.6, 6.5)
    wr = 3.6
    s.node("Wheel", 'type="Node3D"', D, [f"position = {v3((-10.2, -4.3, -2.4))}", 'script = ExtResource("spinner")', "speed = -0.45"])
    s.cyl(f"{D}/Wheel", "Axle", (0, 0, 0), 0.35, 1.4, "iron", rot=(math.pi / 2, 0, 0), sides=8)
    for i in range(12):
        a = i * math.tau / 12
        s.box(f"{D}/Wheel", f"Spoke{i}", (math.cos(a) * wr / 2, math.sin(a) * wr / 2, 0), (wr, 0.14, 0.14), "wood_dark", rot=(0, 0, round(a, 4)))
        s.box(f"{D}/Wheel", f"Paddle{i}", (math.cos(a) * (wr + 0.35), math.sin(a) * (wr + 0.35), 0), (0.14, 1.0, 1.1), "wood",
              rot=(0, 0, round(a, 4)))
    for side, z in (("Front", 0.5), ("Back", -0.5)):
        for i in range(20):
            a = i * math.tau / 20
            s.box(f"{D}/Wheel", f"Rim{side}{i}", (math.cos(a) * wr, math.sin(a) * wr, z), (math.tau * wr / 20 + 0.08, 0.22, 0.12), "wood_dark",
                  rot=(0, 0, round(a + math.pi / 2, 4)))
    for i, x in enumerate((-12.4, -8.0)):
        s.box(D, f"WheelTrestle{i}", (x, -5.4, -1.5), (0.3, 2.4, 0.3), "wood_dark", rot=(0, 0, 0.25 if i else -0.25))
    s.box(D, "Tailrace", (-10.0, -6.45, -2.6), (9.0, 0.06, 2.0), "water")
    for i, z in enumerate((-3.7, -1.5)):
        s.box(D, f"TailraceEdge{i}", (-10.0, -6.35, z), (9.0, 0.3, 0.25), "stone_dark")
    s.box(D, "Flume", (-13.2, -0.3, -2.4), (6.0, 0.4, 1.0), "wood_dark", rot=(0, 0, -0.04))
    s.box(D, "FlumeWater", (-13.2, -0.08, -2.4), (6.0, 0.04, 0.8), "water", rot=(0, 0, -0.04))
    for i, x in enumerate((-15.5, -11.0)):
        s.box(D, f"FlumePost{i}", (x, -3.5, -2.4), (0.25, 6.0, 0.25), "wood_dark")
    s.veil(D, "WheelSpill", (-10.0, -1.6, -2.2), (1.2, 3.2), "spill")
    s.box(D, "Dam", (-18.0, -2.5, -9.0), (28.0, 8.0, 3.0), "stone")
    for i, y in enumerate((-5.0, -3.4, -1.8, -0.2)):
        s.box(D, f"DamCourse{i}", (-18.0, y, -7.48), (28.0, 0.12, 0.06), "stone_dark")
    s.box(D, "DamWalk", (-18.0, 1.6, -9.0), (28.6, 0.25, 3.4), "wood_dark")
    for i in range(8):
        s.box(D, f"DamRailPost{i}", (-31.0 + i * 3.7, 2.2, -7.6), (0.12, 1.0, 0.12), "wood_dark")
    s.box(D, "DamRail", (-18.0, 2.65, -7.6), (28.0, 0.08, 0.08), "wood_dark")
    # Шлюз: щит в пазах, над ним рама с воротом на верёвке.
    s.box(D, "Sluice", (-24.0, -3.0, -7.45), (2.2, 3.0, 0.2), "wood")
    for i, x in enumerate((-25.3, -22.7)):
        s.box(D, f"SluiceGuide{i}", (x, -1.0, -7.35), (0.3, 6.0, 0.3), "wood_dark")
    s.box(D, "SluiceBeam", (-24.0, 2.1, -7.35), (3.2, 0.3, 0.3), "wood_dark")
    s.cyl(D, "SluiceWinch", (-24.0, 2.55, -7.35), 0.22, 1.6, "wood", rot=(0, 0, math.pi / 2), sides=8)
    s.box(D, "SluiceRope", (-24.0, 0.3, -7.3), (0.05, 3.6, 0.05), "rope")
    s.box(D, "Pond", (-18.0, 1.3, -26.0), (90.0, 0.2, 30.0), "water")
    s.box(D, "PondMoon", (-30.0, 1.42, -22.0), (3.0, 0.02, 14.0), "moonpane")
    for i in range(9):
        s.box(D, f"PondReed{i}", (-30.5 + i * 3.1 + (i % 2) * 0.7, 2.0, -10.8 - (i % 3) * 0.4), (0.06, 1.5 - (i % 3) * 0.3, 0.06), "reed",
              rot=(0, 0, round((i % 3 - 1) * 0.15, 3)))
    s.veil(D, "Spillway", (-12.0, -2.6, -7.3), (2.6, 7.8), "spill")
    s.veil(D, "SpillFoam", (-12.0, -6.0, -6.6), (5.0, 1.4), "fog_veil")
    s.box(D, "PassageBack", (18.0, -4.0, -2.4), (28.0, 5.0, 0.3), "stone_dark")
    s.box(D, "PassageStream", (18.0, -6.45, -1.6), (28.0, 0.05, 0.8), "water")
    s.box(D, "PassageLamp", (21.0, -2.6, -1.6), (0.25, 0.4, 0.25), "lantern")
    s.light(D, "PassageLight", (21.0, -2.9, -0.6), (1.0, 0.6, 0.28), 1.0, 6.0)
    # Осколок у ветряка и вдова мельника.
    s.shard("MirrorShard", 7.0, 6.0)
    s.npc("Widow", 21.5, 6.0, "Вдова мельника", [
        "Мельница стоит. Жернова молчат. Молоть нечего — поле никто не жнёт.",
        "Мужа схоронила по весне. Ветряк он сам ставил, крылья до сих пор крутятся. Будто он там.",
        "Ты с холма пришёл? Не ходи туда. Там столб."],
        (0.18, 0.17, 0.2),
        [f'after_flag = &"{SAW_POST}"', f'told_flag = &"{TALE}"', 'lines_after = PackedStringArray('
         '"Видел столб, значит. Пустой… Слушай тогда.", '
         '"После той ночи, когда зверь рвал деревню, мужики поймали на дороге чужака. Худой, в чужих сапогах. Сказали — он зверя навёл.", '
         '"Привязали к столбу на холме на рассвете. Он не кричал. Только просил воды и всё смотрел на рожь.", '
         '"В полдень над полем встало марево, и рожь легла против ветра. Полудница прошла. Мужики разбежались.", '
         '"К вечеру верёвки висели пустые. А ночью в поле кто-то ходил и считал колосья вслух.", '
         '"Не ходи больше на холм. Если на столбе кто-то есть — это уже не он.")'])
    back(s, "BackValley", -62, 4, -6.5, z1=-7.5, mat="mud", depth=4.0)
    back(s, "BackHill", 4, 62, 6, depth=14.0)
    k = bd.Kit(s)
    k.sky(-32, 32, *SKY_DUSK, glow=SUN_DUSK[0], glow_x=SUN_DUSK[1], glow_y=SUN_DUSK[2], glow_size=SUN_DUSK[3])
    bd.fields(k, -32, 32, DUSK["fog"], ground=-6.5, bridge_x=-70.0)
    s.marker("FromHill", (29.0, 6.1, 0))
    s.marker("FromPatch", (29.0, -6.4, 0))
    s.marker("FromPass", (-29.0, 17.1, 0))
    s.door("DoorToHill", 30.5, 6, "execution_hill", "Spawns/FromMill", "На холм со столбом")
    s.door("DoorToPass", -30.5, 17, "pass_bridge", "Spawns/FromMill", "На перевал")
    s.door("DoorToPatch", 30.5, -6.5, "vegetable_patch", "Spawns/FromMill", "Вдоль ручья, к огородам")
    k.foreground("fields", -32, 32, ground=lambda x: -6.5)
    ground_cover(k, [(-62, 62, -6.5)], [(-32, 32, -6.5), (-6, 4, 0), (4, 32, 6), (12, 24, 14), (-32, -26, 17)], PATH_DUSK)
    save(s)


# ---------------------------------------------------------------- 5. Огороды
def vegetable_patch():
    """Низина под холмом: грядки уступами, тыквы и репа, вырезанные фонари-тыквы — единственный свет;
    соломенные куклы на кольях (позже — враги). Вход в гумно; люк в погреб с сундуком — сундук отравлен (§8.14).
    На востоке ручей выходит из трубы под холмом, на западе течёт к мельнице. Над низиной — холм со столбом."""
    s = new_room("VegetablePatch", "vegetable_patch", -30, 30, DUSK, (0.6, 0.56, 0.66), 0.28)
    land(s, "Ground", -60, 18, 0, -8, "mud")
    land(s, "CellarRoof", 19.4, 60, 0, -1, "mud")
    land(s, "CellarFloor", 18, 60, -4.5, -8, "stone_dark")
    land(s, "Bed1", -12, 10, 1.2, 0, "mud")
    land(s, "Bed2", -6, 4, 2.4, 1.2, "mud")
    s.ladder("CellarLadder", 18.7, -4.5, 4.5, -1.0)
    s.ladder_look("Cellar", 18.7, -4.5, 4.5)
    s.box(D, "CellarLid", (18.0, 0.65, -1.2), (1.4, 0.1, 1.2), "wood", rot=(0.0, 0.0, -1.2))
    s.box(D, "CellarBack", (24.5, -2.75, -2.4), (13.0, 3.5, 0.3), "stone_dark")
    for i, y in enumerate((-3.6, -2.3)):
        s.box(D, f"CellarShelf{i}", (26.0, y, -2.0), (5.0, 0.1, 0.5), "wood")
        for j in range(5):
            s.sphere(D, f"CellarTurnip{i}{j}", (24.0 + j * 0.9, y + 0.17, -2.0), 0.15, "turnip")
    s.candles(D, "CellarCandles", 21.5, -4.5, -1.6)
    # Сундук в погребе отравлен (§8.14): зелёные потёки, дохлая крыса; ударить сначала — зашипит.
    s.chest("CellarChest", (27.5, -4.5, -0.8), 90, "cellar_chest", ("holy_flask", "throwing_axe", "throwing_axe"), poisoned=True)
    # Гумно — фасад за дверью; сарай огородника на западе.
    house(s, "Barn", 13.0, -5.0, 14, 7.0, 4.5)
    s.box(D, "BarnGateGlow", (13.0, 2.0, -2.97), (3.4, 4.0, 0.06), "window")
    for i, dx in enumerate((-0.92, 0.92)):
        s.box(D, f"BarnGateLeaf{i}", (13.0 + dx, 2.0, -2.9), (1.6, 4.0, 0.1), "wood_dark")
    house(s, "Shed", -24.0, -4.4, 5, 3.0, 2.0)
    s.box(D, "ShedRake", (-21.2, 1.0, -2.1), (0.06, 2.0, 0.06), "wood", rot=(0, 0, 0.2))
    # Грядки: тыквы и репа, фонари-тыквы вдоль тропы, соломенные куклы.
    for i, (x, g) in enumerate(((-27.0, 0), (-18.5, 0), (-15.0, 0), (-10.5, 1.2), (-4.5, 2.4), (-1.0, 2.4), (2.6, 2.4),
                                (7.0, 1.2), (22.0, 0), (25.5, 0))):
        pumpkin(s, f"Pumpkin{i}", x, -1.7 - (i % 3) * 0.3, ground=g, r=0.32 + (i % 3) * 0.06)
    for i, (x, g) in enumerate(((-20.0, 0), (-8.0, 1.2), (0.6, 2.4), (8.5, 1.2), (23.5, 0))):
        pumpkin(s, f"Jack{i}", x, -1.0, ground=g, r=0.34, lit=True)
    turnips(s, "Turnip", -5.4, 3.6, -2.6, ground=2.4)
    turnips(s, "TurnipLow", -11.4, -6.4, -2.4, ground=1.2)
    for i, (x, g) in enumerate(((-13.0, 0), (1.0, 2.4), (25.0, 0))):
        scarecrow(s, D, f"StrawDoll{i}", x, g, -2.6, k=0.85)
    # Ручей: выходит из трубы под холмом (восток) и течёт к мельнице (запад).
    s.box(D, "Brook", (0.0, -0.03, -3.4), (120.0, 0.06, 1.4), "water")
    s.box(D, "CulvertArch", (27.5, 1.3, -3.4), (2.6, 0.6, 1.6), "stone")
    for i, x in enumerate((26.4, 28.6)):
        s.box(D, f"CulvertSide{i}", (x, 0.5, -3.4), (0.5, 1.4, 1.6), "stone")
    # Над низиной — холм со столбом (силуэт): туда наверх по тропе от мельницы.
    k = bd.Kit(s)
    k.sky(-30, 30, *SKY_DUSK, glow=SUN_DUSK[0], glow_x=SUN_DUSK[1], glow_y=SUN_DUSK[2], glow_size=SUN_DUSK[3])
    bd.fields(k, -30, 30, DUSK["fog"])
    k.put("Backdrop", "HillMass", "ball", "rye_dark", (-2.0, -6.0, -30.0), (90.0, 40.0, 20.0))
    k.put("Backdrop", "HillPost", "box", "sil", (-3.0, 16.5, -24.0), (0.4, 6.0, 0.4))
    k.put("Backdrop", "HillPostBar", "box", "sil", (-3.0, 18.4, -24.0), (2.6, 0.3, 0.3))
    back(s, "BackPatch", -60, 60, 0, z1=-20.0, mat="mud")
    s.marker("FromCulvert", (27.0, 0.1, 0))
    s.marker("FromMill", (-27.0, 0.1, 0))
    s.marker("FromBarn", (13.0, 0.1, 0))
    s.door("DoorToCulvert", 28.5, 0, "rye_field", "Spawns/FromCulvert", "Через трубу под холмом")
    s.door("DoorToMill", -28.5, 0, "mill", "Spawns/FromPatch", "Вдоль ручья, к мельнице")
    s.door("DoorToBarn", 13.0, 0, "threshing_barn", "Spawns/FromPatch", "Войти в гумно")
    k.foreground("garden", -30, 30)
    ground_cover(k, [(-60, 60, 0)], [(-30, -12, 0), (-12, -6, 1.2), (-6, 4, 2.4), (4, 10, 1.2), (10, 18, 0), (19.4, 30, 0), (18, 30, -4.5)],
                 PATH_DUSK)
    save(s)


# ---------------------------------------------------------------- 6. Гумно
def threshing_barn():
    """Гумно изнутри: глиняный ток, снопы, цепы на стене, закрома; сеновал по лестнице, с него — по балкам
    к полке под крышей с сундуком. Свет — полосами сквозь щели крыши. Книга гумна — про чужака.
    У сундука хозяин поставил самострел от воров (§8.14): одна доска полки светлее — наступил, и из стены бьёт болт."""
    s = new_room("ThreshingBarn", "threshing_barn", -18, 18, BARN, (0.6, 0.55, 0.5), 0.0)
    land(s, "Floor", -19, 19, 0, -2, "clay")
    s.box(D, "WallLeftLook", (-18.5, 4.5, 0), (1.0, 11.0, 4.4), "wood_dark")
    s.box(D, "WallRightLook", (18.5, 4.5, 0), (1.0, 11.0, 4.4), "wood_dark")
    s.box(G, "Ceiling", (0, 10.0, 0), (38.0, 1.0, 4.4), "wood_dark", True)
    s.box(D, "BackWall", (0, 4.5, -2.4), (36.0, 9.0, 0.3), "wood")
    for i, x in enumerate((-12.0, -4.0, 4.0, 12.0)):
        s.box(D, f"Post{i}", (x, 4.5, -2.1), (0.4, 9.0, 0.4), "wood_dark")
    # Сеновал, балки и полка под крышей.
    s.box(G, "Loft", (-11.5, 4.0, 0), (13.0, 0.4, 2.4), "wood", True)
    s.ladder("LoftLadder", -4.4, 0.0, 4.2, -1.0)
    s.ladder_look("Loft", -4.4, 0.0, 4.2)
    s.box(G, "Beam1", (-0.8, 4.82, 0), (2.4, 0.35, 0.5), "wood_dark", True)
    s.box(G, "Beam2", (4.8, 5.42, 0), (2.4, 0.35, 0.5), "wood_dark", True)
    s.box(G, "Shelf", (13.5, 5.0, 0), (9.0, 0.4, 2.4), "wood", True)
    for i, (x, y) in enumerate(((-16.0, 4.75), (-14.6, 4.75), (-15.3, 5.35), (-11.5, 4.75), (-8.0, 4.75))):
        s.box(D, f"LoftBale{i}", (x, y, -1.0), (1.3, 0.6, 0.8), "straw", rot=(0, 0.1 * (i % 3 - 1), 0))
    s.chest("ShelfChest", (15.5, 5.2, -0.6), 120, "barn_chest", ("tempered_glass",))
    # Самострел от воров: доска-плита на полке, болт из восточной стены — вдоль полки, на уровне груди.
    s.arrow_launcher("Crossbow", (17.95, 5.2, 0.0), -1, heights=(0.95,), damage=28.0, face_color=(0.16, 0.12, 0.09))
    s.trap_plate("LoosePlank", (11.2, 5.2, 0.0), ["Crossbow"], width=1.0, depth=2.0, color=(0.36, 0.27, 0.17))
    # Ток: снопы, цепы, закрома, веялка.
    for i, (x, z) in enumerate(((-15.0, -1.4), (-13.8, -1.6), (-9.0, -1.5), (6.5, -1.6), (8.0, -1.3))):
        stook(s, f"Sheaf{i}", x, z, h=1.5)
    for i, x in enumerate((-1.0, 0.0, 1.0)):
        s.box(D, f"FlailHandle{i}", (x, 3.2, -2.15), (0.06, 1.6, 0.06), "wood", rot=(0, 0, 0.15))
        s.box(D, f"FlailBeater{i}", (x + 0.25, 2.2, -2.15), (0.08, 0.7, 0.08), "wood_dark", rot=(0, 0, -0.25))
    for i, x in enumerate((10.0, 12.4)):
        s.box(D, f"GrainBin{i}", (x, 0.7, -1.6), (2.2, 1.4, 1.0), "wood_dark")
    s.cyl(D, "Winnow", (3.0, 0.15, -1.0), 0.55, 0.12, "straw", sides=10)
    # Свет сквозь щели крыши, фонарь у двери.
    for i, x in enumerate((-8.0, 2.0, 10.0)):
        s.box(D, f"RoofSlit{i}", (x, 9.45, -0.6), (0.5, 0.06, 1.4), "moonpane")
        s.veil(D, f"Shaft{i}", (x - 0.6, 5.0, -1.2), (1.2, 9.0), "dust_veil")
    s.box(D, "DoorLamp", (14.0, 2.6, -2.0), (0.25, 0.4, 0.25), "lantern")
    s.light(D, "DoorLampLight", (14.0, 2.4, -0.8), (1.0, 0.6, 0.28), 1.2, 8.0)
    s.light(D, "LoftGlow", (-11.0, 6.4, 0.6), (0.9, 0.7, 0.45), 0.8, 8.0)
    s.box(D, "BeamLampChain", (2.0, 8.6, -0.8), (0.04, 1.6, 0.04), "iron")
    s.box(D, "BeamLamp", (2.0, 7.6, -0.8), (0.3, 0.45, 0.3), "lantern")
    s.light(D, "BeamLampLight", (2.0, 7.2, 0.4), (1.0, 0.62, 0.3), 1.5, 11.0)
    s.note("BarnBook", -1.5, 0.0, "Книга гумна", [
        "«…ржи сжато две полосы, третья полегла. Жать некому: днём в поле не идут».",
        "«Ночью в гумне спал чужой. Утром ушёл в сторону холма. Солому за собой не убрал».",
        "Последняя строчка другой рукой: «Не жгите столб. Он ещё не досчитал»."])
    s.marker("FromPatch", (15.0, 0.1, 0))
    s.door("DoorOut", 16.5, 0, "vegetable_patch", "Spawns/FromBarn", "Выйти на огороды")
    save(s)


if __name__ == "__main__":
    farmyard()
    rye_field()
    execution_hill()
    mill()
    vegetable_patch()
    threshing_barn()
    print("ok")
