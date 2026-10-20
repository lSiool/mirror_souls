class_name PlayerArms
extends RefCounted
## Руки героя: позы и взмахи меча, лук. Заглушка до настоящей анимации модели.
## Поза задаётся в пространстве героя, смотрящего вправо (см. AttackStep).

var sword_pivot: Node3D
var _grip_base: Vector3
var _tween: Tween
var _bow: Node3D
var _nocked: Node3D


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


func kill() -> void:
	if _tween:
		_tween.kill()


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
