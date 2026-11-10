# CLAUDE.md — «Осколки»

2.5D side-scroller action-RPG в тёмном фэнтези: соулслайк-бой, постоянный мир-метроидвания, зеркала, стекло-ставка, взросление героя как механика. Godot 4.7.2, GDScript, Forward+. Сейчас — graybox-прототип: всё на примитивах, без моделей и текстур.

Полный дизайн — [GAME_DESIGN.md](GAME_DESIGN.md) (номера параграфов §N в коде и коммитах ссылаются на него). Здесь — то, что нужно для работы с кодом, и краткая выжимка механик.

## Команды

Godot не в PATH, путь — `/c/Program Files/Godot/Godot.exe`.

- Импорт после новых ресурсов или `.uid`: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`
- Смоук-тест (несколько минут): `timeout 900 "/c/Program Files/Godot/Godot.exe" --headless --path . res://tests/smoke_test.tscn > <scratchpad>/smoke.log 2>&1`, в конце лога `RESULT: PASS (0 failures)`. Искать `FAIL|SCRIPT ERROR|RESULT`.
  - **Всегда с `timeout`**: после `SCRIPT ERROR` тест не выходит, а висит. Не убивать все `Godot.exe` — у автора может быть открыт редактор.
  - Тест длинный и проходит все комнаты подряд: проверка, которая сдвинула или развернула врага, должна вернуть его на место (иначе дальше герой может оказаться над пропастью).
- Быстрая проверка разбора всех скриптов (секунды; смоук-тест после ошибки разбора висит до `timeout`): `timeout 120 "/c/Program Files/Godot/Godot.exe" --headless --path . res://tools/check_scripts.tscn`, в конце `SCRIPTS: OK (N)`.
- Генераторы комнат (из корня проекта): `python tools/levels/build_village.py`, `build_forest.py`, `build_enemies.py`, `build_run.py`. После генерации — импорт и смоук-тест.

- В облаке (Linux) Godot скачивается с GitHub Releases: `godotengine/godot-builds`, файл `Godot_v4.7.2-stable_linux.x86_64.zip`; сначала `--headless --import` (папки `.godot` в git нет). Снимки, которым нужен рендер, идут через `xvfb-run -a <godot> --path . --rendering-driver opengl3 <сцена>`: рендер программный, в режиме совместимости (капсула героя там видна — это особенность режима, не баг игры).

## Генерируемые сцены — не править руками

Большинство комнат и часть врагов пишут Python-генераторы; ручная правка `.tscn` будет затёрта следующим запуском.

| Генератор | Что пишет |
|---|---|
| `tools/levels/build_village.py` | `village_hut`, `village_street`, `village_house`, `village_square`, `chapel_yard`, `chapel` |
| `tools/levels/build_forest.py` (+ `scenery.py`) | `cemetery_gate`, `cemetery`, `forest_wall`, `fallen_giant`, `root_maze`, `swamp`, `cursed_village` |
| `tools/levels/build_enemies.py` | сцены врагов леса и босса (`rat`, `fog_wraith`, `drowned_knight`, `blacksmith`, `bandit_*`) |
| `tools/levels/build_run.py` | уровень-забег «Горящая деревня»: `run_village`, `run_exit` (числа забега — константы в начале файла) |

- Правка комнаты = правка генератора + перегенерация. Генераторы воспроизводимы: повторный запуск без изменений не меняет файлы.
- Каждая комната объявляет все ext_resource из словаря `Scene.ext` (соглашение), даже неиспользуемые.
- `world/rooms/room_001.tscn` (комната-прототип, полигон для смоук-теста) и `castle_gallery.tscn` (галерея замка с вампиром) сделаны руками.
- Скрипты-генераторы и прочие инструменты держать в `tools/`, не в scratchpad: Windows чистит `%TEMP%`.

## Структура кода

