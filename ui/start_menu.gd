class_name StartMenu
extends Control
## Первый экран, когда есть сохранение: продолжить или начать заново.

signal chosen(resume: bool)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var resume := _button(box, "Продолжить", true)
	_button(box, "Новая игра", false)
	resume.grab_focus()


func _button(parent: Control, text: String, resume: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(func() -> void: chosen.emit(resume))
	parent.add_child(button)
	return button
