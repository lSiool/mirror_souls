"""Graybox-сцены комнат: коробки, цилиндры, свет и объекты в текстовом .tscn.

Используется генераторами в tools/levels/. Сцены пишутся целиком; запускать из корня проекта.
"""
import math

MATS = {
    "mud": (0.2, 0.17, 0.15), "stone": (0.27, 0.27, 0.29), "stone_dark": (0.15, 0.15, 0.17),
    "wood": (0.25, 0.17, 0.11), "wood_dark": (0.12, 0.09, 0.07), "thatch": (0.2, 0.16, 0.13),
    "plaster": (0.3, 0.27, 0.23), "iron": (0.09, 0.09, 0.1), "cloth": (0.1, 0.09, 0.12),
    "statue": (0.3, 0.32, 0.36), "fir": (0.07, 0.09, 0.11), "earth_dark": (0.05, 0.045, 0.05),
    "char": (0.035, 0.03, 0.03), "rotten": (0.34, 0.27, 0.17), "bark": (0.1, 0.08, 0.07),
    "root": (0.14, 0.1, 0.08), "moss": (0.16, 0.2, 0.1), "bone": (0.62, 0.58, 0.5), "reed": (0.24, 0.24, 0.12),
    "water": (0.02, 0.025, 0.025), "rust": (0.3, 0.16, 0.08), "rope": (0.45, 0.36, 0.22), "silver": (0.6, 0.6, 0.64),
}
## Светящиеся: цвет, сила свечения.
GLOW = {"window": ((1.0, 0.6, 0.25), 2.6), "fire": ((1.0, 0.45, 0.12), 4.0), "moonpane": ((0.45, 0.6, 0.85), 1.1),
        "candle": ((1.0, 0.7, 0.35), 3.0), "lantern": ((1.0, 0.68, 0.3), 5.0), "gas": ((0.45, 0.6, 0.25), 1.2),
        "ember": ((0.9, 0.35, 0.1), 1.6)}
## Полупрозрачные слои тумана: цвет и непрозрачность.
VEILS = {"fog_veil": ((0.6, 0.62, 0.68), 0.22), "fog_thick": ((0.55, 0.58, 0.62), 0.4)}

EXT = {
    "room": ("Script", "res://world/rooms/room.gd"), "door": ("Script", "res://world/common/room_door.gd"),
    "pickup": ("Script", "res://world/common/item_pickup.gd"), "ladder": ("Script", "res://world/common/ladder.gd"),
    "shard": ("PackedScene", "res://world/checkpoints/mirror_shard.tscn"), "chest": ("PackedScene", "res://world/chest/chest.tscn"),
    "glass": ("PackedScene", "res://world/glass/glass_surface.tscn"), "spikes": ("PackedScene", "res://world/hazards/spikes.tscn"),
    "note": ("Script", "res://world/common/note.gd"), "captive": ("Script", "res://world/common/bound_captive.gd"),
    "mud": ("Script", "res://world/common/mud_zone.gd"), "arena": ("Script", "res://world/common/boss_arena.gd"),
    "robbers": ("Script", "res://world/rooms/robber_event.gd"),
    "rat": ("PackedScene", "res://actors/enemies/rat.tscn"), "bat": ("PackedScene", "res://actors/enemies/bat.tscn"),
    "wraith": ("PackedScene", "res://actors/enemies/fog_wraith.tscn"), "knight": ("PackedScene", "res://actors/enemies/drowned_knight.tscn"),
    "bandit_heavy": ("PackedScene", "res://actors/enemies/bandit_heavy.tscn"), "bandit_knife": ("PackedScene", "res://actors/enemies/bandit_knife.tscn"),
    "smith": ("PackedScene", "res://actors/enemies/blacksmith.tscn"),
}


def v3(p):
    return f"Vector3({round(p[0], 4)}, {round(p[1], 4)}, {round(p[2], 4)})"