- **Автозагрузки:** `Events` (шина сигналов, `systems/events.gd`), `GameState` (всё, что переживает смерть и пишется в сейв), `HitStop`, `Sfx` (`Sfx.play(&"id", pos)`, план звуков — `docs/SOUND_PLAN.md`).
- `actors/player/` — `Player` (стейт-машина `State`: MOVE, ROLL, ATTACK, PLUNGE, SLIDE, CLIMB, HURT, DEAD, BLOCK, GUARD_BROKEN, CRITICAL, BOW, LEDGE_*, DRINK, CHARGE, LADDER), `PlayerArms` (позы и взмахи оружия, лук, щит — процедурно, заглушка анимации), `PlayerBody`, `CameraRig`, `PlayerReach`, **`HeroModel`** — манекен-гуманоид (Quaternius, CC0, `assets/characters/mannequin/`) на скелете профиля `SkeletonProfileHumanoid`: только показывает, клип удара — в `AttackStep.anim`; капсула и позы клинка невидимы камере (слой 0), но считаются для логики и тестов. Инструменты: `tools/characters/setup_mannequin.py` (карта костей и импорт), `anim_sheet.gd` (листы кадров клипов), `hero_snapshot.tscn` (снимки героя в игре).
- `actors/enemies/` — базовый `Dummy` (патруль → заметил → WINDUP-телеграф → ATTACK → RECOVER; стойкость, OFF_BALANCE, KNOCKDOWN, CRITICAL_HIT, INVESTIGATE на шум, BLINDED) и наследники: `Bandit`, `Bat`, `Rat`, `FogWraith`, `DrownedKnight`, `GlassCrawler`, `Werewolf`, босс `Blacksmith`. Класс врага (`creature`, `CreatureKind`: человек, проклятый, вампир, оборотень, скелет, зверь, дух, стекло, элементаль) задаёт, как он переживает общий эффект (слепота — `Statuses.BLIND`); наследник ставит свой класс в `_init`, особую реакцию рисует сам. Облик: `mannequin_look` (`soldier`, `vampire`, `blacksmith`) — враг на манекене героя (`EnemyModel`: клипы по состояниям, IK ладоней и рукояти, черты на костях, рост и темп; сцены — `_model_pose()`, сиденье — `_seat_height()`; кулак поперёк рукояти — модификатор скелета `GripHands`; Кузнец — поза под молотом по его углу: `EnemyModel.SMITH_POSES`, корпус и ноги — модификатор `SmithBody`; хват — молот со стороны большого пальца, левая ладонь на рукояти — `GripHands.follow_gap`), иначе примитивы с руками `GrayboxArms` (локоть, IK в плоскости кадра). **Оружие всегда в руке:** хваты — `_grip_node/_grip_points`, рукоять подтягивается к кисти; смоук-тест следит за разрывом весь прогон. Вампир (`Vampire`): приём «Мышь» — фазы `Vampire.Move`, вторая форма `GiantBat` (Skeleton3D с именами гуманоидного профиля: руки-крылья, пальцы-спицы, ноги; процедурные позы, риг для будущей модели — `docs/rigs/giant_bat.md`), взрыв тьмы — `effects/particles/DarkBurst`; плащ-крылья и горящие глаза — `EnemyModel.spread/eyes_flare`. Снимки реакций — `tools/characters/blind_snapshot.tscn`, Кузнеца в его комнате — `boss_snapshot.tscn`, лист поз Кузнеца на сером фоне — `smith_poses.tscn`, «Мыши» — `vampire_snapshot.tscn`; видео боя (Movie Maker, бот за героя) — `tools/video/` (`--write-movie out.avi --fixed-fps 30`).
- `combat/` — `Health`, `Hitbox`/`Hurtbox`, `Arrow` + `ArrowData` (особые стрелы, два гнезда `GameState.arrow_slots`), **`WeaponData` + `AttackStep`** (данные оружия), `consumables/` — `ConsumableData` (броски и склянки), снаряд `Thrown`, зоны склянок `FlaskZone` (огненная лужа, облако яда, кислота, смола, свет) и `TarBlast`; `status/Statuses` — яд, горение, «разъедено», смола, слепота на враге и герое; `magic/` — `SpellData` (заклинания, `data/spells/`) и `GlintFlash` (Блик). Магия: катализатор — `WeaponData.catalyst` (посох), ячейки — `GameState.spell_slots`, мана — `Player.mana`, Память — `PlayerStats.Param.MEMORY`. Огонь — `effects/fire/Flame` (процедурный шейдер).
- `systems/progression/` — `GameState`, `PlayerStats` (все числа героя, зависимость от возраста), `Facet` (грани), `AgeLook`.
- `systems/room_manager/` — `RoomManager`: загрузка комнаты в нужной реальности, применение `MirrorTransformation` (`FlipX`…), двери, смерть и возрождение.
- `world/` — комнаты (`Room` — только раскладка и данные), зеркала, стекло (`GlassSurface` — одна сцена на все роли стекла), осколки-чекпоинты, отзвуки, `common/` (Interactable, Npc, ItemPickup, RoomDoor, SayLine, Note, Ladder, BossArena, FogGate…).
- `ui/` — `Hud`, `LevelMenu` (меню у осколка: уровни, грани, закалка, мастерство, смена оружия и лука; оно же меню паузы — `open_pause`, режим `at_shard = false`: корень паузы — компактная панель `PausePanel`, страница `Page.EQUIP` — экран снаряжения `EquipmentScreen` с манекеном героя), `StartMenu`. Настройки игрока — `systems/settings.gd` (`Settings`, отдельный `user://settings.cfg`).
- `data/` — `.tres`: оружие (`stick`, `sword`, `candlestick`), расходники (`consumables/`), грани, статы героя, особые добивания врагов.
- `tests/smoke_test.gd` — один сквозной тест всей игры, вводом через `Input.action_press`.

