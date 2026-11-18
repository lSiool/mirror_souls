"""Деревня героя и часовня (graybox по art/concepts/locations): хижина, улица, дом, площадь, двор часовни, часовня;
мышь и оборотень. Лес — build_forest.py, враги леса и босс — build_enemies.py.
Запуск из корня проекта: python tools/levels/build_village.py
"""
import math
import zlib
from pathlib import Path

import backdrop as bd

MATS = {
    "mud": (0.2, 0.17, 0.15), "stone": (0.27, 0.27, 0.29), "stone_dark": (0.15, 0.15, 0.17),
    "wood": (0.25, 0.17, 0.11), "wood_dark": (0.12, 0.09, 0.07), "thatch": (0.2, 0.16, 0.13),
    "plaster": (0.3, 0.27, 0.23), "iron": (0.09, 0.09, 0.1), "cloth": (0.1, 0.09, 0.12),
    "bedding": (0.36, 0.33, 0.27), "statue": (0.3, 0.32, 0.36), "fir": (0.07, 0.09, 0.11), "earth_dark": (0.05, 0.045, 0.05), "char": (0.035, 0.03, 0.03), "rotten": (0.34, 0.27, 0.17), "fur": (0.09, 0.075, 0.07), "garlic": (0.72, 0.68, 0.58),
}
GLOW = {"window": ((1.0, 0.6, 0.25), 2.6), "fire": ((1.0, 0.45, 0.12), 4.0), "moonpane": ((0.45, 0.6, 0.85), 1.1), "stained_blue": ((0.1, 0.2, 0.48), 0.9), "stained_dim": ((0.13, 0.15, 0.3), 0.35), "stained_red": ((0.6, 0.12, 0.1), 1.0), "stained_gold": ((0.75, 0.5, 0.16), 1.0)}

BURN = {"bg": (0.07, 0.022, 0.012), "amb": (0.62, 0.36, 0.26), "amb_e": 0.3, "fog": (0.26, 0.085, 0.035), "fog_d": 0.015}
BURN_IN = {"bg": (0.0, 0.0, 0.0), "amb": (0.6, 0.35, 0.22), "amb_e": 0.3, "fog": (0.03, 0.012, 0.006), "fog_d": 0.004}


# Модели из конвейера ComfyUI → TRELLIS.2 (docs/ART_PIPELINE.md). В файле ~1 м; числа — glb_bounds.py:
# низ модели (min y), высота, центр по x и z.
PROPS = {
    "barrel": ("res://assets/props/barrel/prop_barrel.glb", -0.5, 1.0, 0.0, 0.0),
    "woodpile": ("res://assets/props/woodpile/prop_woodpile.glb", -0.307, 0.615, 0.0, 0.008),
    "cartwheel": ("res://assets/props/cartwheel/prop_cartwheel.glb", -0.5, 1.0, 0.0, 0.003),
    "haystack": ("res://assets/props/haystack/prop_haystack.glb", -0.358, 0.745, -0.002, -0.002),
    "fence": ("res://assets/props/fence/prop_fence.glb", -0.458, 0.916, 0.0, 0.01),
    "deadtree": ("res://assets/props/deadtree/prop_deadtree.glb", -0.496, 0.986, 0.002, -0.01),
    "house_hut": ("res://assets/props/house_hut/prop_house_hut.glb", -0.427, 0.856, 0.002, 0.0),
    "house_twostorey": ("res://assets/props/house_twostorey/prop_house_twostorey.glb", -0.496, 0.994, -0.007, 0.002),
    "house_narrow": ("res://assets/props/house_narrow/prop_house_narrow.glb", -0.492, 0.991, 0.008, -0.003),
}


# Дома-модели: поворот, при котором фронтон смотрит в камеру (огонь крыши рассчитан на фронтон, FireSpot.roof),
# карниз и конёк — доли высоты модели (по снимкам glb_views.gd), ширина фронтона и глубина — в единицах файла.
HOUSES = {
    "house_hut": (math.pi, 0.43, 0.94, 0.922, 0.996),
    "house_twostorey": (math.pi / 2, 0.6, 0.98, 0.659, 0.934),
    "house_narrow": (math.pi, 0.6, 1.0, 0.638, 0.589),
}
HOUSE_DEPTH = 3.6  # как у прежней крыши-примитива: дом не подходит к плоскости героя


