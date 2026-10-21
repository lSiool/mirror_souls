#!/usr/bin/env python3
"""Кандидаты звуков из паков Kenney (CC0) + модальный синтез как подложка.

Запуск:
    python3 -I tools/sound/make_candidates.py <папка с распакованными паками Kenney> <выход> [--bank <событие>=<кандидат> ...]

Без --bank: по каждому событию рендерит кандидатов A/B/C/D (вариант 0) в <выход>/<событие>_<буква>.wav
и mp3-превью, плюс candidates.json с подписями — из него собирается страница выбора.
С --bank: для выбранных кандидатов рендерит банк вариантов в <выход>/<группа>/<событие>_NN.wav.

Обработка: моно 44.1 кГц / 16 бит, обрезка тишины, фейды, пик по событию. Нужен ffmpeg в PATH.
"""

import json
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
KENNEY: Path


# --- Источники и эффекты ----------------------------------------------------

def _ffmpeg(args, data=None):
    proc = subprocess.run(["ffmpeg", "-loglevel", "error", *args], input=data, capture_output=True, check=True)
    return proc.stdout


def src(name, pitch=1.0, lp=None, hp=None, gain=1.0, trim=None, reverse=False):
    """Файл Kenney по имени без расширения. pitch < 1 — ниже и медленнее (тяжелее)."""
    matches = list(KENNEY.rglob(name + ".ogg"))
    if not matches:
        raise FileNotFoundError(name)
    chain = [f"asetrate={RATE * pitch:.0f}", f"aresample={RATE}"]
    if trim:
        chain.append(f"atrim=0:{trim}")
    if hp:
        chain.append(f"highpass=f={hp}")
    if lp:
        chain.append(f"lowpass=f={lp}")
    if reverse:
        chain.append("areverse")
    raw = _ffmpeg(["-i", str(matches[0]), "-ac", "1", "-af", ",".join(chain), "-f", "f32le", "-ar", str(RATE), "-"])
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64) * gain


def fx(x, chain):
    """Прогнать сигнал через фильтры ffmpeg."""
    raw = _ffmpeg(["-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-", "-af", chain, "-f", "f32le", "-"],
                  x.astype(np.float32).tobytes())
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def space(x, size=1.0, wet=0.35):
    """Мягкое пространство: каменный зал, хвост без яркого звона."""
    d = [int(40 * size), int(75 * size), int(120 * size), int(190 * size), int(290 * size)]
    decays = [wet, wet * 0.8, wet * 0.6, wet * 0.4, wet * 0.25]
    return fx(x, f"apad=pad_dur={1.2 * size:.2f},aecho=0.8:0.9:{'|'.join(map(str, d))}:"
                 f"{'|'.join(f'{v:.2f}' for v in decays)},lowpass=f=5000")


def modal(base, ratios, gains, decay, damp=0.8, dur=2.0, attack=0.002, seed=0):
    """Сумма затухающих синусоид (как audio/modal/modal_synth.gd), без шума контакта."""
    rng = np.random.default_rng(seed)
    t = np.arange(int(dur * RATE)) / RATE
    out = np.zeros_like(t)
    for r, g in zip(ratios, gains):
        f = base * r * (1.0 + rng.uniform(-0.004, 0.004))
        if f > RATE * 0.45:
            continue
        out += g * np.exp(-decay * r ** damp * t) * np.sin(2 * np.pi * f * t + rng.uniform(0, np.pi))
    n_att = max(1, int(attack * RATE))
    out[:n_att] *= np.linspace(0.0, 1.0, n_att)
    return out


GLASS = ([1.0, 2.32, 4.25, 6.63, 9.38], [1.0, 0.6, 0.4, 0.25, 0.15])
SWORD = ([1.0, 2.756, 5.404, 8.933, 13.344], [1.0, 0.8, 0.6, 0.45, 0.3])


