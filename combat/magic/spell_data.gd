class_name SpellData
extends Resource
## Заклинание стеклянной магии (§6.2, 2026-11-09). Колдуют с катализатором в руке (посох,
## WeaponData.catalyst): удар становится заклинанием из активной ячейки. Ячейки магии — от Памяти,
## мана — от Памяти и Интеллекта, урон — от Интеллекта (PlayerStats). Что делает заклинание —
## по effect: Блик — вспышка, которая ослепляет (GlintFlash). Двойник — позже.

const DIRECTORY := "res://data/spells"

enum Effect { GLINT, DOUBLE }

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var effect := Effect.GLINT
@export var mana_cost := 15.0
## Сколько ячеек магии занимает.
@export var memory_slots := 1
## Когда срабатывает от начала каста и сколько длится весь каст.
@export var cast_time := 0.35
@export var duration := 0.7
## Пока колдует — идёт медленнее.
@export var move_mult := 0.3
@export_group("Блик")
## Куда достаёт вспышка: вперёд от героя и в высоту от его пояса.
@export var reach := 6.5
@export var height := 3.0
## Сколько секунд слепоты вешает (класс врага и его сопротивление укорачивают).
@export var blind_time := 4.0
## Урон светом до множителя Интеллекта; у Блика нет — он слепит.
@export var damage := 0.0


static func by_id(wanted: StringName) -> SpellData:
	var path := "%s/%s.tres" % [DIRECTORY, wanted]
	return load(path) as SpellData if ResourceLoader.exists(path) else null
