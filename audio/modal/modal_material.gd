class_name ModalMaterial
extends Resource
## «Материал» для модального синтеза: набор мод (собственных частот) объекта.
## Звук удара = сумма затухающих синусоид. Подробнее — в modal_synth.gd.
##
## ВАЖНО: пресеты ниже подобраны «по мотивам» физики и на слух,
## это отправная точка для тюнинга, а не точный расчёт реальных предметов.

## Имя материала (для файлов и отладки).
@export var id: StringName = &"custom"
## Частота первой (основной) моды, Гц.
@export var base_freq: float = 600.0
## Отношения частот мод к основной. Для металла они НЕ целые -> «металлический» тембр.
@export var ratios: PackedFloat32Array = PackedFloat32Array([1.0])
## Относительные амплитуды мод (той же длины, что и ratios).
@export var gains: PackedFloat32Array = PackedFloat32Array([1.0])
## Скорость затухания первой моды, 1/сек. Больше = короче звук (дерево ~40, металл ~4).
@export var base_decay: float = 5.0
## Насколько быстрее затухают высокие моды: decay_i = base_decay * ratio_i ^ damping_exp.
@export_range(0.0, 2.0) var damping_exp: float = 0.8
## Громкость шумового «щелчка» контакта (0..1).
@export_range(0.0, 1.0) var noise_amount: float = 0.3
## Как быстро гаснет щелчок, 1/сек (больше = короче).
@export var noise_decay: float = 400.0
## Случайный разброс частот каждого удара (доля, 0.003 = 0.3%) — чтобы не было «пулемёта».
@export_range(0.0, 0.02) var detune: float = 0.003


static func _make(p_id: StringName, p_freq: float, p_ratios: Array, p_gains: Array,
		p_decay: float, p_exp: float, p_noise: float, p_noise_decay: float) -> ModalMaterial:
	var m := ModalMaterial.new()
	m.id = p_id
	m.base_freq = p_freq
	m.ratios = PackedFloat32Array(p_ratios)
	m.gains = PackedFloat32Array(p_gains)
	m.base_decay = p_decay
	m.damping_exp = p_exp
	m.noise_amount = p_noise
	m.noise_decay = p_noise_decay
	return m


## Клинок меча: модель свободной балки (Эйлер–Бернулли), отношения частот 1 : 2.76 : 5.40 : 8.93 …
static func sword() -> ModalMaterial:
	return _make(&"sword", 700.0,
		[1.0, 2.756, 5.404, 8.933, 13.344, 18.64, 24.8],
		[1.0, 0.8, 0.6, 0.45, 0.3, 0.2, 0.12],
		5.0, 0.8, 0.35, 400.0)


## Металлический щит/пластина: плотный негармоничный набор (подобран на слух).
static func shield() -> ModalMaterial:
	return _make(&"shield", 320.0,
		[1.0, 1.59, 2.14, 2.30, 2.65, 2.92, 3.50, 4.06, 4.60],
		[1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.25],
		9.0, 0.7, 0.5, 250.0)


## Стекло: высокая основная частота, редкие моды, долгий тонкий звон.
static func glass() -> ModalMaterial:
	return _make(&"glass", 1800.0,
		[1.0, 2.32, 4.25, 6.63, 9.38],
		[1.0, 0.6, 0.4, 0.25, 0.15],
		3.0, 0.9, 0.15, 800.0)


## Дерево/кожа: низко, сильное затухание — глухой «тук».
static func wood() -> ModalMaterial:
	return _make(&"wood", 160.0,
		[1.0, 1.8, 2.9, 4.1],
		[1.0, 0.6, 0.4, 0.2],
		40.0, 0.5, 0.6, 150.0)