class Scene:
    def __init__(self, name, room_id, width, env, sun_color=(0.55, 0.62, 0.8), sun_energy=0.25):
        self.name, self.room_id, self.width, self.env = name, room_id, width, env
        self.sun_color, self.sun_energy = sun_color, sun_energy
        self.nodes, self.subs, self.used = [], [], set()
        self.meshes = 0

    # --- примитивы
    def mat(self, name):
        self.used.add(name)
        return f'SubResource("Mat_{name}")'

    def node(self, name, kind, parent, props, extra=""):
        self.nodes.append("\n".join([f'[node name="{name}" {kind} parent="{parent}"{extra}]'] + props))

    def instance(self, name, parent, scene, props):
        self.nodes.append("\n".join([f'[node name="{name}" parent="{parent}" instance=ExtResource("{scene}")]'] + props))

    def box(self, parent, name, pos, size, mat, collide=False, rot=None):
        props = [f"position = {v3(pos)}"]
        if rot is not None:
            props.append(f"rotation = {v3(rot)}")
        if collide:
            props.append("use_collision = true")
        props += [f"size = {v3(size)}", f"material = {self.mat(mat)}"]
        self.node(name, 'type="CSGBox3D"', parent, props)

    def cyl(self, parent, name, pos, radius, height, mat, rot=None, sides=10, cone=False, collide=False):
        props = [f"position = {v3(pos)}"]
        if rot is not None:
            props.append(f"rotation = {v3(rot)}")
        if collide:
            props.append("use_collision = true")
        props += [f"radius = {radius}", f"height = {height}", f"sides = {sides}"]
        if cone:
            props.append("cone = true")
        props.append(f"material = {self.mat(mat)}")
        self.node(name, 'type="CSGCylinder3D"', parent, props)

    def sphere(self, parent, name, pos, radius, mat):
        self.node(name, 'type="CSGSphere3D"', parent, [f"position = {v3(pos)}", f"radius = {radius}", f"material = {self.mat(mat)}"])

    def roof(self, parent, name, pos, size, mat="thatch", rot=None):
        self.meshes += 1
        sid = f"Roof_{self.meshes}"
        self.subs.append(f'[sub_resource type="PrismMesh" id="{sid}"]\nmaterial = {self.mat(mat)}\nsize = {v3(size)}')
        props = [f"position = {v3(pos)}", f'mesh = SubResource("{sid}")']
        if rot is not None:
            props.insert(1, f"rotation = {v3(rot)}")
        self.node(name, 'type="MeshInstance3D"', parent, props)

    def veil(self, parent, name, pos, size, mat="fog_veil"):
        """Полупрозрачный слой тумана — плоскость лицом к камере."""
        self.meshes += 1
        sid = f"Veil_{self.meshes}"
        self.subs.append(f'[sub_resource type="QuadMesh" id="{sid}"]\nmaterial = {self.mat(mat)}\nsize = Vector2({size[0]}, {size[1]})')
        self.node(name, 'type="MeshInstance3D"', parent, [f"position = {v3(pos)}", f'mesh = SubResource("{sid}")'])

    def light(self, parent, name, pos, color, energy, rng, shadow=False):
        props = [f"position = {v3(pos)}", f"light_color = Color({color[0]}, {color[1]}, {color[2]}, 1)",
                 f"light_energy = {energy}", f"omni_range = {rng}"]
        if shadow:
            props.append("shadow_enabled = true")
        self.node(name, 'type="OmniLight3D"', parent, props)

    def marker(self, name, pos):
        self.node(name, 'type="Marker3D"', "Spawns", [f"position = {v3(pos)}"])

    # --- рамка комнаты
    def frame(self, left, right, ground=0.0, wall_h=20.0):
        """Пол, стены по краям, дальняя земля и тёмный берег спереди."""
        width = right - left
        self.box("Geometry", "Ground", ((left + right) / 2, ground - 2, 0), (width + 1, 4, 4.4), "mud", True)
        self.box("Geometry", "WallLeft", (left - 0.5, ground + wall_h / 2 - 4, 0), (1, wall_h, 4.4), "stone_dark", True)
        self.box("Geometry", "WallRight", (right + 0.5, ground + wall_h / 2 - 4, 0), (1, wall_h, 4.4), "stone_dark", True)
        self.box("Decor", "FarGround", ((left + right) / 2, ground - 2, -20), (width + 40, 4, 35.6), "mud")
        self.box("Decor", "Bank", ((left + right) / 2, ground - 2.2, 3.7), (width + 2, 4, 3.0), "earth_dark")

    # --- декор
    def dead_tree(self, parent, name, x, z, h, ground=0.0, r=0.3, mat="wood_dark"):
        self.cyl(parent, f"{name}Trunk", (x, ground + h / 2, z), r, h, mat, sides=7)
        for i, (f, side, length, a) in enumerate(((0.55, 1, 2.6, 0.5), (0.68, -1, 2.2, 0.7), (0.82, 1, 1.7, 0.9), (0.92, -1, 1.5, 0.5), (1.0, 1, 1.2, 1.2))):
            bx, by = x + side * length / 2 * math.cos(a), ground + h * f + length / 2 * math.sin(a)
            self.box(parent, f"{name}Branch{i}", (bx, by, z), (length, 0.13, 0.13), mat, rot=(0, 0, side * a))

    def giant_tree(self, parent, name, x, z, h, r=2.2, ground=0.0):
        """Ствол-исполин стены леса с корнями-контрфорсами."""
        self.cyl(parent, f"{name}Trunk", (x, ground + h / 2 - 1, z), r, h, "bark", sides=9)
        for i, side in enumerate((-1, 1)):
            self.box(parent, f"{name}Root{i}", (x + side * (r + 0.6), ground + 0.9, z + 0.4), (2.6, 0.9, 1.0), "root", rot=(0, 0, side * -0.55))

    def lantern_post(self, parent, name, x, z, ground=0.0, side=1, energy=1.3, rng=6.5):
        self.box(parent, f"{name}Post", (x, ground + 2.1, z), (0.2, 4.2, 0.2), "wood_dark")
        self.box(parent, f"{name}Arm", (x + side * 0.7, ground + 4.0, z), (1.6, 0.14, 0.14), "wood_dark")
        self.box(parent, f"{name}Lamp", (x + side * 1.3, ground + 3.4, z), (0.28, 0.48, 0.28), "lantern")
        self.light(parent, f"{name}Light", (x + side * 1.3, ground + 3.2, z + 1.0), (1.0, 0.6, 0.28), energy, rng)

    def hanging_cage(self, parent, name, x, y, z):
        for i in range(5):
            a = i * math.tau / 5
            self.box(parent, f"{name}Bar{i}", (x + 0.3 * math.cos(a), y, z + 0.3 * math.sin(a)), (0.04, 1.0, 0.04), "iron")
        self.box(parent, f"{name}Top", (x, y + 0.5, z), (0.7, 0.06, 0.7), "iron")
        self.box(parent, f"{name}Chain", (x, y + 1.6, z), (0.04, 2.2, 0.04), "iron")

    def grave(self, parent, name, x, z, ground=0.0, tilt=0.0, cross=False):
        if cross:
            self.box(parent, f"{name}Post", (x, ground + 0.7, z), (0.16, 1.4, 0.16), "stone", rot=(0, 0, tilt))
            self.box(parent, f"{name}Bar", (x, ground + 1.0, z), (0.7, 0.14, 0.16), "stone", rot=(0, 0, tilt))
        else:
            self.box(parent, f"{name}", (x, ground + 0.5, z), (0.7, 1.0, 0.2), "stone", rot=(0, 0, tilt))

    def statue(self, parent, name, x, z, ground=0.0, scale=1.0, broken=False):
        s = scale
        self.box(parent, f"{name}Plinth", (x, ground + 0.5 * s, z), (1.4 * s, 1.0 * s, 1.2 * s), "stone")
        self.box(parent, f"{name}Body", (x, ground + 2.3 * s, z), (0.8 * s, 2.6 * s, 0.6 * s), "statue")
        self.sphere(parent, f"{name}Head", (x + (0.12 * s if broken else 0), ground + 3.85 * s, z), 0.32 * s, "statue")
        if not broken:
            self.box(parent, f"{name}ArmA", (x + 0.55 * s, ground + 2.9 * s, z), (0.22 * s, 1.3 * s, 0.24 * s), "statue", rot=(0, 0, -0.4))
        self.box(parent, f"{name}ArmB", (x - 0.5 * s, ground + 2.6 * s, z), (0.22 * s, 1.2 * s, 0.24 * s), "statue", rot=(0, 0, 0.2))

    def rocks(self, parent, name, x, y, z):
        for i, (dx, s, a) in enumerate(((0.0, 0.8, 0.3), (0.8, 0.5, -0.4), (-0.7, 0.45, 0.6))):
            self.box(parent, f"{name}{i}", (x + dx, y + s * 0.3, z), (s * 1.4, s, s * 1.1), "earth_dark", rot=(0.2, a, a * 0.5))

    def tuft(self, parent, name, x, y, z, mat="wood_dark", h=0.7):
        for i in range(5):
            self.box(parent, f"{name}{i}", (x + (i - 2) * 0.12, y + h / 2, z), (0.04, h, 0.04), mat, rot=(0, 0, round(-(i - 2) * 0.28, 2)))

    def fence(self, parent, name, x0, x1, z, y=0.0, step=0.7, mat="iron"):
        n = int((x1 - x0) / step) + 1
        self.box(parent, f"{name}Rail", ((x0 + x1) / 2, y + 0.9, z), (x1 - x0, 0.08, 0.06), mat)
        for i in range(n):
            self.box(parent, f"{name}{i}", (round(x0 + i * step, 2), y + 0.75, z), (0.08, 1.5 + (i % 2) * 0.2, 0.08), mat,
                     rot=(0, 0, round((i * 7 % 5 - 2) * 0.03, 3)))

    def crow(self, parent, name, x, y, z):
        self.box(parent, f"{name}Body", (x, y + 0.13, z), (0.3, 0.2, 0.14), "iron", rot=(0, 0, 0.35))
        self.box(parent, f"{name}Head", (x + 0.16, y + 0.28, z), (0.12, 0.12, 0.11), "iron")

    def candles(self, parent, name, x, y, z, count=3, light=True):
        for i in range(count):
            self.box(parent, f"{name}{i}", (x + i * 0.18, y + 0.12 + (i % 2) * 0.06, z), (0.07, 0.24 + (i % 2) * 0.12, 0.07), "candle")
        if light:
            self.light(parent, f"{name}Light", (x + 0.2, y + 0.6, z + 0.6), (1.0, 0.68, 0.35), 0.9, 4.0)

    def ruined_house(self, parent, name, x, z, w, h, roof_h, ground=0.0, windows=()):
        """Брошенный дом: чёрные окна, болтающиеся ставни, мох, провалившаяся крыша."""
        self.box(parent, f"{name}Wall", (x, ground + h / 2, z), (w, h, 3), "plaster")
        self.roof(parent, f"{name}Roof", (x - w * 0.15, ground + h + roof_h / 2 - 0.3, z), (w * 0.8, roof_h, 3.6), "thatch", rot=(0, 0, 0.12))
        self.box(parent, f"{name}Beam", (x + w * 0.3, ground + h + 0.4, z + 1.2), (w * 0.5, 0.2, 0.2), "wood_dark", rot=(0, 0, -0.5))
        for i, (wx, wy) in enumerate(windows):
            self.box(parent, f"{name}Window{i}", (x + wx, ground + wy, z + 1.53), (0.8, 1.0, 0.08), "char")
            self.box(parent, f"{name}Shutter{i}", (x + wx + 0.6, ground + wy - 0.2, z + 1.6), (0.45, 0.9, 0.06), "wood", rot=(0, 0, 0.35 + i * 0.2))
        self.box(parent, f"{name}Moss", (x - w * 0.25, ground + 0.4, z + 1.52), (w * 0.4, 0.8, 0.06), "moss")

    # --- объекты
    def door(self, name, x, y, target, spawn, prompt, extra=()):
        self.node(name, 'type="Area3D"', "Objects", [f"position = Vector3({x}, {y}, 0)", 'script = ExtResource("door")', f'target_room = &"{target}"',
                  f'target_spawn = NodePath("{spawn}")', f'open_prompt = "{prompt}"'] + list(extra))

    def ladder(self, name, x, y, height, exit_dir):
        self.node(name, 'type="Area3D"', "Objects", [f"position = Vector3({x}, {y}, 0)", 'script = ExtResource("ladder")', f"height = {height}", f"exit_dir = {exit_dir}"])

    def ladder_look(self, name, x, y, height, mat="wood_dark", rungs=True):
        self.box("Decor", f"{name}RailA", (x - 0.3, y + height / 2, -0.4), (0.08, height, 0.08), mat)
        self.box("Decor", f"{name}RailB", (x + 0.3, y + height / 2, -0.4), (0.08, height, 0.08), mat)
        if rungs:
            for i in range(int(height / 0.45)):
                self.box("Decor", f"{name}Rung{i}", (x, y + 0.3 + i * 0.45, -0.4), (0.6, 0.06, 0.06), mat)

    def shard(self, name, x, y, parent="Objects"):
        self.instance(name, parent, "shard", [f"position = Vector3({x}, {y}, 0)"])

    def chest(self, name, pos, reward, flag, items=()):
        props = [f"position = {v3(pos)}", f"reward = {reward}", f'flag_id = &"{flag}"']
        if items:
            props.append("items = Array[StringName]([" + ", ".join(f'&"{i}"' for i in items) + "])")
        self.instance(name, "Objects", "chest", props)

    def note(self, name, x, y, title, lines):
        quoted = ", ".join('"' + line + '"' for line in lines)
        self.node(name, 'type="Area3D"', "Objects", [f"position = Vector3({x}, {y}, 0)", 'script = ExtResource("note")',
                  f'title = "{title}"', f"lines = PackedStringArray({quoted})"])

    def enemy(self, name, scene, pos, props=()):
        self.instance(name, "Objects", scene, [f"position = {v3(pos)}"] + list(props))

    # --- текст сцены
    def env_text(self, sid, e):
        return (f'[sub_resource type="Environment" id="{sid}"]\nbackground_mode = 1\nbackground_color = Color({e["bg"][0]}, {e["bg"][1]}, {e["bg"][2]}, 1)\n'
                f'ambient_light_source = 2\nambient_light_color = Color({e["amb"][0]}, {e["amb"][1]}, {e["amb"][2]}, 1)\nambient_light_energy = {e["amb_e"]}\n'
                f'tonemap_mode = 2\nglow_enabled = true\nglow_intensity = 0.7\nglow_bloom = 0.06\nfog_enabled = true\n'
                f'fog_light_color = Color({e["fog"][0]}, {e["fog"][1]}, {e["fog"][2]}, 1)\nfog_density = {e["fog_d"]}')

    def text(self):
        ext = [f'[ext_resource type="{kind}" path="{path}" id="{key}"]' for key, (kind, path) in EXT.items()]
        subs = []
        for name in sorted(self.used):
            if name in MATS:
                c = MATS[name]
                extra = "\nroughness = 0.15\nmetallic = 0.2" if name == "water" else "\nroughness = 0.95"
                subs.append(f'[sub_resource type="StandardMaterial3D" id="Mat_{name}"]\nalbedo_color = Color({c[0]}, {c[1]}, {c[2]}, 1){extra}')
            elif name in GLOW:
                c, e = GLOW[name]
                subs.append(f'[sub_resource type="StandardMaterial3D" id="Mat_{name}"]\nalbedo_color = Color({c[0]}, {c[1]}, {c[2]}, 1)\nemission_enabled = true\n'
                            f'emission = Color({c[0]}, {c[1]}, {c[2]}, 1)\nemission_energy_multiplier = {e}')
            else:
                c, a = VEILS[name]
                subs.append(f'[sub_resource type="StandardMaterial3D" id="Mat_{name}"]\ntransparency = 1\nshading_mode = 0\ncull_mode = 2\n'
                            f'albedo_color = Color({c[0]}, {c[1]}, {c[2]}, {a})')
        subs.append(self.env_text("Env_room", self.env))
        subs += self.subs
        head = [f"[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]"] + ext + subs
        root = (f'[node name="{self.name}" type="Node3D"]\nscript = ExtResource("room")\nroom_id = &"{self.room_id}"\ncenter_x = 0.0\nwidth = {self.width}\n'
                f'mood = SubResource("Env_room")\nsun_color = Color({self.sun_color[0]}, {self.sun_color[1]}, {self.sun_color[2]}, 1)\nsun_energy = {self.sun_energy}')
        containers = [f'[node name="{c}" type="Node3D" parent="."]' for c in ("Geometry", "Decor", "Spawns", "Objects")]
        return "\n\n".join(head + [root] + containers + self.nodes) + "\n"


