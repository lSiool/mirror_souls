extends Node
## Глобальная шина событий: системы общаются сигналами, не зная друг о друге.

signal camera_shake_requested(strength: float, duration: float)
signal mirror_used(portal: MirrorPortal)
## Герой открыл дверь в другую комнату.
signal door_used(door: RoomDoor)
## Босс заметил героя: HUD показывает его здоровье.
signal boss_engaged(boss: Dummy)
## Короткая надпись игроку над подсказкой.
signal message(text: String)
signal checkpoint_activated(shard: MirrorShard)
signal player_died
signal echoes_changed(total: int)
## Враг погиб (ещё в дереве): менеджер комнаты запоминает его и выпускает отзвук.
signal enemy_killed(enemy: Dummy)
## Найден редкий предмет: HUD коротко показывает название.
signal item_found(id: StringName)
## Расходники изменились: что лежит в ячейках крестовины или сколько чего осталось (HUD).
signal quick_items_changed
## Сменились стрелы в гнёздах лука, их число или активное гнездо (§6.2).
signal arrows_changed
## Выучено заклинание или сменилась активная ячейка магии (§6.2).
signal spells_changed
## Тип оружия достиг новой ступени мастерства.
signal mastery_step_reached(type: StringName, step: int)
## Стекло разбилось: менеджер комнаты запоминает его по виду (GlassSurface.memory).
signal glass_broken(glass: GlassSurface)
## Уровень-забег (§8.11): герой пересёк линию старта — пошло обрушение.
signal run_started(run: RunLevel)
## Забег окончен — пройден или провален; вход закрыт, не забранное ушло торговцу.
signal run_finished(run: RunLevel)
signal reality_changed(reality: StringName)
signal interact_prompt_changed(text: String)
## Шум в мире (стрела ударилась о стену): враги, не видящие героя, идут проверить.
signal noise_made(position: Vector3, radius: float)
