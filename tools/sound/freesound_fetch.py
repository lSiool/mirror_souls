#!/usr/bin/env python3
"""Кандидаты звуков с Freesound: поиск по запросам событий, только CC0 и CC-BY, превью mp3.

Запуск:
    python3 -I tools/sound/freesound_fetch.py <выход> [--only=событие,событие] [--n=5]
    python3 -I tools/sound/freesound_fetch.py <выход> --ids="событие:id,id;событие:id"

Ключ — переменная окружения FREESOUND_API_KEY (на Windows, если её нет в процессе, — из
пользовательского окружения в реестре). Превью качаются без OAuth; оригиналы выбранных — потом.
Выход: <выход>/<событие>/<id>.mp3 и candidates.json — id, имя, автор, лицензия, ссылка, длина.
"""

import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://freesound.org/apiv2"
LICENSES = '("Creative Commons 0" OR "Attribution")'
FIELDS = "id,name,username,license,duration,previews,url,avg_rating,num_downloads,tags"

## Событие: (подпись, запросы, длительность от–до, с).
## Freesound ищет все слова запроса сразу — запросы короткие, по нескольку на событие.
EVENTS = {
    "player_jump": ("толчок и выдох", ["jump grunt", "effort breath", "jump exhale", "male effort"], (0.2, 2.0)),
    "sword_swing": ("свист клинка", ["sword whoosh", "sword swing", "blade swoosh"], (0.1, 1.5)),
    "bow_draw": ("скрип тетивы", ["bow draw", "bow string", "bowstring creak"], (0.4, 4.0)),
    "hurt_voice": ("боль: герой и враг", ["male grunt pain", "pain grunt", "hurt male"], (0.1, 1.5)),
    "enemy_death_voice": ("смерть врага", ["death groan male", "death groan", "monster death"], (0.4, 4.0)),
    "room_tone": ("тон комнаты (петля)", ["room tone", "stone hall ambience", "cave ambience"], (10, 120)),
    "mirror_idle": ("гул зеркала (петля)", ["glass drone", "dark drone", "hum drone", "ethereal drone"], (6, 120)),
    "critical_pierce": ("добивание: клинок входит", ["sword stab flesh", "stab flesh", "blade stab", "impale",
                                                      "knife stab"], (0.2, 2.5)),
    # Второй круг: первые (вынимание из ножен, разрыв плоти, хлюпанье) отвергнуты.
    "critical_release": ("добивание: клинок выдернут", ["flesh tear", "gore pull", "sword withdraw",
                                                         "blood splatter", "body impact flesh", "meat slice"],
                         (0.2, 2.0)),
    "bow_release": ("спуск тетивы", ["arrow loose", "bow release", "bow shot"], (0.2, 1.5)),
}


def api_key():
    key = os.environ.get("FREESOUND_API_KEY")
    if not key and sys.platform == "win32":
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as reg:
            key = winreg.QueryValueEx(reg, "FREESOUND_API_KEY")[0]
    if not key:
        sys.exit("нет FREESOUND_API_KEY")
    return key


def search(key, query, dur, size=15):
    params = {"query": query, "filter": f"license:{LICENSES} duration:[{dur[0]} TO {dur[1]}]",
              "fields": FIELDS, "page_size": size, "token": key}
    with urllib.request.urlopen(f"{API}/search/text/?{urllib.parse.urlencode(params)}", timeout=30) as r:
        return json.load(r)["results"]


def sound(key, sound_id):
    params = {"fields": FIELDS, "token": key}
    with urllib.request.urlopen(f"{API}/sounds/{sound_id}/?{urllib.parse.urlencode(params)}", timeout=30) as r:
        return json.load(r)


def short_license(url):
    if "publicdomain/zero" in url:
        return "CC0"
    if "/licenses/by/" in url:
        return "CC-BY " + url.rstrip("/").split("/")[-1]
    return url  # фильтр не должен пропускать другие, но пусть будет видно


def main():
    out = Path(sys.argv[1])
    opts = dict(a[2:].split("=", 1) for a in sys.argv[2:] if a.startswith("--"))
    n = int(opts.get("n", 5))
    key = api_key()
    # --ids=событие:id,id;событие:id — конкретные звуки (соседи из пака выбранного) вместо поиска.
    wanted = {}
    for part in filter(None, opts.get("ids", "").split(";")):
        event, ids = part.split(":")
        wanted[event] = [int(i) for i in ids.split(",")]
    only = opts["only"].split(",") if "only" in opts else list(wanted) or list(EVENTS)
    found = {}
    for event in only:
        if event in wanted:
            found[event] = [sound(key, i) for i in wanted[event]]
            continue
        _label, queries, dur = EVENTS[event]
        # Запросы по очереди: первые результаты каждого, без повторов.
        lists = [search(key, q, dur) for q in queries]
        picked, seen = [], set()
        for rank in range(max(map(len, lists), default=0)):
            for lst in lists:
                if rank < len(lst) and lst[rank]["id"] not in seen and len(picked) < n:
                    seen.add(lst[rank]["id"])
                    picked.append(lst[rank])
        found[event] = picked
    # Остальные события в candidates.json остаются как были.
    index = out / "candidates.json"
    info = json.loads(index.read_text(encoding="utf-8")) if index.exists() else []
    info = [c for c in info if c["event"] not in found]
    for event, picked in found.items():
        label = EVENTS[event][0] if event in EVENTS else event
        for s in picked:
            # Превью: mp3 — для страницы выбора, ogg (выше битрейт) — для банков.
            for kind, ext in (("preview-hq-mp3", "mp3"), ("preview-hq-ogg", "ogg")):
                path = out / event / f"{s['id']}.{ext}"
                path.parent.mkdir(parents=True, exist_ok=True)
                if not path.exists():
                    urllib.request.urlretrieve(s["previews"][kind], path)
            info.append({"event": event, "label": label, "id": s["id"], "name": s["name"],
                         "author": s["username"], "license": short_license(s["license"]),
                         "url": s["url"], "duration": round(s["duration"], 2),
                         "rating": round(s.get("avg_rating") or 0, 1), "downloads": s.get("num_downloads", 0),
                         "file": f"{event}/{s['id']}.mp3"})
            print(f"{event:18} {s['id']:>7}  {s['duration']:6.2f} s  {info[-1]['license']:10} "
                  f"{s['username']}: {s['name']}")
    index.write_text(json.dumps(info, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
