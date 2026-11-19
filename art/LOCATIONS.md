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

---

## 4. Поля (`env_fields_*`, §8.13)

**Мир:** Земля, за околицей деревни. **Настроение:** поле, где никто не жнёт. Рожь стоит перезрелая, подсолнухи сгнили на корню, люди обходят холм со столбом. Днём в поле не ходят: в полдень во ржи бродит Полудница.
Свет по кадрам — как в игре: двор утром в тумане (кадр 1.2 `env_village_farmyard` — вход в Поля), рожь и холм в выцветший пыльный полдень, низина и мельница в сумерках.
Сначала утвердите 4.1. Он задаёт палитру полдня; остальные кадры делаются с ним как с референсом. Из утверждённых кадров потом генерируются ассеты: копна, тыква-фонарь, столб, ветряк, колесо.

### 4.0. Дальний план биома — `env_fields_farplane`
Слой параллакса за всеми комнатами Полей. Без героя и тропы.
```text
{PREFIX} {WORLD_EARTH}
SCENE: an endless over-ripe rye field rolling in low waves to the horizon under a bleached, dusty noon sky, wide 16:9 panoramic background plate for parallax, no foreground, no characters.
Rows of sheaf stooks and black dead sunflowers fade into heat haze, a lone windmill on a far hill, a few dead trees;
on the left horizon black jagged mountains rise close, and high between two crags hang the broken remains of a stone bridge with chains dangling into the void.
Atmospheric perspective, contrast falls off with distance, haze the colour of dust and old straw.
FOCUS: the pale veiled disc of the sun as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 4.1. Ржаное поле в полдень — `env_fields_rye`
```text
{PREFIX} {WORLD_EARTH}
SCENE: a chest-high rye field at noon, the air bleached and shimmering with heat and dust, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
A trampled path runs through the rye, the stalks lean against the wind in a long wave as if something unseen is walking through them,
a wooden roadside cross with a tiny roof and an icon lamp, a scythe stuck blade-down in the earth with a rag tied to it, a crow watchtower on stilts above the field,
a gully crossed by rickety planks. Colours of old straw, dust and dry earth, no green.
Clear walkable ground line in lower third, dark rye ears as foreground silhouettes.
FOCUS: the small flame of the icon lamp on the roadside cross as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 4.2. Холм со столбом казни — `env_fields_post` (два состояния)
Сначала пустой столб; второй вариант — тот же кадр с Пугалом на столбе (приложите первый как референс).
```text
{PREFIX} {WORLD_EARTH}
SCENE: a bare hilltop above a dead sunflower field at noon, a lone execution post with a crossbar in the middle, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
Frayed cut ropes hang from the crossbar, the wood worn smooth where someone hung for a long time, crows on the beam, a ring of stones and dark stained earth at its foot;
hundreds of black dead sunflowers on the slopes all turn their heavy heads toward the post. A dead tree and a broken stone fence on the crest.
Clear flat walkable hilltop in lower third, sunflower stems as dark foreground framing.
FOCUS: the empty post against the bleached sky as the brightest contrast of the image.
VARIANT B: the same scene, but on the post hangs a tall scarecrow in a ragged coat with a sack head and a wide hat, straw spilling from its sleeves, a heavy iron hook on a chain hanging from its belt, and the sunflowers now turn toward the viewer.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 4.3. Мельница и запруда — `env_fields_mill`
```text
{PREFIX} {WORLD_EARTH}
SCENE: dusk at the edge of the fields, a tall wooden windmill with a stone base on a hill, its torn canvas sails turning slowly, a balcony around the tower;
below, a water mill with a big wheel by a brook, and behind it an old stone dam holding back a dark millpond higher than the road, water spilling over the sluice,
wide 16:9 side-view composition for a 2.5D platformer with two levels: the hilltop and the brook below, connected by ladders down a rocky shelf.
On the far left, black mountains and an old road cut into the cliff, leading up toward a collapsed bridge.
FOCUS: the warm open door of the windmill as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 4.4. Огороды — `env_fields_garden`
```text
{PREFIX} {WORLD_EARTH}
SCENE: terraced kitchen gardens in a hollow below a hill at dusk, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
Beds of pumpkins and turnips stepping up in low terraces held by wattle, carved pumpkin lanterns glowing along the path — the only light,
straw dolls on stakes among the beds, a gardener's shed, an open cellar hatch with its lid propped up, a big dark threshing barn with light leaking between its doors,
a brook coming out of a stone culvert under the hill; on the hilltop above, the silhouette of a lone post.
Clear walkable ground line in lower third, pumpkins and wattle as foreground framing.
FOCUS: the face of the nearest carved pumpkin lantern as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 4.5. Гумно изнутри — `env_fields_barn`
```text
{PREFIX} {WORLD_EARTH}
SCENE: inside a huge dark threshing barn, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
A beaten clay threshing floor, sheaves stacked against the walls, flails hanging on pegs, grain bins, a winnowing basket,
a hayloft reached by a ladder, rough beams under the roof, thin shafts of dusty light falling through gaps in the roof.
FOCUS: a lantern hanging from a beam as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

---

