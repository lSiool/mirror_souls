"""Заглушки значков и рамок HUD (§8.12) в SVG: потёртый тёмный металл, шипы, готика.
Финальные значки — нарисованные картинки в стиле референса автора; каждая — свой файл с тем же
именем, код их не различает. Запуск из корня проекта: python tools/ui/make_icons.py
"""
from pathlib import Path

ICONS = Path("assets/ui/icons")
HUD = Path("assets/ui/hud")

METAL = """<linearGradient id="m" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8d877f"/><stop offset="0.45" stop-color="#4a4641"/><stop offset="1" stop-color="#1e1c1a"/></linearGradient>"""
METAL_H = """<linearGradient id="mh" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8a847c"/><stop offset="0.5" stop-color="#3e3a36"/><stop offset="1" stop-color="#1a1816"/></linearGradient>"""

# Значок: id → (фон внутри рамки, рисунок). Рисунок в квадрате 64×64, рамка по краю.
STICK = '<path d="M18 50 L 46 14" stroke="#9c7a52" stroke-width="7" stroke-linecap="round"/><path d="M20 47 L 44 17" stroke="#d1ad80" stroke-width="1.4" stroke-opacity="0.7"/>'
SWORD = '<path d="M46 14 L 24 42" stroke="#d9dde2" stroke-width="4" stroke-linecap="round"/><path d="M18 36 L 30 48" stroke="#a08a60" stroke-width="3.5" stroke-linecap="round"/><path d="M24 42 L 16 52" stroke="#5e4530" stroke-width="4" stroke-linecap="round"/>'
HAMMER = '<path d="M28 54 L 38 22" stroke="#8a7b6a" stroke-width="4" stroke-linecap="round"/><path d="M22 16 L 50 24 L 47 32 L 19 24 Z" fill="#a9adb3" stroke="#e5e7ea" stroke-width="1"/>'
SHIELD = '<circle cx="32" cy="32" r="18" fill="#6f5532" stroke="#c9a46a" stroke-width="3"/><circle cx="32" cy="32" r="7" fill="#8f7346" stroke="#e0c08a" stroke-width="1.5"/>'
BOW = '<path d="M22 12 Q 50 32 22 52" fill="none" stroke="#c9b99c" stroke-width="3.5" stroke-linecap="round"/><path d="M22 12 V 52" stroke="#e8dcc6" stroke-width="1.2"/><path d="M14 32 H 46" stroke="#c9b99c" stroke-width="2"/>'
FLASK = '<rect x="27" y="10" width="10" height="7" rx="1.5" fill="#7a5638"/><path d="M28 17 h8 v8 a14 14 0 1 1 -8 0 z" fill="#c8d3d9" fill-opacity="0.18" stroke="#c7d2d8" stroke-opacity="0.6" stroke-width="1.4"/><path d="M19 38 q 6 -3 13 0 t 13 0 a 13 13 0 0 1 -26 0 z" fill="#a51e22"/><path d="M23 30 a 10 10 0 0 1 6 -4" stroke="#ffffff" stroke-width="2" stroke-linecap="round" fill="none" opacity="0.6"/>'
POTENCY = FLASK + '<path d="M44 14 l 3 6 l 6 1 l -4 4 l 1 6 l -6 -3 l -6 3 l 1 -6 l -4 -4 l 6 -1 z" fill="#9fe0cf" opacity="0.85"/>'
GLASS = '<path d="M32 10 L 48 28 L 40 54 L 22 50 L 16 26 Z" fill="#7fa6cc" fill-opacity="0.45" stroke="#dbeeff" stroke-width="1.5"/><path d="M32 10 L 30 50 M16 26 L 48 28" stroke="#dbeeff" stroke-opacity="0.5"/>'
CLEAR = '<path d="M32 10 L 48 28 L 40 54 L 22 50 L 16 26 Z" fill="#e8f4ff" fill-opacity="0.25" stroke="#ffffff" stroke-width="1.5"/><path d="M24 22 L 30 18" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/>'
SLOT = '<polygon points="32,10 46,32 32,54 18,32" fill="none" stroke="#dbeeff" stroke-width="2.4"/><polygon points="32,20 39,32 32,44 25,32" fill="#b8dbff" opacity="0.6"/>'
RECIPE = '<rect x="18" y="12" width="28" height="40" fill="#b9a780" stroke="#5e4c30" stroke-width="1.5"/><path d="M23 22 H 41 M23 30 H 41 M23 38 H 35" stroke="#5e4c30" stroke-width="2"/><path d="M36 44 L 44 36 L 47 39 L 39 47 Z" fill="#6b6f75"/>'
ECHO = '<path d="M32 10 C 40 22 46 30 46 38 A 14 14 0 0 1 18 38 C 18 30 24 22 32 10 Z" fill="#b8dbff" fill-opacity="0.7" stroke="#e2f1ff" stroke-width="1.5"/>'
NOTE = '<path d="M18 14 H 42 L 46 18 V 50 H 18 Z" fill="#c9bb98" stroke="#5e4c30" stroke-width="1.5"/><path d="M23 24 H 41 M23 31 H 41 M23 38 H 37" stroke="#5e4c30" stroke-width="1.6"/>'
MUD = '<path d="M14 42 q 6 -5 12 0 t 12 0 t 12 0 V 52 H 14 Z" fill="#3b2a18"/><path d="M27 14 v 18 l -6 6 h 18 v -6 l -4 -2 v -16 z" fill="#8f8172"/><path d="M14 42 q 6 -5 12 0 t 12 0 t 12 0" stroke="#8a6a3a" stroke-width="2.5" fill="none"/>'
REGEN = '<path d="M32 12 C 40 24 46 31 46 38 A 14 14 0 0 1 18 38 C 18 31 24 24 32 12 Z" fill="#5f9e84"/><path d="M32 30 V 46 M24 38 H 40" stroke="#e6f4ee" stroke-width="3" stroke-linecap="round"/>'
STAFF = '<path d="M20 54 L 42 16" stroke="#6e5034" stroke-width="5" stroke-linecap="round"/><circle cx="44" cy="13" r="6" fill="#b8dbff" fill-opacity="0.75" stroke="#e8f4ff" stroke-width="1.5"/>'
GLINT = '<path d="M32 8 L 36 28 L 56 32 L 36 36 L 32 56 L 28 36 L 8 32 L 28 28 Z" fill="#fff6dc" stroke="#ffffff" stroke-width="1"/><circle cx="32" cy="32" r="5" fill="#ffffff"/>'
UNKNOWN = '<circle cx="32" cy="32" r="12" fill="none" stroke="#8a847c" stroke-width="2" stroke-dasharray="4 3"/>'

