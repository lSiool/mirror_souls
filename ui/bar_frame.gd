@tool
class_name BarFrame
extends Control
## Рама полосы здоровья или выносливости (§8.12). Длина растёт с максимумом, как в Souls.
## Нарисованная рама режется на три куска по колонкам чистого рельса (без шипов), поэтому стыки
## не видны: голова (торец) [0, head_to), середина с шипами [head_to, tail_from), хвост (наконечник)
## [tail_from, ширина). Нужно длиннее — середина повторяется, остаток добирает кусок чистого рельса
## [plain_from, plain_to); короче полной середины — только чистый рельс.
## Колонки — в пикселях текстуры (их печатает tools/ui/cut_hud_bars.py); рисуется в масштабе высоты.

@export var texture: Texture2D:
	set(value):
		texture = value
		_relayout()
## Проём рамы по x — где лежит полоса, колонки текстуры.
@export var opening_from := 0:
	set(value):
		opening_from = value
		_relayout()
@export var opening_to := 0:
	set(value):
		opening_to = value
		_relayout()
## Конец головы и начало хвоста — колонки чистого рельса.
@export var head_to := 0:
	set(value):
		head_to = value
		_relayout()
@export var tail_from := 0:
	set(value):
		tail_from = value
		_relayout()
## Кусок чистого рельса, которым добирается длина.
@export var plain_from := 0:
	set(value):
		plain_from = value
		_relayout()
@export var plain_to := 0:
	set(value):
		plain_to = value
		_relayout()
## Ширина проёма на экране; рама подбирает свою ширину под неё (не короче головы с хвостом).
@export var opening_width := 300.0:
	set(value):
		opening_width = value
		_relayout()


## Масштаб текстуры: высота рамы на экране к высоте картинки.
func texture_scale() -> float:
	if texture == null or texture.get_height() <= 0 or size.y <= 0.0:
		return 1.0
	return size.y / texture.get_height()


## Самый короткий проём: голова и хвост без середины.
func min_opening() -> float:
	return ((head_to - opening_from) + (opening_to - tail_from)) * texture_scale()


## Где проём на экране относительно рамы: (левый край, ширина).
func opening_rect() -> Vector2:
	return Vector2(opening_from * texture_scale(), _opening_src() * texture_scale())


func _opening_src() -> float:
	return maxf(opening_width / texture_scale(), (head_to - opening_from) + (opening_to - tail_from))


func _ready() -> void:
	_relayout()


func _relayout() -> void:
	if texture == null or tail_from <= head_to:
		return
	var filler := _opening_src() - (head_to - opening_from) - (opening_to - tail_from)
	size.x = (head_to + filler + texture.get_width() - tail_from) * texture_scale()
	queue_redraw()


## Куски текстуры слева направо: [от, до) в колонках.
func _pieces() -> Array[Vector2]:
	var result: Array[Vector2] = [Vector2(0, head_to)]
	var filler := _opening_src() - (head_to - opening_from) - (opening_to - tail_from)
	var thorny := float(tail_from - head_to)
	while filler >= thorny:
		result.append(Vector2(head_to, tail_from))
		filler -= thorny
	var plain := float(plain_to - plain_from)
	while filler > 0.5 and plain > 0.0:
		var piece := minf(filler, plain)
		result.append(Vector2(plain_from, plain_from + piece))
		filler -= piece
	result.append(Vector2(tail_from, texture.get_width()))
	return result


func _draw() -> void:
	if texture == null or tail_from <= head_to:
		return
	var k := texture_scale()
	var h := float(texture.get_height())
	var src_x := 0.0
	for piece in _pieces():
		# Края кусков — на целых пикселях экрана: соседние стыкуются без щели.
		var x0 := roundf(src_x * k)
		src_x += piece.y - piece.x
		var x1 := roundf(src_x * k)
		draw_texture_rect_region(texture, Rect2(x0, 0.0, x1 - x0, size.y), Rect2(piece.x, 0.0, piece.y - piece.x, h))
