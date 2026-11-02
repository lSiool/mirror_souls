class_name Blacksmith
extends Dummy
## Босс: Безмолвный Кузнец (§6.3). Проклятый старый знакомый кузнеца из хаба: в полтора раза выше
## человека, изуродован, не издаёт ни звука. Медленный и неумолимый: долго разворачивается, идёт
## тяжело, но его не сбить. Вес молота — в ритме: долгий замах, пауза наверху, резкое падение,
## и молот застревает в камне (окно для ответа). Удар сверху раскалывает пол: тряска, остановка
## кадра, каменная крошка, трещина и волна. Боковой — широкий, с шагом, молот тащит его за собой.
## Пока идёт, волочит молот по земле; замах читается по молоту, а не по цвету тела.
## Со второй половины здоровья злее. Побеждён один раз за игру (boss_flag).

const WAVE_SPEED := 9.0
const WAVE_TIME := 0.8
const WAVE_DAMAGE := 12.0
## Наклон молота (радианы от вертикали, вперёд — минус): волочится по земле за спиной, заведён
## над головой или назад, пришёл в пол или вперёд на уровень груди.
const POSE_DRAG := 2.5
const POSE_OVERHEAD := 0.35
const POSE_BACK := 1.7
const POSE_FLOOR := -2.5
const POSE_SWEPT := -1.9

enum Blow { SWEEP, SLAM }

## Флаг мира «побеждён»: открывает Главное Зеркало, отдых его не воскрешает.
@export var boss_flag: StringName = &"boss_smith"
@export var boss_name := "Безмолвный Кузнец"
@export var sweep_windup := 0.85
@export var slam_windup := 1.35
## Сколько молот сидит в камне после удара сверху и сколько возвращается после бокового.
@export var slam_stuck := 1.5
@export var sweep_recover := 0.9

var _blow := Blow.SWEEP
var _blows := 0
var _engaged := false

@onready var hammer: Node3D = $Visual/Hammer


func _ready() -> void:
	super()
	if GameState.has_flag(boss_flag):
		queue_free()


## Перед замахом — какой удар: каждый третий сверху, вблизи чаще боковой.
func _set_state(new_state: State) -> void:
	if new_state == State.WINDUP:
		_blows += 1
		_blow = Blow.SLAM if _blows % 3 == 0 else Blow.SWEEP
		var rage := 0.75 if _enraged() else 1.0
		windup_time = (slam_windup if _blow == Blow.SLAM else sweep_windup) * rage
		attack_lunge = 0.5 if _blow == Blow.SLAM else 7.5
		recover_time = (slam_stuck if _blow == Blow.SLAM else sweep_recover) * rage
		attack_hitbox.damage = 30.0 if _blow == Blow.SLAM else 18.0
	super(new_state)


func _on_attack_started() -> void:
	if _blow != Blow.SLAM:
		return
	# Удар о камень: заметно и без попадания по герою.
	Events.camera_shake_requested.emit(0.75, 0.4)
	HitStop.stop(0.07)
	Sfx.play(&"sword_block", global_position, 6.0)
	var impact := global_position + Vector3(facing * 2.0, 0.1, -0.3)
	HitSpark.spawn(get_parent(), impact, Color(0.5, 0.48, 0.45), 40)
	_leave_crack(impact)
	_spawn_wave(facing)
	if _enraged():
		_spawn_wave(-facing)


func _on_died() -> void:
	GameState.set_flag(boss_flag)
	super()


func _enraged() -> bool:
	return health.current < health.max_health * 0.5


## Молот: в замахе над головой, в ударе вниз; показывает, какой удар идёт.
func _update_extra(delta: float) -> void:
	if not _engaged and _player and state != State.DORMANT and _sees_player(detect_range, false):
		_engaged = true
		Events.boss_engaged.emit(self)
	# Модель стоит глубже героя (Visual в сцене), молот — между ними, куда бы босс ни смотрел.
	hammer.position.z = 0.75 * facing
	var down := POSE_FLOOR if _blow == Blow.SLAM else POSE_SWEPT
	var pose := POSE_DRAG
	var speed := 5.0
	match state:
		State.WINDUP:
			# Тяжело поднимает и держит наверху.
			pose = POSE_OVERHEAD if _blow == Blow.SLAM else POSE_BACK
			speed = 3.0
		State.ATTACK:
			pose = down
			speed = 40.0
		State.RECOVER:
			# Молот лежит, где упал, потом его с трудом вытаскивают.
			pose = down if _state_time < recover_time * 0.6 else POSE_DRAG
			speed = 3.0
	hammer.rotation.z = lerpf(hammer.rotation.z, pose, 1.0 - exp(-speed * delta))


## Трещина в камне остаётся до перезагрузки комнаты.
func _leave_crack(at: Vector3) -> void:
	var crack := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(2.6, 0.03, 1.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.02)
	plate.material = mat
	crack.mesh = plate
	get_parent().add_child(crack)
	crack.global_position = Vector3(at.x, global_position.y + 0.02, -0.4)
	crack.rotation.y = randf_range(-0.4, 0.4)


## Волна по полу: через неё перепрыгивают.
func _spawn_wave(dir: float) -> void:
	var wave := Hitbox.new()
	wave.collision_layer = 0
	wave.collision_mask = 2
	wave.damage = WAVE_DAMAGE
	wave.knockback = 5.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.7, 1.2)
	shape.shape = box
	shape.position.y = 0.35
	wave.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(0.9, 0.5, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.15)
	mat.emission_energy_multiplier = 2.5
	cube.material = mat
	mesh.mesh = cube
	mesh.position.y = 0.25
	wave.add_child(mesh)
	get_parent().add_child(wave)
	wave.global_position = Vector3(global_position.x + dir * 1.8, global_position.y, 0.0)
	wave.active = true
	var tween := wave.create_tween()
	tween.tween_property(wave, "global_position:x", wave.global_position.x + dir * WAVE_SPEED * WAVE_TIME, WAVE_TIME)
	tween.tween_callback(wave.queue_free)
