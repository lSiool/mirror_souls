class_name FlagShown
extends Node3D
## Часть комнаты, которая есть только при флаге мира (или только без него): пустой столб до рассказа
## о казни и Пугало на нём после (§8.13). Проверяется при загрузке комнаты — меняется со следующим заходом.

@export var flag: StringName
## true — узел есть, когда флаг стоит; false — пока флага нет.
@export var shown_when_set := true


func _ready() -> void:
	if flag != &"" and GameState.has_flag(flag) != shown_when_set:
		queue_free()
