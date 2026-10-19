class_name WeaponData
extends Resource
## Оружие и его набор атак (§6.2). У каждого оружия свой набор стадий комбо.

@export var display_name := "Меч"
@export var combo: Array[AttackStep] = []
