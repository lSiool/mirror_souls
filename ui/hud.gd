class_name Hud
extends Control
## Интерфейс прототипа: здоровье, выносливость, блики, текущая реальность,
## подсказка взаимодействия, экран смерти и затемнение.
## Отладка возраста (§1.3): F1/F2 меняют стартовый возраст на лету.

## Через сколько секунд после смерти появляется «ТЫ ПОГИБ»: тело успевает упасть.
const DEATH_LABEL_DELAY := 0.95

@export var player_path: NodePath

var _player: Player

@onready var health_bar: ProgressBar = %HealthBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var currency_label: Label = %Currency
@onready var reality_label: Label = %Reality
@onready var age_label: Label = %AgeInfo
@onready var prompt_label: Label = %Prompt
@onready var death_label: Label = %DeathLabel
@onready var fade: ColorRect = %Fade


func _ready() -> void:
	_player = get_node(player_path)
	_player.health_changed.connect(_on_health_changed)
	_player.stamina_changed.connect(_on_stamina_changed)
	_player.stats.changed.connect(_refresh_age)
	Events.currency_changed.connect(_on_currency_changed)
	Events.reality_changed.connect(_on_reality_changed)
	Events.interact_prompt_changed.connect(_on_prompt_changed)
	Events.player_died.connect(_on_player_died)
	death_label.visible = false
	prompt_label.text = ""
	fade.color.a = 1.0
	_on_currency_changed(GameState.currency)
	_refresh_age()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_age_down"):
		_player.stats.age -= 1
	elif event.is_action_pressed("debug_age_up"):
		_player.stats.age += 1


func fade_to(alpha: float, duration: float) -> Signal:
	var tween := create_tween()
	tween.tween_property(fade, "color:a", alpha, duration)
	return tween.finished


func hide_death() -> void:
	death_label.visible = false


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current


func _on_currency_changed(total: int) -> void:
	currency_label.text = "Блики: %d" % total


func _on_reality_changed(reality: StringName) -> void:
	reality_label.text = "Реальность: обычная" if reality == &"normal" else "Реальность: отражение"


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = "[E]  %s" % text if text != "" else ""


## Надпись — когда тело уже упало; под ней — приглушённый стеклянный тон.
func _on_player_died() -> void:
	await get_tree().create_timer(DEATH_LABEL_DELAY).timeout
	if _player.is_dead():
		death_label.visible = true
		Sfx.play_ui(&"death_sting")


func _refresh_age() -> void:
	var s := _player.stats
	age_label.text = "\n".join([
		"Возраст: %d   (F1 −  /  F2 +)" % s.age,
		"Скорость %.2f · прыжок %.2f" % [s.move_speed, s.jump_velocity],
		"Перекат: неуязвимость %.2f с · урон меча %.1f" % [s.roll_iframes, s.sword_damage],
	])
