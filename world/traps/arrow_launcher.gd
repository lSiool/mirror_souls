class_name ArrowLauncher
extends Node3D
## Стреломёт в стене (§8.14): тёмные щели в кладке; спуск (TrapTrigger: плита или растяжка) — залп вдоль хода.
## Стрелы те же, что у героя (Arrow + ArrowData): обычные, огненные (горение, поджигают смолу), отравленные,
## смоляные. Ловушка бьёт всех на пути: героя и врага, которого заманили на плиту. Перекат проходит сквозь залп.
## Узел стоит на полу у грани стены, из которой летят стрелы; щели — на высотах `heights`.

const STONE := Color(0.2, 0.19, 0.18)
const SLIT := Color(0.01, 0.01, 0.01)

## Особая стрела (id ArrowData, data/arrows); пусто — обычная.
@export var arrow_kind: StringName = &""
## Куда летят стрелы: +1 — вправо, −1 — влево.
@export var direction := 1.0
## Высоты щелей над полом.
@export var heights := PackedFloat32Array([0.5, 1.1, 1.65])
## Сколько залпов подряд и пауза между ними.
@export var volleys := 1
@export var interval := 0.18
@export var speed := 22.0
@export var damage := 16.0
## Сколько метров стрела летит в силе; дальше падает. Залп бьёт по плите и рядом, а не через весь зал.
@export var reach := 9.0
## Рисовать ли свой щиток со щелями (если стена комнаты своя — щели можно нарисовать генератором) и его цвет.
@export var with_face := true
@export var face_color := STONE


func _ready() -> void:
	if not with_face:
		return
	var stone := StandardMaterial3D.new()
	stone.albedo_color = face_color
	stone.roughness = 0.9
	var slit := StandardMaterial3D.new()
	slit.albedo_color = SLIT
	var top := heights[heights.size() - 1] if heights.size() > 0 else 1.6
	_box(Vector3(-direction * 0.2, (top + 0.5) * 0.5, -0.4), Vector3(0.4, top + 0.5, 3.4), stone)
	for h in heights:
		# Щель видна и спереди, и с торца, откуда летят стрелы.
		_box(Vector3(-direction * 0.2, h, 1.31), Vector3(0.3, 0.06, 0.02), slit)
		_box(Vector3(0.005 * direction, h, 0.0), Vector3(0.02, 0.07, 0.5), slit)


## Залп: из каждой щели по стреле, `volleys` раз.
func fire() -> void:
	var kind := ArrowData.by_id(arrow_kind) if arrow_kind != &"" else null
	Sfx.play(&"bow_release", global_position + Vector3(0.0, 1.0, 0.0))
	for volley in volleys:
		if not is_inside_tree():
			return
		for h in heights:
			var at := global_position + Vector3(direction * 0.15, h, 0.0)
			Arrow.spawn(get_parent(), at, Vector3(direction * speed, 0.0, 0.0), damage, 10.0, kind, true, reach)
		if volley < volleys - 1:
			await get_tree().create_timer(interval).timeout


func _box(at: Vector3, box_size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	box.material = material
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)
