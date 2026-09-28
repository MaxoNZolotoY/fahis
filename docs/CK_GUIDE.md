# «Абсолютное Разрушение»: руководство по сборке в Creation Kit

Skyrim Special Edition / Anniversary Edition, без SKSE, ESL-плагин в формате Creation Club.

Рабочее имя плагина: `FHS_Destruction.esp`. Префикс всех записей и скриптов: `FHS_`.

---

## 0. Что делаем и какие решения приняты

| Элемент | Как реализовано | Скрипт |
|---|---|---|
| **Стремительный огненный шар** | Копия «Испепеления» (одиночная цель, без взрыва), 80 урона огнём + ванильный поджог, скорость снаряда 5800 | `FHS_InsightOnHit` на эффекте урона |
| **Озарение** | Стаки хранит квестовый скрипт. Бонус идёт через актёрское значение `DestructionPowerMod`: его уже учитывает ванильный перк `AlchemySkillBoosts` | `FHS_InsightTracker` |
| **Перегруженный разряд** | Копия «Громового разряда», 78 урона молнией + 39 по мане, тот же мгновенный луч | `FHS_ElectroshockOnHit` на эффекте урона |
| **Электрошок** | Бафф на 30 с + скрытый перк `Mod Spell Cost × 0.9`, который действует, пока бафф на игроке | Нет (только условие перка) |
| **Сдвоенное ледяное копьё** | Два заклинания: игрок кастует первое (120), скрипт через 0.2 с выпускает второе (40 + замедление) | `FHS_TwinSpearPlayerAlias` |
| **Абсолютное Разрушение** | Перк в дереве Разрушения после «Мастера школы Разрушения»: `Mod Spell Magnitude × 1.2` для урона огнём, морозом и молнией | Нет |
| **Распространение** | Тома добавляются в те же уровневые списки, где лежат ванильные тома уровня «Эксперт» (включая товар Фаральды), через `LeveledItem.AddForm`, без правки ванильных записей | `FHS_ModInit` |

### Важно про «Электрошок» (время каста)

В ванильном движке **нет** Perk Entry Point для времени каста (Charge Time) и нет актёрского значения «скорость каста». Проверить это можно в Creation Kit: в списке Entry Point есть `Mod Spell Magnitude`, `Mod Spell Duration`, `Mod Spell Cost` и т. д., а для Charge Time ничего нет. Время каста меняют только SKSE-плагины: aTweaks and Utilities с PEPE добавляют новые entry point, Speed Casting правит код движка. Формат Creation Club/Creations не поддерживает SKSE.

Поэтому, по твоему решению, «Электрошок» в этой версии даёт **−10% к стоимости всех заклинаний**. Механика та же: 30 секунд, без стаков, каждое попадание продлевает. Если позже понадобится версия для ПК с настоящим ускорением каста, её можно сделать отдельным опциональным SKSE-патчем поверх этого же плагина.

---

## 1. Подготовка