class Scene:
    def __init__(self, name, room_id, width, center, env, sun_color, sun_energy, burn=None):
        self.name, self.room_id, self.width, self.center = name, room_id, width, center
        self.env, self.sun_color, self.sun_energy, self.burn = env, sun_color, sun_energy, burn
        self.nodes, self.subs, self.used = [], [], set()
        self.meshes = 0
        self.ext = {"room": ("Script", "res://world/rooms/room.gd"), "door": ("Script", "res://world/common/room_door.gd"),
                    "pickup": ("Script", "res://world/common/item_pickup.gd"), "ladder": ("Script", "res://world/common/ladder.gd"),
                    "intro": ("Script", "res://world/rooms/hut_intro.gd"), "rat": ("PackedScene", "res://actors/enemies/rat.tscn"),
                    "bat": ("PackedScene", "res://actors/enemies/bat.tscn"), "smith": ("PackedScene", "res://actors/enemies/blacksmith.tscn"),
                    "shard": ("PackedScene", "res://world/checkpoints/mirror_shard.tscn"),
                    "fire": ("Script", "res://world/common/fire_spot.gd"), "bgscene": ("Script", "res://world/common/background_scene.gd"),
                    "ambience": ("Script", "res://world/common/burning_ambience.gd"), "npc": ("Script", "res://world/common/npc.gd"),
                    "sayline": ("Script", "res://world/common/say_line.gd"),
                    "mainmirror": ("Script", "res://world/common/main_mirror.gd"), "squareevent": ("Script", "res://world/rooms/square_event.gd"),
                    "wolf": ("PackedScene", "res://actors/enemies/werewolf.tscn"), "glass": ("PackedScene", "res://world/glass/glass_surface.tscn"),
                    "chest": ("PackedScene", "res://world/chest/chest.tscn")}

    def prop(self, parent, name, key, bottom, height, rot=None, depth=1.0):
        """Модель из PROPS дном в точку bottom, высотой height (м). rot — поворот по Y (рад), по умолчанию — от имени;
        depth — сплющить по глубине мира Z (деревья и дома не должны дотягиваться до плоскости героя). Базис в .tscn — по строкам."""
        path, y0, h0, cx, cz = PROPS[key]
        self.ext[key] = ("PackedScene", path)
        if rot is None:
            rot = (zlib.crc32(name.encode()) % 360) * math.pi / 180
        k, c, sn = height / h0, math.cos(rot), math.sin(rot)
        rows = ((c * k, 0.0, sn * k), (0.0, k, 0.0), (-sn * k * depth, 0.0, c * k * depth))
        local = (cx, y0, cz)
        origin = [bottom[i] - sum(rows[i][j] * local[j] for j in range(3)) for i in range(3)]
        vals = ", ".join(f"{v:.4f}".rstrip("0").rstrip(".") if v else "0" for row in rows for v in row)
        org = ", ".join(f"{v:.3f}" for v in origin)
        self.nodes.append(f'[node name="{name}" parent="{parent}" instance=ExtResource("{key}")]\ntransform = Transform3D({vals}, {org})')

    def breakable(self, name, key, pos, height, size, stuff=0, hits=1, echoes=0, solid=False):
        """Разрушаемый предмет (world/props/breakable.gd) на плоскости героя. stuff: 0 дерево, 1 глина, 2 плетёнка, 3 кость.
        solid=False — не преграждает путь (первый проход: не мешать маршрутам смоук-теста)."""
        path, y0, h0, _cx, _cz = PROPS[key]
        self.ext[key] = ("PackedScene", path)
        self.ext["breakable"] = ("Script", "res://world/props/breakable.gd")
        turn = round((zlib.crc32(name.encode()) % 360) * math.pi / 180, 3)
        self.node(name, 'type="StaticBody3D"', "Objects", [f"position = Vector3({pos[0]}, {pos[1]}, {pos[2]})", 'script = ExtResource("breakable")',
                  f'model = ExtResource("{key}")', f"model_bottom = {y0}", f"model_height = {h0}", f"height = {height}",
                  f"model_turn = {turn}", f"size = Vector3({size[0]}, {size[1]}, {size[2]})", f"solid = {str(solid).lower()}",
                  f"stuff = {stuff}", f"hits = {hits}", f"echoes = {echoes}"])

    def mat(self, name):
        self.used.add(name)
        return f'SubResource("Mat_{name}")'

    def node(self, name, kind, parent, props, extra=""):
        lines = [f'[node name="{name}" {kind} parent="{parent}"{extra}]'] + props
        self.nodes.append("\n".join(lines))

    def box(self, parent, name, pos, size, mat, collide=False, rot=None):
        props = [f"position = Vector3({pos[0]}, {pos[1]}, {pos[2]})"]
        if rot is not None:
            props.append(f"rotation = Vector3({rot[0]}, {rot[1]}, {rot[2]})")
        if collide:
            props.append("use_collision = true")
        props += [f"size = Vector3({size[0]}, {size[1]}, {size[2]})", f"material = {self.mat(mat)}"]
        self.node(name, 'type="CSGBox3D"', parent, props)

    def cyl(self, parent, name, pos, radius, height, mat, rot=None, sides=12, cone=False):
        props = [f"position = Vector3({pos[0]}, {pos[1]}, {pos[2]})"]
        if rot is not None:
            props.append(f"rotation = Vector3({rot[0]}, {rot[1]}, {rot[2]})")
        props += [f"radius = {radius}", f"height = {height}", f"sides = {sides}"]
        if cone:
            props.append("cone = true")
        props.append(f"material = {self.mat(mat)}")
        self.node(name, 'type="CSGCylinder3D"', parent, props)

    def sphere(self, parent, name, pos, radius, mat):
        self.node(name, 'type="CSGSphere3D"', parent, [f"position = Vector3({pos[0]}, {pos[1]}, {pos[2]})",
                                                         f"radius = {radius}", f"material = {self.mat(mat)}"])

    def roof(self, parent, name, pos, size, mat="thatch"):
        self.meshes += 1
        sid = f"Roof_{self.meshes}"
        self.subs.append(f'[sub_resource type="PrismMesh" id="{sid}"]\nmaterial = {self.mat(mat)}\nsize = Vector3({size[0]}, {size[1]}, {size[2]})')
        self.node(name, 'type="MeshInstance3D"', parent, [f"position = Vector3({pos[0]}, {pos[1]}, {pos[2]})", f'mesh = SubResource("{sid}")'])

    def light(self, parent, name, pos, color, energy, rng, shadow=False):
        props = [f"position = Vector3({pos[0]}, {pos[1]}, {pos[2]})", f"light_color = Color({color[0]}, {color[1]}, {color[2]}, 1)",
                 f"light_energy = {energy}", f"omni_range = {rng}"]
        if shadow:
            props.append("shadow_enabled = true")
        self.node(name, 'type="OmniLight3D"', parent, props)

    def marker(self, name, pos):
        self.node(name, 'type="Marker3D"', "Spawns", [f"position = Vector3({pos[0]}, {pos[1]}, {pos[2]})"])

    def wall(self, name, pos, size, parent="Geometry"):
        """Невидимая стена края комнаты: только коллизия; дальше видны земля и фон (§2.2)."""
        self.meshes += 1
        sid = f"Wall_{self.meshes}"
        self.subs.append(f'[sub_resource type="BoxShape3D" id="{sid}"]\nsize = Vector3({size[0]}, {size[1]}, {size[2]})')
        self.node(name, 'type="StaticBody3D"', parent, [f"position = Vector3({pos[0]}, {pos[1]}, {pos[2]})"])
        self.node("Shape", 'type="CollisionShape3D"', f"{parent}/{name}", [f'shape = SubResource("{sid}")'])

    def house(self, parent, name, x, z, w, h, roof_h, windows=(), plaster="plaster", ground=0.0, fire=None, model=None):
        if model:
            # Модель высотой h + roof_h, фронтоном к камере, глубиной HOUSE_DEPTH. Огонь — по крыше модели.
            rot, eave, ridge, gable_w, depth = HOUSES[model]
            height = h + roof_h
            k = height / PROPS[model][2]
            self.prop(parent, name, model, (x, ground, z), height, rot=rot, depth=HOUSE_DEPTH / (depth * k))
            if fire and self.burn:
                roof_size = (round(gable_w * k, 3), round((ridge - eave) * height, 3), HOUSE_DEPTH)
                self.fire(f"{name}RoofFire", (x, round(ground + eave * height, 3), z), roof_size, *fire,
                          roof=zlib.crc32(f"{name}{x}{z}".encode()) % 10000)
            return
        self.box(parent, f"{name}Wall", (x, ground + h / 2, z), (w, h, 3), plaster)
        self.roof(parent, f"{name}Roof", (x, ground + h + roof_h / 2, z), (w + 1.2, roof_h, 3.6))
        if fire and self.burn:
            # Крыша горит: у каждого дома пожар свой — раскладку языков задаёт зерно (FireSpot.roof_seed).
            self.fire(f"{name}RoofFire", (x, ground + h, z), (w + 1.2, roof_h, 3.6), *fire, roof=zlib.crc32(f"{name}{x}{z}".encode()) % 10000)
        for b, off in enumerate((-w / 2 + 0.15, w / 2 - 0.15)):
            self.box(parent, f"{name}Post{b}", (x + off, ground + h / 2, z + 1.55), (0.25, h, 0.15), "wood_dark")
        self.box(parent, f"{name}Beam", (x, ground + h * 0.55, z + 1.55), (w, 0.2, 0.15), "wood_dark")
        for i, (wx, wy) in enumerate(windows):
            pane = (x + wx, ground + wy, z + 1.53)
            if self.burn:
                # В пожаре из окон рвётся огонь, после него они чёрные: живых в домах нет.
                self.box("Burning", f"{name}Window{i}", pane, (0.8, 1.0, 0.08), "window")
                self.box("AfterFire", f"{name}Window{i}", pane, (0.8, 1.0, 0.08), "char")
            else:
                self.box(parent, f"{name}Window{i}", pane, (0.8, 1.0, 0.08), "window")

    def fence(self, parent, name, x0, x1, z, y=0.0, step=0.7):
        h = 1.45
        w = PROPS["fence"][2] and h / PROPS["fence"][2] * 0.999  # ширина секции при высоте h
        n = max(1, round((x1 - x0) / w))
        for i in range(n):
            cx = x0 + (x1 - x0) * (i + 0.5) / n
            self.prop(parent, f"{name}{i}", "fence", (round(cx, 3), y, z), h, rot=math.pi * (i % 2))

    def wheel(self, parent, name, x, y, z, r):
        if r >= 0.6:
            self.prop(parent, name, "cartwheel", (x, round(y - r, 3), z), round(2 * r, 3), rot=0.0)
            return
        for i in range(10):
            a = i * math.tau / 10
            self.box(parent, f"{name}Rim{i}", (round(x + r * math.cos(a), 3), round(y + r * math.sin(a), 3), z),
                     (round(r * 0.68, 3), 0.13, 0.1), "wood_dark", rot=(0, 0, round(a + math.pi / 2, 4)))
        for i in range(3):
            self.box(parent, f"{name}Spoke{i}", (x, y, z), (round(r * 2, 3), 0.08, 0.07), "wood_dark", rot=(0, 0, round(i * math.pi / 3 + 0.3, 4)))

    def dead_tree(self, parent, name, x, z, h, ground=0.0):
        self.prop(parent, name, "deadtree", (x, ground, z), h, depth=0.5)

    def lantern_post(self, parent, name, x, z, ground=0.0, side=1):
        # Модель prop_lanternpost (ComfyUI → TRELLIS.2): в файле ~1 м, перекладина вдоль +Z. Поворот на 90° по Y кладёт её вдоль ±X (side),
        # масштаб ×4 ≈ 4 м. Основание столба в файле на z = -0.032, лампа на z = +0.224, y ≈ 0 (середина высоты). Базис в .tscn — по строкам.
        self.ext["lantern"] = ("PackedScene", "res://assets/props/lanternpost/prop_lanternpost.glb")
        k = 4.0
        ox, oy = x + side * 0.032 * k, ground + 0.498 * k
        self.nodes.append(f'[node name="{name}" parent="{parent}" instance=ExtResource("lantern")]\n'
                          f'transform = Transform3D(0, 0, {side * k}, 0, {k}, 0, {-side * k}, 0, 0, {round(ox, 3)}, {round(oy, 3)}, {z})')
        self.light(parent, f"{name}Light", (round(x + side * 1.0, 3), ground + 1.8, z + 0.8), (1.0, 0.6, 0.28), 1.3, 6.5)

    def woodpile(self, parent, name, x, z, ground=0.0, columns=5):
        self.prop(parent, name, "woodpile", (round(x + columns * 0.19, 3), ground, z), 1.1, rot=0.0)

    def wash_line(self, parent, name, x0, x1, z, ground=0.0):
        for i, x in enumerate((x0, x1)):
            self.box(parent, f"{name}Post{i}", (x, ground + 1.7, z), (0.14, 3.4, 0.14), "wood_dark")
        self.box(parent, f"{name}Rope", ((x0 + x1) / 2, ground + 3.2, z), (x1 - x0, 0.04, 0.04), "iron")
        count = int((x1 - x0) / 1.3)
        for i in range(count):
            size = (0.8, 1.2 - (i % 3) * 0.2, 0.04)
            self.box(parent, f"{name}Cloth{i}", (round(x0 + 0.8 + i * 1.3, 2), round(ground + 3.2 - size[1] / 2, 2), z), size, "cloth")

    def garlic(self, parent, name, x, y, z):
        for i in range(4):
            self.sphere(parent, f"{name}{i}", (round(x + (i % 2) * 0.16, 2), round(y - i * 0.2, 2), z), 0.13, "garlic")

    def rocks(self, parent, name, x, y, z):
        for i, (dx, s, a) in enumerate(((0.0, 0.8, 0.3), (0.8, 0.5, -0.4), (-0.7, 0.45, 0.6))):
            self.box(parent, f"{name}{i}", (round(x + dx, 2), round(y + s * 0.3, 2), z), (s * 1.4, s, s * 1.1), "earth_dark", rot=(0.2, a, a * 0.5))

    def tuft(self, parent, name, x, y, z):
        for i in range(5):
            a = (i - 2) * 0.28
            self.box(parent, f"{name}{i}", (round(x + (i - 2) * 0.12, 2), y + 0.35, z), (0.04, 0.7, 0.04), "wood_dark", rot=(0, 0, round(-a, 2)))

    def crow(self, parent, name, x, y, z):
        self.box(parent, f"{name}Body", (x, y + 0.13, z), (0.3, 0.2, 0.14), "iron", rot=(0, 0, 0.35))
        self.box(parent, f"{name}Head", (x + 0.16, y + 0.28, z), (0.12, 0.12, 0.11), "iron")

    def fire(self, name, pos, size=(1.6, 2.2, 0.6), energy=2.2, rng=8.0, roof=None):
        self.node(name, 'type="Node3D"', "Burning", [f"position = Vector3({pos[0]}, {pos[1]}, {pos[2]})", 'script = ExtResource("fire")',
                  f"size = Vector3({size[0]}, {size[1]}, {size[2]})", f"light_energy = {energy}", f"light_range = {rng}"]
                  + (["roof = true", f"roof_seed = {roof}"] if roof is not None else []))

    def scene_bg(self, name, pos, kind, rng=15.0):
        self.node(name, 'type="Node3D"', "Burning", [f"position = Vector3({pos[0]}, {pos[1]}, {pos[2]})", 'script = ExtResource("bgscene")',
                  f"kind = {kind}", f"trigger_range = {rng}"])

    def ambience(self, calls=(), every=12.0):
        quoted = ", ".join(f'"{c}"' for c in calls)
        self.node("Ambience", 'type="Node"', "Burning", ['script = ExtResource("ambience")', f"calls = PackedStringArray({quoted})", f"every = {every}"])

    def env_text(self, sid, e):
        return (f'[sub_resource type="Environment" id="{sid}"]\nbackground_mode = 1\nbackground_color = Color({e["bg"][0]}, {e["bg"][1]}, {e["bg"][2]}, 1)\n'
                f'ambient_light_source = 2\nambient_light_color = Color({e["amb"][0]}, {e["amb"][1]}, {e["amb"][2]}, 1)\nambient_light_energy = {e["amb_e"]}\n'
                f'tonemap_mode = 2\nglow_enabled = true\nglow_intensity = 0.7\nglow_bloom = 0.06\nfog_enabled = true\n'
                f'fog_light_color = Color({e["fog"][0]}, {e["fog"][1]}, {e["fog"][2]}, 1)\nfog_density = {e["fog_d"]}')

    def text(self):
        ext = []
        for key, (kind, path) in self.ext.items():
            ext.append(f'[ext_resource type="{kind}" path="{path}" id="{key}"]')
        subs = []
        for name in sorted(self.used):
            if name in MATS:
                c = MATS[name]
                subs.append(f'[sub_resource type="StandardMaterial3D" id="Mat_{name}"]\nalbedo_color = Color({c[0]}, {c[1]}, {c[2]}, 1)\nroughness = 0.95')
            else:
                c, e = GLOW[name]
                subs.append(f'[sub_resource type="StandardMaterial3D" id="Mat_{name}"]\nalbedo_color = Color({c[0]}, {c[1]}, {c[2]}, 1)\nemission_enabled = true\nemission = Color({c[0]}, {c[1]}, {c[2]}, 1)\nemission_energy_multiplier = {e}')
        subs.append(self.env_text("Env_room", self.env))
        if self.burn:
            subs.append(self.env_text("Env_burn", self.burn))
        subs += self.subs
        head = [f'[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]'] + ext + subs
        root = (f'[node name="{self.name}" type="Node3D"]\nscript = ExtResource("room")\nroom_id = &"{self.room_id}"\ncenter_x = {self.center}\nwidth = {self.width}\n'
                f'mood = SubResource("Env_room")\nsun_color = Color({self.sun_color[0]}, {self.sun_color[1]}, {self.sun_color[2]}, 1)\nsun_energy = {self.sun_energy}')
        if self.burn:
            root += '\nburning_until = &"fire_out"\nburning_mood = SubResource("Env_burn")'
        names = ("Geometry", "Decor", "Spawns", "Objects") + (("Burning", "AfterFire") if self.burn else ())
        containers = [f'[node name="{c}" type="Node3D" parent="."]' for c in names]
        return "\n\n".join(head + [root] + containers + self.nodes) + "\n"


