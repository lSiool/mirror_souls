#!/usr/bin/env python3
"""Нарезка длинной записи с серией звуков (удары, шаги) на отдельные куски.

Запуск:
    python3 -I tools/sound/slice_source.py <запись.wav> <папка кусков> [--threshold=30] [--max=1.6]

Каждый звук — от атаки (−threshold dB от общего пика) до следующей атаки или до max секунд;
хвост обрезается там, где звук тонет в шуме записи. Кусок: моно 44.1 кГц float, без нормализации.
Рядом — slices.json: время в записи, длина, пик, длина хвоста до −40 dB, шумовой пол, яркость.
"""

import json
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
HOP = 441  # 10 мс


def load(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def save(x, path):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def main():
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    opts = dict(a[2:].split("=") for a in sys.argv[3:] if a.startswith("--"))
    threshold = float(opts.get("threshold", 30))
    max_len = float(opts.get("max", 1.6))
    out.mkdir(parents=True, exist_ok=True)
    x = load(src)
    env = np.array([np.abs(x[i:i + HOP]).max() for i in range(0, len(x) - HOP, HOP)])
    db = 20 * np.log10(env + 1e-9)
    peak = db.max()
    # Атака — переход через порог снизу вверх, не чаще чем раз в 0.4 с.
    above = db > peak - threshold
    onsets = []
    for i in range(1, len(above)):
        if above[i] and not above[i - 1] and (not onsets or i - onsets[-1] > 40):
            onsets.append(i)
    info = []
    for n, a in enumerate(onsets):
        b = onsets[n + 1] - 5 if n + 1 < len(onsets) else len(db)
        b = min(b, a + int(max_len * RATE / HOP))
        start = max(0, a - 1)
        seg_db = db[start:b]
        # Шумовой пол — тишина перед атакой (или в конце куска).
        floor = np.percentile(db[max(0, a - 60):max(1, a - 5)], 50) if a > 10 else np.percentile(seg_db, 10)
        local_peak = seg_db.max()
        cut = len(seg_db)
        for k in range(len(seg_db) - 1, 0, -1):
            if seg_db[k] > max(floor + 6, local_peak - 50):
                cut = k + 1
                break
        piece = x[start * HOP:(start + cut) * HOP].copy()
        tail40 = int(np.argmax(seg_db[::-1] > local_peak - 40))
        tail40 = (len(seg_db) - tail40) * HOP / RATE
        spec = np.abs(np.fft.rfft(piece * np.hanning(len(piece))))
        freqs = np.fft.rfftfreq(len(piece), 1 / RATE)
        name = f"slice_{n + 1:02d}.wav"
        save(piece, out / name)
        info.append({"n": n + 1, "file": name, "at": round(start * HOP / RATE, 2),
                     "length": round(len(piece) / RATE, 2), "peak_db": round(float(local_peak), 1),
                     "tail40": round(tail40, 2), "floor_db": round(float(floor), 1),
                     "centroid": int((spec * freqs).sum() / spec.sum())})
        print(f"{name}  at {info[-1]['at']:6.2f}s  len {info[-1]['length']:.2f}  peak {local_peak:6.1f}  "
              f"tail40 {tail40:.2f}  floor {floor:6.1f}  centroid {info[-1]['centroid']}")
    (out / "slices.json").write_text(json.dumps({"source": src.name, "slices": info}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
