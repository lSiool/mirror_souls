class_name GiantBat
extends Node3D
## Огромная летучая мышь — вторая форма вампира (§6.3, 2026-11-09; образ — «Ван Хельсинг», арт и
## 3D-модель — от автора позже). Только показывает: где она и что бьёт — у Vampire.
##
## Риг — настоящий Skeleton3D с именами костей гуманоидного профиля Godot (SkeletonProfileHumanoid):
## мышь антропоморфная — руки стали крыльями, пальцы — спицами перепонки (большой — коготь на
## сгибе, указательный…мизинец — спицы), ноги с когтями. Покой — T-поза: стоит, смотрит в +Z,
## крылья раскинуты в плоскости XY. Будущая модель с тем же скелетом встаёт на место graybox,
## процедурные позы ниже работают и с ней (docs/rigs/giant_bat.md).
##
## Повёрнута головой к герою (в полёте — по скорости), в три четверти к камере — иначе крылья
## в 2.5D видны с ребра. Позы: полёт (тело горизонтально, взмахи), вис (тело стоймя, ноги висят),
## пике (крылья поджаты назад, ноги с когтями вперёд), открытая пасть в крике.

## Где центр тела (Hips) над началом узла: сюда Vampire ставит середину мыши.
const CENTER := 0.9
## Насколько повёрнута к камере (рад): 0 — строго в профиль.
const VIEW := 0.45
## Крен к камере в горизонтальном полёте (рад).
const BANK := 0.6
const FLAP_SPEED := 9.0
const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Little"]
## Кончики пальцев крыла (от кисти, левое крыло; правое — зеркально по X).
const FINGER_TIPS := {
	"Thumb": Vector3(0.1, 0.13, 0.06), "Index": Vector3(0.85, 0.25, 0.0), "Middle": Vector3(1.05, -0.1, 0.0),
	"Ring": Vector3(0.8, -0.55, 0.0), "Little": Vector3(0.4, -0.85, 0.0),
}

## Позы (0…1), их ставит Vampire: машет ли, вис стоймя, крылья поджаты, когти вперёд, глаза горят.
var flap := 1.0
var hover := 0.0
var tuck := 0.0
var claws := 0.0
var eyes_flare := 0.0
## Куда смотрит: +1 — вправо по X мира, -1 — влево.
var facing := 1.0
## Покой рига (T-поза, крылья раскинуты, смотрит в +Z) — для снимков и сверки модели.
var rest_pose := false
var skeleton: Skeleton3D
var body_material: StandardMaterial3D

var _eye_material: StandardMaterial3D
var _eyes: Array[MeshInstance3D] = []
var _membrane: MeshInstance3D
var _time := 0.0
var _pitch := 0.0
var _yaw := 0.0
var _roll := 0.0
var _bones := {}


static func build(parent: Node3D) -> GiantBat:
	var bat := GiantBat.new()
	bat.name = &"GiantBat"
	parent.add_child(bat)
	bat._make()
	return bat


func _make() -> void:
	body_material = _flat(Color(0.14, 0.1, 0.1))
	body_material.emission_enabled = true
	body_material.emission = Color.BLACK
	_eye_material = _flat(Color(1.0, 0.1, 0.06))
	_eye_material.emission_enabled = true
	_eye_material.emission = Color(1.0, 0.08, 0.04)
	_eye_material.emission_energy_multiplier = 4.0
	skeleton = Skeleton3D.new()
	skeleton.name = &"Skeleton3D"
	skeleton.position.y = CENTER
	add_child(skeleton)
	_rig()
	_dress()
	_membrane = MeshInstance3D.new()
	_membrane.name = &"Membrane"
	_membrane.mesh = ImmediateMesh.new()
	var skin := _flat(Color(0.22, 0.09, 0.1))
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	_membrane.material_override = skin
	_membrane.top_level = true
	add_child(_membrane)
	_membrane.global_transform = Transform3D.IDENTITY
	_yaw = _target_yaw()


# --- Скелет (имена — SkeletonProfileHumanoid) -------------------------------------

