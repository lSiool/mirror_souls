"""Пекло (§8.13): под глубокой выработкой копей пол провалился в огромную пещеру. Лава смертельна, как пропасть;
воздух дрожит от жара; из живых — только пленники демонов (сами демоны — позже). Четыре комнаты graybox:
провал (осколок на месте падения) → огненная река (мост на цепях над лавой) → темница (пленники, рыцарь в клетке)
→ обсидиановые ступени (скат из чёрного стекла, ворот старой клети, запертые ворота стража ямы — будущая арена).

Спуск — в одну сторону: дверь «Спуститься в провал» на досках в `deep_gallery`. Путь наверх открывается изнутри:
ворот на обсидиановых ступенях (флаг `inferno_shortcut`) опускает клеть под провал — в комнате провала появляется
дверь «Подняться в клети к забою».
Палитра: тёмный багрово-коричневый и сажа, ярка только лава; стекло — чёрный обсидиан с обычным бликом.
Высоты: ноль каждой комнаты — дно пещеры, на 24 м ниже глубокой выработки (на карте — WorldMap.ROOMS).
Запуск из корня проекта: python tools/levels/build_inferno.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from scenery import Scene, v3  # noqa: E402
import backdrop as bd  # noqa: E402
import build_graveyard as bg  # noqa: E402
from build_mines import land, ramp  # noqa: E402

G, D, O = "Geometry", "Decor", "Objects"
INFERNO = {"bg": (0.02, 0.005, 0.003), "amb": (0.55, 0.3, 0.22), "amb_e": 0.34, "fog": (0.12, 0.03, 0.015), "fog_d": 0.024}
SKY_DEPTHS = ((0.02, 0.005, 0.004), (0.24, 0.06, 0.025))
DEPTH_GLOW = (0.8, 0.25, 0.05, 0.45)
HEAT = (1.0, 0.36, 0.1)
PATH_HEAT = (0.08, 0.035, 0.02)
SHORTCUT = "inferno_shortcut"


def save(scene):
    Path(f"world/rooms/{scene.room_id}.tscn").write_text(scene.text(), encoding="utf-8")


def new_room(name, room_id, left, right):
    s = Scene(name, room_id, right - left, INFERNO, (0.9, 0.45, 0.3), 0.0)
    s.use("lava", "Script", "res://world/hazards/lava.gd")
    s.use("sayline", "Script", "res://world/common/say_line.gd")
    s.use("flagshown", "Script", "res://world/common/flag_shown.gd")
    s.use("lever", "Script", "res://world/common/flag_lever.gd")
    s.use("npc", "Script", "res://world/common/npc.gd")
    s.wall("WallLeft", (left - 0.5, 6.0, 0), (1, 40, 4.4))
    s.wall("WallRight", (right + 0.5, 6.0, 0), (1, 40, 4.4))
    return s


# ---------------------------------------------------------------- помощники
def lava(s, name, x, y, w, z=0.0, depth=4.4, glow=1.6):
    """Лава (Lava): поверхность на высоте y, ширина w; глубже плоскости героя — фон, тоже смертельный."""
    s.node(name, 'type="Area3D"', O, [f"position = {v3((x, y, z))}", 'script = ExtResource("lava")',
                                      f"size = {v3((w, 1.0, depth))}", f"glow_energy = {glow}"])


def armor_pickup(s, name, x, y, item, flag, prompt, color, size=(0.7, 0.12, 0.5)):
    """Доспех-болванка с сопротивлением огню (ArmorData, data/armor): лежит на месте, берётся один раз."""
    s.node(name, 'type="Area3D"', O, [f"position = {v3((x, y, 0.0))}", 'script = ExtResource("pickup")', f'item_id = &"{item}"',
                                      f'flag = &"{flag}"', f'pickup_prompt = "{prompt}"', f"look_size = {v3(size)}",
                                      f"look_color = Color({color[0]}, {color[1]}, {color[2]}, 1)"])


def lava_fall(s, name, x, y_top, y_bottom, z=-6.0, w=1.6):
    """Лавопад со стены пещеры: светящаяся полоса и тёплый свет у подножия."""
    s.box(D, name, (x, (y_top + y_bottom) / 2, z), (w, y_top - y_bottom, 0.3), "lava_glow")
    s.light(D, f"{name}Light", (x, y_bottom + 2.0, z + 2.5), HEAT, 1.4, 12.0)


def basalt_columns(s, name, x0, x1, y, z=-2.6, step=1.1):
    """Шестигранные столбы базальта у стены пещеры."""
    x, i = x0, 0
    while x < x1:
        h = 2.0 + ((i * 37) % 7) * 0.6
        s.cyl(D, f"{name}{i}", (round(x, 2), y + h / 2, z - (i % 2) * 0.4), 0.55, h, "basalt", sides=6)
        x += step
        i += 1


def stalactites(s, name, x0, x1, y, z=-1.8, step=2.3):
    x, i = x0, 0
    while x < x1:
        h = 1.2 + ((i * 53) % 5) * 0.5
        s.cyl(D, f"{name}{i}", (round(x, 2), y - h / 2, z - (i % 3) * 0.5), 0.35 + (i % 2) * 0.15, h, "basalt",
              rot=(math.pi, 0, 0), sides=6, cone=True)
        x += step + ((i * 17) % 3) * 0.6
        i += 1


def obsidian_shards(s, name, x0, x1, y, z=-2.4, step=2.6):
    """Чёрные стеклянные иглы обсидиана: глянец без блика (блик — только у стекла-механики)."""
    x, i = x0, 0
    while x < x1:
        h = 0.8 + ((i * 29) % 5) * 0.45
        t = ((i * 13) % 5 - 2) * 0.12
        s.cyl(D, f"{name}{i}", (round(x, 2), y + h / 2 - 0.1, z - (i % 2) * 0.6), 0.3, h, "obsidian", rot=(0, 0, t), sides=4, cone=True)
        x += step
        i += 1


def hanging_cage(s, name, x, y, z, top, skeleton=True):
    s.hanging_cage(D, name, x, y, z)
    s.box(D, f"{name}Line", (x, (y + 2.7 + top) / 2, z), (0.05, top - y - 2.7, 0.05), "iron")
    if skeleton:
        s.sphere(D, f"{name}Skull", (x + 0.05, y - 0.25, z), 0.14, "bone")
        s.box(D, f"{name}Ribs", (x, y - 0.42, z), (0.28, 0.3, 0.16), "bone")


def depths(k, left, right, ground=0.0):
    """Даль пещеры: багровое зарево снизу, скальные иглы, лавовое озеро до горизонта, лавопады, клетки на цепях,
    тёмный свод сверху. Неба нет — «небо» здесь зарево над лавой."""
    k.sky(left, right, *SKY_DEPTHS, glow=DEPTH_GLOW, glow_x=0.5, glow_y=0.72, glow_size=0.35)
    k.put("Backdrop", "Vault", "box", "sil", ((left + right) / 2, ground + 30.0, -40.0), (right - left + 2 * bd.FAR_PAD + 120, 8.0, 80.0))
    k.put("Backdrop", "LavaLake", "box", "ember", ((left + right) / 2, ground - 3.2, -50.0), (right - left + 2 * bd.FAR_PAD + 80, 0.2, 40.0))
    k.pinnacles(left - 40, right + 40, -22, -38, ground - 4, 14, 30, mat="sil")
    x = left - 30.0
    while x < right + 30.0:
        k.put("Backdrop", "FarFall", "box", "ember", (x, ground + 12.0, -44.0), (0.9, 26.0, 0.3))
        x += k.rng.uniform(22.0, 36.0)
    x = left - 20.0
    while x < right + 20.0:
        y = ground + k.rng.uniform(6.0, 12.0)
        k.put("Backdrop", "FarCage", "box", "sil", (x, y, -26.0), (0.9, 1.4, 0.9))
        k.put("Backdrop", "FarCageChain", "box", "sil", (x, (y + ground + 26.0) / 2, -26.0), (0.06, ground + 26.0 - y, 0.06))
        x += k.rng.uniform(9.0, 16.0)
    k.haze(left, right, ground + 1.5, -6, 4, (0.3, 0.08, 0.03), 0.3)
    k.haze(left, right, ground + 4, -18, 12, (0.22, 0.06, 0.025), 0.45)
    k.haze(left, right, ground + 8, -34, 22, (0.18, 0.05, 0.02), 0.55)


def heat_veils(s, name, xs, y, w=4.0, h=6.0):
    for i, x in enumerate(xs):
        s.veil(D, f"{name}{i}", (x, y + h / 2, -1.4), (w, h), "dust_veil")


# ---------------------------------------------------------------- 1. Провал
def inferno_breach():
    """Место падения: груда обломков и досок под дырой в своде, сверху — темнота забоя. Осколок прямо здесь:
    спуск в одну сторону, и первый отдых нужен сразу. Обломки спускаются к дну пещеры; дальше — первая
    огненная протока: три метра лавы, только прыжком. После ворота на обсидиановых ступенях под провалом висит
    клеть — путь наверх, к забою."""
    s = new_room("InfernoBreach", "inferno_breach", -24, 24)
    land(s, "Mound", -54, -8, 8, -6, "basalt")
    ramp(s, "Rubble", -8, 8, 4, 0, "basalt", thick=6.0)
    land(s, "Floor", 4, 8, 0, -6, "basalt")
    land(s, "ChannelBed", 8, 11, -1.5, -6, "basalt")
    land(s, "FloorEast", 11, 54, 0, -6, "basalt")
    land(s, "CeilingWest", -54, -17, 20, 18, "basalt")
    land(s, "CeilingEast", -11, 54, 20, 18, "basalt")
    lava(s, "Channel", 9.5, -1.0, 3.0)
    lava(s, "ChannelBack", 9.5, -1.0, 3.0, z=-14.2, depth=24.0, glow=0.0)
    # Провал в своде: темнота забоя, обломки досок, оборванная цепь.
    s.box(D, "BreachDark", (-14.0, 24.0, 0.0), (6.0, 8.0, 4.4), "char")
    for i, (x, t) in enumerate(((-15.5, 0.5), (-12.6, -0.7), (-10.4, 0.2), (-17.2, 1.1))):
        s.box(D, f"FallenPlank{i}", (x, 8.15 + (i % 2) * 0.2, -1.0 + (i % 3) * 0.5), (2.2, 0.2, 0.6), "wood", rot=(0, 0.3 * i, t))
    for i in range(10):
        s.box(D, f"BrokenChain{i}", (-12.6, round(19.6 - i * 0.32, 3), -0.6), (0.08, 0.26, 0.08), "iron", rot=(0, (i % 2) * 1.57, 0))
    bg.say(s, "BreachLine", -14.0, 8.0, "«Провал над головой. Цепь оборвана — назад не подняться.»", size=(5, 4, 4))
    s.shard("MirrorShard", -20.0, 8.0)
    # Клеть под провалом — после ворота (флаг inferno_shortcut).
    s.node("ShortcutLook", 'type="Node3D"', D, ['script = ExtResource("flagshown")', f'flag = &"{SHORTCUT}"'])
    for i, (dx, dz) in enumerate(((-0.9, -1.6), (0.9, -1.6), (-0.9, 0.1), (0.9, 0.1))):
        s.box(f"{D}/ShortcutLook", f"CageBar{i}", (-12.5 + dx, 9.3, dz), (0.08, 2.6, 0.08), "iron")
    s.box(f"{D}/ShortcutLook", "CageRoof", (-12.5, 10.6, -0.75), (2.0, 0.12, 1.9), "iron")
    s.box(f"{D}/ShortcutLook", "CageChain", (-12.5, 15.0, -0.75), (0.1, 8.6, 0.1), "iron")
    s.node("Shortcut", 'type="Node3D"', O, ['script = ExtResource("flagshown")', f'flag = &"{SHORTCUT}"'])
    s.node("DoorUp", 'type="Area3D"', f"{O}/Shortcut", [f"position = {v3((-12.5, 8.0, 0.0))}", 'script = ExtResource("door")',
                                                       'target_room = &"deep_gallery"', 'target_spawn = NodePath("Spawns/FromInferno")',
                                                       'open_prompt = "Подняться в клети к забою"', "door_color = Color(0.09, 0.09, 0.1, 1)"])
    # Дно пещеры: базальтовые столбы, сталактиты, скелет забойщика у груды, жар.
    basalt_columns(s, "Columns", 12.0, 24.0, 0.0)
    stalactites(s, "Stalactite", -24.0, 24.0, 18.0)
    s.sphere(D, "MinerSkull", (2.0, 0.15, -1.2), 0.15, "bone")
    s.box(D, "MinerBones", (2.6, 0.08, -1.1), (0.9, 0.08, 0.3), "bone", rot=(0, 0.4, 0))
    s.box(D, "MinerPick", (1.2, 0.3, -1.4), (0.06, 1.0, 0.06), "wood", rot=(0, 0, 1.1))
    # На забойщике — плащ, вымоченный в глине: он шёл к лаве подготовленным, и всё же не дошёл.
    armor_pickup(s, "FireCloak", 3.2, 0.0, "armor_fire_cloak", "found_fire_cloak", "Снять плащ с забойщика", (0.3, 0.24, 0.18))
    lava_fall(s, "Fall", 18.0, 17.5, 0.0)
    heat_veils(s, "Heat", (9.5, 18.0), 0.0)
    k = bd.Kit(s)
    depths(k, -24, 24)
    s.marker("FromMines", (-18.0, 8.1, 0))
    s.marker("FromRiver", (21.0, 0.1, 0))
    s.door("DoorToRiver", 22.5, 0, "lava_river", "Spawns/FromBreach", "К огненной реке")
    for x0, x1, y in ((-24, -8, 8.0), (4, 8, 0.0), (11, 24, 0.0)):
        k.path_light(x0, x1, y, PATH_HEAT)
    save(s)


# ---------------------------------------------------------------- 2. Огненная река
def lava_river():
    """Широкая река лавы поперёк пещеры; через неё — мост из досок на цепях, местами доски прогорели
    (короткие провалы — герой цепляется за край). Лава неглубокая, по колено: сорвался в прогар — горишь, пока
    не выпрыгнешь обратно на доски (под мостом не пройти — низко). Над лавой клетка с тем, кто не дождался."""
    s = new_room("LavaRiver", "lava_river", -30, 30)
    land(s, "WestBank", -60, -20, 0, -6, "basalt")
    land(s, "EastBank", 16, 60, 0, -6, "basalt")
    land(s, "Ceiling", -60, 60, 18, 16, "basalt")
    land(s, "RiverBed", -20, 16, -1.9, -6, "basalt")
    lava(s, "River", -2.0, -1.3, 36.0, glow=2.0)
    lava(s, "RiverBack", -2.0, -1.3, 100.0, z=-16.2, depth=28.0, glow=0.0)
    for i, (x0, x1) in enumerate(((-20.0, -8.0), (-6.6, 4.0), (5.4, 16.0))):
        s.box(G, f"Bridge{i}", ((x0 + x1) / 2, -0.15, 0), (x1 - x0, 0.3, 2.4), "wood_dark", True)
    for i, x in enumerate((-17.0, -11.0, -3.5, 1.5, 8.0, 13.0)):
        s.box(D, f"BridgeChain{i}", (x, 8.0, -1.1), (0.08, 16.0, 0.08), "iron")
    for i, z in enumerate((-1.15, 1.15)):
        s.box(D, f"BridgeRail{i}", (-2.0, 0.9, z), (36.0, 0.06, 0.06), "iron")
    for i, x in enumerate((-7.3, 4.7)):
        s.box(D, f"BurntEnd{i}", (x, -0.4, 0.6), (0.6, 0.3, 1.2), "char", rot=(0, 0, 0.6 if i else -0.6))
    bg.say(s, "BridgeLine", -22.0, 0.0, "«Мост на цепях. Доски прогорели — где-то их нет вовсе.»", size=(4, 3, 4))
    hanging_cage(s, "RiverCage", -2.0, 6.0, -1.6, 16.0)
    lava_fall(s, "FallA", 10.0, 15.5, -1.3)
    lava_fall(s, "FallB", -24.0, 15.5, -1.3, z=-8.0, w=1.0)
    basalt_columns(s, "ColumnsW", -30.0, -21.0, 0.0)
    basalt_columns(s, "ColumnsE", 17.0, 30.0, 0.0)
    stalactites(s, "Stalactite", -30.0, 30.0, 16.0)
    heat_veils(s, "Heat", (-12.0, -2.0, 8.0), -1.3, w=6.0, h=7.0)
    k = bd.Kit(s)
    depths(k, -30, 30)
    s.marker("FromBreach", (-27.0, 0.1, 0))
    s.marker("FromCells", (27.0, 0.1, 0))
    s.door("DoorToBreach", -28.5, 0, "inferno_breach", "Spawns/FromRiver", "Назад, к провалу")
    s.door("DoorToCells", 28.5, 0, "captive_cells", "Spawns/FromRiver", "В темницу")
    for x0, x1 in ((-30, -20), (16, 30)):
        k.path_light(x0, x1, 0.0, PATH_HEAT)
    save(s)


# ---------------------------------------------------------------- 3. Темница
def captive_cells():
    """Пещера пленников: клетки на цепях, дыбы, жаровня. Трое связанных — пропавшие сверху: забойщик из копей,
    пастух из деревни, послушник часовни; развязать — благодарность и награда (позже среди пленников будут
    и демоны в чужом обличье). На возвышении — клетка с рыцарем в тёмных избитых доспехах: замок не открыть,
    ключ — у стража ямы."""
    s = new_room("CaptiveCells", "captive_cells", -26, 26)
    s.use("captive", "Script", "res://world/common/bound_captive.gd")
    land(s, "Floor", -56, 56, 0, -6, "basalt")
    land(s, "Dais", 10, 22, 1.0, -6, "basalt")
    land(s, "Ceiling", -56, 56, 16, 14, "basalt")
    captives = (
        ("CaptiveMiner", -16.0, "captive_miner", "Забойщик", ("Ты… сверху? Значит, клеть ещё ходит.", "Возьми. Тут мне это ни к чему."),
         (0.22, 0.2, 0.18), ['reward_item = &"tempered_glass"']),
        ("CaptiveShepherd", -7.0, "captive_shepherd", "Пастух из деревни",
         ("В ночь пожара меня утащили не волки. Волки так не говорят.", "Вот всё, что при мне было."), (0.24, 0.22, 0.16), ["reward_echoes = 150"]),
        ("CaptiveNovice", 2.0, "captive_novice", "Послушник часовни",
         ("Я молился, чтобы пришёл кто-нибудь. Не думал, что придёт живой.", "Святая вода — последняя. Тебе нужнее."), (0.2, 0.2, 0.24),
         ['reward_item = &"holy_flask"', "reward_amount = 2"]),
    )
    for name, x, flag, title, thanks, color, reward in captives:
        quoted = ", ".join('"' + line + '"' for line in thanks)
        s.node(name, 'type="Area3D"', O, [f"position = {v3((x, 0.0, 0.0))}", 'script = ExtResource("captive")', f'flag = &"{flag}"',
                                          f'captive_name = "{title}"', f"thanks = PackedStringArray({quoted})",
                                          f"look_color = Color({color[0]}, {color[1]}, {color[2]}, 1)"] + reward)
        s.box(D, f"{name}Chain", (x + 0.4, 1.6, -2.2), (0.06, 1.6, 0.06), "iron")
        s.box(D, f"{name}Ring", (x + 0.4, 2.4, -2.18), (0.3, 0.3, 0.05), "iron")
    # Рыцарь в клетке на возвышении.
    kx = 16.0
    for i, (dx, dz) in enumerate(((-1.4, -0.2), (-0.7, -0.2), (0.0, -0.2), (0.7, -0.2), (1.4, -0.2), (-1.4, -2.3), (1.4, -2.3))):
        s.box(D, f"KnightBar{i}", (kx + dx, 2.6, dz), (0.1, 3.2, 0.1), "iron")
    s.box(D, "KnightCageTop", (kx, 4.25, -1.25), (3.0, 0.15, 2.3), "iron")
    s.box(D, "KnightCageFloor", (kx, 1.05, -1.25), (3.0, 0.1, 2.3), "iron")
    s.box(D, "KnightLock", (kx + 1.4, 2.4, -0.1), (0.3, 0.4, 0.2), "rust")
    s.npc("Knight", kx, 1.0, "Рыцарь в клетке", [
        "Не трать силы на замок. Ключ носит тот, кто стережёт яму.",
        "Я спустился сюда за одним… другим. Давно. Доспех помнит больше, чем я.",
        "Когда дойдёшь до ворот — не смотри в обсидиан. Он показывает не тебя.",
        "Иди. Я подожду. Здесь все ждут."],
        (0.1, 0.1, 0.12))
    # Клетки на цепях, дыба, жаровня, пятна.
    hanging_cage(s, "CageA", -11.0, 7.0, -1.8, 14.0)
    hanging_cage(s, "CageB", 6.0, 8.5, -2.2, 14.0, skeleton=False)
    s.box(D, "RackFrame", (-21.0, 1.4, -2.0), (2.4, 2.8, 0.3), "wood_dark")
    s.box(D, "RackBar", (-21.0, 2.6, -1.8), (2.6, 0.15, 0.15), "wood_dark", rot=(0, 0, 0.1))
    # Фартук палача у дыбы: толстая кожа с бляхами — у жаровни в нём не обжечься.
    armor_pickup(s, "SmithApron", -19.6, 0.0, "armor_smith_apron", "found_smith_apron", "Взять кожаный фартук", (0.22, 0.14, 0.09),
                 size=(0.6, 0.16, 0.7))
    s.cyl(D, "Brazier", (-3.0, 0.5, -1.8), 0.5, 1.0, "iron", sides=8)
    s.box(D, "BrazierFire", (-3.0, 1.1, -1.8), (0.7, 0.3, 0.7), "fire")
    s.light(D, "BrazierLight", (-3.0, 1.8, -0.6), HEAT, 1.8, 9.0)
    for i, x in enumerate((-18.0, -9.0, 3.0)):
        s.box(D, f"Stain{i}", (x, 0.02, -0.6), (1.6, 0.03, 1.2), "flesh_dark", rot=(0, 0.5 * i, 0))
    stalactites(s, "Stalactite", -26.0, 26.0, 14.0)
    basalt_columns(s, "Columns", 20.0, 26.0, 0.0)
    k = bd.Kit(s)
    depths(k, -26, 26)
    s.marker("FromRiver", (-23.0, 0.1, 0))
    s.marker("FromSteps", (23.0, 0.1, 0))
    s.door("DoorToRiver", -24.5, 0, "lava_river", "Spawns/FromCells", "Назад, к реке")
    s.door("DoorToSteps", 24.5, 0, "obsidian_steps", "Spawns/FromCells", "К обсидиановым ступеням")
    for x0, x1, y in ((-26, 10, 0.0), (10, 22, 1.0), (22, 26, 0.0)):
        k.path_light(x0, x1, y, PATH_HEAT)
    save(s)


# ---------------------------------------------------------------- 4. Обсидиановые ступени
def obsidian_steps():
    """Чёрный обсидиан: скат из стекла вниз (не бьётся, по нему съезжают), нижняя площадка над лавовым рвом,
    лестница на верхнюю террасу. Там — ворот старой клети (путь наверх к копям) и запертые ворота стража ямы
    (будущая арена босса Пекла)."""
    s = new_room("ObsidianSteps", "obsidian_steps", -28, 28)
    land(s, "Entry", -58, -18, 0, -8, "basalt")
    ramp(s, "SlideBed", -18, -0.3, -6, -5.3, "basalt", thick=6.0)
    a = math.atan2(-5.0, 12.0)
    cx, cy = -12.0 + math.sin(a) * 0.15, -2.5 - math.cos(a) * 0.15
    s.instance("ObsidianSlide", O, "glass", [f"position = {v3((cx, cy, 0.0))}", f"rotation = {v3((0.0, 0.0, round(a, 4)))}",
                                              "role = 1", "size = Vector3(13.1, 0.3, 3)", "breakable = false", "obsidian = true"])
    land(s, "Lower", -6, 10, -5, -8, "basalt")
    land(s, "Terrace", 10, 58, 4, -8, "basalt")
    land(s, "Ceiling", -58, 58, 16, 14, "basalt")
    s.ladder("TerraceLadder", 9.4, -5.0, 9.0, 1.0)
    s.ladder_look("Terrace", 9.4, -5.0, 9.0, mat="iron")
    lava(s, "Moat", 2.0, -5.6, 16.0, z=-8.4, depth=8.0, glow=1.4)
    # Ворот старой клети: опускает клеть под провал — путь наверх.
    s.node("CageWinch", 'type="Area3D"', O, [f"position = {v3((14.0, 4.0, 0.0))}", 'script = ExtResource("lever")', f'flag = &"{SHORTCUT}"',
                                             'lever_prompt = "Повернуть ворот старой клети"',
                                             'line = "«Где-то над головой загрохотала цепь: клеть опустилась под провал. Путь к забою открыт.»"'])
    s.box(D, "WinchChain", (14.0, 9.5, -1.0), (0.1, 9.0, 0.1), "iron")
    s.note("CageNote", 11.5, 4.0, "Бирка на вороте", ["«Клеть забоя. Спускать только с ведома десятника».",
                                                     "Ниже нацарапано: «Спустили троих. Поднимать некого»."])
    # Ворота стража ямы — заперты изнутри.
    gx = 24.0
    for i, dx in enumerate((-1.6, 1.6)):
        s.box(D, f"GateLeaf{i}", (gx + dx, 4.0 + 3.5, -2.0), (3.0, 7.0, 0.4), "rust")
    s.box(D, "GateArch", (gx, 11.6, -2.1), (8.0, 1.2, 0.6), "basalt")
    s.sphere(D, "GateFace", (gx, 9.6, -1.75), 0.9, "char")
    for i, dx in enumerate((-0.35, 0.35)):
        s.sphere(D, f"GateEye{i}", (gx + dx, 9.8, -0.95), 0.12, "ember")
    bg.say(s, "GateLine", 21.0, 4.0, "«Ворота заперты изнутри. За ними что-то ходит — тяжело, кругами.»", size=(4, 3, 4))
    obsidian_shards(s, "ShardsBack", -28.0, 28.0, 0.0, z=-3.2)
    obsidian_shards(s, "ShardsLow", -6.0, 10.0, -5.0, z=-2.4, step=3.1)
    stalactites(s, "Stalactite", -28.0, 28.0, 14.0)
    lava_fall(s, "Fall", -22.0, 13.5, 0.0, z=-7.0, w=1.2)
    heat_veils(s, "Heat", (2.0, 12.0), -5.0)
    k = bd.Kit(s)
    depths(k, -28, 28)
    s.marker("FromCells", (-25.0, 0.1, 0))
    s.door("DoorToCells", -26.5, 0, "captive_cells", "Spawns/FromSteps", "Назад, в темницу")
    for x0, x1, y in ((-28, -18, 0.0), (-6, 10, -5.0), (10, 28, 4.0)):
        k.path_light(x0, x1, y, PATH_HEAT)
    save(s)


if __name__ == "__main__":
    inferno_breach()
    lava_river()
    captive_cells()
    obsidian_steps()
    print("ok")
