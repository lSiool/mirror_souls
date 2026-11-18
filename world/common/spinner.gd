class_name Spinner
extends Node3D
## Медленно вращается вокруг своей оси Z (к камере): крылья ветряной мельницы, водяное колесо (§8.13).
## Только вид, без коллизии.

## Радиан в секунду; знак — направление.
@export var speed := 0.25


func _process(delta: float) -> void:
	rotation.z = wrapf(rotation.z + speed * delta, -PI, PI)
