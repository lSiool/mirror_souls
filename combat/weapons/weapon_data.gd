class_name WeaponData
extends Resource
## Оружие и его набор атак (§6.2). У каждого оружия свой набор стадий комбо.
## Базовое комбо, заряженный удар и блок есть сразу; мастерство типа оружия (ступени 1–5)
## открывает остальное, закалённое стекло качает урон (GameState).

## Ступени мастерства (§8.6). Парирование на второй ступени — у любого оружия.
const STEP_EXTRA_HIT := 1
const STEP_PARRY := 2
const STEP_AIR := 3
const STEP_COUNTER := 4
## Последняя ступень — спецэффект вида оружия: у меча и копья кровотечение, у топора раскол брони,
## у молота оглушение.
const STEP_SPECIAL := 5

@export var display_name := "Меч"
## Этот предмет: закалённое стекло вложено в него.
@export var id: StringName = &"sword"
## Тип оружия: мастерство общее на все мечи.
@export var type: StringName = &"sword"
## Что открывают ступени 1–5: для меню и сообщений.
@export var step_names: Array[String] = []
@export var combo: Array[AttackStep] = []
## Удар во время скольжения или сразу на выходе из него.
@export var slide_attack: AttackStep
## Удар сразу после кувырка.
@export var roll_attack: AttackStep
## Добивание после парирования.
@export var riposte: AttackStep
## Удар в спину.
@export var backstab: AttackStep
## Заряженный удар: есть сразу, держать удар после взмаха и отпустить.
@export var charged: AttackStep
## Продолжение серии: ступень 1.
@export var extra_hit: AttackStep
## Удар в прыжке: ступень 3. Контрудар сразу после принятого на блок удара: ступень 4.
@export var air_attack: AttackStep
@export var counter: AttackStep
## Спецэффект последней ступени: сколько кровотечения копит обычный удар; сильнее удар — больше.
@export var bleed_buildup := 0.0


## Серия на этой ступени мастерства.
func combo_at(step: int) -> Array[AttackStep]:
	var list: Array[AttackStep] = combo.duplicate()
	if extra_hit and step >= STEP_EXTRA_HIT:
		list.append(extra_hit)
	return list