# Боевые расходники (§6.2): без квадратной рамки — лежат в ромбе крестовины HUD.
KNIFE = '<path d="M47 13 L 30 36 L 34 39 Z" fill="#d9dde2" stroke="#f2f4f6" stroke-width="0.8"/><path d="M30 36 L 34 39" stroke="#6b6f75" stroke-width="2.4"/><path d="M31 38 L 20 51" stroke="#5e4530" stroke-width="4" stroke-linecap="round"/><circle cx="19" cy="52" r="2.4" fill="#8a7b6a"/>'
AXE = '<path d="M22 54 L 40 18" stroke="#7a5a3a" stroke-width="4.5" stroke-linecap="round"/><path d="M34 16 Q 50 14 52 30 Q 44 26 38 30 Z" fill="#a9adb3" stroke="#e5e7ea" stroke-width="1"/>'
FIRE = ('<rect x="28" y="12" width="8" height="8" rx="1.5" fill="#7a5638"/><path d="M32 6 q 4 3 0 7 q -3 -3 0 -7" fill="#ffb040"/>'
        '<path d="M29 20 h6 v6 a13 13 0 1 1 -6 0 z" fill="#c8d3d9" fill-opacity="0.2" stroke="#c7d2d8" stroke-opacity="0.6" stroke-width="1.4"/>'
        '<path d="M20 40 q 6 -3 12 0 t 12 0 a 12 12 0 0 1 -24 0 z" fill="#d0601e"/><path d="M26 44 q 6 -6 12 0" stroke="#ffd27a" stroke-width="1.6" fill="none"/>')