def enemy_scene(script, root, subs, health, props, nodes):
    """Сцена врага: CharacterBody3D, Health и узлы модели. Hitbox/Hurtbox — ext 2_hitbox/3_hurtbox."""
    return f'''[gd_scene format=3]

[ext_resource type="Script" path="{script}" id="1_script"]
[ext_resource type="Script" path="res://combat/hitboxes/hitbox.gd" id="2_hitbox"]
[ext_resource type="Script" path="res://combat/hitboxes/hurtbox.gd" id="3_hurtbox"]
[ext_resource type="Script" path="res://combat/damage/health.gd" id="4_health"]

{subs}

{root}
script = ExtResource("1_script")
{props}

{nodes}

[node name="Health" type="Node" parent="."]
script = ExtResource("4_health")
max_health = {health}
'''


def mesh_node(name, parent, mesh, pos, rot_z=0.0):
    c, s = math.cos(rot_z), math.sin(rot_z)
    basis = f"{round(c, 4)}, {round(s, 4)}, 0, {round(-s, 4)}, {round(c, 4)}, 0, 0, 0, 1" if rot_z else "1, 0, 0, 0, 1, 0, 0, 0, 1"
    return f'[node name="{name}" type="MeshInstance3D" parent="{parent}"]\ntransform = Transform3D({basis}, {pos[0]}, {pos[1]}, {pos[2]})\nmesh = SubResource("{mesh}")'


