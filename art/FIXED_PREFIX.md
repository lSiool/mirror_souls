Стиль v0.3 (`STYLE_BIBLE.md`). Два способа подставлять его в запрос.

## 1. Локально, gen3 (основной путь, `docs/ART_PIPELINE.md`)
gen3 сам добавляет к описанию `styles\common.txt` + профиль по префиксу имени ассета (`D:\AI\comfy_tools\styles\`):
`env_`/`key_` → `env`, `prop_` → `prop`, `char_` → `char`, `icon_` → `icon`; Зеркальный мир — `--style env_mirror`.
В описании пишем только сам предмет или сцену: стиль, свет и фон уже в профиле.
Негативов нет: FLUX 3 и Z-Image идут с CFG 1, поле negative не работает. Запреты пишем положительно (§11 библии).

Тексты профилей (держать в синхроне с файлами):
- **common:** Dark gothic fantasy, painterly hand-painted digital art with visible brushstrokes and expressive weathered materials, semi-realistic proportions, grim melancholic fairy-tale mood of an ancient world.
- **env** (Земля): Cold blue-grey ambient light and drifting fog, warm amber light only from fires, lanterns and windows, cold rim light on silhouettes, low-key dramatic contrast, desaturated palette of soot, peat brown and wet ash, deep atmospheric haze in the distance.
- **env_mirror:** Light coming from the glass itself, palette of abyssal indigo, deep cobalt and ice blue with mercury-silver and pale teal accents, almost no warm light, cold polished emptiness, deep blue haze in the distance.
- **prop:** Game asset concept for a 3D model: one single object, whole and centered, three-quarter view, hand-painted texture with painted grime and wear, matte surfaces, soft even neutral studio lighting from all sides, plain flat light-grey background.
- **char:** Game character concept for a 3D model: full body from head to feet, front view, standing in a relaxed A-pose with arms held slightly away from the body, hand-painted texture with painted grime and wear, matte surfaces, soft even neutral studio lighting from all sides, plain flat light-grey background.
- **icon:** Game UI icon: one bold silhouette centered on a square canvas, readable at small size, dark vignette circle behind it, flat grey outside the circle, minimal detail.

## 2. Внешние генераторы (с полем negative и приложенными референсами)
В запрос идут: {PREFIX} + один {WORLD} + шаблон из FIXED_ASSETS.md. AVOID вынесен отдельно: если у генератора есть поле negative, вставляйте туда без слова AVOID.
Для предметов и персонажей под 3D свет в шаблоне — ровный нейтральный, без rim light (§12 библии).

### {PREFIX}
STYLE: dark gothic fantasy painterly 2.5D game art, hand-painted digital oil texture with visible brushstrokes,
thin dark-umber outlines, semi-realistic anatomically plausible characters, gothic elongated proportions,
low-key dramatic lighting with cold rim light, dense atmospheric haze, grim melancholic fairy tale of an ancient world.

### {WORLD_EARTH}
WORLD: desaturated palette of soot, peat brown, wet ash and grey-blue fog, weathered black oak and moss,
warm amber light only from fires, lanterns and windows, mud, straw and smoke, lived-in and organic.

### {WORLD_MIRROR}
WORLD: palette of abyssal indigo, deep cobalt and ice blue with mercury-silver and pale teal accents,
light coming from the glass itself, almost no warm light, cold polished emptiness,
motif of broken mirrors, fractured reflections and floating glass shards.

### {AVOID}
AVOID: photorealism, anime, chibi, cute or comedic cartoon look, plastic 3D render, neon colors,
star-shaped sparkles, lens flare, text, watermark, extra limbs.
