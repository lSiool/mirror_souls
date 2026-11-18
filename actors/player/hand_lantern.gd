class_name HandLantern
extends Node3D
## Фонарь фонарщика (§8.13, катакомбы): светит вокруг героя и зажигает свечи (WallCandle).
## Занимает левую руку вместо щита; когда рука занята (двуручное оружие, лук, лестница, уступ, крюк) —
## висит на поясе и светит оттуда. Сам фонарь всегда висит отвесно, как бы ни шла рука.

enum At { NONE, HAND, BELT }

const LIGHT_COLOR := Color(1.0, 0.64, 0.3)
const LIGHT_ENERGY := 3.0
const LIGHT_RANGE := 10.0
## Огонёк дрожит: доля силы света.
const FLICKER := 0.12
## Корпус ниже ручки, м.
const HANG := 0.17

var at := At.NONE
var light: OmniLight3D
var _t := 0.0


func _init() -> void:
	name = &"HandLantern"
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.09, 0.08, 0.08)
	iron.roughness = 0.7
	iron.metallic = 0.4
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1.0, 0.7, 0.35)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.62, 0.28)
	glass.emission_energy_multiplier = 4.0
	_part(Vector3(0.012, 0.09, 0.012), iron, Vector3(0.0, -0.045, 0.0))
	_part(Vector3(0.15, 0.03, 0.15), iron, Vector3(0.0, -0.09, 0.0))
	_part(Vector3(0.11, 0.15, 0.11), glass, Vector3(0.0, -HANG, 0.0))
	for i in 4:
		var corner := Vector3(0.06 if i % 2 else -0.06, -HANG, 0.06 if i < 2 else -0.06)
		_part(Vector3(0.015, 0.17, 0.015), iron, corner)
	_part(Vector3(0.14, 0.03, 0.14), iron, Vector3(0.0, -HANG - 0.09, 0.0))
	light = OmniLight3D.new()
	light.light_color = LIGHT_COLOR
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.omni_attenuation = 1.2
	light.position = Vector3(0.0, -HANG, 0.25)
	add_child(light)
	visible = false


func _part(size: Vector3, mat: Material, pos: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mesh.mesh = box
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


## Куда повесить фонарь: в руку (hand), на пояс (belt) или убрать.
func place(where: At, hand: Node3D, belt: Node3D) -> void:
	at = where
	visible = where != At.NONE
	var mount := hand if where == At.HAND else belt
	if where != At.NONE and mount and get_parent() != mount:
		if get_parent():
			reparent(mount, false)
		else:
			mount.add_child(self)
		transform = Transform3D.IDENTITY


func is_lit() -> bool:
	return visible and is_inside_tree()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# Отвесно: ручка в ладони, корпус под ней.
	global_basis = Basis.IDENTITY
	light.light_energy = LIGHT_ENERGY * (1.0 + FLICKER * (sin(_t * 13.0) * 0.6 + sin(_t * 5.3) * 0.4))
