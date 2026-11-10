"""Уровень-забег «Горящая деревня» (GAME_DESIGN §8.11) — graybox-полигон.

Две комнаты: run_village — деревня героя горит и рушится за спиной; run_exit — за воротами,
у осколка, где герой приходит в себя. Пока стоит отдельно от основного маршрута: вход — дверь
в комнате-прототипе room_001. Запуск из корня проекта: python tools/levels/build_run.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import scenery  # noqa: E402

# Свои ресурсы забега — только в этих комнатах: сцены леса от запуска не меняются.
scenery.EXT = {**scenery.EXT,
               "fire": ("Script", "res://world/common/fire_spot.gd"), "ambience": ("Script", "res://world/common/burning_ambience.gd"),
               "npc": ("Script", "res://world/common/npc.gd"), "run": ("Script", "res://world/run/run_level.gd"),
               "collapsible": ("Script", "res://world/run/collapsible.gd")}
scenery.MATS = {**scenery.MATS, "wood_burnt": (0.16, 0.1, 0.07)}
from scenery import Scene  # noqa: E402

G, D = "Geometry", "Decor"
BURN = {"bg": (0.07, 0.022, 0.012), "amb": (0.62, 0.36, 0.26), "amb_e": 0.3, "fog": (0.26, 0.085, 0.035), "fog_d": 0.015}
DAWN = {"bg": (0.05, 0.04, 0.05), "amb": (0.36, 0.33, 0.38), "amb_e": 0.36, "fog": (0.17, 0.13, 0.13), "fog_d": 0.02}

# --- Числа забега (черновик, настраивает автор) -----------------------------
LEFT, RIGHT = 0.0, 150.0
START_X = 7.0        # линия старта: шаг от двери дома
HEAD_START = 12.0    # фронт стартует на столько позади линии
MAX_SLACK = 5.0      # запас героя, с (§8.11: не больше ~5 с)
WARN = 0.7           # сколько кусок дрожит перед падением
# Скорость фронта по участкам (x начала, м/с). Герой бежит ~7 м/с по ровному.
PACE = ((0.0, 6.0),      # улица
        (30.0, 5.6),     # мост над оврагом
        (62.0, 5.0),     # двор с мародёром
        (84.0, 4.2),     # подъём на крыши
        (90.0, 5.4),     # крыши
        (106.0, 5.4),    # сквозь дом
        (127.0, 6.0))    # ворота
REWARDS = (("run_village_loft", "tempered_glass"), ("run_village_gallery", "fire_flask"))

MODE_FOREVER, MODE_RESTORES = 0, 1


def save(scene, file):
    Path(f"world/rooms/{file}.tscn").write_text(scene.text(), encoding="utf-8")


def fire(s, name, pos, size=(1.6, 2.2, 0.6), energy=2.2, rng=8.0):
    s.node(name, 'type="Node3D"', D, [f"position = {scenery.v3(pos)}", 'script = ExtResource("fire")',
           f"size = {scenery.v3(size)}", f"light_energy = {energy}", f"light_range = {rng}"])


def piece(s, name, pos, size, mode=MODE_FOREVER, color=(0.25, 0.17, 0.11), solid=True, warn=WARN, offset=0.0, extra=()):
    """Кусок, который рушится, когда до него доходит фронт (Collapsible)."""
    props = [f"position = {scenery.v3(pos)}", 'script = ExtResource("collapsible")', f"size = {scenery.v3(size)}",
             f"color = Color({color[0]}, {color[1]}, {color[2]}, 1)", f"warn_time = {warn}"]
    if mode != MODE_FOREVER:
        props.append(f"mode = {mode}")
    if not solid:
        props.append("solid = false")
    if offset:
        props.append(f"at_offset = {offset}")
    s.node(name, 'type="StaticBody3D"', "Objects", props + list(extra))


def burning_house(s, name, x, z, w, h, roof_h, fire_at=True):
    """Дом на заднем плане: окна светятся огнём, крыша занялась."""
    s.box(D, f"{name}Wall", (x, h / 2, z), (w, h, 3), "plaster")
    s.roof(D, f"{name}Roof", (x, h + roof_h / 2, z), (w + 1.0, roof_h, 3.6))
    s.box(D, f"{name}Window", (x - w * 0.2, h * 0.55, z + 1.53), (0.9, 1.1, 0.08), "fire")
    s.box(D, f"{name}Door", (x + w * 0.22, 1.1, z + 1.53), (1.0, 2.2, 0.08), "char")
    if fire_at:
        fire(s, f"{name}Fire", (x, h + 0.2, z + 0.6), (w * 0.6, 2.6, 0.6), 2.4, 10.0)


def run_village():
    s = Scene("RunVillage", "run_village", RIGHT - LEFT, BURN, sun_color=(1.0, 0.5, 0.25), sun_energy=0.3)
    mid = (LEFT + RIGHT) / 2
    # Стены по краям и дальняя земля; пол — участками: между ними овраг и погреба.
    s.box(G, "WallLeft", (LEFT - 0.5, 6.0, 0), (1, 20, 4.4), "stone_dark", True)
    s.box(G, "WallRight", (RIGHT + 0.5, 6.0, 0), (1, 20, 4.4), "stone_dark", True)
    s.box(D, "FarGround", (mid, -2, -20), (RIGHT - LEFT + 40, 4, 35.6), "mud")
    for name, x0, x1 in (("Street", LEFT, 30.0), ("Yard", 62.0, 88.0), ("HouseSill", 106.0, 109.0), ("Gate", 127.0, RIGHT)):
        s.box(G, f"Ground{name}", ((x0 + x1) / 2, -2, 0), (x1 - x0, 4, 4.4), "mud", True)
        s.box(D, f"Bank{name}", ((x0 + x1) / 2, -2.2, 3.7), (x1 - x0, 4, 3.0), "earth_dark")

    # --- 1. Улица от двери дома: ровный разгон. За спиной падают заборы и балки.
    s.box(D, "HomeWall", (1.0, 2.4, -3.2), (7.0, 4.8, 3), "plaster")
    s.roof(D, "HomeRoof", (1.0, 6.2, -3.2), (8.0, 2.8, 3.6))
    s.box(D, "HomeDoor", (2.0, 1.2, -1.66), (1.3, 2.4, 0.1), "wood")
    s.box(D, "HomeWindow", (-0.6, 2.6, -1.66), (0.9, 1.1, 0.08), "window")
    burning_house(s, "StreetHouseA", 13.0, -5.5, 7.0, 4.4, 3.0)
    burning_house(s, "StreetHouseB", 24.0, -6.0, 6.0, 4.0, 2.8)
    for i, x in enumerate((9.0, 12.0, 15.0, 19.0, 23.0, 27.0)):
        piece(s, f"Fence{i}", (x, 0.6, -1.7), (2.6, 1.2, 0.12), color=(0.2, 0.14, 0.09), solid=False)
    for i, x in enumerate((11.0, 21.0)):
        piece(s, f"StreetBeam{i}", (x, 3.4, -1.4), (4.0, 0.3, 0.3), color=(0.14, 0.09, 0.06), solid=False)
        s.box(D, f"StreetPost{i}", (x - 1.9, 1.7, -1.4), (0.3, 3.4, 0.3), "wood_dark")
    fire(s, "StreetFireA", (5.0, 0.0, -1.9), (2.4, 2.8, 0.6))
    fire(s, "StreetFireB", (17.0, 0.0, -2.4), (2.0, 2.4, 0.6))
    s.box(D, "Cart", (26.0, 0.7, -2.2), (2.6, 0.5, 1.4), "wood")
    s.cyl(D, "CartWheel", (25.2, 0.5, -1.4), 0.5, 0.12, "wood_dark", rot=(1.5708, 0, 0))

    # --- 2. Мост над оврагом: настил падает кусками, два обгоревших пролёта держат повторно.
    planks = ((30.0, 34.5, MODE_FOREVER), (36.5, 40.5, MODE_FOREVER), (43.0, 47.0, MODE_RESTORES),
              (49.5, 53.5, MODE_FOREVER), (55.5, 59.5, MODE_RESTORES))
    for i, (x0, x1, mode) in enumerate(planks):
        color = (0.2, 0.2, 0.21) if mode == MODE_RESTORES else (0.25, 0.17, 0.11)
        piece(s, f"Plank{i}", ((x0 + x1) / 2, -0.2, 0), (x1 - x0, 0.4, 3.0), mode, color)
        s.box(D, f"PlankPost{i}", ((x0 + x1) / 2, -7.0, -1.7), (0.4, 13.0, 0.4), "wood_dark")
    s.box(D, "RavineFar", (46.0, -9.0, -6.0), (34.0, 14.0, 6.0), "earth_dark")
    fire(s, "RavineFire", (46.0, -6.0, -2.4), (10.0, 4.0, 0.6), 2.6, 16.0)
    for i, x in enumerate((33.0, 41.5, 51.0, 58.0)):
        s.box(D, f"BridgeRope{i}", (x, 1.0, -1.5), (0.06, 2.0, 0.06), "rope")

    # --- 3. Двор: мародёр мешает пройти; сверху, на сеновале, — сундук (боковая ветка по лестнице).
    burning_house(s, "Barn", 72.0, -5.0, 12.0, 5.4, 3.2)
    s.enemy("Looter", "bandit_knife", (79.0, 0.0, 0))
    s.ladder("LoftLadder", 67.0, 0.0, 3.3, 1.0)
    s.ladder_look("Loft", 67.0, 0.0, 3.3)
    piece(s, "Loft", (71.2, 3.1, 0), (7.2, 0.4, 3.0), offset=2.0)
    for i, x in enumerate((67.9, 74.5)):
        s.box(D, f"LoftPost{i}", (x, 1.45, -1.3), (0.3, 2.9, 0.3), "wood_dark")
    s.chest("LoftChest", (73.2, 3.3, -0.6), 150, REWARDS[0][0], (REWARDS[0][1],))
    s.box(D, "Hay", (70.0, 3.65, -0.9), (2.2, 0.7, 1.0), "thatch")
    fire(s, "YardFire", (81.0, 0.0, -2.2), (2.2, 2.6, 0.6))

    # --- 4. Крыши: улица завалена, дорога — поверху, над горящими погребами.
    s.box(G, "Barricade", (87.0, 1.6, 0), (2.0, 3.2, 3.0), "char", True)
    for i, (x, top) in enumerate(((83.6, 1.1), (85.2, 2.2))):
        s.box(G, f"RoofCrate{i}", (x, top / 2, 0), (1.6, top, 3.0), "wood", True)
    fire(s, "BarricadeFire", (87.0, 3.2, -0.9), (1.8, 2.2, 0.5))
    roofs = ((88.0, 94.5), (97.0, 103.5))
    for i, (x0, x1) in enumerate(roofs):
        piece(s, f"Roof{i}", ((x0 + x1) / 2, 3.0, 0), (x1 - x0, 0.4, 3.0), color=(0.2, 0.16, 0.13))
        s.box(D, f"RoofWall{i}", ((x0 + x1) / 2, -2.0, -2.2), (x1 - x0 - 0.6, 10.0, 1.2), "plaster")
        fire(s, f"RoofFire{i}", ((x0 + x1) / 2, -2.5, -1.2), (x1 - x0 - 1.5, 4.0, 0.6), 2.4, 12.0)
    # Каменный приступок у дома: с него — вниз, в дверь, или прыжком на полати.
    s.box(G, "StepDown", (105.0, -0.8, 0), (2.0, 6.4, 3.0), "stone", True)

    # --- 5. Сквозь горящий дом: пол над погребом рушится доска за доской, упавшая балка — прыжок.
    #        Полати под потолком (боковая ветка): на них прыгают с приступка, там находка.
    s.box(D, "HouseBack", (118.0, 3.0, -2.3), (20.0, 6.0, 0.6), "plaster")
    s.box(D, "HouseCeiling", (118.0, 5.6, -0.6), (20.0, 0.3, 3.2), "wood_dark")
    for i, x in enumerate((108.2, 127.8)):
        s.box(D, f"HouseJamb{i}", (x, 4.3, -0.4), (0.5, 2.6, 2.6), "plaster")
    for i in range(6):
        x0 = 109.0 + i * 3.0
        piece(s, f"Floor{i}", (x0 + 1.5, -0.2, 0), (3.0, 0.4, 3.0), color=(0.22, 0.15, 0.1))
    s.box(D, "CellarGlow", (118.0, -6.0, -1.0), (18.0, 0.2, 3.0), "ember")
    fire(s, "CellarFire", (118.0, -6.0, -1.2), (12.0, 4.0, 0.6), 2.8, 16.0)
    piece(s, "Gallery", (112.5, 2.25, 0), (6.0, 0.3, 3.0), color=(0.2, 0.14, 0.09), offset=1.0)
    s.node("GalleryFind", 'type="Area3D"', "Objects", ["position = Vector3(113.5, 2.4, 0)", 'script = ExtResource("pickup")',
           f'item_id = &"{REWARDS[1][1]}"', f'flag = &"{REWARDS[1][0]}"', 'pickup_prompt = "Схватить склянку"',
           "look_size = Vector3(0.25, 0.4, 0.25)", "look_color = Color(0.5, 0.2, 0.1, 1)"])
    piece(s, "FallenBeam", (120.5, 0.45, 0), (1.0, 0.9, 3.0), color=(0.14, 0.09, 0.06))
    for i, x in enumerate((111.0, 117.0, 124.0)):
        piece(s, f"CeilingBeam{i}", (x, 4.6, -0.9), (0.3, 0.3, 2.4), color=(0.14, 0.09, 0.06), solid=False, offset=-2.0)
    fire(s, "HouseFire", (123.0, 0.0, -1.9), (2.0, 3.0, 0.5))

    # --- 6. Ворота деревни: выход.
    s.box(D, "GatePostA", (143.5, 2.6, -1.4), (0.8, 5.2, 0.8), "wood_dark")
    s.box(D, "GatePostB", (148.5, 2.6, -1.4), (0.8, 5.2, 0.8), "wood_dark")
    s.box(D, "GateTop", (146.0, 5.4, -1.4), (6.0, 0.6, 0.8), "wood_dark")
    s.fence(D, "Palisade", 128.5, 143.0, -1.8, mat="wood_dark")
    burning_house(s, "GateHouse", 136.0, -6.0, 7.0, 4.2, 3.0)
    fire(s, "GateFire", (131.0, 0.0, -2.2), (2.0, 2.4, 0.6))

    pace = ", ".join(f"{x}, {v}" for x, v in PACE)
    flags = ", ".join(f'&"{f}"' for f, _ in REWARDS)
    items = ", ".join(f'&"{i}"' for _, i in REWARDS)
    s.node("Run", 'type="Node3D"', "Objects", ['script = ExtResource("run")', 'next_room = &"run_exit"',
           'next_shard = NodePath("Objects/MirrorShard")', 'echo_spawn = NodePath("Spawns/HeroEcho")', 'done_flag = &"run_village_done"',
           f"start_x = {START_X}", f"head_start = {HEAD_START}", f"pace = PackedVector2Array({pace})", f"max_slack = {MAX_SLACK}",
           f"reward_flags = Array[StringName]([{flags}])", f"reward_items = Array[StringName]([{items}])"])
    s.node("Ambience", 'type="Node"', "Objects", ['script = ExtResource("ambience")',
           'calls = PackedStringArray("…бегите!..", "…горит, всё горит!..")', "every = 9.0"])
    s.marker("PlayerStart", (2.0, 0.1, 0))
    s.door("DoorOut", 147.0, 0, "run_exit", "Spawns/FromVillage", "Бежать из деревни")
    save(s, "run_village")


def run_exit():
    s = Scene("RunExit", "run_exit", 36.0, DAWN, sun_color=(0.8, 0.6, 0.55), sun_energy=0.3)
    s.frame(-18, 18)
    # Позади — зарево: деревня догорает. Дороги назад нет.
    s.box(D, "Glow", (-24.0, 4.0, -8.0), (10.0, 9.0, 0.3), "ember")
    s.light(D, "GlowLight", (-16.0, 3.0, -1.0), (1.0, 0.45, 0.2), 2.2, 16.0)
    s.box(D, "Rubble", (-16.5, 1.2, -0.4), (3.0, 2.4, 3.4), "char", rot=(0, 0, 0.2))
    for i, x in enumerate((-10.0, -3.0, 9.0, 15.0)):
        s.dead_tree(D, f"Tree{i}", x, -4.0 - (i % 2) * 2.0, 6.0 + i % 3)
    s.rocks(D, "Rocks", 6.0, 0.0, -2.4)
    # Камень у осколка: на нём герой приходит в себя.
    s.box(D, "SeatStone", (2.0, 0.25, -0.1), (1.0, 0.5, 1.2), "stone")
    s.shard("MirrorShard", 3.0, 0.0)
    s.marker("PlayerStart", (-13.0, 0.1, 0))
    s.marker("FromVillage", (-13.0, 0.1, 0))
    s.marker("HeroEcho", (-1.5, 0.1, 0))
    s.marker("Wake", (1.7, 0.1, 0))
    s.node("Peddler", 'type="Area3D"', "Objects", ["position = Vector3(11.0, 0, 0)", 'script = ExtResource("npc")', 'npc_name = "Погорелец"',
           'lines = PackedStringArray("Всё сгорело. Всё.", "Иди к часовне. Там ещё есть люди.")',
           "look_color = Color(0.28, 0.2, 0.16, 1)", "sells_leftovers = true"])
    save(s, "run_exit")


if __name__ == "__main__":
    run_village()
    run_exit()