1. **Creation Kit.** В Steam: *Библиотека → Инструменты → Skyrim Special Edition: Creation Kit*. При первом запуске CK предложит распаковать `Scripts.zip`: соглашайся. Исходники ванильных скриптов окажутся в `Data\Source\Scripts\`, без них скрипты не скомпилируются.
2. **Скрипты мода.** Скопируй все `.psc` из папки репозитория `Source/Scripts/` в `…\Skyrim Special Edition\Data\Source\Scripts\`.
3. **Новый плагин.** *File → Data…* → отметь `Skyrim.esm` и `Update.esm` → OK. После первой правки: *File → Save* → `FHS_Destruction.esp`. Все используемые ванильные записи лежат в `Skyrim.esm`, DLC не нужны.
4. **Как копировать ванильные записи.** Открой запись, поменяй **EditorID**, нажми OK. CK спросит, создать ли новый объект (*Create new object?*). Отвечай **«Да»**. Если ответить «Нет», ты переименуешь ванильную запись: это правка оригинала и источник конфликтов. Проверять себя удобно в *File → Data → Details*: в плагине должны быть только записи `FHS_*` и одна правка `AVDestruction` из раздела 5.
5. **Кириллица.** Если CK превращает русские названия в `???`, заведи названия на английском и переведи плагин через xTranslator. EditorID всегда пиши латиницей.

### Все записи мода

| Тип | EditorID | На основе |
|---|---|---|
| Projectile | `FHS_FlashFireballProjectile` | снаряд «Испепеления» |
| Magic Effect | `FHS_FlashFireballDamage` | эффект урона «Испепеления» |
| Spell | `FHS_FlashFireball` | Incinerate (`0010F7ED`) |
| Magic Effect | `FHS_InsightDisplayEffect` | новый (Script) |
| Spell | `FHS_InsightDisplaySpell` | новый |
| Magic Effect | `FHS_OverchargedBoltDamage` | эффект урона «Громового разряда» |
| Spell | `FHS_OverchargedBolt` | Thunderbolt (`0010F7EE`) |
| Magic Effect | `FHS_ElectroshockEffect` | новый (Script) |
| Spell | `FHS_ElectroshockBuff` | новый |
| Perk | `FHS_ElectroshockPerk` | новый, скрытый |
| Magic Effect | `FHS_TwinIceSpearDamage` | эффект урона «Ледяного копья» |
| Spell | `FHS_TwinIceSpear` | Icy Spear (`0010F7EC`) |
| Spell | `FHS_TwinIceSpearFollowup` | Icy Spear |
| Perk | `FHS_DestructionMastery` | новый |
| Book ×3 | `FHS_SpellTomeFlashFireball`, `FHS_SpellTomeOverchargedBolt`, `FHS_SpellTomeTwinIceSpear` | ванильные тома этих трёх заклинаний |
| Quest | `FHS_ControllerQuest` | новый |
| ActorValue (правка) | `AVDestruction` | ванильное дерево перков |

Итого около 20 записей, это далеко от лимита ESL.

> Рекомендую сначала создать все записи (разделы 2–5), потом квест и скрипты (раздел 6). Свойства скриптов ссылаются на записи, поэтому к моменту их заполнения записи уже должны существовать.

---

## 2. «Стремительный огненный шар» и «Озарение»

### 2.1. Снаряд `FHS_FlashFireballProjectile`

1. *Object Window → Magic → Spell*, найди **Incinerate** («Испепеление»), открой его эффект двойным щелчком и посмотри поле **Projectile** в Magic Effect.
2. Открой этот снаряд (*Special Effect → Projectile*), поменяй ID на `FHS_FlashFireballProjectile` → «Да».
3. Параметры:

| Поле | Значение | Зачем |
|---|---|---|
| Type | Missile (не меняй) | одиночная цель, как у Испепеления |
| **Speed** | **5800** | быстрее ванильных стрел (по твоим данным 3600–4000; сверь в CK на любом `Arrow…Projectile`) |
| Range | не меняй | дальность как у Испепеления (по ТЗ) |
| Gravity | 0 (не меняй) | летит прямо |
| Explosion | как в оригинале; *не* ставь взрыв от Fireball | иначе появится урон по площади |

> Хочешь визуально «огненный шар»: можно взять **Model** и **Light** из снаряда Fireball, но поле **Explosion** оставь как у Испепеления, а у эффекта в заклинании **Area = 0**. Иначе заклинание начнёт взрываться и бить по площади.

### 2.2. Эффект урона `FHS_FlashFireballDamage`

1. Открой эффект урона Incinerate (тот, что открыл в 2.1), поменяй ID → `FHS_FlashFireballDamage` → «Да».
2. **Оставь как есть:** Archetype *Value Modifier* (Health), Resist Value *ResistFire*, Magic Skill *Destruction*, Minimum Skill Level *75*, Casting Type *Fire and Forget*, Delivery *Aimed*, все **Keywords** (обязательно `MagicDamageFire`, иначе не сработают «Разрушительное пламя» и перк из раздела 5), шейдеры, Impact Data Set, звуки.
3. **Поджог.** В ванили догорание реализовано через поля **Taper Weight / Taper Curve / Taper Duration** этого эффекта: после попадания урон продолжает капать и угасает. Не меняй эти поля, тогда «стандартный поджог» сохранится.
4. **Меняешь:**
   - **Projectile** → `FHS_FlashFireballProjectile`;
   - **Description** → `Огненный снаряд наносит <mag> ед. урона огнём. Попадание по врагу даёт «Озарение».`;
   - **Papyrus Scripts** → *Add…* → `FHS_InsightOnHit`. Свойства заполнишь в разделе 6.

### 2.3. Заклинание `FHS_FlashFireball`

1. Открой **Incinerate**, ID → `FHS_FlashFireball` → «Да».
2. **Full Name:** `Стремительный огненный шар`.
3. В списке **Effects** открой эффект двойным щелчком: Effect → `FHS_FlashFireballDamage`, **Magnitude 80**, Area 0, Duration 0.
4. **Не меняй:** Type *Spell*, Casting *Fire and Forget*, Delivery *Aimed*, Equip Type *EitherHand*, Charge Time, Half-cost Perk (`DestructionExpert75`).
5. **Стоимость:** оставь *Auto-Calc*, она вырастет пропорционально урону. Для фиксированной цены отметь *Manual Cost* и впиши значение.

### 2.4. Индикатор «Озарения»: `FHS_InsightDisplayEffect` и `FHS_InsightDisplaySpell`

Индикатор не влияет на урон (бонус держит скрипт). Он только показывает иконку и таймер в меню «Активные эффекты».

**Magic Effect `FHS_InsightDisplayEffect`** (*Magic → Magic Effect → New*):

| Поле | Значение |
|---|---|
| Name | `Озарение` |
| Archetype | **Script** |
| Casting Type / Delivery | Fire and Forget / **Self** |
| Magic Skill | None |
| Flags | **No Magnitude** ✓, **No Area** ✓, Hide in UI ✗, Detrimental ✗ |
| Description | `Урон заклинаний Разрушения повышен. Каждое попадание «Стремительным огненным шаром» усиливает эффект и продлевает его.` |

**Spell `FHS_InsightDisplaySpell`** (*Magic → Spell → New*): Type *Spell*, Casting *Fire and Forget*, Delivery *Self*, **Manual Cost 0**, флаг *No Absorb/Reflect* ✓. Effects: `FHS_InsightDisplayEffect`, Magnitude 0, **Duration 20**.

### 2.5. Как работает «Озарение»

```
Попадание снаряда ─► на цели стартует FHS_FlashFireballDamage
                     └─► FHS_InsightOnHit.OnEffectStart
                         (стрелял игрок? цель жива и враждебна?)
                         └─► FHS_ControllerQuest.RegisterHit()   [FHS_InsightTracker]
                             • стаки + 1
                             • бонус = 5 + 0.5 × (стаки − 1) %
                             • DestructionPowerMod += разница
                             • RegisterForSingleUpdate(20)  ← таймер снова 20 с
                             • перекастовать индикатор
