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
               "npc": ("Script", "res://world/common/npc.gd"), "bgscene": ("Script", "res://world/common/background_scene.gd"), "run": ("Script", "res://world/run/run_level.gd"),
               "collapsible": ("Script", "res://world/run/collapsible.gd")}
scenery.MATS = {**scenery.MATS, "wood_burnt": (0.16, 0.1, 0.07)}
from scenery import Scene  # noqa: E402

G, D = "Geometry", "Decor"
BURN = {"bg": (0.07, 0.022, 0.012), "amb": (0.62, 0.36, 0.26), "amb_e": 0.3, "fog": (0.26, 0.085, 0.035), "fog_d": 0.015}
DAWN = {"bg": (0.05, 0.04, 0.05), "amb": (0.36, 0.33, 0.38), "amb_e": 0.36, "fog": (0.17, 0.13, 0.13), "fog_d": 0.02}

# --- Числа забега (черновик, настраивает автор) -----------------------------
LEFT, RIGHT = 0.0, 250.0
TOP, LOW = 5.0, -5.5  # этажи: крыши и овраг; улица — 0
TOWER = 3.0          # высота башенки с сундуком над крышами
RUBBLE = 2.4         # высота завала в овраге
START_X = 7.0        # линия старта: шаг от двери дома
HEAD_START = 12.0    # фронт стартует на столько позади линии
MAX_SLACK = 5.0      # запас героя, с (§8.11: не больше ~5 с)
WARN = 0.7           # сколько кусок дрожит перед падением
# Скорость фронта по участкам (x начала, м/с). Герой бежит ~7 м/с по ровному.
PACE = ((0.0, 6.0),      # улица от дома
        (24.0, 5.6),     # первый мост
        (41.0, 4.0),     # площадь-развилка: секунда на выбор
        (58.0, 5.6),     # три пути
        (128.0, 4.4),    # погреб с громилой внизу, башенка наверху
        (150.0, 5.6),
        (200.0, 5.8))    # схождение, последний мост, ворота
# Награды: флаг «забрано», предмет, сколько. Верх — сундук на башенке, прямо — находка у дороги,
# низ — носит громила.
REWARDS = (("run_village_tower", "fire_arrow", 10), ("run_village_tower", "throwing_knife", 5),
           ("run_village_road", "fire_flask", 1), ("run_village_brute", "tempered_glass", 1))