def door(s, name, x, y, target, spawn, prompt, extra=()):
    props = [f"position = Vector3({x}, {y}, 0)", 'script = ExtResource("door")', f'target_room = &"{target}"',
             f'target_spawn = NodePath("{spawn}")', f'open_prompt = "{prompt}"'] + list(extra)
    s.node(name, 'type="Area3D"', "Objects", props)


# ---------------------------------------------------------------- Хижина
hut = Scene("VillageHut", "village_hut", 16.0, 0.0,
            {"bg": (0.0, 0.0, 0.0), "amb": (0.4, 0.3, 0.24), "amb_e": 0.28, "fog": (0.012, 0.009, 0.007), "fog_d": 0.004},
            (0.5, 0.6, 0.8), 0.0, BURN_IN)
g, d = "Geometry", "Decor"
hut.box(g, "Floor", (0, -1, 0), (17, 2, 4), "wood_dark", True)
hut.box(g, "WallLeft", (-8.5, 3, 0), (1, 8, 4), "stone_dark", True)
hut.box(g, "WallRight", (8.5, 3, 0), (1, 8, 4), "stone_dark", True)
hut.box(g, "Ceiling", (0, 6.5, 0), (18, 1, 4), "wood_dark", True)
hut.box(d, "BackWall", (0, 3, -2.2), (17, 7, 0.4), "plaster")
for i, x in enumerate((-6.5, -3.0, 0.0, 3.0, 6.5)):
    hut.box(d, f"Post{i}", (x, 3, -1.9), (0.3, 6, 0.3), "wood")
for i, y in enumerate((1.9, 4.4)):
    hut.box(d, f"Rail{i}", (0, y, -1.95), (16, 0.2, 0.15), "wood")
for i, x in enumerate((-5, 0, 5)):
    hut.box(d, f"Rafter{i}", (x, 5.1, -0.6), (0.3, 0.3, 3.2), "wood")
# Кровать: слева, откуда герой встаёт
hut.box(d, "BedFrame", (-5.7, 0.28, -0.9), (2.4, 0.55, 1.1), "wood")
hut.box(d, "Bedding", (-5.7, 0.62, -0.9), (2.2, 0.22, 1.0), "bedding")
# Очаг
hut.box(d, "HearthStone", (-2.0, 1.25, -1.75), (2.8, 2.5, 0.7), "stone")
hut.box(d, "HearthMouth", (-2.0, 0.65, -1.38), (1.5, 1.1, 0.1), "stone_dark")
hut.box(d, "Fire", (-2.0, 0.42, -1.3), (0.9, 0.55, 0.1), "fire")
hut.light(d, "FireLight", (-2.0, 1.1, -0.5), (1.0, 0.55, 0.22), 2.6, 9.0, True)
# Стол со свечой и полка
hut.box(d, "TableTop", (1.0, 0.95, -1.1), (2.4, 0.12, 1.0), "wood")
for i, x in enumerate((0.0, 2.0)):
    hut.box(d, f"TableLeg{i}", (x, 0.45, -1.1), (0.14, 0.9, 0.14), "wood_dark")
hut.box(d, "Candle", (1.3, 1.14, -1.1), (0.08, 0.26, 0.08), "fire")
hut.light(d, "CandleLight", (1.3, 1.6, -0.8), (1.0, 0.65, 0.35), 0.9, 4.0)
hut.box(d, "Shelf", (1.0, 2.6, -1.85), (2.6, 0.1, 0.4), "wood")
for i, x in enumerate((0.1, 0.7, 1.4, 1.9)):
    hut.cyl(d, f"Jar{i}", (x, 2.86, -1.85), 0.14, 0.42, "stone_dark")
# Окно: холодный свет снаружи
hut.box("AfterFire", "Window", (4.0, 2.9, -1.96), (1.6, 1.9, 0.08), "moonpane")
hut.light("AfterFire", "WindowLight", (4.0, 2.6, -0.8), (0.5, 0.65, 0.95), 1.1, 6.0)
hut.box("Burning", "WindowFire", (4.0, 2.9, -1.96), (1.6, 1.9, 0.08), "fire")
hut.fire("WindowFlames", (4.0, 2.0, -1.85), (1.2, 1.6, 0.3), 2.0, 7.0)
hut.ambience()
# Прялка и бочка у двери
hut.cyl(d, "SpinWheel", (5.3, 0.9, -1.0), 0.7, 0.1, "wood", rot=(math.pi / 2, 0, 0), sides=14)
hut.prop(d, "Barrel", "barrel", (-7.3, 0.5 - 0.5, -1.2), 1.1)
# Чеснок под балкой
for i, (x, y) in enumerate(((-7.2, 4.5), (-6.9, 4.2), (-7.5, 4.2), (6.9, 4.5), (7.2, 4.15))):
    hut.sphere(d, f"Garlic{i}", (x, y, -1.5), 0.17, "garlic")
hut.marker("PlayerStart", (-5.7, 0.1, 0))
hut.marker("FromStreet", (6.0, 0.1, 0))
door(hut, "DoorToStreet", 7.0, 0, "village_street", "Spawns/FromHut", "Выйти наружу")
hut.node("Intro", 'type="Node"', "Objects", ['script = ExtResource("intro")'])

# ---------------------------------------------------------------- Улица
st = Scene("VillageStreet", "village_street", 64.0, 0.0,
           {"bg": (0.045, 0.055, 0.095), "amb": (0.34, 0.4, 0.58), "amb_e": 0.42, "fog": (0.16, 0.19, 0.3), "fog_d": 0.022},
           (0.55, 0.65, 0.9), 0.35, BURN)
# Земля: хижина на пригорке, тропа спускается к площади
st.box(g, "GroundHigh", (-38.5, -1.3, 0), (49, 5, 4.4), "mud", True)
slope = math.atan2(1.2, 6.0)
st.box(g, "Ramp", (-11.0, 0.1, 0), (6.2, 1.0, 4.4), "mud", True, rot=(0, 0, -round(slope, 4)))
st.box(g, "GroundLow", (26.5, -2, 0), (73, 4, 4.4), "mud", True)
st.box(d, "RampBase", (-12.0, -2, 0), (5.0, 4, 4.4), "mud")
st.wall("WallLeft", (-33.5, 6, 0), (1, 20, 4.4))
st.wall("WallRight", (33.5, 6, 0), (1, 20, 4.4))
# Края улицы — дома, а не стены: деревня продолжается за кадр.
st.house(d, "EdgeHouseL", -38.0, -1.8, 8, 4.4, 3.6, ground=1.2, fire=(3.0, 11.0), model="house_twostorey")
st.house(d, "EdgeHouseR", 38.5, -2.0, 8, 4.6, 3.8, fire=(3.0, 11.0), model="house_narrow")
# Препятствия на тропе
st.box(g, "Cart", (-4.0, 0.55, 0), (2.6, 1.1, 1.4), "wood", True)
for i, x in enumerate((-4.9, -3.1)):
    st.cyl(d, f"CartWheel{i}", (x, 0.5, 0.8), 0.5, 0.1, "wood_dark", rot=(math.pi / 2, 0, 0), sides=12)
