#!/usr/bin/env python3
"""Кандидаты звуков из паков Kenney (CC0) + модальный синтез как подложка.

Запуск:
    python3 -I tools/sound/make_candidates.py <папка с распакованными паками Kenney> <выход> [--bank <событие>=<кандидат> ...]

Без --bank: по каждому событию рендерит кандидатов A/B/C/D (вариант 0) в <выход>/<событие>_<буква>.wav
и mp3-превью, плюс candidates.json с подписями — из него собирается страница выбора.
С --only=событие,событие: кандидаты только этих событий.
С --bank: для выбранных кандидатов рендерит банк вариантов в <выход>/<группа>/<событие>_NN.wav.

Обработка: моно 44.1 кГц / 16 бит, обрезка тишины, фейды, пик по событию. Нужен ffmpeg в PATH.
"""

import json
import re
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
KENNEY: Path
## Какие файлы Kenney взял последний рендер — для манифеста лицензий.
USED: list = []
## Нарезка присланной записи (--user=<папка с slices.json>), имена в рецептах: "user/slice_08".
USER: Path = Path()
USER_SOURCE = ""
## Автор и лицензия записи — поля "author", "license", "commercial" в slices.json.
USER_AUTHOR = "unknown"
USER_LICENSE = "unconfirmed"
USER_COMMERCIAL = "unconfirmed"
## Превью Freesound (tools/sound/freesound_fetch.py), имена в рецептах: "fs/667292".
FS = Path(__file__).resolve().parents[2] / "audio" / "_source" / "freesound"
_FS_META: dict = {}


# --- Источники и эффекты ----------------------------------------------------

def _ffmpeg(args, data=None):
    proc = subprocess.run(["ffmpeg", "-loglevel", "error", *args], input=data, capture_output=True, check=True)
    return proc.stdout


def src(name, pitch=1.0, lp=None, hp=None, gain=1.0, trim=None, reverse=False):
    """Файл Kenney по имени без расширения. pitch < 1 — ниже и медленнее (тяжелее)."""
    if name.startswith("user/"):
        # Кусок присланной записи (tools/sound/slice_source.py).
        matches = [USER / (name[5:] + ".wav")]
        USED.append(f"{USER_SOURCE}#{name[5:]}")
    elif name.startswith("fs/"):
        matches = list(FS.rglob(name[3:] + ".ogg"))
        if not matches:
            raise FileNotFoundError(name)
        USED.append(name)
    else:
        matches = list(KENNEY.rglob(name + ".ogg"))
        if not matches:
            raise FileNotFoundError(name)
        USED.append(f"{matches[0].parent.parent.name}/{name}.ogg")
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


def fit(x, seconds):
    """Растянуть или сжать по времени без смены высоты (atempo) — под длительность действия."""
    x = finish(x, 0.0)
    return fx(x, f"atempo={len(x) / RATE / seconds:.4f}")


def fs_meta(sound_id):
    """Автор, лицензия и название звука Freesound — из candidates.json."""
    if not _FS_META:
        for c in json.loads((FS / "candidates.json").read_text(encoding="utf-8")):
            _FS_META[str(c["id"])] = c
    return _FS_META[sound_id]


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


## Удары меча из присланной записи: короткие чистые — для серии, с долгим звоном — для завершающего.
SWORD_HITS = [8, 10, 11, 12, 7]
SWORD_FINISHERS = [25, 24, 17, 26, 35]
## Freesound: один исполнитель на событие — банк из соседей по паку.
JUMP_VOICES = [667293, 667292, 667291, 667290, 667297, 667296]  # pekena_larva, VOC_Male_Jump_01–06
BOW_DRAWS = [649332, 649337]  # SonoFxAudio, Bow_draw_fast01–02
ENEMY_HURTS = [632242, 632241]  # AUDACITIER, Male Hurt #1–2
## Натяжение лука в игре (PlayerStats.bow_draw_time): звук кончается вместе с полным натяжением.
BOW_DRAW_TIME = 0.6
## Буквы кандидатов события по порядку рецептов.
LETTERS = "ABCDEFGH"
## Сколько вариантов в банке, если не 5.
BANK_SIZE = {"death_sting": 2, "player_jump_voice": 6, "bow_draw": 4, "enemy_hurt_voice": 4}


def hit(v, pool=SWORD_HITS):
    return f"user/slice_{pool[v % len(pool)]:02d}"


