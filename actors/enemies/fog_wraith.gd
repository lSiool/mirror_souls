class_name FogWraith
extends Bat
## Призрак корневого лабиринта (§8.9, кадр 4): кружит в тумане, издали видны только глаза.
## Чем ближе — тем плотнее тело. Пикирует как летучая мышь, только быстрее.

const FAR_ALPHA := 0.06
const NEAR_ALPHA := 0.55
const SEEN_RANGE := 7.0

var _wing_materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	super()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for wing in [wing_left, wing_right]:
		var mesh := wing as MeshInstance3D
		var material := (mesh.get_active_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = material
		_wing_materials.append(material)


func _physics_process(delta: float) -> void:
	super(delta)
	var alpha := FAR_ALPHA
	if _player:
		var distance := global_position.distance_to(_player.global_position)
		alpha = lerpf(NEAR_ALPHA, FAR_ALPHA, clampf(distance / SEEN_RANGE, 0.0, 1.0))
	if state == State.WINDUP or state == State.ATTACK:
		alpha = NEAR_ALPHA
	body_color.a = alpha
	for material in _wing_materials:
		material.albedo_color.a = alpha
