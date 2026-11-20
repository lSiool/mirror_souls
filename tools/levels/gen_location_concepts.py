#!/usr/bin/env python3
"""Концепты локаций из art/LOCATIONS.md через gen3 (ComfyUI, docs/ART_PIPELINE.md): по 4 варианта на кадр.

Запуск (из корня проекта):
    python -I -X utf8 tools/levels/gen_location_concepts.py env_crypts_ env_mines_ env_inferno_
    python -I -X utf8 tools/levels/gen_location_concepts.py env_mines_wheel --dry   # только показать запрос

Аргументы — имена ассетов или их начала. Из блока ```text под заголовком «### … — `env_…`» берутся строки
SCENE и FOCUS: стиль, свет и мир gen3 добавляет сам по профилю env, подстановки {PREFIX}/{WORLD_EARTH}/{AVOID}
и строка OUTPUT (референсов gen3 не подаёт) отбрасываются. Модели работают с CFG 1 и запретов не понимают —
известные отрицания переписываются утвердительно (NEGATIVES). Результат — ComfyUI/output/mirror_souls/<ассет>/rNN_*.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMFY = Path("D:/AI/ComfyUI_windows_portable")
GEN3 = Path("D:/AI/comfy_tools/gen3.py")

## Отрицания из промптов → утвердительно (профиль env сам добавляет туман — катакомбам нужна чистая тьма).
NEGATIVES = {
    "No fog, no grey haze: depth is shown only by fading light.": "Clear black air, depth shown only by fading light.",
    "no foreground, no characters": "an empty plate of scenery",
    "Massive engineering of a poor medieval mine, no gears and no metal machinery, only timber, rope and iron straps.":
        "Massive engineering of a poor medieval mine built only of rough timber, rope and iron straps.",
    "Solid glossy black glass with clean reflections, no red light on the glass.":
        "Solid glossy black glass with clean cold reflections of dim grey light.",
}


def prompts():
    text = (ROOT / "art" / "LOCATIONS.md").read_text(encoding="utf-8")
    found = {}
    for m in re.finditer(r"^### [^\n]*`(env_[a-z_]+)`\s*\n(?:[^\n]*\n)*?```text\n(.*?)```", text, re.M | re.S):
        asset, body = m.group(1), m.group(2)
        lines = []
        for line in body.splitlines():
            line = line.strip()
            if not line or line.startswith("{") or line.startswith("OUTPUT:"):
                continue
            # Заглавная — только в начале SCENE и FOCUS: прочие строки продолжают фразу с переноса.
            if re.match(r"^(SCENE|FOCUS):", line):
                line = re.sub(r"^(SCENE|FOCUS):\s*", "", line)
                line = line[:1].upper() + line[1:]
            lines.append(line)
        prompt = " ".join(lines)
        for old, new in NEGATIVES.items():
            prompt = prompt.replace(old, new)
        found[asset] = prompt
    return found


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry" in sys.argv
    table = prompts()
    assets = [a for a in table if any(a == x or a.startswith(x) for x in args)]
    if not assets:
        sys.exit("нет таких кадров; есть: " + ", ".join(table))
    for i, asset in enumerate(assets, 1):
        print(f"[{i}/{len(assets)}] {asset}: {table[asset][:120]}…", flush=True)
        if dry:
            print(table[asset])
            continue
        run = subprocess.run([str(COMFY / "python_embeded" / "python.exe"), "-I", "-X", "utf8", str(GEN3), asset,
                              table[asset], "--no-open"], capture_output=True, text=True, encoding="utf-8")
        tail = [ln for ln in run.stdout.splitlines() if "·" in ln or "Лист" in ln]
        print("\n".join("    " + ln for ln in tail) or run.stdout[-400:] + run.stderr[-400:], flush=True)


if __name__ == "__main__":
    main()
