class_name WorldMap
extends RefCounted
## Карта мира (§8.13): где на сетке лежит каждая комната и к какому биому она относится.
## Одна сетка на весь основной мир; слой отражения позже ляжет на неё же (§2.2).
## Единица карты — 8 м; ось x — на восток, y — вниз. Деревня в середине, на западе — Поля и Подвесной
## перевал к Пепельным Пикам, на востоке — лес, под ним копи и Пекло.
## Форма комнат, двери и осколки — MapShapes (снимаются с самих комнат). Новая комната — строка в ROOMS
## и перезапуск tools/world_map/build_map.tscn.

## Метров в одной единице карты.
const METERS := 8.0

## Биомы: имя на карте и цвет. planned — область ещё не построена: видна только в тестовом режиме.
const BIOMES := {
	&"village": {"name": "Деревня", "color": Color(0.85, 0.55, 0.3)},
	&"hub": {"name": "Часовня", "color": Color(0.85, 0.78, 0.55)},
	&"cemetery": {"name": "Кладбище", "color": Color(0.6, 0.65, 0.85)},
	&"forest": {"name": "Край Мёртвого Леса", "color": Color(0.45, 0.65, 0.58)},
	&"castle": {"name": "Зеркальный замок", "color": Color(0.5, 0.7, 1.0)},
	&"runs": {"name": "Забеги", "color": Color(0.85, 0.45, 0.42)},
	&"tests": {"name": "Полигоны", "color": Color(0.62, 0.62, 0.66)},
	&"fields": {"name": "Поля", "color": Color(0.8, 0.72, 0.4)},
	&"pass": {"name": "Подвесной перевал", "color": Color(0.7, 0.7, 0.75)},
	&"peaks": {"name": "Пепельные Пики", "color": Color(0.6, 0.6, 0.66)},
	&"crypts": {"name": "Катакомбы кладбища", "color": Color(0.5, 0.52, 0.66)},
	&"mines": {"name": "Железные копи", "color": Color(0.65, 0.55, 0.45)},
	&"inferno": {"name": "Пекло", "color": Color(0.85, 0.3, 0.2)},
}

