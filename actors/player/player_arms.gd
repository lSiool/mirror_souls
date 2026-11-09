class_name PlayerArms
extends RefCounted
## Руки героя: позы и взмахи оружия, лук и щит. Заглушка до настоящей анимации модели.
## Поза задаётся в пространстве героя, смотрящего вправо (см. AttackStep).

const WORLD_MASK := 1
## Наклон плоскости лежащего оружия от пола к камере, рад.
const LYING_TILT := 1.05
## Щит-гоплон: радиус, толщина диска, насколько выпукла середина.
const SHIELD_RADIUS := 0.42
const SHIELD_THICK := 0.05
const SHIELD_DOME := 0.12

## Замах и доводка взмаха (§6.1, 2026-11-09): клинок отводят дальше позы from и держат,
## после удара он по инерции проходит дальше позы to. Замах короче WINDUP_MIN — без отвода.
const WINDUP_MIN := 0.08
const WINDUP_SHARE := 0.7
const WINDUP_BLADE := 0.4
const WINDUP_GRIP := 0.12
const FOLLOW_BLADE := 0.25
const FOLLOW_GRIP := 0.1
const FOLLOW_TIME := 0.07
const FOLLOW_HOLD := 0.05

enum ShieldAt { NONE, HAND, GUARD, BACK }

var sword_pivot: Node3D
var _grip_base: Vector3
var _tween: Tween
var _bow: Node3D
var _nocked: Node3D
## Выпавшее при смерти оружие — копия в мире.
var _dropped: Node3D
## Есть ли что-то в руке: безоружный герой клинка не показывает.
var armed := true
var _weapon: WeaponData
var _head: MeshInstance3D
var _shield: Node3D
var shield_at := ShieldAt.NONE
## Рука модели героя (HeroModel.hand): там видимая копия оружия. Сам sword_pivot тогда
## полностью прозрачен — его позы остаются для логики и тестов (§3.3, 2026-11-09).
## Не слой 0: с ним рендер Godot 4.7 падал при смене оружия («did not unpair geometries
## from light») — так зависала игра на подборе подсвечника.
var hand: Node3D
## Модель героя: щит и лук висят на её костях, а не у капсулы.
var _model: HeroModel


func _init(visual: Node3D, sword: Node3D) -> void:
	sword_pivot = sword
	_grip_base = sword.position
	_build_bow(visual)
	_build_shield(visual)
	rest()


## Взмах стадии удара в четыре фазы: замах (клинок из текущей позы отводят дальше позы from
## и держат) → удар к позе to в активное окно → доводка по инерции → возврат в стойку.
func swing(step: AttackStep) -> void:
	kill()
	# Куда идёт взмах: «+» — клинок идёт вперёд (угол убывает). Выпад (from = to) — только рукоять.
	var dir := signf(step.blade_from - step.blade_to)
	var heavy_rest := step.recover_from > step.active_to and step.duration > step.recover_from
	_tween = sword_pivot.create_tween().set_parallel()
	if step.active_from >= WINDUP_MIN:
		var draw := step.active_from * WINDUP_SHARE
		_pose(step.blade_from + dir * WINDUP_BLADE, step.blade_yaw_from,
			step.grip_from + Vector2(-WINDUP_GRIP, 0.0), draw, Tween.TRANS_SINE)
		_tween.chain().tween_interval(step.active_from - draw)
	else:
		sword_pivot.rotation = Vector3(0.0, step.blade_yaw_from, step.blade_from)
		sword_pivot.position = _grip(step.grip_from)
		_tween.tween_interval(step.active_from)
	_tween.chain()
	_pose(step.blade_to, step.blade_yaw_to, step.grip_to, step.active_to - step.active_from, Tween.TRANS_QUAD)
	var settled := step.active_to
	# Доводка: лёгкое оружие проходит дальше по инерции. Тяжёлое и так лежит в конце взмаха.
	if not heavy_rest:
		_tween.chain()
		_pose(step.blade_to - dir * FOLLOW_BLADE, step.blade_yaw_to,
			step.grip_to + Vector2(FOLLOW_GRIP, 0.0), FOLLOW_TIME, Tween.TRANS_SINE)
		settled += FOLLOW_TIME
	# Тяжёлое оружие лежит в конце взмаха до recover_from; лёгкое — миг, потом плавно в стойку.
	var back_from := step.recover_from if heavy_rest else settled + FOLLOW_HOLD
	var back := step.duration - back_from
	if back > 0.04:
		_tween.chain().tween_interval(back_from - settled)
		_tween.chain()
		_pose(_rest_blade(), 0.0, _rest_grip(), back, Tween.TRANS_SINE)