func _rig() -> void:
	_add("Hips", "", Vector3.ZERO)
	_add("Spine", "Hips", Vector3(0.0, 0.15, 0.0))
	_add("Chest", "Spine", Vector3(0.0, 0.15, 0.0))
	_add("UpperChest", "Chest", Vector3(0.0, 0.15, 0.0))
	_add("Neck", "UpperChest", Vector3(0.0, 0.12, 0.0))
	_add("Head", "Neck", Vector3(0.0, 0.12, 0.0))
	_add("Jaw", "Head", Vector3(0.0, -0.05, 0.1))
	for side in ["Left", "Right"]:
		var s := 1.0 if side == "Left" else -1.0
		_add(side + "Shoulder", "UpperChest", Vector3(s * 0.08, 0.08, 0.0))
		_add(side + "UpperArm", side + "Shoulder", Vector3(s * 0.12, 0.0, 0.0))
		_add(side + "LowerArm", side + "UpperArm", Vector3(s * 0.5, 0.0, 0.0))
		_add(side + "Hand", side + "LowerArm", Vector3(s * 0.65, 0.0, 0.0))
		for finger: String in FINGERS:
			var tip: Vector3 = FINGER_TIPS[finger] * Vector3(s, 1.0, 1.0)
			var base := tip.normalized() * 0.04
			_add(side + finger + "Proximal", side + "Hand", base)
			_add(side + finger + "Intermediate", side + finger + "Proximal", (tip - base) * 0.55)
			_add(side + finger + "Distal", side + finger + "Intermediate", (tip - base) * 0.45)
		_add(side + "UpperLeg", "Hips", Vector3(s * 0.12, -0.1, 0.0))
		_add(side + "LowerLeg", side + "UpperLeg", Vector3(0.0, -0.36, 0.0))
		_add(side + "Foot", side + "LowerLeg", Vector3(0.0, -0.36, 0.0))
		_add(side + "Toes", side + "Foot", Vector3(0.0, -0.04, 0.12))


func _add(bone: String, parent: String, at: Vector3) -> void:
	var index := skeleton.add_bone(bone)
	if parent != "":
		skeleton.set_bone_parent(index, _bones[parent])
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, at))
	skeleton.set_bone_pose_position(index, at)
	_bones[bone] = index


## Graybox на костях: тело, голова с ушами, мордой, клыками и глазами, кости крыльев и ног.
func _dress() -> void:
	var bone := _flat(Color(0.08, 0.05, 0.06))
	_on("Hips").add_child(_part(CapsuleMesh, Vector3(0.2, 0.62, 0.0), Vector3(0.0, 0.22, 0.0), body_material))
	_on("Chest").add_child(_part(SphereMesh, Vector3(0.46, 0.5, 0.36), Vector3(0.0, 0.1, 0.04), _flat(Color(0.24, 0.17, 0.16))))
	var head := _on("Head")
	head.add_child(_part(SphereMesh, Vector3(0.4, 0.36, 0.38), Vector3(0.0, 0.1, 0.0), body_material))
	head.add_child(_part(BoxMesh, Vector3(0.16, 0.12, 0.2), Vector3(0.0, 0.06, 0.2), body_material))
	for x: float in [-1.0, 1.0]:
		head.add_child(_part(PrismMesh, Vector3(0.16, 0.34, 0.05), Vector3(x * 0.12, 0.36, -0.02), body_material, Vector3(0.0, 0.0, -x * 0.3)))
		var eye := _part(SphereMesh, Vector3(0.07, 0.05, 0.04), Vector3(x * 0.08, 0.14, 0.16), _eye_material)
		head.add_child(eye)
		_eyes.append(eye)
	var jaw := _on("Jaw")
	jaw.add_child(_part(BoxMesh, Vector3(0.14, 0.05, 0.16), Vector3(0.0, 0.0, 0.06), body_material))
	for x: float in [-1.0, 1.0]:
		jaw.add_child(_part(PrismMesh, Vector3(0.035, 0.08, 0.03), Vector3(x * 0.045, 0.06, 0.12), _flat(Color(0.85, 0.82, 0.75))))
	# Кости крыльев и ног — палки от сустава к следующему.
	for side in ["Left", "Right"]:
		_limb(side + "UpperArm", side + "LowerArm", 0.07, body_material)
		_limb(side + "LowerArm", side + "Hand", 0.05, bone)
		for finger: String in FINGERS:
			_limb(side + finger + "Proximal", side + finger + "Intermediate", 0.03, bone)
			_limb(side + finger + "Intermediate", side + finger + "Distal", 0.025, bone)
		_on(side + "ThumbDistal").add_child(_part(PrismMesh, Vector3(0.04, 0.1, 0.04), Vector3(0.0, 0.04, 0.0), _flat(Color(0.7, 0.66, 0.6))))
		_limb(side + "UpperLeg", side + "LowerLeg", 0.07, body_material)
		_limb(side + "LowerLeg", side + "Foot", 0.045, bone)
		var foot := _on(side + "Foot")
		for x: float in [-0.04, 0.0, 0.04]:
			foot.add_child(_part(PrismMesh, Vector3(0.03, 0.14, 0.03), Vector3(x, -0.03, 0.08), _flat(Color(0.7, 0.66, 0.6)), Vector3(PI * 0.5, 0.0, 0.0)))


