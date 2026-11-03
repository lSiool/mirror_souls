class_name Rat
extends Dummy
## Крыса по образцу Mandragora: низкое длинное тело с горбом, морда у самой земли, длинный хвост
## из звеньев. Бегает рывками: метнулась, замерла, принюхалась. Перед укусом задирает хвост и
## прыгает дугой, укусив — отскакивает. Тому, кто стоит за спиной, достаётся хвостом.
## В стае держит расстояние от соседей. Погибнув, переворачивается на спину.

const BURST_RUN := 0.45
const BURST_PAUSE := 0.28
const LEAP_UP := 4.5
const RETREAT_SPEED := 4.0
const SPACING := 0.9
const TAIL_REACH := 1.5
const TAIL_COOLDOWN := 1.6

var _burst := 0.0
var _tail_strike := false
var _tail_wait := 0.0
var _time := 0.0

@onready var head: Node3D = $Visual/Head
@onready var tail: Node3D = $Visual/Tail
@onready var tail_hitbox: Hitbox = $Visual/TailHitbox
@onready var legs: Array[Node3D] = [$Visual/LegA, $Visual/LegB, $Visual/LegC, $Visual/LegD]


func _ready() -> void:
	super()
	_time = randf() * 5.0
	tail_hitbox.non_lethal = non_lethal


## Погоня рывками и с оглядкой на соседей; со спины — хвостом.
func _chase(delta: float) -> void:
	_tail_wait -= delta
	if _player and _tail_wait <= 0.0:
		var dx := _player.global_position.x - global_position.x
		if signf(dx) == -facing and absf(dx) < TAIL_REACH and absf(_player.global_position.y - global_position.y) < 1.0:
			_tail_strike = true
			_tail_wait = TAIL_COOLDOWN
			velocity.x = 0.0
			_set_state(State.WINDUP)
			return
	_tail_strike = false
	super(delta)
	if state != State.CHASE:
		return
	_burst += delta
	if _burst > BURST_RUN + BURST_PAUSE:
		_burst = 0.0
	if _burst > BURST_RUN or _crowded():
		velocity.x = 0.0


func _crowded() -> bool:
	for node in get_tree().get_nodes_in_group("enemy"):
		var other := node as Rat
		if other == null or other == self or other.state == State.DEAD:
			continue
		var gap := other.global_position.x - global_position.x
		if signf(gap) == facing and absf(gap) < SPACING:
			return true
	return false


func _set_state(new_state: State) -> void:
	if new_state == State.WINDUP:
		windup_time = 0.22 if _tail_strike else 0.32
		attack_lunge = 0.0 if _tail_strike else 6.0
	super(new_state)


func _on_attack_started() -> void:
	if _tail_strike:
		attack_hitbox.active = false
		tail_hitbox.active = true
	else:
		velocity.y = LEAP_UP


func _on_attack_ended() -> void:
	tail_hitbox.active = false
	if not _tail_strike:
		# Укусил — отскочил.
		velocity.x = -facing * RETREAT_SPEED


func _on_died() -> void:
	tail_hitbox.active = false
	var flip := create_tween()
	flip.tween_property(visual, "rotation:x", PI, 0.15)
	super()


func _update_extra(delta: float) -> void:
	_time += delta
	var running := absf(velocity.x) > 0.5
	# Лапы семенят на бегу.
	for i in legs.size():
		legs[i].rotation.z = sin(_time * 26.0 + i * PI * 0.5) * 0.7 if running else 0.0
	# Хвост: на бегу струится, перед ударом задран, в ударе хлещет.
	var lift := 0.15
	var whip := sin(_time * (14.0 if running else 4.0)) * 0.25
	match state:
		State.WINDUP:
			lift = 1.3
			whip = 0.0
		State.ATTACK:
			lift = -0.6 if _tail_strike else 0.4
	var k := 1.0 - exp(-14.0 * delta)
	var link := tail
	var depth := 0
	while link:
		link.rotation.z = lerpf(link.rotation.z, (lift + whip) * (0.5 + depth * 0.25), k)
		link = link.get_node_or_null(^"Link") as Node3D
		depth += 1
	# Замерла — принюхивается: морда покачивается.
	var sniff := sin(_time * 18.0) * 0.12 if not running and state == State.CHASE else 0.0
	var duck := -0.3 if state == State.WINDUP else 0.0
	head.rotation.z = lerpf(head.rotation.z, sniff + duck, k)
	visual.scale.y = lerpf(visual.scale.y, 0.8 if state == State.WINDUP else 1.0, k)
