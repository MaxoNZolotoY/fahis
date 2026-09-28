Scriptname FHS_InsightOnHit extends ActiveMagicEffect
{Вешается на эффект урона «Стремительного огненного шара» (FHS_FlashFireballDamage).

Эффект урона стартует на ЦЕЛИ только при успешном попадании снаряда. Если заклинание
поглощено (Атронах, Поглощение магии) или снаряд промахнулся, эффекта нет и стака тоже нет.
Скрипт проверяет, что стрелял игрок и что цель — живой враг, и передаёт попадание трекеру.}

Actor Property PlayerRef Auto
{Игрок. Auto-Fill: PlayerRef.}

FHS_InsightTracker Property FHS_ControllerQuest Auto
{Квест-контроллер со скриптом FHS_InsightTracker. Auto-Fill находит его по EditorID.}

Bool Property RequireHostileTarget = True Auto
{True = стак даёт только попадание по враждебной цели. Так нельзя «накрутить» стаки
на компаньоне или мирном NPC. False = засчитывается любое попадание по живой цели.}

Event OnEffectStart(Actor akTarget, Actor akCaster)
	; Заклинание могут использовать и NPC. Бафф получает только игрок.
	If akCaster != PlayerRef || akTarget == None || akTarget == akCaster
		Return
	EndIf
	If akTarget.IsDead()
		Return
	EndIf
	If RequireHostileTarget && !akTarget.IsHostileToActor(akCaster)
		Return
	EndIf

	FHS_ControllerQuest.RegisterHit()
EndEvent