def flask(liquid, emblem="", glow=None):
    """Склянка-заглушка цветом листа автора: пробка, стекло, жидкость и знак на стекле."""
    shine = f'<circle cx="32" cy="40" r="15" fill="{glow}" opacity="0.25"/>' if glow else ""
    return (f'{shine}<rect x="28" y="12" width="8" height="8" rx="1.5" fill="#7a5638"/>'
            '<path d="M29 20 h6 v6 a13 13 0 1 1 -6 0 z" fill="#c8d3d9" fill-opacity="0.2" stroke="#c7d2d8" stroke-opacity="0.6" stroke-width="1.4"/>'
            f'<path d="M20 40 q 6 -3 12 0 t 12 0 a 12 12 0 0 1 -24 0 z" fill="{liquid}"/>{emblem}'
            '<path d="M24 31 a 9 9 0 0 1 5 -3.5" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" fill="none" opacity="0.55"/>')


POISON = flask("#6a2a86", '<circle cx="32" cy="41" r="3.2" fill="#d8d0c0"/><rect x="30" y="43" width="4" height="3" fill="#d8d0c0"/>'
               '<path d="M22 14 q 3 -5 6 -1 M38 12 q 4 -4 6 1" stroke="#a070c0" stroke-width="1.6" fill="none" opacity="0.8"/>')
ACID = flask("#7ac21c", '<path d="M26 50 v 5 M33 51 v 6 M39 50 v 4" stroke="#9be030" stroke-width="2" stroke-linecap="round"/>', "#9be030")
HOLY = flask("#c9a85a", '<path d="M32 33 v 16 M26.5 38 h 11" stroke="#fff3c8" stroke-width="2.6" stroke-linecap="round"/>', "#ffe9a8")
TAR = flask("#141110", '<path d="M24 44 q 2 6 4 1 M36 46 q 2 7 4 0" stroke="#3a2c1a" stroke-width="2" fill="none"/>'
            '<path d="M28 20 q -3 4 0 6 M36 20 q 3 3 0 6" stroke="#2a2018" stroke-width="2.2" fill="none"/>')
CONSUMABLES = {"throwing_knife": KNIFE, "throwing_axe": AXE, "fire_flask": FIRE, "poison_flask": POISON,
               "acid_flask": ACID, "holy_flask": HOLY, "tar_flask": TAR}

# Стрелы у лука (§6.2) и состояния от склянок (ряд эффектов HUD).
ARROW = ('<path d="M16 48 L 46 18" stroke="#9c7a52" stroke-width="3" stroke-linecap="round"/>'
         '<path d="M46 18 L 40 19 L 45 24 Z" fill="#d9dde2" stroke="#d9dde2" stroke-width="2"/>'
         '<path d="M16 48 l -3 -6 M16 48 l 6 3 M20 44 l -3 -6 M20 44 l 6 3" stroke="#c9b99c" stroke-width="1.6"/>')
FIRE_ARROW = ARROW + '<path d="M47 8 q 8 6 1 15 q -4 -2 -6 -6 q 0 -5 5 -9" fill="#ff9a30"/><path d="M46 13 q 3 3 1 7 q -2 -2 -2 -4" fill="#ffe08a"/>'
POISONED = ('<path d="M32 12 C 40 24 46 31 46 38 A 14 14 0 0 1 18 38 C 18 31 24 24 32 12 Z" fill="#6a2a86"/>'
            '<circle cx="32" cy="37" r="5" fill="#d8d0c0"/><rect x="29.5" y="40" width="5" height="4" fill="#d8d0c0"/>'
            '<circle cx="30" cy="36.5" r="1.2" fill="#2a1030"/><circle cx="34" cy="36.5" r="1.2" fill="#2a1030"/>')
BURNING = ('<path d="M32 10 C 42 22 46 30 44 40 A 12 12 0 0 1 20 40 C 18 32 24 28 26 20 C 28 26 30 28 32 28 C 32 22 30 16 32 10 Z" fill="#e0601c"/>'
           '<path d="M32 30 C 36 36 38 40 36 44 A 5 5 0 0 1 28 44 C 27 40 30 36 32 30 Z" fill="#ffd27a"/>')
CORRODED = ('<path d="M18 16 H 46 V 34 Q 46 48 32 54 Q 18 48 18 34 Z" fill="#5c6066" stroke="#8a8f96" stroke-width="1.5"/>'
            '<path d="M24 22 q 3 6 0 10 M34 18 q 4 8 1 14 M40 26 q 2 5 -1 8" stroke="#9be030" stroke-width="2.4" fill="none" stroke-linecap="round"/>')
