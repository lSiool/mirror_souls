extends SceneTree
## Запекает модальные звуки (первый слой звука, docs/SOUND_PLAN.md) в WAV:
##   godot --headless --path . -s res://tools/bake_modal_sounds.gd
## Файлы: res://audio/sfx/<группа>/<событие>_NN.wav — 44.1 кГц, 16 бит, моно, пик по событию.
## Сид каждого варианта фиксирован: повторный запуск даёт те же файлы.

const ModalSynthScript := preload("res://audio/modal/modal_synth.gd")
const ModalMaterialScript := preload("res://audio/modal/modal_material.gd")
const RATE := 44100
const FADE := 88  # 2 мс

## Событие: группа, материал, вариантов, сила, точка удара, высота, пик dBFS, слои.
## Слои — дополнительные мелкие удары поверх основного: [задержка с, высота, сила, громкость].
var events := [
	{"id": "sword_hit_glass", "group": "combat", "mat": "glass", "count": 4,
		"strength": 0.75, "position": 0.35, "pitch": 1.0, "peak": -3.0, "layers": [
			[0.0, 0.5, 0.9, 0.5]]},
	{"id": "glass_break", "group": "glass", "mat": "glass", "count": 3,
		"strength": 1.0, "position": 0.7, "pitch": 0.8, "peak": -2.0, "layers": [
			[0.03, 1.3, 0.6, 0.5], [0.07, 1.7, 0.5, 0.4], [0.12, 1.45, 0.45, 0.35],
			[0.2, 2.1, 0.4, 0.3], [0.3, 1.9, 0.35, 0.25], [0.45, 2.4, 0.3, 0.2]]},
	{"id": "arrow_ricochet_glass", "group": "combat", "mat": "glass", "count": 4,
		"strength": 0.5, "position": 0.5, "pitch": 1.4, "peak": -6.0, "layers": []},
	{"id": "sword_block", "group": "combat", "mat": "sword", "count": 4,
		"strength": 0.6, "position": 0.4, "pitch": 0.9, "peak": -4.0, "layers": [
			[0.0, 0.55, 0.6, 0.4]]},
	{"id": "sword_parry", "group": "combat", "mat": "sword", "count": 3,
		"strength": 1.0, "position": 0.15, "pitch": 1.12, "peak": -1.5, "layers": [
			[0.0, 1.5, 0.8, 0.35]]},
	{"id": "arrow_hit_wood", "group": "combat", "mat": "wood", "count": 4,
		"strength": 0.8, "position": 0.3, "pitch": 1.0, "peak": -4.0, "layers": []},
	{"id": "glass_glint", "group": "glass", "mat": "glass", "count": 3,
		"strength": 0.15, "position": 0.0, "pitch": 1.0, "peak": -14.0, "layers": []},
	# Блик стекла-ловушки — та же нота на полтона ниже (язык бликов, §3 плана).
	{"id": "glass_glint_trap", "group": "glass", "mat": "glass", "count": 3,
		"strength": 0.15, "position": 0.0, "pitch": 0.9439, "peak": -14.0, "layers": []},
]


func _init() -> void:
	var total := 0
	for event: Dictionary in events:
		var dir := "res://audio/sfx/%s" % event.group
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		for i in int(event.count):
			var path := "%s/%s_%02d.wav" % [dir, event.id, i + 1]
			var seed_value := hash("%s_%d" % [event.id, i]) & 0x7fffffff
			var samples := _render_event(event, seed_value)
			var err := _encode(samples).save_to_wav(path)
			print("%s  %.2f с  %s" % [path, samples.size() / float(RATE), error_string(err)])
			total += 1
	print("Запечено файлов: %d" % total)
	quit()


func _render_event(event: Dictionary, seed_value: int) -> PackedFloat32Array:
	var mat := _material(event.mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Варианты: чуть другая сила, точка и высота — звучат живее.
	var strength := clampf(float(event.strength) + rng.randf_range(-0.06, 0.06), 0.0, 1.0)
	var position := clampf(float(event.position) + rng.randf_range(-0.08, 0.08), 0.0, 1.0)
	var pitch := float(event.pitch) * rng.randf_range(0.985, 1.015)
	var out := _decode(ModalSynthScript.render(mat, strength, position, pitch, seed_value))
	for layer: Array in event.layers:
		var shard := _decode(ModalSynthScript.render(mat, layer[2], rng.randf(),
			pitch * float(layer[1]) * rng.randf_range(0.95, 1.05), rng.randi() | 1))
		_mix(out, shard, int(float(layer[0]) * RATE), float(layer[3]))
	_normalize(out, db_to_linear(float(event.peak)))
	return out


func _material(id: String) -> ModalMaterial:
	match id:
		"sword": return ModalMaterialScript.sword()
		"shield": return ModalMaterialScript.shield()
		"glass": return ModalMaterialScript.glass()
	return ModalMaterialScript.wood()


func _decode(wav: AudioStreamWAV) -> PackedFloat32Array:
	var data := wav.data
	var out := PackedFloat32Array()
	out.resize(data.size() / 2)
	for k in out.size():
		out[k] = data.decode_s16(k * 2) / 32768.0
	return out


func _mix(into: PackedFloat32Array, layer: PackedFloat32Array, offset: int, gain: float) -> void:
	if into.size() < offset + layer.size():
		into.resize(offset + layer.size())
	for k in layer.size():
		into[offset + k] += layer[k] * gain


## Пик в target, фейд 2 мс по краям — без щелчков.
func _normalize(samples: PackedFloat32Array, target: float) -> void:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var gain := target / peak
	var n := samples.size()
	for k in n:
		var fade := minf(1.0, minf(k, n - 1 - k) / float(FADE))
		samples[k] *= gain * fade


func _encode(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for k in samples.size():
		data.encode_s16(k * 2, int(clampf(samples[k], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