st.box(d, "CartLoad", (-4.0, 1.35, 0), (2.0, 0.5, 1.1), "cloth")
# Хижина героя и дома
ROOF_FIRE = (3.0, 11.0)
st.house(d, "HeroHut", -28.0, -2.5, 8, 4.2, 3.4, windows=((-2.2, 2.2),), ground=1.2, fire=ROOF_FIRE, model="house_hut")
st.house(d, "HouseA", -18.0, -6.5, 7, 4.5, 3.8, windows=((1.5, 3.0),), ground=1.2, fire=ROOF_FIRE, model="house_narrow")
st.house(d, "HouseB", -6.0, -8.0, 8, 5.0, 4.0, windows=((-2.0, 3.0), (2.0, 1.8)), fire=ROOF_FIRE, model="house_twostorey")
st.house(d, "HouseC", 8.0, -11.0, 8, 4.5, 4.0, windows=((0, 2.8),), fire=ROOF_FIRE, model="house_hut")
st.house(d, "HouseD", 19.0, -9.0, 7, 4.2, 3.6, windows=((-1.5, 2.2),), fire=ROOF_FIRE, model="house_narrow")
st.house(d, "HouseFar", -14.0, -18.0, 9, 5.0, 4.5, windows=((0, 3.0),), fire=ROOF_FIRE, model="house_twostorey")
st.house(d, "HouseFar2", 14.0, -20.0, 10, 5.0, 5.0, windows=((3, 3.0),), fire=ROOF_FIRE, model="house_hut")
# Дом, откуда кричали: справа, главная цель улицы
st.house(d, "ScreamHouse", 26.5, -2.5, 9, 5.2, 4.6, windows=((-2.8, 3.6), (2.6, 3.6)), plaster="stone", model="house_twostorey")
st.box(d, "ScreamLantern", (24.6, 2.9, -0.8), (0.25, 0.4, 0.25), "window")
st.light(d, "ScreamLight", (24.6, 2.6, 0.2), (1.0, 0.6, 0.28), 2.0, 7.0)
st.light(d, "HutWindowLight", (-30.2, 3.4, 0.2), (1.0, 0.6, 0.28), 1.0, 5.0)
# Вывеска-колесо на столбе (как на референсе)
st.box(d, "SignPost", (-13.0, 3.0, -1.5), (0.25, 4.0, 0.25), "wood_dark")
st.box(d, "SignArm", (-12.2, 4.9, -1.5), (1.9, 0.18, 0.18), "wood_dark")
st.cyl(d, "SignWheel", (-11.5, 4.0, -1.5), 0.6, 0.08, "wood", rot=(math.pi / 2, 0, 0), sides=10)
# Заборы: сзади вдоль тропы и тёмные перед камерой
st.fence(d, "FenceBack", -24, -14, -1.8, 1.2)
st.fence(d, "FenceBack2", -8, 1, -1.9)
st.fence(d, "FenceFront", -21, -15, 2.4, 1.2, 1.0)
st.fence(d, "FenceFront2", 14, 21, 2.4, 0.0, 1.0)
# Конец деревни закрыт: выйти можно только через дом
st.box(d, "EndGate", (31.8, 2.0, 0), (0.5, 4.0, 3.5), "wood_dark")
# Фон и передний план (tools/levels/backdrop.py): второй ряд домов, зарево и дым, горы на западе, шпиль часовни на востоке.
STREET_NIGHT = (0.16, 0.19, 0.3)
k = bd.Kit(st)
bd.village(k, -33, 33, STREET_NIGHT, burn=BURN["fog"], spire_x=62.0)
st.marker("FromHut", (-28.0, 1.3, 0))
st.marker("FromHouse", (26.5, 0.1, 0))
door(st, "DoorToHut", -28.0, 1.2, "village_hut", "Spawns/FromStreet", "Войти в хижину")
door(st, "DoorToHouse", 26.5, 0, "village_house", "Spawns/FromStreet", "Войти в дом",
     ['required_flag = &"got_stick"', 'locked_text = "С голыми руками туда лучше не соваться. У хижины была поленница…"'])
# Поленница у стены хижины. Топоры похватали жители, когда услышали крики, — остались только дрова.
# Прочный брусок прислонён к стопке: первое оружие, его видно по тёплому блику (§8.9).
for i, (y, z, length) in enumerate(((0.12, -0.85, 1.6), (0.12, -0.61, 1.6), (0.33, -0.73, 1.5), (0.33, -0.49, 1.4), (0.54, -0.67, 1.2))):
    st.cyl(d, f"Woodpile{i}", (-25.3, 1.2 + y, z), 0.12, length, "wood", rot=(0, 0, round(math.pi / 2, 4)), sides=8)
st.node("Stick", 'type="Area3D"', "Objects", ["position = Vector3(-24.9, 1.2, 0)", 'script = ExtResource("pickup")', 'weapon_id = &"stick"',
                                                'flag = &"got_stick"', 'pickup_prompt = "Взять брусок"',
                                                'pickup_line = "«Всё равно сгорит. А так мне будет спокойнее.»"',
                                                "look_size = Vector3(0.14, 1.3, 0.14)", "look_color = Color(0.36, 0.25, 0.15, 1)",
                                                "look_rotation = Vector3(-0.3, 0, 0.12)", "look_offset = Vector3(0, 0, -0.25)"])
st.node("NeedWeapon", 'type="Area3D"', "Objects", ["position = Vector3(-28.0, 1.2, 0)", 'script = ExtResource("sayline")',
                                                     'text = "«Голыми руками не помочь…»"', 'until_flag = &"got_stick"'])

# Деревня в огне (крыши горят у домов выше): тени дерутся на фоне, в одном месте человек становится зверем, в другом отползает
for i, (x, y, z) in enumerate(((-24.0, 1.2, -3.2), (-9.5, 0.0, -2.8), (3.0, 0.0, -2.6), (11.0, 0.0, -3.2), (21.0, 0.0, -2.8))):
    st.fire(f"GroundFire{i}", (x, y, z), (2.0, 2.0, 0.6), 2.0, 7.0)
st.scene_bg("FightA", (-15.5, 1.2, -5.2), 0)
st.scene_bg("FightB", (6.0, 0.0, -6.2), 0)
st.scene_bg("FightC", (17.5, 0.0, -6.5), 0)
st.scene_bg("Turning", (-2.5, 0.0, -3.0), 1, 11.0)
st.fire("TurningFire", (-2.5, 0.0, -4.4), (4.5, 4.0, 0.6), 1.2, 7.0)
st.scene_bg("Crawl", (13.5, 0.0, -3.0), 2, 11.0)
st.fire("CrawlFire", (15.0, 0.0, -4.4), (7.0, 3.5, 0.6), 1.2, 7.0)
st.ambience(("…помогите!..", "…кто-нибудь!..", "…сюда, в дом!.."), 11.0)
st.box("AfterFire", "AshA", (-9.5, 0.1, -2.8), (2.4, 0.2, 1.2), "char")
st.box("AfterFire", "AshB", (11.0, 0.1, -3.2), (2.2, 0.2, 1.2), "char")
# Земля за тропой, чтобы дома стояли на ней, а не висели в тумане
st.box(d, "FarGround", (0, -2, -20), (150, 4, 35.6), "mud")
st.box(d, "FarHill", (-24, -0.9, -8.1), (20, 4.2, 11.8), "mud")
# Второй план: жизнь деревни (по art/concepts/locations)
st.woodpile(d, "HutWood", -31.7, -0.6, 1.2)
st.prop(d, "HutBarrel", "barrel", (-25.2, 1.7 - 0.5, -0.6), 1.1)
st.garlic(d, "HutGarlic", -31.3, 4.1, -0.85)
st.lantern_post(d, "PathLamp", -22.5, -1.2, 1.2)
st.dead_tree(d, "TreeHill", -18.0, -3.6, 8.0, 1.2)
st.prop(d, "Hay", "haystack", (-12.0, 0.0, -3.2), 2.8)
st.wash_line(d, "Wash", -9.0, -2.5, -3.6)
st.dead_tree(d, "TreeWell", -0.5, -4.8, 9.0)
st.lantern_post(d, "SquareLamp", 15.3, -0.9, 0.0, -1)
st.dead_tree(d, "TreeFar", 20.8, -5.0, 8.0)
st.prop(d, "HouseBarrelA", "barrel", (22.7, 0.5 - 0.5, -0.6), 1.1)
st.prop(d, "HouseBarrelB", "barrel", (23.6, 0.5 - 0.5, -0.7), 1.1)
st.crow(d, "Crow", 22.7, 1.0, -0.6)
st.garlic(d, "HouseGarlic", 22.6, 4.3, -0.85)
# Передний план: низкие тёмные вещи и берег перед тропой (слои картинки, §2.2)
st.box(d, "BankHigh", (-38.5, -1.25, 3.7), (49, 4, 3.0), "earth_dark")
st.box(d, "BankLow", (24.5, -2.2, 3.7), (77, 4, 3.0), "earth_dark")
k.near_ground(-63, -14, y=0.95, pad=0)
k.near_ground(-14, 63, y=-0.25, pad=0)
k.foreground("village", -33, 33, ground=lambda x: 1.2 if x < -14 else 0.0, skip=((-14.5, -10.5),))
# Подсвеченный путь (§2.2): тропа светлее краёв — в пожаре от огня, после — от луны.
PATH_FIRE, PATH_NIGHT = (0.13, 0.065, 0.03), (0.06, 0.07, 0.1)
for parent, light in (("Burning", PATH_FIRE), ("AfterFire", PATH_NIGHT)):
    k.path_light(-33, -14, 1.2, light, parent=parent)
    k.path_light(-8, 33, 0.0, light, parent=parent)
st.wheel(d, "FrontWheelHill", -27.0, 1.55, 3.1, 0.8)
st.rocks(d, "FrontRocksHill", -31.0, 0.75, 3.4)
st.tuft(d, "FrontTuftHill", -23.5, 0.75, 3.2)
st.tuft(d, "FrontTuftRamp", -12.5, 0.2, 3.0)
st.wheel(d, "FrontWheel", -6.5, 0.75, 3.3, 0.95)
st.prop(d, "FrontBarrel", "barrel", (3.5, 0.3 - 0.5, 3.1), 1.1)
st.tuft(d, "FrontTuft", 1.0, -0.2, 3.2)
st.rocks(d, "FrontRocks", 9.5, -0.2, 3.4)
st.tuft(d, "FrontTuft2", 11.5, -0.2, 3.2)
st.rocks(d, "FrontRocks2", 24.0, -0.2, 3.4)
st.tuft(d, "FrontTuft3", 28.0, -0.2, 3.2)

# ---------------------------------------------------------------- Дом с крысами: два этажа в разрезе
ho = Scene("VillageHouse", "village_house", 25.0, 0.0,
           {"bg": (0.0, 0.0, 0.0), "amb": (0.3, 0.3, 0.42), "amb_e": 0.3, "fog": (0.01, 0.01, 0.016), "fog_d": 0.006},
           (0.55, 0.65, 0.9), 0.0, BURN_IN)
