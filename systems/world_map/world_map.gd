class_name WorldMap
extends RefCounted
## Карта мира (§8.13): где лежит каждая комната, к какому биому относится, куда ведут двери и где осколки.
## Одна сетка на весь основной мир; слой отражения позже ляжет на неё же (§2.2).
## Единица карты — 8 м ширины комнаты; ось x — на восток, y — вниз. Деревня в середине, на западе — Поля
## и Подвесной перевал к Пепельным Пикам, на востоке — лес, под ним копи и Пекло.
## Новая комната — строка в ROOMS (и в LINKS, если её двери ведут в другие комнаты); осколок — в SHARDS.

## Метров ширины комнаты в одной единице карты.
const METERS := 8.0

## Биомы: имя на карте и цвет подложки. planned — область ещё не построена: видна только в тестовом режиме.
const BIOMES := {
	&"village": {"name": "Деревня", "color": Color(0.85, 0.55, 0.3)},
	&"hub": {"name": "Часовня", "color": Color(0.85, 0.78, 0.55)},
	&"cemetery": {"name": "Кладбище", "color": Color(0.6, 0.65, 0.8)},
	&"forest": {"name": "Край Мёртвого Леса", "color": Color(0.45, 0.62, 0.55)},
	&"castle": {"name": "Зеркальный замок", "color": Color(0.5, 0.7, 1.0)},
	&"runs": {"name": "Забеги", "color": Color(0.8, 0.45, 0.45)},
	&"fields": {"name": "Поля", "color": Color(0.8, 0.72, 0.4), "planned": Rect2(-41, -1.5, 13, 4)},
	&"pass": {"name": "Подвесной перевал", "color": Color(0.7, 0.7, 0.75), "planned": Rect2(-38, -5.5, 10, 3)},
	&"peaks": {"name": "Пепельные Пики", "color": Color(0.6, 0.6, 0.66), "planned": Rect2(-52, -12, 16, 5.5)},
	&"crypts": {"name": "Катакомбы кладбища", "color": Color(0.6, 0.65, 0.8), "planned": Rect2(3, 2, 10, 3.5)},
	&"mines": {"name": "Железные копи", "color": Color(0.65, 0.55, 0.45), "planned": Rect2(48, -0.5, 12, 4.5)},
	&"inferno": {"name": "Пекло", "color": Color(0.85, 0.3, 0.2), "planned": Rect2(44, 5, 18, 5)},
}

## Комнаты: биом, левый верхний угол (x, y) в единицах карты, ширина комнаты в метрах (w), высота в единицах (h)
## (у всех комнат центр — x = 0, как `Room.center_x`); squash — сжать длинный забег по ширине. Имена — LevelMenu.PLACE_NAMES.
const ROOMS := {
	&"village_hut": {"biome": &"village", "x": -26.5, "y": 0.0, "w": 16.0, "h": 1.0},
	&"village_street": {"biome": &"village", "x": -24.5, "y": 0.0, "w": 64.0, "h": 1.0},
	&"village_house": {"biome": &"village", "x": -16.5, "y": -0.6, "w": 25.0, "h": 1.6},
	&"village_square": {"biome": &"village", "x": -13.4, "y": 0.0, "w": 38.0, "h": 1.0},
	&"chapel_yard": {"biome": &"hub", "x": -8.65, "y": 0.0, "w": 50.0, "h": 1.0},
	&"chapel": {"biome": &"hub", "x": -6.5, "y": -1.7, "w": 28.0, "h": 1.5},
	&"cemetery_gate": {"biome": &"cemetery", "x": -2.4, "y": 0.0, "w": 44.0, "h": 1.0},
	&"cemetery": {"biome": &"cemetery", "x": 3.1, "y": -0.3, "w": 56.0, "h": 1.3},
	&"forest_wall": {"biome": &"forest", "x": 10.1, "y": -0.8, "w": 60.0, "h": 1.8},
	&"fallen_giant": {"biome": &"forest", "x": 17.6, "y": -0.5, "w": 60.0, "h": 2.5},
	&"root_maze": {"biome": &"forest", "x": 25.1, "y": -1.6, "w": 56.0, "h": 3.4},
	&"swamp": {"biome": &"forest", "x": 32.1, "y": 0.0, "w": 60.0, "h": 1.0},
	&"cursed_village": {"biome": &"forest", "x": 39.6, "y": 0.0, "w": 60.0, "h": 1.0},
	&"room_001": {"biome": &"castle", "x": -8.0, "y": -5.0, "w": 48.0, "h": 1.6},
	&"castle_gallery": {"biome": &"castle", "x": -2.0, "y": -5.0, "w": 30.0, "h": 1.6},
	&"run_village": {"biome": &"runs", "x": -24.0, "y": -8.5, "w": 250.0, "h": 1.6, "squash": 0.5},
	&"run_exit": {"biome": &"runs", "x": -8.4, "y": -8.5, "w": 36.0, "h": 1.0},
	&"reflection_run": {"biome": &"runs", "x": -24.0, "y": -10.6, "w": 400.0, "h": 1.0, "squash": 0.5},
}

## Двери между комнатами — линии на карте. Дверь в неоткрытую комнату видна обрывком: туда есть выход.
const LINKS := [
	[&"village_hut", &"village_street"], [&"village_street", &"village_house"], [&"village_house", &"village_square"],
	[&"village_square", &"chapel_yard"], [&"chapel_yard", &"chapel"], [&"chapel_yard", &"cemetery_gate"],
	[&"cemetery_gate", &"cemetery"], [&"cemetery", &"forest_wall"], [&"forest_wall", &"fallen_giant"],
	[&"fallen_giant", &"root_maze"], [&"root_maze", &"swamp"], [&"swamp", &"cursed_village"],
	[&"chapel", &"room_001"], [&"room_001", &"castle_gallery"], [&"room_001", &"run_village"],
	[&"run_village", &"run_exit"], [&"room_001", &"reflection_run"],
]

## Осколки: путь узла в комнате и x в метрах. Смоук-тест сверяет таблицу со сценами комнат.
const SHARDS := {
	&"village_square": {"path": ^"AfterFire/MirrorShard", "x": -4.0},
	&"chapel_yard": {"path": ^"Objects/MirrorShard", "x": 15.0},
	&"cemetery": {"path": ^"Objects/MirrorShard", "x": 24.0},
	&"fallen_giant": {"path": ^"Objects/MirrorShard", "x": 16.0},
	&"cursed_village": {"path": ^"Objects/MirrorShard", "x": -24.0},
	&"room_001": {"path": ^"Objects/MirrorShard", "x": -18.5},
	&"run_exit": {"path": ^"Objects/MirrorShard", "x": 3.0},
}


## Прямоугольник комнаты в единицах карты.
static func room_rect(room: StringName) -> Rect2:
	var r: Dictionary = ROOMS[room]
	return Rect2(r["x"], r["y"], r["w"] / METERS * r.get("squash", 1.0), r["h"])


## Точка на карте по x в метрах внутри комнаты (низ комнаты — пол основного пути).
static func room_point(room: StringName, x_m: float) -> Vector2:
	var rect := room_rect(room)
	var w: float = ROOMS[room]["w"]
	var t := clampf((x_m + w * 0.5) / w, 0.0, 1.0)
	return Vector2(rect.position.x + rect.size.x * t, rect.end.y - 0.32)


static func biome_name(biome: StringName) -> String:
	return BIOMES[biome]["name"]


static func is_planned(biome: StringName) -> bool:
	return BIOMES[biome].has("planned")
