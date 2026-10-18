class_name Hurtbox
extends Area3D
## Принимает удары от Hitbox. Владелец подписывается на `hurt`.

signal hurt(hitbox: Hitbox)

var invulnerable := false


func _ready() -> void:
	monitoring = false
	monitorable = true


func receive_hit(hitbox: Hitbox) -> bool:
	if invulnerable:
		return false
	hurt.emit(hitbox)
	return true
