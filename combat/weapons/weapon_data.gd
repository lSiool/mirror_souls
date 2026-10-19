class_name WeaponData
extends Resource
## Оружие и его набор атак (§6.2). У каждого оружия свой набор стадий комбо.

@export var display_name := "Меч"
@export var combo: Array[AttackStep] = []
## Удар во время скольжения или сразу на выходе из него.
@export var slide_attack: AttackStep
## Удар сразу после кувырка.
@export var roll_attack: AttackStep
## Добивание после парирования.
@export var riposte: AttackStep
## Удар в спину.
@export var backstab: AttackStep
