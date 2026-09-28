Scriptname FHS_InsightTracker extends Quest
{«Озарение» (Insight): считает стаки и держит бонус к урону заклинаний Разрушения.

Висит на квесте FHS_ControllerQuest. Каждое успешное попадание «Стремительным огненным шаром»
вызывает RegisterHit() (из скрипта FHS_InsightOnHit на эффекте урона).

Как применяется бонус:
  Используется актёрское значение DestructionPowerMod. Ванильный скрытый перк AlchemySkillBoosts,
  который есть у игрока с начала игры, умножает магнитуду всех заклинаний Разрушения на
  (1 + DestructionPowerMod / 100). Так же работают зелья «Усиление Разрушения», поэтому бонусы
  честно складываются, а свой перк для «Озарения» не нужен.

Почему стаки хранятся здесь, а не в ActiveMagicEffect:
  при повторном наложении того же заклинания движок снимает старый эффект (OnEffectFinish)
  и запускает новый, и счётчик внутри эффекта обнулился бы. Квестовый скрипт живёт всё время,
  а RegisterForSingleUpdate при повторном вызове просто перезапускает таймер.}

;=====================================================================================
; СВОЙСТВА (Properties) — заполняются в CK: Quest > Scripts > Properties
;=====================================================================================

Actor Property PlayerRef Auto
{Игрок. Auto-Fill найдёт ванильную ссылку PlayerRef (00000014).}

Spell Property FHS_InsightDisplaySpell Auto
{Заклинание-«иконка» на 20 с (Fire and Forget, Self, эффект с архетипом Script).
Нужно только для того, чтобы «Озарение» и его таймер было видно в меню «Активные эффекты».
На урон оно не влияет: бонус держит этот скрипт.}

Float Property BuffDuration = 20.0 Auto
{Длительность эффекта в секундах. Каждое попадание сбрасывает таймер на это значение.}

Float Property FirstStackBonus = 5.0 Auto
{Бонус к урону Разрушения (в %) за первое попадание.}

Float Property ExtraStackBonus = 0.5 Auto
{Дополнительный бонус (в %) за каждое следующее попадание, пока эффект активен.}

Int Property MaxStacks = 0 Auto
{Потолок стаков. 0 = без ограничения (как в ТЗ). Например, 21 даст потолок +15%.}

Bool Property ShowNotifications = False Auto
{True = показывать уведомление в углу экрана при каждом стаке (удобно для тестов).}

;=====================================================================================
; ВНУТРЕННЕЕ СОСТОЯНИЕ (сохраняется в сейве вместе с квестом)
;=====================================================================================

Int Stacks = 0
Float AppliedBonus = 0.0 ; сколько процентов мы СЕЙЧАС добавили к DestructionPowerMod

;=====================================================================================
; ПУБЛИЧНЫЕ ФУНКЦИИ
;=====================================================================================

Function RegisterHit()
	{Вызывается при каждом успешном попадании «Стремительным огненным шаром» по врагу.}
	If MaxStacks <= 0 || Stacks < MaxStacks
		Stacks += 1
	EndIf

	; Стак 1 = 5%, стак 2 = 5.5%, стак 3 = 6% ... Формула: First + Extra * (N - 1)
	SetBonus(FirstStackBonus + ExtraStackBonus * (Stacks - 1))

	; Повторная регистрация заменяет предыдущую, то есть таймер снова становится 20 с.
	RegisterForSingleUpdate(BuffDuration)

	; Перезапускаем «иконку», чтобы в меню эффектов снова тикали 20 секунд.
	PlayerRef.DispelSpell(FHS_InsightDisplaySpell)
	FHS_InsightDisplaySpell.Cast(PlayerRef, PlayerRef)

	If ShowNotifications
		Debug.Notification("Озарение: +" + FormatPercent(AppliedBonus) + "% к урону Разрушения (стаков: " + Stacks + ")")
	EndIf
EndFunction

Function ResetInsight()
	{Снимает эффект полностью: обнуляет стаки и убирает бонус. Вызывается по таймеру,
	но безопасна и для ручного вызова (например, перед удалением мода).}
	Stacks = 0
	UnregisterForUpdate()
	SetBonus(0.0)
	PlayerRef.DispelSpell(FHS_InsightDisplaySpell)
EndFunction

Int Function GetStacks()
	Return Stacks
EndFunction

Float Function GetBonus()
	Return AppliedBonus
EndFunction

;=====================================================================================
; СОБЫТИЯ
;=====================================================================================

Event OnUpdate()
	; 20 секунд прошли без новых попаданий: эффект заканчивается.
	ResetInsight()
EndEvent

;=====================================================================================
; СЛУЖЕБНОЕ
;=====================================================================================

Function SetBonus(Float afNewBonus)
	{Доводит наш вклад в DestructionPowerMod до afNewBonus.
	Меняем значение на разницу (delta), а не через SetActorValue: так мы не затираем
	бонусы от зелий, зачарований и других модов.}
	Float delta = afNewBonus - AppliedBonus
	If delta == 0.0
		Return
	EndIf
	; Сначала обновляем состояние, потом делаем внешний вызов. ModActorValue отпускает
	; блокировку скрипта, и параллельный RegisterHit() должен увидеть уже актуальное значение.
	AppliedBonus = afNewBonus
	PlayerRef.ModActorValue("DestructionPowerMod", delta)
EndFunction

String Function FormatPercent(Float afValue)
	{5.5 -> "5.5" (в Papyrus нет форматирования чисел, по умолчанию было бы "5.500000").}
	Int tenths = Math.Floor(afValue * 10.0 + 0.5)
	Return "" + (tenths / 10) + "." + (tenths % 10)
EndFunction