ATTIC = 4.0
ho.box(g, "Floor", (0, -1, 0), (26, 2, 4), "stone_dark", True)
ho.box(g, "WallLeft", (-12.5, 4.5, 0), (1, 11, 4), "stone", True)
ho.box(g, "WallRight", (12.5, 4.5, 0), (1, 11, 4), "stone", True)
ho.box(g, "Ceiling", (0, 9, 0), (26, 1, 4), "wood_dark", True)
# Чердачный пол с проёмом под лестницу
ho.box(g, "AtticFloor", (-2.7, ATTIC - 0.25, 0), (18.6, 0.5, 4), "wood", True)
ho.box(g, "AtticFloorRight", (10.2, ATTIC - 0.25, 0), (3.6, 0.5, 4), "wood", True)
ho.node("Ladder", 'type="Area3D"', "Objects", ["position = Vector3(7.5, 0, 0)", 'script = ExtResource("ladder")', f"height = {ATTIC}", "exit_dir = -1.0"])
# Низ: камень, арки, клетка, фонарь, бочки
ho.box(d, "BackLow", (0, 1.8, -2.2), (25, 3.6, 0.4), "stone")
ho.box(d, "BackHigh", (0, 6.4, -2.2), (25, 5.2, 0.4), "wood_dark")
for i, x in enumerate((-8.0, -1.5, 5.0)):
    ho.box(d, f"Arch{i}", (x, 1.25, -1.96), (2.6, 2.5, 0.08), "stone_dark")
for i, x in enumerate((-4.75, 1.75)):
    ho.box(d, f"Pillar{i}", (x, 1.85, -1.8), (0.7, 3.7, 0.5), "stone")
for i in range(6):
    ho.box(d, f"CageBar{i}", (-9.0 + i * 0.4, 0.9, -1.2), (0.05, 1.8, 0.05), "iron")
ho.box(d, "CageTop", (-8.0, 1.8, -1.2), (2.2, 0.06, 0.1), "iron")
ho.box(d, "LanternLow", (-4.0, 2.9, -1.2), (0.26, 0.42, 0.26), "window")
ho.light(d, "LowLight", (-4.0, 2.8, 0.2), (1.0, 0.6, 0.28), 2.2, 10.0, True)
ho.box(d, "LanternLow2", (3.6, 2.9, -1.2), (0.26, 0.42, 0.26), "window")
ho.light(d, "LowLight2", (3.6, 2.8, 0.2), (1.0, 0.6, 0.28), 1.6, 8.0)
for i, x in enumerate((-10.6, 9.6, 10.6)):
    ho.prop(d, f"Barrel{i}", "barrel", (x, 0.5 - 0.5, -1.4), 1.1)
ho.box(d, "BeamBrace", (0, 3.45, -1.6), (24, 0.25, 0.3), "wood_dark")
# Чердак: кровать, ящики, окно, балка с летучей мышью
ho.box(d, "AtticBed", (-4.5, ATTIC + 0.35, -1.0), (2.6, 0.7, 1.2), "bedding")
ho.box(d, "CrateA", (-9.5, ATTIC + 0.5, -1.2), (1.0, 1.0, 1.0), "wood")
ho.box(d, "CrateB", (-8.4, ATTIC + 0.35, -1.2), (0.7, 0.7, 0.8), "wood")
ho.prop(d, "AtticBarrel", "barrel", (0.6, ATTIC + 0.5 - 0.5, -1.3), 1.1)
ho.box(d, "AtticWindow", (3.6, ATTIC + 2.0, -1.96), (1.4, 1.8, 0.08), "window")
ho.light(d, "AtticLight", (3.6, ATTIC + 1.8, 0.0), (1.0, 0.6, 0.28), 1.6, 9.0, True)
ho.box(d, "RoofBeam", (0, ATTIC + 3.2, -0.6), (24, 0.35, 0.35), "wood")
for i, x in enumerate((-8, -2, 4, 10)):
    ho.box(d, f"Brace{i}", (x, ATTIC + 1.6, -1.8), (0.3, 3.2, 0.3), "wood_dark")
ho.marker("FromStreet", (-10.3, 0.1, 0))
ho.marker("FromExit", (11.0, 0.1, 0))
door(ho, "DoorToStreet", -11.0, 0, "village_street", "Spawns/FromHouse", "Выйти на улицу")
ho.fire("AtticFire", (9.5, ATTIC, -1.6), (1.8, 1.8, 0.4), 2.0, 8.0)
ho.fire("LowFire", (-11.0, 0.0, -1.7), (1.4, 1.4, 0.4), 1.4, 6.0)
ho.ambience(("…помогите!..", "…там, на площади!.."), 10.0)
door(ho, "DoorOut", 11.4, 0, "village_square", "Spawns/FromHouse", "Выйти на площадь",
     ["needs_clear = true", 'clear_flag = &"village_house_clear"', 'locked_text = "В доме ещё кто-то возится. Дверь завалена изнутри."'])
for name, x, y in (("RatA", -2.5, 0.0), ("RatB", 3.8, 0.0)):
    ho.nodes.append(f'[node name="{name}" parent="Objects" instance=ExtResource("rat")]\nposition = Vector3({x}, {y}, 0)')
ho.nodes.append(f'[node name="Bat" parent="Objects" instance=ExtResource("bat")]\nposition = Vector3(-1.0, {ATTIC + 2.75}, 0)')

# ---------------------------------------------------------------- Площадь: конец первой сцены
sq = Scene("VillageSquare", "village_square", 38.0, 0.0,
           {"bg": (0.045, 0.055, 0.095), "amb": (0.34, 0.4, 0.58), "amb_e": 0.42, "fog": (0.16, 0.19, 0.3), "fog_d": 0.022},
           (0.55, 0.65, 0.9), 0.35, BURN)
sq.box(g, "Ground", (0, -2, 0), (100, 4, 4.4), "mud", True)
sq.wall("WallLeft", (-19.5, 6, 0), (1, 20, 4.4))
sq.wall("WallRight", (19.5, 6, 0), (1, 20, 4.4))
sq.box(d, "FarGround", (0, -2, -18), (130, 4, 31.6), "mud")
sq.house(d, "EdgeHouseL", -24.0, -2.0, 8, 4.6, 3.8, fire=(3.2, 12.0), model="house_hut")
sq.house(d, "EdgeHouseR", 24.5, -2.4, 8, 4.8, 4.0, fire=(3.2, 12.0), model="house_twostorey")
k = bd.Kit(sq)
bd.village(k, -19, 19, (0.16, 0.19, 0.3), burn=BURN["fog"], spire_x=40.0)
k.near_ground(-19, 19)
for parent, light in (("Burning", PATH_FIRE), ("AfterFire", PATH_NIGHT)):
    k.path_light(-19, 19, 0.0, light, parent=parent)
k.foreground("village", -19, 19)
sq.house(d, "HouseA", -13.0, -7.0, 8, 4.8, 4.0, windows=((-2.0, 3.0), (2.0, 1.8)), fire=(3.2, 12.0), model="house_twostorey")
sq.house(d, "HouseB", 0.0, -11.0, 9, 5.0, 4.4, windows=((0, 3.0),), fire=(3.2, 12.0), model="house_narrow")
sq.house(d, "HouseC", 13.5, -7.5, 8, 4.6, 3.8, windows=((1.5, 2.8),), fire=(3.2, 12.0), model="house_hut")
# Колодец — первая настоящая модель (ComfyUI → TRELLIS.2, docs/ART_PIPELINE.md): ~1 м в файле, ×3.2 ≈ 3 м высотой
sq.ext["well"] = ("PackedScene", "res://assets/props/well/prop_well.glb")
WELL_S, WELL_Y0 = 3.2, -0.4806  # масштаб и низ модели (AABB.y) — ставим дном на землю
sq.nodes.append(f'[node name="Well" parent="{d}" instance=ExtResource("well")]\n'
                f'transform = Transform3D({WELL_S}, 0, 0, 0, {WELL_S}, 0, 0, 0, {WELL_S}, -8.5, {-WELL_Y0 * WELL_S:.3f}, -1.5)')
# Статуя на площади
sq.box(d, "Plinth", (3.0, 0.45, -2.9), (4.2, 0.9, 3.2), "stone")
sq.box(d, "Plinth2", (3.0, 1.3, -2.9), (2.6, 0.8, 2.2), "stone")
sq.box(d, "StatueBody", (3.0, 3.3, -2.9), (1.1, 3.2, 0.9), "statue")
sq.sphere(d, "StatueHead", (3.0, 5.25, -2.9), 0.42, "statue")
sq.box(d, "StatueArm", (3.85, 4.5, -2.9), (0.28, 1.6, 0.3), "statue", rot=(0, 0, -0.5))
# Навес и верёвка с тряпками
sq.box(d, "StallTop", (12.0, 2.4, -2.0), (3.8, 0.15, 2.2), "cloth", rot=(0.15, 0, 0))
for i, x in enumerate((10.3, 13.7)):
    sq.box(d, f"StallPost{i}", (x, 1.15, -2.0), (0.14, 2.3, 0.14), "wood_dark")
sq.wash_line(d, "Banners", -5.5, 1.0, -4.5)
sq.lantern_post(d, "Lamp", -14.5, -1.2)
sq.dead_tree(d, "Tree", 8.0, -5.5, 9.0)
sq.fence(d, "FenceBack", 15, 19, -1.8)
sq.fence(d, "FenceFront", -16, -11, 2.4, 0.0, 1.0)
sq.box(d, "Bank", (0, -2.2, 3.7), (100, 4, 3.0), "earth_dark")
sq.wheel(d, "FrontWheel", -6.0, 0.75, 3.3, 0.95)
sq.rocks(d, "FrontRocks", 6.0, -0.2, 3.5)
sq.tuft(d, "FrontTuft", 0.5, -0.2, 3.2)
sq.tuft(d, "FrontTuft2", 14.0, -0.2, 3.2)
sq.prop(d, "FrontBarrel", "barrel", (16.0, 0.3 - 0.5, 3.1), 1.1)
# Огонь (крыши горят у домов выше) и жертва зверя
for i, (x, y, z) in enumerate(((-3.5, 0.0, -2.8), (9.5, 0.0, -2.8))):
    sq.fire(f"GroundFire{i}", (x, y, z), (2.0, 2.0, 0.6), 2.4, 8.0)
