class_name PlayerBody
extends RefCounted
## Тело-капсула героя: вспышки и поза смерти. Заглушка до настоящей модели.

## Смерть на капсуле: оседает, затем падает вперёд. С моделью — колено, потом пол (§8.5).
const SLUMP_TIME := 0.4
const FALL_TIME := 0.5
const SLUMP_SCALE := Vector3(1.12, 0.75, 1.12)

var mesh: MeshInstance3D
var _radius: float
var _half_height: float


func _init(body_mesh: MeshInstance3D, shape: CapsuleShape3D) -> void:
	mesh = body_mesh
	_radius = shape.radius
	_half_height = shape.height * 0.5


func flash(color: Color) -> void:
	var mat := mesh.get_active_material(0) as StandardMaterial3D
	if mat == null:
		return
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	var tween := mesh.create_tween()
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.25)


## Поза через t секунд после смерти: капсула оседает, потом падает вокруг носков
## (dir = 1 — вперёд, -1 — назад, если впереди стена).
func death_pose(t: float, dir: float) -> void:
	mesh.visible = true
	var slump := clampf(t / SLUMP_TIME, 0.0, 1.0)
	mesh.scale = Vector3.ONE.lerp(SLUMP_SCALE, ease(slump, 0.5))
	var half := _half_height * mesh.scale.y
	var fall := clampf((t - SLUMP_TIME) / FALL_TIME, 0.0, 1.0)
	# Падение ускоряется, как у тела, которое уже не держится на ногах.
	var angle := -dir * PI * 0.5 * fall * fall
	var center := Vector2(dir * _radius, 0.0) + Vector2(-dir * _radius, half).rotated(angle)
	mesh.rotation = Vector3(0.0, 0.0, angle)
	mesh.position = Vector3(center.x, center.y, 0.0)


## Куда падать: вперёд, а если впереди стена ближе роста — назад.
func fall_direction(owner: Node3D, facing: float) -> float:
	var from := owner.global_position + Vector3(0.0, 0.5, 0.0)
	var reach := _half_height * 2.0 * SLUMP_SCALE.y + _radius
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(facing * reach, 0.0, 0.0), 1)
	return -1.0 if owner.get_world_3d().direct_space_state.intersect_ray(query) else 1.0


func landed(t: float) -> bool:
	return t >= SLUMP_TIME + FALL_TIME
