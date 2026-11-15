# Герой (`hero`)

**Тип:** игровой персонаж · **Статус:** graybox (манекен `assets/characters/mannequin/`)

## Кто это
Мальчишка из деревни, который не знает, что его ждёт. Возраст в начале игры выбирает игрок: от 14–15 до 22 лет (GAME_DESIGN §1.3).
Зеркала показывают его старше: тема игры — взросление (§7.4).

## Где встречается
Везде. Первая сцена — горящая деревня, безоружен, потом палка-брусок у поленницы (§8.9, §9.2).

## Как выглядит
Худощавый, одежда простая и с чужого плеча, без героической брони в начале (`art/STYLE_BIBLE.md` §7).
Концепты: раскадровка `art/concepts/key/key_intro_boy_through_fire.png`. Утверждённого листа персонажа пока нет.
Пробные генерации стиля v0.3: `ComfyUI\output\mirror_souls\char_hero_boy\r01_*` (2026-11-15).

**Описание для gen3:**
```text
gen3.bat char_hero_boy "A 15-year-old village boy, thin and wiry, messy dark hair, soot on his face, frightened but determined eyes, an oversized patched linen shirt with rolled sleeves, a hand-me-down wool vest, a rope belt, worn trousers, wrapped leather boots, holding a sturdy piece of firewood as a club in his right hand."
```

## 3D и анимации
Манекен с клипами UAL (`HeroModel`), карта костей `assets/characters/mannequin/ue_bone_map.tres`.

## Открытые вопросы
- Как меняется внешность с возрастом и уровнем: отдельные модели, морфы или только одежда.