sq.scene_bg("Turning", (-4.5, 0.0, -4.4), 1, 12.0)
sq.fire("TurningFire", (-4.5, 0.0, -5.8), (4.5, 4.0, 0.6), 1.2, 7.0)
sq.scene_bg("Fight", (9.0, 0.0, -5.5), 0)
sq.box("Burning", "Victim", (6.3, 0.2, -0.7), (1.6, 0.34, 0.5), "char")
sq.ambience()
sq.box("AfterFire", "VictimAsh", (6.3, 0.05, -0.7), (1.6, 0.08, 0.5), "char")
sq.box("AfterFire", "AshA", (-3.5, 0.1, -2.8), (2.4, 0.2, 1.2), "char")
sq.box("AfterFire", "AshB", (9.5, 0.1, -2.8), (2.4, 0.2, 1.2), "char")
sq.nodes.append('[node name="MirrorShard" parent="AfterFire" instance=ExtResource("shard")]\nposition = Vector3(-4.0, 0, 0)')
sq.marker("FromHouse", (-16.0, 0.1, 0))
sq.marker("FromChapel", (16.0, 0.1, 0))
sq.marker("AfterWolf", (-1.0, 0.1, 0))
door(sq, "DoorToHouse", -17.5, 0, "village_house", "Spawns/FromExit", "Вернуться в дом")
door(sq, "DoorToChapel", 17.5, 0, "chapel_yard", "Spawns/FromSquare", "Идти к часовне",
     ['required_flag = &"fire_out"', 'locked_text = "Дорогу отрезал огонь."'])
sq.nodes.append('[node name="Werewolf" parent="Objects" instance=ExtResource("wolf")]\nposition = Vector3(5.0, 0, 0)')
sq.node("WolfEvent", 'type="Node"', "Objects", ['script = ExtResource("squareevent")'])


def npc(s, name, x, title, lines, color, extra=()):
    quoted = ", ".join('"' + l + '"' for l in lines)
    s.node(name, 'type="Area3D"', "Objects", [f"position = Vector3({x}, 0, 0)", 'script = ExtResource("npc")', f'npc_name = "{title}"',
           f"lines = PackedStringArray({quoted})", f"look_color = Color({color[0]}, {color[1]}, {color[2]}, 1)"] + list(extra))


# ---------------------------------------------------------------- Двор часовни: слева направо как на арте
ch = Scene("ChapelYard", "chapel_yard", 50.0, 0.0,
           {"bg": (0.03, 0.035, 0.07), "amb": (0.3, 0.34, 0.5), "amb_e": 0.36, "fog": (0.12, 0.14, 0.24), "fog_d": 0.02},
           (0.55, 0.65, 0.9), 0.25)
ch.box(g, "Ground", (0, -2, 0), (112, 4, 4.4), "mud", True)
ch.wall("WallLeft", (-25.5, 6, 0), (1, 20, 4.4))
ch.wall("WallRight", (25.5, 6, 0), (1, 20, 4.4))
ch.box(d, "FarGround", (0, -2, -20), (150, 4, 35.6), "mud")
# Хаб между мирами: слева на горизонте деревня (откуда пришёл), справа лес и кладбищенский холм (куда идти).
k = bd.Kit(ch)
k.sky(-25, 25, (0.025, 0.03, 0.065), (0.15, 0.17, 0.27))
bd.hub(k, -25, 25, (0.12, 0.14, 0.24))
k.near_ground(-25, 25)
k.path_light(-25, 25, 0.0, (0.08, 0.075, 0.08))
k.foreground("village", -25, 25)
ch.house(d, "EdgeHouseL", -30.5, -2.2, 8, 4.4, 3.6, windows=((1.5, 2.6),))
ch.dead_tree(d, "EdgeTreeR", 30.0, -1.6, 9.0)
# Кузнец: наковальня и горн под открытым небом
ch.box(d, "AnvilBase", (-18.8, 0.4, -1.5), (0.7, 0.8, 0.7), "wood_dark")
ch.box(d, "Anvil", (-18.8, 1.0, -1.5), (1.2, 0.4, 0.5), "iron")
ch.box(d, "Hearth", (-20.8, 0.7, -2.0), (1.6, 1.4, 1.0), "stone_dark")
ch.box(d, "HearthFire", (-20.8, 1.0, -1.45), (1.0, 0.5, 0.08), "fire")
ch.light(d, "HearthLight", (-20.8, 1.3, -0.4), (1.0, 0.5, 0.2), 2.0, 7.0)
# Травница: навес с пучками
ch.box(d, "HerbTop", (-13.0, 2.5, -1.8), (3.6, 0.15, 2.2), "cloth", rot=(0.15, 0, 0))
for i, x in enumerate((-14.6, -11.4)):
    ch.box(d, f"HerbPost{i}", (x, 1.2, -1.8), (0.14, 2.4, 0.14), "wood_dark")
ch.box(d, "HerbTable", (-13.0, 0.8, -2.0), (3.0, 0.14, 1.0), "wood")
for i in range(5):
    ch.box(d, f"Herb{i}", (-14.4 + i * 0.7, 2.0, -1.6), (0.18, 0.7, 0.12), "thatch")
ch.lantern_post(d, "HerbLamp", -16.0, -1.5, 0.0)
# Дерево с оберегами
ch.dead_tree(d, "CharmTree", -9.0, -4.5, 9.0)
# Часовня: каменный неф с витражом и башня с колоколом
ch.box(d, "Nave", (-2.5, 4.0, -3.5), (8.0, 8.0, 3.0), "stone")
ch.roof(d, "NaveRoof", (-2.5, 10.0, -3.5), (9.0, 4.0, 3.6), "wood_dark")
ch.box(d, "Tower", (-7.5, 6.5, -3.5), (2.6, 13.0, 2.6), "stone_dark")
ch.roof(d, "TowerRoof", (-7.5, 15.0, -3.5), (3.2, 4.0, 3.2), "wood_dark")
ch.box(d, "Bell", (-7.5, 11.0, -2.1), (0.8, 0.9, 0.2), "iron")
# Витраж снаружи — тусклый, свечи внутри: самым ярким во дворе остаётся осколок (§2.2).
ch.box(d, "FacadeGlass", (-2.5, 5.3, -1.96), (2.6, 4.0, 0.08), "stained_dim")
ch.box(d, "FacadeCastle", (-2.5, 5.3, -1.9), (0.9, 2.2, 0.04), "stone_dark")
ch.box(d, "FacadeTowerA", (-3.2, 4.9, -1.9), (0.35, 1.4, 0.04), "stone_dark")
ch.box(d, "FacadeTowerB", (-1.8, 4.9, -1.9), (0.35, 1.4, 0.04), "stone_dark")
ch.box(d, "ChapelDoor", (-2.5, 1.3, -1.94), (1.5, 2.6, 0.1), "wood_dark")
for i, x in enumerate((-4.2, -0.8)):
    ch.box(d, f"Candle{i}", (x, 1.5, -1.9), (0.14, 0.34, 0.14), "fire")
    ch.light(d, f"CandleLight{i}", (x, 1.7, -1.0), (1.0, 0.65, 0.35), 0.9, 4.0)
# Мастерская стекольщика: навес, печь, стеклянные листы
ch.box(d, "ShopBack", (7.5, 2.6, -3.5), (11.0, 5.2, 0.6), "wood_dark")
ch.roof(d, "ShopRoof", (7.5, 6.4, -2.6), (12.0, 2.4, 3.8), "wood_dark")
for i, x in enumerate((2.2, 12.8)):
    ch.box(d, f"ShopPost{i}", (x, 2.6, -1.3), (0.25, 5.2, 0.25), "wood_dark")
ch.box(d, "Furnace", (5.5, 1.3, -2.7), (2.4, 2.6, 1.0), "stone")
ch.box(d, "FurnaceFire", (5.5, 1.1, -2.16), (1.0, 0.9, 0.08), "fire")
ch.light(d, "FurnaceLight", (5.5, 1.5, -0.8), (1.0, 0.5, 0.2), 2.6, 9.0)
for i, x in enumerate((9.6, 10.5, 11.3)):
    ch.box(d, f"Pane{i}", (x, 1.1, -2.2), (0.8, 2.2, 0.06), "moonpane", rot=(0.12, 0, 0))
ch.box(d, "Chimney", (6.0, 7.5, -3.6), (1.3, 5.0, 1.3), "stone_dark")
# Верстак с перегонным кубом ордена (prop_alembic: в файле ~1 м, ×0.75 ≈ 0.75 м, низ модели y = -0.488)
ch.box(d, "Workbench", (7.9, 0.45, -2.4), (1.8, 0.9, 0.8), "wood_dark")
ch.ext["alembic"] = ("PackedScene", "res://assets/props/alembic/prop_alembic.glb")
ch.nodes.append(f'[node name="Alembic" parent="{d}" instance=ExtResource("alembic")]\n'
                f'transform = Transform3D(0.75, 0, 0, 0, 0.75, 0, 0, 0, 0.75, 7.9, {0.9 + 0.488 * 0.75:.3f}, -2.4)')
# Выжившие у костра: часовня стала убежищем
ch.box(d, "CampWood", (18.5, 0.15, -1.7), (1.4, 0.3, 0.9), "wood_dark")
ch.box(d, "CampFlame", (18.5, 0.6, -1.7), (0.6, 0.7, 0.3), "fire")
ch.light(d, "CampLight", (18.5, 1.2, -0.7), (1.0, 0.55, 0.25), 1.6, 6.0)
for i, (x, z) in enumerate(((17.4, -2.0), (19.6, -2.1))):
    ch.box(d, f"Survivor{i}", (x, 0.5, z), (0.5, 1.0, 0.45), "cloth")
ch.fence(d, "FenceFront", -24, -15, 2.4, 0.0, 1.0)
ch.fence(d, "FenceFront2", 15, 24, 2.4, 0.0, 1.0)
ch.box(d, "Bank", (0, -2.2, 3.7), (112, 4, 3.0), "earth_dark")
ch.wheel(d, "FrontWheel", -21.5, 0.75, 3.3, 0.95)
ch.rocks(d, "FrontRocks", 6.5, -0.2, 3.5)
ch.tuft(d, "FrontTuft", -8.0, -0.2, 3.2)
ch.tuft(d, "FrontTuft2", 13.0, -0.2, 3.2)
ch.nodes.append('[node name="MirrorShard" parent="Objects" instance=ExtResource("shard")]\nposition = Vector3(15.0, 0, 0)')
ch.marker("FromSquare", (-23.0, 0.1, 0))
ch.marker("FromChapel", (-2.5, 0.1, 0))
ch.marker("FromForest", (22.5, 0.1, 0))
door(ch, "DoorToSquare", -24.3, 0, "village_square", "Spawns/FromChapel", "Вернуться на площадь")
door(ch, "DoorToChapel", -2.5, 0, "chapel", "Spawns/FromYard", "Войти в часовню")
door(ch, "DoorToForest", 24.3, 0, "cemetery_gate", "Spawns/FromChapel", "К кладбищу и в лес")
npc(ch, "Smith", -18.0, "Кузнец",
    ["Многих нет. Кого не нашли среди живых, не нашли и среди мёртвых.",
     "Отстроимся. Сперва кровля, потом кузня. Железо огню не по зубам.",
     "За лесом, за болотом, была деревня моего приятеля. Мы вместе ковали.",
     "Несколько лет назад её вырезали. Говорят, он сам. Не верю. Не хочу верить.",
     "Травницу никто не видел с той ночи. Если она в лесу — найди её."],
    (0.3, 0.22, 0.18),
    ['gift_weapon = &"sword"', 'gift_flag = &"got_sword"', 'gift_line = "Живой… Палкой много не навоюешь. Держи, он старый, но честный."',
     'sell_item = &"shield_hoplon"', 'sell_price = 250', 'sell_offer = "Есть круглый щит, гоплон. Старый, но удар держит. Возьмёшь?"',
     'sell_line = "Держи. Подставляй его под удар — и вовремя: отобьёшь не хуже клинка."',
     'after_flag = &"boss_smith"', 'lines_after = PackedStringArray("Значит, это был он… От него одни руки и остались.", "Спасибо, что не дал ему дальше так ходить.")'])
