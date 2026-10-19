extends Node
## Глобальная шина событий: системы общаются сигналами, не зная друг о друге.

signal camera_shake_requested(strength: float, duration: float)
signal mirror_used(portal: MirrorPortal)
signal checkpoint_activated(shard: MirrorShard)
signal player_died
signal currency_changed(total: int)
signal reality_changed(reality: StringName)
signal interact_prompt_changed(text: String)
## Шум в мире (стрела ударилась о стену): враги, не видящие героя, идут проверить.
signal noise_made(position: Vector3, radius: float)
