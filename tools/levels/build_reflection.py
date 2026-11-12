"""Сюжетный забег «Нестабильное отражение» (GAME_DESIGN §8.11) — graybox-полигон.

Бесконечная пустота, в которой раскололся первый Осколок. Дорожки нет: путь складывается из
стеклянных глыб, летящих герою навстречу; за спиной пространство схлопывается. Тонкие пластины
герой пробивает плечом на бегу и в прыжке, от толстых обломков уходит. Наград и врагов нет;
сорвался — очнётся у последнего осколка и пойдёт снова. Вход и выход — стеклянные преграды
в комнате-прототипе room_001. Запуск из корня проекта: python tools/levels/build_reflection.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import scenery  # noqa: E402

# Свои ресурсы отражения — только в этой комнате: остальные сцены от запуска не меняются.
scenery.EXT = {**scenery.EXT,
               "run": ("Script", "res://world/run/run_level.gd"), "shard_fly": ("Script", "res://world/run/flying_shard.gd"),
               "meteor": ("Script", "res://world/run/glass_meteor.gd"), "drift": ("Script", "res://world/run/drift.gd"),
               "caustics": ("Shader", "res://effects/shaders/caustics.gdshader"),
               "pearl": ("Shader", "res://effects/shaders/pearl_glass.gdshader")}
from scenery import Scene, v3  # noqa: E402

D = "Decor"
VOID = {"bg": (0.012, 0.012, 0.04), "amb": (0.42, 0.5, 0.75), "amb_e": 0.55, "fog": (0.05, 0.06, 0.14), "fog_d": 0.004}

# --- Числа забега (черновик, настраивает автор) -----------------------------
START_X = 9.0        # линия старта: край стартовой площадки
HEAD_START = 16.0    # фронт стартует на столько позади линии
MAX_SLACK = 5.0      # запас героя, с
FRONT_SPEED = 8.2    # скорость схлопывания, м/с: шагом (≈7,2) не уйти, бегом (≈9,7) — да
PANE = (0.25, 3.6, 3.0)  # тонкая пластина: пробивается плечом
DEPTH = 3.2          # глубина глыб


class Path_:
    """Курсор, который раскладывает глыбы слева направо."""

    def __init__(self, s, x, y):
        self.s, self.x, self.y, self.n = s, x, y, 0
        self.panes = self.meteors = self.slides = 0

    def piece(self, length, gap=3.0, rise=0.0, tilt=0.0, thick=0.6):
        """Глыба длиной length после провала gap; rise — выше или ниже прежней. Возвращает её середину."""
        self.x += gap
        self.y += rise
        cx = self.x + length / 2
        # Каждая прилетает со своей стороны: сверху, снизу, из глубины.
        side = self.n % 4
        frm = ((18.0, 8.0, -9.0), (20.0, -9.0, -6.0), (14.0, 3.0, -14.0), (22.0, 11.0, 5.0))[side]
        props = [f"position = {v3((cx, self.y - thick / 2, 0))}"]
        if tilt:
            props.append(f"rotation = Vector3(0, 0, {tilt})")
        props += ['script = ExtResource("shard_fly")', f"size = {v3((length, thick, DEPTH))}", f"from = {v3(frm)}"]
        self.s.node(f"Shard{self.n}", 'type="AnimatableBody3D"', "Objects", props)
        self.n += 1
        self.x += length
        return cx

    def slide(self, length, angle=0.4636, thick=0.5):
        """Стеклянный скат вниз прямо от конца прежней глыбы: герой съезжает и разгоняется."""
        dx, dy = length * math.cos(angle), length * math.sin(angle)
        cx, cy = self.x + dx / 2, self.y - dy / 2 - thick / 2 / math.cos(angle)
        frm = ((16.0, 10.0, -8.0), (18.0, -8.0, -10.0))[self.n % 2]
        self.s.node(f"Shard{self.n}", 'type="AnimatableBody3D"', "Objects", [f"position = {v3((cx, cy, 0))}", f"rotation = Vector3(0, 0, {-angle})",
                    'script = ExtResource("shard_fly")', f"size = {v3((length, thick, DEPTH))}", f"from = {v3(frm)}", "slide = true"])
        self.n += 1
        self.slides += 1
        self.x += dx
        self.y -= dy

    def pane(self, x, lift=0.0):
        """Тонкая пластина поперёк пути: низ на высоте текущей глыбы + lift."""
        self.s.instance(f"Pane{self.panes}", "Objects", "glass",
                        [f"position = {v3((x, self.y + lift + PANE[1] / 2 - 0.3, 0))}", f"size = {v3(PANE)}"])
        self.panes += 1

    def meteor(self, meet_x, height, size=1.5, speed=11.0, climb=0.0):
        """Толстый обломок: встретит бегущего героя около meet_x на высоте height над глыбой."""
        # Срывается, когда герой в 34 м; до встречи летит ~1,6 с — ставим на столько впереди.
        ahead = 18.0
        self.s.node(f"Meteor{self.meteors}", 'type="Area3D"', "Objects",
                    [f"position = {v3((meet_x + ahead, self.y + height - climb * ahead / speed, 0))}", 'script = ExtResource("meteor")',
                     f"size = {v3((size, size, size))}", f"fly = {v3((-speed, climb, 0))}"])
        self.meteors += 1


def reflection_run():
    s = Scene("ReflectionRun", "reflection_run", 400.0, VOID, sun_color=(0.6, 0.7, 1.0), sun_energy=0.35)
    # Стартовая площадка стоит сразу: на неё герой вылетает из стеклянной преграды.
    s.node("StartShard", 'type="AnimatableBody3D"', "Objects", [f"position = {v3((3.0, -0.4, 0))}", 'script = ExtResource("shard_fly")',
           f"size = {v3((14.0, 0.8, DEPTH))}", "always_here = true"])
    p = Path_(s, 10.0, 0.0)

    # --- 1. Разбег: длинные глыбы, короткие провалы. Понять: стоять нельзя, сзади рассыпается.
    for i in range(4):
        p.piece(9.0, gap=3.0, rise=(0.0, 0.4, -0.3, 0.2)[i])

    # --- Скат: глыба наклонена вниз — съехать, разогнаться и с разгона в пластины.
    p.piece(5.0, gap=3.0, rise=1.6)
    p.slide(6.0)
    # --- 2. Пластины: первая стоит на глыбе — бегом с блоком насквозь; потом две подряд.
    cx = p.piece(13.0, gap=0.0)
    p.pane(cx + 1.0)
    cx = p.piece(12.0, gap=3.2, rise=-0.4)
    p.pane(cx - 2.5)
    p.pane(cx + 3.0)

    # --- 3. Пластина в воздухе над провалом: таран в прыжке.
    p.piece(8.0, gap=3.0, rise=0.3)
    p.pane(p.x + 2.4, lift=-0.4)
    p.piece(9.0, gap=4.8)

    # --- 4. Длинные провалы: только с разбега.
    for i in range(3):
        p.piece(8.0, gap=6.0, rise=(-0.3, 0.3, -0.5)[i], tilt=(0.0, 0.06, -0.05)[i])

    # --- 5. Обломки навстречу: низкий — перепрыгнуть, высокий — не прыгать.
    # Низкий обломок встречает героя в начале глыбы: прыжок через него не уносит в провал.
    cx = p.piece(15.0, gap=3.2, rise=0.2)
    p.meteor(cx - 3.5, 0.8)
    cx = p.piece(15.0, gap=3.4)
    p.meteor(cx - 4.0, 3.1, size=1.8)
    p.meteor(cx + 1.0, 0.8)
    # Обломок проносится наискось над провалом, выше головы: пугает, но не сбивает.
    p.piece(9.0, gap=4.0, rise=-0.4)
    p.meteor(p.x + 2.5, 4.2, size=1.3, speed=9.0, climb=-1.5)

    # --- 6. Всё вместе: провалы с разбега, пластины на бегу и в воздухе, обломки.
    cx = p.piece(10.0, gap=5.6, rise=0.3)
    p.pane(cx + 2.0)
    p.piece(7.0, gap=5.8, tilt=0.07)
    p.pane(p.x + 2.8, lift=-0.5)
    cx = p.piece(12.0, gap=5.2, rise=-0.3)
    p.meteor(cx - 2.5, 0.8)
    p.piece(5.0, gap=6.0, rise=2.4)
    p.slide(7.0)
    p.piece(3.0, gap=0.0)
    cx = p.piece(11.0, gap=5.0)
    p.pane(cx - 2.0)
    p.meteor(cx + 3.5, 3.0, size=1.7)
    p.piece(8.0, gap=6.0, rise=-0.3)

    # --- 7. Финиш: последняя площадка стоит сама, на ней — стеклянная преграда выхода.
    end_x = p.x + 4.5
    s.node("EndShard", 'type="AnimatableBody3D"', "Objects", [f"position = {v3((end_x + 7.0, p.y - 0.4, 0))}", 'script = ExtResource("shard_fly")',
           f"size = {v3((14.0, 0.8, DEPTH))}", "always_here = true"])
    s.node("GateOut", 'type="Area3D"', "Objects", [f"position = {v3((end_x + 10.0, p.y, 0))}", 'script = ExtResource("door")',
           'target_room = &"room_001"', 'target_spawn = NodePath("Spawns/PlayerStart")', 'open_prompt = "Сквозь стекло"',
           "door_size = Vector3(0.25, 4.2, 3.2)", "glass_gate = true"])
    length = end_x + 14.0

    # --- Фон: каустика во всю пустоту и дальние осколки, плывущие навстречу.
    s.subs.append('[sub_resource type="ShaderMaterial" id="Mat_caustics"]\nshader = ExtResource("caustics")\nshader_parameter/scale = 5.0\n'
                  'shader_parameter/speed = 0.35\nshader_parameter/glow = 1.0')
    s.subs.append(f'[sub_resource type="QuadMesh" id="Mesh_backdrop"]\nmaterial = SubResource("Mat_caustics")\nsize = Vector2({length + 260.0}, 110)')
    s.node("Backdrop", 'type="MeshInstance3D"', D, [f"position = {v3((length / 2, 4.0, -38.0))}", 'mesh = SubResource("Mesh_backdrop")'])
    s.subs.append('[sub_resource type="ShaderMaterial" id="Mat_pearl"]\nshader = ExtResource("pearl")\nshader_parameter/alpha = 0.45\nshader_parameter/seed = 0.37')
    s.subs.append('[sub_resource type="PrismMesh" id="Mesh_far"]\nmaterial = SubResource("Mat_pearl")\nleft_to_right = 0.3\nsize = Vector3(3, 4, 1.2)')
    s.subs.append('[sub_resource type="BoxMesh" id="Mesh_slab"]\nmaterial = SubResource("Mat_pearl")\nsize = Vector3(5, 0.5, 3)')
    s.node("Far", 'type="Node3D"', D, ['script = ExtResource("drift")'])
    for i in range(30):
        # Детерминированный разброс: одинаковый от запуска к запуску.
        x = (i * 37.0) % 150.0
        y = -13.0 + (i * 7.3) % 28.0
        z = -16.0 - (i * 5.1) % 18.0
        k = 0.35 + (i % 5) * 0.22
        mesh = "Mesh_far" if i % 3 else "Mesh_slab"
        s.node(f"Far{i}", 'type="MeshInstance3D"', f"{D}/Far", [f"position = {v3((x, y, z))}",
               f"rotation = {v3(((i * 0.7) % 3.1, (i * 1.3) % 3.1, (i * 0.4) % 3.1))}", f"scale = {v3((k, k, k))}", f'mesh = SubResource("{mesh}")'])
    # Ближние обломки перед героем: тёмные силуэты, мимо которых он летит.
    for i in range(10):
        s.node(f"Near{i}", 'type="MeshInstance3D"', D, [f"position = {v3((18.0 + i * (length / 10.0), -6.0 + (i * 3.7) % 5.0, 4.6))}",
               f"rotation = {v3((0.4 * i, 0.9, 0.3 * i))}", 'mesh = SubResource("Mesh_far")'])
    for i in range(int(length / 26.0)):
        s.light(D, f"Glow{i}", (13.0 + i * 26.0, 5.0 + 3.0 * math.sin(i * 1.7), 2.0), (0.6, 0.75, 1.0), 1.4, 16.0)

    s.node("Run", 'type="Node3D"', "Objects", ['script = ExtResource("run")', 'done_flag = &"reflection_done"',
           f"start_x = {START_X}", f"head_start = {HEAD_START}", f"pace = PackedVector2Array(0.0, {FRONT_SPEED})", f"max_slack = {MAX_SLACK}",
           "burn_rate = 0.0", "fire_levels = PackedFloat32Array()", "shatter_wall = true", "free_run = true"])
    s.marker("PlayerStart", (-2.0, 0.1, 0))
    Path("world/rooms/reflection_run.tscn").write_text(s.text(), encoding="utf-8")
    print(f"reflection_run: {p.n} глыб, {p.slides} скатов, {p.panes} пластин, {p.meteors} обломков, длина {length:.0f} м")


if __name__ == "__main__":
    reflection_run()
