class_name MainMirror
extends RoomDoor
## Главное Зеркало в часовне, под витражом с замком (§8.3, §8.4). Стоит накрытое тканью и неполное:
## каждый активированный осколок снимает кусок ткани и открывает кусок стекла. Подошедший герой видит
## в открытом стекле себя старше, и чем больше кусков, тем дальше зеркало заглядывает вперёд (§7.4).
## Откроется, когда стоят все required_flags: победа над боссом и все осколки.

const YEARS_PER_PANE := 4.0
const GLASS_COLOR := Color(0.55, 0.72, 0.95)
const CLOTH_COLOR := Color(0.13, 0.11, 0.1)
## Отражение чуть в стороне от героя, иначе он сам его заслоняет.
const REFLECTION_SIDE := 0.9

## Осколки на пути, по одному на кусок зеркала.
@export var shard_flags: Array[StringName] = []

var _reflection: ShardReflection
var _hero: Player


func _ready() -> void:
	super()
	var count := shard_flags.size()
	var width := door_size.x * 0.92 / maxf(count, 1)
	for i in count:
		var lit := GameState.has_flag(shard_flags[i])
		var pane := MeshInstance3D.new()
		pane.name = "Pane%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(width * 0.96, door_size.y * 0.94, 0.06)
		var material := StandardMaterial3D.new()
		material.albedo_color = GLASS_COLOR if lit else CLOTH_COLOR
		if lit:
			material.emission_enabled = true
			material.emission = GLASS_COLOR
			material.emission_energy_multiplier = 1.0 if not is_locked() else 0.22
		box.material = material
		pane.mesh = box
		pane.position = Vector3((i - (count - 1) * 0.5) * width, door_size.y * 0.5, -0.82)
		add_child(pane)


func lit_panes() -> int:
	var lit := 0
	for flag in shard_flags:
		if GameState.has_flag(flag):
			lit += 1
	return lit


func _process(_delta: float) -> void:
	if _reflection and is_instance_valid(_hero):
		var half := door_size.x * 0.4
		var side := -REFLECTION_SIDE if _hero.global_position.x > global_position.x else REFLECTION_SIDE
		_reflection.global_position = Vector3(
			clampf(_hero.global_position.x + side, global_position.x - half, global_position.x + half),
			global_position.y, global_position.z - 0.7)


func _on_body_entered(body: Node3D) -> void:
	super(body)
	if body is Player and lit_panes() > 0 and _reflection == null:
		_hero = body
		_reflection = ShardReflection.spawn(self, _hero)
		_reflection.show_age(_hero.stats.current_age + YEARS_PER_PANE * lit_panes())


func _on_body_exited(body: Node3D) -> void:
	super(body)
	if body is Player and _reflection:
		_reflection.dismiss()
		_reflection = null
