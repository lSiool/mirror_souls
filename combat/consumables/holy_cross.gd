class_name HolyCross
extends Node3D
## Крест из света над нежитью, которую задела святая склянка (§6.2): возникает маленьким,
## растёт до пика яркости, затем гаснет и исчезает.

const COLOR := Color(1.0, 0.92, 0.6)
const GROW_TIME := 0.35
const FADE_TIME := 0.6
const PEAK_ENERGY := 4.0

var _material: StandardMaterial3D
var _light: OmniLight3D
var _glow := 0.0:
	set(value):
		_glow = value
		_material.albedo_color = Color(COLOR * (0.6 + value), value)
		_light.light_energy = PEAK_ENERGY * value


static func spawn(parent: Node, at: Vector3, height := 1.8) -> HolyCross:
	var cross := HolyCross.new()
	cross._build(height)
	parent.add_child(cross)
	cross.global_position = at + Vector3(0.0, 0.0, 0.45)
	cross._play()
	return cross


func _build(height: float) -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var beams := [Vector3(0.18, height, 0.05), Vector3(height * 0.62, 0.18, 0.05)]
	for i in beams.size():
		var box := BoxMesh.new()
		box.size = beams[i]
		box.material = _material
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.position.y = height * (0.5 if i == 0 else 0.68)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.omni_range = 5.0
	_light.position.y = height * 0.65
	add_child(_light)
	_glow = 0.0


func _play() -> void:
	scale = Vector3.ONE * 0.3
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 1.15, GROW_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_glow", 1.0, GROW_TIME)
	tween.chain().tween_property(self, "_glow", 0.0, FADE_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