## 5. Подвесной перевал и Пепельные Пики (`env_pass_*`, `env_peaks_*`, §8.13)

**Мир:** Земля, высоко над Полями. **Настроение:** дорога, которую бросили. Мост держали цепи — цепи держат до сих пор, а камень нет. За перевалом горы, где третью ночь красное небо: там лежит что-то огромное и дышит.

### 5.1. Подвесной перевал — `env_pass_bridge`
```text
{PREFIX} {WORLD_EARTH}
SCENE: a ruined stone causeway high above a misty chasm, cold blue-grey twilight, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
The first span stands whole, then the bridge breaks off: a gap with an iron ring hanging on a chain between two broken towers,
a pier with the ruins of a gatehouse and one surviving arch over the next gap with another ring on a chain, a rusted cage swinging on a beam,
needle-like rock pinnacles rising from the fog below, black snowy mountains behind; far below in the east, tiny fields and a windmill.
Broken parapet stones and old ropes along the near edge of the bridge as foreground, nothing but fog under the spans.
FOCUS: a lantern at the start of the bridge as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 5.2. Пепельные Пики, хребет дракона — `env_peaks_spine`
```text
{PREFIX} {WORLD_EARTH}
SCENE: black volcanic mountains under falling ash, a dull red glow behind the ridge, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
A scorched slope with burnt trees, a burnt-out stone watchtower with a charred wooden top, and beyond it the colossal spine of a dead dragon
lying across a chasm as a bridge, its ribs arching over the path like a cathedral nave; on the far terrace the dragon's skull with open jaws,
a faint ember glow deep in its eye sockets. Snow only on the highest peaks, grey with ash.
Clear walkable line along the spine, bone fragments and rocks as dark foreground.
FOCUS: the ember glow in the skull's eye socket as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

---

## 6. Катакомбы кладбища (`env_crypts_*`, §8.13)

**Мир:** Земля, под кладбищем у деревни. **Настроение:** темнота, которую когда-то держали в узде. Фонарщик каждую ночь зажигал свечи в нишах, могильщики спускали гробы по шахте, колокол молчал сорок лет. Теперь свечи погасли, могилы стоят открытыми, а колокол снова звонит сам.
Свет — только тот, что в кадре: свечи в нишах, фонарь в руке героя, холодная луна сквозь решётки и шахты. Всё остальное тонет в черноте, без серой дымки.
Сначала утвердите 6.1. Он задаёт палитру тьмы и тёплого огня; остальные кадры делаются с ним как с референсом. Из утверждённых кадров потом генерируются ассеты: свеча в нише, фонарь фонарщика, груда костей, колокол.