# Крыши верхнего пути (x начала, x конца) — рушатся; между ними прыжки.
ROOFS = ((55.5, 66.0), (68.0, 76.0), (78.5, 86.0), (89.0, 98.0), (100.5, 104.0), (115.0, 126.0),
         (129.0, 138.0), (141.0, 152.0), (154.5, 166.0), (168.5, 178.0), (180.5, 192.0))

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
    s.box(G, "WallLeft", (LEFT - 0.5, 6.0, 0), (1, 30, 4.4), "stone_dark", True)
    s.box(G, "WallRight", (RIGHT + 0.5, 6.0, 0), (1, 30, 4.4), "stone_dark", True)
    s.box(D, "FarGround", (mid, -2, -20), (RIGHT - LEFT + 40, 4, 35.6), "mud")
    # Земля: сплошная у дома, на площади и у ворот; между ними улица — настил над оврагом.
    for name, x0, x1 in (("Home", LEFT, 24.0), ("Plaza", 41.0, 46.0), ("Meet", 200.0, 214.0), ("Gate", 232.0, RIGHT)):
        s.box(G, f"Ground{name}", ((x0 + x1) / 2, -4.25, 0), (x1 - x0, 8.5, 4.4), "mud", True)
        s.box(D, f"Bank{name}", ((x0 + x1) / 2, -2.2, 3.7), (x1 - x0, 4, 3.0), "earth_dark")
    for name, x0, x1 in (("A", 46.0, 47.0), ("B", 50.0, 197.0)):
        s.box(G, f"Street{name}", ((x0 + x1) / 2, -0.5, 0), (x1 - x0, 1.0, 4.4), "mud", True)
    # Дно оврага и погреба: два провала насмерть.
    for i, (x0, x1) in enumerate(((46.0, 80.0), (83.0, 118.0), (121.0, 200.0))):
        s.box(G, f"Ravine{i}", ((x0 + x1) / 2, LOW - 1.5, 0), (x1 - x0, 3.0, 4.4), "earth_dark", True)
    s.box(D, "RavineBack", (123.0, -3.3, -2.5), (154.0, 5.6, 0.6), "earth_dark")

    # --- 1. Разгон: улица от двери дома и первый мост — учит «дрожит → падает».
    s.box(D, "HomeWall", (1.0, 2.4, -3.2), (7.0, 4.8, 3), "plaster")
    s.roof(D, "HomeRoof", (1.0, 6.2, -3.2), (8.0, 2.8, 3.6))
    s.box(D, "HomeDoor", (2.0, 1.2, -1.66), (1.3, 2.4, 0.1), "wood")
    s.box(D, "HomeWindow", (-0.6, 2.6, -1.66), (0.9, 1.1, 0.08), "window")
    burning_house(s, "StreetHouseA", 12.0, -5.5, 7.0, 4.4, 3.0)
    burning_house(s, "StreetHouseB", 21.0, -6.0, 6.0, 4.0, 2.8)
    for i, x in enumerate((9.0, 12.0, 15.0, 19.0, 22.0)):
        piece(s, f"Fence{i}", (x, 0.6, -1.7), (2.6, 1.2, 0.12), color=(0.2, 0.14, 0.09), solid=False)
    for i, x in enumerate((11.0, 19.0)):
        piece(s, f"StreetBeam{i}", (x, 3.4, -1.4), (4.0, 0.3, 0.3), color=(0.14, 0.09, 0.06), solid=False)
        s.box(D, f"StreetPost{i}", (x - 1.9, 1.7, -1.4), (0.3, 3.4, 0.3), "wood_dark")
    fire(s, "StreetFireA", (5.0, 0.0, -1.9), (2.4, 2.8, 0.6))
    fire(s, "StreetFireB", (16.0, 0.0, -2.4), (2.0, 2.4, 0.6))
    planks = ((24.0, 28.5, MODE_FOREVER), (30.5, 34.5, MODE_FOREVER), (37.0, 41.0, MODE_RESTORES))
    for i, (x0, x1, mode) in enumerate(planks):
        color = (0.2, 0.2, 0.21) if mode == MODE_RESTORES else (0.25, 0.17, 0.11)
        piece(s, f"Plank{i}", ((x0 + x1) / 2, -0.2, 0), (x1 - x0, 0.4, 3.0), mode, color)
        s.box(D, f"PlankPost{i}", ((x0 + x1) / 2, -7.0, -1.7), (0.4, 13.0, 0.4), "wood_dark")
    fire(s, "FirstRavineFire", (32.0, -7.0, -2.4), (8.0, 4.0, 0.6), 2.6, 16.0)

    # --- 2. Площадь-развилка: колодец; вниз — пролом в мостовой, вверх — лестница на крыши,
    #        прямо — улица. У каждого проёма свой свет и блик награды вдали.
    s.cyl(D, "Well", (43.5, 0.5, -1.6), 0.9, 1.0, "stone", sides=10)
    s.box(D, "WellRoof", (43.5, 2.6, -1.6), (2.2, 0.2, 1.6), "wood_dark")
    for i, side in enumerate((-0.8, 0.8)):
        s.box(D, f"WellPost{i}", (43.5 + side, 1.6, -1.6), (0.14, 2.2, 0.14), "wood_dark")
    for i, x in enumerate((46.6, 50.4)):
        s.box(D, f"HoleEdge{i}", (x, 0.08, -1.2), (0.5, 0.16, 1.2), "char")
    s.light(D, "HoleGlow", (48.5, -2.0, 0.6), (0.45, 0.6, 0.85), 2.4, 9.0)
    s.box(D, "HoleSign", (46.2, 1.0, -1.9), (0.9, 0.5, 0.08), "moonpane", rot=(0, 0, -0.6))
    s.ladder("RoofLadder", 55.0, 0.0, TOP, 1.0)
    s.ladder_look("Roof", 55.0, 0.0, TOP)
    s.light(D, "LadderGlow", (55.0, 4.0, 0.8), (1.0, 0.8, 0.5), 2.2, 8.0)
    s.box(D, "LadderLantern", (54.3, 4.6, -0.9), (0.3, 0.45, 0.3), "lantern")
    burning_house(s, "PlazaHouse", 52.0, -6.0, 9.0, 4.6, 3.0)

    # --- 3а. Верх — крыши и чердаки (ловкость): прыжки, скат, летучие мыши, мародёр с ножом.
    #         Сорвался — упал на улицу: награда потеряна, жизнь нет.
    for i, (x0, x1) in enumerate(ROOFS):
        piece(s, f"Roof{i}", ((x0 + x1) / 2, TOP - 0.2, 0), (x1 - x0, 0.4, 3.0), color=(0.2, 0.16, 0.13))
        s.box(D, f"RoofHouse{i}", ((x0 + x1) / 2, TOP / 2 - 0.3, -3.4), (x1 - x0 - 0.8, TOP - 0.6, 2.4), "plaster")
        s.box(D, f"RoofGlow{i}", ((x0 + x1) / 2, 2.4, -2.18), (0.9, 1.1, 0.06), "fire")
    # Чердак-надстройка и стеклянный скат с неё.
    piece(s, "Attic", (108.0, TOP + 0.75, 0), (8.0, 1.5, 3.0), color=(0.22, 0.17, 0.13))
    s.instance("RoofSlide", "Objects", "glass", ["position = Vector3(113.43, 5.62, 0)", "rotation = Vector3(0, 0, -0.4636)",
               "role = 1", "size = Vector3(3.36, 0.3, 3)", "breakable = false"])
    s.enemy("RoofBatA", "bat", (82.0, TOP + 3.2, 0))
    s.enemy("RoofBatB", "bat", (133.0, TOP + 3.2, 0))
    s.enemy("RoofKnife", "bandit_knife", (94.5, TOP, 0))
    # Башенка с сундуком: её огонь виден с площади. Наверх — по лестнице; под помостом можно
    # пробежать мимо — это цена награды.
    piece(s, "TowerDeck", (174.5, TOP + TOWER - 0.2, 0), (7.0, 0.4, 3.0), color=(0.22, 0.17, 0.13))
    s.ladder("TowerLadder", 170.5, TOP, TOWER, 1.0)
    s.ladder_look("Tower", 170.5, TOP, TOWER)
    s.box(D, "TowerBack", (174.5, TOP + TOWER + 1.6, -1.8), (6.0, 3.2, 0.5), "stone")
    s.roof(D, "TowerRoof", (174.5, TOP + TOWER + 4.0, -1.4), (7.5, 1.8, 2.4), "thatch")
    s.light(D, "TowerGlow", (175.0, TOP + TOWER + 1.6, 0.6), (1.0, 0.8, 0.5), 2.6, 10.0)
    s.chest("TowerChest", (175.0, TOP + TOWER, -0.6), 120, "run_village_tower", ("fire_arrow",) * 10 + ("throwing_knife",) * 5)

    # --- 3б. Прямо — улица (просто): балки-прыжки, один мародёр, находка у дороги.
    for i, x in enumerate((70.0, 122.0, 165.0)):
        piece(s, f"StreetLog{i}", (x, 0.45, 0), (1.0, 0.9, 3.0), color=(0.14, 0.09, 0.06), offset=1.0)
    s.enemy("StreetKnife", "bandit_knife", (104.0, 0.0, 0))
    s.node("RoadFind", 'type="Area3D"', "Objects", ["position = Vector3(150.0, 0.0, 0)", 'script = ExtResource("pickup")',
           'item_id = &"fire_flask"', 'flag = &"run_village_road"', 'pickup_prompt = "Схватить склянку"',
           "look_size = Vector3(0.25, 0.4, 0.25)", "look_color = Color(0.5, 0.2, 0.1, 1)"])
    for i, x in enumerate((62.0, 88.0, 112.0, 140.0, 178.0)):
        fire(s, f"RoadFire{i}", (x, 0.0, -1.9), (2.0, 2.4, 0.5))
    s.box(D, "Cart", (84.0, 0.7, -1.8), (2.6, 0.5, 1.2), "wood")
    s.cyl(D, "CartWheel", (83.2, 0.5, -1.1), 0.5, 0.12, "wood_dark", rot=(1.5708, 0, 0))

    # --- 3в. Низ — овраг и погреба (бой): крысы, два провала, в тесном погребе громила с наградой.
    s.box(G, "RavineWall", (45.5, -3.25, 0), (1.0, 4.5, 4.4), "earth_dark", True)
    for i, x in enumerate((66.0, 96.0, 110.0)):
        s.enemy(f"Rat{i}", "rat", (x, LOW, 0))
    s.enemy("Brute", "bandit_heavy", (140.0, LOW, 0), ['drop_item = &"tempered_glass"', 'drop_flag = &"run_village_brute"'])
    # Погреб: низкий свод — громилу не перепрыгнуть; бочки, свет.
    s.box(G, "CellarVault", (139.0, LOW + 3.3, 0), (20.0, 1.4, 4.4), "stone_dark", True)
    # Завал за погребом: через него — только по лестнице.
    s.box(G, "Rubble", (155.0, LOW + RUBBLE / 2, 0), (6.0, RUBBLE, 4.4), "char", True)
    s.ladder("RubbleLadder", 151.5, LOW, RUBBLE, 1.0)
    s.ladder_look("Rubble", 151.5, LOW, RUBBLE)
    for i, x in enumerate((129.0, 149.0)):
        s.box(D, f"CellarArch{i}", (x, LOW + 1.3, -1.9), (0.8, 2.6, 0.6), "stone")
    for i, x in enumerate((133.0, 136.0, 146.0)):
        s.cyl(D, f"Barrel{i}", (x, LOW + 0.6, -1.6), 0.5, 1.2, "wood", sides=10)
    s.light(D, "CellarLight", (139.0, LOW + 1.8, 0.8), (1.0, 0.55, 0.25), 2.4, 11.0)
    for i, x in enumerate((58.0, 76.0, 100.0, 160.0, 184.0)):
        fire(s, f"RavineFire{i}", (x, LOW, -1.8), (1.8, 2.0, 0.5), 2.0, 9.0)
    for i, x in enumerate((81.5, 119.5)):
        s.light(D, f"PitGlow{i}", (x, LOW - 3.0, 0.0), (1.0, 0.4, 0.15), 2.0, 7.0)
    s.ladder("RavineLadder", 199.5, LOW, -LOW, 1.0)
    s.ladder_look("Ravine", 199.5, LOW, -LOW)

    # --- 4. Схождение: площадь у ворот, последний мост, ворота.
    last = ((214.0, 218.5, MODE_FOREVER), (220.5, 224.5, MODE_FOREVER), (227.0, 232.0, MODE_RESTORES))
    for i, (x0, x1, mode) in enumerate(last):
        color = (0.2, 0.2, 0.21) if mode == MODE_RESTORES else (0.25, 0.17, 0.11)
        piece(s, f"Final{i}", ((x0 + x1) / 2, -0.2, 0), (x1 - x0, 0.4, 3.0), mode, color)
        s.box(D, f"FinalPost{i}", ((x0 + x1) / 2, -7.0, -1.7), (0.4, 13.0, 0.4), "wood_dark")
    fire(s, "LastRavineFire", (223.0, -7.0, -2.4), (10.0, 4.0, 0.6), 2.6, 16.0)
    burning_house(s, "MeetHouse", 206.0, -6.0, 8.0, 4.4, 3.0)
    s.box(D, "GatePostA", (243.5, 2.6, -1.4), (0.8, 5.2, 0.8), "wood_dark")
    s.box(D, "GatePostB", (248.5, 2.6, -1.4), (0.8, 5.2, 0.8), "wood_dark")
    s.box(D, "GateTop", (246.0, 5.4, -1.4), (6.0, 0.6, 0.8), "wood_dark")
    s.fence(D, "Palisade", 233.0, 243.0, -1.8, mat="wood_dark")
    fire(s, "GateFire", (236.0, 0.0, -2.2), (2.0, 2.4, 0.6))

    # --- Жизнь на заднем плане (§9.2): деревня гибнет не только под ногами героя.
    for i, (x, y, kind) in enumerate(((18.0, 0.0, 0), (60.0, 0.0, 2), (118.0, 0.0, 0), (158.0, 0.0, 1), (208.0, 0.0, 2), (238.0, 0.0, 0))):
        s.node(f"Background{i}", 'type="Node3D"', D, [f"position = Vector3({x}, {y}, -4.6)", 'script = ExtResource("bgscene")',
               f"kind = {kind}", "trigger_range = 16.0"])
    # Дым слоями: над улицей и в овраге.
    for i in range(6):
        s.veil(D, f"Smoke{i}", (20.0 + i * 42.0, 7.5, -3.0), (46, 9), "fog_thick")
    for i in range(4):
        s.veil(D, f"RavineSmoke{i}", (66.0 + i * 40.0, LOW + 2.4, -2.0), (42, 4), "fog_veil")
    # Передний план: обгоревшие столбы и ограда — тёмные силуэты, мимо которых бежит герой.
    for i, x in enumerate(range(12, 250, 23)):
        s.box(D, f"FrontPost{i}", (float(x), 1.6 + (i % 3) * 0.5, 3.4), (0.35, 3.2 + (i % 3), 0.35), "char", rot=(0, 0, 0.06 * (i % 5 - 2)))

    pace = ", ".join(f"{x}, {v}" for x, v in PACE)
    flags = ", ".join(f'&"{f}"' for f, _, _ in REWARDS)
    items = ", ".join(f'&"{i}"' for _, i, _ in REWARDS)
    counts = ", ".join(str(c) for _, _, c in REWARDS)
    s.node("Run", 'type="Node3D"', "Objects", ['script = ExtResource("run")', 'next_room = &"run_exit"',
           'next_shard = NodePath("Objects/MirrorShard")', 'echo_spawn = NodePath("Spawns/HeroEcho")', 'done_flag = &"run_village_done"',
           f"start_x = {START_X}", f"head_start = {HEAD_START}", f"pace = PackedVector2Array({pace})", f"max_slack = {MAX_SLACK}",
           f"reward_flags = Array[StringName]([{flags}])", f"reward_items = Array[StringName]([{items}])",
           f"reward_counts = Array[int]([{counts}])", f"fire_levels = PackedFloat32Array({TOP}, 0.0, {LOW})"])
    s.node("Ambience", 'type="Node"', "Objects", ['script = ExtResource("ambience")',
           'calls = PackedStringArray("…бегите!..", "…горит, всё горит!..")', "every = 9.0"])
    s.marker("PlayerStart", (2.0, 0.1, 0))
    s.door("DoorOut", 246.0, 0, "run_exit", "Spawns/FromVillage", "Бежать из деревни")
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