TARRED = ('<path d="M14 40 q 6 -6 12 0 t 12 0 t 12 0 V 52 H 14 Z" fill="#141110"/>'
          '<path d="M24 14 v 20 q 0 4 3 4 M40 14 v 16 q 0 6 -3 6" stroke="#2a2018" stroke-width="5" stroke-linecap="round" fill="none"/>'
          '<path d="M18 44 q 4 -3 8 0" stroke="#5a4a36" stroke-width="1.6" fill="none"/>')


def loose(art):
    """Значок без рамки: прозрачный фон и мягкая тень, чтобы рисунок читался на тёмном ромбе."""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<defs><filter id="s" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="1" dy="2" stdDeviation="1.4" flood-color="#000000" flood-opacity="0.8"/></filter></defs>
<g filter="url(#s)">{art}</g>
</svg>
"""


FACETS = {
    "facet_youth": ("#2a2416", '<path d="M20 50 Q 32 12 44 50 M25 38 H 39" fill="none" stroke="#d9b870" stroke-width="3" stroke-linecap="round"/>'),
    "facet_experience": ("#2a2416", '<path d="M18 18 H 46 L 32 50 Z" fill="none" stroke="#d9b870" stroke-width="3" stroke-linejoin="round"/>'),
    "facet_breath": ("#12201c", '<path d="M14 30 Q 22 20 30 30 T 46 30 M14 42 Q 22 32 30 42 T 46 42" fill="none" stroke="#8fd1bb" stroke-width="3" stroke-linecap="round"/>'),
    "facet_eye": ("#241414", '<path d="M20 14 Q 46 32 20 50 M20 14 V 50 M14 32 H 48" fill="none" stroke="#d98a7e" stroke-width="3" stroke-linecap="round"/>'),
    "facet_blood": ("#241414", '<path d="M32 12 C 38 22 44 28 44 36 A 12 12 0 0 1 20 36 C 20 28 26 22 32 12 Z" fill="#9e1b20" stroke="#e0555a" stroke-width="1.5"/>'),
    "facet_sip": ("#12201c", FLASK),
    "facet_sole": ("#141a22", '<path d="M14 42 L 50 26 M16 50 H 48" fill="none" stroke="#9cc0e0" stroke-width="3" stroke-linecap="round"/>'),
    "facet_grip": ("#141a22", '<path d="M22 50 V 18 M32 50 V 14 M42 50 V 20 M18 36 Q 32 26 46 36" fill="none" stroke="#9cc0e0" stroke-width="3" stroke-linecap="round"/>'),
}

ITEMS = {
    "stick": ("#1c1712", STICK), "sword": ("#141a20", SWORD), "candlestick": ("#17181b", HAMMER),
    "shield_hoplon": ("#1c1712", SHIELD), "bow_hunter": ("#1c1712", BOW), "bow_guard": ("#161a1e", BOW),
    "has_bow": ("#1c1712", BOW), "flask": ("#1c1214", FLASK), "flask_vessel": ("#1c1214", FLASK),
    "flask_potency": ("#12201c", POTENCY), "tempered_glass": ("#141a22", GLASS), "clear_glass": ("#141a22", CLEAR),
    "facet_slot": ("#141a22", SLOT), "recipe_heavy_hammer": ("#1c1712", RECIPE), "boss_smith_echo": ("#141a22", ECHO),
    "note": ("#1c1712", NOTE), "mud": ("#2a1f14", MUD), "regen": ("#12201c", REGEN), "unknown": ("#141112", UNKNOWN),
    "arrow": ("#1c1712", ARROW), "fire_arrow": ("#24160e", FIRE_ARROW), "poison": ("#1e1224", POISONED),
    "burning": ("#24140c", BURNING), "corroded": ("#16200c", CORRODED), "tar": ("#141110", TARRED),
    "staff": ("#141a22", STAFF), "glint": ("#1a1a24", GLINT),
}


def icon(fill, art):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<defs>{METAL}</defs>
<rect x="2" y="2" width="60" height="60" fill="#141112"/>
<rect x="5" y="5" width="54" height="54" fill="{fill}"/>
{art}
<rect x="2.5" y="2.5" width="59" height="59" fill="none" stroke="url(#m)" stroke-width="4"/>
<rect x="5.5" y="5.5" width="53" height="53" fill="none" stroke="#0a0908" stroke-width="1"/>
</svg>
"""


