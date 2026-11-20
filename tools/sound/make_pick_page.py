#!/usr/bin/env python3
"""Страница выбора звуков из кандидатов Freesound: плееры, «Беру» и заметка по каждому событию.

Запуск:
    python -I -X utf8 tools/sound/make_pick_page.py <выход.html> событие,событие,...

Берёт кандидатов из audio/_source/freesound/candidates.json (их качает freesound_fetch.py), подписи событий —
из таблицы docs/SOUND_PLAN.md. Превью встраиваются в страницу: первые 5 с, моно, mp3 96 кбит/с (нужен ffmpeg —
в PATH или в D:/Downloads/ffmpeg). Выбор хранит сама страница (артефакт с capability `db`, коллекция `picks`,
документ на событие: picks — id звуков, none — ничего не подошло, note — заметка); Claude читает его оттуда.
"""

import base64
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FS = ROOT / "audio" / "_source" / "freesound"
PLAN = ROOT / "docs" / "SOUND_PLAN.md"
CLIP_SECONDS = 5


def ffmpeg():
    found = shutil.which("ffmpeg")
    if found:
        return found
    for exe in Path("D:/Downloads/ffmpeg").rglob("ffmpeg.exe"):
        return str(exe)
    sys.exit("нет ffmpeg")


def plan_rows():
    """`событие` (где звучит) | вар. | длит. | приоритет | как получаем — из таблицы плана звуков."""
    rows = {}
    for line in PLAN.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\|\s*`([a-z_]+)`\s*(?:\(([^)]*)\))?\s*\|\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|", line)
        if m:
            rows[m.group(1)] = {"where": (m.group(2) or "").strip(), "variants": m.group(3).strip(),
                                "length": m.group(4).strip(), "how": m.group(6).strip()}
    return rows


def clip(exe, path):
    out = subprocess.run([exe, "-loglevel", "error", "-i", str(path), "-t", str(CLIP_SECONDS), "-ac", "1",
                          "-b:a", "96k", "-f", "mp3", "-"], capture_output=True, check=True).stdout
    return "data:audio/mpeg;base64," + base64.b64encode(out).decode("ascii")


def main():
    out = Path(sys.argv[1])
    events = sys.argv[2].split(",")
    exe = ffmpeg()
    info = json.loads((FS / "candidates.json").read_text(encoding="utf-8"))
    rows = plan_rows()
    data = []
    for event in events:
        cands = [c for c in info if c["event"] == event]
        if not cands:
            sys.exit(f"нет кандидатов: {event}")
        row = rows.get(event, {})
        data.append({
            "event": event, "label": cands[0]["label"], "where": row.get("where", ""),
            "length": row.get("length", ""), "variants": row.get("variants", ""), "how": row.get("how", ""),
            "cands": [{"id": c["id"], "name": c["name"], "author": c["author"], "license": c["license"],
                       "url": c["url"], "duration": c["duration"], "src": clip(exe, FS / c["file"])}
                      for c in cands],
        })
        print(f"{event}: {len(cands)}")
    template = (Path(__file__).parent / "pick_page.html").read_text(encoding="utf-8")
    payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    out.write_text(template.replace("/*DATA*/[]", payload), encoding="utf-8")
    print(f"{out}: {out.stat().st_size // 1024} КБ")


if __name__ == "__main__":
    main()
