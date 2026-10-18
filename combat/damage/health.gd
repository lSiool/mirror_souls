class_name Health
extends Node
## Компонент здоровья. Владелец подписывается на сигналы.

signal changed(current: float, maximum: float)
signal damaged(amount: float)
signal died

@export var max_health := 100.0

var current := 0.0


func _ready() -> void:
	current = max_health


func is_dead() -> bool:
	return current <= 0.0


## non_lethal: удар не опускает здоровье ниже 1 (первая засада не убивает, §5.3).
func take_damage(amount: float, non_lethal := false) -> void:
	if is_dead():
		return
	var lowest := minf(1.0, current) if non_lethal else 0.0
	current = maxf(current - amount, lowest)
	changed.emit(current, max_health)
	damaged.emit(amount)
	if is_dead():
		died.emit()


func heal_full() -> void:
	current = max_health
	changed.emit(current, max_health)