# Медальон зелья: кольцо с шипами, середина прозрачная — в ней лежит значок зелья.
MEDALLION = f"""<svg xmlns="http://www.w3.org/2000/svg" width="160" height="160" viewBox="0 0 160 160">
<defs>{METAL}<radialGradient id="w" cx="0.45" cy="0.4" r="0.7"><stop offset="0" stop-color="#1d1718"/><stop offset="1" stop-color="#050404"/></radialGradient></defs>
<circle cx="80" cy="80" r="56" fill="url(#w)"/>
<polygon points="80,2 90,30 80,40 70,30" fill="url(#m)" stroke="#a39d94" stroke-width="0.8"/>
<polygon points="80,158 90,130 80,120 70,130" fill="url(#m)" stroke="#a39d94" stroke-width="0.8"/>
<polygon points="2,80 30,70 40,80 30,90" fill="url(#m)" stroke="#a39d94" stroke-width="0.8"/>
<polygon points="158,80 130,70 120,80 130,90" fill="url(#m)" stroke="#a39d94" stroke-width="0.8"/>
<polygon points="22,22 40,30 44,40 34,36" fill="url(#m)"/><polygon points="138,22 120,30 116,40 126,36" fill="url(#m)"/>
<polygon points="22,138 40,130 44,120 34,124" fill="url(#m)"/><polygon points="138,138 120,130 116,120 126,124" fill="url(#m)"/>
<circle cx="80" cy="80" r="62" fill="none" stroke="url(#m)" stroke-width="12"/>
<circle cx="80" cy="80" r="69" fill="none" stroke="#9a948b" stroke-opacity="0.55" stroke-width="1"/>
<circle cx="80" cy="80" r="56" fill="none" stroke="#0a0908" stroke-width="2"/>
<path d="M22 54 l -7 -3 M24 108 l -7 4 M50 20 l -2 -7 M110 20 l 2 -7 M138 54 l 7 -3 M136 108 l 7 4" stroke="#8a847c" stroke-width="2" stroke-linecap="round"/>
</svg>
"""

BADGE = f"""<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
<defs>{METAL}</defs><circle cx="24" cy="24" r="20" fill="#0b0a0a" stroke="url(#m)" stroke-width="4"/>
</svg>
"""

# Бутылка зелья в медальоне (по вырезке автора): круглая колба, пробка, бечёвка, красное.
FLASK_BIG = """<svg xmlns="http://www.w3.org/2000/svg" width="80" height="100" viewBox="0 0 80 100">
<defs><linearGradient id="l" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c22a2e"/><stop offset="1" stop-color="#5a0709"/></linearGradient>
<radialGradient id="g" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#d9e4ea" stop-opacity="0.24"/><stop offset="1" stop-color="#7c8a93" stop-opacity="0.08"/></radialGradient></defs>
<rect x="30" y="4" width="20" height="16" rx="3" fill="#7a5638"/><path d="M32 9 H 48 M32 14 H 48" stroke="#4e3522" stroke-width="1"/>
<rect x="32" y="19" width="16" height="22" rx="2" fill="url(#g)" stroke="#c7d2d8" stroke-opacity="0.45" stroke-width="1"/>
<path d="M30 33 H 50" stroke="#6b5440" stroke-width="2.4"/><path d="M32 34 q -12 -2 -10 -12 M48 34 q 12 -2 10 -12" stroke="#6b5440" stroke-width="1.6" fill="none"/>
<path d="M12 64 q 7 -4 14 0 t 14 0 t 14 0 t 14 0 A 28 28 0 0 1 12 64 Z" fill="url(#l)"/>
<path d="M12 64 q 7 -4 14 0 t 14 0 t 14 0 t 14 0" stroke="#e25458" stroke-opacity="0.6" stroke-width="1.2" fill="none"/>
<circle cx="40" cy="66" r="28" fill="url(#g)" stroke="#c7d2d8" stroke-opacity="0.5" stroke-width="1.4"/>
<path d="M22 54 a 21 21 0 0 1 12 -12" stroke="#ffffff" stroke-opacity="0.5" stroke-width="3" stroke-linecap="round" fill="none"/>
<circle cx="55" cy="78" r="2.2" fill="#ffffff" fill-opacity="0.5"/>
</svg>
"""


