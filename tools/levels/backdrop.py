"""Фон и передний план комнат (GAME_DESIGN §2.2): общий каркас слоёв, наполнение — своё у биома.

Каркас один для всех: небо-градиент, горизонт (−45…−70 м), дальний план (−20…−32 м), средний (−8…−15 м),
дымка между слоями, ближняя земля и полоса тёмных силуэтов перед героем (z 3.6…6, в ближнем размытии глубины).
Чем наполнить слои, решает биом и комната: деревня, кладбище, лес, болото, мёртвая деревня.

Работает с обоими классами сцен (`scenery.Scene` и `Scene` из build_village.py): нужны только `node()`, `subs`
и `nodes`. Силуэты — MeshInstance3D с общими единичными сетками и масштабом в transform, без тени и коллизии.
Случайность — от id комнаты: генератор воспроизводим.
"""
import math
import random
import zlib

from scenery import MIST_SHADER

SKY_SHADER = """shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_disabled;
uniform vec4 top : source_color = vec4(0.03, 0.035, 0.05, 1.0);
uniform vec4 horizon : source_color = vec4(0.14, 0.15, 0.19, 1.0);
uniform float horizon_at = 0.6;
uniform vec4 glow : source_color = vec4(0.0);
uniform vec2 glow_at = vec2(0.2, 0.6);
uniform float glow_size = 0.12;
void fragment() {
	float t = smoothstep(0.0, horizon_at, UV.y);
	vec3 c = mix(top.rgb, horizon.rgb, t * t);
	c *= mix(1.0, 0.6, clamp((UV.y - horizon_at) / (1.0 - horizon_at), 0.0, 1.0));
	vec2 d = (UV - glow_at) * vec2(1.0, 2.4);
	c += glow.rgb * glow.a * exp(-dot(d, d) / (glow_size * glow_size));
	ALBEDO = c;
}
"""