def fin(v):
    return hit(v, SWORD_FINISHERS)


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
    # Голос прыжка — слоем поверх толчка, не на каждый прыжок (Sfx.CHANCE).
    "player_jump_voice": ("player", -10.0, False, [
        ("выдох при толчке (pekena_larva)", lambda v: src(f"fs/{JUMP_VOICES[v % len(JUMP_VOICES)]}")),
    ]),
    "player_hurt": ("player", -6.0, False, [
        ("стон боли (elynch0901)", lambda v: src("fs/464486")),
    ]),
    # Голос при уроне от падения с большой высоты (актёр прыжка, его «приземление»).
    "player_fall_hurt": ("player", -5.0, False, [
        ("VOC_Male_Land_01 (pekena_larva)", lambda v: src("fs/667295")),
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
        # Второй круг: сталь о камень (кирка по камню), без «жестяного» металла.
        ("сталь о камень + отскок", lambda v: mix((src(k("impactMining", v)), 0, 1.0),
                                                  (src(k("impactMining", v + 2), lp=4000), 0.14, 0.4))),
        ("сталь о камень, ниже и глуше", lambda v: mix((src(k("impactMining", v), pitch=0.8, lp=3500), 0, 1.0),
                                                       (src(k("impactMining", v + 1), pitch=0.8, lp=3000), 0.12, 0.35))),
        ("клинок глухо + шорох по камню", lambda v: mix((src(k("impactMetal_light", v), pitch=0.85, lp=3000), 0, 0.9),
                                                        (src(k("footstep_concrete", v), pitch=1.2), 0.03, 0.6),
                                                        (src(k("impactMining", v + 3), pitch=0.9, lp=3000), 0.15, 0.3))),
    ]),
    # --- Меч ---
    "sword_swing": ("combat", -8.0, False, [
        ("свист: шум со свипом (временно, синтез)", lambda v: whoosh(0.3, 450, 1700, seed=v)),
        ("ниже и тяжелее (синтез)", lambda v: whoosh(0.38, 300, 1100, seed=v + 10)),
        ("короткий + шорох одежды", lambda v: mix((whoosh(0.26, 600, 2200, seed=v + 20), 0, 1.0),
                                                  (src(f"cloth{v % 4 + 1}", trim=0.2), 0, 0.35))),
        ("WeaponSwipe01 (Yap Audio)", lambda v: src("fs/219002")),
    ]),
    # Режущие стадии — sword_swing, колющий выпад — свой свист (AttackStep.swing_sound).
    "sword_swing_thrust": ("combat", -8.0, False, [
        ("WeaponSwipe02 (Yap Audio)", lambda v: src("fs/219004")),
    ]),
    "sword_hit_body": ("combat", -3.0, False, [
        # Второй круг: клинок в плоть и кожаный доспех — без «кулака».
        ("плоть + рез ниже + кожа", lambda v: mix((src(k("impactSoft_medium", v)), 0, 1.0),
                                                  (src("knifeSlice2", pitch=0.75), 0, 0.6),
                                                  (src("dropLeather"), 0.01, 0.45))),
        ("тяжело + рубящий, глуше", lambda v: mix((src(k("impactSoft_heavy", v), lp=3000), 0, 1.0),
                                                  (src("chop", pitch=0.8, lp=3500), 0, 0.7))),
        ("рез ниже + рвётся ткань", lambda v: mix((src("knifeSlice", pitch=0.8), 0, 0.8),
                                                  (src(f"cloth{v % 4 + 1}", pitch=1.2, trim=0.2), 0, 0.6),
                                                  (src(k("impactSoft_medium", v), lp=2500), 0.01, 0.7))),
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
    # Удар меча: 1–2 стадия комбо — один звук, выпад (3) — свой, завершающий серию.
    "sword_hit": ("combat", -4.0, False, [
        ("как в записи, чуть темнее", lambda v: src(hit(v), lp=9000)),
        ("ниже на 10 %, темнее", lambda v: src(hit(v), pitch=0.9, lp=7000)),
        ("сталь + тело в доспехе", lambda v: mix((src(hit(v), pitch=0.92, lp=8000), 0, 1.0),
                                                 (src(k("impactSoft_medium", v), lp=2500), 0.0, 0.7))),
        ("короче и суше", lambda v: src(hit(v), pitch=0.95, lp=8000, trim=0.28)),
    ]),
    "sword_hit_finisher": ("combat", -2.0, False, [
        ("долгий звон ниже", lambda v: src(fin(v), pitch=0.85, lp=7000)),
        ("двойной удар внахлёст, толще", lambda v: mix((src(fin(v), pitch=0.88, lp=7500), 0, 1.0),
                                                       (src(fin(v + 1), pitch=0.78, lp=6000), 0.035, 0.6))),
        ("удар + вес тела", lambda v: mix((src(fin(v), pitch=0.88, lp=7500), 0, 1.0),
                                          (src(k("impactPunch_heavy", v), pitch=0.7, lp=1800), 0.0, 0.8),
                                          (src(k("footstep_concrete", v), pitch=0.8, lp=3000), 0.0, 0.5))),
        ("низко, в зале", lambda v: space(src(fin(v), pitch=0.82, lp=6500), size=1.1, wet=0.28)),
    ]),
    "critical_pierce": ("combat", -3.0, False, [
        ("рез + удар", lambda v: mix((src("knifeSlice"), 0, 0.9), (src(k("impactPunch_medium", v)), 0.02, 0.8))),
        ("рубка + мягкий удар", lambda v: mix((src("chop"), 0, 0.9), (src(k("impactSoft_medium", v)), 0.02, 0.8))),
        ("рез ниже + глухой тяжёлый", lambda v: mix((src("knifeSlice2", pitch=0.8), 0, 0.9),
                                                    (src(k("impactPunch_heavy", v), lp=2500), 0.03, 0.9))),
        ("Sword Stab Body Hit (GeorgeDiamond)", lambda v: src("fs/718259")),
    ]),
    "critical_release": ("combat", -2.0, False, [
        ("тяжёлый удар + одежда", lambda v: mix((src(k("impactPunch_heavy", v)), 0, 1.0),
                                                (src(f"cloth{v % 4 + 1}", trim=0.3), 0.02, 0.5))),
        ("выдернул: рез + глухо", lambda v: mix((src("knifeSlice2"), 0, 0.7),
                                                (src(k("impactSoft_heavy", v)), 0.06, 1.0))),
        ("рубка + удар ниже", lambda v: mix((src("chop", pitch=0.85), 0, 0.8),
                                            (src(k("impactPunch_heavy", v), pitch=0.8, lp=2500), 0.04, 1.0))),
        ("Sword stab 4 (ihitokage) + сброшенное тело", lambda v: mix(
            (src("fs/395365", pitch=0.9), 0, 1.0),
            (src(k("impactSoft_heavy", v), pitch=0.85, lp=2500), 0.12, 0.8))),
        ("Hit Impact Sword (CogFireStudios)", lambda v: src("fs/547035")),
    ]),
    # Спуск тетивы — пара к натяжению, тот же автор.
    "bow_release": ("combat", -6.0, False, [
        ("Arrow_loose01 (SonoFxAudio)", lambda v: src("fs/649335")),
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
        # Второй круг: стекло хрустит под ногой.
        ("хруст под ногой + тонкий треск", lambda v: mix((src(k("footstep_snow", v), lp=5000), 0, 0.9),
                                                         (src(k("impactGlass_light", v), pitch=0.8, lp=4500), 0.02, 0.5))),
        ("хруст ниже + треск назад", lambda v: mix((src(k("footstep_snow", v), pitch=0.8, lp=4000), 0, 0.9),
                                                   (src(k("impactGlass_light", v + 1), pitch=0.75, lp=4000, reverse=True), 0.0, 0.4))),
        ("два-три тихих щелчка", lambda v: mix((src(k("impactGlass_light", v), pitch=0.7, lp=3500), 0, 0.6),
                                               (src(k("impactGlass_light", v + 1), pitch=0.65, lp=3000), 0.11, 0.45),
                                               (src(k("impactGlass_light", v + 2), pitch=0.6, lp=3000), 0.19, 0.35))),
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
    "enemy_hurt_voice": ("enemy", -8.0, False, [
        ("Male Hurt #1–2 (AUDACITIER)", lambda v: src(f"fs/{ENEMY_HURTS[v % len(ENEMY_HURTS)]}")),
    ]),
    "enemy_death_voice": ("enemy", -6.0, False, [
        ("monster medium death (Leadstarson)", lambda v: src("fs/559621")),
    ]),
    "enemy_death": ("enemy", -3.0, False, [
        # Второй круг: тело в доспехе падает на камень.
        ("тело на камень + звяк доспеха", lambda v: mix((src(k("impactSoft_heavy", v)), 0, 1.0),
                                                        (src(k("footstep_concrete", v), pitch=0.7, lp=2500), 0.01, 0.7),
                                                        (src("beltHandle2"), 0.04, 0.45))),
        ("тяжело ниже + доспех о камень", lambda v: mix((src(k("impactSoft_heavy", v), pitch=0.8, lp=2200), 0, 1.0),
                                                        (src(k("impactMining", v), pitch=0.7, lp=2500), 0.03, 0.35))),
        ("колени, потом тело", lambda v: mix((src(k("impactSoft_medium", v), pitch=0.85, lp=2500), 0, 0.7),
                                             (src("beltHandle1"), 0.02, 0.3),
                                             (src(k("impactSoft_heavy", v + 1), pitch=0.8), 0.38, 1.0),
                                             (src(k("footstep_concrete", v + 2), pitch=0.7, lp=2000), 0.39, 0.6))),
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
        ("тетива (SonoFxAudio), подогнана под натяжение",
         lambda v: fit(src(f"fs/{BOW_DRAWS[v % len(BOW_DRAWS)]}"), BOW_DRAW_TIME)),
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
    global KENNEY, USER, USER_SOURCE, USER_AUTHOR, USER_LICENSE, USER_COMMERCIAL
    KENNEY = Path(sys.argv[1])
    user = next((a.split("=", 1)[1] for a in sys.argv[3:] if a.startswith("--user=")), None)
    if user:
        USER = Path(user)
        meta = json.loads((USER / "slices.json").read_text(encoding="utf-8"))
        USER_SOURCE = meta["source"]
        USER_AUTHOR = meta.get("author", "unknown")
        USER_LICENSE = meta.get("license", "unconfirmed")
        USER_COMMERCIAL = meta.get("commercial", "unconfirmed")
    out = Path(sys.argv[2])
    picks = dict(arg.split("=") for arg in sys.argv[3:] if "=" in arg and not arg.startswith("--"))
    only = next((a.split("=", 1)[1].split(",") for a in sys.argv[3:] if a.startswith("--only=")), None)
    if picks:
        rows = []
        for event, letter in picks.items():
            group, peak, _, cands = EVENTS[event]
            label, recipe = cands[LETTERS.index(letter)]
            count = BANK_SIZE.get(event, 5)
            for v in range(count):
                USED.clear()
                # Варианты чуть разной высоты — даже если рецепт берёт один и тот же файл.
                spread = 1.0 + (v - (count - 1) / 2) * 0.025
                x = fx(recipe(v), f"asetrate={RATE * spread:.0f},aresample={RATE}")
                name = f"{group}/{event}_{v + 1:02d}.wav"
                save(finish(x, peak), out / name, preview=False)
                # Автор и лицензия по каждому источнику: Kenney, присланная запись, Freesound.
                sources, authors, licenses, commercial = [], [], [], "yes"
                for used in dict.fromkeys(USED):
                    if "#" in used:
                        sources.append(used)
                        authors.append(USER_AUTHOR)
                        licenses.append(USER_LICENSE)
                        if USER_COMMERCIAL != "yes":
                            commercial = USER_COMMERCIAL
                    elif used.startswith("fs/"):
                        meta = fs_meta(used[3:])
                        sources.append(f"freesound.org/s/{meta['id']} ({meta['name']})")
                        authors.append(f"{meta['author']} (Freesound)")
                        licenses.append(meta["license"])
                    else:
                        sources.append(f"Kenney: {used}")
                        authors.append("Kenney (kenney.nl)")
                        licenses.append("CC0")
                joined = " + ".join(sources) or "modal synthesis"
                author = " + ".join(dict.fromkeys(authors)) or "project"
                license_ = " + ".join(dict.fromkeys(licenses)) or "own"
                rows.append(f'sfx/{name},"{joined}","{author}","{license_}",{commercial},"{label}; '
                            f'make_candidates.py {event}={letter}"')
                print(name)
        _update_manifest(out.parent / "_source" / "manifest.csv", picks, rows)
        return
    info = []
    for event, (group, peak, is_seq, cands) in EVENTS.items():
        if only and event not in only:
            continue
        for i, (label, recipe) in enumerate(cands):
            letter = LETTERS[i]
            x = seq(*[finish(recipe(v), peak) for v in range(4)], gap=0.18) if is_seq else finish(recipe(0), peak)
            save(x, out / f"{event}_{letter}.wav")
            info.append({"event": event, "group": group, "letter": letter, "label": label,
                         "duration": round(len(x) / RATE, 2)})
            print(f"{event}_{letter}  {len(x) / RATE:.2f} с  {label}")
    (out / "candidates.json").write_text(json.dumps(info, ensure_ascii=False, indent=1), encoding="utf-8")


def _update_manifest(path, picks, rows):
    """Строки выбранных событий заменяются, остальные остаются."""
    header = "file,source,author,license,commercial,notes"
    old = path.read_text(encoding="utf-8").splitlines()[1:] if path.exists() else []
    # Точное имя банка: sword_swing_NN не задевает sword_swing_thrust_NN.
    keep = [r for r in old if not any(re.search(rf"/{e}_\d\d\.wav$", r.split(",")[0]) for e in picks)]
    path.write_text("\n".join([header, *keep, *rows]) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
