Scriptname FHS_TwinSpearPlayerAlias extends ReferenceAlias
{Вешается на алиас Player в квесте FHS_ControllerQuest.

«Сдвоенное ледяное копьё»: когда игрок выпускает FHS_TwinIceSpear (первое копьё, 120 урона),
через FollowupDelay секунд скрипт выпускает от игрока второе, догоняющее копьё
FHS_TwinIceSpearFollowup (40 урона + замедление 50% + урон по запасу сил).

Почему так: в Skyrim нет «под-заклинаний» (sub-spells). Все эффекты одного заклинания
летят одним снарядом с общим Delivery. Два снаряда с задержкой делаются только двумя
заклинаниями и скриптом.

Второе копьё выпускается при любом касте, даже если первое промахнулось. Получается
очередь из двух выстрелов в направлении, куда смотрит игрок.}

Spell Property FHS_TwinIceSpear Auto
{Заклинание, которое кастует игрок (первое копьё).}

Spell Property FHS_TwinIceSpearFollowup Auto
{Второе копьё: Fire and Forget, Aimed, стоимость 0, время каста 0. Игроку НЕ выдаётся.}

Float Property FollowupDelay = 0.2 Auto
{Задержка между копьями в секундах. 0.15–0.3 выглядит как «очередь».}

Event OnSpellCast(Form akSpell)
	If akSpell != FHS_TwinIceSpear
		Return
	EndIf

	; Wait не блокирует игру, а на время открытого меню ставится на паузу.
	Utility.Wait(FollowupDelay)

	Actor playerActor = GetActorReference()
	If playerActor && !playerActor.IsDead()
		; Cast() без цели выпускает Aimed-снаряд вперёд, в направлении, куда смотрит кастер.
		; Стоимость и время каста при этом не тратятся.
		FHS_TwinIceSpearFollowup.Cast(playerActor)
	EndIf
EndEvent
