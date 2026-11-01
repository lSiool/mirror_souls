extends Node
## Глобальная шина событий: системы общаются сигналами, не зная друг о друге.

signal camera_shake_requested(strength: float, duration: float)
signal mirror_used(portal: MirrorPortal)
signal checkpoint_activated(shard: MirrorShard)
signal player_died
signal echoes_changed(total: int)
## Враг погиб (ещё в дереве): менеджер комнаты запоминает его и выпускает отзвук.
signal enemy_killed(enemy: Dummy)
## Найден редкий предмет: HUD коротко показывает название.
signal item_found(id: StringName)
## Стекло разбилось: менеджер комнаты запоминает его по виду (GlassSurface.memory).
signal glass_broken(glass: GlassSurface)
signal reality_changed(reality: StringName)
signal interact_prompt_changed(text: String)
## Шум в мире (стрела ударилась о стену): враги, не видящие героя, идут проверить.
signal noise_made(position: Vector3, radius: float)