## Шаг твина: клинок, поворот и рукоять — одновременно, с замедлением к концу.
func _pose(blade: float, yaw: float, grip: Vector2, time: float, trans: Tween.TransitionType) -> void:
	_tween.tween_property(sword_pivot, "rotation:z", blade, time).set_trans(trans).set_ease(Tween.EASE_OUT)
	_tween.tween_property(sword_pivot, "rotation:y", yaw, time).set_trans(trans).set_ease(Tween.EASE_OUT)
	_tween.tween_property(sword_pivot, "position", _grip(grip), time).set_trans(trans).set_ease(Tween.EASE_OUT)


## Заряд: клинок отведён назад, вдоль плеча.
func charge_pose() -> void:
	kill()
	sword_pivot.rotation = Vector3(0.0, 0.0, _weapon.charge_blade if _weapon else 1.9)
	sword_pivot.position = _grip(_weapon.charge_grip if _weapon else Vector2(-0.35, 0.05))


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
	sword_pivot.rotation = Vector3(0.0, 0.0, _rest_blade())
	sword_pivot.position = _grip(_rest_grip())


## Стойка блока: клинок наискось перед собой, молот — низко поперёк.
func guard() -> void:
	kill()
	sword_pivot.rotation = Vector3(0.0, 0.0, _weapon.guard_blade if _weapon else -0.75)
	sword_pivot.position = _grip(_weapon.guard_grip if _weapon else Vector2(0.2, 0.05))


## Блок пробит: клинок отброшен за спину.
func guard_broken() -> void:
	kill()
	sword_pivot.rotation = Vector3(0.0, 0.0, 1.5)


## Взять оружие в руку: заглушка клинка принимает его вид. null — руки пусты.
func set_weapon(weapon: WeaponData) -> void:
	_weapon = weapon
	armed = weapon != null
	sword_pivot.visible = armed
	if is_instance_valid(_head):
		_head.free()
	if weapon == null:
		return
	var blade := sword_pivot.get_child(0) as MeshInstance3D
	if blade == null:
		return
	blade.scale = weapon.look_scale
	blade.position.y = 0.6 * weapon.look_scale.y
	var mat: StandardMaterial3D = null
	if weapon.look_color.a > 0.0:
		mat = StandardMaterial3D.new()
		mat.albedo_color = weapon.look_color
	blade.material_override = mat
	if weapon.head_size != Vector3.ZERO:
		var box := BoxMesh.new()
		box.size = weapon.head_size
		_head = MeshInstance3D.new()
		_head.name = &"Head"
		_head.mesh = box
		_head.material_override = mat
		# Навершие — на конце древка (меш клинка 1.1 по высоте, от рукояти).
		_head.position.y = blade.position.y + 0.55 * weapon.look_scale.y - weapon.head_size.y * 0.5
		sword_pivot.add_child(_head)
	_sync_hand()
	rest()


## Оружие — в руку модели: видимая копия там, у sword_pivot — только позы. Щит — на левое
## предплечье или за спину, лук — в левую руку.
func attach_model(model: HeroModel) -> void:
	_model = model
	hand = model.hand
	_sync_hand()
	_bow.reparent(model.bow_grip, false)
	_bow.transform = Transform3D.IDENTITY
	place_shield(shield_at)


func _sync_hand() -> void:
	if hand == null:
		return
	for old in hand.get_children():
		hand.remove_child(old)
		old.queue_free()
	for part in sword_pivot.get_children():
		var copy := part.duplicate() as Node3D
		hand.add_child(copy)
		ghost(copy, false)
	ghost(sword_pivot, true)
	hand.visible = sword_pivot.visible


