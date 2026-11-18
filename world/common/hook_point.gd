class_name HookPoint
extends Node3D
## Точка зацепа крюка на цепи (§5, §8.13): железное кольцо в мире. Крюк есть — кольцо в досягаемости
## слабо светится, выбранное — ярче. Как у Mandragora: в прыжке у кольца кнопка крюка (или перекат в воздухе)
## выстреливает цепь. Что дальше — по виду кольца:
## PULL — притягивает к кольцу и бросает дальше по ходу: перелететь пропасть;
## SWING — раскачивает на цепи, пока кнопка зажата; отпустил или прыгнул — летит с набранной скоростью;
## WALL — кольцо на кромке стены: подтягивает к нему и перебрасывает наверх.

enum Kind { PULL, SWING, WALL }

const IRON := Color(0.16, 0.15, 0.15)
const GLINT := Color(1.0, 0.78, 0.45)

@export var kind := Kind.PULL

var _ring: MeshInstance3D
var _material: StandardMaterial3D
## 0 — не видно крюку, 1 — в досягаемости, 2 — выбрано.
var _shine := 0


func _ready() -> void:
	add_to_group(&"hook_point")
	_material = StandardMaterial3D.new()
	_material.albedo_color = IRON
	_material.metallic = 0.7
	_material.roughness = 0.45
	_material.emission_enabled = true
	_material.emission = GLINT
	_material.emission_energy_multiplier = 0.0
	# Кольцо лицом к камере, на коротком кованом креплении: у стены — из стены, иначе — сверху.
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.17
	torus.outer_radius = 0.27
	torus.rings = 16
	torus.ring_segments = 8
	_ring.mesh = torus
	_ring.rotation.x = PI * 0.5
	_ring.material_override = _material
	add_child(_ring)
	var mount := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.09, 0.42, 0.09) if kind != Kind.WALL else Vector3(0.42, 0.09, 0.09)
	mount.mesh = bar
	mount.position = Vector3(0, 0.42, 0) if kind != Kind.WALL else Vector3(0.0, 0.0, -0.3)
	mount.material_override = _material
	add_child(mount)


## Подсветка: крюк дотянется (1) или выбран (2).
func set_shine(level: int) -> void:
	if level == _shine:
		return
	_shine = level
	_material.emission_energy_multiplier = [0.0, 0.5, 2.2][level]
	_ring.scale = Vector3.ONE * (1.25 if level == 2 else 1.0)


func shine() -> int:
	return _shine
