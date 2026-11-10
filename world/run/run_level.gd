class_name RunLevel
extends Node3D
## Уровень-забег (§8.11): комната рушится за героем. Этот узел — таймер под капотом:
## фронт обрушения идёт слева направо со скоростью участка (pace) и не отстаёт от героя
## больше чем на max_slack секунд — уровень рушится по ходу движения, запас не копится.
## Кому падать, решают сами куски (Collapsible). На твёрдой земле вместо обрушения — огонь:
## кто остался за фронтом, горит.
## Гибель здесь — не возврат назад: менеджер комнат переносит героя к следующему осколку,
## отзвук героя ждёт перед ним, а повторно пройти уровень нельзя.

## Комната за уровнем, осколок в ней и место, где героя ждёт его отзвук.
@export var next_room: StringName
@export var next_shard: NodePath = ^"Objects/MirrorShard"
@export var echo_spawn: NodePath = ^"Spawns/HeroEcho"
## Где герой приходит в себя после гибели на уровне — сидя, рядом с осколком. Нет такой точки — у самого осколка.
@export var wake_spawn: NodePath = ^"Spawns/Wake"
## Ставится, когда забег окончен — пройден или провален: вход закрывается.
@export var done_flag: StringName
## Герой пересёк эту линию — пошёл отсчёт.
@export var start_x := 0.0
## Фронт стартует на столько метров позади линии старта.
@export var head_start := 6.0
## Скорость фронта по участкам: (x начала участка, м/с). До первой точки — скорость первой.
@export var pace := PackedVector2Array([Vector2(0.0, 6.0)])
## Запас героя, с: фронт не отстаёт от него больше чем на столько секунд своего хода.
@export var max_slack := 5.0
## Огонь за фронтом: доля здоровья в секунду.
@export var burn_rate := 0.3
## Награды уровня: флаг «забрано» (сундука или находки) и предмет под тем же номером.
## Не забранное к концу забега уходит торговцу (GameState.run_leftovers).
@export var reward_flags: Array[StringName] = []
@export var reward_items: Array[StringName] = []
## Сколько штук под тем же номером; короче списка наград — по одной.
@export var reward_counts: Array[int] = []
## Стена огня идёт вместе с фронтом — игрок видит угрозу, а не угадывает таймер.
## Высоты этажей, на которых она горит; пусто — стены нет.
@export var fire_levels := PackedFloat32Array([0.0])
@export var fire_size := Vector3(1.8, 3.6, 0.6)

var running := false
var front_x := 0.0
var _player: Player
var _wall: Node3D


func _ready() -> void:
	add_to_group(&"run_level")
	front_x = start_x - head_start
	_wall = Node3D.new()
	add_child(_wall)
	for level in fire_levels:
		var fire := FireSpot.new()
		fire.size = fire_size
		fire.light_energy = 3.0
		fire.light_range = 10.0
		fire.position = Vector3(0.0, level, -0.6)
		_wall.add_child(fire)
	_wall.visible = false


## Узел забега в комнате; нет — обычная комната.
static func of(room: Node) -> RunLevel:
	if room == null:
		return null
	for node in room.find_children("*", "", true, false):
		if node is RunLevel:
			return node
	return null


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	var hero_x := _player.global_position.x
	if not running:
		if hero_x < start_x or _player.is_dead():
			return
		running = true
		_wall.visible = true
		Events.run_started.emit(self)
	front_x += speed_at(front_x) * delta
	if not _player.is_dead():
		front_x = maxf(front_x, x_behind(hero_x, max_slack))
	_wall.global_position = Vector3(front_x - 1.0, 0.0, 0.0)
	for piece: Collapsible in get_tree().get_nodes_in_group(&"collapsible"):
		piece.front_at(front_x)
	if hero_x < front_x and not _player.is_dead():
		_player.statuses.apply(Statuses.BURNING, 1.0)
		_player.health.take_damage(_player.health.max_health * burn_rate * delta)


## Скорость фронта в точке x.
func speed_at(x: float) -> float:
	var speed := pace[0].y
	for point in pace:
		if x >= point.x:
			speed = point.y
	return speed


## Сколько секунд фронту идти от a до b (a ≤ b).
func time_between(a: float, b: float) -> float:
	var total := 0.0
	var x := a
	for i in pace.size():
		var seg_end := pace[i + 1].x if i + 1 < pace.size() else INF
		if seg_end <= x:
			continue
		var to := minf(seg_end, b)
		if to > x:
			total += (to - x) / pace[i].y
			x = to
		if x >= b:
			break
	return total


## Точка, от которой фронту идти до x ровно seconds секунд.
func x_behind(x: float, seconds: float) -> float:
	var left := seconds
	var at := x
	for i in range(pace.size() - 1, -1, -1):
		var seg_start := pace[i].x if i > 0 else -INF
		if seg_start >= at:
			continue
		var span := (at - seg_start) / pace[i].y
		if span >= left:
			return at - left * pace[i].y
		left -= span
		at = seg_start
	return at


## Забег окончен (выход или гибель): флаг стоит, не забранные награды — торговцу.
func close() -> void:
	running = false
	set_physics_process(false)
	if done_flag != &"":
		GameState.set_flag(done_flag)
	# Одна награда — один флаг, но предметов в ней может быть несколько (сундук).
	var missed: Array[StringName] = []
	for flag in reward_flags:
		if not GameState.has_flag(flag) and flag not in missed:
			missed.append(flag)
	for i in mini(reward_flags.size(), reward_items.size()):
		if reward_flags[i] in missed:
			GameState.add_leftover(reward_items[i], reward_counts[i] if i < reward_counts.size() else 1)
	for flag in missed:
		GameState.set_flag(flag)
	Events.run_finished.emit(self)