## Спрятать от камеры, не выключая узел: полностью прозрачен и без тени.
static func ghost(node: Node, on: bool) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.transparency = 1.0 if on else 0.0
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if on 			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		ghost(child, on)


## Узел щита — для копии на манекене в «Снаряжении».
func shield_node() -> Node3D:
	return _shield


## Где щит: в руке, выставлен в блоке, за спиной или его нет.
func place_shield(at: ShieldAt) -> void:
	shield_at = at
	_shield.visible = at != ShieldAt.NONE
	if _model:
		var mount := _model.back_mount if at == ShieldAt.BACK else _model.shield_mount
		if _shield.get_parent() != mount:
			_shield.reparent(mount, false)
		_shield.transform = Transform3D.IDENTITY
		return
	match at:
		ShieldAt.HAND:
			_shield.position = Vector3(0.32, 1.1, 0.1)
			_shield.rotation = Vector3.ZERO
		ShieldAt.GUARD:
			_shield.position = Vector3(0.5, 1.2, 0.15)
			_shield.rotation = Vector3.ZERO
		ShieldAt.BACK:
			_shield.position = Vector3(-0.3, 1.2, 0.0)
			_shield.rotation = Vector3(0.0, PI, 0.2)


## На время стрельбы меч убран, в руке лук.
func show_bow(on: bool) -> void:
	_bow.visible = on
	sword_pivot.visible = armed and not on
	if hand:
		hand.visible = armed and not on


## Натяжение 0…1 и угол прицела.
func draw_bow(draw_t: float, angle: float) -> void:
	_nocked.position.x = 0.3 - 0.35 * draw_t
	# На модели лук держит рука — прицел задаёт поза (HeroModel), а не поворот лука.
	if _model == null:
		_bow.rotation.z = angle


## Смерть: оружие выпадает из руки и ложится плашмя на пол — так ложится любое оружие,
## и меч, и копьё (остриём вниз копьё пробило бы пол). Упирается в стену — сдвигается от неё.
func drop_weapon(world: Node, facing: float) -> void:
	restore_weapon()
	kill()
	_dropped = sword_pivot.duplicate() as Node3D
	ghost(_dropped, false)
	world.add_child(_dropped)
	if hand:
		hand.visible = false
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
	sword_pivot.visible = armed
	if hand:
		hand.visible = armed
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


func _rest_blade() -> float:
	return _weapon.rest_blade if _weapon else 0.5


func _rest_grip() -> Vector2:
	return _weapon.rest_grip if _weapon else Vector2.ZERO


## Гоплон: круглый диск, середина чуть выпукла наружу, бронзовый обод. Лицом по взгляду (+X).
func _build_shield(visual: Node3D) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.3, 0.17)
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.55, 0.4, 0.2)
	bronze.metallic = 0.5
	bronze.roughness = 0.5
	_shield = Node3D.new()
	_shield.name = &"Shield"
	visual.add_child(_shield)
	_shield.add_child(_shield_part(SHIELD_RADIUS, SHIELD_THICK, wood, 0.0))
	_shield.add_child(_shield_part(SHIELD_RADIUS + 0.04, SHIELD_THICK * 0.6, bronze, -SHIELD_THICK * 0.3))
	var dome := SphereMesh.new()
	dome.radius = SHIELD_RADIUS * 0.85
	dome.height = SHIELD_RADIUS * 1.7
	dome.radial_segments = 20
	dome.rings = 8
	dome.material = bronze
	var dome_mesh := MeshInstance3D.new()
	dome_mesh.mesh = dome
	dome_mesh.scale = Vector3(SHIELD_DOME / (SHIELD_RADIUS * 0.85), 1.0, 1.0)
	dome_mesh.position.x = SHIELD_THICK * 0.5
	_shield.add_child(dome_mesh)
	_shield.visible = false


## Диск щита: цилиндр, положенный осью по взгляду.
func _shield_part(radius: float, thick: float, mat: Material, x: float) -> MeshInstance3D:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = thick
	disc.radial_segments = 20
	disc.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = disc
	mesh.rotation.z = PI * 0.5
	mesh.position.x = x
	return mesh


func _build_bow(visual: Node3D) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.18)
	_bow = Node3D.new()
	_bow.name = &"Bow"
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
