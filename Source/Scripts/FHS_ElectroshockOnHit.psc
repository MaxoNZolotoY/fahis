Scriptname FHS_ElectroshockOnHit extends ActiveMagicEffect
{Вешается на эффект урона «Перегруженного разряда» (FHS_OverchargedBoltDamage).

При успешном попадании игрока по врагу накладывает на игрока бафф «Электрошок»
(FHS_ElectroshockBuff, 30 с). Повторное попадание не усиливает бафф, а только сбрасывает
таймер обратно на 30 секунд.

Сам эффект баффа (−10% стоимости заклинаний) работает БЕЗ скриптов: скрытый перк
FHS_ElectroshockPerk (Entry Point «Mod Spell Cost» × 0.9) включается условием
HasMagicEffect FHS_ElectroshockEffect == 1. Перк выдаёт игроку скрипт FHS_ModInit.

Почему не скорость каста: в ванильном движке нет Perk Entry Point для времени каста
(Charge Time). Его меняют только SKSE-плагины, а они несовместимы с форматом
Creation Club. Подробности — в docs/CK_GUIDE.md, раздел 4.}

Actor Property PlayerRef Auto
{Игрок. Auto-Fill: PlayerRef.}

Spell Property FHS_ElectroshockBuff Auto
{Бафф «Электрошок»: Fire and Forget, Self, длительность 30 с, эффект FHS_ElectroshockEffect.}

Bool Property RequireHostileTarget = True Auto
{True = бафф даёт только попадание по враждебной цели (не по компаньону или мирному NPC).}

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If akCaster != PlayerRef || akTarget == None || akTarget == akCaster
		Return
	EndIf
	If akTarget.IsDead()
		Return
	EndIf
	If RequireHostileTarget && !akTarget.IsHostileToActor(akCaster)
		Return
	EndIf

	; Снимаем и накладываем заново, чтобы таймер гарантированно вернулся к 30 с.
	; Процент при этом не растёт: эффект всегда один и тот же.
	PlayerRef.DispelSpell(FHS_ElectroshockBuff)
	FHS_ElectroshockBuff.Cast(PlayerRef, PlayerRef)
EndEvent