## Комнаты: биом, x — левый край комнаты на карте, y — линия её пола (высота 0 м) на карте;
## squash — сжать длинный забег по ширине. Соседние комнаты стыкуются краями, полы — по дверям.
## Имена — LevelMenu.PLACE_NAMES.
const ROOMS := {
	&"village_hut": {"biome": &"village", "x": -25.875, "y": -1.5},
	&"village_street": {"biome": &"village", "x": -24.5, "y": 0.0},
	&"village_house": {"biome": &"village", "x": -16.5, "y": 0.0},
	&"village_square": {"biome": &"village", "x": -13.375, "y": 0.0},
	&"chapel_yard": {"biome": &"hub", "x": -8.625, "y": 0.0},
	&"chapel": {"biome": &"hub", "x": -7.6, "y": -2.6},
	&"cemetery_gate": {"biome": &"cemetery", "x": -2.375, "y": 0.0},
	&"cemetery": {"biome": &"cemetery", "x": 3.125, "y": 0.0},
	&"forest_wall": {"biome": &"forest", "x": 10.125, "y": 0.0},
	&"fallen_giant": {"biome": &"forest", "x": 17.625, "y": 0.0},
	&"root_maze": {"biome": &"forest", "x": 25.125, "y": 0.5},
	&"swamp": {"biome": &"forest", "x": 32.125, "y": -0.5},
	&"cursed_village": {"biome": &"forest", "x": 39.625, "y": -0.5},
	&"room_001": {"biome": &"castle", "x": -9.0, "y": -7.0},
	&"castle_gallery": {"biome": &"castle", "x": -3.0, "y": -7.0},
	&"run_village": {"biome": &"runs", "x": -32.0, "y": -11.0, "squash": 0.5},
	&"run_exit": {"biome": &"runs", "x": -16.4, "y": -11.0},
	&"reflection_run": {"biome": &"runs", "x": -32.0, "y": -15.0, "squash": 0.5},
	&"hook_range": {"biome": &"tests", "x": -32.0, "y": -19.0},
	# Поля (§8.13): высоты общие для области, ноль комнат — земля двора; огороды и гумно ниже.
	&"farmyard": {"biome": &"fields", "x": -31.0, "y": -0.15},
	&"rye_field": {"biome": &"fields", "x": -42.0, "y": -0.15},
	&"execution_hill": {"biome": &"fields", "x": -49.5, "y": -0.15},
	&"mill": {"biome": &"fields", "x": -57.5, "y": -0.15},
	&"vegetable_patch": {"biome": &"fields", "x": -49.5, "y": 0.6625},
	&"threshing_barn": {"biome": &"fields", "x": -48.4375, "y": 2.6},
	# Перевал — от мельницы вверх и влево: настил моста на 17 м выше поля, Пики — ещё на 6 м выше.
	&"pass_bridge": {"biome": &"pass", "x": -68.0, "y": -2.275},
	&"ash_peaks": {"biome": &"peaks", "x": -78.0, "y": -3.025},
	# Копи (§8.13): за мёртвой деревней; каждая комната в своём нуле, глубина — здесь: галерея на 12 м ниже двора,
	# штрек и выработка — ещё на 9 м.
	&"mine_yard": {"biome": &"mines", "x": 47.125, "y": -0.5},
	&"mine_shafts": {"biome": &"mines", "x": 54.125, "y": 1.0},
	&"pump_wheel": {"biome": &"mines", "x": 60.625, "y": 2.125},
	&"flooded_drift": {"biome": &"mines", "x": 67.125, "y": 2.125},
	&"deep_gallery": {"biome": &"mines", "x": 74.125, "y": 2.125},
	# Пекло (§8.13): под провалом глубокой выработки, дно пещеры на 24 м ниже неё.
	&"inferno_breach": {"biome": &"inferno", "x": 77.5, "y": 5.125},
	&"lava_river": {"biome": &"inferno", "x": 83.5, "y": 5.125},
	&"captive_cells": {"biome": &"inferno", "x": 91.0, "y": 5.125},
	&"obsidian_steps": {"biome": &"inferno", "x": 97.5, "y": 5.125},
	# Катакомбы кладбища (§8.13): вход — запечатанный склеп кладбища. Катакомбы и верх оссуария — на 16 м ниже
	# кладбища, дно оссуария, квартал и низ колокольни — ещё на 14 м; колокольня поднимается почти до поверхности.
	&"catacombs": {"biome": &"crypts", "x": 4.0, "y": 2.0},
	&"ossuary": {"biome": &"crypts", "x": 12.0, "y": 2.0},
	&"gravedigger_quarter": {"biome": &"crypts", "x": 4.0, "y": 3.75},
	&"bell_tower": {"biome": &"crypts", "x": 1.0, "y": 3.75},
}


static func shape(room: StringName) -> Dictionary:
	return MapShapes.get_shapes().rooms.get(room, {})


## Точка карты по координатам в комнате (м).
static func to_map(room: StringName, p: Vector2) -> Vector2:
	var r: Dictionary = ROOMS[room]
	var s := shape(room)
	var left: float = s.get("left", -20.0)
	return Vector2(r["x"] + (p.x - left) / METERS * r.get("squash", 1.0), r["y"] - p.y / METERS)


## Прямоугольник комнаты на карте.
static func room_rect(room: StringName) -> Rect2:
	var s := shape(room)
	var a := to_map(room, Vector2(s.get("left", -20.0), s.get("top", 6.0)))
	var b := to_map(room, Vector2(s.get("right", 20.0), s.get("bottom", -2.0)))
	return Rect2(a, b - a)


## Осколки на карте: комната → путь узла осколка (по снятой форме комнат).
static func shards() -> Dictionary:
	var result := {}
	for room: StringName in ROOMS:
		var found: Dictionary = shape(room).get("shards", {})
		if not found.is_empty():
			result[room] = NodePath(found.keys()[0])
	return result


## Точка осколка комнаты на карте.
static func shard_point(room: StringName) -> Vector2:
	var found: Dictionary = shape(room).get("shards", {})
	return to_map(room, found.values()[0]) if not found.is_empty() else room_rect(room).get_center()


static func biome_name(biome: StringName) -> String:
	return BIOMES[biome]["name"]


static func is_planned(biome: StringName) -> bool:
	return BIOMES[biome].has("planned")
