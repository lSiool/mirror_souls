#!/usr/bin/env python3
"""Бесшовная петля из длинной записи (гул, фон): кусок нужной длины, хвост сведён в начало.

Запуск:
    python3 -I tools/sound/make_loop.py <запись> <выход.ogg> [--start=2] [--length=20] [--xfade=2.5] [--peak=-12]
        [--channels=1]

Берётся отрезок [start, start + length + xfade). Последние xfade секунд плавно (равная мощность)
накладываются на первые — на стыке петли нет щелчка и скачка громкости. По умолчанию моно
(петлю ставят в мир источником AudioStreamPlayer3D); музыке — --channels=2. 44.1 кГц, OGG Vorbis.
--length=0 — до конца записи. Нужен ffmpeg в PATH.
"""

import subprocess
import sys
from pathlib import Path

import numpy as np

RATE = 44100


def load(path, channels):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-ac", str(channels), "-ar", str(RATE),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64).reshape(-1, channels)


def main():
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    opts = {k: float(v) for k, v in (a[2:].split("=") for a in sys.argv[3:] if a.startswith("--"))}
    start, length = opts.get("start", 2.0), opts.get("length", 20.0)
    xfade, peak_db = opts.get("xfade", 2.5), opts.get("peak", -12.0)
    channels = int(opts.get("channels", 1))
    x = load(src, channels)
    a, c = int(start * RATE), int(xfade * RATE)
    n = int(length * RATE) if length > 0 else len(x) - a - c
    if a + n + c > len(x):
        sys.exit(f"запись короче {start + length + xfade:.1f} с")
    seg = x[a:a + n + c].copy()
    t = np.linspace(0.0, np.pi / 2, c)[:, None]
    # Хвост (после length) уходит, начало появляется: на стыке звучит то же, что в конце.
    seg[:c] = seg[:c] * np.sin(t) + seg[n:n + c] * np.cos(t)
    loop = seg[:n]
    loop *= 10 ** (peak_db / 20) / (np.max(np.abs(loop)) or 1.0)
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", str(channels),
                    "-i", "-", "-c:a", "libvorbis", "-q:a", "5", str(out)],
                   input=loop.astype(np.float32).tobytes(), check=True)
    print(f"{out}: {n / RATE:.1f} с, стык сведён за {xfade:.1f} с")


if __name__ == "__main__":
    main()
