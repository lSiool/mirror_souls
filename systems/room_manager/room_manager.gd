class_name RoomManager
extends Node
## Загружает комнату в нужной реальности, применяет правила отражения,
## переносит героя через зеркала и возрождает его у осколка (§12.2).
## Сброс комнаты после смерти — честное пересоздание сцены: враги, стекло и ловушки как новые.

const NORMAL: StringName = &"normal"

@export var room_scene: PackedScene
@export var player_path: NodePath
@export var camera_rig_path: NodePath
@export var hud_path: NodePath
@export var world_environment_path: NodePath
@export var sun_path: NodePath

@export_group("Реальности")
@export var normal_environment: Environment
@export var mirror_environment: Environment
@export var normal_sun_color := Color(1.0, 0.88, 0.72)
@export var mirror_sun_color := Color(0.62, 0.78, 1.0)

var current_room: Room
var reality: StringName = NORMAL

## Правила, с которыми строится каждая реальность (запоминаются, чтобы возрождаться в отражении).
var _reality_rules: Dictionary = {NORMAL: []}
var _busy := false

@onready var player: Player = get_node(player_path)
@onready var camera_rig: CameraRig = get_node(camera_rig_path)
@onready var hud: Hud = get_node(hud_path)
@onready var world_environment: WorldEnvironment = get_node(world_environment_path)
@onready var sun: DirectionalLight3D = get_node(sun_path)


func _ready() -> void:
	Events.mirror_used.connect(_on_mirror_used)
	Events.checkpoint_activated.connect(_on_checkpoint_activated)
	player.died.connect(_on_player_died)
	_load_room(GameState.checkpoint_reality)
	player.respawn(_checkpoint_position())
	camera_rig.snap_to_target()
	hud.fade_to(0.0, 0.6)


func _load_room(target_reality: StringName) -> void:
	if current_room:
		remove_child(current_room)
		current_room.queue_free()
	var room := room_scene.instantiate() as Room
	room.apply_reality(target_reality)
	for rule: MirrorTransformation in _reality_rules.get(target_reality, []):
		rule.apply(room)
	add_child(room)
	current_room = room
	reality = target_reality
	_apply_mood()
	var shard := current_room.get_node_or_null(GameState.checkpoint_path) as MirrorShard
	if shard and GameState.checkpoint_reality == reality:
		shard.set_lit(true)
	Events.reality_changed.emit(reality)


func _apply_mood() -> void:
	var mirrored := reality != NORMAL
	world_environment.environment = mirror_environment if mirrored else normal_environment
	sun.light_color = mirror_sun_color if mirrored else normal_sun_color


func _on_mirror_used(portal: MirrorPortal) -> void:
	if _busy:
		return
	_busy = true
	var portal_path := current_room.get_path_to(portal)
	var target := portal.destination_reality if reality != portal.destination_reality else NORMAL
	if target != NORMAL:
		_reality_rules[target] = portal.transformations
	player.frozen = true
	await hud.fade_to(1.0, 0.25)
	_load_room(target)
	var exit_portal := current_room.get_node_or_null(portal_path) as MirrorPortal
	var at := exit_portal.get_entry_position() if exit_portal else _checkpoint_position()
	player.teleport(at)
	player.facing = -player.facing
	camera_rig.snap_to_target()
	player.frozen = false
	await hud.fade_to(0.0, 0.35)
	_busy = false


func _on_checkpoint_activated(shard: MirrorShard) -> void:
	GameState.set_checkpoint(reality, current_room.get_path_to(shard))
	for other in get_tree().get_nodes_in_group("mirror_shard"):
		if other != shard:
			other.set_lit(false)


func _on_player_died() -> void:
	_busy = true
	await get_tree().create_timer(1.2).timeout
	await hud.fade_to(1.0, 0.5)
	_load_room(GameState.checkpoint_reality)
	player.respawn(_checkpoint_position())
	camera_rig.snap_to_target()
	hud.hide_death()
	await hud.fade_to(0.0, 0.5)
	_busy = false


func _checkpoint_position() -> Vector3:
	var node := current_room.get_node_or_null(GameState.checkpoint_path) as Node3D
	if node == null:
		node = current_room.get_node(^"Spawns/PlayerStart") as Node3D
	if node.has_method("get_spawn_position"):
		return node.get_spawn_position()
	return node.global_position
