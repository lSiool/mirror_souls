"""Заглушки звуков первой сцены (§9.2), пока не выбраны настоящие: сердце и треск огня.

Запуск из корня проекта: python tools/sound/synth_placeholders.py
Сердце — wav в банке Sfx; треск — петля ogg (нужен ffmpeg в PATH или в аргументе).
"""
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100


def write_wav(path: Path, samples: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(samples, -1.0, 1.0) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())


def thump(freq: float, length: float, gain: float) -> np.ndarray:
    t = np.arange(int(length * RATE)) / RATE
    glide = freq * (1.0 + 0.8 * np.exp(-t * 40.0))
    phase = 2.0 * np.pi * np.cumsum(glide) / RATE
    attack = np.minimum(t / 0.006, 1.0)
    return gain * attack * np.exp(-t * 16.0) * np.sin(phase)


def heartbeat(pitch: float = 1.0, gap: float = 0.24) -> np.ndarray:
    """Глухое «тук-тук»: удар и второй, потише."""
    out = np.zeros(int(0.62 * RATE))
    first = thump(58.0 * pitch, 0.26, 0.95)
    second = thump(46.0 * pitch, 0.3, 0.7)
    out[: first.size] += first
    start = int(gap * RATE)
    out[start: start + second.size] += second
    return out


def crackle(rng: np.random.Generator) -> np.ndarray:
    """Треск огня: низкий гул и случайные щелчки. Петля без шва: щелчки заворачиваются."""
    length = 8.0
    size = int(length * RATE)
    rumble = np.convolve(rng.normal(0.0, 1.0, size + 2000), np.ones(600) / 600.0, mode="same")[1000:1000 + size]
    rumble = 0.5 * rumble / np.max(np.abs(rumble))
    fade = int(0.5 * RATE)
    blend = np.linspace(0.0, 1.0, fade)
    rumble[:fade] = rumble[:fade] * blend + rumble[-fade:] * (1.0 - blend)
    out = rumble
    for _ in range(int(length * 14)):
        at = rng.integers(0, size)
        n = int(rng.uniform(0.002, 0.018) * RATE)
        click = rng.normal(0.0, 1.0, n) * np.exp(-np.arange(n) / (n * 0.25)) * rng.uniform(0.05, 0.5)
        idx = (at + np.arange(n)) % size
        out[idx] += click
    return 0.8 * out


def main() -> None:
    ffmpeg = sys.argv[1] if len(sys.argv) > 1 else "ffmpeg"
    rng = np.random.default_rng(1)
    for i, (pitch, gap) in enumerate(((1.0, 0.24), (0.96, 0.25), (1.04, 0.23))):
        write_wav(Path(f"audio/sfx/player/heartbeat_{i + 1:02d}.wav"), heartbeat(pitch, gap))
    temp = Path("audio/loops/_fire_crackle.wav")
    write_wav(temp, crackle(rng))
    subprocess.run([ffmpeg, "-v", "error", "-y", "-i", str(temp), "-c:a", "libvorbis", "-q:a", "3",
                    "audio/loops/fire_crackle.ogg"], check=True)
    temp.unlink()


if __name__ == "__main__":
    main()
