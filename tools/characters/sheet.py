"""Склеить снимки героя (user://hero_snapshots) в один лист: python tools/characters/sheet.py idle block bow"""
import sys
from pathlib import Path
from PIL import Image

DIR = Path.home() / "AppData/Roaming/Godot/app_userdata/Осколки/hero_snapshots"
names = sys.argv[1:] or ["idle", "run", "attack_1", "attack_2", "attack_3", "jump_attack", "roll", "block", "bow", "back"]
images = [Image.open(DIR / f"{n}.png") for n in names if (DIR / f"{n}.png").exists()]
w, h = images[0].size
cols = min(4, len(images))
rows = (len(images) + cols - 1) // cols
sheet = Image.new("RGB", (w * cols, h * rows))
for i, im in enumerate(images):
    sheet.paste(im, ((i % cols) * w, (i // cols) * h))
sheet = sheet.resize((w * cols // 2, h * rows // 2))
sheet.save(DIR / "sheet.png")
print(DIR / "sheet.png")
