extends Node
## Демо-стенд. Создай пустую сцену с корнем Node, повесь этот скрипт, запусти.
##
##   1–4        материал: меч / щит / стекло / дерево
##   Пробел     ударить
##   ↑ / ↓      сила удара
##   ← / →      точка удара (центр ... край)
##   B          сохранить текущий звук в user://<материал>.wav

var _materials: Array[ModalMaterial] = [
	ModalMaterial.sword(),
	ModalMaterial.shield(),
	ModalMaterial.glass(),
	ModalMaterial.wood(),
]
var _index := 0
var _strength := 0.7
var _position := 0.3
var _render_ms := 0.0

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _label: Label


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 16)
	layer.add_child(_label)
	_update_label()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_1: _select(0)
		KEY_2: _select(1)
		KEY_3: _select(2)
		KEY_4: _select(3)
		KEY_SPACE:
			if not event.echo:
				_strike()
		KEY_UP: _strength = clampf(_strength + 0.05, 0.0, 1.0)
		KEY_DOWN: _strength = clampf(_strength - 0.05, 0.0, 1.0)
		KEY_RIGHT: _position = clampf(_position + 0.05, 0.0, 1.0)
		KEY_LEFT: _position = clampf(_position - 0.05, 0.0, 1.0)
		KEY_B:
			var mat := _materials[_index]
			var path := "user://%s.wav" % mat.id
			var err := ModalSynth.bake(mat, path, _strength, _position)
			print("bake -> ", ProjectSettings.globalize_path(path), " (", error_string(err), ")")
	_update_label()


func _select(i: int) -> void:
	_index = i
	_strike()


func _strike() -> void:
	var mat := _materials[_index]
	var t0 := Time.get_ticks_usec()
	var stream := ModalSynth.render(mat, _strength, _position)
	_render_ms = (Time.get_ticks_usec() - t0) / 1000.0
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = randf_range(0.97, 1.03)
	p.play()


func _update_label() -> void:
	var mat := _materials[_index]
	_label.text = "Материал: %s   сила: %.2f   точка удара: %.2f\nрендер: %.1f мс\n" % [
		mat.id, _strength, _position, _render_ms]
	_label.text += "[1-4] материал  [Пробел] удар  [↑↓] сила  [←→] точка  [B] сохранить WAV"
