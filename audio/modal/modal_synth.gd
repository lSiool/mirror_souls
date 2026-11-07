class_name ModalSynth
extends RefCounted
## Модальный синтез удара:
##
##   s(t) = Σ aᵢ · e^(−dᵢ·t) · sin(2π·fᵢ·t)
##
## fᵢ — частоты мод (ModalMaterial.ratios × base_freq),
## dᵢ — затухания (высокие моды гаснут быстрее),
## aᵢ — амплитуды: зависят от материала, ЖЁСТКОСТИ/силы удара и ТОЧКИ удара.
##
## Рендер делается ОФЛАЙН в AudioStreamWAV (не в реальном времени):
## так нет проблем с буфером генератора, результат можно кэшировать
## и сохранить в .wav как обычный ассет (см. bake()).
##
## Каждая мода считается рекуррентным резонатором:
##   y[n] = 2·r·cos(ω)·y[n−1] − r²·y[n−2],  r = e^(−d/RATE)
## — без sin() и exp() на каждый сэмпл, поэтому быстро даже в GDScript.

const RATE := 44100
const MAX_DURATION := 3.0   # потолок длины звука, сек
const SILENCE := 0.001      # порог тишины (−60 dB): дальше звук обрезается


## strength 0..1  — сила удара: громче и ярче (короче контакт -> больше высоких частот).
## position 0..1  — точка удара: 0 — центр, 1 — край; меняет баланс мод.
## pitch          — множитель частоты (1.0 = как в материале).
## seed_value     — 0 = случайно; иначе воспроизводимый результат.
static func render(mat: ModalMaterial, strength: float = 0.7, position: float = 0.3,
		pitch: float = 1.0, seed_value: int = 0) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	strength = clampf(strength, 0.0, 1.0)
	position = clampf(position, 0.0, 1.0)

	# Время контакта (по модели Герца: твёрже/быстрее удар -> короче контакт).
	var contact := lerpf(0.004, 0.0006, strength)

	var omegas := PackedFloat64Array()
	var radii := PackedFloat64Array()
	var amps := PackedFloat64Array()
	var duration := 0.05
	var count := mini(mat.ratios.size(), mat.gains.size())

	for i in count:
		var ratio := mat.ratios[i]
		var f := mat.base_freq * pitch * ratio * (1.0 + rng.randf_range(-mat.detune, mat.detune))
		if f > RATE * 0.45:
			continue  # выше — алиасинг
		var decay := mat.base_decay * pow(ratio, mat.damping_exp)
		# Спектр импульса контакта: ~ низкочастотный фильтр, срез зависит от contact.
		var excite := 1.0 / (1.0 + pow(f * contact * 0.5, 2.0))
		# Эвристика точки удара: разные моды по-разному «видят» разные места.
		var place := 0.35 + 0.65 * absf(cos(position * PI * 0.5 * (i + 1)))
		var a := mat.gains[i] * excite * place
		if a <= SILENCE:
			continue
		omegas.append(TAU * f / RATE)
		radii.append(exp(-decay / RATE))
		amps.append(a)
		duration = maxf(duration, log(a / SILENCE) / decay)

	duration = minf(duration, MAX_DURATION)
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)  # заполнено нулями

	# 1) Банк резонаторов.
	for m in omegas.size():
		var r: float = radii[m]
		var w: float = omegas[m]
		var c := 2.0 * r * cos(w)
		var r2 := r * r
		var y2 := 0.0
		var y1: float = amps[m] * r * sin(w)
		if n > 1:
			out[1] += y1
		for k in range(2, n):
			var y0 := c * y1 - r2 * y2
			out[k] += y0
			y2 = y1
			y1 = y0

	# 2) Шумовой «щелчок» контакта (высокочастотный шум с быстрым затуханием).
	var noise_len := mini(n, int(0.06 * RATE))
	var lp := 0.0
	for k in noise_len:
		var x := rng.randf_range(-1.0, 1.0)
		lp += 0.25 * (x - lp)
		var hp := x - lp
		out[k] += hp * mat.noise_amount * strength * exp(-mat.noise_decay * k / RATE)

	# 3) Микро-атака (убирает щелчок на старте) и затухание хвоста (на обрезке).
	var attack := mini(n, 20)
	for k in attack:
		out[k] *= float(k) / attack
	var fade := mini(n, 200)
	for k in fade:
		out[n - 1 - k] *= float(k) / fade

	# 4) Нормализация: громкость зависит от силы удара.
	var peak := 0.0001
	for k in n:
		peak = maxf(peak, absf(out[k]))
	var gain := lerpf(0.3, 0.95, strength) / peak

	# 5) В 16-битный PCM.
	var data := PackedByteArray()
	data.resize(n * 2)
	for k in n:
		data.encode_s16(k * 2, int(clampf(out[k] * gain, -1.0, 1.0) * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


## Несколько вариантов одного удара (разные детюн/шум) — для round-robin в игре.
static func make_bank(mat: ModalMaterial, count: int = 6, strength: float = 0.7,
		position: float = 0.3) -> Array[AudioStreamWAV]:
	var bank: Array[AudioStreamWAV] = []
	for i in count:
		# Чуть варьируем точку удара и силу — варианты звучат живее.
		var s := clampf(strength + randf_range(-0.08, 0.08), 0.0, 1.0)
		var p := clampf(position + randf_range(-0.1, 0.1), 0.0, 1.0)
		bank.append(render(mat, s, p))
	return bank


## Сохранить результат как обычный .wav (например, user://sword_01.wav),
## чтобы потом доработать в Reaper/Audacity или использовать как ассет.
static func bake(mat: ModalMaterial, path: String, strength: float = 0.7,
		position: float = 0.3, pitch: float = 1.0) -> Error:
	return render(mat, strength, position, pitch).save_to_wav(path)
