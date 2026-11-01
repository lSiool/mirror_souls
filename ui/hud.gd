class_name Hud
extends Control
## Интерфейс прототипа: здоровье, выносливость, отзвуки, зелье, текущая реальность,
## подсказка взаимодействия, экран смерти и затемнение.
## Отладка возраста (§1.3): F1/F2 меняют стартовый возраст на лету.

## Через сколько секунд после смерти появляется «ТЫ ПОГИБ»: тело успевает упасть.
const DEATH_LABEL_DELAY := 0.95
## Тон под надписью звучит без места в мире — убавлен до уровня звуков комнаты.
const DEATH_STING_DB := -9.0
const ITEM_NAMES := {&"clear_glass": "чистое стекло", &"facet_slot": "слот для граней", &"tempered_glass": "закалённое стекло"}

@export var player_path: NodePath

var _player: Player
var _echoes_shown := 0

@onready var health_bar: ProgressBar = %HealthBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var currency_label: Label = %Currency
@onready var flasks_label: Label = %Flasks
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
	Events.echoes_changed.connect(_on_echoes_changed)
	_player.flasks_changed.connect(_on_flasks_changed)
	Events.reality_changed.connect(_on_reality_changed)
	Events.interact_prompt_changed.connect(_on_prompt_changed)
	Events.player_died.connect(_on_player_died)
	Events.item_found.connect(_on_item_found)
	Events.mastery_step_reached.connect(_on_mastery_step)
	death_label.visible = false
	prompt_label.text = ""
	fade.color.a = 1.0
	_on_echoes_changed(GameState.echoes)
	_on_flasks_changed(_player.flasks, _player.stats.flask_charges)
	currency_label.pivot_offset = Vector2(0.0, 12.0)
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


## Отзвуки: прибавились — счётчик коротко вспыхивает.
func _on_echoes_changed(total: int) -> void:
	var grew := total > _echoes_shown
	_echoes_shown = total
	currency_label.text = "Отзвуки: %d" % total
	if grew:
		var tween := create_tween()
		tween.tween_property(currency_label, "scale", Vector2(1.25, 1.25), 0.08)
		tween.tween_property(currency_label, "scale", Vector2.ONE, 0.2)


## Новая ступень мастерства оружия в руке.
func _on_mastery_step(type: StringName, step: int) -> void:
	var weapon := _player.weapon
	if weapon and weapon.type == type and step <= weapon.step_names.size():
		_toast("Мастерство: %s" % weapon.step_names[step - 1])


## Найден редкий предмет: название появляется над подсказкой и гаснет.
func _on_item_found(id: StringName) -> void:
	var facet := Facet.by_id(id)
	_toast("Найдено: %s" % (facet.display_name if facet else ITEM_NAMES.get(id, String(id))))


func _toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color(0.72, 0.86, 1.0)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 170)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(label)
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func _on_flasks_changed(current: int, maximum: int) -> void:
	flasks_label.text = "Зелье: %s%s" % ["◆".repeat(current), "◇".repeat(maxi(maximum - current, 0))]


func _on_reality_changed(reality: StringName) -> void:
	reality_label.text = "Реальность: обычная" if reality == &"normal" else "Реальность: отражение"


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = "[E]  %s" % text if text != "" else ""


## Надпись — когда тело уже упало; под ней — приглушённый стеклянный тон.
func _on_player_died() -> void:
	await get_tree().create_timer(DEATH_LABEL_DELAY).timeout
	if _player.is_dead():
		death_label.visible = true
		Sfx.play_ui(&"death_sting", DEATH_STING_DB)


func _refresh_age() -> void:
	var s := _player.stats
	age_label.text = "\n".join([
		"Возраст: %.2f · уровень %d   (F1 −  /  F2 + — стартовый)" % [s.current_age, s.level],
		"Скорость %.2f · прыжок %.2f" % [s.move_speed, s.jump_velocity],
		"Перекат: неуязвимость %.2f с · урон меча %.1f" % [s.roll_iframes, s.sword_damage],
	])