20 с без попаданий ─► OnUpdate ─► бонус вычитается, стаки = 0
```

**Почему `DestructionPowerMod`.** Это ванильное актёрское значение. Скрытый перк `AlchemySkillBoosts`, который есть у игрока с начала игры, умножает магнитуду заклинаний Разрушения на `1 + DestructionPowerMod / 100`. Этим же механизмом работают зелья «Усиление Разрушения». Скрипт меняет значение только на разницу (`ModActorValue`) и помнит, сколько добавил, поэтому чужие бонусы не затираются.

**Почему стаки не в ActiveMagicEffect.** При повторном наложении того же заклинания движок завершает старый эффект и запускает новый, и счётчик внутри эффекта обнулился бы. Квестовый скрипт живёт всё время, а повторный вызов `RegisterForSingleUpdate` сам перезапускает таймер.

---

## 3. «Перегруженный разряд» и «Электрошок»

### 3.1. Эффект урона `FHS_OverchargedBoltDamage`

1. Открой **Thunderbolt** («Громовой разряд»), затем его эффект урона. ID → `FHS_OverchargedBoltDamage` → «Да».
2. **Projectile не трогай.** Луч Thunderbolt мгновенный, ванильный снаряд можно использовать повторно, копия не нужна.
3. **Урон по мане.** Посмотри **Archetype**:
   - **Dual Value Modifier** (Health + Magicka, *Second AV Weight 0.5*): урон по мане считается сам, половина от магнитуды. Больше ничего делать не нужно;
   - если мана снимается **отдельным эффектом** в заклинании, выставишь ему магнитуду 39 на шаге 3.2.
4. Keywords оставь (`MagicDamageShock`).
5. **Papyrus Scripts** → *Add…* → `FHS_ElectroshockOnHit`. Вешай только на эффект урона по здоровью.

### 3.2. Заклинание `FHS_OverchargedBolt`

1. Открой **Thunderbolt**, ID → `FHS_OverchargedBolt` → «Да».
2. Full Name: `Перегруженный разряд`.
3. Эффект урона → `FHS_OverchargedBoltDamage`, **Magnitude 78** (60 × 1.3). Если мана снимается отдельным эффектом, поставь ему **39**.
4. Остальное как у Thunderbolt: Fire and Forget, Aimed, тот же Charge Time.

### 3.3. Бафф «Электрошок»

**Magic Effect `FHS_ElectroshockEffect`**: Name `Электрошок`, Archetype **Script**, Fire and Forget / **Self**, Magic Skill None, флаги *No Magnitude* ✓ и *No Area* ✓. Description: `Стоимость всех заклинаний снижена на 10%.`

**Spell `FHS_ElectroshockBuff`**: Type Spell, Fire and Forget, Self, **Manual Cost 0**, *No Absorb/Reflect* ✓. Effects: `FHS_ElectroshockEffect`, **Duration 30**.

**Perk `FHS_ElectroshockPerk`** (*Character → Perk → New*):

| Поле | Значение |
|---|---|
| Playable | ✗ |
| Hidden | ✓ |
| Perk Entries → New | Type **Entry Point**, Rank 1, Priority 0 |
| Entry Point | **Mod Spell Cost** |
| Function | **Multiply Value**, значение **0.9** |
| Условие, вкладка *Perk Owner* | `HasMagicEffect` → `FHS_ElectroshockEffect` `== 1`, Run On: Subject |
| Условие, вкладка *Spell* | пусто: действует на любые заклинания |

Логика: перк висит на игроке постоянно (его выдаёт `FHS_ModInit`), но действует только пока на игроке эффект `FHS_ElectroshockEffect`. Скрипт `FHS_ElectroshockOnHit` при каждом попадании снимает бафф и накладывает заново, поэтому таймер возвращается к 30 с, а процент не растёт.

---

## 4. «Сдвоенное ледяное копьё»

### 4.1. Как делается очередь из двух снарядов

- **Sub-Spells в Skyrim нет.** Все эффекты одного заклинания летят одним снарядом с общим Delivery.
- **Trigger Spell с задержкой тоже нет.** У записей Spell и Magic Effect нет поля «через N секунд выпустить другое заклинание».
- **Работающий вариант: два заклинания и скрипт.** Игрок кастует `FHS_TwinIceSpear`. Скрипт на алиасе игрока ловит событие `OnSpellCast`, ждёт `FollowupDelay` (0.2 с) и выпускает от игрока `FHS_TwinIceSpearFollowup`. Получается очередь «тук-тук» в направлении взгляда.

### 4.2. Эффект урона `FHS_TwinIceSpearDamage`

Открой **Icy Spear**, затем его эффект урона. ID → `FHS_TwinIceSpearDamage` → «Да». Ничего не меняй: снаряд ванильный, Keywords `MagicDamageFrost`, Archetype (урон по здоровью и запасу сил). Этот эффект используют **оба** копья, с разной магнитудой.

### 4.3. Первое копьё `FHS_TwinIceSpear`

1. Открой **Icy Spear**, ID → `FHS_TwinIceSpear` → «Да». Full Name: `Сдвоенное ледяное копьё`.
2. Effects:
   - эффект урона → `FHS_TwinIceSpearDamage`, **Magnitude 120**;
   - **эффект замедления удали.** В ванильных ледяных заклинаниях замедление — отдельный эффект (Peak Value Modifier, ограничивает SpeedMult до 50). По ТЗ замедляет только второе копьё. Хочешь, чтобы замедляли оба, — оставь.
3. Остальное как у Icy Spear.

### 4.4. Второе копьё `FHS_TwinIceSpearFollowup`

1. Ещё раз открой **Icy Spear**, ID → `FHS_TwinIceSpearFollowup` → «Да». Full Name: `Сдвоенное ледяное копьё`.
2. Effects: `FHS_TwinIceSpearDamage` с **Magnitude 40** + ванильный эффект замедления (оставить как есть: 50%).
3. **Manual Cost 0**, Charge Time 0, Half-cost Perk пусто. Игроку это заклинание **не выдаётся** и тома у него нет. `Cast()` из скрипта не тратит ману и не ждёт каста.

### 4.5. Альтернатива: второе копьё только при попадании

Если нужно, чтобы второе копьё летело прицельно в цель и только когда первое попало:

1. Сделай второму копью **отдельный** эффект урона: ещё одну копию эффекта Icy Spear, например `FHS_TwinIceSpearFollowupDamage`, без скрипта. Иначе второе копьё будет запускать третье и так далее.
2. Убери `FHS_TwinSpearPlayerAlias` с алиаса.
3. Повесь на `FHS_TwinIceSpearDamage` (эффект первого копья) скрипт такого вида:

```papyrus
Scriptname FHS_TwinSpearOnHit extends ActiveMagicEffect