def bar(width, height, tip):
    """Рама полосы: два рельса с шипами и наконечник копья; середина прозрачная."""
    y0, y1 = 4, height - 4
    mid = height / 2
    end = width - tip
    thorns = []
    for x in range(60, end - 20, 110):
        thorns.append(f'<path d="M{x} {y0} l 5 -4 l 5 4" fill="#3e3a36" stroke="#8a847c" stroke-width="0.8"/>')
        thorns.append(f'<path d="M{x + 50} {y1} l 5 4 l 5 -4" fill="#3e3a36" stroke="#8a847c" stroke-width="0.8"/>')
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<defs>{METAL}{METAL_H}</defs>
<path d="M0 {y0} H {end} M0 {y1} H {end}" stroke="url(#mh)" stroke-width="5"/>
<path d="M0 {y0 + 2.5} H {end} M0 {y1 - 2.5} H {end}" stroke="#0a0908" stroke-width="1"/>
<path d="M2 {y0} V {y1}" stroke="url(#mh)" stroke-width="4"/>
{''.join(thorns)}
<polygon points="{end - 4},{y0 - 4} {end + 22},{mid} {end - 4},{y1 + 4} {end + 4},{mid}" fill="url(#m)" stroke="#9a948b" stroke-width="0.8"/>
<polygon points="{end + 18},{mid - 4} {width},{mid} {end + 18},{mid + 4}" fill="url(#m)"/>
</svg>
"""


# Рамка окна находки (§8.12, референс автора): узорные линии, завитки, ромб-эмблема со звездой.
POPUP = """<svg xmlns="http://www.w3.org/2000/svg" width="900" height="220" viewBox="0 0 900 220">
<defs><linearGradient id="b" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#050608" stop-opacity="0"/><stop offset="0.12" stop-color="#050608" stop-opacity="0.86"/><stop offset="0.88" stop-color="#050608" stop-opacity="0.86"/><stop offset="1" stop-color="#050608" stop-opacity="0"/></linearGradient>
<linearGradient id="e" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2a3038"/><stop offset="1" stop-color="#0c0f13"/></linearGradient></defs>
<rect x="40" y="46" width="820" height="128" fill="url(#b)"/>
<g fill="none" stroke="#a99d8c" stroke-linecap="round">
<path d="M70 46 H 410 M490 46 H 830 M70 174 H 830" stroke-width="1.6"/>
<path d="M120 52 H 780 M120 168 H 780" stroke-width="0.6" stroke-opacity="0.55"/>
<path d="M70 46 q -22 -14 -40 -2 q 14 2 20 12 M70 174 q -22 14 -40 2 q 14 -2 20 -12" stroke-width="1.4"/>
<path d="M830 46 q 22 -14 40 -2 q -14 2 -20 12 M830 174 q 22 14 40 2 q -14 -2 -20 -12" stroke-width="1.4"/>
<path d="M30 110 L 6 110 M30 110 l 18 -26 M30 110 l 18 26 M48 84 l -6 -12 M48 136 l -6 12" stroke-width="1.4"/>
<path d="M870 110 L 894 110 M870 110 l -18 -26 M870 110 l -18 26 M852 84 l 6 -12 M852 136 l 6 12" stroke-width="1.4"/>
<path d="M160 46 l -8 -9 M200 46 l 6 -8 M260 46 l -6 -10 M330 46 l 7 -8 M570 46 l -7 -8 M640 46 l 6 -10 M700 46 l -6 -8 M740 46 l 8 -9" stroke-width="1"/>
<path d="M180 174 l -7 9 M290 174 l 6 10 M380 174 l -6 8 M520 174 l 6 8 M610 174 l -6 10 M720 174 l 7 9" stroke-width="1"/>
<path d="M410 46 q 20 -6 40 -34 q 20 28 40 34" stroke-width="1.4"/>
</g>
<polygon points="450,4 480,36 450,68 420,36" fill="url(#e)" stroke="#a99d8c" stroke-width="1.6"/>
<polygon points="450,16 455,32 468,36 455,40 450,56 445,40 432,36 445,32" fill="#dbeeff"/>
<path d="M450 196 l 10 8 l -10 8 l -10 -8 z" fill="none" stroke="#a99d8c" stroke-width="1.2"/>
<path d="M330 204 H 436 M464 204 H 570" stroke="#a99d8c" stroke-width="0.8" stroke-opacity="0.6"/>
</svg>
"""

# Разделитель для меню осколка.
DIVIDER = """<svg xmlns="http://www.w3.org/2000/svg" width="440" height="16" viewBox="0 0 440 16">
<path d="M0 8 H 206 M234 8 H 440" stroke="#a99d8c" stroke-width="1"/><path d="M220 1 l 7 7 l -7 7 l -7 -7 z" fill="none" stroke="#a99d8c" stroke-width="1.2"/>
</svg>
"""

# Ромб-маркер выбранного пункта меню и точка мастерства.
MARK = """<svg xmlns="http://www.w3.org/2000/svg" width="16" height="22" viewBox="0 0 16 22"><polygon points="8,1 15,11 8,21 1,11" fill="#c9b99c"/></svg>
"""
MARK_EMPTY = """<svg xmlns="http://www.w3.org/2000/svg" width="16" height="22" viewBox="0 0 16 22"><polygon points="8,1.5 14.5,11 8,20.5 1.5,11" fill="none" stroke="#c9b99c" stroke-opacity="0.6" stroke-width="1.4"/></svg>
"""


def button(top, bottom, border, border_alpha):
    """Плашка кнопки в рамке (как «Подтвердить» в макете): вертикальный градиент, тонкая рамка
    и едва заметный блик по верхнему краю. Тянется девятью частями (StyleBoxTexture, поля 3 px)."""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient></defs>
<rect x="0.5" y="0.5" width="63" height="63" fill="url(#g)" stroke="{border}" stroke-opacity="{border_alpha}" stroke-width="1"/>
<path d="M2 2 H 62" stroke="#ffffff" stroke-opacity="0.06" stroke-width="1"/>
</svg>
"""


