class_name PlayerReach
extends RefCounted
## Что герой может взять или открыть рядом: зоны Interactable сами сообщают о входе и выходе.
## Ближайшая доступная зона — текущая; её подсказка уходит в HUD.

var _targets: Array[Interactable] = []
var _prompt := ""


func add(target: Interactable) -> void:
	if target not in _targets:
		_targets.append(target)


func remove(target: Interactable) -> void:
	_targets.erase(target)


## После телепорта: список не очищаем — если герой остался внутри зоны (зеркало, сундук),
## зона не сообщит о входе повторно. Уходя из зоны, герой и так её отпустит.
func prune() -> void:
	_targets = _targets.filter(is_instance_valid)


func nearest(from: Vector3) -> Interactable:
	var best: Interactable = null
	var best_distance := INF
	for target in _targets:
		if not is_instance_valid(target) or not target.enabled or not target.is_inside_tree():
			continue
		var d := from.distance_to(target.global_position)
		if d < best_distance:
			best = target
			best_distance = d
	return best


## Подсказка ближайшей зоны (пусто — подсказки нет); в HUD уходит только смена текста.
func update_prompt(from: Vector3, active: bool) -> void:
	var target := nearest(from) if active else null
	var text := target.prompt if target else ""
	if text != _prompt:
		_prompt = text
		Events.interact_prompt_changed.emit(text)
