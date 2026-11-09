class_name CreatureKind
extends RefCounted
## Базовая принадлежность врага к классу (§6.3, 2026-11-09): человек, проклятый, вампир, оборотень,
## скелет, зверь, дух, стекло, элементаль. Общий эффект (первый — слепота, §6.2) каждый класс
## переживает по-своему: человек трёт глаза, оборотень ревёт, вампир теряется, у скелета глаз нет.
##
## Здесь — только таблица «класс → реакция и её длительность». Как реакция выглядит — у врага:
## общее (гуманоид трёт глаза, вампир шатается) в Dummy, особое — в наследнике (Werewolf, Rat,
## FogWraith). Отдельный враг может выбиться из своего класса (летучая мышь — зверь, но летает
## по эхолокации): Dummy._status_reaction.
##
## Новый общий эффект — своя таблица рядом с BLIND и строка в TABLES; новый класс — строка в каждой.

enum Kind { HUMAN, CURSED, VAMPIRE, WEREWOLF, SKELETON, BEAST, SPIRIT, GLASS, ELEMENTAL }

## Как враг переживает эффект.
enum Reaction {
	## Не действует.
	IMMUNE,
	## Гуманоид: отшатнулся, поднял ладони к глазам, трёт глаза.
	RUB_EYES,
	## Оборотень: ревёт, раскинув руки; не нападает.
	ROAR,
	## Вампир: потерян и шатается — окно для добивания спереди.
	DISORIENT,
	## Зверь: замер, трясёт мордой и трёт её лапами.
	SHAKE_HEAD,
	## Дух: глаза гаснут, растворяется в тумане и отступает.
	FADE,
}

## Слепота: реакция класса и доля стандартной длительности (Statuses.BLIND_TIME).
## Звери, духи и оборотень приходят в себя вдвое быстрее человека, вампир — за три четверти.
## Элементаль — не решено (2026-11-09): пока не слепнет.
const BLIND := {
	Kind.HUMAN: [Reaction.RUB_EYES, 1.0],
	Kind.CURSED: [Reaction.RUB_EYES, 1.0],
	Kind.VAMPIRE: [Reaction.DISORIENT, 0.75],
	Kind.WEREWOLF: [Reaction.ROAR, 0.5],
	Kind.SKELETON: [Reaction.IMMUNE, 0.0],
	Kind.BEAST: [Reaction.SHAKE_HEAD, 0.5],
	Kind.SPIRIT: [Reaction.FADE, 0.5],
	Kind.GLASS: [Reaction.IMMUNE, 0.0],
	Kind.ELEMENTAL: [Reaction.IMMUNE, 0.0],
}

## Эффект → его таблица. Эффекта нет в списке — классы его не различают.
const TABLES := {Statuses.BLIND: BLIND}

## Сложены как человек: руки, голова, глаза на лице (руки graybox — GrayboxArms).
const HUMANOID: Array[Kind] = [Kind.HUMAN, Kind.CURSED, Kind.VAMPIRE, Kind.SKELETON]


static func reaction(effect: StringName, kind: Kind) -> Reaction:
	var table: Dictionary = TABLES.get(effect, {})
	return table[kind][0] if table.has(kind) else Reaction.IMMUNE


## Доля стандартной длительности эффекта для класса; эффект без таблицы — как есть.
static func duration_scale(effect: StringName, kind: Kind) -> float:
	var table: Dictionary = TABLES.get(effect, {})
	if table.is_empty():
		return 1.0
	return table[kind][1] if table.has(kind) else 0.0


static func humanoid(kind: Kind) -> bool:
	return kind in HUMANOID