npc(ch, "Herbalist", -13.0, "Травница",
    ["Разбойники утащили меня в ту ночь, пока все тушили огонь.",
     "Говорят, перед пожаром по деревне ходил чародей. Кто его видел, уже не расскажет.",
     "Они были нашими соседями. А потом стали другими. На глазах.",
     "Многие пропали без вести. Лес забрал больше, чем огонь."],
    (0.22, 0.26, 0.2),
    ['appear_flag = &"herbalist_rescued"', 'gift_item = &"flask_potency"', 'gift_flag = &"herbalist_potency"',
     'gift_line = "Ты меня вытащил. Дай-ка твою флягу: с моими травами зелье будет крепче."'])
npc(ch, "Glassblower", 7.5, "Стекольщик",
    ["Стекло пережило огонь лучше, чем люди. Будем стеклить заново.",
     "Витраж-то цел. Замок на нём смотрит так, будто доволен.",
     "То зеркало в часовне старше всех нас. Молчит, пока не вернутся его осколки.",
     "Травница пропала в ту ночь. Её прилавок так и стоит пустой."],
    (0.26, 0.24, 0.3),
    ['after_flag = &"herbalist_rescued"', 'lines_after = PackedStringArray("Травница вернулась! Говорит, её держали разбойники на поваленном дубе.", '
     '"Витраж-то цел. Замок на нём смотрит так, будто доволен.", "То зеркало в часовне старше всех нас. Молчит, пока не вернутся его осколки.")'])

# ---------------------------------------------------------------- Часовня внутри
ci = Scene("Chapel", "chapel", 28.0, 0.0,
           {"bg": (0.0, 0.0, 0.0), "amb": (0.3, 0.32, 0.46), "amb_e": 0.3, "fog": (0.012, 0.012, 0.02), "fog_d": 0.004},
           (0.55, 0.65, 0.9), 0.0)
BAL = 4.4
ci.box(g, "Floor", (0, -1, 0), (30, 2, 4), "stone_dark", True)
ci.box(g, "WallLeft", (-14.5, 6, 0), (1, 14, 4), "stone", True)
ci.box(g, "WallRight", (14.5, 6, 0), (1, 14, 4), "stone", True)
ci.box(g, "Ceiling", (0, 12.5, 0), (30, 1, 4), "wood_dark", True)
ci.box(d, "BackWall", (0, 6, -2.2), (29, 13, 0.4), "stone")
for i, x in enumerate((-10.0, -5.0, 5.0)):
    ci.box(d, f"Pillar{i}", (x, 6, -1.9), (0.7, 12, 0.5), "stone_dark")
# Витраж с замком над Главным Зеркалом
ci.box(d, "GlassFrame", (0, 7.4, -2.0), (4.4, 6.8, 0.15), "iron")
ci.box(d, "GlassBlue", (0, 7.4, -1.92), (4.0, 6.4, 0.05), "stained_blue")
ci.box(d, "GlassForest", (0, 5.0, -1.88), (4.0, 1.2, 0.03), "stone_dark")
ci.box(d, "CastleKeep", (0, 7.6, -1.88), (1.2, 3.6, 0.03), "stone_dark")
ci.box(d, "CastleTowerA", (-1.0, 7.0, -1.88), (0.5, 2.6, 0.03), "stone_dark")
ci.box(d, "CastleTowerB", (1.0, 7.0, -1.88), (0.5, 2.6, 0.03), "stone_dark")
ci.roof(d, "CastleSpire", (0, 10.0, -1.87), (1.2, 1.2, 0.03), "stone_dark")
ci.roof(d, "CastleSpireA", (-1.0, 8.75, -1.87), (0.5, 0.9, 0.03), "stone_dark")
ci.roof(d, "CastleSpireB", (1.0, 8.75, -1.87), (0.5, 0.9, 0.03), "stone_dark")
for i, x in enumerate((-0.9, 0.0, 0.9)):
    ci.box(d, f"Kneeler{i}", (x, 4.75, -1.85), (0.4, 0.7, 0.03), "stained_gold" if i == 1 else "stained_red")
for i, y in enumerate((5.6, 6.6, 7.6, 8.6, 9.6)):
    ci.box(d, f"LeadH{i}", (0, y, -1.86), (4.0, 0.05, 0.02), "iron")
for i, x in enumerate((-1.3, 1.3)):
    ci.box(d, f"LeadV{i}", (x, 7.4, -1.86), (0.05, 6.4, 0.02), "iron")
ci.light(d, "GlassLight", (0, 6.4, 0.2), (0.45, 0.6, 1.0), 2.2, 11.0)
# Скамьи и свечи
for i, x in enumerate((-9.5, -6.5, 4.2)):
    ci.box(d, f"Pew{i}", (x, 0.4, -1.3), (2.2, 0.8, 0.7), "wood_dark")
for i, x in enumerate((-3.0, 3.0)):
    ci.box(d, f"CandleStand{i}", (x, 0.7, -1.5), (0.14, 1.4, 0.14), "iron")
    ci.box(d, f"Candle{i}", (x, 1.55, -1.5), (0.14, 0.3, 0.14), "fire")
    ci.light(d, f"CandleLight{i}", (x, 1.9, -0.6), (1.0, 0.65, 0.35), 1.2, 5.0)
# Балкон справа: лестница, стена тайника, гнилой пол над ним
ci.node("Ladder", 'type="Area3D"', "Objects", ["position = Vector3(6.2, 0, 0)", 'script = ExtResource("ladder")', f"height = {BAL}", "exit_dir = 1.0"])
ci.box(g, "BalconyA", (8.3, BAL - 0.25, 0), (2.4, 0.5, 4), "wood", True)
ci.box(g, "BalconyB", (12.75, BAL - 0.25, 0), (2.5, 0.5, 4), "wood", True)
ci.box(g, "StashWall", (8.4, (BAL - 0.5) / 2, 0), (0.4, BAL - 0.5, 4), "stone", True)
ci.box(d, "Chandelier", (10.5, 9.0, -0.8), (1.8, 0.12, 0.8), "iron")
ci.light(d, "ChandelierLight", (10.5, 8.6, -0.2), (1.0, 0.65, 0.35), 2.0, 9.0)
ci.box(d, "BalconyStatue", (12.8, BAL + 1.1, -1.6), (0.7, 2.2, 0.5), "statue")
for i in range(8):
    ci.box(d, f"BalconyRail{i}", (7.4 + i * 0.9, BAL + 0.5, -1.5), (0.08, 1.0, 0.08), "wood_dark")
ci.box(d, "BalconyRailTop", (10.5, BAL + 1.0, -1.5), (6.8, 0.08, 0.08), "wood_dark")
ci.used.add("rotten")
ci.nodes.append(f'[node name="StashFloor" parent="Objects" instance=ExtResource("glass")]\nposition = Vector3(10.5, {BAL - 0.15}, 0)\nsize = Vector3(2, 0.3, 4)\nlook = SubResource("Mat_rotten")')
ci.node("StashLadder", 'type="Area3D"', "Objects", ["position = Vector3(10.5, 0, 0)", 'script = ExtResource("ladder")', f"height = {BAL}", "exit_dir = 1.0"])
ci.nodes.append('[node name="StashChest" parent="Objects" instance=ExtResource("chest")]\nposition = Vector3(12.6, 0, -1.2)\nreward = 150\nitems = Array[StringName]([&"tempered_glass", &"fire_flask", &"fire_flask", &"holy_flask", &"holy_flask"])\nflag_id = &"chapel_stash"')
ci.box(d, "StashCrate", (9.4, 0.4, -1.4), (0.9, 0.8, 0.9), "wood")
ci.light(d, "StashLight", (12.0, 2.4, -0.4), (1.0, 0.6, 0.3), 0.8, 5.0)
ci.marker("FromYard", (-11.5, 0.1, 0))
ci.marker("FromMirror", (2.6, 0.1, 0))
door(ci, "DoorToYard", -12.8, 0, "chapel_yard", "Spawns/FromChapel", "Выйти во двор")
ci.node("MainMirror", 'type="Area3D"', "Objects", ["position = Vector3(0, 0, 0)", 'script = ExtResource("mainmirror")', 'target_room = &"room_001"',
        'target_spawn = NodePath("Spawns/PlayerStart")', 'open_prompt = "Прикоснуться к Главному Зеркалу"',
        'shard_flags = Array[StringName]([&"shard_village_square", &"shard_chapel_yard", &"shard_cemetery", &"shard_fallen_giant", &"shard_cursed_village"])',
        'required_flags = Array[StringName]([&"boss_smith", &"shard_village_square", &"shard_chapel_yard", &"shard_cemetery", &"shard_fallen_giant", &"shard_cursed_village"])',
        'locked_text = "Зеркало молчит. Под тканью не хватает осколков, и что-то ещё держит его закрытым."',
        "door_size = Vector3(3.0, 3.3, 0.15)", "door_color = Color(0.06, 0.06, 0.08, 1)"])

