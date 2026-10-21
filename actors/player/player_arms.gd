class_name PlayerArms
extends RefCounted
## Руки героя: позы и взмахи меча, лук. Заглушка до настоящей анимации модели.
## Поза задаётся в пространстве героя, смотрящего вправо (см. AttackStep).

const WORLD_MASK := 1
## Наклон плоскости лежащего оружия от пола к камере, рад.
const LYING_TILT := 1.05

var sword_pivot: Node3D
var _grip_base: Vector3
var _tween: Tween
var _bow: Node3D
var _nocked: Node3D
## Выпавшее при смерти оружие — копия в мире.
var _dropped: Node3D


func _init(visual: Node3D, sword: Node3D) -> void:
	sword_pivot = sword
	_grip_base = sword.position
	_build_bow(visual)
	rest()


## Взмах стадии удара: от позы from к позе to в активное окно стадии.
func swing(step: AttackStep) -> void:
	kill()
	sword_pivot.rotation = Vector3(0.0, step.blade_yaw_from, step.blade_from)
	sword_pivot.position = _grip(step.grip_from)
	var time := step.active_to - step.active_from
	_tween = sword_pivot.create_tween().set_parallel()
	var targets := {
		"rotation:z": step.blade_to, "rotation:y": step.blade_yaw_to, "position": _grip(step.grip_to),
	}
	for prop: String in targets:
		_tween.tween_property(sword_pivot, prop, targets[prop], time) \
			.set_delay(step.active_from).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Плавно перевести клинок в позу (фазы добивания).
func tween_blade(blade: float, grip: Vector2, time: float, trans: Tween.TransitionType) -> void:
	kill()
	_tween = sword_pivot.create_tween().set_parallel()
	_tween.tween_property(sword_pivot, "rotation:z", blade, time).set_trans(trans)
	_tween.tween_property(sword_pivot, "rotation:y", 0.0, time).set_trans(trans)
	_tween.tween_property(sword_pivot, "position", _grip(grip), time).set_trans(trans)


func point_down() -> void:
	kill()
	sword_pivot.rotation = Vector3(0.0, 0.0, PI)


func rest() -> void:
	kill()
	sword_pivot.rotation = Vector3(0.0, 0.0, 0.5)
	sword_pivot.position = _grip_base


## Стойка блока: клинок наискось перед собой.
func guard() -> void:
	kill()
	sword_pivot.rotation = Vector3(0.0, 0.0, -0.75)
	sword_pivot.position = _grip(Vector2(0.2, 0.05))


## Блок пробит: клинок отброшен за спину.
func guard_broken() -> void:
	kill()
	sword_pivot.rotation = Vector3(0.0, 0.0, 1.5)


## На время стрельбы меч убран, в руке лук.
func show_bow(on: bool) -> void:
	_bow.visible = on
	sword_pivot.visible = not on


## Натяжение 0…1 и угол прицела.
func draw_bow(draw_t: float, angle: float) -> void:
	_nocked.position.x = 0.3 - 0.35 * draw_t
	_bow.rotation.z = angle


## Смерть: оружие выпадает из руки и ложится плашмя на пол — так ложится любое оружие,
## и меч, и копьё (остриём вниз копьё пробило бы пол). Упирается в стену — сдвигается от неё.
func drop_weapon(world: Node, facing: float) -> void:
	restore_weapon()
	kill()
	_dropped = sword_pivot.duplicate() as Node3D
	world.add_child(_dropped)
	_dropped.global_transform = sword_pivot.global_transform
	sword_pivot.visible = false
	var box := _local_aabb(_dropped)
	var space := sword_pivot.get_world_3d().direct_space_state
	var from := _dropped.global_position
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		from, from + Vector3.DOWN * 6.0, WORLD_MASK))
	var floor_y: float = floor_hit.position.y if floor_hit else from.y - 1.0
	# Лежит вдоль пола по взгляду, опираясь на гарду: плоскость наклонена к камере —
	# совсем плашмя клинок с камеры почти не виден.
	var along := Vector3(facing, 0.0, 0.0)
	var face := Vector3(0.0, cos(LYING_TILT), sin(LYING_TILT))
	var lying := Basis(along.cross(face), along, face)
	var rest := Vector3(from.x, floor_y - _lowest(box, lying), from.z)
	# Клинок или рукоять не должны уйти в стену.
	var probe_y := floor_y + 0.1
	var tip := _ray_along(space, rest.x, probe_y, facing * box.end.y)
	if tip:
		rest.x = tip.position.x - facing * (box.end.y + 0.02)
	var butt := _ray_along(space, rest.x, probe_y, facing * box.position.y)
	if butt:
		rest.x = butt.position.x - facing * (box.position.y - 0.02)
	var fall := clampf(sqrt(2.0 * maxf(from.y - rest.y, 0.05) / 30.0), 0.18, 0.5)
	var tween := _dropped.create_tween()
	tween.set_parallel()
	tween.tween_property(_dropped, "global_position", rest, fall) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_dropped, "quaternion", lying.get_rotation_quaternion(), fall)
	tween.chain().tween_callback(func() -> void: Sfx.play(&"weapon_drop", rest))
	# Короткий отскок.
	tween.chain().tween_property(_dropped, "global_position", rest + Vector3(0.0, 0.05, 0.0), 0.06)
	tween.chain().tween_property(_dropped, "global_position", rest, 0.08).set_trans(Tween.TRANS_QUAD)


## Возрождение: оружие снова в руке.
func restore_weapon() -> void:
	if is_instance_valid(_dropped):
		_dropped.queue_free()
	_dropped = null
	sword_pivot.visible = true
	rest()


## Лежит ли выпавшее оружие (для тестов): копия в мире или null.
func dropped_weapon() -> Node3D:
	return _dropped if is_instance_valid(_dropped) else null


func kill() -> void:
	if _tween:
		_tween.kill()


func _ray_along(space: PhysicsDirectSpaceState3D, x: float, y: float, length: float) -> Dictionary:
	var from := Vector3(x, y, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(length, 0.0, 0.0), WORLD_MASK)
	return space.intersect_ray(query)


## Самая низкая точка габаритов при повороте basis (относительно начала оружия).
func _lowest(box: AABB, basis: Basis) -> float:
	var low := INF
	for i in 8:
		low = minf(low, (basis * box.get_endpoint(i)).y)
	return low


## Габариты всех мешей оружия в его собственных координатах.
func _local_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in root.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		var part := mesh.transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


func _grip(offset: Vector2) -> Vector3:
	return _grip_base + Vector3(offset.x, offset.y, 0.0)


func _build_bow(visual: Node3D) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.18)
	_bow = Node3D.new()
	_bow.position = Vector3(0.35, 1.25, 0.35)
	visual.add_child(_bow)
	var limb := MeshInstance3D.new()
	var limb_mesh := BoxMesh.new()
	limb_mesh.size = Vector3(0.06, 1.2, 0.05)
	limb_mesh.material = wood
	limb.mesh = limb_mesh
	limb.position.x = 0.15
	_bow.add_child(limb)
	var nocked := MeshInstance3D.new()
	var arrow_mesh := BoxMesh.new()
	arrow_mesh.size = Vector3(0.75, 0.035, 0.035)
	arrow_mesh.material = wood
	nocked.mesh = arrow_mesh
	_bow.add_child(nocked)
	_nocked = nocked
	_bow.visible = false