**Главное правило архитектуры:** геймплей не смешивается с конкретными комнатами. Системы общаются через `Events`; комната — данные и раскладка, логика — в компонентах и системах.

## Оружие (data-driven)

- `WeaponData`: `combo` (массив `AttackStep`), `extra_hit` (удар серии со 2-й ступени), `charged`, `slide_attack`, `roll_attack`, `air_attack`, `riposte`, `backstab`; `type` (`sword`, `hammer`…) — к нему привязано мастерство; `two_handed`, `head_size` (навершие молота), позы `rest/guard/charge_*`.
- `AttackStep`: тайминги (`duration`, `active_from/to`, `chain_from`, `recover_from`), урон и стойкость, выпад, хитбокс, `blade_from/to` + `grip_from/to` + `blade_yaw_*`, `ground_impact`, `follow_up` (следующий удар сам), `air_hover`, `victim_throw`.
- **Поза клинка:** угол 0 — вверх, «+» — назад, «−» — вперёд; хват — смещение в пространстве героя, смотрящего вправо.
- **Ступени мастерства** (`WeaponData.STEP_*`): 1 парирование, 2 extra_hit, 3 удар в воздухе, 4 контрудар/волна, 5 спецэффект. Очки по врагам: обычный 1, мини-босс 2, босс 5; ступени — 20, 50 всего, дальше 100/175/275 (черновик).
- Новое оружие: `.tres` в `data/weapons/`, id в `GameState.WEAPONS`, имя в `ItemCatalog.ITEMS`, значок в `make_icons.py`. Посох (`staff`) — катализатор магии.
- Новое заклинание: `.tres` в `data/spells/` (`SpellData`, свой `effect`), имя в `ItemCatalog.ITEMS` (раздел SPELL), значок в `make_icons.py`; учит находка (`ItemPickup.spell_id`) или `GameState.learn_spell()`.

## Механики — коротко (подробно в GAME_DESIGN.md)