def dark_glass(base=700.0, decay=2.2, dur=2.2, seed=0, lp=2500):
    """Низкое приглушённое стекло: не бокал, а толстая плита."""
    return fx(modal(base, *GLASS, decay=decay, damp=1.0, dur=dur, attack=0.004, seed=seed), f"lowpass=f={lp}")


def whoosh(dur=0.32, low=500, high=1800, seed=0):
    """Свист клинка: шум, полоса уходит снизу вверх, огибающая — подъём и спад."""
    rng = np.random.default_rng(seed)
    n = int(dur * RATE)
    noise = rng.uniform(-1, 1, n)
    a = fx(noise, f"bandpass=f={low}:width_type=o:w=1.2")
    b = fx(noise, f"bandpass=f={high}:width_type=o:w=1.0")
    k = np.linspace(0, 1, n)
    env = np.sin(np.pi * np.clip(k * 1.15, 0, 1)) ** 2
    return (a * (1 - k) + b * k) * env


def mix(*layers):
    """layers: (сигнал, задержка с, громкость)."""
    end = max(int(off * RATE) + len(x) for x, off, _ in layers)
    out = np.zeros(end)
    for x, off, g in layers:
        i = int(off * RATE)
        out[i:i + len(x)] += x * g
    return out


def seq(*items, gap=0.0):
    return np.concatenate([np.concatenate([x, np.zeros(int(gap * RATE))]) for x in items])


def finish(x, peak_db, fade_in=0.003, fade_out=0.03, tail_db=-60.0):
    """Обрезка тишины, фейды, пик в peak_db."""
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    above = np.nonzero(np.abs(x) > peak * 10 ** (-45 / 20))[0]
    tail = np.nonzero(np.abs(x) > peak * 10 ** (tail_db / 20))[0]
    if len(above):
        x = x[max(0, above[0] - int(0.002 * RATE)):tail[-1] + 1]
    n_in, n_out = min(len(x), int(fade_in * RATE)), min(len(x), int(fade_out * RATE))
    x[:n_in] *= np.linspace(0, 1, n_in)
    x[len(x) - n_out:] *= np.linspace(1, 0, n_out)
    return x / (np.max(np.abs(x)) or 1.0) * 10 ** (peak_db / 20)


def save(x, path, preview=True):
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    if preview:
        _ffmpeg(["-y", "-i", str(path), "-b:a", "96k", str(path.with_suffix(".mp3"))])


# --- Рецепты ----------------------------------------------------------------
# Каждый кандидат: (подпись, функция(v) -> сигнал). v — номер варианта для банка (0…4).

def k(name, v, n=5):
    """Имя файла Kenney с номером варианта: impactGlass_heavy → impactGlass_heavy_00v."""
    return f"{name}_{v % n:03d}"


def rpg_step(v):
    return f"footstep{v % 10:02d}"


