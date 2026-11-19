"""Полигон ловушек (§8.14): нажимные плиты и стреломёты со всеми видами стрел, растяжка с маятником-топором.
Комната тестовая — попасть в неё можно с тестовой карты (F4, осколок полигона); по ней ходит бот смоук-теста.
Каждый отсек: плита на полу, дальше стена со щелями (стрелы летят назад, на плиту), лестница на стену,
спрыгнуть в следующий отсек. Плиту можно перепрыгнуть или спустить издали — броском, стрелой, ударом.
Запуск из корня проекта: python tools/levels/build_traps.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from scenery import Scene  # noqa: E402
import backdrop as bd  # noqa: E402
from build_mines import ramp  # noqa: E402

G, D = "Geometry", "Decor"
DUSK = {"bg": (0.035, 0.04, 0.06), "amb": (0.34, 0.37, 0.46), "amb_e": 0.4, "fog": (0.13, 0.14, 0.18), "fog_d": 0.018}
LEFT, RIGHT = -30.0, 100.0
WALL_H = 3.0
# Отсеки стреломётов: (стрелы, плита x, стена x0) — стрелы летят на запад, к плите.
BAYS = (("", -13.0, -8.0), ("fire_arrow", 5.0, 10.0), ("poison_arrow", 23.0, 28.0), ("tar_arrow", 41.0, 46.0))
BAY_NAMES = {"": "обычные стрелы", "fire_arrow": "огненные", "poison_arrow": "отравленные", "tar_arrow": "смоляные"}
WIRE_X, PIVOT_X, CEILING = 55.0, 58.0, 5.5


def trap_range():
    s = Scene("TrapRange", "trap_range", RIGHT - LEFT, DUSK)
    s.wall("WallLeft", (LEFT - 0.5, 8.0, 0), (1, 30, 4.4))
    s.wall("WallRight", (RIGHT + 0.5, 8.0, 0), (1, 30, 4.4))
    s.box(G, "Ground", (-0.5, -2.0, 0), (141.0, 4.0, 4.4), "mud", True)
    for i, (kind, plate_x, wall_x) in enumerate(BAYS):
        s.box(G, f"Wall{i}", (wall_x + 2.0, WALL_H / 2, 0), (4.0, WALL_H, 4.4), "stone", True)
        s.arrow_launcher(f"Launcher{i}", (wall_x, 0.0, 0.0), -1, kind)
        s.trap_plate(f"Plate{i}", (plate_x, 0.0, 0.0), [f"Launcher{i}"])
        s.ladder(f"Ladder{i}", wall_x - 0.6, 0.0, WALL_H, 1.0)
        s.ladder_look(f"Wall{i}", wall_x - 0.6, 0.0, WALL_H)
        s.note(f"Sign{i}", plate_x - 3.0, 0.0, f"Отсек {i + 1}: {BAY_NAMES[kind]}", [
            "«Плита чуть выше пола и светлее камня. Наступишь — залп из щелей в стене.",
            "Перепрыгни, перекатись сквозь залп или спусти её издали: брось нож, выстрели, ударь.»"])
    # Растяжка под балочным потолком: нить по щиколотку, в потолке ждёт топор — торчит лишь кромка.
    s.box(G, "Ceiling", (60.0, CEILING + 0.75, 0), (16.0, 1.5, 4.4), "wood_dark", True)
    s.box(D, "BladeSlot", (PIVOT_X + 3.0, CEILING - 0.01, 0.0), (6.4, 0.02, 0.3), "char")
    for i, x in enumerate((52.4, 67.6)):
        s.box(D, f"CeilingPost{i}", (x, CEILING / 2, -1.6), (0.35, CEILING, 0.35), "wood_dark")
    s.tripwire("Tripwire", (WIRE_X, 0.0, 0.0), ["Blade"])
    # Подвес на 1,1 м выше потолка: задранное лезвие торчит из щели на 15–20 %, внизу проходит на уровне груди.
    s.swing_blade("Blade", (PIVOT_X, CEILING + 1.1, 0.0), CEILING + 1.1 - 1.0)
    # Валун: подъём на холм, валун ждёт на полке над тропой; вниз по склону — плита; яма поуже валуна — укрытие;
    # в конце слабая стена — валун проломит её, за ней тайник.
    s.box(G, "HillTop", (75.0, 2.0, 0), (2.0, 4.0, 4.4), "mud", True)
    ramp(s, "HillUp", 68.0, 0.0, 74.0, 4.0, "mud", thick=6.0)
    ramp(s, "HillDown", 76.0, 4.0, 86.0, 0.0, "mud", thick=6.0)
    s.box(G, "BoulderShelf", (75.5, 6.4, 0), (2.2, 0.4, 4.4), "stone_dark", True)
    s.boulder("Boulder", (75.5, 6.6, 0.0), direction=1)
    s.trap_plate("BoulderPlate", (88.0, 0.0, 0.0), ["Boulder"], rearm=600.0)
    s.box(G, "GroundEast", (86.0, -2.0, 0), (10.4, 4.0, 4.4), "mud", True)
    s.box(G, "PitFloor", (92.0, -3.0, 0), (1.6, 2.0, 4.4), "mud", True)
    s.box(G, "GroundFar", (110.0, -2.0, 0), (34.4, 4.0, 4.4), "mud", True)
    s.weak_wall("WeakWall", (96.5, 0.0, 0.0), flag="")
    s.chest("StashChest", (98.6, 0.0, -0.8), 50, "", ("tempered_glass",))
    s.note("BoulderSign", 84.0, 0.0, "Валун", [
        "«Наступишь на плиту внизу склона — сверху загудит и посыплется пыль, и валун сорвётся с полки.",
        "Спрячься в узкую яму — валун её перекатит; или перепрыгни, перекатись. В конце он проломит трухлявую стену.»"])
    s.note("WireSign", WIRE_X - 3.0, 0.0, "Растяжка", [
        "«Нить поперёк хода блестит, только когда смотришь под нужным углом. Над ней в потолке — топор.",
        "Перешагни прыжком или перережь издали: стрела, нож. Услышал щелчок — стой, не беги.»"])
    # Фон: двор на закате.
    k = bd.Kit(s)
    k.sky(LEFT, RIGHT, (0.03, 0.035, 0.055), (0.17, 0.18, 0.23))
    k.far_ground(LEFT, RIGHT)
    k.mountains(LEFT - 60, RIGHT + 60, -72, -1, 14, 30)
    k.firs(LEFT - 40, RIGHT + 40, -40, -52, 10, 18)
    k.haze(LEFT, RIGHT, 3, -20, 10, DUSK["fog"], 0.35)
    k.haze(LEFT, RIGHT, 6, -38, 22, DUSK["fog"], 0.5)
    k.near_ground(LEFT, RIGHT)
    for x0, x1 in ((LEFT, 68.0), (86.0, RIGHT)):
        k.path_light(x0, x1, 0.0, (0.06, 0.07, 0.09))
    s.lantern_post(D, "Lamp", -25.0, -1.2)
    s.light(D, "BladeLight", (WIRE_X, 2.6, 1.2), (0.8, 0.8, 0.9), 0.8, 7.0)
    s.shard("MirrorShard", -26.0, 0.0)
    s.marker("PlayerStart", (-28.0, 0.1, 0))
    Path("world/rooms/trap_range.tscn").write_text(s.text(), encoding="utf-8")


trap_range()