PATH_SHADER = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.1, 0.09, 0.07, 1.0);
float hash(float p) { return fract(sin(p * 127.1) * 43758.5453); }
float noise(float x) { float i = floor(x); float f = fract(x); return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f)); }
void fragment() {
	float band = smoothstep(0.0, 0.42, UV.y) * smoothstep(1.0, 0.62, UV.y);
	float ends = smoothstep(0.0, 0.03, UV.x) * smoothstep(1.0, 0.97, UV.x);
	float patch = 0.65 + 0.35 * noise(UV.x * 18.0);
	ALBEDO = tint.rgb * tint.a * band * ends * patch;
}
"""

## Силуэты: цвет и (необязательно) свечение. Тёмные, без бликов: читаются формой, а туман окружения
## сам осветляет их с глубиной (воздушная перспектива).
MATS = {
    "sil": ((0.035, 0.035, 0.042), 0.0), "sil_warm": ((0.055, 0.04, 0.035), 0.0), "ridge": ((0.07, 0.075, 0.09), 0.0),
    "fir": ((0.045, 0.06, 0.065), 0.0), "bark": ((0.06, 0.052, 0.048), 0.0), "stone": ((0.1, 0.1, 0.11), 0.0),
    "earth": ((0.04, 0.036, 0.04), 0.0), "reed": ((0.09, 0.085, 0.05), 0.0), "water": ((0.015, 0.02, 0.022), 0.0),
    "window": ((1.0, 0.6, 0.25), 2.2), "moonlit": ((0.35, 0.42, 0.5), 0.6), "ember": ((0.9, 0.35, 0.1), 1.6), "wisp": ((0.45, 0.6, 0.3), 1.4),
    "rye": ((0.14, 0.12, 0.07), 0.0), "rye_dark": ((0.075, 0.065, 0.04), 0.0), "straw": ((0.13, 0.11, 0.065), 0.0),
    "jack": ((1.0, 0.5, 0.12), 1.8),
}
MESHES = {"box": 'BoxMesh', "prism": 'PrismMesh', "cone": 'CylinderMesh', "ball": 'SphereMesh'}

FAR_PAD = 60.0  # дальние слои шире комнаты: камера ходит за героем до края и видит за него


class Kit:
    """Наполнитель одной сцены: свои ресурсы с префиксом BD_, контейнеры Decor/Backdrop и Decor/Foreground."""

    def __init__(self, s, seed=None):
        self.s = s
        self.rng = random.Random(zlib.crc32((seed or s.room_id).encode()))
        self.made = set()
        self.count = {}
        for name in ("Backdrop", "Foreground"):
            s.node(name, 'type="Node3D"', "Decor", [])

    # --- ресурсы
    def _res(self, sid, text):
        if sid not in self.made:
            self.made.add(sid)
            self.s.subs.append(text)
        return f'SubResource("{sid}")'

    def _mat(self, name):
        c, e = MATS[name]
        body = f'albedo_color = Color({c[0]}, {c[1]}, {c[2]}, 1)\nroughness = 1.0'
        if e:
            body += f'\nemission_enabled = true\nemission = Color({c[0]}, {c[1]}, {c[2]}, 1)\nemission_energy_multiplier = {e}'
        return self._res(f"BD_mat_{name}", f'[sub_resource type="StandardMaterial3D" id="BD_mat_{name}"]\n{body}')

    def _mesh(self, shape, mat):
        mref = self._mat(mat)
        extra = {"box": "", "prism": "", "cone": "\ntop_radius = 0.0\nbottom_radius = 0.5\nheight = 1.0\nradial_segments = 7\nrings = 1",
                 "ball": "\nradius = 0.5\nheight = 1.0\nradial_segments = 10\nrings = 5"}[shape]
        sid = f"BD_{shape}_{mat}"
        return self._res(sid, f'[sub_resource type="{MESHES[shape]}" id="{sid}"]\nmaterial = {mref}{extra}')

    def _name(self, base):
        n = self.count.get(base, 0)
        self.count[base] = n + 1
        return f"{base}{n}"

    # --- примитив: единичная сетка, масштаб и наклон по Z (базис в .tscn — по строкам)
    def put(self, layer, base, shape, mat, pos, scale, tilt=0.0, turn=0.0):
        c, s = math.cos(tilt), math.sin(tilt)
        cy, sy = math.cos(turn), math.sin(turn)
        sx, sy_, sz = scale
        # R = Rz(tilt) · Ry(turn), затем масштаб по осям
        r = ((c * cy, -s, c * sy), (s * cy, c, s * sy), (-sy, 0.0, cy))
        rows = [[r[i][j] * (sx, sy_, sz)[j] for j in range(3)] for i in range(3)]
        vals = ", ".join(_f(v) for row in rows for v in row)
        org = ", ".join(_f(v) for v in pos)
        self.s.nodes.append(f'[node name="{self._name(base)}" type="MeshInstance3D" parent="Decor/{layer}"]\n'
                            f'transform = Transform3D({vals}, {org})\nmesh = {self._mesh(shape, mat)}\ncast_shadow = 0')

    def quad(self, layer, base, pos, size, material, parent=None):
        sid = f"BD_quad_{_f(size[0])}x{_f(size[1])}".replace(".", "_").replace("-", "m")
        mesh = self._res(sid, f'[sub_resource type="QuadMesh" id="{sid}"]\nsize = Vector2({_f(size[0])}, {_f(size[1])})')
        self.s.nodes.append(f'[node name="{self._name(base)}" type="MeshInstance3D" parent="{parent or "Decor/" + layer}"]\n'
                            f'position = Vector3({_f(pos[0])}, {_f(pos[1])}, {_f(pos[2])})\nmesh = {mesh}\n'
                            f'material_override = {material}\ncast_shadow = 0')

    def put_in(self, parent, name, shape, mat, pos, scale):
        """Силуэт в чужом контейнере (Burning/AfterFire у деревни)."""
        self.s.nodes.append(f'[node name="{name}" type="MeshInstance3D" parent="{parent}"]\n'
                            f'transform = Transform3D({_f(scale[0])}, 0, 0, 0, {_f(scale[1])}, 0, 0, 0, {_f(scale[2])}, '
                            f'{_f(pos[0])}, {_f(pos[1])}, {_f(pos[2])})\nmesh = {self._mesh(shape, mat)}\ncast_shadow = 0')

    # --- небо и дымка
    def sky(self, left, right, top, horizon, glow=None, glow_x=0.2, glow_size=0.12, parent=None, tag="Sky", glow_y=0.6):
        """Небо — плоскость за всем, без тумана. Горизонт кадра — около y=0 (60 % высоты сверху)."""
        code = SKY_SHADER.replace("\\", "\\\\").replace('"', '\\"')
        shader = self._res("BD_sky_shader", f'[sub_resource type="Shader" id="BD_sky_shader"]\ncode = "{code}"')
        g = glow or (0.0, 0.0, 0.0, 0.0)
        sid = f"BD_sky_{tag}"
        mat = self._res(sid, f'[sub_resource type="ShaderMaterial" id="{sid}"]\nshader = {shader}\n'
                             f'shader_parameter/top = Color({top[0]}, {top[1]}, {top[2]}, 1)\n'
                             f'shader_parameter/horizon = Color({horizon[0]}, {horizon[1]}, {horizon[2]}, 1)\n'
                             f'shader_parameter/horizon_at = 0.6\nshader_parameter/glow = Color({g[0]}, {g[1]}, {g[2]}, {g[3]})\n'
                             f'shader_parameter/glow_at = Vector2({glow_x}, {glow_y})\nshader_parameter/glow_size = {glow_size}')
        w = right - left + 2 * FAR_PAD + 120
        self.quad("Backdrop", tag, ((left + right) / 2, 16.0, -80.0), (w, 100.0), mat, parent)

    def haze(self, left, right, y, z, h, color, alpha, pad=FAR_PAD, parent=None):
        code = MIST_SHADER.replace("\\", "\\\\").replace('"', '\\"')
        shader = self._res("BD_mist_shader", f'[sub_resource type="Shader" id="BD_mist_shader"]\ncode = "{code}"')
        key = "_".join(_f(v) for v in (*color, alpha)).replace(".", "p")
        mat = self._res(f"BD_haze_{key}", f'[sub_resource type="ShaderMaterial" id="BD_haze_{key}"]\nshader = {shader}\n'
                                          f'shader_parameter/tint = Color({color[0]}, {color[1]}, {color[2]}, {alpha})')
        self.quad("Backdrop", "Haze", ((left + right) / 2, y, z), (right - left + 2 * pad, h), mat, parent)

    # --- земля
    def far_ground(self, left, right, y=0.0, mat="earth"):
        """Земля до горизонта: дальние слои стоят на ней, а не висят в пустоте."""
        self.put("Backdrop", "FarLand", "box", mat, ((left + right) / 2, y - 2.0, -58.0), (right - left + 2 * FAR_PAD + 80, 4.0, 44.0))

    def near_ground(self, left, right, y=-0.25, z0=2.2, z1=18.0, pad=30.0):
        """Ближняя земля перед героем: камера смотрит на неё сверху, а не в чёрный срез пола."""
        self.put("Foreground", "NearLand", "box", "earth", ((left + right) / 2, y - 1.0, (z0 + z1) / 2), (right - left + 2 * pad, 2.0, z1 - z0))

    def near_slope(self, x0, y0, x1, y1, z0=2.2, z1=18.0):
        """Ближняя земля на склоне: от (x0, y0) до (x1, y1), как пол в плоскости героя."""
        a = math.atan2(y1 - y0, x1 - x0)
        ln = math.hypot(x1 - x0, y1 - y0)
        cx, cy = (x0 + x1) / 2 + math.sin(a) * 1.25, (y0 + y1) / 2 - math.cos(a) * 1.25
        self.put("Foreground", "NearSlope", "box", "earth", (cx, cy, (z0 + z1) / 2), (ln + 0.6, 2.0, z1 - z0), tilt=a)

    # --- силуэты горизонта
    def mountains(self, x0, x1, z, base, lo, hi, mat="ridge"):
        """Гряда: призмы разной ширины и высоты внахлёст."""
        x = x0
        while x < x1:
            h = self.rng.uniform(lo, hi)
            w = h * self.rng.uniform(1.6, 2.6)
            self.put("Backdrop", "Peak", "prism", mat, (x, base + h / 2, z + self.rng.uniform(-4, 4)), (w, h, 6.0))
            x += w * self.rng.uniform(0.35, 0.6)

    def firs(self, x0, x1, z0, z1, lo, hi, step=(2.5, 4.5), base=0.0, mat="fir"):
        x = x0
        while x < x1:
            h = self.rng.uniform(lo, hi)
            self.put("Backdrop", "Fir", "cone", mat, (x, base + h / 2 - 0.4, self.rng.uniform(z1, z0)), (h * 0.32, h, h * 0.32))
            x += self.rng.uniform(*step)

    def hills(self, x0, x1, z, base, lo, hi, mat="earth"):
        x = x0
        while x < x1:
            w = self.rng.uniform(18, 34)
            h = self.rng.uniform(lo, hi)
            self.put("Backdrop", "Hill", "ball", mat, (x, base, z + self.rng.uniform(-3, 3)), (w, h * 2, 14.0))
            x += w * 0.6

    def dead_trees(self, x0, x1, z0, z1, lo, hi, step=(6, 12), base=0.0, mat="sil"):
        x = x0
        while x < x1:
            h = self.rng.uniform(lo, hi)
            z = self.rng.uniform(z1, z0)
            r = h * 0.035
            self.put("Backdrop", "Trunk", "box", mat, (x, base + h / 2, z), (r * 2, h, r * 2), tilt=self.rng.uniform(-0.08, 0.08))
            for k in range(3):
                f = 0.5 + k * 0.17
                side = 1 if (k + int(x)) % 2 else -1
                ln = h * self.rng.uniform(0.18, 0.3)
                a = side * self.rng.uniform(0.6, 1.0)
                self.put("Backdrop", "Branch", "box", mat, (x - math.sin(a) * ln / 2, base + h * f + math.cos(a) * ln / 2, z),
                         (r * 0.9, ln, r * 0.9), tilt=a)
            x += self.rng.uniform(*step)

    def houses(self, x0, x1, z0, z1, base=0.0, mat="sil", windows=0.0, ruined=False, step=(7, 13)):
        """Силуэты домов: стена, двускатная крыша, труба, редкие тёплые окна."""
        x = x0
        while x < x1:
            w, h = self.rng.uniform(5, 9), self.rng.uniform(3.5, 6)
            z = self.rng.uniform(z1, z0)
            self.put("Backdrop", "House", "box", mat, (x, base + h / 2, z), (w, h, 4.0))
            rh = self.rng.uniform(2.5, 4.5)
            if ruined and self.rng.random() < 0.6:
                self.put("Backdrop", "Roof", "prism", mat, (x - w * 0.18, base + h + rh / 2 - 0.6, z), (w * 0.7, rh, 4.4), tilt=0.18)
            else:
                self.put("Backdrop", "Roof", "prism", mat, (x, base + h + rh / 2, z), (w + 1.0, rh, 4.4))
                if self.rng.random() < 0.6:
                    self.put("Backdrop", "Chimney", "box", mat, (x + w * 0.25, base + h + rh * 0.7, z), (0.7, rh, 0.7))
            if self.rng.random() < windows:
                self.put("Backdrop", "Window", "box", "window", (x + self.rng.uniform(-w / 4, w / 4), base + h * 0.55, z + 2.05), (0.6, 0.8, 0.05))
            x += w + self.rng.uniform(*step) - 5

    def windmill(self, x, z, base, h, mat="sil", turn=0.4):
        """Ветряная мельница вдали — ориентир Полей: башня, шатёр, четыре крыла крестом. Без случайности."""
        self.put("Backdrop", "MillTower", "box", mat, (x, base + h * 0.32, z), (h * 0.22, h * 0.64, h * 0.22))
        self.put("Backdrop", "MillCap", "prism", mat, (x, base + h * 0.72, z), (h * 0.3, h * 0.16, h * 0.3))
        hub = (x, base + h * 0.68, z + h * 0.13)
        for i in range(4):
            a = turn + i * math.pi / 2
            ln = h * 0.5
            self.put("Backdrop", "MillSail", "box", mat, (hub[0] + math.cos(a) * ln / 2, hub[1] + math.sin(a) * ln / 2, hub[2]),
                     (ln, h * 0.07, 0.1), tilt=a)

    def broken_bridge(self, x, z, base, span, mat="ridge"):
        """Подвесной перевал вдали (§8.13): две скалы-опоры, от пролёта между ними остались обломки, цепи висят над пропастью."""
        deck = base + 15.0
        for side in (-1, 1):
            self.put("Backdrop", "Crag", "prism", mat, (x + side * span / 2, base + 9.0, z), (span * 0.4, 18.0, 6.0))
            self.put("Backdrop", "Span", "box", "sil", (x + side * span * 0.36, deck - side * 0.4, z + 2.0), (span * 0.26, 0.6, 2.0), tilt=side * 0.12)
            self.put("Backdrop", "Chain", "box", "sil", (x + side * span * 0.2, deck - 2.6, z + 2.0), (0.12, 5.0, 0.12), tilt=side * -0.1)

    def stooks(self, x0, x1, z0, z1, base=0.0, mat="straw", step=(3.0, 7.0)):
        """Копны снопов на сжатом поле."""
        x = x0
        while x < x1:
            h = self.rng.uniform(1.3, 2.0)
            z = self.rng.uniform(z1, z0)
            self.put("Backdrop", "Stook", "cone", mat, (x, base + h / 2 - 0.1, z), (h * 0.75, h, h * 0.75), tilt=self.rng.uniform(-0.06, 0.06))
            self.put("Backdrop", "StookBand", "box", "sil", (x, base + h * 0.55, z), (h * 0.38, 0.07, h * 0.38))
            x += self.rng.uniform(*step)

    def sunflowers(self, x0, x1, z0, z1, base=0.0, mat="sil", step=(1.0, 2.6), layer="Backdrop"):
        """Мёртвые подсолнухи: сухой стебель и тяжёлая голова, свесившаяся вниз."""
        x = x0
        while x < x1:
            h = self.rng.uniform(1.8, 2.8)
            z = self.rng.uniform(z1, z0)
            t = self.rng.uniform(-0.08, 0.08)
            self.put(layer, "Stem", "box", mat, (x, base + h / 2, z), (0.06, h, 0.06), tilt=t)
            side = 1 if self.rng.random() < 0.5 else -1
            self.put(layer, "Head", "ball", mat, (x - math.sin(t) * h + side * 0.18, base + h - 0.15, z), (0.2, 0.55, 0.5), tilt=side * 0.5)
            x += self.rng.uniform(*step)

    def spire(self, x, z, base, h, mat="sil"):
        """Часовня или колокольня вдали: башня и шпиль — ориентир."""
        self.put("Backdrop", "Tower", "box", mat, (x, base + h * 0.35, z), (h * 0.14, h * 0.7, h * 0.14))
        self.put("Backdrop", "Spire", "cone", mat, (x, base + h * 0.85, z), (h * 0.2, h * 0.32, h * 0.2))
        self.put("Backdrop", "Nave", "box", mat, (x + h * 0.22, base + h * 0.2, z), (h * 0.34, h * 0.4, h * 0.2))
        self.put("Backdrop", "NaveRoof", "prism", mat, (x + h * 0.22, base + h * 0.48, z), (h * 0.38, h * 0.16, h * 0.22))

    def crosses(self, x0, x1, z0, z1, base=0.0, mat="stone", step=(1.2, 3.0)):
        x = x0
        while x < x1:
            z = self.rng.uniform(z1, z0)
            h = self.rng.uniform(0.8, 1.6)
            t = self.rng.uniform(-0.2, 0.2)
            if self.rng.random() < 0.55:
                self.put("Backdrop", "Cross", "box", mat, (x, base + h / 2, z), (0.16, h, 0.16), tilt=t)
                self.put("Backdrop", "CrossBar", "box", mat, (x - math.sin(t) * h * 0.2, base + h * 0.7, z), (h * 0.5, 0.14, 0.16), tilt=t)
            else:
                self.put("Backdrop", "Stone", "box", mat, (x, base + h * 0.35, z), (h * 0.5, h * 0.7, 0.2), tilt=t)
            x += self.rng.uniform(*step)

    def trunks(self, x0, x1, z0, z1, rlo, rhi, h=40.0, base=-1.0, mat="bark", step=(5, 9)):
        """Стволы-исполины уходят выше кадра."""
        x = x0
        while x < x1:
            r = self.rng.uniform(rlo, rhi)
            z = self.rng.uniform(z1, z0)
            self.put("Backdrop", "Giant", "cone", mat, (x, base + h / 2, z), (r * 2.4, h * 1.3, r * 2.4))
            for side in (-1, 1):
                self.put("Backdrop", "Buttress", "box", mat, (x + side * r * 1.2, base + 1.4, z), (r * 1.3, 0.9, r * 0.8), tilt=side * -0.55)
            x += self.rng.uniform(*step) + r

    def reeds(self, x0, x1, z0, z1, base=0.0, mat="reed", step=(1.0, 3.0), lo=1.0, hi=2.2, layer="Backdrop"):
        x = x0
        while x < x1:
            z = self.rng.uniform(z1, z0)
            h = self.rng.uniform(lo, hi)
            for k in range(5):
                t = (k - 2) * 0.13 + self.rng.uniform(-0.05, 0.05)
                self.put(layer, "Reed", "box", mat, (x + (k - 2) * 0.1, base + h / 2, z), (0.035, h * self.rng.uniform(0.7, 1.0), 0.035), tilt=t)
            x += self.rng.uniform(*step)

    # --- передний план
    def foreground(self, kind, left, right, ground=lambda x: 0.0, skip=(), step=(9.0, 16.0)):
        """Редкие затенённые предметы места перед героем (как у Mandragora: тени ассетов локации, а не сплошной слой).
        Ближе к пути — ниже (до 0.7 м), дальше — выше (до 1.4 м). skip — участки (x0, x1), где ничего не ставить."""
        pick = FOREGROUND[kind]
        x = left - 6.0 + self.rng.uniform(0, 5)
        while x < right + 6.0:
            if not any(a <= x <= b for a, b in skip):
                z = self.rng.uniform(3.8, 5.6)
                cap = 0.7 if z < 4.6 else 1.4
                item = pick[self.rng.randrange(len(pick))]
                getattr(self, "_fg_" + item)(x, ground(x) - 0.25, z, cap)
            x += self.rng.uniform(*step)

    def path_light(self, x0, x1, y, color, strength=1.0, depth=3.6, parent="Decor/Backdrop"):
        """Подсвеченный путь (§2.2): мягкая полоса света по линии ходьбы, к переднему и заднему краю гаснет.
        Плоскость на полу, складывается со светом сцены."""
        code = PATH_SHADER.replace("\\", "\\\\").replace('"', '\\"')
        shader = self._res("BD_path_shader", f'[sub_resource type="Shader" id="BD_path_shader"]\ncode = "{code}"')
        key = "_".join(_f(v) for v in (*color, strength)).replace(".", "p")
        mat = self._res(f"BD_path_{key}", f'[sub_resource type="ShaderMaterial" id="BD_path_{key}"]\nshader = {shader}\n'
                                          f'shader_parameter/tint = Color({color[0]}, {color[1]}, {color[2]}, {strength})')
        w = x1 - x0
        sid = f"BD_plane_{_f(w)}x{_f(depth)}".replace(".", "_").replace("-", "m")
        mesh = self._res(sid, f'[sub_resource type="QuadMesh" id="{sid}"]\nsize = Vector2({_f(w)}, {_f(depth)})\norientation = 1')
        self.s.nodes.append(f'[node name="{self._name("PathLight")}" type="MeshInstance3D" parent="{parent}"]\n'
                            f'position = Vector3({_f((x0 + x1) / 2)}, {_f(y + 0.015)}, 0.2)\nmesh = {mesh}\n'
                            f'material_override = {mat}\ncast_shadow = 0')

    def _fg_grass(self, x, y, z, cap):
        h = self.rng.uniform(0.4, cap)
        for k in range(7):
            t = (k - 3) * 0.16 + self.rng.uniform(-0.06, 0.06)
            self.put("Foreground", "Grass", "box", "sil", (x + (k - 3) * 0.09, y + h / 2, z), (0.04, h * self.rng.uniform(0.6, 1.0), 0.04), tilt=t)

    def _fg_rock(self, x, y, z, cap):
        s = self.rng.uniform(0.5, 1.2)
        self.put("Foreground", "Rock", "ball", "earth", (x, y + 0.1, z), (s * 1.6, min(s, cap) * 0.9, s), turn=self.rng.uniform(0, 3))
        self.put("Foreground", "Rock", "ball", "earth", (x + s * 0.8, y, z + 0.3), (s, s * 0.5, s * 0.8))

    def _fg_fence(self, x, y, z, cap):
        h = min(cap, 1.2)
        t = self.rng.uniform(-0.15, 0.15)
        for k in range(3):
            self.put("Foreground", "Picket", "box", "sil_warm", (x + k * 0.55, y + h / 2, z), (0.1, h * (1 - k * 0.12), 0.08), tilt=t + k * 0.05)
        self.put("Foreground", "Rail", "box", "sil_warm", (x + 0.55, y + h * 0.6, z + 0.05), (1.6, 0.07, 0.05), tilt=t * 0.5)

    def _fg_wheel(self, x, y, z, cap):
        r = min(cap, 1.0) * 0.6
        self.put("Foreground", "Wheel", "ball", "sil_warm", (x, y + r * 0.7, z), (r * 2, r * 2, 0.12), tilt=0.2)

    def _fg_cross(self, x, y, z, cap):
        h = min(cap, 1.3)
        t = self.rng.uniform(-0.35, 0.35)
        self.put("Foreground", "Cross", "box", "sil", (x, y + h / 2, z), (0.14, h, 0.12), tilt=t)
        self.put("Foreground", "CrossBar", "box", "sil", (x - math.sin(t) * h * 0.2, y + h * 0.7, z), (h * 0.5, 0.12, 0.12), tilt=t)

    def _fg_railing(self, x, y, z, cap):
        h = min(cap, 1.3)
        for k in range(5):
            self.put("Foreground", "Bar", "box", "sil", (x + k * 0.22, y + h / 2, z), (0.05, h * (1.0 if k % 2 else 0.88), 0.05))
        self.put("Foreground", "BarRail", "box", "sil", (x + 0.44, y + h * 0.75, z), (1.1, 0.05, 0.05), tilt=0.06)

    def _fg_root(self, x, y, z, cap):
        ln = self.rng.uniform(1.5, 3.0)
        a = self.rng.uniform(0.25, 0.6) * (1 if self.rng.random() < 0.5 else -1)
        self.put("Foreground", "Root", "box", "sil_warm", (x, y + min(cap, 0.9) * 0.4, z), (ln, 0.28, 0.32), tilt=a)
        self.put("Foreground", "Root", "box", "sil_warm", (x + ln * 0.45, y + 0.1, z + 0.2), (ln * 0.6, 0.2, 0.26), tilt=-a * 0.4)

    def _fg_fern(self, x, y, z, cap):
        h = self.rng.uniform(0.4, min(cap, 0.9))
        for k in range(6):
            a = (k - 2.5) * 0.35
            self.put("Foreground", "Frond", "box", "sil", (x + math.sin(a) * h * 0.5, y + math.cos(a) * h * 0.45, z),
                     (0.08, h, 0.03), tilt=-a)

    def _fg_reeds(self, x, y, z, cap):
        self.reeds(x, x + 0.5, z, z, base=y, mat="sil", step=(1.0, 1.0), lo=0.6, hi=max(0.7, cap + 0.2), layer="Foreground")

    def _fg_stump(self, x, y, z, cap):
        h = self.rng.uniform(0.4, min(cap, 0.9))
        self.put("Foreground", "Stump", "box", "sil_warm", (x, y + h / 2, z), (0.5, h, 0.5), tilt=self.rng.uniform(-0.1, 0.1))

    def _fg_rye(self, x, y, z, cap):
        h = self.rng.uniform(0.7, cap + 0.4)
        for k in range(9):
            t = (k - 4) * 0.09 + self.rng.uniform(-0.05, 0.05)
            hh = h * self.rng.uniform(0.75, 1.0)
            self.put("Foreground", "Stalk", "box", "sil", (x + (k - 4) * 0.07, y + hh / 2, z), (0.025, hh, 0.025), tilt=t)
            self.put("Foreground", "Ear", "box", "sil", (x + (k - 4) * 0.07 - math.sin(t) * hh, y + hh, z), (0.06, 0.22, 0.05), tilt=t)

    def _fg_sunflower(self, x, y, z, cap):
        self.sunflowers(x, x + 0.5, z, z, base=y, step=(1.0, 1.0), layer="Foreground")

    def _fg_pumpkin(self, x, y, z, cap):
        s = self.rng.uniform(0.5, 0.8)
        self.put("Foreground", "Pumpkin", "ball", "sil_warm", (x, y + s * 0.3, z), (s * 1.3, s * 0.75, s))
        self.put("Foreground", "PumpkinStem", "box", "sil", (x + 0.05, y + s * 0.7, z), (0.06, 0.2, 0.06), tilt=0.3)

    def _fg_skull(self, x, y, z, cap):
        self._fg_rock(x, y, z, cap)
        self.put("Foreground", "Skull", "ball", "stone", (x - 0.4, y + 0.25, z - 0.3), (0.32, 0.28, 0.3))


## Только предметы, которые есть в этом месте.
FOREGROUND = {
    "village": ("fence", "fence", "wheel", "stump"),
    "cemetery": ("cross", "cross", "railing"),
    "forest": ("root", "root", "stump", "fern"),
    "swamp": ("reeds", "reeds", "stump"),
    "dead": ("fence", "skull", "stump"),
    "fields": ("rye", "rye", "sunflower", "rock"),
    "garden": ("pumpkin", "fence", "rye"),
}


def _f(v):
    v = round(float(v), 3)
    if v == 0:
        return "0"
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return s


# ---------------------------------------------------------------- биомы
## Каждый биом — небо, горизонт, дальний и средний планы, дымка. Запад (слева) — горы «Пепельные Пики»,
## восток (справа) — лес; деревня между ними. Горизонт показывает, где игрок был и куда идёт.

def village(k, left, right, fog, burn=None, spire_x=None, ground=0.0, mill_x=None):
    """Деревня: дома второго ряда, холмы, горы на западе, лес на востоке, шпиль часовни — следующий шаг.
    burn — туман пожара: тогда небо и дымка двух видов, в контейнерах Burning и AfterFire (комната сама
    показывает нужный, `Room.burning_until`), над домами — зарево и столбы дыма."""
    k.far_ground(left, right, ground)
    k.mountains(left - FAR_PAD, left + 20, -70, ground - 1, 18, 32)
    k.hills(left - 40, right + 40, -50, ground - 2, 3, 6)
    k.firs(right - 10, right + FAR_PAD, -44, -54, 9, 16, base=ground)
    k.houses(left - 30, right + 30, -24, -32, base=ground)
    if spire_x is not None:
        k.spire(spire_x, -36, ground, 16)
    if mill_x is not None:
        k.windmill(mill_x, -46, ground + 2, 15)
    states = (("AfterFire", fog, SKY_NIGHT), ("Burning", burn, SKY_FIRE)) if burn else ((None, fog, SKY_NIGHT),)
    for parent, f, (top, hor, glow) in states:
        k.sky(left, right, top, hor, glow=glow if parent else None, glow_x=0.5, glow_size=0.3, parent=parent, tag=f"Sky{parent or ''}")
        k.haze(left, right, ground + 3, -20, 10, f, 0.35, parent=parent)
        k.haze(left, right, ground + 6, -40, 22, f, 0.5, parent=parent)
    if burn:
        # Пожар за вторым рядом: зарево над крышами и столбы дыма.
        k.haze(left, right, ground + 5, -27, 12, (0.55, 0.2, 0.06), 0.35, parent="Burning")
        x = left - 20
        while x < right + 20:
            k.haze(x - 2.5, x + 2.5, ground + 14, -29, 22, (0.08, 0.06, 0.06), 0.55, pad=0, parent="Burning")
            x += k.rng.uniform(14, 24)


SKY_NIGHT = ((0.03, 0.035, 0.07), (0.17, 0.19, 0.28), None)
SKY_FIRE = ((0.05, 0.018, 0.012), (0.4, 0.13, 0.05), (0.6, 0.2, 0.05, 0.6))


def hub(k, left, right, fog):
    """Двор часовни: слева — деревня (откуда пришёл), справа — лес и кладбищенский холм (куда идти)."""
    k.far_ground(left, right)
    k.mountains(left - FAR_PAD, left + 10, -72, -1, 18, 30)
    k.houses(left - 40, left + 8, -26, -34, windows=0.5)
    k.hills(left - 20, right + 40, -52, -2, 3, 5)
    k.hills(right - 6, right + 30, -30, -1, 4, 7)
    k.crosses(right - 4, right + 22, -28, -32, base=3.5)
    k.firs(left + 10, right + FAR_PAD, -40, -50, 10, 18, base=0.0)
    k.haze(left, right, 3, -18, 9, fog, 0.3)
    k.haze(left, right, 6, -38, 22, fog, 0.5)


def cemetery(k, left, right, fog, ground=0.0):
    """Кладбище: ряды надгробий вглубь, колокольня на холме, зарево деревни на западе, лес на востоке."""
    k.far_ground(left, right, ground)
    k.mountains(left - FAR_PAD, left - 10, -74, ground - 1, 14, 24)
    k.firs(left - 20, right + FAR_PAD, -44, -56, 10, 20, base=ground)
    k.hills(left - 10, right + 20, -24, ground - 1.5, 2, 3.5)
    k.crosses(left - 20, right + 20, -9, -13, base=ground)
    k.crosses(left - 30, right + 30, -16, -21, base=ground + 0.6, step=(1.6, 3.4))
    k.spire(right - 14, -27, ground + 2.5, 13)
    k.dead_trees(left - 20, right + 20, -14, -22, 7, 12)
    k.haze(left, right, ground + 2, -12, 6, fog, 0.25)
    k.haze(left, right, ground + 3, -23, 10, fog, 0.4)
    k.haze(left, right, ground + 6, -40, 22, fog, 0.5)


def forest(k, left, right, fog, ground=0.0, giants=True):
    """Мёртвый лес: исполины на трёх глубинах, ели стеной, светлые прорехи тумана."""
    k.far_ground(left, right, ground)
    k.firs(left - FAR_PAD, right + FAR_PAD, -44, -58, 14, 26, step=(2.0, 3.5), base=ground)
    k.firs(left - 30, right + 30, -26, -34, 10, 20, step=(2.5, 4.5), base=ground)
    if giants:
        k.trunks(left - 20, right + 20, -14, -20, 1.4, 2.4, base=ground - 1)
    k.haze(left, right, ground + 4, -11, 12, fog, 0.3)
    k.haze(left, right, ground + 5, -23, 16, fog, 0.45)
    k.haze(left, right, ground + 8, -38, 26, fog, 0.55)


def swamp(k, left, right, fog, ground=0.0):
    """Болото: тёмная вода до горизонта, камыш слоями, затопленные стволы, огоньки."""
    k.far_ground(left, right, ground - 0.15)
    k.put("Backdrop", "Water", "box", "water", ((left + right) / 2, ground - 0.1, -18.0), (right - left + 2 * FAR_PAD, 0.1, 30.0))
    k.firs(left - FAR_PAD, right + FAR_PAD, -48, -58, 8, 15, step=(3.0, 6.0), base=ground)
    k.dead_trees(left - 30, right + 30, -24, -34, 8, 14, step=(5, 10), base=ground)
    k.dead_trees(left - 20, right + 20, -10, -15, 6, 10, step=(8, 14), base=ground, mat="bark")
    k.reeds(left - 20, right + 20, -6, -12, base=ground, step=(1.2, 3.5))
    for i in range(int((right - left) / 8)):
        x = left + 4 + i * 8 + k.rng.uniform(-3, 3)
        k.put("Backdrop", "Wisp", "ball", "wisp", (x, ground + k.rng.uniform(0.4, 1.4), k.rng.uniform(-9, -20)), (0.22, 0.22, 0.22))
    k.haze(left, right, ground + 1.0, -8, 3, fog, 0.4)
    k.haze(left, right, ground + 3, -20, 9, fog, 0.45)
    k.haze(left, right, ground + 7, -40, 22, fog, 0.55)


def dead_village(k, left, right, fog, ground=0.0):
    """Мёртвая деревня Кузнеца: брошенные дома с провалившимися крышами, лес и болото позади."""
    k.far_ground(left, right, ground)
    k.firs(left - FAR_PAD, right + FAR_PAD, -44, -56, 12, 22, step=(2.2, 4.0), base=ground)
    k.houses(left - 30, right + 30, -16, -24, base=ground, ruined=True)
    k.dead_trees(left - 20, right + 20, -12, -20, 7, 11, step=(9, 15), base=ground)
    k.haze(left, right, ground + 2.5, -13, 7, fog, 0.3)
    k.haze(left, right, ground + 4, -27, 14, fog, 0.45)
    k.haze(left, right, ground + 8, -40, 24, fog, 0.55)


## Поля (§8.13). Небо и туман задаёт комната: полдень во ржи, сумерки у мельницы и на огородах.
def fields(k, left, right, fog, ground=0.0, mill_x=None, village=False, bridge_x=None):
    """Поля: рожь волнами до горизонта, копны, мёртвые подсолнухи, редкие сухие деревья. На западе близко встают
    Пепельные Пики, в них — обрушенный мост Подвесного перевала (bridge_x); мельница на холме — ориентир (mill_x);
    village — на востоке деревня и шпиль часовни, откуда пришёл."""
    k.far_ground(left, right, ground, mat="rye_dark")
    k.mountains(left - FAR_PAD - 20, left + 10, -70, ground - 1, 16, 30)
    if bridge_x is not None:
        k.broken_bridge(bridge_x, -62, ground + 20, 24)
    k.hills(left - 40, right + 40, -48, ground - 2, 3, 6, mat="rye")
    k.hills(left - 30, right + 30, -30, ground - 1.6, 1.5, 3, mat="rye_dark")
    k.stooks(left - 30, right + 30, -12, -20, base=ground)
    k.sunflowers(left - 20, right + 20, -7, -11, base=ground)
    k.dead_trees(left - 20, right + 20, -22, -34, 6, 10, step=(18, 30), base=ground)
    if mill_x is not None:
        k.windmill(mill_x, -40, ground + 2, 18)
    if village:
        k.houses(right + 6, right + 70, -26, -34, base=ground, windows=0.5)
        k.spire(right + 60, -40, ground, 16)
    k.haze(left, right, ground + 2, -10, 6, fog, 0.25)
    k.haze(left, right, ground + 4, -24, 12, fog, 0.4)
    k.haze(left, right, ground + 8, -42, 24, fog, 0.55)