- **Возраст и уровни (§1.3, §8.6):** старт 14–22 лет; каждый уровень +¼ года. Младше — быстрее и ловчее, старше — сильнее удар. Прокачка у осколка: набрать очки → «Подтвердить» → «Повысить уровень?».
- **Характеристики (§8.6):** восемь — Жизненная сила, Стойкость, Крепость, Сила, Ловкость, Память (ячейки магии, мана, её восстановление), Интеллект (урон магии, мана), Удача; подвижность задаёт возраст (растёт до 45, потом падает до планки); у оружия скалирование S–E. В коде — `PlayerStats.Param` (VIGOR, ENDURANCE, STRENGTH, DEXTERITY — прежние ключи сейва 0–3, дальше VITALITY, INTELLIGENCE, LUCK, MEMORY), порядок в меню — `PARAM_ORDER`; скалирование — `WeaponData.scaling`, урон — `Player.weapon_damage()`. Вес, интеллект, защита и сопротивления пока только числа в меню.
- **Интерфейс (§8.12):** макет — артефакт «Осколки — UI осколка и HUD»; меню осколка как место благодати Elden Ring, HUD в стиле мрачной готики, значки — сменные картинки, окно находки в витой рамке. В коде: `ui/hud.gd` (+ `hud.tscn`), `ui/item_popup.gd`, `ui/level_menu.gd` (страницы `Page`), `ui/item_catalog.gd` (имена, значки, разделы), эффекты — `StatusEffect` (`data/effects/`) и `Player.add_effect()`. Графика UI — `assets/ui/` (папка `art/` исключена из Godot через `.gdignore`), заглушки делает `python tools/ui/make_icons.py`; нарисованные части HUD режет из листа автора `python tools/ui/cut_hud_sheet.py` (`art/ui_source/` → `assets/ui/hud/painted/`), рамки полос HP и выносливости — из листа с прозрачностью `python tools/ui/cut_hud_bars.py` (`*_frame_v2.png`; длина растёт с максимумом — `ui/bar_frame.gd` собирает раму из кусков по чистому рельсу, числа длины — в `Hud`); ромб крестовины расходников — `python tools/ui/cut_quick_cross.py` (заглушка из референса `art/ui_source/quick_cross_v1.png`); финальные картинки кладутся с теми же именами. Крестовина: ячейки `GameState.quick_slots` (верх, лево, право, низ), новый расходник — `.tres` в `data/consumables/` + имя в `ItemCatalog.ITEMS` (раздел CONSUMABLE) + значок в `make_icons.py`. Тесты выключают перехват «взаимодействия» окном находки (`popup.blocks_interact = false`).
- **Отзвуки (§8.6)** — валюта и опыт. Рядовые сами летят к герою; отзвук босса и героя — касанием.
- **Смерть (§8.5):** все отзвуки остаются в отзвуке героя на месте гибели; умер снова, не подобрав, — пропали. Возврат к осколку, враги и одноразовое стекло восстанавливаются, открытые сундуки и навсегда разбитое — нет.
- **Осколки Главного Зеркала (§8.4)** — чекпоинты и место прокачки, как костёр. Главный осколок — у часовни в хабе.
- **Грани (§8.6)** — надеваемые модификаторы со слотами (как амулеты Hollow Knight).
- **Оружие:** закалка стеклом (+12 % урона за шаг, 5 шагов) — у предмета; мастерство — у типа оружия, учится и у врагов (треть опыта). Брусок у поленницы — первое оружие; меч — от кузнеца; подсвечник (молот низкого качества) — с мародёра; тяжёлый молот — по рецепту с босса, ковка у кузнеца часовни за 1000.
- **Защита:** блок (выносливость, может быть пробит), парирование (с 1-й ступени или сразу со щитом-гоплоном — 250 у кузнеца, блок им ×0.6), добивание после парирования, удар в спину. Двуручное и лук — щит за спиной.
- **Стекло (§5):** поверхность для скольжения и лазания; разбить — ставка: чистое (награда), мутное (засада), хрупкое над шипами.
- **Зеркала (§7):** переход в отражённую реальность той же комнаты (`FlipX` + объекты только одной реальности); виды — реальность, врата в биом, аномалия.
- **Награда босса (§8.6):** отзвук босса, рецепт уникального оружия, другая валюта прокачки.
- **Уровень-забег (§8.11):** один на биом, не первый и не последний; рушится за героем по скрытому таймеру; без осколка отдыха; гибель — очнуться сидя у следующего осколка, отзвук героя ждёт перед ним; без повтора; пропущенные предметы продаёт NPC. В коде — `world/run/`: `RunLevel` (узел в комнате: фронт обрушения `front_x`, скорость по участкам `pace`, запас `max_slack`, огонь за фронтом, награды уровня) и `Collapsible` (кусок, который падает; `RESTORES` встаёт снова). Гибель и выход ведёт `RoomManager` (`_wake_after_run`, `RunLevel.close()`); вход закрывает `RoomDoor.closed_flag`; упущенное — `GameState.run_leftovers`, цены — `ItemCatalog.PRICES`, продаёт `Npc.sells_leftovers`. На уровне игра не сохраняется. Полигон — «Горящая деревня» (`run_village` → `run_exit`), вход — дверь в `room_001`. Снимки участков — `tools/levels/run_snapshot.tscn`.

## Соглашения

- Язык проекта — русский: комментарии `##` у классов и экспортов, тексты в игре, документация. Валюта в интерфейсе — «Отзвуки». Комментарии по плотности как в соседнем коде, со ссылкой на §.
- Отступы в GDScript — табы. `GAME_DESIGN.md`, `README.md`, большинство `.gd` и генераторы — с CRLF; правки должны сохранять окончания строк.
- Решения по дизайну записываются в `GAME_DESIGN.md` (нужный § + строка в §14 «Журнал решений» с датой); заметные фичи — пунктом в `README.md` «Текущий этап».
- Декор переднего плана может перекрывать героя — это не баг; главное, чтобы предмет подходил месту.
- Большие загрузки (архивы, бандлы ассетов) — в `D:\Downloads`, не на C:.
- Референсы чужих фильмов (`art/refs/`) в git не попадают.

## Git

- Работа идёт в `dev`, `main` — стабильная. Коммиты мелкие, в стиле `feat: …` / `fix: …` / `docs: …`.
- После необходимых изменений — коммит в `dev`. Пушит обычно автор; пушить самому — только когда автор просит.
