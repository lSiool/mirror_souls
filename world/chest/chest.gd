class_name Chest
extends Interactable
## Сундук с отзвуками (валюта). Открытый сундук остаётся открытым после смерти:
## мир постоянен (§8.5).
## По сундуку можно ударить (свой Hurtbox: меч, стрела, брошенный нож) — глухой стук. Отравленный (§8.14)
## при этом шипит: игла в замке выпускает яд впустую, и открыть его уже безопасно. Не проверил — открыл:
## игла колет, из щелей валит ядовитое облако. Подсказки рядом: зелёные потёки по стенке, дохлая крыса.

const LAYER_HITTABLE := 1 << 2
const POISON_GREEN := Color(0.36, 0.55, 0.14)
## Склянка, чьё облако валит из отравленного сундука.
const POISON_CLOUD := &"poison_flask"
const NEEDLE_DAMAGE := 8.0
const NEEDLE_POISON := 8.0

@export var reward := 50
## Редкие предметы в сундуке (GameState.add_item); пусто — только отзвуки. Повтор id — несколько штук.
@export var items: Array[StringName] = []
## Уникальный флаг мира. Пусто — сундук закрывается снова при перезагрузке комнаты.
@export var flag_id: StringName
## Ловушка в замке (§8.14): открыл, не проверив, — игла и облако яда.
@export var poisoned := false

var opened := false
## Ловушка ещё взведена (не сработала и не выпущена ударом).
var trap_armed := false

@onready var lid: Node3D = $Lid


func _ready() -> void:
	super()
	prompt = "Открыть сундук"
	trap_armed = poisoned
	var hurtbox := Hurtbox.new()
	hurtbox.name = &"Hurtbox"
	hurtbox.collision_layer = LAYER_HITTABLE
	hurtbox.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.9, 0.8)
	shape.shape = box
	shape.position.y = 0.45
	hurtbox.add_child(shape)
	add_child(hurtbox)
	hurtbox.hurt.connect(_on_struck)
	if poisoned:
		_poison_hints()
	if flag_id != &"" and GameState.has_flag(flag_id):
		_open(false)


func interact(by: Player) -> void:
	if opened:
		return
	_open(true)
	if trap_armed:
		_spring(by)
	Sfx.play(&"chest_open", global_position)
	Sfx.play(&"chest_loot", global_position, -4.0)
	GameState.add_echoes(reward)
	# Одинаковые предметы — одной находкой: «Метательный нож ×5», а не пять окон подряд.
	var counts := {}
	for item in items:
		counts[item] = counts.get(item, 0) + 1
	for item: StringName in counts:
		GameState.add_item(item, counts[item])
	if flag_id != &"":
		GameState.set_flag(flag_id)
	HitSpark.spawn(get_parent(), global_position + Vector3(0, 0.8, 0.3), Color(1.0, 0.85, 0.35), 24)


## Ударили по сундуку: глухой стук; отравленный — шипит, яд выходит впустую.
func _on_struck(_hitbox: Hitbox) -> void:
	if opened:
		return
	if not trap_armed:
		Sfx.play(&"prop_hit_wood", global_position + Vector3(0.0, 0.5, 0.0))
		return
	trap_armed = false
	Sfx.play(&"chest_hiss", global_position + Vector3(0.0, 0.5, 0.0))
	# Струйка яда из замка вверх — не облако: стоящего рядом не задевает.
	HitSpark.spawn(get_parent(), global_position + Vector3(0.0, 0.9, 0.4), POISON_GREEN, 18)


## Открыл взведённый: игла колет, из щелей валит ядовитое облако.
func _spring(by: Player) -> void:
	trap_armed = false
	Sfx.play(&"chest_hiss", global_position + Vector3(0.0, 0.5, 0.0))
	if by and not by.is_dead():
		by.health.take_damage(NEEDLE_DAMAGE, true)
		by.statuses.apply(Statuses.POISON, NEEDLE_POISON)
	var cloud := ConsumableData.by_id(POISON_CLOUD)
	if cloud:
		FlaskZone.spawn(get_parent(), global_position + Vector3(0.0, 0.4, 0.0), cloud)


## Зелёные потёки по передней стенке и у замка, дохлая крыса рядом: внимательный заметит.
func _poison_hints() -> void:
	var slime := StandardMaterial3D.new()
	slime.albedo_color = POISON_GREEN
	slime.roughness = 0.2
	for i in 3:
		var drip := MeshInstance3D.new()
		var drip_box := BoxMesh.new()
		drip_box.size = Vector3(0.05, 0.22 + 0.1 * (i % 2), 0.01)
		drip_box.material = slime
		drip.mesh = drip_box
		drip.position = Vector3(-0.25 + i * 0.25, 0.42 - 0.05 * i, 0.356)
		add_child(drip)
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.22, 0.2, 0.18)
	var rat := MeshInstance3D.new()
	var rat_box := BoxMesh.new()
	rat_box.size = Vector3(0.32, 0.12, 0.14)
	rat_box.material = fur
	rat.mesh = rat_box
	rat.position = Vector3(0.85, 0.06, 0.3)
	rat.rotation = Vector3(0.0, 0.4, PI * 0.9)
	add_child(rat)
	var tail := MeshInstance3D.new()
	var tail_box := BoxMesh.new()
	tail_box.size = Vector3(0.28, 0.02, 0.02)
	tail_box.material = fur
	tail.mesh = tail_box
	tail.position = Vector3(1.12, 0.02, 0.38)
	tail.rotation.y = 0.6
	add_child(tail)


func _open(animate: bool) -> void:
	opened = true
	enabled = false
	if animate:
		create_tween().tween_property(lid, "rotation:x", -1.9, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		lid.rotation.x = -1.9
