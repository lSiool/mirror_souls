"""Полигон крюка на цепи (§5, §8.13): все три вида колец подряд. Комната тестовая — попасть в неё можно
с тестовой карты (F4, осколок полигона); по ней ходит бот смоук-теста.
Запуск из корня проекта: python tools/levels/build_hook.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from scenery import Scene  # noqa: E402
import backdrop as bd  # noqa: E402

G, D = "Geometry", "Decor"
DUSK = {"bg": (0.035, 0.04, 0.06), "amb": (0.34, 0.37, 0.46), "amb_e": 0.4, "fog": (0.13, 0.14, 0.18), "fog_d": 0.018}
PULL, SWING, WALL = 0, 1, 2
LEFT, RIGHT = -36.0, 44.0


def hook_range():
    s = Scene("HookRange", "hook_range", RIGHT - LEFT, DUSK)
    s.wall("WallLeft", (LEFT - 0.5, 8.0, 0), (1, 30, 4.4))
    s.wall("WallRight", (RIGHT + 0.5, 8.0, 0), (1, 30, 4.4))
    # Старт: ровная площадка, осколок.
    s.box(G, "StartGround", (-55.0, -2.0, 0), (82.0, 4.0, 4.4), "mud", True)
    # 1. Пропасть: кольцо «притянуть» над ней. Сорвался — дно с лестницей наверх.
    s.box(G, "PitFloor", (-9.5, -6.0, 0), (9.0, 4.0, 4.4), "mud", True)
    s.box(G, "PitWall", (-9.5, -2.0, -2.4), (9.0, 4.0, 0.4), "stone_dark")
    s.ladder("PitLadder", -5.6, -4.0, 4.0, 1.0)
    s.ladder_look("Pit", -5.6, -4.0, 4.0)
    s.hook_point("RingPull", (-9.0, 5.6, 0.0), PULL)
    s.box(D, "PullBeam", (-9.0, 6.6, -0.5), (10.0, 0.35, 0.35), "wood_dark")
    for i, x in enumerate((-14.2, -3.8)):
        s.box(D, f"PullPost{i}", (x, 1.6 if x > -6 else 3.3, -0.5), (0.35, 10.0, 0.35), "wood_dark")
    # 2. Стена: кольцо на кромке, крюк перебрасывает наверх.
    s.box(G, "MidGround", (1.5, -2.0, 0), (13.0, 4.0, 4.4), "mud", True)
    s.box(G, "Wall", (14.0, 1.0, 0), (12.0, 10.0, 4.4), "stone", True)
    s.hook_point("RingWall", (7.7, 6.3, 0.0), WALL)
    # 3. Качели: кольцо на балке над пролётом; внизу безопасный пол и лестница обратно на стену.
    s.box(G, "SwingFloor", (27.0, -2.0, 0), (14.0, 4.0, 4.4), "mud", True)
    s.ladder("SwingLadder", 20.6, 0.0, 6.0, -1.0)
    s.ladder_look("Swing", 20.6, 0.0, 6.0)
    s.hook_point("RingSwing", (27.0, 12.4, 0.0), SWING)
    s.box(D, "SwingBeam", (27.0, 13.3, -0.6), (16.0, 0.4, 0.4), "wood_dark")
    for i, x in enumerate((19.6, 34.4)):
        s.box(D, f"SwingPost{i}", (x, 9.6, -0.6), (0.4, 7.4, 0.4), "wood_dark")
    s.box(D, "SwingChain", (27.0, 12.9, -0.05), (0.06, 0.8, 0.06), "iron")
    s.box(G, "FarLedge", (39.0, 1.0, 0), (10.0, 10.0, 4.4), "stone", True)
    s.box(G, "FarGround", (55.0, -2.0, 0), (30.0, 4.0, 4.4), "mud", True)
    # Фон: двор на закате.
    k = bd.Kit(s)
    k.sky(LEFT, RIGHT, (0.03, 0.035, 0.055), (0.17, 0.18, 0.23))
    k.far_ground(LEFT, RIGHT)
    k.mountains(LEFT - 60, RIGHT + 60, -72, -1, 14, 30)
    k.firs(LEFT - 40, RIGHT + 40, -40, -52, 10, 18)
    k.haze(LEFT, RIGHT, 3, -20, 10, DUSK["fog"], 0.35)
    k.haze(LEFT, RIGHT, 6, -38, 22, DUSK["fog"], 0.5)
    k.near_ground(LEFT, -14.0)
    k.path_light(LEFT, -14.0, 0.0, (0.06, 0.07, 0.09))
    k.path_light(-5.0, 8.0, 0.0, (0.06, 0.07, 0.09))
    k.path_light(8.0, 20.0, 6.0, (0.06, 0.07, 0.09))
    k.path_light(34.0, RIGHT, 6.0, (0.06, 0.07, 0.09))
    s.lantern_post(D, "Lamp", -31.0, -1.2)
    s.shard("MirrorShard", -30.0, 0.0)
    s.marker("PlayerStart", (-33.0, 0.1, 0))
    s.note("RangeNote", -26.0, 0.0, "Полигон крюка", [
        "«H или перекат в прыжке у кольца — бросить крюк.",
        "Над пропастью — притянет и бросит дальше. На кромке стены — перебросит наверх.",
        "На балке — качели: держи кнопку, отпусти на взлёте.»"])
    Path("world/rooms/hook_range.tscn").write_text(s.text(), encoding="utf-8")


hook_range()
print("ok")
