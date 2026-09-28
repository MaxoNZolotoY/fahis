Scriptname FHS_ModInit extends Quest
{Разовая инициализация мода. Висит на FHS_ControllerQuest (Start Game Enabled).

1. Выдаёт игроку скрытый перк FHS_ElectroshockPerk. Он неактивен, пока на игроке
   нет эффекта «Электрошок».
2. Добавляет тома новых заклинаний в уровневые списки через LeveledItem.AddForm()
   (приём «script injection»). Ванильные записи LeveledItem при этом НЕ редактируются,
   поэтому нет конфликтов с другими модами, которые трогают те же списки.
   Изменения хранятся в сейве и переживают респавн сундука торговца.

Срабатывает и на новой игре, и при установке мода в существующее сохранение.}

Actor Property PlayerRef Auto
{Игрок. Auto-Fill: PlayerRef.}

Perk Property FHS_ElectroshockPerk Auto
{Скрытый перк «Электрошок» (Mod Spell Cost × 0.9 при активном эффекте).}

LeveledItem[] Property TomeLists Auto
{Уровневые списки, куда добавить тома. Сюда кладут ТЕ ЖЕ списки, в которых лежат ванильные
тома «Испепеление», «Ледяное копьё» и «Громовой разряд». Их находят в CK через
Use Info на SpellTomeIncinerate. Так тома попадут и к Фаральде, и в лут
на тех же условиях, что ванильные заклинания уровня «Эксперт».}

Book[] Property Tomes Auto
{Тома новых заклинаний: FHS_SpellTomeFlashFireball, FHS_SpellTomeOverchargedBolt,
FHS_SpellTomeTwinIceSpear.}

Int Property TomeLevel = 1 Auto
{Уровень записи в списке. Поставь такой же, как у ванильного тома в том же списке.}

Int Property TomeCount = 1 Auto
{Количество за одну запись.}

Bool Initialized = False

Event OnInit()
	; Защита от повторного запуска: OnInit у квеста может прийти больше одного раза,
	; а AddForm на каждый вызов добавляет новую запись (появились бы дубли).
	If Initialized
		Return
	EndIf
	Initialized = True

	If FHS_ElectroshockPerk && !PlayerRef.HasPerk(FHS_ElectroshockPerk)
		PlayerRef.AddPerk(FHS_ElectroshockPerk)
	EndIf

	InjectTomes()
EndEvent

Function InjectTomes()
	Int i = 0
	While i < TomeLists.Length
		LeveledItem list = TomeLists[i]
		If list
			Int j = 0
			While j < Tomes.Length
				If Tomes[j]
					list.AddForm(Tomes[j], TomeLevel, TomeCount)
				EndIf
				j += 1
			EndWhile
		EndIf
		i += 1
	EndWhile
EndFunction
