"""Уровень «Край Мёртвого Леса» (level_concept/Edge of the Dead Forest, art/refs/Edge of the Dead Forest).

Семь комнат graybox: кладбищенские ворота → кладбище → стена леса → поваленный гигант → корневой
лабиринт → болото → мёртвая деревня Кузнеца. Запуск из корня проекта: python tools/levels/build_forest.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from scenery import Scene  # noqa: E402

G, D = "Geometry", "Decor"
DUSK = {"bg": (0.035, 0.04, 0.06), "amb": (0.3, 0.33, 0.42), "amb_e": 0.36, "fog": (0.13, 0.14, 0.18), "fog_d": 0.02}
FOREST = {"bg": (0.02, 0.025, 0.03), "amb": (0.26, 0.3, 0.32), "amb_e": 0.34, "fog": (0.11, 0.13, 0.14), "fog_d": 0.028}
SWAMP = {"bg": (0.025, 0.03, 0.025), "amb": (0.28, 0.32, 0.25), "amb_e": 0.34, "fog": (0.13, 0.15, 0.12), "fog_d": 0.03}
DEAD = {"bg": (0.03, 0.03, 0.035), "amb": (0.32, 0.31, 0.34), "amb_e": 0.34, "fog": (0.15, 0.15, 0.17), "fog_d": 0.026}


def firs(s, left, right, z0=-26.0, step=4.0):
    for i in range(int((right - left) / step) + 1):
        h = 10 + (i * 7 % 5)
        s.cyl(D, f"Fir{i}", (left + i * step, h / 2 - 0.5, z0 - (i % 3) * 3), 2.0, h, "fir", cone=True, sides=6)


def save(scene, file):
    Path(f"world/rooms/{file}.tscn").write_text(scene.text(), encoding="utf-8")


# ---------------------------------------------------------------- Кадр 1: вход на кладбище
def cemetery_gate():
    s = Scene("CemeteryGate", "cemetery_gate", 44.0, DUSK)
    s.frame(-22, 22)
    firs(s, -24, 24)
    # Слева дорога из деревни: тёплый свет позади.
    s.box(D, "VillageHouse", (-18.5, 2.2, -5.5), (6, 4.4, 3), "plaster")
    s.roof(D, "VillageRoof", (-18.5, 6.2, -5.5), (7, 3.6, 3.6))
    for i, (x, y) in enumerate(((-20.0, 2.6), (-17.0, 3.2))):
        s.box(D, f"VillageWindow{i}", (x, y, -3.95), (0.8, 1.0, 0.08), "window")
    s.light(D, "VillageGlow", (-18.0, 2.8, -2.2), (1.0, 0.6, 0.28), 1.6, 10.0)
    s.fence(D, "WoodFence", -21.5, -11.5, -1.8, mat="wood_dark")
    # Готическая арка, калитка и фонарь — последний человеческий огонь.
    s.box(D, "PillarLeft", (-3.6, 3.0, -1.3), (1.0, 6.0, 1.0), "stone")
    s.box(D, "PillarRight", (0.4, 3.0, -1.3), (1.0, 6.0, 1.0), "stone")
    s.box(D, "ArchTop", (-1.6, 6.3, -1.3), (5.2, 0.7, 1.0), "stone")
    s.statue(D, "Mourner", -3.6, -1.3, ground=6.65, scale=0.45)
    for i in range(6):
        s.box(D, f"GateBar{i}", (-2.9 + i * 0.12, 1.6, -0.6 - i * 0.1), (0.06, 3.2, 0.06), "iron")
    s.box(D, "GateTop", (-2.6, 3.1, -0.85), (0.8, 0.08, 0.6), "iron", rot=(0, 0.9, 0))
    s.box(D, "LanternArm", (-3.0, 4.1, -0.7), (0.7, 0.1, 0.1), "iron")
    s.box(D, "Lantern", (-2.75, 3.6, -0.7), (0.36, 0.58, 0.36), "lantern")
    s.light(D, "LanternLight", (-2.6, 3.4, 0.4), (1.0, 0.62, 0.3), 3.0, 11.0, True)
    # Кладбищенская стена с пиками и сгнивший святой в глубине.
    s.box(D, "CemeteryWall", (8.0, 1.3, -1.9), (15.0, 2.6, 0.6), "stone_dark")
    s.fence(D, "WallSpikes", 0.8, 15.2, -1.9, y=2.6)
    s.statue(D, "Saint", 7.0, -7.0, scale=1.5, broken=True)
    for i, x in enumerate((3.0, 5.5, 9.0, 11.5, 13.5)):
        s.grave(D, f"Grave{i}", x, -4.0 - (i % 2), tilt=(i % 3 - 1) * 0.12, cross=i % 2 == 0)
    s.crow(D, "CrowA", 5.0, 2.6, -1.9)
    s.crow(D, "CrowB", 12.0, 2.6, -1.9)
    # Корень обнимает стену: по нему лезут на пост могильщика.
    s.box(D, "RootClimbA", (-7.7, 2.2, -0.9), (1.1, 4.8, 1.0), "root", rot=(0, 0, 0.18))
    s.box(D, "RootClimbB", (-4.0, 5.0, -1.2), (7.0, 0.9, 1.0), "root", rot=(0, 0, -0.1))
    s.ladder("RootClimb", -7.8, 0.0, 4.4, 1.0)
    # Пост могильщика: толстый настил, гнилая доска над ямой с кольями, сундук за ней.
    s.box(G, "PostDeckA", (-3.4, 3.7, 0), (7.2, 1.4, 4), "wood", True)
    s.box(G, "PitFloor", (1.0, 3.05, 0), (1.6, 0.1, 4), "wood_dark", True)
    s.box(G, "PitWallBack", (1.0, 3.7, -1.9), (1.6, 1.4, 0.2), "wood_dark")
    s.box(G, "PostDeckB", (3.0, 3.7, 0), (2.4, 1.4, 4), "wood", True)
    for i, x in enumerate((-6.8, -3.0, 0.0, 4.0)):
        s.box(D, f"DeckPost{i}", (x, 1.5, -1.2), (0.3, 3.0, 0.3), "wood_dark")
        s.box(D, f"RoofPost{i}", (x, 5.8, -1.6), (0.2, 2.8, 0.2), "wood_dark")
    s.box(D, "PostRoof", (-1.4, 7.3, -1.0), (9.0, 0.2, 2.6), "wood_dark", rot=(0, 0, 0.05))
    s.used.add("rotten")
    s.instance("RottenPlank", "Objects", "glass", ["position = Vector3(1.0, 4.25, 0)", "size = Vector3(1.6, 0.3, 4)",
               "crumble_time = 0.35", 'look = SubResource("Mat_rotten")'])
    s.instance("PitSpikes", "Objects", "spikes", ["position = Vector3(1.0, 3.1, 0)", "width = 1.4", "spike_height = 0.5",
               "trap_damage = 18.0", "non_lethal = true"])
    s.chest("PostChest", (3.2, 4.4, -0.8), 120, "cem_gate_chest", ("tempered_glass",))
    # Справа мёртвые деревья и стена тумана.
    s.dead_tree(D, "TreeA", 13.0, -3.5, 9.0)
    s.dead_tree(D, "TreeB", 18.5, -5.0, 10.0)
    s.veil(D, "FogFar", (16.0, 3.5, -2.6), (16, 8))
    s.veil(D, "FogNear", (21.0, 2.0, 1.0), (6, 5), "fog_thick")
    s.tuft(D, "FrontTuft", -9.0, -0.2, 3.2)
    s.rocks(D, "FrontRocks", 9.0, -0.2, 3.4)
    s.grave(D, "FrontCross", 15.0, 3.0, ground=-0.2, tilt=0.25, cross=True)
    s.marker("FromChapel", (-19.8, 0.1, 0))
    s.marker("FromCemetery", (19.8, 0.1, 0))
    s.door("DoorToChapel", -21.3, 0, "chapel_yard", "Spawns/FromForest", "Вернуться к часовне")
    s.door("DoorToCemetery", 21.3, 0, "cemetery", "Spawns/FromGate", "Войти на кладбище")
    save(s, "cemetery_gate")


# ---------------------------------------------------------------- Кадр 1.2: кладбище и мародёры
def cemetery():
    s = Scene("Cemetery", "cemetery", 56.0, DUSK)
    s.frame(-28, 28)
    firs(s, -30, 30)
    # Верхняя терраса со склепом и лестницы.
    s.box(G, "Terrace", (11.0, 1.2, 0), (14.0, 2.4, 4.4), "stone", True)
    s.box(G, "StairsUp", (2.0, 0.85, 0), (4.7, 0.6, 4.4), "stone", True, rot=(0, 0, 0.54))
    s.box(G, "StairsDown", (20.0, 0.85, 0), (4.7, 0.6, 4.4), "stone", True, rot=(0, 0, -0.54))
    s.box(D, "CryptBack", (11.0, 4.6, -3.0), (5.0, 4.4, 1.2), "stone_dark")
    s.roof(D, "CryptRoof", (11.0, 7.5, -3.0), (5.8, 1.6, 1.6), "stone_dark")
    s.box(D, "CryptDark", (11.0, 3.6, -2.38), (1.8, 2.4, 0.05), "char")
    s.node("CryptDoor", 'type="Node3D"', D, ["position = Vector3(10.1, 2.4, -2.3)"])
    s.box(f"{D}/CryptDoor", "Leaf", (0.9, 1.2, 0), (1.8, 2.4, 0.12), "wood_dark")
    s.box(D, "Sarcophagus", (8.3, 2.8, -1.3), (2.2, 0.7, 1.0), "stone", rot=(0, 0.2, 0.15))
    s.box(D, "Coffin", (13.8, 2.65, -1.4), (1.9, 0.5, 0.7), "wood", rot=(0.4, -0.3, 0))
    s.candles(D, "CryptCandles", 9.4, 2.4, -1.9)
    s.candles(D, "CryptCandles2", 12.4, 2.4, -1.9, 2, False)
    # Мародёры ждут в склепе (RobberEvent выпустит).
    s.enemy("RobberHeavy", "bandit_heavy", (9.5, 2.4, -2.0), ['partner_path = NodePath("../RobberKnife")'])
    s.enemy("RobberKnife", "bandit_knife", (12.5, 2.4, -2.0), ['partner_path = NodePath("../RobberHeavy")'])
    s.node("RobberEvent", 'type="Node3D"', "Objects", ["position = Vector3(11, 2.4, 0)", 'script = ExtResource("robbers")',
           "trigger_x = 2.0", "landing = Vector2(-1.5, 2.0)", 'door_path = NodePath("../../Decor/CryptDoor")'])
    # Нижний путь: запечатанный склеп (будущее подземелье).
    s.box(D, "SealedCrypt", (-10.0, 2.2, -3.0), (5.0, 4.4, 1.6), "stone_dark")
    s.roof(D, "SealedRoof", (-10.0, 5.2, -3.0), (5.8, 1.6, 2.0), "stone_dark")
    s.box(D, "SealedSlab", (-10.0, 1.2, -2.15), (1.8, 2.4, 0.1), "iron")
    s.door("SealedCryptDoor", -10.0, 0, "cemetery", "Spawns/FromGate", "Открыть склеп",
           ['required_flag = &"crypt_key"', 'locked_text = "Склеп запечатан. Тяжёлая плита не сдвинется — пока."',
            "door_size = Vector3(1.6, 2.4, 0.15)", "door_color = Color(0.08, 0.08, 0.09, 1)"])
    # Ангелы, могилы, деревья, фонарь.
    s.statue(D, "Angel", -20.0, -3.4, scale=0.9)
    s.statue(D, "Saint", 22.5, -4.5, scale=1.1)
    for i, x in enumerate((-24.0, -21.5, -16.0, -13.5, -5.5, -2.0, 5.0, 16.5, 24.5, 26.5)):
        s.grave(D, f"Grave{i}", x, -1.7 - (i % 3) * 1.2, tilt=(i % 3 - 1) * 0.15, cross=i % 2 == 1)
    for i, x in enumerate((6.0, 9.0, 13.0, 16.0)):
        s.grave(D, f"TerraceGrave{i}", x, -4.2, ground=2.4, cross=i % 2 == 0)
    s.dead_tree(D, "TreeA", -26.0, -3.0, 10.0, r=0.5)
    s.dead_tree(D, "TreeB", 0.0, -5.5, 9.0)
    s.lantern_post(D, "Lamp", -23.5, -1.2)
    s.fence(D, "BackFence", -27.0, -12.0, -2.2)
    s.veil(D, "Fog", (0.0, 3.0, -2.8), (56, 6))
    s.veil(D, "FogLow", (6.0, 0.8, 1.2), (30, 1.6), "fog_veil")
    s.fence(D, "FrontFence", -26.0, -18.0, 2.5, mat="wood_dark")
    s.grave(D, "FrontCross", -6.0, 3.0, ground=-0.2, tilt=-0.3, cross=True)
    s.rocks(D, "FrontRocks", 14.0, -0.2, 3.4)
    s.shard("MirrorShard", 24.0, 0.0)
    s.marker("FromGate", (-26.0, 0.1, 0))
    s.marker("FromForest", (26.0, 0.1, 0))
    s.door("DoorToGate", -27.3, 0, "cemetery_gate", "Spawns/FromCemetery", "Назад к воротам")
    s.door("DoorToForest", 27.3, 0, "forest_wall", "Spawns/FromCemetery", "В лес")
    save(s, "cemetery")


# ---------------------------------------------------------------- Кадр 2: стена леса
def forest_wall():
    s = Scene("ForestWall", "forest_wall", 60.0, FOREST, sun_energy=0.18)
    s.frame(-30, 30)
    for i, x in enumerate(range(-27, 30, 6)):
        s.giant_tree(D, f"Giant{i}", float(x), -4.5 - (i % 2) * 1.5, 24.0, r=2.0 + (i % 3) * 0.4)
        s.box(D, f"Fused{i}", (x + 3.0, 9.0, -6.8), (4.0, 22.0, 1.0), "bark")
        for j in range(3):
            s.box(D, f"Vine{i}_{j}", (x + 1.2 + j * 0.7, 10.0 - j * 1.3, -3.2), (0.07, 5.0 + j, 0.07), "moss")
    # Верхний маршрут: лианы, площадки охотников, лестница вниз.
    s.ladder("Vines", -24.0, 0.0, 6.0, 1.0)
    s.ladder_look("Vines", -24.0, 0.0, 6.0, "moss", rungs=False)
    for i, (x, y, w) in enumerate(((-20.0, 6.0, 7.0), (-10.0, 6.6, 8.0), (1.0, 6.0, 8.0), (11.5, 6.6, 7.0))):
        s.box(G, f"Platform{i}", (x, y - 0.2, 0), (w, 0.4, 3.0), "wood", True)
        for side in (-1, 1):
            s.box(D, f"PlatformRope{i}_{side}", (x + side * (w / 2 - 0.3), y + 4.0, -0.6), (0.05, 8.0, 0.05), "rope")
    s.box(D, "WatchRoof", (1.0, 9.2, -0.4), (8.4, 0.2, 3.0), "wood_dark", rot=(0, 0, -0.06))
    s.ladder("HunterLadder", 16.0, 0.0, 6.6, -1.0)
    s.ladder_look("Hunter", 16.0, 0.0, 6.6)
    s.box(D, "CollapsedPlatform", (22.0, 2.5, -2.4), (6.0, 0.3, 2.4), "wood", rot=(0, 0, 0.5))
    s.box(D, "CollapsedLeg", (20.0, 1.2, -2.4), (0.25, 2.6, 0.25), "wood_dark", rot=(0, 0, -0.4))
    # Скелет разведчика, письмо, припасы.
    s.box(D, "ScoutRibs", (3.0, 6.15, -0.9), (0.9, 0.25, 0.5), "bone")
    s.sphere(D, "ScoutSkull", (3.7, 6.25, -0.9), 0.18, "bone")
    s.note("ScoutLetter", 2.0, 6.0, "Письмо разведчика", [
        "«Третью ночь из тумана смотрят глаза. Не звериные.",
        "Охотники бросили посты. Я останусь, пока не сменят.",
        "Если найдёте — передайте в деревню: в лес не ходить.»"])
    s.node("ScoutSupplies", 'type="Area3D"', "Objects", ["position = Vector3(-1.5, 6.0, 0)", 'script = ExtResource("pickup")',
           'flag = &"scout_supplies"', "echoes = 80", 'pickup_prompt = "Забрать припасы разведчика"',
           "look_size = Vector3(0.6, 0.35, 0.45)", "look_color = Color(0.4, 0.3, 0.2, 1)"])
    s.enemy("BatA", "bat", (-10.5, 5.7, 0))
    s.enemy("BatB", "bat", (11.0, 5.7, 0))
    s.enemy("RatA", "rat", (4.0, 0.0, 0))
    s.enemy("RatB", "rat", (19.0, 0.0, 0))
    s.veil(D, "Fog", (0.0, 4.0, -3.6), (60, 10))
    s.tuft(D, "FrontTuft", -14.0, -0.2, 3.2, "moss")
    s.rocks(D, "FrontRocks", 7.0, -0.2, 3.4)
    s.marker("FromCemetery", (-28.0, 0.1, 0))
    s.marker("FromGiant", (28.0, 0.1, 0))
    s.door("DoorToCemetery", -29.3, 0, "cemetery", "Spawns/FromForest", "Назад на кладбище")
    s.door("DoorToGiant", 29.3, 0, "fallen_giant", "Spawns/FromWall", "Дальше в лес")
    save(s, "forest_wall")


# ---------------------------------------------------------------- Кадр 3: поваленный гигант и хижина
def fallen_giant():
    s = Scene("FallenGiant", "fallen_giant", 60.0, FOREST, sun_energy=0.18)
    s.box(G, "GroundLeft", (-23.0, -9.0, 0), (14.0, 18.0, 4.4), "mud", True)
    s.box(G, "Cliff", (24.0, -7.0, 0), (12.0, 22.0, 4.4), "stone_dark", True)
    s.box(G, "RavineFloor", (1.0, -16.0, 0), (34.0, 4.0, 4.4), "mud", True)
    s.box(G, "WallLeft", (-30.5, 0.0, 0), (1.0, 44.0, 4.4), "stone_dark", True)
    s.box(G, "WallRight", (30.5, 0.0, 0), (1.0, 44.0, 4.4), "stone_dark", True)
    s.box(D, "FarGround", (0.0, -16.0, -20.0), (100.0, 4.0, 35.6), "mud")
    firs(s, -32, 32, -28.0)
    # Ствол: наклонный от края обрыва и ровный над пропастью.
    s.box(G, "TrunkSlope", (-7.0, 1.55, 0), (18.6, 1.2, 2.6), "bark", True, rot=(0, 0, 0.2))
    s.box(G, "TrunkMid", (3.0, 3.4, 0), (2.0, 1.2, 2.6), "bark", True)
    s.box(G, "TrunkTop", (11.8, 3.4, 0), (12.4, 1.2, 2.6), "bark", True)
    s.box(D, "TrunkUnder", (3.0, 1.9, -0.6), (30.0, 2.2, 2.4), "bark", rot=(0, 0, 0.08))
    for i, x in enumerate((-12.0, -4.0, 6.0, 15.0)):
        s.box(D, f"Moss{i}", (x, 2.0 + (x + 16) * 0.12 if x < 2 else 4.05, 0.9), (3.0, 0.12, 0.6), "moss", rot=(0, 0, 0.2 if x < 2 else 0))
        s.box(D, f"Hanging{i}", (x + 1.0, -1.0, 0.6), (0.08, 5.0, 0.08), "moss")
    for i, x in enumerate((-8.0, 2.0, 12.0)):
        s.box(D, f"Stub{i}", (x, 5.6 if x > 2 else 3.4, -0.9), (0.5, 1.8, 0.5), "bark", rot=(0, 0, 0.4))
    # Хижина разбойников на стволе, в разрезе.
    s.box(D, "HutBack", (10.0, 6.2, -1.4), (8.0, 4.4, 0.3), "wood_dark")
    s.box(D, "HutSideL", (6.1, 6.2, -0.6), (0.25, 4.4, 1.8), "wood_dark")
    s.box(D, "HutSideR", (13.9, 6.2, -0.6), (0.25, 4.4, 1.8), "wood_dark")
    s.roof(D, "HutRoof", (10.0, 9.2, -0.6), (9.6, 1.8, 3.2), "thatch")
    s.box(D, "Table", (8.0, 4.9, -0.9), (1.8, 0.1, 0.8), "wood")
    s.box(D, "TableLeg", (8.0, 4.45, -0.9), (0.15, 0.9, 0.15), "wood_dark")
    for i, x in enumerate((7.3, 7.7, 8.6)):
        s.cyl(D, f"Jug{i}", (x, 5.15, -1.0), 0.12, 0.4, "rust", sides=8)
    s.box(D, "WeaponRack", (11.0, 5.6, -1.2), (1.6, 1.8, 0.2), "wood_dark")
    for i in range(3):
        s.box(D, f"Blade{i}", (10.5 + i * 0.5, 5.7, -1.05), (0.06, 1.4, 0.06), "iron", rot=(0, 0, 0.1))
    s.cyl(D, "RopeCoil", (6.8, 4.15, -1.0), 0.35, 0.3, "rope", sides=10)
    s.box(D, "Loot", (9.5, 4.2, -1.1), (0.8, 0.4, 0.5), "cloth")
    s.box(D, "HutLantern", (12.6, 7.2, -0.6), (0.3, 0.45, 0.3), "lantern")
    s.light(D, "HutLight", (11.0, 6.8, 0.6), (1.0, 0.6, 0.3), 1.8, 7.0)
    s.note("BanditNote", 8.0, 4.0, "Записка разбойников", [
        "«Травницу держать до четверга. Купец из-за леса даст",
        "за неё серебром — травы знает, лечить умеет.",
        "Воды давать мало, чтоб не сбежала.»"])
    s.node("Herbalist", 'type="Area3D"', "Objects", ["position = Vector3(12.8, 4.0, 0)", 'script = ExtResource("captive")',
           'flag = &"herbalist_rescued"', 'captive_name = "Травница"', 'free_prompt = "Развязать Травницу"',
           'thanks = PackedStringArray("Мальчик?.. Воды… Спасибо. Они бы меня продали.", "Я вернусь к часовне. Найди меня там.")'])
    s.shard("MirrorShard", 16.0, 4.0)
    s.hanging_cage(D, "Cage", -14.0, 7.5, -0.8)
    s.box(D, "CageBranch", (-14.0, 10.2, -0.8), (6.0, 0.3, 0.3), "bark", rot=(0, 0, 0.1))
    # Дно пропасти: туман, крысиное гнездо, колья и лестница наверх.
    for i, y in enumerate((-3.0, -9.0)):
        s.veil(D, f"RavineFog{i}", (1.0, y, 0.8 if i else -1.2), (34.0, 5.0), "fog_veil")
    # Верёвочная лестница свисает в трещину ствола — туда же, куда падают.
    s.ladder("RavineLadder", 4.8, -14.0, 18.0, 1.0)
    s.enemy("RatA", "rat", (-12.0, -14.0, 0))
    s.enemy("RatB", "rat", (-8.0, -14.0, 0))
    s.enemy("RatC", "rat", (-4.0, -14.0, 0))
    s.instance("RavineSpikes", "Objects", "spikes", ["position = Vector3(12.0, -14.0, 0)", "width = 3.0", "trap_damage = 25.0"])
    for i, x in enumerate((-10.0, -3.0, 3.0)):
        s.box(D, f"Bones{i}", (x, -13.8, -1.0), (0.8, 0.2, 0.4), "bone")
    s.marker("FromWall", (-28.0, 0.1, 0))
    s.marker("FromMaze", (28.0, 4.1, 0))
    s.door("DoorToWall", -29.3, 0, "forest_wall", "Spawns/FromGiant", "Назад к стене леса")
    s.door("DoorToMaze", 29.3, 4.0, "root_maze", "Spawns/FromGiant", "В корневой лабиринт")
    save(s, "fallen_giant")


# ---------------------------------------------------------------- Кадр 4: корневой лабиринт
## Ярусы (верх пола): дно бездны −10, нижняя тропа 3, главный путь 8, верхние 13 и 18.
## Над каждой лестницей — дыра в ярусе, наверху пол со стороны exit_dir.
ROOTS = {"bg": (0.02, 0.025, 0.03), "amb": (0.26, 0.3, 0.32), "amb_e": 0.34, "fog": (0.17, 0.19, 0.21), "fog_d": 0.042,
         "fog_h": 2.0, "fog_hd": 0.2}


def root_maze():
    s = Scene("RootMaze", "root_maze", 56.0, ROOTS, sun_energy=0.12)

    def tier(name, x0, x1, y):
        s.box(G, name, ((x0 + x1) / 2, y - 0.4, 0), (x1 - x0, 0.8, 2.6), "root", True)

    s.box(G, "AbyssFloor", (0.0, -12.0, 0), (56.0, 4.0, 4.4), "mud", True)
    s.box(G, "WallLeft", (-28.5, 9.0, 0), (1.0, 42.0, 4.4), "stone_dark", True)
    s.box(G, "WallRight", (28.5, 9.0, 0), (1.0, 42.0, 4.4), "stone_dark", True)
    s.box(G, "EntryRoots", (-23.0, -1.0, 0), (10.0, 18.0, 4.4), "root", True)
    s.box(G, "ExitRoots", (23.0, -1.0, 0), (10.0, 18.0, 4.4), "root", True)
    # Главный путь: дыры над лестницами с нижней тропы, подрубленный корень над бездной.
    tier("RootBridgeA1", -18.0, -13.8, 8.0)
    tier("RootBridgeA2", -12.2, -1.4, 8.0)
    s.used.add("rotten")
    for i, x in enumerate((-0.7, 0.7)):
        s.instance(f"SawnRoot{i}", "Objects", "glass", [f"position = Vector3({x}, 7.75, 0)", "size = Vector3(1.4, 0.5, 2.6)",
                   "crumble_time = 0.45", 'look = SubResource("Mat_rotten")'])
    s.box(D, "SawMark", (0.0, 7.9, 1.32), (0.15, 0.5, 0.05), "char")
    tier("RootBridgeB", 1.4, 12.6, 8.0)
    tier("RootBridgeB2", 14.2, 18.0, 8.0)
    # Нижняя тропа: от стены до стены, один разрыв под подрубленным корнем — в бездну.
    tier("RootLowA", -18.0, -1.9, 3.0)
    tier("RootLowB", 1.9, 18.0, 3.0)
    s.ladder("LowLadderA", -13.0, 3.0, 5.0, 1.0)
    s.ladder("LowLadderB", 13.4, 3.0, 5.0, 1.0)
    # Тайник в расколотом корне на нижней тропе.
    s.box(D, "HollowBack", (5.5, 4.4, -1.9), (3.6, 3.0, 0.4), "char")
    s.box(D, "HollowArchL", (3.6, 4.4, -1.6), (0.6, 3.2, 0.8), "root", rot=(0, 0, 0.15))
    s.box(D, "HollowArchR", (7.4, 4.4, -1.6), (0.6, 3.2, 0.8), "root", rot=(0, 0, -0.15))
    s.box(D, "HollowTop", (5.5, 6.1, -1.6), (4.6, 0.6, 0.8), "root")
    s.chest("RootCache", (5.5, 3.0, -1.0), 200, "root_cache", ("flask_vessel",))
    s.candles(D, "CacheCandles", 4.2, 3.0, -1.5)
    # Верхний ярус 1: над туманом, прыжок через разрыв, припасы охотника.
    s.ladder("UpLadderA", -8.0, 8.0, 5.0, 1.0)
    tier("RootHighA", -16.0, -8.8, 13.0)
    tier("RootHighB", -7.2, 5.0, 13.0)
    tier("RootHighC", 7.5, 14.0, 13.0)
    s.node("HunterSupplies", 'type="Area3D"', "Objects", ["position = Vector3(-14.0, 13.0, 0)", 'script = ExtResource("pickup")',
           'flag = &"root_supplies"', "echoes = 120", 'pickup_prompt = "Забрать припасы охотника"',
           "look_size = Vector3(0.6, 0.35, 0.45)", "look_color = Color(0.4, 0.3, 0.2, 1)"])
    # Верхний ярус 2: брошенный пост охотника, его лук.
    s.ladder("UpLadderB", 12.6, 13.0, 5.0, -1.0)
    tier("RootTop", 4.0, 11.8, 18.0)
    s.box(D, "PostRail", (7.9, 18.9, -1.0), (7.6, 0.1, 0.1), "wood_dark")
    for i, x in enumerate((4.4, 7.9, 11.4)):
        s.box(D, f"PostPole{i}", (x, 19.4, -1.0), (0.14, 2.8, 0.14), "wood_dark")
    s.box(D, "PostRoof", (7.9, 20.9, -0.6), (8.4, 0.18, 2.4), "wood_dark", rot=(0, 0, 0.05))
    s.box(D, "HunterRibs", (7.2, 18.15, -0.8), (0.9, 0.25, 0.5), "bone")
    s.sphere(D, "HunterSkull", (7.9, 18.25, -0.8), 0.18, "bone")
    s.note("HunterNote", 9.0, 18.0, "Записка охотника", [
        "«Из тумана не спуститься — внизу что-то ждёт.",
        "Лук я берёг для сына. Пусть возьмёт тот, кто дойдёт сюда.»"])
    s.node("BowHunter", 'type="Area3D"', "Objects", ["position = Vector3(5.5, 18.0, 0)", 'script = ExtResource("pickup")',
           'item_id = &"bow_hunter"', 'flag = &"got_bow_hunter"', 'pickup_prompt = "Взять охотничий лук"',
           "look_size = Vector3(1.2, 0.08, 0.08)", "look_color = Color(0.5, 0.36, 0.2, 1)"])
    # Дно бездны: крысы у стены, смертельные колья, летуны под корнями, лестница наверх под разрывом.
    s.ladder("AbyssLadder", -1.5, -10.0, 13.0, -1.0)
    for i, x in enumerate((-16.0, -12.5, -9.0)):
        s.enemy(f"Rat{'ABC'[i]}", "rat", (x, -10.0, 0))
    s.instance("AbyssSpikes", "Objects", "spikes", ["position = Vector3(10.5, -10.0, 0)", "width = 3.0", "trap_damage = 25.0"])
    s.enemy("AbyssBatA", "bat", (-5.0, -6.8, 0))
    s.enemy("AbyssBatB", "bat", (5.0, -6.8, 0))
    for i, x in enumerate((-14.0, -4.0, 14.0)):
        s.box(D, f"Bones{i}", (x, -9.8, -1.0), (0.8, 0.2, 0.4), "bone")
    # Летуны: двое над главным путём, двое над верхним ярусом.
    s.enemy("WraithA", "wraith", (-8.0, 11.0, 0))
    s.enemy("WraithB", "wraith", (9.0, 11.0, 0))
    s.enemy("WraithC", "wraith", (-2.0, 16.0, 0))
    s.enemy("WraithD", "wraith", (10.5, 16.0, 0))
    # Фонари на ярусах (за плоскостью боя), корни-исполины фоном.
    for i, (x, ground) in enumerate(((-17.0, 8.0), (16.5, 8.0), (-15.0, 13.0), (13.5, 13.0))):
        s.lantern_post(D, f"Lamp{i}", x, -1.8, ground=ground, energy=1.0, rng=6.0)
    for i, x in enumerate((-20.0, -6.0, 8.0, 20.0)):
        s.box(D, f"BigRoot{i}", (x, 8.0, -4.0 - i % 2), (3.0, 32.0, 2.0), "root", rot=(0, 0, (i % 2 - 0.5) * 0.3))
    # Туман: сзади слоями и спереди, между ярусами — мешает смотреть.
    for i, (y, z, mat) in enumerate(((-6.0, -2.4, "fog_dense"), (0.0, -2.4, "fog_thick"), (6.0, -2.6, "fog_thick"),
                                     (12.0, -2.8, "fog_veil"), (17.0, -3.0, "fog_veil"), (-4.0, 0.9, "fog_dense"),
                                     (5.5, 0.9, "fog_thick"), (11.0, 0.9, "fog_thick"), (16.5, 0.9, "fog_veil"))):
        s.veil(D, f"Fog{i}", (0.0, y, z), (56.0, 7.0), mat)
    s.marker("FromGiant", (-26.0, 8.1, 0))
    s.marker("FromSwamp", (26.0, 8.1, 0))
    s.door("DoorToGiant", -27.3, 8.0, "fallen_giant", "Spawns/FromMaze", "Назад к поваленному дубу")
    s.door("DoorToSwamp", 27.3, 8.0, "swamp", "Spawns/FromMaze", "К болоту")
    save(s, "root_maze")


# ---------------------------------------------------------------- Кадр 5: болото
def swamp():
    s = Scene("Swamp", "swamp", 60.0, SWAMP, sun_energy=0.15)
    s.frame(-30, 30)
    for name, x, w in (("MudA", -8.0, 26.0), ("MudB", 17.0, 10.0)):
        s.node(name, 'type="Area3D"', "Objects", [f"position = Vector3({x}, 0, 0)", 'script = ExtResource("mud")', f"size = Vector3({w}, 0.3, 4.4)"])
    for i, x in enumerate((-15.0, -5.0, 4.5, 23.5)):
        s.box(G, f"Walkway{i}", (x, 0.25, 0), (2.6, 0.2, 2.4), "wood", True)
        s.box(D, f"WalkPost{i}", (x - 1.1, 0.3, 1.0), (0.12, 0.8, 0.12), "wood_dark")
    for i, (x, z, w) in enumerate(((-12.0, -1.8, 6.0), (2.0, -2.2, 8.0), (14.0, -1.6, 5.0), (-2.0, 1.8, 5.0))):
        s.box(D, f"Pool{i}", (x, 0.03, z), (w, 0.04, 1.2), "water")
    for i, x in enumerate((-24.0, -18.0, -9.0, -1.0, 7.0, 12.0, 20.0, 26.0)):
        s.tuft(D, f"Reeds{i}", x, 0.0, -1.4 - (i % 3) * 0.5, "reed", h=1.4)
    for i, x in enumerate((-20.0, 10.0, 24.0)):
        s.dead_tree(D, f"Tree{i}", x, -3.5 - i, 9.0, r=0.45)
        for j in range(3):
            s.box(D, f"MossHang{i}_{j}", (x + 1.2 + j * 0.6, 6.0 - j, -3.0 - i), (0.06, 2.4, 0.06), "moss")
    s.hanging_cage(D, "Cage", -16.0, 5.0, -2.0)
    s.box(D, "Banner", (-6.0, 3.4, -2.6), (0.8, 1.4, 0.05), "cloth")
    s.box(D, "BannerPole", (-6.4, 2.3, -2.6), (0.12, 4.6, 0.12), "wood_dark")
    s.box(D, "Watchtower", (18.0, 3.5, -7.0), (5.0, 0.4, 3.0), "wood_dark")
    for i, x in enumerate((16.0, 20.0)):
        s.box(D, f"TowerLeg{i}", (x, 1.7, -7.0), (0.3, 3.4, 0.3), "wood_dark", rot=(0, 0, 0.1 * (i * 2 - 1)))
    s.box(D, "TowerLantern", (19.5, 4.2, -6.4), (0.3, 0.45, 0.3), "lantern")
    s.light(D, "TowerLight", (19.5, 4.2, -5.0), (1.0, 0.6, 0.3), 1.2, 7.0)
    for i, (x, y, z) in enumerate(((-11.0, 0.3, -1.5), (-3.0, 0.5, 1.4), (9.0, 0.4, -1.0), (15.0, 0.3, 1.2))):
        s.sphere(D, f"Gas{i}", (x, y, z), 0.18, "gas")
    s.lantern_post(D, "Lamp", -26.0, -1.2, energy=1.1)
    s.enemy("DrownedKnight", "knight", (6.0, 0.0, 0))
    s.veil(D, "Fog", (0.0, 2.5, -2.6), (60.0, 5.0), "fog_thick")
    s.veil(D, "FogLow", (0.0, 0.6, 1.3), (60.0, 1.2))
    s.box(D, "FrontLog", (-12.0, 0.1, 3.2), (5.0, 0.6, 0.6), "bark", rot=(0, 0.2, 0))
    s.sphere(D, "FrontSkull", (-8.0, 0.0, 3.1), 0.22, "bone")
    s.tuft(D, "FrontReeds", 6.0, -0.2, 3.2, "reed", h=1.6)
    s.marker("FromMaze", (-28.0, 0.1, 0))
    s.marker("FromVillage", (28.0, 0.1, 0))
    s.door("DoorToMaze", -29.3, 0, "root_maze", "Spawns/FromSwamp", "Назад в лабиринт")
    s.door("DoorToVillage", 29.3, 0, "cursed_village", "Spawns/FromSwamp", "К мёртвой деревне")
    save(s, "swamp")


# ---------------------------------------------------------------- Кадр 6: мёртвая деревня Кузнеца
def cursed_village():
    s = Scene("CursedVillage", "cursed_village", 60.0, DEAD, sun_energy=0.2)
    s.frame(-30, 30)
    firs(s, -32, 32)
    s.ruined_house(D, "HouseA", -19.0, -5.5, 8.0, 5.0, 4.0, windows=((-2.0, 3.0), (2.0, 3.0)))
    s.ruined_house(D, "HouseB", -5.0, -9.5, 9.0, 5.5, 4.5, windows=((0.0, 3.2),))
    s.ruined_house(D, "HouseC", 24.0, -6.0, 7.0, 4.6, 3.8, windows=((-1.5, 2.8),))
    # Кузня справа: камень, труба, едва тлеющий горн, наковальня, ржавая вывеска.
    s.box(D, "ForgeBase", (16.5, 2.0, -3.2), (6.0, 4.0, 2.0), "stone")
    s.box(D, "ForgeChimney", (18.5, 7.0, -3.6), (1.6, 6.0, 1.6), "stone_dark")
    s.box(D, "ForgeMouth", (15.5, 1.1, -2.18), (1.6, 1.1, 0.06), "ember")
    s.light(D, "ForgeGlow", (15.5, 1.4, -0.8), (1.0, 0.45, 0.2), 0.9, 6.0)
    s.box(D, "AnvilBase", (12.0, 0.4, -2.2), (0.7, 0.8, 0.7), "wood_dark")
    s.box(D, "Anvil", (12.0, 1.0, -2.2), (1.2, 0.4, 0.5), "iron")
    s.box(D, "SignPost", (9.0, 2.4, -2.0), (0.2, 4.8, 0.2), "wood_dark")
    s.box(D, "SignArm", (9.7, 4.6, -2.0), (1.6, 0.12, 0.12), "wood_dark")
    s.box(D, "Sign", (10.2, 3.9, -2.0), (1.0, 0.8, 0.06), "rust", rot=(0, 0, 0.12))
    # Площадь: камень, черепа вокруг.
    s.box(D, "SeatStone", (4.0, 0.45, -1.15), (1.6, 0.9, 1.2), "stone")
    for i, (x, z) in enumerate(((2.4, -0.3), (5.8, -0.5), (3.1, 0.7), (6.6, 0.4), (1.5, -1.4), (7.0, -1.8))):
        s.sphere(D, f"Skull{i}", (x, 0.15, z), 0.18, "bone")
    s.enemy("Blacksmith", "smith", (4.0, 0.0, 0), ["seated = true", "dormant = true", "facing = -1.0"])
    s.node("Arena", 'type="Node3D"', "Objects", ['script = ExtResource("arena")', 'boss_path = NodePath("../Blacksmith")',
           "left_x = -10.0", "right_x = 19.0", "height = 9.0"])
    s.node("BossEcho", 'type="Area3D"', "Objects", ["position = Vector3(4.0, 0, 0)", 'script = ExtResource("pickup")', 'flag = &"boss_smith_echo"',
           'appear_flag = &"boss_smith_loot"', "echoes = 500", 'pickup_prompt = "Коснуться отзвука Безмолвного Кузнеца"',
           "look_size = Vector3(0.45, 1.1, 0.45)", "look_color = Color(0.5, 0.75, 1, 1)"])
    s.lantern_post(D, "Lamp", -26.0, -1.2, energy=0.9)
    s.dead_tree(D, "TreeA", -12.0, -4.0, 9.0)
    s.dead_tree(D, "TreeB", 28.0, -3.5, 8.0)
    s.fence(D, "BrokenFence", -16.0, -9.0, -1.8, mat="wood_dark")
    s.crow(D, "Crow", 9.0, 4.85, -2.0)
    s.veil(D, "Mist", (0.0, 2.0, -2.8), (60.0, 5.0), "fog_thick")
    s.box(D, "FrontCart", (-14.0, 0.4, 3.2), (2.6, 0.8, 1.0), "wood_dark", rot=(0, 0, 0.2))
    s.tuft(D, "FrontTuft", 10.0, -0.2, 3.2, "moss")
    s.rocks(D, "FrontRocks", 20.0, -0.2, 3.4)
    s.shard("MirrorShard", -24.0, 0.0)
    s.marker("FromSwamp", (-28.0, 0.1, 0))
    s.door("DoorToSwamp", -29.3, 0, "swamp", "Spawns/FromVillage", "Назад к болоту")
    save(s, "cursed_village")


cemetery_gate()
cemetery()
forest_wall()
fallen_giant()
root_maze()
swamp()
cursed_village()
print("ok")