func _on(bone: String) -> BoneAttachment3D:
	var node := skeleton.get_node_or_null(NodePath(bone)) as BoneAttachment3D
	if node:
		return node
	node = BoneAttachment3D.new()
	node.name = bone
	node.bone_name = bone
	skeleton.add_child(node)
	return node


## Палка от сустава bone до сустава child (покой: повороты костей нулевые).
func _limb(bone: String, child: String, radius: float, material: Material) -> void:
	var to := skeleton.get_bone_rest(_bones[child]).origin
	var rod := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = to.length()
	mesh.radial_segments = 6
	mesh.material = material
	rod.mesh = mesh
	rod.position = to * 0.5
	rod.basis = Basis(Quaternion(Vector3.UP, to.normalized()))
	_on(bone).add_child(rod)


# --- Каждый кадр -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if rest_pose:
		skeleton.reset_bone_poses()
	else:
		_pose()
	_update_membrane()
	_eye_material.emission_energy_multiplier = 4.0 + eyes_flare * 14.0
	for eye in _eyes:
		eye.scale = Vector3.ONE * (1.0 + eyes_flare)


## Направление и наклон по полёту: голова к герою (face_x) или по скорости, если летит быстро;
## пикирует — клонится носом вниз, набирает высоту — вверх.
func steer(velocity: Vector3, delta: float, face_x: float) -> void:
	if absf(velocity.x) > 3.0:
		facing = signf(velocity.x)
	elif face_x != 0.0:
		facing = signf(face_x)
	var climb := atan2(velocity.y, maxf(absf(velocity.x), 2.0)) if velocity.length() > 1.0 else 0.0
	_pitch = lerpf(_pitch, clampf(climb, -0.9, 0.9), 1.0 - exp(-8.0 * delta))
	_yaw = lerp_angle(_yaw, _target_yaw(), 1.0 - exp(-7.0 * delta))
	# В горизонтальном полёте — крен к камере: дальнее крыло выше, перепонка видна, а не ребро.
	_roll = lerpf(_roll, BANK * (1.0 - hover) * facing, 1.0 - exp(-6.0 * delta))
	skeleton.rotation = Vector3(0.0, _yaw, _roll)


## Голова (+Z скелета) — к facing, в три четверти к камере.
func _target_yaw() -> float:
	return (PI * 0.5 - VIEW) * facing