### 6.0. Дальний план биома — `env_crypts_farplane`
Слой за всеми комнатами катакомб: глубина подземелья вместо неба. Без героя и тропы.
```text
{PREFIX} {WORLD_EARTH}
SCENE: an endless underground necropolis receding into darkness, wide 16:9 panoramic background plate for parallax, no foreground, no characters.
Rows of vaulted stone corridors and burial niches fade into black, distant arches of an ossuary walled with skulls, a far bell tower rising through the rock toward a crack of night sky,
a few tiny candle flames scattered deep in the dark like the last stars. No fog, no grey haze: depth is shown only by fading light.
FOCUS: the thin crack of moonlight high above the bell tower as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 6.1. Катакомбы, коридор со свечами — `env_crypts_catacombs`
```text
{PREFIX} {WORLD_EARTH}
SCENE: a low vaulted catacomb corridor under a cemetery in near total darkness, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
The walls are lined with rows of burial niches holding skulls and bones; small candle shelves in some niches, a few lit, most dark;
a broken hole in the floor opening into a lower crypt with coffins, a raised dais with stone sarcophagi, and at the far end a dead lamplighter slumped against the wall with his pole.
Warm candle light in small pools, everything between them black.
Clear walkable floor line in lower third, nothing in front of the hero but darkness.
FOCUS: the lamplighter's oil lantern lying by his hand as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 6.2. Оссуарий — `env_crypts_ossuary`
```text
{PREFIX} {WORLD_EARTH}
SCENE: a tall ossuary chamber with three tiers, walls built entirely of stacked skulls and long bones, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
A chandelier made of bones hangs unlit in the middle, pillars of skulls hold up the upper galleries, bone ladders connect the tiers,
heaps of bones lie on the floors as if something could rise from them; at the bottom an iron grate with black still water behind it;
a mirror shard crystal on a pedestal on the upper tier near the entrance.
FOCUS: the faint glow of the mirror shard as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 6.3. Квартал могильщика — `env_crypts_quarter`
```text
{PREFIX} {WORLD_EARTH}
SCENE: a cavern beneath the cemetery where the gravediggers lived and worked, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
Crooked wooden shacks against the rock wall, carts loaded with coffins, shovels stuck in heaps of earth, open graves dug into the cave floor, some with coffins inside,
a deep mass grave full of bones with a ladder, a wooden walkway with a winch above a shaft where coffins were lowered from the surface.
FOCUS: a cold beam of moonlight falling down the coffin shaft as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 6.4. Колокольня мёртвых — `env_crypts_belltower`
```text
{PREFIX} {WORLD_EARTH}
SCENE: the inside of an old bell tower sunk deep into the earth, wide 16:9 side-view composition for a 2.5D platformer, the frame reaching from dark lower tiers up to the belfry.
Stone landings alternate left and right, connected by ladders; thin slits in the walls let in more moonlight the higher you climb;
at the top an open belfry under the night sky, a heavy rusted bell whose clapper is wrapped in rags and bound with a chain, its long rope hanging down through the whole tower;
a small door in the belfry wall, barred from the outside.
FOCUS: the night sky seen through the belfry arches as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

---

## 7. Железные копи (`env_mines_*`, §8.13)

**Мир:** Земля, под мёртвой деревней Кузнеца. **Настроение:** копи бросили посреди смены. Железо брали для кузни, и чем глубже — тем лучше; на самой глубине руда стала тёплой, а под забоем что-то дышит.

### 7.1. Рудный двор и копёр — `env_mines_yard`
```text
{PREFIX} {WORLD_EARTH}
SCENE: an abandoned mine yard at grey ashen dusk behind a dead village, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
A tall timber headframe with a big wheel over a mine shaft at the foot of a black cliff, ore carts on rusted rails, heaps of grey slag,
a sagging miners' barrack, a cold stone smelter with a soot-black chimney, picks left in the mud, a wooden lift cage hanging in the shaft on chains.
Clear walkable ground line in lower third, slag stones and broken rails as dark foreground.
FOCUS: a single lantern burning on a post near the shaft as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 7.2. Затопленный штрек — `env_mines_drift`
```text
{PREFIX} {WORLD_EARTH}
SCENE: a long flooded mine tunnel under the ground, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
Square timber supports along rough rock walls with rusty ore veins, black still water waist-deep in a sump, a wooden water-lifting wheel with buckets turning by itself,
a collapse of rubble to climb over, candles in niches in the wall, a miner's lamp hanging on a hook, the ceiling low and heavy.
FOCUS: the lamp on the hook reflected in the black water as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 7.3. Глубокая выработка — `env_mines_deep`
```text
{PREFIX} {WORLD_EARTH}
SCENE: the deepest working of an iron mine, a tall rough chamber, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
Ore veins in the walls smoulder dull red like embers, cracks in the floor breathe heat, in the middle a breach in the floor crudely covered with planks,
a deep red glow and heat haze rising between the boards; beyond it a miners' small shrine — a wooden cross, stubs of candles, an old pick left against the warm wall.
Low saturation soot and rust colours, the red glow the only strong colour.
FOCUS: the red glow between the planks over the breach as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

---

## 8. Пекло (`env_inferno_*`, §8.13)

**Мир:** Земля, под копями. **Настроение:** дно, куда никто не должен был спуститься. Жар, сажа, лава — единственный яркий свет; из живых — только пленники. Палитра: тёмный багрово-коричневый и сажа, низкая насыщенность; яркое — лава. Стекло — чёрный обсидиан; красных отсветов на стекле нет.

### 8.0. Дальний план биома — `env_inferno_farplane`
```text
{PREFIX} {WORLD_EARTH}
SCENE: an immense underground cavern seen far into the distance, wide 16:9 panoramic background plate for parallax, no foreground, no characters.
A lake of lava to the horizon under a black rock vault, needle-like rock spires rising from it, thin falls of lava pouring from the walls,
iron cages hanging on long chains from the darkness above, heat haze and drifting soot. Low saturation crimson-brown and soot, the lava the only bright colour.
FOCUS: the glow of the lava lake on the horizon as the brightest band of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 8.1. Огненная река — `env_inferno_river`
```text
{PREFIX} {WORLD_EARTH}
SCENE: a river of lava across a dark cavern, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
A long bridge of charred planks hanging on iron chains from the vault, some planks burnt through, basalt columns on both banks,
a cage with a skeleton hanging over the lava, a lava fall pouring down the back wall, heat haze shimmering over the river.
Clear walkable line along the bridge, basalt rocks as dark foreground.
FOCUS: the lava river beneath the bridge as the brightest area of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 8.2. Темница — `env_inferno_cells`
```text
{PREFIX} {WORLD_EARTH}
SCENE: a cavern prison of demons, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
Iron cages hanging on chains, a torture rack, a brazier, chains and rings on the walls, bound captives sitting huddled on the floor,
on a raised stone dais a large cage holding a tall knight in dark, badly battered and dented armour, sitting still behind the bars.
FOCUS: the brazier fire beside the captives as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```

### 8.3. Обсидиановые ступени — `env_inferno_obsidian`
```text
{PREFIX} {WORLD_EARTH}
SCENE: black volcanic glass in a burning cavern, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level.
A long slope of smooth black obsidian glass sliding down to a ledge above a moat of lava, black glass spikes growing from the rock,
a ladder up to a high terrace with an old mine winch and chain, and beyond it huge rusted gates with a demonic face, its eyes glowing faintly.
Solid glossy black glass with clean reflections, no red light on the glass.
FOCUS: the faint glowing eyes on the gates as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}
```
