class_name Settings
## Настройки игрока (§8.12, меню паузы → «Настройки»): пока только громкость. Хранятся отдельно
## от сохранения игры — «Новая игра» их не сбрасывает.

const PATH := "user://settings.cfg"
const VOLUME_STEP := 0.1

## Общая громкость 0…1.
static var volume := 1.0
static var _loaded := false


## Прочитать файл (один раз) и применить.
static func apply() -> void:
	if not _loaded:
		_loaded = true
		var file := ConfigFile.new()
		if file.load(PATH) == OK:
			volume = clampf(float(file.get_value("audio", "volume", 1.0)), 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)


static func set_volume(value: float) -> void:
	volume = clampf(snappedf(value, VOLUME_STEP), 0.0, 1.0)
	apply()
	var file := ConfigFile.new()
	file.set_value("audio", "volume", volume)
	file.save(PATH)