func _pose() -> void:
	var beat := sin(_time * FLAP_SPEED) * flap
	# Крыло идёт вверх — складывается (меньше сопротивления), вниз — раскрыто.
	var fold := maxf(0.0, cos(_time * FLAP_SPEED)) * 0.45 * flap + tuck * 0.9
	# Тело: в полёте горизонтально (голова вперёд), в висе — стоймя; плюс наклон по скорости.
	var body := lerpf(PI * 0.5, 0.25, hover) - _pitch
	_rot("Hips", Quaternion(Vector3.RIGHT, body) * Quaternion(Vector3.FORWARD, beat * 0.04))
	# Голова смотрит вперёд по горизонту, сколько бы ни клонилось тело.
	_rot("Neck", Quaternion(Vector3.RIGHT, -body * 0.55))
	_rot("Head", Quaternion(Vector3.RIGHT, -body * 0.35))
	_rot("Jaw", Quaternion(Vector3.RIGHT, 0.55 * eyes_flare))
	for side in ["Left", "Right"]:
		var s := 1.0 if side == "Left" else -1.0
		# Взмах — вокруг оси вперёд (Z), поджать назад — вокруг Y.
		var lift := beat * 0.75 + 0.15 + tuck * 0.35
		_rot(side + "UpperArm", Quaternion(Vector3.UP, s * (0.15 + tuck * 0.5)) * Quaternion(Vector3.BACK, s * lift))
		_rot(side + "LowerArm", Quaternion(Vector3.UP, s * fold * 0.9))
		_rot(side + "Hand", Quaternion(Vector3.UP, s * fold * 0.8) * Quaternion(Vector3.BACK, -s * beat * 0.25))
		for finger: String in FINGERS:
			_rot(side + finger + "Proximal", Quaternion(Vector3.UP, s * fold * 0.5))
		# Ноги: в полёте отведены назад, в висе висят, в пике — когтями вперёд.
		var leg := lerpf(0.25, -0.15, hover) - claws * 1.5
		_rot(side + "UpperLeg", Quaternion(Vector3.RIGHT, leg) * Quaternion(Vector3.BACK, s * (0.08 + claws * 0.12)))
		_rot(side + "LowerLeg", Quaternion(Vector3.RIGHT, 0.35 + claws * 0.4 - hover * 0.25))
		_rot(side + "Foot", Quaternion(Vector3.RIGHT, -0.4 * claws))


func _rot(bone: String, rotation_: Quaternion) -> void:
	skeleton.set_bone_pose_rotation(_bones[bone], rotation_)


func _at(bone: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(_bones[bone]).origin


## Перепонка по итоговой позе костей: плечо — локоть — кисть — кончики пальцев (фестоны между
## ними провисают к кисти) — щиколотка — бедро; между ног — хвостовая перепонка.
func _update_membrane() -> void:
	var mesh := _membrane.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in ["Left", "Right"]:
		var shoulder := _at(side + "UpperArm")
		var elbow := _at(side + "LowerArm")
		var hand := _at(side + "Hand")
		var ankle := _at(side + "Foot")
		var hip := _at(side + "UpperLeg")
		var chest := _at("Chest")
		var tips: Array[Vector3] = []
		for finger: String in ["Index", "Middle", "Ring", "Little"]:
			tips.append(_at(side + finger + "Distal"))
		_tri(mesh, shoulder, elbow, hand)
		_tri(mesh, shoulder, hand, tips[3])
		_tri(mesh, shoulder, tips[3], ankle)
		_tri(mesh, chest, shoulder, ankle)
		_tri(mesh, chest, ankle, hip)
		for i in 3:
			var scallop := tips[i].lerp(tips[i + 1], 0.5).lerp(hand, 0.25)
			_tri(mesh, hand, tips[i], scallop)
			_tri(mesh, hand, scallop, tips[i + 1])
		# Край от мизинца к щиколотке — фестоном.
		var hem := tips[3].lerp(ankle, 0.5).lerp(shoulder, 0.15)
		_tri(mesh, tips[3], hem, ankle)
	_tri(mesh, _at("Hips"), _at("LeftFoot"), _at("RightFoot"))
	mesh.surface_end()


func _tri(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for p in [a, b, c]:
		mesh.surface_set_normal(normal)
		mesh.surface_add_vertex(p)


## Свечение тела — как у врага: красное в замахе, белое от удара (ставит Vampire).
func glow(emission: Color, energy: float) -> void:
	body_material.emission = emission
	body_material.emission_energy_multiplier = energy


func _part(kind: Variant, size: Vector3, at: Vector3, material: Material, tilt := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh: PrimitiveMesh = kind.new()
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x * 0.5
		(mesh as SphereMesh).height = size.y
	elif mesh is CapsuleMesh:
		(mesh as CapsuleMesh).radius = size.x
		(mesh as CapsuleMesh).height = size.y
	elif mesh is PrismMesh:
		(mesh as PrismMesh).size = size
	mesh.material = material
	node.mesh = mesh
	node.position = at
	node.rotation = tilt
	if mesh is SphereMesh and size.z != size.x:
		node.scale.z = size.z / size.x
	return node


static func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
