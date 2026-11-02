# Первые три локации — промпты

Перед каждым запросом подставьте блоки из `FIXED_PREFIX.md`. Шаблоны — из `FIXED_ASSETS.md`.
Порядок: сначала утвердите первый кадр каждой локации, затем прикладывайте его как референс к остальным кадрам этой локации.

Замка нет ни в одном кадре деревни и тропы: от деревни его отделяет непроходимый лес, жители знают его только по легендам. Игрок видит замок лишь в образах и попадает в него в конце игры через Главное Зеркало в хабе.

---

## 1. Деревня героя (`env_village_*`)

**Мир:** Земля. **Настроение:** здесь живут и работают, но окна закрывают до заката. Страх входит в быт: обереги над дверями, кол у каждого порога. В бедах от нечисти винят далёкий замок из легенд, которого никто не видел.

### 1.1. Главная улица — `env_village_street`
```text
{PREFIX} {WORLD_EARTH}
SCENE: a poor mountain village street at grey dusk, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
Crooked half-timbered houses with sagging thatched roofs and tall narrow gables lean over a mud road rutted by cart wheels.
Peasants in heavy patched wool carry firewood and buckets, a woman shutters a window, an ox cart stands at a well.
Garlic bundles, iron charms and carved wooden wards hang above every door, sharpened stakes lean against the walls.
Clear walkable ground line in lower third, fence posts and hanging laundry as dark foreground framing,
far background: low hills fading into fog and a dark unbroken wall of forest on the horizon.
FOCUS: warm amber light from an open tavern door as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 1.2. Двор и скот — `env_village_farmyard`
```text
{PREFIX} {WORLD_EARTH}
SCENE: the edge of the same village, a farmyard in cold morning mist, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
A low barn with a roof of black shingles, gaunt cows and muddy sheep behind a crooked wattle fence, chickens in the straw,
a peasant splitting wood, a slaughtered pig hung from a beam, smoke crawling from a chimney along the ground.
Beyond the fence stands a twisted dead tree hung with iron charms, and past it an impenetrable forest begins as a dark wall.
Clear walkable ground line in lower third, far background fades into fog.
FOCUS: the fire under a cauldron in the yard as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 1.3. Часовня и мастерская стекольщика — `env_village_glassworks`
Единственное стекло деревни: так мир сразу знакомит со своей главной поверхностью. Витраж часовни — единственный образ замка в деревне: так жители его себе представляют.
```text
{PREFIX} {WORLD_EARTH}
SCENE: the village square at night, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
A small stone chapel with one narrow dark stained-glass window, its naive picture showing a pale faceted castle above a black forest and tiny kneeling villagers,
beside a glassblower's workshop built of soot-black timber,
panes of greenish hand-blown glass stacked on wooden racks and leaning against the wall, a furnace glowing through the open door,
a craftsman with a blowpipe in silhouette. Cobbles half sunk in mud, walkable ground line in lower third, far background fades into fog.
FOCUS: the orange mouth of the glass furnace as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

---

## 2. Тропа из деревни (`env_trail_*`)

**Мир:** Земля, холоднее и безлюднее деревни. **Настроение:** от леса, где кто-то смотрит, — вверх, к людям, которые опаснее леса.
Четыре кадра — это один непрерывный маршрут снизу вверх. Одним изображением такой маршрут не получить.
Тропа идёт по краю непроходимого леса и к замку не ведёт; в черновике она ведёт к хабу.

### 2.1. Лес — `env_trail_forest`
```text
{PREFIX} {WORLD_EARTH}
SCENE: a narrow trail along the edge of an impenetrable dead forest in thick fog, a tangled wall of trunks and thorns with no way through, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
Huge black trees with twisted, screaming trunks and roots clawing across the path, a roadside wooden shrine with a rotted saint,
crows on a gibbet, deep hoofprints in the mud. Almost monochrome fog-grey, layers of trunks dissolving into white-grey depth.
Clear walkable ground line in lower third, black roots as foreground framing.
FOCUS: a single lantern left burning on the shrine as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 2.2. Мост через реку — `env_trail_bridge`
```text
{PREFIX} {WORLD_EARTH}
SCENE: an old narrow humpbacked stone bridge over a fast black river in a gorge, dusk, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
Broken parapet, rotten timber repairs, a gallows post at the far end, wet boulders and white water far below the deck,
mist rising from the river, cliff walls with hanging roots on both sides.
The bridge deck is the clear walkable line, a lower walkable rock shelf runs under the arch by the water,
far background: the gorge fades into fog.
FOCUS: the pale last light on the water under the arch as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 2.3. Подъём по лестнице — `env_trail_stairs`
```text
{PREFIX} {WORLD_EARTH}
SCENE: an ancient stair cut into a sheer cliff above the river, overcast, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
3 clearly separated walkable levels: a rocky riverbank at the bottom, a landing with a ruined watch post in the middle, the grassy cliff edge at the top,
connected by worn zig-zag stone steps and one rickety wooden ladder section,
every walkable surface lit brighter than the wet cliff behind it, far background fades into fog.
FOCUS: a bandit's torch at the top of the stairs as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 2.4. Верхний уровень: трава и лагерь разбойников — `env_trail_camp`
```text
{PREFIX} {WORLD_EARTH}
SCENE: a windswept high meadow of tall dry grass on the cliff top, evening, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
A bandit camp: patched hide tents, a palisade of sharpened logs, a looted cart, stolen livestock, a cage on a pole, trophies of armour and bones,
gaunt bandits in stolen mismatched armour around a fire. Clear walkable ground line in lower third, grass blown across the foreground,
far background: an enormous valley in fog and the black forest stretching unbroken to the horizon.
FOCUS: the camp bonfire as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

---

## 3. Зеркальный замок (`env_mirrorcastle_*`, `key_mirrorcastle_*`)

**Мир:** Зеркальный, сине-голубой. Прототип локации конца игры; герой попадает сюда только через Главное Зеркало. **Настроение:** это явно замок, и он слишком красив, чтобы быть безопасным. Легенда оказывается правдой: он сложен не то из хрусталя, не то из неведомого стекла.
**Референс:** `art/refs/ref_mirrorcastle_01.webp`. Берём ярусы, рёбра-арки, черепа в основании колонн и линейный орнамент; зелёный заменяем синим, звёздчатые искры не берём. Прикладывайте его только для архитектуры.

### 3.0. Сначала: Главное Зеркало — `prop_mainmirror`
Стоит в хабе, здесь показано до сборки. Парное зеркало опирается на него, поэтому его утверждаем первым.
```text
{PREFIX} {WORLD_MIRROR}
OBJECT: the First Mirror, a colossal gothic standing mirror taller than a cathedral door, frame of tarnished bronze growing into a pointed arch with thorn-like tracery,
the glass shattered, large sections missing, the remaining shards hanging in place in the frame with pale teal light behind them.
3/4 view, isolated, plain flat neutral grey background, soft cold rim light from upper left, no cast shadow.
{AVOID}
```

### 3.1. Тронный зал, парадный кадр — `key_mirrorcastle_throne`
```text
{PREFIX} {WORLD_MIRROR}
SCENE: the throne hall of a mirror castle, cinematic wide 16:9 one-point perspective, a small lone figure in the near corner looks up, monumental scale.
Walls of dark faceted crystal-like glass with cold light deep inside, soaring gothic tiers with ribcage arches and bone tracery drawn in fine ink lines over deep blue washes, towering columns with horned skulls at their bases,
a floor of black polished glass reflecting everything slightly wrong. At the far end a terrifying throne of thorn-like black glass spines curling into an arch,
and above it an immense inhuman statue with folded wings that seems about to breathe.
Behind the throne stands a second colossal mirror: the same pointed bronze frame as the First Mirror but reversed, and whole, without a single crack.
FOCUS: the intact mirror behind the throne as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 3.2. Колоннада, геймплейный кадр — `env_mirrorcastle_colonnade`
```text
{PREFIX} {WORLD_MIRROR}
SCENE: a colossal colonnade inside a mirror castle, deep blue gloom, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
Ceiling lost high in darkness, gothic columns of dark faceted crystal-like glass with bone-like ribs, walls of tall lancet niches, and floor panels of dark glass reflecting the columns slightly out of place.
Along the wall stand mirror portals in bronze frames: each shows the same hall, but different.
Clear walkable ground line in lower third, a broken column as foreground framing, far background fades into blue haze.
FOCUS: the largest mirror portal, glowing pale teal from within, as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 3.3. Галерея статуй — `env_mirrorcastle_statues`
```text
{PREFIX} {WORLD_MIRROR}
SCENE: a long upper gallery of a mirror castle, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
2 clearly separated walkable levels: a stone gallery with a balustrade, and a sloped glass walkway descending to the hall below.
Rows of unknown, monstrous statues, long-limbed and many-jointed creatures of pale stone and glass, unnaturally lifelike, wet-looking,
their heads subtly turned toward the viewer, their reflections in the glass posed differently from the statues themselves.
Every walkable surface lit brighter than the wall behind it, far background fades into blue haze.
FOCUS: a single statue whose reflection is missing, lit from below, as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 3.4. Особый враг: живая статуя — `char_glasssentinel_idle`
```text
{PREFIX} {WORLD_MIRROR}
SUBJECT: full-body game character, a Glass Sentinel, a towering gaunt statue-creature of cracked pale stone with limbs of smoky glass, face smooth and featureless except for a mirror shard where the eyes should be, long blade-like glass forearm.
POSE: neutral side 3/4 view for a 2.5D side-scroller, readable silhouette, whole figure visible.
OUTPUT: centered, plain flat neutral grey background, no shadow on ground, consistent with attached reference images.
{AVOID}
```

### 3.6. Замок снаружи, легенда — `key_mirrorcastle_exterior`
Тот самый вид, от которого стынет кровь. Подходит для сцены легенды или для финала.
```text
{PREFIX} {WORLD_MIRROR}
SCENE: an ancient colossal gothic castle built entirely of dark faceted crystal or some unknown glass-like material, night, cinematic wide 16:9 one-point perspective, seen from far below across an endless black forest, monumental scale.
Spires like enormous shards, flying buttresses like ribs, no windows and no lights, its surfaces reflecting a sky that is not the sky above it, utterly silent and wrong.
FOCUS: a faint cold light deep inside the highest spire as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 3.5. Парное зеркало отдельно — `prop_pairmirror`
Приложите утверждённый `prop_mainmirror`.
```text
{PREFIX} {WORLD_MIRROR}
OBJECT: the twin of the attached First Mirror, identical pointed bronze frame reversed left to right, but the glass whole and flawless, dark and perfectly still, faint cold light deep inside it,
the bronze cleaner and better kept, as if someone has tended it for centuries. 3/4 view, isolated, plain flat neutral grey background, soft cold rim light from upper left, no cast shadow, consistent with attached reference images.
{AVOID}
```