EVENTS = {
    # --- Герой: только записи ---
    "player_step_floor": ("player", -6.0, True, [
        ("шаг по камню (Impact)", lambda v: src(k("footstep_concrete", v))),
        ("шаг (RPG), сапог", lambda v: src(rpg_step(v))),
        ("шаг по камню ниже и глуше — тяжёлый сапог", lambda v: src(k("footstep_concrete", v), pitch=0.85, lp=4000)),
    ]),
    "player_jump": ("player", -9.0, False, [
        ("шорох одежды", lambda v: src(f"cloth{v % 4 + 1}", trim=0.3)),
        ("ремень и одежда", lambda v: src("clothBelt" if v % 2 == 0 else "clothBelt2", trim=0.35)),
        ("толчок ногой + шорох", lambda v: mix((src(k("footstep_concrete", v), pitch=0.9, lp=3500), 0, 0.8),
                                               (src(f"cloth{v % 4 + 1}", trim=0.3), 0.02, 0.6))),
    ]),
    "player_land": ("player", -5.0, False, [
        ("мягкий удар + шаг", lambda v: mix((src(k("impactSoft_medium", v)), 0, 0.8),
                                            (src(k("footstep_concrete", v)), 0, 0.6))),
        ("тяжёлое приземление, глухо", lambda v: src(k("impactSoft_heavy", v), lp=2500)),
        ("две ноги + одежда", lambda v: mix((src(k("footstep_concrete", v)), 0, 0.8),
                                            (src(k("footstep_concrete", v + 1)), 0.05, 0.7),
                                            (src(f"cloth{v % 4 + 1}", trim=0.25), 0.0, 0.4))),
    ]),
    "player_roll": ("player", -6.0, False, [
        ("шорох + касание пола", lambda v: mix((src(f"cloth{v % 4 + 1}", trim=0.45), 0, 0.8),
                                               (src(k("impactSoft_medium", v), lp=3000), 0.18, 0.6))),
        ("шорох, кожа о пол", lambda v: mix((src(f"cloth{(v + 1) % 4 + 1}", trim=0.45), 0, 0.7),
                                            (src("dropLeather"), 0.15, 0.6))),
        ("ремень + глухой перекат", lambda v: mix((src("clothBelt2", trim=0.4), 0, 0.7),
                                                  (src(k("impactSoft_heavy", v), lp=1800), 0.2, 0.5))),
    ]),
    "player_knee": ("player", -6.0, False, [
        ("колено об пол + одежда", lambda v: mix((src(k("impactSoft_medium", v), lp=2500), 0, 0.9),
                                                 (src(f"cloth{v % 4 + 1}", trim=0.3), 0, 0.5))),
        ("колено + звяк снаряжения", lambda v: mix((src("dropLeather"), 0, 0.8),
                                                   (src("beltHandle1"), 0.03, 0.5))),
        ("глухо и тяжело", lambda v: src(k("impactSoft_heavy", v), pitch=0.85, lp=1800)),
    ]),
    "player_body_fall": ("player", -4.0, False, [
        ("тело о пол + одежда", lambda v: mix((src(k("impactSoft_heavy", v)), 0, 1.0),
                                              (src(f"cloth{v % 4 + 1}", trim=0.35), 0.04, 0.5))),
        ("тяжелее + звяк снаряжения", lambda v: mix((src(k("impactSoft_heavy", v), pitch=0.8, lp=2200), 0, 1.0),
                                                    (src("dropLeather"), 0.03, 0.5),
                                                    (src("beltHandle2"), 0.06, 0.35))),
        ("глухой удар, ниже", lambda v: mix((src(k("impactPunch_heavy", v), pitch=0.7, lp=1500), 0, 1.0),
                                            (src(f"cloth{v % 4 + 1}", trim=0.3), 0.03, 0.4))),
    ]),
    "weapon_drop": ("player", -6.0, False, [
        ("металл о камень + отскок", lambda v: mix((src(k("impactMetal_light", v)), 0, 1.0),
                                                   (src(k("impactMetal_light", v + 2)), 0.13, 0.45))),
        ("пластина, два удара", lambda v: mix((src(k("impactPlate_light", v)), 0, 1.0),
                                              (src(k("impactPlate_light", v + 1)), 0.11, 0.4))),
        ("глуше, тяжёлый клинок", lambda v: mix((src(k("impactMetal_medium", v), lp=4000), 0, 1.0),
                                                (src(k("impactMetal_light", v), lp=3500), 0.15, 0.35))),
    ]),
    # --- Меч ---
    "sword_swing": ("combat", -8.0, False, [
        ("свист: шум со свипом (временно, синтез)", lambda v: whoosh(0.3, 450, 1700, seed=v)),
        ("ниже и тяжелее (синтез)", lambda v: whoosh(0.38, 300, 1100, seed=v + 10)),
        ("короткий + шорох одежды", lambda v: mix((whoosh(0.26, 600, 2200, seed=v + 20), 0, 1.0),
                                                  (src(f"cloth{v % 4 + 1}", trim=0.2), 0, 0.35))),
    ]),
    "sword_hit_body": ("combat", -3.0, False, [
        ("удар + рез", lambda v: mix((src(k("impactPunch_heavy", v)), 0, 1.0), (src("knifeSlice"), 0, 0.6))),
        ("удар средний + рубка", lambda v: mix((src(k("impactPunch_medium", v)), 0, 1.0), (src("chop"), 0, 0.6))),
        ("мягкий тяжёлый + рез", lambda v: mix((src(k("impactSoft_heavy", v)), 0, 1.0),
                                               (src("knifeSlice2"), 0, 0.55))),
    ]),
    "sword_block": ("combat", -4.0, False, [
        ("металл, тяжёлый", lambda v: src(k("impactMetal_heavy", v))),
        ("пластина", lambda v: src(k("impactPlate_heavy", v))),
        ("металл + низкий хвост клинка", lambda v: mix(
            (src(k("impactMetal_heavy", v)), 0, 1.0),
            (fx(modal(430, *SWORD, decay=7, dur=1.0, seed=v), "lowpass=f=3000"), 0, 0.35))),
        ("пластина + котелок", lambda v: mix((src(k("impactPlate_medium", v)), 0, 1.0),
                                             (src(f"metalPot{v % 3 + 1}"), 0, 0.4))),
    ]),
    "sword_parry": ("combat", -2.0, False, [
        ("колокол, обрезан", lambda v: src(k("impactBell_heavy", v), trim=0.9)),
        ("металл + звон колокола", lambda v: mix((src(k("impactMetal_heavy", v)), 0, 1.0),
                                                 (src(k("impactBell_heavy", v), lp=5000, trim=1.0), 0.0, 0.5))),
        ("пластина + звенящий клинок", lambda v: mix(
            (src(k("impactPlate_heavy", v)), 0, 1.0),
            (fx(modal(620, *SWORD, decay=4, dur=1.2, seed=v), "lowpass=f=5000"), 0, 0.45))),
    ]),
    "critical_pierce": ("combat", -3.0, False, [
        ("рез + удар", lambda v: mix((src("knifeSlice"), 0, 0.9), (src(k("impactPunch_medium", v)), 0.02, 0.8))),
        ("рубка + мягкий удар", lambda v: mix((src("chop"), 0, 0.9), (src(k("impactSoft_medium", v)), 0.02, 0.8))),
        ("рез ниже + глухой тяжёлый", lambda v: mix((src("knifeSlice2", pitch=0.8), 0, 0.9),
                                                    (src(k("impactPunch_heavy", v), lp=2500), 0.03, 0.9))),
    ]),
    "critical_release": ("combat", -2.0, False, [
        ("тяжёлый удар + одежда", lambda v: mix((src(k("impactPunch_heavy", v)), 0, 1.0),
                                                (src(f"cloth{v % 4 + 1}", trim=0.3), 0.02, 0.5))),
        ("выдернул: рез + глухо", lambda v: mix((src("knifeSlice2"), 0, 0.7),
                                                (src(k("impactSoft_heavy", v)), 0.06, 1.0))),
        ("рубка + удар ниже", lambda v: mix((src("chop", pitch=0.85), 0, 0.8),
                                            (src(k("impactPunch_heavy", v), pitch=0.8, lp=2500), 0.04, 1.0))),
    ]),
    # --- Стекло: мрачнее, ниже, без «бокала» ---
    "glass_break": ("glass", -2.0, False, [
        ("тяжёлое стекло ниже + осыпь", lambda v: mix(
            (src(k("impactGlass_heavy", v), pitch=0.8, lp=6000), 0, 1.0),
            (src(k("impactGlass_light", v + 1), pitch=0.75, lp=5000), 0.09, 0.4),
            (src(k("impactGlass_light", v + 2), pitch=0.7, lp=4500), 0.21, 0.3),
            (src(k("impactGlass_medium", v + 3), pitch=0.7, lp=4000), 0.36, 0.22))),
        ("то же + низкий гул плиты", lambda v: mix(
            (src(k("impactGlass_heavy", v), pitch=0.8, lp=6000), 0, 1.0),
            (src(k("impactGlass_light", v + 1), pitch=0.75, lp=5000), 0.1, 0.35),
            (src(k("impactGlass_light", v + 3), pitch=0.7, lp=4000), 0.27, 0.25),
            (dark_glass(520, decay=2.5, dur=2.0, seed=v), 0, 0.35))),
        ("очень низко, в зале", lambda v: space(mix(
            (src(k("impactGlass_heavy", v), pitch=0.6, lp=4000), 0, 1.0),
            (src(k("impactGlass_medium", v + 2), pitch=0.6, lp=3500), 0.12, 0.4)), size=1.2, wet=0.3)),
    ]),
    "sword_hit_glass": ("combat", -3.0, False, [
        ("стекло + металл клинка", lambda v: mix((src(k("impactGlass_medium", v), pitch=0.85, lp=6000), 0, 1.0),
                                                 (src(k("impactMetal_light", v)), 0, 0.5))),
        ("тяжёлое стекло ниже, глуше", lambda v: src(k("impactGlass_heavy", v), pitch=0.8, lp=4500)),
        ("стекло + низкий хвост", lambda v: mix((src(k("impactGlass_light", v), pitch=0.85), 0, 0.9),
                                                (dark_glass(640, decay=3, dur=1.4, seed=v), 0, 0.5))),
    ]),
    "glass_crack": ("glass", -10.0, False, [
        ("тихий треск ниже", lambda v: src(k("impactGlass_light", v), pitch=0.7, lp=3500)),
        ("скрип + треск", lambda v: mix((src(f"creak{v % 3 + 1}", pitch=1.3, trim=0.5), 0, 0.6),
                                        (src(k("impactGlass_light", v), pitch=0.8, lp=4000), 0.05, 0.8))),
        ("короткий хруст (реверс)", lambda v: mix((src(k("impactGlass_light", v), pitch=0.9, lp=4000, reverse=True), 0, 0.6),
                                                  (src(k("impactGlass_light", v + 1), pitch=0.75, lp=3500), 0.18, 0.8))),
    ]),
    "arrow_ricochet_glass": ("combat", -6.0, False, [
        ("лёгкое стекло", lambda v: src(k("impactGlass_light", v))),
        ("стекло + металл наконечника", lambda v: mix((src(k("impactGlass_light", v)), 0, 1.0),
                                                      (src(k("impactMetal_light", v), pitch=1.2), 0, 0.4))),
        ("ниже + хвост", lambda v: mix((src(k("impactGlass_light", v), pitch=0.8, lp=5000), 0, 1.0),
                                       (dark_glass(900, decay=4, dur=1.0, seed=v), 0, 0.35))),
    ]),
    # --- Враг ---
    "enemy_hurt": ("enemy", -4.0, False, [
        ("удар по телу", lambda v: src(k("impactPunch_medium", v))),
        ("удар + звяк брони", lambda v: mix((src(k("impactPunch_heavy", v)), 0, 1.0),
                                            (src(k("impactPlate_light", v)), 0, 0.4))),
        ("мягкий + щелчок металла", lambda v: mix((src(k("impactSoft_medium", v)), 0, 1.0),
                                                  (src("metalClick"), 0.01, 0.3))),
    ]),
    "enemy_death": ("enemy", -3.0, False, [
        ("падение в броне", lambda v: mix((src(k("impactSoft_heavy", v)), 0, 1.0),
                                          (src(k("impactPlate_heavy", v), lp=4000), 0.03, 0.5))),
        ("два глухих удара", lambda v: mix((src(k("impactSoft_heavy", v)), 0, 1.0),
                                           (src(k("impactSoft_heavy", v + 2), pitch=0.85), 0.22, 0.7))),
        ("тяжело + снаряжение", lambda v: mix((src(k("impactPunch_heavy", v), pitch=0.75, lp=2000), 0, 1.0),
                                              (src("beltHandle1"), 0.05, 0.4))),
    ]),
    # --- Мир ---
    "arrow_hit_wood": ("combat", -4.0, False, [
        ("дерево", lambda v: src(k("impactWood_medium", v))),
        ("доска", lambda v: src(k("impactPlank_medium", v))),
        ("дерево тяжёлое, коротко", lambda v: src(k("impactWood_heavy", v), trim=0.25)),
    ]),
    "bow_draw": ("combat", -9.0, False, [
        ("скрип дерева", lambda v: src("creak1")),
        ("скрип выше, туже", lambda v: src("creak2", pitch=1.2)),
        ("скрип медленный", lambda v: src("creak3", pitch=0.85)),
    ]),
    "chest_open": ("world", -5.0, False, [
        ("скрип крышки + защёлка", lambda v: mix((src("metalLatch"), 0, 0.8), (src("doorOpen_1"), 0.08, 1.0))),
        ("скрип + щелчок", lambda v: mix((src("metalClick"), 0, 0.7), (src("creak1", pitch=0.9), 0.06, 1.0))),
        ("тяжёлая крышка", lambda v: src("doorOpen_2", pitch=0.85)),
    ]),
    "chest_loot": ("world", -6.0, False, [
        ("монеты", lambda v: src("handleCoins")),
        ("монеты, другие", lambda v: src("handleCoins2")),
        ("осколки-блики", lambda v: mix((src(k("impactGlass_light", v), pitch=1.3), 0, 0.8),
                                        (src(k("impactGlass_light", v + 1), pitch=1.5), 0.09, 0.6),
                                        (src(k("impactGlass_light", v + 2), pitch=1.7), 0.2, 0.45))),
    ]),
    # --- Смерть: приглушённое томное стекло под надписью ---
    "death_sting": ("ui", -6.0, False, [
        ("низкая стеклянная чаша, мягкая атака", lambda v: space(
            dark_glass(310, decay=1.1, dur=3.5, seed=v, lp=1600), size=1.4, wet=0.3)),
        ("колокол на октаву ниже, глухо", lambda v: space(
            src(k("impactBell_heavy", v), pitch=0.5, lp=1400), size=1.5, wet=0.35)),
        ("тяжёлое стекло совсем низко + гул", lambda v: space(mix(
            (src(k("impactGlass_heavy", v), pitch=0.45, lp=1800), 0, 0.8),
            (dark_glass(260, decay=0.9, dur=3.5, seed=v, lp=1200), 0.0, 0.7)), size=1.5, wet=0.3)),
        ("нарастание из тишины → глухой тон", lambda v: space(mix(
            (fx(dark_glass(330, decay=1.5, dur=1.2, seed=v + 5, lp=1400), "areverse"), 0, 0.5),
            (dark_glass(330, decay=1.0, dur=3.5, seed=v, lp=1500), 1.15, 1.0)), size=1.3, wet=0.25)),
    ]),
}


def main():
    global KENNEY
    KENNEY = Path(sys.argv[1])
    out = Path(sys.argv[2])
    picks = dict(arg.split("=") for arg in sys.argv[3:] if "=" in arg)
    if picks:
        for event, letter in picks.items():
            group, peak, _, cands = EVENTS[event]
            _, recipe = cands["ABCD".index(letter)]
            for v in range(5 if event != "death_sting" else 2):
                save(finish(recipe(v), peak), out / group / f"{event}_{v + 1:02d}.wav", preview=False)
                print(f"{group}/{event}_{v + 1:02d}.wav")
        return
    info = []
    for event, (group, peak, is_seq, cands) in EVENTS.items():
        for i, (label, recipe) in enumerate(cands):
            letter = "ABCD"[i]
            x = seq(*[finish(recipe(v), peak) for v in range(4)], gap=0.18) if is_seq else finish(recipe(0), peak)
            save(x, out / f"{event}_{letter}.wav")
            info.append({"event": event, "group": group, "letter": letter, "label": label,
                         "duration": round(len(x) / RATE, 2)})
            print(f"{event}_{letter}  {len(x) / RATE:.2f} с  {label}")
    (out / "candidates.json").write_text(json.dumps(info, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