def node3d(name, parent, pos):
    return f'[node name="{name}" type="Node3D" parent="{parent}"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {pos[0]}, {pos[1]}, {pos[2]})'


def box_mesh(sid, size, mat=None):
    line = f'\nmaterial = SubResource("{mat}")' if mat else ""
    return f'[sub_resource type="BoxMesh" id="{sid}"]{line}\nsize = Vector3({size[0]}, {size[1]}, {size[2]})'


def box_shape(sid, size):
    return f'[sub_resource type="BoxShape3D" id="{sid}"]\nsize = Vector3({size[0]}, {size[1]}, {size[2]})'


def material(sid, color, emission=0.0, alpha=1.0):
    text = f'[sub_resource type="StandardMaterial3D" id="{sid}"]\nalbedo_color = Color({color[0]}, {color[1]}, {color[2]}, {alpha})'
    if alpha < 1.0:
        text += "\ntransparency = 1"
    if emission:
        text += f"\nemission_enabled = true\nemission = Color({color[0]}, {color[1]}, {color[2]}, 1)\nemission_energy_multiplier = {emission}"
    return text


def hitbox_nodes(parent, shape, pos, damage, knockback, name="AttackHitbox"):
    return (f'[node name="{name}" type="Area3D" parent="{parent}"]\ncollision_layer = 0\ncollision_mask = 2\nscript = ExtResource("2_hitbox")\n'
            f'damage = {damage}\nknockback = {knockback}\n\n'
            f'[node name="Shape" type="CollisionShape3D" parent="{parent}/{name}"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {pos[0]}, {pos[1]}, {pos[2]})\n'
            f'shape = SubResource("{shape}")')


def hurtbox_nodes(shape, y):
    return (f'[node name="Hurtbox" type="Area3D" parent="."]\ncollision_layer = 4\ncollision_mask = 0\nscript = ExtResource("3_hurtbox")\n\n'
            f'[node name="Shape" type="CollisionShape3D" parent="Hurtbox"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {y}, 0)\n'
            f'shape = SubResource("{shape}")')


def collision_node(shape, y):
    return (f'[node name="Collision" type="CollisionShape3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {y}, 0)\n'
            f'shape = SubResource("{shape}")')
