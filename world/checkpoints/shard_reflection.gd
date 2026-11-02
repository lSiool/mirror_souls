class_name ShardReflection
extends Node3D
## Отражение героя у осколка (§8.6): стеклянная копия с его оружием, чуть старше его самого.
## При новом уровне отзвуки текут в отражение, оно на мгновение заметно взрослеет,
## затем успокаивается — и прожитое переходит на героя. Вид по возрасту — AgeLook.

## Отражение всегда немного впереди героя (§7.4).
const AHEAD_YEARS := 2.0
## Насколько старше оно становится на миг при новом уровне: сам уровень — всего ¼ года,
## а игрок должен увидеть, куда ведут годы: плечи раздаются, волосы седеют.
const FORESHADOW_YEARS := 22.0
const SIDE_OFFSET := 1.7
const COLD_TINT := Color(0.72, 0.86, 1.0, 0.62)

var _body: MeshInstance3D
var _hair_material: StandardMaterial3D
var _caption: Label3D
var _shown_age := 0.0


## Рядом с героем, лицом к нему.
static func spawn(parent: Node3D, player: Player) -> ShardReflection:
	var reflection := ShardReflection.new()
	parent.add_child(reflection)
	reflection.global_position = player.global_position + Vector3(player.facing * SIDE_OFFSET, 0.0, -0.5)
	reflection._build(player)
	return reflection


func _build(player: Player) -> void:
	var copy := player.make_silhouette(player.held_weapon(), true)
	add_child(copy)
	copy.rotation.y = 0.0 if player.facing < 0.0 else PI
	_body = copy.find_child("Body", true, false) as MeshInstance3D
	for mesh: MeshInstance3D in copy.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _glass_of(mesh)
	var hair := copy.find_child("Hair", true, false) as MeshInstance3D
	if hair:
		# Волосы непрозрачные: сквозь стекло седину не разглядеть.
		_hair_material = hair.material_override
		_hair_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		_hair_material.emission_enabled = false
	_caption = Label3D.new()
	_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_caption.no_depth_test = true
	_caption.font_size = 40
	_caption.pixel_size = 0.008
	_caption.modulate = Color(0.75, 0.88, 1.0)
	_caption.position.y = 2.45
	add_child(_caption)
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.8, 1.0)
	light.light_energy = 0.7
	light.omni_range = 3.0
	light.position.y = 1.4
	add_child(light)
	show_age(player.stats.current_age + AHEAD_YEARS)
	# Проступает из воздуха.
	scale = Vector3(1.0, 0.0, 1.0)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_SINE)


func show_age(age: float) -> void:
	_shown_age = age
	if _body:
		_body.scale = AgeLook.body_scale(age)
		_body.position = Vector3(0.0, 0.9 * _body.scale.y, 0.0)
		_body.rotation = Vector3(0.0, 0.0, -AgeLook.stoop(age))
	if _hair_material:
		_hair_material.albedo_color = AgeLook.hair_color(age)
	if _caption:
		_caption.text = "%d лет" % int(age)


## Новый уровень: миг взрослости и возврат. Закончилось — можно переносить прожитое на героя.
func play_level_up(new_age: float) -> void:
	var tween := create_tween()
	tween.tween_method(show_age, _shown_age, new_age + FORESHADOW_YEARS, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.45)
	tween.tween_method(show_age, new_age + FORESHADOW_YEARS, new_age + AHEAD_YEARS, 0.35) \
		.set_trans(Tween.TRANS_SINE)
	await tween.finished


func dismiss() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.0, 0.0, 1.0), 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(queue_free)


## Тот же цвет, но стекло: холоднее и насквозь.
func _glass_of(mesh: MeshInstance3D) -> StandardMaterial3D:
	var source := mesh.get_active_material(0) as StandardMaterial3D
	var glass := source.duplicate() as StandardMaterial3D if source else StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = glass.albedo_color * COLD_TINT
	glass.emission_enabled = true
	glass.emission = Color(0.35, 0.55, 0.8)
	glass.emission_energy_multiplier = 0.35
	return glass