# Плашка заголовка раздела (как «Характеристики» и «Статус игрока» в Dark Souls): тёмный металл
# с отливом слева, светлая кромка сверху, тёмная снизу, тонкая рамка, ромб у левого края.
SECTION = """<svg xmlns="http://www.w3.org/2000/svg" width="96" height="40" viewBox="0 0 96 40">
<defs><linearGradient id="h" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#3a4250"/><stop offset="0.35" stop-color="#232830"/><stop offset="1" stop-color="#14171c"/></linearGradient>
<linearGradient id="v" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff" stop-opacity="0.10"/><stop offset="0.5" stop-color="#ffffff" stop-opacity="0"/><stop offset="1" stop-color="#000000" stop-opacity="0.35"/></linearGradient></defs>
<rect x="0.5" y="0.5" width="95" height="39" fill="url(#h)" stroke="#5e5a54" stroke-width="1"/>
<rect x="1" y="1" width="94" height="38" fill="url(#v)"/>
<path d="M1 1.5 H 95" stroke="#a39d94" stroke-opacity="0.7" stroke-width="1"/>
<path d="M1 38.5 H 95" stroke="#000000" stroke-opacity="0.6" stroke-width="1"/>
<path d="M10 14 l 6 6 l -6 6 l -6 -6 z" fill="#c9b99c" fill-opacity="0.85"/>
</svg>
"""


def main():
    ICONS.mkdir(parents=True, exist_ok=True)
    HUD.mkdir(parents=True, exist_ok=True)
    for name, (fill, art) in {**ITEMS, **FACETS}.items():
        (ICONS / f"{name}.svg").write_text(icon(fill, art), encoding="utf-8")
    for name, art in CONSUMABLES.items():
        (ICONS / f"{name}.svg").write_text(loose(art), encoding="utf-8")
    files = {"medallion": MEDALLION, "badge": BADGE, "flask": FLASK_BIG, "bar_long": bar(620, 34, 70),
             "bar_short": bar(470, 26, 54), "popup_frame": POPUP, "divider": DIVIDER, "mark": MARK, "mark_empty": MARK_EMPTY,
             "button": button("#1f2329", "#0c0e11", "#8f8a82", 0.9),
             "button_lit": button("#2a2f37", "#12151a", "#e6eaee", 1.0),
             "button_off": button("#15181c", "#0a0b0d", "#8f8a82", 0.35),
             "section": SECTION}
    for name, text in files.items():
        (HUD / f"{name}.svg").write_text(text, encoding="utf-8")
    print("icons:", len(ITEMS) + len(FACETS) + len(CONSUMABLES), "hud:", len(files))


if __name__ == "__main__":
    main()