Actor Property PlayerRef Auto
Spell Property FHS_TwinIceSpearFollowup Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If akCaster == PlayerRef && akTarget != akCaster
		Utility.Wait(0.15)
		FHS_TwinIceSpearFollowup.Cast(akCaster, akTarget) ; снаряд летит в цель
	EndIf
EndEvent
```

---

## 5. Перк «Абсолютное Разрушение» (`FHS_DestructionMastery`)

### 5.1. Запись перка

*Character → Perk → New*:

| Поле | Значение |
|---|---|
| ID | `FHS_DestructionMastery` |
| Name | `Абсолютное Разрушение` |
| Description | `Урон заклинаний Разрушения увеличен на 20%.` |
| Playable | ✓ |
| Hidden | ✗ |
| Num Ranks | 1 |
| Conditions (перка) | `GetBaseActorValue` `Destruction` `>= 100`, Run On: Subject |

Связь с «Мастером школы Разрушения» (`DestructionMaster100`) задаётся линией в дереве (5.3). Дополнительно можно добавить условие `HasPerk DestructionMaster100 == 1`, это страховка на случай, если связь в дереве собьётся.

### 5.2. Entry Point

*Perk Entries → New*: Type **Entry Point**, Rank 1, Priority 0.

| Поле | Значение |
|---|---|
| Entry Point | **Mod Spell Magnitude** |
| Function | **Multiply Value** |
| Value | **1.20** |

Условия на вкладке **Spell** (порядок и AND/OR важны):

```
EPMagic_SpellHasSkill    Destruction        == 1   AND
EPMagic_SpellHasKeyword  MagicDamageFire    == 1   OR
EPMagic_SpellHasKeyword  MagicDamageFrost   == 1   OR
EPMagic_SpellHasKeyword  MagicDamageShock   == 1
```

- В CK подряд идущие OR объединяются в блок и вычисляются **раньше** AND. Список читается как `Разрушение AND (огонь OR мороз OR молния)`.
- **Зачем `EPMagic_SpellHasSkill`.** Ванильные «Разрушительное пламя/холод/молния» проверяют только ключевое слово, поэтому заодно усиливают стихийные зачарования на оружии (известный ванильный баг). Проверка школы отсекает зачарования.

### 5.3. Добавление в дерево перков Разрушения

Дерево перков хранится в записи ActorValue **`AVDestruction`**. Её правка — это override ванильной записи.

**В xEdit (надёжнее).** Названия полей могут чуть отличаться в зависимости от версии xEdit.
1. Загрузи `FHS_Destruction.esp`, найди `ActorValue Information → AVDestruction`, *Copy as override into…* → свой плагин.
2. В **Perk Tree** добавь узел: `PNAM` = `FHS_DestructionMastery`, `INAM` = свободный индекс (максимальный существующий + 1), `XNAM/YNAM` (клетка сетки) и `HNAM/VNAM` (смещение) — рядом с узлом `DestructionMaster100`, например на ряд выше.
3. В узле `DestructionMaster100` добавь в `CNAM` (соединения) индекс нового узла. Так рисуется линия «Мастер → Абсолютное Разрушение».

**В Creation Kit** дерево правится в окне Actor Values (меню *Character*), но редактор неудобный и иногда сбивает связи. Итог проверяй в игре.

> ⚠️ **Конфликт.** Любой мод, который правит дерево Разрушения (Ordinator, Vokrii, Adamant и др.), конфликтует с `AVDestruction`: побеждает тот, кто ниже в порядке загрузки. Для таких сборок нужен патч. Без SKSE-фреймворков это неизбежная цена нового перка в ванильном дереве.

---

## 6. Квест-контроллер, компиляция и свойства скриптов

### 6.1. Компиляция

**Вариант А: в CK.** *Gameplay → Papyrus Script Manager* → выдели `FHS_*` → ПКМ → *Compile*. Скомпилированные `.pex` появятся в `Data\Scripts\`.

**Вариант Б: командная строка** (из папки `…\Skyrim Special Edition\Papyrus Compiler\`):

```bat
PapyrusCompiler.exe "FHS_InsightTracker.psc" -f="TESV_Papyrus_Flags.flg" -i="..\Data\Source\Scripts" -o="..\Data\Scripts"
PapyrusCompiler.exe "FHS_InsightOnHit.psc" -f="TESV_Papyrus_Flags.flg" -i="..\Data\Source\Scripts" -o="..\Data\Scripts"
PapyrusCompiler.exe "FHS_ElectroshockOnHit.psc" -f="TESV_Papyrus_Flags.flg" -i="..\Data\Source\Scripts" -o="..\Data\Scripts"
PapyrusCompiler.exe "FHS_TwinSpearPlayerAlias.psc" -f="TESV_Papyrus_Flags.flg" -i="..\Data\Source\Scripts" -o="..\Data\Scripts"
PapyrusCompiler.exe "FHS_ModInit.psc" -f="TESV_Papyrus_Flags.flg" -i="..\Data\Source\Scripts" -o="..\Data\Scripts"
```

`FHS_InsightOnHit` ссылается на тип `FHS_InsightTracker`, поэтому трекер компилируется первым (компилятор находит его сам, если оба файла лежат в `Source\Scripts`).

Удобная альтернатива: VS Code с расширением **Papyrus** (joelday/papyrus-lang): подсветка, проверка ошибок и компиляция по Ctrl+Shift+B.

### 6.2. Квест `FHS_ControllerQuest`

*Character → Quest → New*:

| Вкладка / поле | Значение |
|---|---|
| Quest Data → ID | `FHS_ControllerQuest` |
| Name | `FHS Controller` (игроку не показывается) |
| **Start Game Enabled** | ✓ |
| Run Once | ✗ |
| Priority | 50 |
| Quest Aliases → New Reference Alias | Name `Player`, Fill Type **Specific Reference** → `PlayerRef` (*'Player'*) |
| Скрипты на алиасе `Player` | `FHS_TwinSpearPlayerAlias` |
| Scripts (вкладка квеста) | `FHS_InsightTracker`, `FHS_ModInit` |

У квеста нет диалогов, поэтому SEQ-файл не нужен.

### 6.3. Свойства (Properties)

Кнопка **Auto-Fill All** в окне свойств сама заполнит всё, у чего имя свойства совпадает с EditorID записи: `PlayerRef` и все `FHS_…`. Остальное задаётся вручную или остаётся по умолчанию.

| Скрипт → где висит | Свойство | Значение |
|---|---|---|
| `FHS_InsightTracker` → квест | `PlayerRef` | PlayerRef (Auto-Fill) |
| | `FHS_InsightDisplaySpell` | `FHS_InsightDisplaySpell` (Auto-Fill) |
| | `BuffDuration` | 20.0 |
| | `FirstStackBonus` | 5.0 (% за 1-е попадание) |
| | `ExtraStackBonus` | 0.5 (% за каждое следующее) |
| | `MaxStacks` | 0 = без потолка (как в ТЗ); 21 даст потолок +15% |
| | `ShowNotifications` | False; для тестов True |
| `FHS_ModInit` → квест | `PlayerRef` | PlayerRef (Auto-Fill) |
| | `FHS_ElectroshockPerk` | `FHS_ElectroshockPerk` (Auto-Fill) |
| | `TomeLists` | уровневые списки из раздела 7 |
| | `Tomes` | три тома `FHS_SpellTome…` |
| | `TomeLevel` / `TomeCount` | 1 / 1 (или как у ванильного тома в этом списке) |
| `FHS_TwinSpearPlayerAlias` → алиас Player | `FHS_TwinIceSpear` | Auto-Fill |
| | `FHS_TwinIceSpearFollowup` | Auto-Fill |
| | `FollowupDelay` | 0.2 |
| `FHS_InsightOnHit` → `FHS_FlashFireballDamage` | `PlayerRef` | Auto-Fill |
| | `FHS_ControllerQuest` | Auto-Fill (квест со скриптом трекера) |
| | `RequireHostileTarget` | True |
| `FHS_ElectroshockOnHit` → `FHS_OverchargedBoltDamage` | `PlayerRef` | Auto-Fill |
| | `FHS_ElectroshockBuff` | Auto-Fill |
| | `RequireHostileTarget` | True |

`RequireHostileTarget = True` засчитывает только попадания по враждебным целям. Без этого можно «накрутить» стаки на компаньоне или по трупу.

---

## 7. Распространение: тома, уровневые списки, Фаральда

### 7.1. Тома заклинаний

Для каждого заклинания открой ванильный том (*Items → Book*, фильтр `Incinerate` / `Thunderbolt` / `Icy`), поменяй ID → «Да»:

| Поле | Значение |
|---|---|
| ID | `FHS_SpellTomeFlashFireball` (и т. д.) |
| Name | `Том заклинания: Стремительный огненный шар` |
| Teaches → Spell | `FHS_FlashFireball` |
| Модель, вес, цена | как у оригинала |

### 7.2. Куда класть, без конфликтов

**Не редактируй ванильные уровневые списки напрямую.** Такая правка — override: побеждает последний мод в порядке загрузки, и добавки других модов пропадают (без Bashed Patch).

Вместо этого `FHS_ModInit` при старте добавляет тома в списки через `LeveledItem.AddForm()`. Ванильные записи в плагине не меняются, изменения хранятся в сохранении и переживают респавн сундука торговца.

**Какие списки указать в `TomeLists`:**

1. В CK найди ванильный том «Испепеление» → ПКМ → **Use Info**. Откроется список всех записей, где он используется, включая уровневые списки.
2. Отбери уровневые списки (LeveledItem), где лежат ванильные тома уровня «Эксперт» по Разрушению. Скорее всего там окажутся и списки для лута, и списки торговцев.
3. Чтобы узнать, какой из них у **Фаральды**, открой её сундук торговца **`MerchantWCollegeFaraldaChest`** (*WorldObjects → Container*) и посмотри, какие списки томов в нём лежат. Торговцы Коллегии продают тома уровня «Эксперт» своей школы при навыке 65+. Если положить новые тома в тот же список, условия продажи будут такими же, как у ванильных.
4. Если нужна только Фаральда, а лут не нужен, укажи в `TomeLists` только её список.

Новые тома появятся у Фаральды после респавна её сундука (~48 игровых часов) или сразу на новой игре.

---

## 8. ESL-флаг (формат Creation Club)

### 8.1. Лимиты

| Версия заголовка | Диапазон новых FormID | Максимум новых записей | Работает на |
|---|---|---|---|
| 1.70 (обычный) | `0x800`–`0xFFF` | 2048 | всех SE/AE |
| 1.71 | `0x000`–`0xFFF` | 4096 | только игра **1.6.1130+** |

У мода около 20 записей, поэтому оставляй заголовок **1.70**: так плагин совместим со всеми версиями.

### 8.2. Порядок действий

1. Работай в CK с обычным `.esp` без флага.
2. Перед релизом открой плагин в **xEdit (SSEEdit)**:
   - ПКМ по плагину → **Check for Errors**: ошибок быть не должно;
   - ПКМ → **Compact FormIDs for ESL**. Нужно, только если какие-то FormID вышли за `0xFFF`. У нового плагина CK обычно нумерует с `0x800`, так что при 20 записях это, скорее всего, не понадобится;
   - открой **File Header → Record Flags** → отметь **ESL** → сохрани.
3. После каждой правки в CK проверяй плагин в xEdit заново: CK может выдать новым записям FormID вне диапазона ESL.
4. **Никогда не сжимай FormID после публикации:** это ломает сохранения пользователей.

### 8.3. Упаковка и публикация

- **Скрипты** `.pex` лежат в `Data\Scripts\`. Для релиза упакуй их в архив с тем же именем, что у плагина (`FHS_Destruction.bsa`): *File → Create Archive* в CK. Архив с именем плагина игра подгружает сама.
- **Creations (Bethesda.net):** загрузка идёт из CK (*File → Upload Plugin and Archive to Bethesda.net*). Бесплатный мод может загрузить любой автор. Платные Creations выпускают только участники программы **Verified Creators**, по заявке и договору с Bethesda.
- **Консоли:** Xbox поддерживает скрипты. На PlayStation, насколько мне известно, Creations не могут содержать своих скриптов и ассетов. Там останутся заклинания и перк, но без «Озарения», «Электрошока» и второго копья.
- **Nexus:** ESP с ESL-флагом (ESPFE) плюс BSA или папка `Scripts`.

---

## 9. Тестирование

1. **Логи Papyrus.** В `Documents\My Games\Skyrim Special Edition\Skyrim.ini` добавь:
   ```ini
   [Papyrus]
   bEnableLogging=1
   bEnableTrace=1
   bLoadDebugInformation=1
   ```
   Лог: `Documents\My Games\Skyrim Special Edition\Logs\Script\Papyrus.0.log`.
2. **Чистый тест.** Из главного меню: консоль → `coc qasmoke` (тестовая ячейка).
3. **Команды консоли:**
   - `help "<часть названия>" 4` — найти FormID (у ESL они вида `FE xxx yyy`);
   - `player.addspell <ID>`, `player.setav destruction 100`, `player.addperk <ID>`;
   - `player.getav DestructionPowerMod` — до и после попаданий «Огненным шаром»: +5, +5.5, +6… и возврат к исходному через 20 с без попаданий.
4. **Чек-лист:**
   - [ ] «Огненный шар» летит заметно быстрее стрел, урон 80 + догорание;
   - [ ] «Озарение» появляется только при попадании по врагу (не при промахе, не по компаньону), таймер 20 с обновляется;
   - [ ] «Перегруженный разряд»: 78 по здоровью, 39 по мане; «Электрошок» 30 с, стоимость заклинаний −10% (видно в меню магии);
   - [ ] «Ледяное копьё»: два снаряда с паузой ~0.2 с; второе замедляет;
   - [ ] перк виден в дереве после «Мастера», требует 100 навыка, урон +20%;
   - [ ] тома у Фаральды и в луте;
   - [ ] в `Papyrus.0.log` нет ошибок с `FHS_`.

---

## 10. Ограничения и совместимость

- **`AlchemySkillBoosts`.** «Озарение» опирается на этот ванильный скрытый перк. Если оверхол его удалит или переделает, «Озарение» перестанет влиять на урон.
- **Удаление мода во время «Озарения».** Бонус к `DestructionPowerMod` останется навсегда. Перед удалением подожди 20 с после последнего попадания. Если уже поздно: `player.getav DestructionPowerMod`, затем `player.modav DestructionPowerMod -<лишнее>`.
- **Второе копьё.** `Spell.Cast()` без цели выпускает снаряд туда, куда смотрит персонаж. В виде от третьего лица при свободной камере направление может отличаться от прицела. Проверь в игре; если мешает, используй вариант из 4.5.
- **Кириллица в уведомлениях.** Отладочное `Debug.Notification` из `FHS_InsightTracker` (при `ShowNotifications = True`) может показать «кракозябры»: это зависит от кодировки `.psc`. Тогда пересохрани файл в Windows-1251 и перекомпилируй. На геймплей это не влияет.
- **Дерево перков.** См. предупреждение в 5.3.

---

## Приложение: формулы и цифры

**Озарение:** `бонус(N) = 5 + 0.5 × (N − 1) %`, где N — число попаданий подряд (без 20-секундных пауз).

| Попаданий | 1 | 5 | 10 | 20 | 30 |
|---|---|---|---|---|---|
| Бонус | +5% | +7% | +9.5% | +14.5% | +19.5% |

**Итоговый урон.** Множители `Mod Spell Magnitude` от разных перков перемножаются:

```
Урон = База × Π(множители перков) × (1 + DestructionPowerMod / 100)
```

Пример: «Стремительный огненный шар» с «Разрушительным пламенем» 2/2 (×1.5 по описанию перка), «Абсолютным Разрушением» (×1.2) и 10 стаками «Озарения» (+9.5%):
`80 × 1.5 × 1.2 × 1.095 ≈ 158` урона огнём, плюс догорание.

| Заклинание | Урон |
|---|---|
| Стремительный огненный шар | 80 огнём + поджог |
| Перегруженный разряд | 78 по здоровью + 39 по мане |
| Сдвоенное ледяное копьё | 120 + 40 = 160 по здоровью и запасу сил, второе копьё замедляет на 50% |
| Электрошок | стоимость × 0.9 (перемножается с другими скидками) |

---

## Источники (проверенные факты)

- DestructionPowerMod и перк AlchemySkillBoosts (бонус = 1 + значение × 0.01): [UESP — Actor Value Indices](https://en.uesp.net/wiki/Skyrim_Mod:Actor_Value_Indices), [Nexus Forums — PowerMod AVs](https://forums.nexusmods.com/topic/4022955-le-do-npcs-have-the-powermod-avs/)
- Имя значения в Papyrus (`"DestructionPowerMod"`) в реальном скрипте: [GBT_Script_LegendaryBonus.psc](https://github.com/Rukan/Grimy-Skyrim-Papyrus-Source/blob/master/GBT_Script_LegendaryBonus.psc)
- Время каста меняется только через SKSE: [aTweaks and Utilities](https://www.nexusmods.com/skyrimspecialedition/mods/107741), [Speed Casting SKSE Remake](https://www.nexusmods.com/skyrimspecialedition/mods/36574)
- Поджог через Taper: [UESP — Tapering](https://en.m.uesp.net/wiki/Skyrim:Tapering), [UESP — Fire Damage](https://en.uesp.net/wiki/Skyrim:Fire_Damage)
- Замедление от мороза — Peak Value Modifier: [Frost Slow Tweaks](https://www.nexusmods.com/skyrimspecialedition/mods/26584)
- EPMagic_SpellHasKeyword и баг с зачарованиями: [CK Wiki](https://skyrimck.uesp.net/wiki/EPMagic_SpellHasKeyword), [Weapon Enchantments Fixed](https://www.nexusmods.com/skyrimspecialedition/mods/42634)
- Приоритет OR над AND в условиях: [CK Wiki — Condition Functions](https://ck.uesp.net/wiki/Condition_Functions)
- EditorID перков Разрушения: [UESP — Destruction](https://en.uesp.net/wiki/Skyrim:Destruction)
- Сундук Фаральды `MerchantWCollegeFaraldaChest`: [Steam CK Public — adding new loot](https://steamcommunity.com/groups/SkyrimCKPublic/discussions/0/828939978537834610/)
- Торговцы Коллегии продают тома «Эксперт» при навыке 65+: [Fandom — Spell Tomes](https://elderscrolls.fandom.com/wiki/Spell_Tomes_(Skyrim))
- ESL: лимиты и заголовок 1.71: [ESLify guide](https://www.nexusmods.com/skyrimspecialedition/mods/21618), [Tome of xEdit](https://tes5edit.github.io/docs/8-managing-mod-files.html)
- FormID ванильных заклинаний: [Skyrim Commands — Spells](https://skyrimcommands.com/spells)