# ---------------------------------------------------------------- Разрушаемые предметы (GAME_DESIGN §8.13)
# Лут не в каждом: примерно один из четырёх. Площадь — арена оборотня, там ничего не ставим.
BARREL = dict(key="barrel", height=1.05, size=(0.8, 1.05, 0.8), stuff=0, hits=2)
st.breakable("BarrelHill", pos=(-20.5, 1.2, 0), **BARREL)
st.breakable("BarrelRoad", pos=(5.2, 0.0, 0), **BARREL)
st.breakable("BarrelLoot", pos=(17.0, 0.0, 0), echoes=8, **BARREL)
ho.breakable("BarrelHall", pos=(-8.4, 0.0, 0), **BARREL)
ho.breakable("BarrelAttic", pos=(-9.6, ATTIC, 0), echoes=6, **BARREL)
ch.breakable("BarrelGate", pos=(-20.5, 0.0, 0), **BARREL)
ch.breakable("BarrelCamp", pos=(21.3, 0.0, 0), echoes=10, **BARREL)

for scene, file in ((hut, "village_hut"), (st, "village_street"), (ho, "village_house"), (sq, "village_square"),
                    (ch, "chapel_yard"), (ci, "chapel")):
    Path(f"world/rooms/{file}.tscn").write_text(scene.text(), encoding="utf-8")


# ---------------------------------------------------------------- Враги
def enemy_scene(script_ext, root, shapes, health, props, extras):
    return f'''[gd_scene load_steps=12 format=3]

{script_ext}
[ext_resource type="Script" path="res://combat/hitboxes/hitbox.gd" id="2_hitbox"]
[ext_resource type="Script" path="res://combat/hitboxes/hurtbox.gd" id="3_hurtbox"]
[ext_resource type="Script" path="res://combat/damage/health.gd" id="4_health"]

{shapes}

{root}
{props}

{extras}

[node name="Health" type="Node" parent="."]
script = ExtResource("4_health")
max_health = {health}
'''


bat = enemy_scene('[ext_resource type="Script" path="res://actors/enemies/bat.gd" id="1_dummy"]',
  '[node name="Bat" type="CharacterBody3D"]\ncollision_layer = 0\ncollision_mask = 1\nscript = ExtResource("1_dummy")',
  '''[sub_resource type="BoxShape3D" id="Shape_body"]
size = Vector3(0.5, 0.4, 0.5)

[sub_resource type="BoxMesh" id="Mesh_body"]
size = Vector3(0.36, 0.5, 0.3)

[sub_resource type="BoxMesh" id="Mesh_wing"]
size = Vector3(0.6, 0.06, 0.32)

[sub_resource type="BoxShape3D" id="Shape_attack"]
size = Vector3(0.9, 0.9, 1.0)

[sub_resource type="BoxShape3D" id="Shape_hurt"]
size = Vector3(1.3, 1.1, 1.0)''',
  18.0,
  '''body_color = Color(0.13, 0.1, 0.13, 1)
windup_time = 0.45
attack_time = 0.5
recover_time = 0.5
backstab_allowed = false
parry_allowed = false
hurt_voice = &""
death_voice = &""
echoes = 10''',
  '''[node name="Collision" type="CollisionShape3D" parent="."]
shape = SubResource("Shape_body")

[node name="Visual" type="Node3D" parent="."]

[node name="Body" type="MeshInstance3D" parent="Visual"]
mesh = SubResource("Mesh_body")

[node name="WingLeft" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.4, 0.05, 0)
mesh = SubResource("Mesh_wing")

[node name="WingRight" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.4, 0.05, 0)
mesh = SubResource("Mesh_wing")

[node name="AttackHitbox" type="Area3D" parent="Visual"]
collision_layer = 0
collision_mask = 2
script = ExtResource("2_hitbox")
damage = 10.0
knockback = 4.0

[node name="Shape" type="CollisionShape3D" parent="Visual/AttackHitbox"]
shape = SubResource("Shape_attack")

[node name="Hurtbox" type="Area3D" parent="."]
collision_layer = 4
collision_mask = 0
script = ExtResource("3_hurtbox")

[node name="Shape" type="CollisionShape3D" parent="Hurtbox"]
shape = SubResource("Shape_hurt")''')
Path("actors/enemies/bat.tscn").write_text(bat, encoding="utf-8")


wolf = enemy_scene('[ext_resource type="Script" path="res://actors/enemies/werewolf.gd" id="1_dummy"]',
  '[node name="Werewolf" type="CharacterBody3D"]\ncollision_layer = 4\ncollision_mask = 3\nscript = ExtResource("1_dummy")',
  """[sub_resource type="StandardMaterial3D" id="Mat_fur"]
albedo_color = Color(0.09, 0.075, 0.07, 1)

[sub_resource type="StandardMaterial3D" id="Mat_claw"]
albedo_color = Color(0.72, 0.68, 0.58, 1)

[sub_resource type="StandardMaterial3D" id="Mat_eye"]
albedo_color = Color(1, 0.15, 0.05, 1)
emission_enabled = true
emission = Color(1, 0.15, 0.05, 1)
emission_energy_multiplier = 3.0

[sub_resource type="BoxShape3D" id="Shape_body"]
size = Vector3(1.0, 2.1, 1.0)

[sub_resource type="BoxMesh" id="Mesh_body"]
size = Vector3(1.1, 1.6, 0.8)

[sub_resource type="BoxMesh" id="Mesh_hump"]
material = SubResource("Mat_fur")
size = Vector3(1.0, 0.6, 0.75)

[sub_resource type="BoxMesh" id="Mesh_leg"]
material = SubResource("Mat_fur")
size = Vector3(0.36, 1.0, 0.36)

[sub_resource type="BoxMesh" id="Mesh_arm"]
material = SubResource("Mat_fur")
size = Vector3(0.26, 1.35, 0.26)

[sub_resource type="BoxMesh" id="Mesh_claw"]
material = SubResource("Mat_claw")
size = Vector3(0.36, 0.3, 0.1)

[sub_resource type="BoxMesh" id="Mesh_skull"]
material = SubResource("Mat_fur")
size = Vector3(0.62, 0.5, 0.5)

[sub_resource type="BoxMesh" id="Mesh_snout"]
material = SubResource("Mat_fur")
size = Vector3(0.5, 0.24, 0.3)

[sub_resource type="BoxMesh" id="Mesh_ear"]
material = SubResource("Mat_fur")
size = Vector3(0.12, 0.34, 0.12)

[sub_resource type="BoxMesh" id="Mesh_eye"]
material = SubResource("Mat_eye")
size = Vector3(0.1, 0.06, 0.52)

[sub_resource type="BoxMesh" id="Mesh_spike"]
material = SubResource("Mat_fur")
size = Vector3(0.12, 0.42, 0.3)

[sub_resource type="BoxShape3D" id="Shape_attack"]
size = Vector3(2.4, 2.2, 4.0)

[sub_resource type="BoxShape3D" id="Shape_hurt"]
size = Vector3(1.5, 2.5, 1.2)""",
  240.0,
  """facing = 1.0
dormant = true
non_lethal = true
body_color = Color(0.09, 0.075, 0.07, 1)
windup_tint = 0.25
hurt_voice = &""
death_voice = &""
detect_range = 26.0
back_sense_range = 26.0
chase_speed = 6.0
attack_range = 2.4
stagger_time = 0.2
max_poise = 9999.0
turn_time = 0.12
backstab_allowed = false
parry_allowed = false
roll_through = true
flinch_threshold = 999.0
echoes = 0""",
  """[node name="Collision" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.05, 0)
shape = SubResource("Shape_body")

[node name="Visual" type="Node3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -0.95)

[node name="Body" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.35, 0)
mesh = SubResource("Mesh_body")

[node name="Hump" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.1, 2.25, 0)
mesh = SubResource("Mesh_hump")

[node name="SpikeA" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(0.92, 0.39, 0, -0.39, 0.92, 0, 0, 0, 1, -0.45, 2.6, 0)
mesh = SubResource("Mesh_spike")

[node name="SpikeB" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(0.92, 0.39, 0, -0.39, 0.92, 0, 0, 0, 1, -0.1, 2.68, 0)
mesh = SubResource("Mesh_spike")

[node name="SpikeC" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(0.92, 0.39, 0, -0.39, 0.92, 0, 0, 0, 1, -0.65, 2.3, 0)
mesh = SubResource("Mesh_spike")

[node name="LegA" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.28, 0.5, 0.2)
mesh = SubResource("Mesh_leg")

[node name="LegB" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.28, 0.5, -0.2)
mesh = SubResource("Mesh_leg")

[node name="ArmFront" type="Node3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.55, 2.05, 0.5)

[node name="Arm" type="MeshInstance3D" parent="Visual/ArmFront"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.65, 0)
mesh = SubResource("Mesh_arm")

[node name="Claw" type="MeshInstance3D" parent="Visual/ArmFront"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -1.42, 0)
mesh = SubResource("Mesh_claw")

[node name="ArmBack" type="Node3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.45, 2.05, -0.5)

[node name="Arm" type="MeshInstance3D" parent="Visual/ArmBack"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.65, 0)
mesh = SubResource("Mesh_arm")

[node name="Claw" type="MeshInstance3D" parent="Visual/ArmBack"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -1.42, 0)
mesh = SubResource("Mesh_claw")

[node name="Head" type="Node3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.55, 2.3, 0)

[node name="Skull" type="MeshInstance3D" parent="Visual/Head"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.2, 0, 0)
mesh = SubResource("Mesh_skull")

[node name="Snout" type="MeshInstance3D" parent="Visual/Head"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.65, -0.1, 0)
mesh = SubResource("Mesh_snout")

[node name="EarA" type="MeshInstance3D" parent="Visual/Head"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.05, 0.38, 0.14)
mesh = SubResource("Mesh_ear")

[node name="EarB" type="MeshInstance3D" parent="Visual/Head"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.05, 0.38, -0.14)
mesh = SubResource("Mesh_ear")

[node name="Eye" type="MeshInstance3D" parent="Visual/Head"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.38, 0.1, 0)
mesh = SubResource("Mesh_eye")

[node name="AttackHitbox" type="Area3D" parent="Visual"]
collision_layer = 0
collision_mask = 2
script = ExtResource("2_hitbox")
damage = 18.0
knockback = 7.0

[node name="Shape" type="CollisionShape3D" parent="Visual/AttackHitbox"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.25, 1.1, 0)
shape = SubResource("Shape_attack")

[node name="Hurtbox" type="Area3D" parent="."]
collision_layer = 4
collision_mask = 0
script = ExtResource("3_hurtbox")

[node name="Shape" type="CollisionShape3D" parent="Hurtbox"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.25, 0)
shape = SubResource("Shape_hurt")""")
Path("actors/enemies/werewolf.tscn").write_text(wolf, encoding="utf-8")
print("ok")
