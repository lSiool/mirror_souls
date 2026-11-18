"""Катакомбы кладбища (§8.13): под запечатанным склепом на нижней дорожке кладбища.

Первый шаг области (2026-11-18), четыре комнаты graybox без врагов:
катакомбы → оссуарий (осколок) → квартал могильщика → колокольня мёртвых. Дальше (позже): затопленные склепы
и склеп Сгнившего святого — за решёткой на дне оссуария; холм Дерева мёртвых — за дверью на верху колокольни.

Тьма — главное испытание: окружения почти нет, светит только то, что зажёг герой. Свечи в нишах (WallCandle)
зажигаются только фонарём фонарщика; фонарь лежит в конце катакомб — до него путь во тьме, назад — со свечами.
Зажжённая свеча горит и после смерти (флаг в сейве), путь светлеет, как открытые срезки.

Высоты (ноль каждой комнаты; на карте — WorldMap.ROOMS): катакомбы и верх оссуария — на 16 м ниже кладбища,
дно оссуария, квартал и низ колокольни — ещё на 14 м ниже; колокольня поднимается почти до поверхности.
Места под будущих врагов: груды костей оссуария (Decor/AmbushSpots), могилы квартала, верх колокольни.
Запуск из корня проекта: python tools/levels/build_graveyard.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from scenery import Scene, v3  # noqa: E402
import backdrop as bd  # noqa: E402

G, D, O = "Geometry", "Decor", "Objects"

## Тьма подземелья: окружение почти погашено, туман чёрный — видно только освещённое.
DARK = {"bg": (0.0, 0.0, 0.0), "amb": (0.32, 0.34, 0.42), "amb_e": 0.07, "fog": (0.01, 0.01, 0.014), "fog_d": 0.03}
## Колокольня: сверху сквозь щели и звонницу — ночь, чуть светлее.
BELFRY = {"bg": (0.0, 0.0, 0.0), "amb": (0.34, 0.38, 0.48), "amb_e": 0.09, "fog": (0.02, 0.022, 0.03), "fog_d": 0.02}
MOON = (0.5, 0.6, 0.8)
SKY_NIGHT = ((0.01, 0.012, 0.02), (0.07, 0.08, 0.11))
## Ниши с костями в стенах — по рядам.
LOCULUS = (0.9, 0.5)


def save(scene):
    Path(f"world/rooms/{scene.room_id}.tscn").write_text(scene.text(), encoding="utf-8")


def new_room(name, room_id, left, right, env=DARK, sun_energy=0.0):
    s = Scene(name, room_id, right - left, env, (0.5, 0.55, 0.7), sun_energy)
    s.use("candle", "Script", "res://world/common/wall_candle.gd")
    s.use("sayline", "Script", "res://world/common/say_line.gd")
    s.wall("WallLeft", (left - 0.5, 10.0, 0), (1, 60, 4.4))
    s.wall("WallRight", (right + 0.5, 10.0, 0), (1, 60, 4.4))
    return s


# ---------------------------------------------------------------- помощники
def land(s, name, x0, x1, top, bottom, mat="stone_dark"):
    """Камень в плоскости героя: с коллизией, от bottom до top."""
    s.box(G, name, ((x0 + x1) / 2, (top + bottom) / 2, 0), (x1 - x0, top - bottom, 4.4), mat, True)


def ramp(s, name, x0, y0, x1, y1, mat="stone", thick=1.6):
    """Склон или лестница в плоскости героя: верх от (x0, y0) к (x1, y1), x0 < x1."""
    a = math.atan2(y1 - y0, x1 - x0)
    ln = math.hypot(x1 - x0, y1 - y0) + 0.1
    cx, cy = (x0 + x1) / 2 + math.sin(a) * thick / 2, (y0 + y1) / 2 - math.cos(a) * thick / 2
    s.box(G, name, (cx, cy, 0), (ln, thick, 4.4), mat, True, rot=(0, 0, round(a, 4)))


def back_wall(s, name, x0, x1, y0, y1, mat="stone_dark", z=-2.4):
    s.box(D, name, ((x0 + x1) / 2, (y0 + y1) / 2, z), (x1 - x0, y1 - y0, 0.4), mat)


def loculi(s, name, x0, x1, y, rows=3, z=-2.18):
    """Ниши-локулы в стене: ряды тёмных проёмов, в некоторых — череп и кости."""
    n = int((x1 - x0) / (LOCULUS[0] + 0.35))
    for r in range(rows):
        for i in range(n):
            x = round(x0 + 0.5 + i * (LOCULUS[0] + 0.35) + (r % 2) * 0.2, 2)
            yy = round(y + r * (LOCULUS[1] + 0.3), 2)
            s.box(D, f"{name}{r}_{i}", (x, yy, z), (LOCULUS[0], LOCULUS[1], 0.06), "char")
            if (i * 7 + r * 3) % 5 == 0:
                s.sphere(D, f"{name}Skull{r}_{i}", (x - 0.15, yy - 0.08, z + 0.12), 0.14, "bone")
            elif (i * 5 + r) % 4 == 0:
                s.box(D, f"{name}Bone{r}_{i}", (x, yy - 0.16, z + 0.1), (0.6, 0.07, 0.07), "bone", rot=(0, 0, 0.12))


def bone_heap(s, name, x, y, z, w=2.4, h=1.0):
    """Груда костей: черепа и длинные кости. В грудах оссуария будут прятаться враги."""
    s.node(name, 'type="Node3D"', D, [f"position = {v3((x, y, z))}"])
    p = f"{D}/{name}"
    s.cyl(p, "Mound", (0, h * 0.4, 0), w * 0.5, h * 0.8, "bone", sides=9, cone=True)
    for i in range(7):
        a = i * 2.39996
        dx, dz = math.cos(a) * w * 0.32, math.sin(a) * 0.35
        s.sphere(p, f"Skull{i}", (round(dx, 3), round(h * 0.25 + (i % 3) * 0.12, 3), round(dz + 0.3, 3)), 0.13, "bone")
        s.box(p, f"Long{i}", (round(dx * 0.8, 3), round(h * 0.2, 3), round(dz, 3)), (0.7, 0.07, 0.07), "bone",
              rot=(0, round(a, 3), round((i % 3 - 1) * 0.4, 3)))


def candle(s, name, x, y, count=3, energy=1.6, rng=7.0):
    """Свеча в нише (WallCandle) над полом y: зажигается только фонарём, флаг — candle_<комната>_<имя>.
    Узел — на полу в плоскости героя (зона взаимодействия), полка со свечами — в нише стены."""
    s.box(D, f"{name}Niche", (x, y + 1.6, -2.18), (0.9, 0.9, 0.06), "char")
    s.node(name, 'type="Area3D"', O, [f"position = {v3((x, y, 0))}", 'script = ExtResource("candle")',
                                      f'flag = &"candle_{s.room_id}_{name}"', f"light_energy = {energy}", f"light_range = {rng}",
                                      f"count = {count}"])


def say(s, name, x, y, text, size=(4, 3, 4), flag=None):
    props = [f"position = {v3((x, y, 0))}", 'script = ExtResource("sayline")', f'text = "{text}"', f"size = {v3(size)}"]
    if flag:
        props.append(f'sets_flag = &"{flag}"')
    s.node(name, 'type="Area3D"', O, props)


def moon_shaft(s, name, x, y_top, y_bottom, energy=0.7, rng=10.0):
    """Лунный свет сквозь решётку сверху: холодный столб — единственный ориентир во тьме."""
    s.box(D, f"{name}Grate", (x, y_top, 0.0), (1.4, 0.08, 1.4), "moonpane")
    for i in range(4):
        s.box(D, f"{name}Bar{i}", (x - 0.5 + i * 0.33, y_top - 0.06, 0.0), (0.06, 0.08, 1.5), "iron")
    s.veil(D, f"{name}Beam", (x, (y_top + y_bottom) / 2, -0.6), (1.6, y_top - y_bottom), "fog_veil")
    s.light(D, f"{name}Light", (x, y_bottom + 2.5, 0.8), MOON, energy, rng)


def coffin(s, parent, name, x, y, z, tilt=0.0, open_lid=False, collide=False):
    s.box(parent, name, (x, y + 0.3, z), (1.9, 0.6, 0.7), "wood_dark", collide, rot=(0, 0, tilt) if tilt else None)
    if open_lid:
        s.box(D, f"{name}Lid", (x + 0.4, y + 0.75, z - 0.35), (1.9, 0.08, 0.7), "wood", rot=(0.9, 0, 0.2))


def ladder(s, name, x, y, h, exit_dir, mat="wood_dark"):
    s.ladder(name, x, y, h, exit_dir)
    s.ladder_look(name, x, y, h, mat)


def platform(s, name, x0, x1, y, mat="wood", thick=0.5, posts=True):
    """Настил на балках в плоскости героя; posts — опоры до пола под ним не ставим (воздух под настилом)."""
    s.box(G, name, ((x0 + x1) / 2, y - thick / 2, 0), (x1 - x0, thick, 3.0), mat, True)
    if posts:
        for i, x in enumerate((x0 + 0.3, x1 - 0.3)):
            s.box(D, f"{name}Brace{i}", (x, y - 1.0, -1.5), (0.2, 2.0, 0.2), "wood_dark", rot=(0.5, 0, 0))


# ---------------------------------------------------------------- 1. Катакомбы
def catacombs():
    """Из склепа кладбища — лестница вниз, в зал с решёткой (луна — единственный свет), дальше коридор во тьме:
    ниши-локулы с костями, свечи в нишах (без огня их не зажечь), провал в полу — нижняя крипта с сундуком,
    лестница из неё наверх, возвышение с саркофагами. В конце у стены сидит мёртвый фонарщик: его фонарь —
    находка области. Назад — уже со светом, зажигая свечи. Справа — дверь в оссуарий."""
    s = new_room("Catacombs", "catacombs", -32, 32)
    # Лестница из склепа: площадка на +6, ступени вниз к коридору.
    land(s, "Landing", -36, -25, 6, -8)
    ramp(s, "Stairs", -25, 6, -15, 0, "stone", thick=6.0)
    land(s, "FloorWest", -25, 4, 0, -8)
    # Провал в полу 4 м: прыжком перемахнуть можно, пешком во тьме — упадёшь (за край уже не зацепиться).
    # Внизу крипта с сундуком, лестница на восточной стене провала.
    land(s, "CryptFloor", 4, 15, -4.5, -8)
    land(s, "FloorSlab", 8, 15, 0, -1.5)
    land(s, "FloorEast", 15, 36, 0, -8)
    land(s, "Dais", 12, 20, 1.0, 0)
    ladder(s, "CryptLadder", 7.4, -4.5, 4.5, 1.0)
    # Потолки: высокий зал лестницы, низкий коридор, свод над саркофагами.
    s.box(G, "CeilingHall", (-25.5, 11.5, 0), (21.0, 4.0, 4.4), "stone_dark", True)
    s.box(G, "CeilingWest", (-2.5, 6.6, 0), (25.0, 4.0, 4.4), "stone_dark", True)
    s.box(G, "CeilingVault", (16.0, 9.5, 0), (12.0, 4.0, 4.4), "stone_dark", True)
    s.box(G, "CeilingEast", (29.0, 6.6, 0), (14.0, 4.0, 4.4), "stone_dark", True)
    s.box(D, "VaultStepA", (10.6, 5.2, -0.4), (0.8, 1.6, 4.0), "stone")
    s.box(D, "VaultStepB", (21.4, 5.2, -0.4), (0.8, 1.6, 4.0), "stone")
    # Стены и ниши.
    back_wall(s, "HallWall", -36, -15, 0, 10)
    back_wall(s, "CorridorWall", -15, 36, -8, 8)
    loculi(s, "HallLoc", -24.5, -16.0, 6.6, rows=2)
    loculi(s, "WestLoc", -14.0, 3.5, 1.0)
    loculi(s, "EastLoc", 22.5, 31.5, 1.0)
    loculi(s, "VaultLoc", 12.0, 20.0, 2.4, rows=3)
    loculi(s, "CryptLoc", 7.0, 14.5, -4.0, rows=2)
    for i, x in enumerate((-15.0, -6.0, 3.0, 22.0, 30.0)):
        s.box(D, f"Rib{i}", (x, 2.3, -1.9), (0.5, 4.6, 0.6), "stone")
    # Решётка в своде зала: лунный столб над лестницей.
    moon_shaft(s, "Moon", -20.0, 9.5, 2.5, 0.8, 11.0)
    # Возвышение с саркофагами и крипта под провалом.
    for i, x in enumerate((13.5, 17.0)):
        s.box(D, f"Sarcophagus{i}", (x, 1.45, -1.3), (2.4, 0.9, 1.0), "stone")
        s.box(D, f"SarcophagusLid{i}", (x + 0.1, 1.95, -1.3), (2.5, 0.12, 1.1), "statue", rot=(0, 0.05 * (1 - 2 * i), 0.04))
    s.box(D, "PitRim", (6.0, -0.05, -1.6), (4.0, 0.1, 0.4), "stone")
    coffin(s, D, "CryptCoffinA", 9.5, -4.5, -1.3, open_lid=True)
    coffin(s, D, "CryptCoffinB", 11.8, -4.5, -1.4, tilt=0.05)
    bone_heap(s, "CryptBones", 5.6, -4.5, -1.2, w=1.8, h=0.6)
    s.chest("CryptChest", (13.6, -4.5, -0.8), 140, "catacombs_chest", ("holy_flask", "holy_flask"))
    # Мёртвый фонарщик у стены и его фонарь.
    lx = 27.0
    s.box(D, "LamplighterTorso", (lx, 0.55, -1.6), (0.45, 0.7, 0.3), "bone", rot=(0, 0, 0.2))
    s.sphere(D, "LamplighterSkull", (lx + 0.05, 1.08, -1.5), 0.16, "bone")
    s.box(D, "LamplighterLegs", (lx + 0.55, 0.12, -1.4), (0.9, 0.16, 0.36), "bone")
    s.box(D, "LamplighterCloak", (lx - 0.1, 0.5, -1.78), (0.8, 1.0, 0.1), "cloth", rot=(0, 0, 0.2))
    s.box(D, "LamplighterPole", (lx - 0.5, 1.2, -1.75), (0.06, 2.4, 0.06), "wood", rot=(0, 0, -0.25))
    s.node("Lantern", 'type="Area3D"', O, [f"position = {v3((lx + 1.0, 0.0, 0))}", 'script = ExtResource("pickup")',
                                           'item_id = &"lantern"', 'flag = &"lantern_found"', 'pickup_prompt = "Взять фонарь"',
                                           "look_size = Vector3(0.2, 0.3, 0.2)", "look_color = Color(0.9, 0.6, 0.25, 1)",
                                           "look_rotation = Vector3(0, 0, 0)",
                                           'pickup_line = "«Фонарь фонарщика. Масла ещё хватит, чтобы зажечь его свечи»."'])
    s.note("LamplighterNote", lx - 1.6, 0.0, "Записи фонарщика", [
        "«Свечи гаснут сами. Я хожу и зажигаю их снова — и так каждую ночь».",
        "«Внизу опять звонили. Колокол мёртвых не звонил сорок лет».",
        "«Масла осталось на одну ночь. Дальше пойду без света»."])
    say(s, "DarkLine", -12.0, 0.0, "«Темно, хоть глаз выколи. В нишах свечи — но зажечь их нечем».", size=(4, 3, 4))
    # Свечи: зажигаются только фонарём (он — в конце коридора).
    for name, x, y in (("CandleLanding", -28.0, 6.0), ("CandleWest", -11.0, 0.0), ("CandleMid", -3.0, 0.0),
                       ("CandlePit", 2.0, 0.0), ("CandleCrypt", 10.6, -4.5), ("CandleDais", 16.0, 1.0),
                       ("CandleEast", 24.0, 0.0), ("CandleLamplighter", 29.0, 0.0)):
        candle(s, name, x, y)
    s.marker("FromCemetery", (-29.0, 6.1, 0))
    s.marker("FromOssuary", (29.0, 0.1, 0))
    s.door("DoorToCemetery", -30.5, 6, "cemetery", "Spawns/FromCrypt", "Наверх, на кладбище")
    s.door("DoorToOssuary", 30.5, 0, "ossuary", "Spawns/FromCatacombs", "В оссуарий")
    save(s)


# ---------------------------------------------------------------- 2. Оссуарий
def ossuary():
    """Костница: три яруса в стенах из черепов. Наверху — вход из катакомб и осколок; ниже — ярус с грудами костей
    (в них будут засады), на дне — выход в квартал могильщика и решётка, за которой стоит вода (затопленные
    склепы — позже). Между ярусами лестницы; вниз можно и спрыгнуть (7 м)."""
    s = new_room("Ossuary", "ossuary", -20, 20)
    land(s, "TierA", -24, -2, 0, -1.5)
    land(s, "TierB", -10, 24, -7, -8.5)
    land(s, "Bottom", -24, 24, -14, -18)
    ladder(s, "LadderA", -1.4, -7.0, 7.0, -1.0, "bone")
    ladder(s, "LadderB", -10.6, -14.0, 7.0, 1.0, "bone")
    s.box(G, "Vault", (0.0, 10.0, 0), (48.0, 4.0, 4.4), "stone_dark", True)
    # Опоры ярусов — столбы из костей.
    for i, (x, y0, y1) in enumerate(((-16.0, -14.0, -1.5), (-6.0, -7.0, -1.5), (4.0, -14.0, -8.5), (14.0, -14.0, -8.5))):
        s.box(D, f"Pillar{i}", (x, (y0 + y1) / 2, -1.4), (0.8, y1 - y0, 0.8), "bone")
        for j in range(int((y1 - y0) / 0.6)):
            s.sphere(D, f"Pillar{i}Skull{j}", (x, y0 + 0.3 + j * 0.6, -0.95), 0.14, "bone")
    # Стены из черепов.
    back_wall(s, "Wall", -24, 24, -14, 8, "earth_dark")
    for r in range(11):
        y = -13.4 + r * 2.0
        for i in range(10):
            x = round(-19.0 + i * 4.0 + (r % 2) * 2.0, 2)
            s.sphere(D, f"Skull{r}_{i}", (x, round(y, 2), -2.1), 0.2, "bone")
        s.box(D, f"Femurs{r}", (0.0, round(y - 0.5, 2), -2.15), (40.0, 0.12, 0.12), "bone")
    # Люстра из костей посреди зала — без огня.
    s.box(D, "ChandelierChain", (2.0, 6.4, -0.6), (0.05, 3.2, 0.05), "iron")
    s.cyl(D, "ChandelierRing", (2.0, 4.8, -0.6), 1.3, 0.12, "bone", sides=12)
    for i in range(8):
        a = i * math.tau / 8
        s.sphere(D, f"ChandelierSkull{i}", (round(2.0 + math.cos(a) * 1.3, 3), 4.6, round(-0.6 + math.sin(a) * 1.3, 3)), 0.14, "bone")
    # Груды костей — места засад.
    s.node("AmbushSpots", 'type="Node3D"', D, [])
    for i, (x, y) in enumerate(((3.0, -7.0), (12.0, -7.0), (-4.0, -14.0), (9.0, -14.0))):
        bone_heap(s, f"Heap{i}", x, y, -0.8, w=2.6, h=1.1)
        s.node(f"Ambush{i}", 'type="Marker3D"', f"{D}/AmbushSpots", [f"position = {v3((x, y + 0.1, 0))}"])
    # Решётка на дне: за ней вода — путь в затопленные склепы (позже).
    for i in range(7):
        s.box(D, f"GrateBar{i}", (17.6 + i * 0.4, -11.5, -1.4), (0.08, 5.0, 0.08), "iron")
    s.box(D, "GrateTop", (18.8, -9.0, -1.4), (3.0, 0.15, 0.15), "iron")
    s.box(D, "GrateWater", (19.0, -13.3, -2.0), (4.0, 1.4, 0.1), "water")
    s.light(D, "GrateGlow", (19.0, -12.0, -1.8), (0.4, 0.55, 0.6), 0.5, 4.0)
    say(s, "GrateLine", 18.5, -14.0, "«За решёткой стоит чёрная вода. Где-то в глубине она то поднимается, то опускается».",
        size=(4, 3, 4))
    s.shard("MirrorShard", -12.0, 0.0)
    for name, x, y in (("CandleEntry", -15.5, 0.0), ("CandleLadderA", -4.5, 0.0), ("CandleTierB", 7.5, -7.0),
                       ("CandleTierBEast", 18.0, -7.0), ("CandleBottomWest", -15.0, -14.0), ("CandleBottom", 3.0, -14.0),
                       ("CandleGrate", 14.0, -14.0)):
        candle(s, name, x, y)
    s.marker("FromCatacombs", (-17.5, 0.1, 0))
    s.marker("FromQuarter", (-17.5, -13.9, 0))
    s.door("DoorToCatacombs", -18.5, 0, "catacombs", "Spawns/FromOssuary", "Назад, в катакомбы")
    s.door("DoorToQuarter", -18.5, -14, "gravedigger_quarter", "Spawns/FromOssuary", "В квартал могильщика")
    save(s)


# ---------------------------------------------------------------- 3. Квартал могильщика
def gravedigger_quarter():
    """Пещера под кладбищем, где жили и работали могильщики: хибары у стены, телеги с гробами, ворот над шахтой,
    по которой с кладбища спускали гробы (сверху — лунный свет). В полу — открытые могилы: в них падаешь
    и выбираешься (в большинстве — гроб, на него можно встать); братская могила глубже — из неё по лестнице.
    Наверху помост с сундуком могильщика. Слева — дверь в колокольню мёртвых."""
    s = new_room("GravediggerQuarter", "gravedigger_quarter", -32, 32)
    graves = ((22.0, True), (15.0, False), (5.0, True), (-17.0, False), (-23.0, True))
    edges = sorted([g[0] - 1.1 for g in graves] + [g[0] + 1.1 for g in graves] + [-8.0, -4.0])
    # Пол кусками между ямами; ямы могил — 2 м, братская могила — 6 м.
    xs = [-36.0] + edges + [36.0]
    for i in range(0, len(xs), 2):
        land(s, f"Floor{i // 2}", xs[i], xs[i + 1], 0, -8, "earth_dark")
    for i, (x, has_coffin) in enumerate(graves):
        land(s, f"Grave{i}Bottom", x - 1.1, x + 1.1, -2.0, -8, "earth_dark")
        if has_coffin:
            coffin(s, G, f"Grave{i}Coffin", x, -2.0, 0, collide=True)
        s.box(D, f"Grave{i}Mound", (x + 1.9, 0.25, -1.2), (1.4, 0.5, 1.0), "earth_dark", rot=(0, 0, -0.25))
        s.grave(D, f"Grave{i}Cross", x - 1.6, -1.6, cross=True, tilt=(i % 3 - 1) * 0.1)
        s.box(D, f"Grave{i}Shovel", (x + 1.4, 0.75, -0.9), (0.06, 1.5, 0.06), "wood", rot=(0, 0, -0.3))
    land(s, "MassGraveBottom", -8.0, -4.0, -6.0, -8, "earth_dark")
    bone_heap(s, "MassGraveBones", -6.0, -6.0, -0.6, w=3.4, h=0.9)
    ladder(s, "MassGraveLadder", -7.4, -6.0, 6.0, -1.0)
    s.box(G, "Ceiling", (0.0, 11.0, 0), (72.0, 4.0, 4.4), "stone_dark", True)
    back_wall(s, "Wall", -36, 36, -8, 9, "earth_dark")
    # Хибары могильщиков у стены, телеги, кресты.
    for i, (x, w) in enumerate(((-12.0, 6.0), (6.0, 5.0), (27.0, 5.0))):
        s.box(D, f"Shack{i}", (x, 1.8, -1.9), (w, 3.6, 0.8), "wood_dark")
        s.roof(D, f"Shack{i}Roof", (x, 4.2, -1.9), (w + 0.8, 1.2, 1.4), "shingle")
        s.box(D, f"Shack{i}Door", (x - w * 0.25, 1.1, -1.48), (0.9, 2.0, 0.06), "char")
        s.box(D, f"Shack{i}Window", (x + w * 0.2, 2.2, -1.48), (0.7, 0.6, 0.06), "char")
    s.box(D, "Cart", (-1.0, 0.7, -1.2), (2.6, 0.6, 1.2), "wood")
    for i, x in enumerate((-2.0, 0.0)):
        s.cyl(D, f"CartWheel{i}", (x, 0.45, -0.55), 0.45, 0.1, "wood_dark", rot=(math.pi / 2, 0, 0), sides=12)
    coffin(s, D, "CartCoffin", -1.0, 1.0, -1.2, tilt=0.04)
    for i, x in enumerate((-29.0, -27.5, 9.0, 11.0)):
        s.grave(D, f"OldCross{i}", x, -1.8, tilt=(i % 3 - 1) * 0.15, cross=i % 2 == 0)
    # Помост у шахты: ворот, по которому спускали гробы; лунный свет из шахты.
    platform(s, "Walkway", 12.0, 25.0, 4.5)
    ladder(s, "WalkwayLadder", 11.4, 0.0, 4.5, 1.0)
    s.box(D, "Winch", (18.5, 5.3, -0.8), (1.6, 0.5, 0.5), "wood_dark")
    s.box(D, "WinchRope", (18.5, 7.6, -0.8), (0.05, 4.4, 0.05), "rope")
    coffin(s, D, "HoistCoffin", 18.0, 5.6, -0.6, tilt=0.1)
    moon_shaft(s, "Shaft", 18.5, 9.0, 4.5, 0.8, 11.0)
    s.chest("DiggerChest", (23.5, 4.5, -0.6), 180, "quarter_chest", ("throwing_knife",) * 4 + ("tempered_glass",))
    s.note("BurialBook", 3.0, 0.0, "Книга могильщика", [
        "«Схоронено за неделю: девять. Трое — без отпевания: святой отец не спускается».",
        "«Колокол опять звонил сам. После него в братской яме кто-то шевелится. Засыпали известью».",
        "«Святого похоронили в нижнем склепе, как он просил. Вода туда пришла на третий день»."])
    for name, x, y in (("CandleEast", 28.5, 0.0), ("CandleWalkway", 21.0, 4.5), ("CandleShack", 8.6, 0.0),
                       ("CandleCart", -2.5, 0.0), ("CandleMassGrave", -10.5, 0.0), ("CandleWest", -27.0, 0.0)):
        candle(s, name, x, y)
    s.marker("FromOssuary", (29.0, 0.1, 0))
    s.marker("FromBellTower", (-29.0, 0.1, 0))
    s.door("DoorToOssuary", 30.5, 0, "ossuary", "Spawns/FromQuarter", "Назад, в оссуарий")
    s.door("DoorToBellTower", -30.5, 0, "bell_tower", "Spawns/FromQuarter", "В колокольню мёртвых")
    save(s)


# ---------------------------------------------------------------- 4. Колокольня мёртвых
def bell_tower():
    """Колокольня, вросшая в землю: подъём по лестницам с яруса на ярус. Чем выше, тем больше лунного света
    сквозь щели. Наверху звонница под ночным небом: колокол мёртвых, язык обмотан тряпьём (позже звон
    поднимает мёртвых), дверь наружу заперта снаружи — дорога к холму Дерева мёртвых (позже)."""
    s = new_room("BellTower", "bell_tower", -12, 12, BELFRY)
    land(s, "Floor", -16, 16, 0, -6)
    # Ярусы чередуются; лестница стоит на нижнем ярусе у края верхнего.
    tiers = ((1, -2.0, 12.0, 5.0), (2, -12.0, 6.0, 10.0), (3, -6.0, 12.0, 15.0), (4, -12.0, 6.0, 20.0), (5, -6.0, 12.0, 25.0))
    for n, x0, x1, y in tiers:
        platform(s, f"Tier{n}", x0, x1, y, "stone", posts=False)
    ladder(s, "Ladder1", -2.6, 0.0, 5.0, 1.0)
    ladder(s, "Ladder2", 6.6, 5.0, 5.0, -1.0)
    ladder(s, "Ladder3", -6.6, 10.0, 5.0, 1.0)
    ladder(s, "Ladder4", 6.6, 15.0, 5.0, -1.0)
    ladder(s, "Ladder5", -6.6, 20.0, 5.0, 1.0)
    s.box(G, "Roof", (0.0, 32.0, 0), (32.0, 4.0, 4.4), "stone_dark", True)
    s.roof(D, "Spire", (0.0, 36.0, -1.0), (26.0, 6.0, 3.0), "shingle")
    # Стены башни: низ — глухой камень (и земля вокруг), наверху — звонница с арками на ночное небо.
    back_wall(s, "Wall", -40, 40, -6, 24)
    for i, x in enumerate((-13.0, 13.0)):
        s.box(D, f"TowerSide{i}", (x, 12.0, 0.0), (1.0, 36.0, 4.4), "stone_dark")
    for i, x in enumerate((-14.0, -4.0, 4.0, 14.0)):
        s.box(D, f"BelfryPier{i}", (x, 27.5, -2.4), (2.0, 7.0, 0.6), "stone_dark")
    s.box(D, "BelfryLintel", (0.0, 30.5, -2.4), (32.0, 1.0, 0.6), "stone_dark")
    k = bd.Kit(s)
    k.sky(-12, 12, *SKY_NIGHT, glow=(0.6, 0.68, 0.85, 0.18), glow_x=0.62, glow_y=0.3, glow_size=0.035)
    for i, (x, y) in enumerate(((-9.0, 8.0), (9.0, 13.0), (-9.0, 18.0), (9.0, 22.5))):
        s.box(D, f"Slit{i}", (x, y, -2.18), (0.3, 1.6, 0.06), "moonpane")
        s.light(D, f"SlitLight{i}", (x, y - 0.6, -1.2), MOON, 0.25 + 0.1 * i, 6.0)
    s.light(D, "BelfryMoon", (2.0, 29.0, 1.5), MOON, 0.9, 14.0)
    # Колокол мёртвых и верёвка до самого низа.
    bx = 2.0
    s.cyl(D, "BellBeam", (bx, 30.0, -0.8), 0.18, 8.0, "wood_dark", rot=(0, 0, math.pi / 2), sides=6)
    s.cyl(D, "Bell", (bx, 28.4, -0.8), 1.2, 2.2, "rust", sides=14, cone=True)
    s.cyl(D, "BellLip", (bx, 27.35, -0.8), 1.25, 0.2, "rust", sides=14)
    s.box(D, "BellClapperRag", (bx, 27.6, -0.8), (0.35, 0.6, 0.35), "cloth")
    s.box(D, "BellRope", (bx + 0.9, 13.7, -1.2), (0.05, 27.0, 0.05), "rope")
    s.note("BellNote", bx, 25.0, "Колокол мёртвых", [
        "Язык колокола обмотан тряпьём и перевязан цепью.",
        "На ободе выбито: «Звоню — и встают. Молчу — и спят»."])
    # Дверь наружу — к холму Дерева мёртвых (позже): заперта снаружи.
    s.box(D, "HillDoor", (11.2, 26.2, -1.2), (1.4, 2.4, 0.2), "wood_dark")
    s.box(D, "HillDoorBand", (11.2, 26.6, -1.08), (1.4, 0.12, 0.05), "iron")
    say(s, "HillDoorLine", 10.0, 25.0, "«Дверь наружу. Засов снаружи — не поддаётся. Оттуда тянет сырой землёй и ветром».",
        size=(3, 3, 4))
    for name, x, y in (("Candle0", -8.0, 0.0), ("Candle1", 9.0, 5.0), ("Candle2", -9.0, 10.0), ("Candle3", 9.0, 15.0),
                       ("Candle4", -9.0, 20.0), ("Candle5", -3.0, 25.0)):
        candle(s, name, x, y)
    s.marker("FromQuarter", (9.0, 0.1, 0))
    s.door("DoorToQuarter", 10.5, 0, "gravedigger_quarter", "Spawns/FromBellTower", "В квартал могильщика")
    save(s)


if __name__ == "__main__":
    catacombs()
    ossuary()
    gravedigger_quarter()
    bell_tower()
    print("ok")
