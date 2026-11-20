#!/usr/bin/env python3
"""Страница выбора концептов локаций: четыре варианта gen3 на кадр, готовый запрос под каждым, «Беру» и заметка.

Запуск (из корня проекта):
    python -I -X utf8 tools/levels/make_concept_page.py <выход.html> env_crypts_ env_mines_ env_inferno_

Берёт последний прогон каждого ассета из ComfyUI/output/mirror_souls/<ассет>/rNN_meta.json (его пишет gen3),
подписи кадров — из заголовков art/LOCATIONS.md. Под кадром — готовый запрос варианта A, ровно тот текст,
что ушёл в модель: описание со стилем профиля (full_prompt; его же получает C, а B и D — переписанный
улучшателем) — чтобы автор мог сгенерировать кадр у себя. Картинки встраиваются JPEG шириной 1024. Выбор хранит сама страница (артефакт
с capability `db`, коллекция `concepts`, документ на ассет: pick — буква, none, note); Claude читает его оттуда.
"""

import base64
import io
import json
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = Path("D:/AI/ComfyUI_windows_portable/ComfyUI/output/mirror_souls")
WIDTH = 1024


def titles():
    text = (ROOT / "art" / "LOCATIONS.md").read_text(encoding="utf-8")
    return {m.group(2): m.group(1).strip() for m in re.finditer(r"^### (.*?) — `(env_[a-z_]+)`", text, re.M)}


def jpeg(path):
    im = Image.open(path).convert("RGB")
    im = im.resize((WIDTH, round(im.height * WIDTH / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=80, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def main():
    out = Path(sys.argv[1])
    wanted = sys.argv[2:]
    names = titles()
    data = []
    for asset in names:
        if not any(asset.startswith(w) for w in wanted):
            continue
        metas = sorted((OUT_DIR / asset).glob("r*_meta.json"))
        if not metas:
            print(f"{asset}: прогона нет")
            continue
        meta = json.loads(metas[-1].read_text(encoding="utf-8"))
        variants = []
        for letter in "ABCD":
            v = meta["variants"].get(letter)
            if not v:
                continue
            variants.append({"letter": letter, "model": v["model"], "seconds": v.get("seconds"), "src": jpeg(v["file"])})
        data.append({"asset": asset, "title": names[asset], "run": meta["run"], "seed": meta["seed"],
                     "size": meta.get("size"), "style": meta.get("style_profile"), "prompt": meta["full_prompt"],
                     "variants": variants})
        print(f"{asset}: r{meta['run']:02d}, {len(variants)} вар.")
    template = (Path(__file__).parent / "concept_page.html").read_text(encoding="utf-8")
    payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    out.write_text(template.replace("/*DATA*/[]", payload), encoding="utf-8")
    print(f"{out}: {out.stat().st_size // 1024} КБ")


if __name__ == "__main__":
    main()
