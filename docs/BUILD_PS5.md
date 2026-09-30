# Сборка и публикация FHS Magic Scaling для PS5

Пошаговая инструкция. Играть мод будет на PS5. ПК нужен как мастерская: на нём собирается плагин, проверяется в игре с консолью и загружается на Bethesda.net. Оттуда PS5 скачивает ровно тот же `.esp`.

Что получится: `FHS_MagicScaling.esp` — плагин без скриптов и ассетов, как описано в [SPEC_PS5.md](SPEC_PS5.md).

---

## 0. Что понадобится

| Что | Где взять |
|---|---|
| Skyrim Special Edition на ПК (Steam), обновлённый | уже есть |
| Creation Kit | Steam → Библиотека → Инструменты → *Skyrim Special Edition: Creation Kit* |
| SSEEdit 4.1.5f (генератор проверен под эту версию) | [Nexus Mods — SSEEdit](https://www.nexusmods.com/skyrimspecialedition/mods/164?tab=files) или [GitHub — TES5Edit releases](https://github.com/TES5Edit/TES5Edit/releases/) |
| Аккаунт Bethesda.net | тот же, что привязан к PS5 |
| Генератор | [`tools/xedit/FHS_BuildMagicScaling.pas`](../tools/xedit/FHS_BuildMagicScaling.pas) из этого репозитория |

---

## 1. Установить SSEEdit и генератор

1. Распакуй архив SSEEdit в отдельную папку, например `C:\Modding\SSEEdit\`. Не в `Program Files`: там Windows мешает записывать файлы.
2. Скопируй `FHS_BuildMagicScaling.pas` в `C:\Modding\SSEEdit\Edit Scripts\`. Эта папка уже есть в архиве SSEEdit.

---

## 2. Собрать плагин

1. Запусти `SSEEdit.exe`. Он сам найдёт игру.
2. Появится список плагинов. Правый клик → *Select None*, затем отметь **Skyrim.esm, Update.esm, Dawnguard.esm, Dragonborn.esm** (Hearthfires и Creation Club не нужны). Нажми OK.
3. Дождись в окне *Messages* справа строки `Background Loader: finished`.
4. Правый клик по `Skyrim.esm` в дереве слева → *Apply Script…* → в списке выбери **FHS_BuildMagicScaling** → OK.
5. Скрипт работает несколько секунд. В конце в *Messages* будет:
   ```
   [FHS] summons patched: 22, skipped: 0
   [FHS] errors: 0, warnings: 0
   [FHS] DONE. Close SSEEdit and save FHS_MagicScaling.esp.
   ```
   - Если есть строки `[FHS] ERROR` или скрипт остановился (`Aborted`), **не сохраняй**. Скопируй всё содержимое вкладки *Messages* (Ctrl+A, Ctrl+C) и пришли мне.
   - Даже если сборка прошла, пришли мне строки `[FHS] vanilla …` и `[FHS] condition tabs: …`, а также все `[FHS] WARNING`. Строки `vanilla` показывают, как устроены условия ванильных перков (например, Блока `ElementalProtection`), и по ним я сверю допущения спецификации.
6. Закрой SSEEdit. Он спросит, какие файлы сохранить: отметь `FHS_MagicScaling.esp` → OK. Файл появится в `…\Skyrim Special Edition\Data\`.

Строки внутри плагина (названия эффектов и описания) на английском. Так они одинаково отображаются на ПК и на PS5 при любом языке игры: кириллица в плагине без файлов перевода могла бы превратиться в «кракозябры», а файлы перевода на PlayStation загрузить нельзя.

---

## 3. Проверить плагин в Creation Kit

1. Запусти Creation Kit → *File → Data…* → отметь `FHS_MagicScaling.esp` → *Set as Active File* → OK.
2. Если CK показывает предупреждения при загрузке, сделай скриншот. Ошибки в ванильных файлах, не связанные с `FHS_`, — это нормально.
3. В *Object Window* введи в фильтр `FHS_` и убедись, что есть: квест `FHS_CoreQuest`, заклинание `FHS_AttunementAbility`, перки `FHS_Attunement` и `FHS_SummonAttunement`, 4 магических эффекта, ключевое слово и список.
4. Открой `FHS_Attunement` → в *Perk Entries* должно быть **34** записи, у `FHS_SummonAttunement` — **64**.
5. Закрой CK **без сохранения**, ничего не меняя.

---

## 4. Проверить на ПК в игре

Тесты удобнее делать на отдельном персонаже, потому что команды ниже меняют уровень.

**Включить плагин.** Открой `%LOCALAPPDATA%\Skyrim Special Edition\Plugins.txt` (если файла нет — создай) и добавь строку:
```
*FHS_MagicScaling.esp
```
Звёздочка означает «включён». Если пользуешься Vortex или Mod Organizer 2, включи плагин там.

**Тестовый персонаж.** В главном меню открой консоль (`~`) и введи `coc qasmoke`: игра откроет тестовую комнату с новым персонажем.

**Узнать FormID записей мода.** В консоли:
```
help FHS_ 4
```
Запомни FormID `FHS_Attunement` и `FHS_SummonAttunement` (вида `xx000801`, где `xx` — номер плагина).

| # | Что проверяем | Команды | Ожидается |
|---|---|---|---|
| 1 | Перк выдан | `player.hasperk <FormID FHS_Attunement>` | `1` |
| 2 | До 30-го уровня ничего не меняется | `player.setlevel 20`, `player.addspell 10F7ED` (Испепеление), `player.addperk 581E7`, `player.addperk 10FCF8` (Разрушительное пламя 1/2 и 2/2). Меню магии → Испепеление | урон **90** |
| 3 | Масштаб Разрушения | `player.setlevel 50` → меню магии | урон **170**, в «Активных эффектах» строка *Magic Resonance* +89% |
| 4 | Абсолютное Разрушение | `player.setav destruction 100`, `player.addperk C44C2` → меню магии | урон **204**, строка *Absolute Destruction* |
| 5 | Потолок | `player.setlevel 80` → меню магии | урон **320** |
| 6 | Зачарования не усиливаются | `player.additem 28E96 1` (даэдрический меч с огнём). Сравни урон огнём в описании зачарования, а лучше удар по одному и тому же NPC, на 20-м и 80-м уровне | урон огнём одинаковый |
| 7 | Призванное оружие | `player.addspell 211EB` (Призванный меч), наколдовать, посмотреть урон в инвентаре на 20-м и 80-м уровне | на 80-м ×1.69 |
| 8 | Пороги воскрешения | `player.setlevel 50`, `player.addspell 96D94` (Ревенант). Найди труп NPC 22–39 уровня: кликни по нему в консоли, `getlevel` покажет уровень. Если рядом нет, призови любого сильного NPC через `player.placeatme`, кликни по нему и введи `kill` | Ревенант поднимает труп (в ванили он работает только до 21-го уровня) |
| 9 | Призывы | `player.setlevel 80`, `player.addspell 10DDEC`, призвать лорда дремору, в консоли кликнуть по нему, `hasperk <FormID FHS_SummonAttunement>` | `1` |
| 10 | Число призывов | `player.addperk D5F1C` (Близнецы-души), призвать дважды | ровно 2 дреморы |
| 11 | Старое сохранение | загрузить обычное сохранение 30+ уровня | в «Активных эффектах» есть *Magic Resonance* |

Если какой-то пункт не совпал, пришли номер пункта и что показала игра (скриншот меню магии или вывод консоли).

---

## 5. Загрузить на Bethesda.net для PlayStation

1. Запусти Creation Kit → *File → Data…* → выбери `FHS_MagicScaling.esp` → *Set as Active File* → OK.
2. В меню *File* выбери вход в Bethesda.net и войди своим аккаунтом.
3. В меню *File* выбери загрузку плагина на Bethesda.net (*Upload Plugin and Archive to Bethesda.net*).
4. *Create New Mod*:
   - **Название:** `FHS Magic Scaling - Destruction and Conjuration`
   - **Платформа:** PlayStation
   - **Архив:** не нужен: на PlayStation загружается только `.esp`
   - **Описание** (можно скопировать):
     ```
     Destruction and Conjuration keep up with enemies at high levels.
     - Destruction damage scales with character level: x1.00 below level 30, up to x2.96 at level 80+.
     - Absolute Destruction / Absolute Conjuration: +20% for masters of the school (skill 100 + master perk).
     - Summons grow with you up to twice their own level; Dremora Lord and atronach thralls grow to the end game.
     - Reanimation and Banish/Command level limits and bound weapons scale too.
     No scripts, no new assets. Requires only the base game (Dawnguard and Dragonborn are included in SE/AE).
     Works on existing saves. Check the "Magic Resonance" line in Active Effects.
     ```
5. Нажми *Upload* и дождись подтверждения.
6. Приватных модов на Bethesda.net нет, мод будет виден всем. Если хочешь, чтобы его не скачивали случайные люди, добавь в начало названия `[WIP]`.

Если CK предлагает сохранить плагин перед загрузкой, отвечай «нет»: загружается уже готовый файл из `Data`.

---

## 6. Установить на PS5

1. Сделай обычное сохранение в игре (без модов) — это точка возврата.
2. Главное меню → **Творения** (Creations) → поиск по названию `FHS Magic Scaling` → *Загрузить* (Download).
3. В меню порядка загрузки проверь, что мод включён. Порядок относительно контента Creation Club не важен.
4. Загрузи сохранение. На персонаже 30+ уровня в «Активных эффектах» появится *Magic Resonance*, а урон заклинаний Разрушения в меню магии вырастет.

Трофеи при включённом моде не выдаются. Чтобы снова их получать, выключи мод и загрузи сохранение, сделанное до его установки.

---

## 7. Обновления и удаление

- **Обновление.** Новая версия собирается тем же генератором и загружается поверх той же страницы мода (*Upload* → выбрать существующий мод). Генератор создаёт записи в одном и том же порядке, поэтому их FormID не меняются и старые сохранения продолжают работать.
- **Удаление.** Выключи мод в «Творениях» и загрузи сохранение. Мод не меняет характеристики персонажа навсегда: способность и перки исчезнут вместе с плагином.

---

## 8. Если что-то пошло не так

Пришли мне:
- весь текст вкладки *Messages* из SSEEdit, если ошибка при сборке;
- номер теста из раздела 4 и скриншот, если результат в игре не совпал;
- что именно видно на PS5 (меню магии, «Активные эффекты»), если проблема только там.

Проверки генератора без игры, которые я уже прогнал (описаны в [`tools/xedit/check/`](../tools/xedit/check/)):
- все ссылки на ванильные записи сверены с данными `Skyrim.esm`, `Dawnguard.esm`, `Dragonborn.esm`;
- скрипт компилируется Free Pascal с заглушками API xEdit без предупреждений;
- прогон на модели SSEEdit 4.1.5f проходит все проверки структуры плагина: 34 + 64 записи перков, условия, OR-флаги и параметры, множители, магические эффекты, способность, квест, 22 правки призывов со счётчиками. Модель собрана по исходникам 4.1.5f (определения записей, `Add`, пути, обработчики смены типа) и повторяет ошибку первой сборки `EPFD - Data can not be edited` на старой версии генератора.

Эти проверки не заменяют запуск в настоящем SSEEdit: модель повторяет только то, что использует генератор. Поэтому сборка — вместе, по логу.
