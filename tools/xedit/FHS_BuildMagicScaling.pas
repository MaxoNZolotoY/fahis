{
  FHS Magic Scaling: генератор плагина FHS_MagicScaling.esp для SSEEdit.

  Что делает: создаёт с нуля плагин из docs/SPEC_PS5.md (модули D, C1-C4).
  В плагине нет скриптов и ассетов, поэтому его можно загрузить на
  Bethesda.net для PlayStation.

  Как запускать (подробно: docs/BUILD_PS5.md):
    1. Скопировать этот файл в папку "Edit Scripts" рядом с SSEEdit.exe.
    2. Запустить SSEEdit, в списке плагинов оставить отмеченными только
       Skyrim.esm, Update.esm, Dawnguard.esm, Dragonborn.esm.
    3. Правый клик по любому плагину -> Apply Script -> FHS_BuildMagicScaling.
    4. Дождаться строки "[FHS] DONE" в окне Messages. Если там есть ERROR,
       прислать весь лог.
    5. Закрыть SSEEdit и сохранить FHS_MagicScaling.esp.

  Все числа берутся из блока GENERATED VALUES. Его пересобирает
  tools/sync_xedit_values.py из модели tools/scaling_model.py.
  Руками этот блок не правь.

  Строки внутри плагина только на английском (ASCII): так они одинаково
  отображаются на ПК и на PS5 при любом языке игры.
}
unit UserScript;

const
  cPluginName = 'FHS_MagicScaling.esp';
  cPlayerRef = '00000014';

  cEPSpellMag = 'Mod Spell Magnitude';
  cEPAttack = 'Mod Attack Damage';
  cEPIncoming = 'Mod Incoming Damage';
  cEPIncomingSpell = 'Mod Incoming Spell Magnitude';

  // Флаги магического эффекта (DATA\Flags)
  cFlagNoDuration = 512;
  cFlagNoMagnitude = 1024;
  cFlagNoArea = 2048;
  cFlagHideInUI = 32768;

  // Номер актёрского значения Health
  cAVHealth = 24;

var
  gFile: IInterface;
  gErrors, gWarnings, gPriority: Integer;

  // Записи ванили
  gKwdFire, gKwdFrost, gKwdShock, gKwdDrain: IInterface;
  gPerkDestrMaster, gPerkConjMaster: IInterface;

  // Новые записи
  gKwdEndgame, gBoundList, gPlayerPerk, gSummonPerk: IInterface;
  gCarrier, gDisplayResonance, gDisplayAbsDestr, gDisplayAbsConj: IInterface;
  gAbility, gQuest: IInterface;

  // Вкладки условий по точкам входа (уточняются по ванильным перкам)
  gTabsSpellMag, gTabsAttack, gTabsIncoming, gTabsIncomingSpell: Integer;
  gSpellTabSpellMag, gWeaponTabAttack, gSpellTabIncomingSpell: Integer;

  gNpcPatched, gNpcSkipped: Integer;

// BEGIN GENERATED VALUES (tools/sync_xedit_values.py, не править руками)

function DestrBandCount: Integer;
begin
  Result := 11;
end;

function DestrBandFirst: Integer;
begin
  Result := 30;
end;

function DestrBandStep: Integer;
begin
  Result := 5;
end;

function SummonMilestoneCount: Integer;
begin
  Result := 15;
end;

function SummonMilestoneFirst: Integer;
begin
  Result := 10;
end;

function SummonMilestoneStep: Integer;
begin
  Result := 5;
end;

function AbsoluteMilli: Integer;
begin
  Result := 1200;
end;

function AbsoluteInvMilli: Integer;
begin
  Result := 833;
end;

// Резонанс Разрушения и пороги Колдовства, ступенька i (модуль D1, C3)
function DestrMilli(i: Integer): Integer;
begin
  case i of
    0: Result := 1180;
    1: Result := 1360;
    2: Result := 1540;
    3: Result := 1710;
    4: Result := 1890;
    5: Result := 2070;
    6: Result := 2250;
    7: Result := 2430;
    8: Result := 2610;
    9: Result := 2790;
    10: Result := 2960;
  else
    Result := 0;
  end;
end;

// То же в процентах прибавки, для строки в «Активных эффектах»
function DestrPercent(i: Integer): Integer;
begin
  case i of
    0: Result := 18;
    1: Result := 36;
    2: Result := 54;
    3: Result := 71;
    4: Result := 89;
    5: Result := 107;
    6: Result := 125;
    7: Result := 143;
    8: Result := 161;
    9: Result := 179;
    10: Result := 196;
  else
    Result := 0;
  end;
end;

// Призванное оружие, ступенька i (модуль C4)
function BoundMilli(i: Integer): Integer;
begin
  case i of
    0: Result := 1060;
    1: Result := 1130;
    2: Result := 1190;
    3: Result := 1250;
    4: Result := 1310;
    5: Result := 1370;
    6: Result := 1440;
    7: Result := 1500;
    8: Result := 1560;
    9: Result := 1630;
    10: Result := 1690;
  else
    Result := 0;
  end;
end;

// Шаг рубежа призывов i: урон ×r (модуль C1)
function SummonStepMilli(i: Integer): Integer;
begin
  case i of
    0: Result := 1625;
    1: Result := 1385;
    2: Result := 1278;
    3: Result := 1217;
    4: Result := 1179;
    5: Result := 1152;
    6: Result := 1132;
    7: Result := 1116;
    8: Result := 1104;
    9: Result := 1094;
    10: Result := 1086;
    11: Result := 1079;
    12: Result := 1074;
    13: Result := 1068;
    14: Result := 1064;
  else
    Result := 0;
  end;
end;

// Шаг рубежа призывов i: входящий урон ×1/r (модуль C1)
function SummonStepInvMilli(i: Integer): Integer;
begin
  case i of
    0: Result := 615;
    1: Result := 722;
    2: Result := 782;
    3: Result := 822;
    4: Result := 848;
    5: Result := 868;
    6: Result := 883;
    7: Result := 896;
    8: Result := 906;
    9: Result := 914;
    10: Result := 921;
    11: Result := 927;
    12: Result := 931;
    13: Result := 936;
    14: Result := 940;
  else
    Result := 0;
  end;
end;

// Минимальный уровень призыва для рубежа i (правило 2×)
function SummonMinLevel(i: Integer): Integer;
begin
  case i of
    0: Result := 5;
    1: Result := 8;
    2: Result := 10;
    3: Result := 13;
    4: Result := 15;
    5: Result := 18;
    6: Result := 20;
    7: Result := 23;
    8: Result := 25;
    9: Result := 28;
    10: Result := 30;
    11: Result := 33;
    12: Result := 35;
    13: Result := 38;
    14: Result := 40;
  else
    Result := 0;
  end;
end;

// END GENERATED VALUES

//============================================================================
// Журнал
//============================================================================

procedure Info(s: string);
begin
  AddMessage('[FHS] ' + s);
end;

procedure Warn(s: string);
begin
  gWarnings := gWarnings + 1;
  AddMessage('[FHS] WARNING: ' + s);
end;

procedure Err(s: string);
begin
  gErrors := gErrors + 1;
  AddMessage('[FHS] ERROR: ' + s);
end;

//============================================================================
// Поиск ванильных записей
//============================================================================

function IsBaseFile(fileName: string): Boolean;
begin
  Result := SameText(fileName, 'Skyrim.esm') or SameText(fileName, 'Update.esm')
    or SameText(fileName, 'Dawnguard.esm') or SameText(fileName, 'Dragonborn.esm');
end;

// Собственная запись файла по «короткому» FormID (без индекса файла).
// В файле она хранится с индексом, равным числу его мастеров (Skyrim.esm: 00,
// Dawnguard.esm и Dragonborn.esm: 02); RecordByFormID ждёт FormID в порядке
// загрузки. Работает и в SSEEdit 4.1.5, и в более новых версиях.
function RecordInFile(fileName: string; objectId: Integer): IInterface;
var
  f: IInterface;
  loadOrderFormId: Integer;
begin
  Result := nil;
  f := FileByName(fileName);
  if not Assigned(f) then
    Exit;
  loadOrderFormId := FileFormIDtoLoadOrderFormID(f, MasterCount(f) * $1000000 + objectId);
  Result := RecordByFormID(f, loadOrderFormId, True);
end;

// Запись из конкретного мастер-файла; EditorID сверяется, чтобы не промахнуться.
function BaseRec(fileName: string; objectId: Integer; edid: string): IInterface;
begin
  Result := RecordInFile(fileName, objectId);
  if not Assigned(Result) then begin
    Err('not found: ' + edid + ' [' + IntToHex(objectId, 6) + '] in ' + fileName);
    Exit;
  end;
  if not SameText(EditorID(Result), edid) then
    Warn('EditorID mismatch for [' + IntToHex(objectId, 6) + '] in ' + fileName
      + ': expected ' + edid + ', got ' + EditorID(Result));
end;

// Последняя версия записи среди Skyrim/Update/Dawnguard/Dragonborn.
// Правки других плагинов (Creation Club и т. п.) не переносим, чтобы у мода
// остались только четыре базовых мастер-файла.
function BaseWinner(rec: IInterface): IInterface;
var
  m, o: IInterface;
  i: Integer;
  fn: string;
begin
  m := MasterOrSelf(rec);
  Result := m;
  for i := 0 to OverrideCount(m) - 1 do begin
    o := OverrideByIndex(m, i);
    fn := GetFileName(GetFile(o));
    if IsBaseFile(fn) then
      Result := o
    else if not SameText(fn, cPluginName) then
      Warn(EditorID(m) + ' is also changed by ' + fn + '; that change is not carried into ' + cPluginName);
  end;
end;

function HexOf(rec: IInterface): string;
begin
  Result := IntToHex(GetLoadOrderFormID(rec), 8);
end;

// Подзапись ли это с сигнатурой sig. Имя подзаписи в xEdit: "ALFR - Reference".
// Вложенные структуры тоже отвечают на поиск по сигнатуре своего первого поля,
// поэтому сверяем именно имя.
function IsSubrecord(el: IInterface; sig: string): Boolean;
begin
  Result := False;
  if Assigned(el) then
    Result := SameText(Copy(Name(el), 1, Length(sig) + 3), sig + ' - ');
end;

// Поиск подзаписи sig в глубину (не глубже depthLeft уровней).
function FindSub(parent: IInterface; sig: string; depthLeft: Integer): IInterface;
var
  i: Integer;
  c: IInterface;
begin
  Result := nil;
  if not Assigned(parent) then
    Exit;
  for i := 0 to ElementCount(parent) - 1 do begin
    c := ElementByIndex(parent, i);
    if IsSubrecord(c, sig) then begin
      Result := c;
      Exit;
    end;
  end;
  if depthLeft <= 0 then
    Exit;
  for i := 0 to ElementCount(parent) - 1 do begin
    Result := FindSub(ElementByIndex(parent, i), sig, depthLeft - 1);
    if Assigned(Result) then
      Exit;
  end;
end;

// Найти подзапись sig или создать её. Если Add вернул вложенную структуру,
// создаём подзапись уже внутри неё.
function EnsureSub(parent: IInterface; sig: string): IInterface;
begin
  Result := FindSub(parent, sig, 2);
  if Assigned(Result) then
    Exit;
  Result := Add(parent, sig, True);
  if Assigned(Result) and not IsSubrecord(Result, sig) then
    Result := Add(Result, sig, True);
  if not IsSubrecord(Result, sig) then
    Result := FindSub(parent, sig, 2);
end;

//============================================================================
// Создание записей и элементов
//============================================================================

function NewRecord(sig: string; edid: string): IInterface;
var
  g: IInterface;
begin
  g := GroupBySignature(gFile, sig);
  if not Assigned(g) then
    g := Add(gFile, sig, True);
  Result := Add(g, sig, True);
  if not Assigned(Result) then begin
    Err('can not create ' + sig + ' ' + edid);
    Exit;
  end;
  SetEditorID(Result, edid);
end;

// Новый элемент массива, который лежит прямо в записи (Effects, Aliases, Perks).
// Если массива ещё нет, берём элемент, который xEdit создаёт вместе с массивом,
// иначе добавляем в конец.
function NewArrayChild(parent: IInterface; arrayName: string): IInterface;
var
  arr: IInterface;
begin
  arr := ElementByName(parent, arrayName);
  if not Assigned(arr) then begin
    arr := Add(parent, arrayName, True);
    if ElementCount(arr) > 0 then begin
      Result := ElementByIndex(arr, 0);
      Exit;
    end;
  end;
  Result := ElementAssign(arr, HighInteger, nil, False);
end;

// Массив arrayName внутри вложенной структуры parent (запись перка, эффект
// заклинания). Внутри такой структуры SSEEdit 4.1.5 умеет Add только по
// сигнатуре, а массив структур так не создаётся (xEdit падает на Assert).
// Поэтому создаём его через ElementAssign по номеру члена в определении
// записи и сверяем имя того, что получилось. xEdit создаёт массив сразу
// с одним пустым элементом.
function InnerArray(parent: IInterface; arrayName: string; memberIndex: Integer): IInterface;
begin
  Result := ElementByName(parent, arrayName);
  if Assigned(Result) then
    Exit;
  Result := ElementAssign(parent, memberIndex, nil, False);
  if Assigned(Result) then
    if not SameText(Name(Result), arrayName) then begin
      Err('unexpected record layout: member ' + IntToStr(memberIndex) + ' is "' + Name(Result)
        + '", expected "' + arrayName + '"');
      Result := nil;
      Exit;
    end;
  if not Assigned(Result) then
    Err('can not create ' + arrayName + ' in ' + EditorID(ContainingMainRecord(parent)));
end;

// Число с плавающей точкой в подзапись. В SSEEdit 4.1.5 значение подзаписи-
// объединения лежит во вложенном поле (EPFD - Data -> Float), и писать надо
// в него. Записанное значение читается обратно и сверяется.
function WriteFloat(sub: IInterface; value: Double; what: string): Boolean;
var
  el: IInterface;
  v: Variant;
  d: Double;
begin
  Result := False;
  if not Assigned(sub) then begin
    Err(what + ': no element to write to');
    Exit;
  end;
  el := sub;
  if ElementCount(sub) > 0 then
    el := ElementByIndex(sub, 0);
  SetNativeValue(el, value);
  v := GetNativeValue(el);
  if (VarType(v) = 0) or (VarType(v) = 1) then     // varEmpty, varNull
    d := 1000
  else
    d := v - value;
  Result := (d < 0.0005) and (d > -0.0005);
  if not Result then
    Err(what + ': value ' + FloatToStr(value) + ' was not written, got "' + GetEditValue(el) + '"');
end;

// Имя поля, которое в разных версиях xEdit называется по-разному.
function FieldName(parent: IInterface; name1: string; name2: string): string;
begin
  Result := name1;
  if not Assigned(ElementByName(parent, name1)) then
    if Assigned(ElementByName(parent, name2)) then
      Result := name2;
end;

function SetText(rec: IInterface; sig: string; text: string): IInterface;
begin
  Result := ElementBySignature(rec, sig);
  if not Assigned(Result) then
    Result := Add(rec, sig, True);
  SetEditValue(Result, text);
end;

//============================================================================
// Условия (CTDA)
//============================================================================

function OpBits(op: string): Integer;
begin
  Result := 0;
  if op = '==' then Result := 0
  else if op = '!=' then Result := 32
  else if op = '>' then Result := 64
  else if op = '>=' then Result := 96
  else if op = '<' then Result := 128
  else if op = '<=' then Result := 160
  else Err('unknown compare operator ' + op);
end;

// Пустое условие, которое xEdit создаёт вместе с массивом Conditions.
// Функция 0 (GetWantBlocking) нам не нужна, поэтому по ней и отличаем.
function IsEmptyCondition(cond: IInterface): Boolean;
var
  ctda: IInterface;
begin
  ctda := ElementBySignature(cond, 'CTDA');
  if not Assigned(ctda) then begin
    Result := True;
    Exit;
  end;
  Result := (GetElementNativeValues(ctda, 'Function') = 0);
end;

// Добавляет условие в элемент, у которого есть массив Conditions
// (эффект заклинания или вкладка условий перка).
//   func      - имя функции условия ('GetLevel', 'HasKeyword', ...)
//   op, cmpValue - сравнение, например '>=', 30
//   param1    - параметр: FormID в hex или имя актёрского значения, '' если нет
//   onPlayer  - Run On = Reference PlayerRef вместо Subject
//   orNext    - флаг OR (объединить со следующим условием)
procedure Cond(parent: IInterface; func: string; op: string; cmpValue: Integer; param1: string; onPlayer: Boolean; orNext: Boolean);
var
  conds, cond, ctda: IInterface;
  t: Integer;
begin
  // Во вкладке перка массив условий есть всегда, в эффекте заклинания
  // (EFID, EFIT, Conditions) его создаём.
  conds := ElementByName(parent, 'Conditions');
  if not Assigned(conds) then
    conds := InnerArray(parent, 'Conditions', 2);
  if not Assigned(conds) then
    Exit;
  cond := nil;
  if ElementCount(conds) = 1 then
    if IsEmptyCondition(ElementByIndex(conds, 0)) then
      cond := ElementByIndex(conds, 0);
  if not Assigned(cond) then
    cond := ElementAssign(conds, HighInteger, nil, False);
  ctda := ElementBySignature(cond, 'CTDA');
  if not Assigned(ctda) then
    ctda := Add(cond, 'CTDA', True);
  if not Assigned(ctda) then begin
    Err('can not create condition ' + func);
    Exit;
  end;

  SetElementEditValues(ctda, 'Function', func);
  t := OpBits(op);
  if orNext then
    t := t + 1;
  SetElementNativeValues(ctda, 'Type', t);
  SetElementNativeValues(ctda, 'Comparison Value', cmpValue);
  if param1 <> '' then
    SetElementEditValues(ctda, 'Parameter #1', param1);
  if onPlayer then begin
    SetElementEditValues(ctda, 'Run On', 'Reference');
    SetElementEditValues(ctda, 'Reference', cPlayerRef);
  end else
    SetElementEditValues(ctda, 'Run On', 'Subject');
  SetElementNativeValues(ctda, 'Parameter #3', -1);

  // Прочитать обратно: xEdit молча пропускает запись в поле, которого нет.
  if not SameText(GetElementEditValues(ctda, 'Function'), func) then
    Err('condition function not set: ' + func);
  if GetElementNativeValues(ctda, 'Type') <> t then
    Err('condition type not set: ' + func);
  if GetElementNativeValues(ctda, 'Comparison Value') <> cmpValue then
    Err('condition value not set: ' + func);
  if param1 <> '' then
    if GetElementNativeValues(ctda, 'Parameter #1') = 0 then
      Err('condition parameter not set: ' + func + ' ' + param1);
  if onPlayer then
    if GetElementNativeValues(ctda, 'Reference') = 0 then
      Err('condition reference not set: ' + func);
end;

//============================================================================
// Записи перка
//============================================================================

// Новая запись перка (Entry Point, Multiply Value) со значением milli/1000.
function NewEntry(perk: IInterface; ep: string; tabCount: Integer; valueMilli: Integer): IInterface;
var
  e, fp, epft, epfd: IInterface;
begin
  Result := nil;
  e := NewArrayChild(perk, 'Effects');
  if not Assigned(e) then begin
    Err('can not add perk entry to ' + EditorID(perk));
    Exit;
  end;
  if not Assigned(EnsureSub(e, 'PRKE')) then
    Err('can not create PRKE in ' + EditorID(perk));
  // Смена типа на Entry Point пересоздаёт DATA и параметры функции.
  SetElementNativeValues(e, 'PRKE\Type', 2);
  SetElementNativeValues(e, 'PRKE\Rank', 0);
  SetElementNativeValues(e, 'PRKE\Priority', gPriority);
  gPriority := gPriority + 1;

  SetElementEditValues(e, 'DATA\Entry Point\Entry Point', ep);
  SetElementEditValues(e, 'DATA\Entry Point\Function', 'Multiply Value');
  SetElementNativeValues(e, 'DATA\Entry Point\Perk Condition Tab Count', tabCount);

  // Параметры функции xEdit создаёт при смене типа. Если их нет, Add по
  // сигнатуре EPFT создаёт всю структуру Function Parameters.
  fp := ElementByName(e, 'Function Parameters');
  if not Assigned(fp) then begin
    Add(e, 'EPFT', True);
    fp := ElementByName(e, 'Function Parameters');
  end;
  if not Assigned(fp) then begin
    Err('can not create function parameters in ' + EditorID(perk));
    Exit;
  end;
  epft := EnsureSub(fp, 'EPFT');
  SetNativeValue(epft, 1);                              // Float
  if GetNativeValue(epft) <> 1 then
    Err('EPFT not set in ' + EditorID(perk));
  epfd := FindSub(fp, 'EPFD', 0);
  if not Assigned(epfd) then
    epfd := Add(fp, 'EPFD', True);
  WriteFloat(epfd, valueMilli / 1000, EditorID(perk) + ' ' + ep + ' multiplier');

  if not SameText(GetElementEditValues(e, 'DATA\Entry Point\Entry Point'), ep) then
    Err('entry point not set: ' + ep);
  if not SameText(GetElementEditValues(e, 'DATA\Entry Point\Function'), 'Multiply Value') then
    Err('entry point function not set: ' + ep);
  if GetElementNativeValues(e, 'DATA\Entry Point\Perk Condition Tab Count') <> tabCount then
    Err('tab count not set: ' + ep);
  Result := e;
end;

// Вкладка условий perk entry (0 = Perk Owner, дальше зависит от точки входа).
function CondTab(entry: IInterface; tabIndex: Integer): IInterface;
var
  pcs, pc, prkc, conds, unused: IInterface;
  i: Integer;
begin
  Result := nil;
  unused := nil;
  // Perk Conditions — третий член записи перка (PRKE, DATA, Perk Conditions, ...).
  pcs := InnerArray(entry, 'Perk Conditions', 2);
  if not Assigned(pcs) then
    Exit;
  for i := 0 to ElementCount(pcs) - 1 do begin
    pc := ElementByIndex(pcs, i);
    prkc := FindSub(pc, 'PRKC', 0);
    conds := ElementByName(pc, 'Conditions');
    if (ElementCount(conds) = 1) and IsEmptyCondition(ElementByIndex(conds, 0)) then
      unused := pc                  // пустая вкладка, которую xEdit создал вместе с массивом
    else if Assigned(prkc) then
      if GetNativeValue(prkc) = tabIndex then begin
        Result := pc;
        Exit;
      end;
  end;
  pc := unused;
  if not Assigned(pc) then
    pc := ElementAssign(pcs, HighInteger, nil, False);
  prkc := EnsureSub(pc, 'PRKC');
  if not Assigned(prkc) then begin
    Err('can not create PRKC in ' + EditorID(ContainingMainRecord(entry)));
    Exit;
  end;
  SetNativeValue(prkc, tabIndex);
  if GetNativeValue(prkc) <> tabIndex then
    Err('PRKC not set in ' + EditorID(ContainingMainRecord(entry)));
  Result := pc;
end;

// Условие «уровень игрока в ступеньке i» на вкладке Perk Owner.
procedure LevelBand(entry: IInterface; i: Integer);
var
  first: Integer;
begin
  first := DestrBandFirst + i * DestrBandStep;
  if i < DestrBandCount - 1 then begin
    Cond(CondTab(entry, 0), 'GetLevel', '>=', first, '', False, False);
    Cond(CondTab(entry, 0), 'GetLevel', '<', first + DestrBandStep, '', False, False);
  end else
    Cond(CondTab(entry, 0), 'GetLevel', '>=', first, '', False, False);
end;

// Заклинание Разрушения, наносящее урон огнём, морозом, молнией или истощением.
procedure DestructionDamageSpell(pc: IInterface);
begin
  Cond(pc, 'EPMagic_SpellHasSkill', '==', 1, 'Destruction', False, False);
  Cond(pc, 'EPMagic_SpellHasKeyword', '==', 1, HexOf(gKwdFire), False, True);
  Cond(pc, 'EPMagic_SpellHasKeyword', '==', 1, HexOf(gKwdFrost), False, True);
  Cond(pc, 'EPMagic_SpellHasKeyword', '==', 1, HexOf(gKwdShock), False, True);
  Cond(pc, 'EPMagic_SpellHasKeyword', '==', 1, HexOf(gKwdDrain), False, False);
end;

// Входящий урон стихией (для Mod Incoming Spell Magnitude).
procedure ElementalDamageSpell(pc: IInterface);
begin
  Cond(pc, 'EPMagic_SpellHasKeyword', '==', 1, HexOf(gKwdFire), False, True);
  Cond(pc, 'EPMagic_SpellHasKeyword', '==', 1, HexOf(gKwdFrost), False, True);
  Cond(pc, 'EPMagic_SpellHasKeyword', '==', 1, HexOf(gKwdShock), False, True);
  Cond(pc, 'EPMagic_SpellHasKeyword', '==', 1, HexOf(gKwdDrain), False, False);
end;

//============================================================================
// Вкладки условий: сверка с ванильными перками
//============================================================================

// Ищет в ванильном перке запись с нужной точкой входа.
function FindTemplateEntry(perk: IInterface; ep: string): IInterface;
var
  effs, e: IInterface;
  i: Integer;
begin
  Result := nil;
  if not Assigned(perk) then
    Exit;
  effs := ElementByName(perk, 'Effects');
  if not Assigned(effs) then
    Exit;
  for i := 0 to ElementCount(effs) - 1 do begin
    e := ElementByIndex(effs, i);
    if SameText(GetElementEditValues(e, 'DATA\Entry Point\Entry Point'), ep) then begin
      Result := e;
      Exit;
    end;
  end;
end;

// Номер вкладки, на которой в ванильной записи стоит условие func. -1, если нет.
function TabOfFunction(entry: IInterface; func: string): Integer;
var
  pcs, pc, conds: IInterface;
  i, j: Integer;
begin
  Result := -1;
  pcs := ElementByName(entry, 'Perk Conditions');
  if not Assigned(pcs) then
    Exit;
  for i := 0 to ElementCount(pcs) - 1 do begin
    pc := ElementByIndex(pcs, i);
    conds := ElementByName(pc, 'Conditions');
    if Assigned(conds) then
      for j := 0 to ElementCount(conds) - 1 do
        if SameText(GetElementEditValues(ElementByIndex(conds, j), 'CTDA\Function'), func) then begin
          Result := GetElementNativeValues(pc, 'PRKC');
          Exit;
        end;
  end;
end;

function TemplateTabCount(entry: IInterface; ep: string; fallback: Integer): Integer;
begin
  Result := fallback;
  if Assigned(entry) then begin
    Result := GetElementNativeValues(entry, 'DATA\Entry Point\Perk Condition Tab Count');
    if Result <> fallback then
      Warn(ep + ': vanilla tab count is ' + IntToStr(Result) + ', expected ' + IntToStr(fallback) + '; using vanilla value');
  end else
    Warn(ep + ': no vanilla template found, using tab count ' + IntToStr(fallback));
end;

// Строка журнала с устройством ванильной записи перка: вкладки и условия.
// По ней видно, на какой вкладке игра ждёт условия на заклинание.
procedure DumpTemplate(perkName: string; entry: IInterface);
var
  pcs, pc, conds, ctda: IInterface;
  i, j: Integer;
  s, p: string;
begin
  if not Assigned(entry) then
    Exit;
  s := perkName + ' / ' + GetElementEditValues(entry, 'DATA\Entry Point\Entry Point')
    + ': tabs ' + GetElementEditValues(entry, 'DATA\Entry Point\Perk Condition Tab Count');
  pcs := ElementByName(entry, 'Perk Conditions');
  for i := 0 to ElementCount(pcs) - 1 do begin
    pc := ElementByIndex(pcs, i);
    s := s + '; tab ' + GetElementEditValues(pc, 'PRKC') + ':';
    conds := ElementByName(pc, 'Conditions');
    for j := 0 to ElementCount(conds) - 1 do begin
      ctda := ElementBySignature(ElementByIndex(conds, j), 'CTDA');
      s := s + ' ' + GetElementEditValues(ctda, 'Function');
      p := GetElementEditValues(ctda, 'Parameter #1');
      if p <> '' then
        s := s + '(' + p + ')';
      s := s + ' [' + GetElementEditValues(ctda, 'Type') + ' ' + GetElementEditValues(ctda, 'Comparison Value')
        + ' on ' + GetElementEditValues(ctda, 'Run On') + ']';
    end;
  end;
  Info('vanilla ' + s);
end;

// Вкладка, на которой в ванильной записи стоят условия на заклинание.
function SpellTabOf(entry: IInterface): Integer;
begin
  Result := TabOfFunction(entry, 'EPMagic_SpellHasKeyword');
  if Result < 0 then
    Result := TabOfFunction(entry, 'EPMagic_SpellHasSkill');
end;

procedure DetectTabs;
var
  e: IInterface;
  t: Integer;
begin
  // Вкладки условий по Creation Kit (число вкладок записано в каждой записи перка):
  //   Mod Spell Magnitude:          Perk Owner, Spell, Target
  //   Mod Attack Damage:            Perk Owner, Weapon, Target
  //   Mod Incoming Damage:          Perk Owner, Attacker, Attacker Weapon
  //   Mod Incoming Spell Magnitude: Perk Owner, Spell
  // Номера вкладок сверяются с ванильными перками ниже.
  gSpellTabSpellMag := 1;
  gWeaponTabAttack := 1;
  gSpellTabIncomingSpell := 1;

  // AugmentedFlames: Mod Spell Magnitude с условиями по ключевым словам заклинания
  e := FindTemplateEntry(BaseRec('Skyrim.esm', $0581E7, 'AugmentedFlames'), cEPSpellMag);
  DumpTemplate('AugmentedFlames', e);
  gTabsSpellMag := TemplateTabCount(e, cEPSpellMag, 3);
  t := SpellTabOf(e);
  if (t >= 0) and (t <> gSpellTabSpellMag) then begin
    Warn(cEPSpellMag + ': spell conditions are on tab ' + IntToStr(t) + ' in vanilla; using it');
    gSpellTabSpellMag := t;
  end;

  // Armsman00: Mod Attack Damage
  e := FindTemplateEntry(BaseRec('Skyrim.esm', $0BABE4, 'Armsman00'), cEPAttack);
  DumpTemplate('Armsman00', e);
  gTabsAttack := TemplateTabCount(e, cEPAttack, 3);

  // crDragonResistNPCs или DragonhideSpellPerk: Mod Incoming Damage
  e := FindTemplateEntry(BaseRec('Skyrim.esm', $1046BD, 'crDragonResistNPCs'), cEPIncoming);
  if not Assigned(e) then
    e := FindTemplateEntry(BaseRec('Skyrim.esm', $109639, 'DragonhideSpellPerk'), cEPIncoming);
  DumpTemplate('Mod Incoming Damage template', e);
  gTabsIncoming := TemplateTabCount(e, cEPIncoming, 3);

  // ElementalProtection (Блок): Mod Incoming Spell Magnitude
  e := FindTemplateEntry(BaseRec('Skyrim.esm', $058F69, 'ElementalProtection'), cEPIncomingSpell);
  DumpTemplate('ElementalProtection', e);
  gTabsIncomingSpell := TemplateTabCount(e, cEPIncomingSpell, 2);
  t := SpellTabOf(e);
  if (t >= 0) and (t <> gSpellTabIncomingSpell) then begin
    Warn(cEPIncomingSpell + ': spell conditions are on tab ' + IntToStr(t) + ' in vanilla; using it');
    gSpellTabIncomingSpell := t;
  end;
  if gSpellTabIncomingSpell >= gTabsIncomingSpell then begin
    Warn(cEPIncomingSpell + ': no Spell tab, incoming spell reduction applies to all spells');
    gSpellTabIncomingSpell := -1;
  end;

  Info('condition tabs: SpellMag=' + IntToStr(gTabsSpellMag) + '/spell ' + IntToStr(gSpellTabSpellMag)
    + ', Attack=' + IntToStr(gTabsAttack) + '/weapon ' + IntToStr(gWeaponTabAttack)
    + ', Incoming=' + IntToStr(gTabsIncoming)
    + ', IncomingSpell=' + IntToStr(gTabsIncomingSpell) + '/spell ' + IntToStr(gSpellTabIncomingSpell));
end;

//============================================================================
// Модули
//============================================================================

procedure LoadVanilla;
begin
  gKwdFire := BaseRec('Skyrim.esm', $01CEAD, 'MagicDamageFire');
  gKwdFrost := BaseRec('Skyrim.esm', $01CEAE, 'MagicDamageFrost');
  gKwdShock := BaseRec('Skyrim.esm', $01CEAF, 'MagicDamageShock');
  gKwdDrain := BaseRec('Skyrim.esm', $101BDE, 'MagicVampireDrain');
  gPerkDestrMaster := BaseRec('Skyrim.esm', $0C44C2, 'DestructionMaster100');
  gPerkConjMaster := BaseRec('Skyrim.esm', $0C44BE, 'ConjurationMaster100');
end;

procedure AddToList(list: IInterface; fileName: string; objectId: Integer; edid: string);
var
  rec, el: IInterface;
begin
  rec := BaseRec(fileName, objectId, edid);
  if not Assigned(rec) then
    Exit;
  el := NewArrayChild(list, 'FormIDs');
  SetEditValue(el, HexOf(rec));
end;

procedure BuildKeywordAndList;
begin
  gKwdEndgame := NewRecord('KYWD', 'FHS_SummonEndgame');

  gBoundList := NewRecord('FLST', 'FHS_BoundWeapons');
  AddToList(gBoundList, 'Skyrim.esm', $058F5F, 'BoundWeaponSword');
  AddToList(gBoundList, 'Skyrim.esm', $0424F9, 'BoundWeaponSwordMystic');
  AddToList(gBoundList, 'Skyrim.esm', $0BA30E, 'BoundWeaponSwordRightHand');
  AddToList(gBoundList, 'Skyrim.esm', $058F5E, 'BoundWeaponBattleaxe');
  AddToList(gBoundList, 'Skyrim.esm', $0424F7, 'BoundWeaponBattleaxeMystic');
  AddToList(gBoundList, 'Skyrim.esm', $058F60, 'BoundWeaponBow');
  AddToList(gBoundList, 'Skyrim.esm', $0424F8, 'BoundWeaponBowMystic');
  AddToList(gBoundList, 'Dragonborn.esm', $01CE02, 'DLC2BoundWeaponDagger');
  AddToList(gBoundList, 'Dragonborn.esm', $01CE03, 'DLC2BoundWeaponDaggerMystic');
end;

function NewPerk(edid: string; fullName: string; desc: string): IInterface;
begin
  Result := NewRecord('PERK', edid);
  SetText(Result, 'FULL', fullName);
  SetText(Result, 'DESC', desc);
  SetElementNativeValues(Result, 'DATA\Trait', 0);
  SetElementNativeValues(Result, 'DATA\Level', 0);
  SetElementNativeValues(Result, 'DATA\Num Ranks', 1);
  SetElementNativeValues(Result, 'DATA\Playable', 0);
  SetElementNativeValues(Result, 'DATA\Hidden', 1);
end;

// Скрытый перк игрока: модули D1, D2, C3, C4.
procedure BuildPlayerPerk;
var
  i: Integer;
  e: IInterface;
begin
  gPriority := 0;
  gPlayerPerk := NewPerk('FHS_Attunement', 'FHS Magic Resonance',
    'Destruction damage, Conjuration level limits and bound weapons scale with character level.');

  // D1. Резонанс Разрушения
  for i := 0 to DestrBandCount - 1 do begin
    e := NewEntry(gPlayerPerk, cEPSpellMag, gTabsSpellMag, DestrMilli(i));
    LevelBand(e, i);
    DestructionDamageSpell(CondTab(e, gSpellTabSpellMag));
  end;

  // D2. Абсолютное Разрушение: мастер школы и навык 100
  e := NewEntry(gPlayerPerk, cEPSpellMag, gTabsSpellMag, AbsoluteMilli);
  Cond(CondTab(e, 0), 'HasPerk', '==', 1, HexOf(gPerkDestrMaster), False, False);
  Cond(CondTab(e, 0), 'GetBaseActorValue', '>=', 100, 'Destruction', False, False);
  DestructionDamageSpell(CondTab(e, gSpellTabSpellMag));

  // C3. Пороги уровня Колдовства (воскрешение, изгнание, подчинение)
  for i := 0 to DestrBandCount - 1 do begin
    e := NewEntry(gPlayerPerk, cEPSpellMag, gTabsSpellMag, DestrMilli(i));
    LevelBand(e, i);
    Cond(CondTab(e, gSpellTabSpellMag), 'EPMagic_SpellHasSkill', '==', 1, 'Conjuration', False, False);
  end;

  // C4. Призванное оружие
  for i := 0 to DestrBandCount - 1 do begin
    e := NewEntry(gPlayerPerk, cEPAttack, gTabsAttack, BoundMilli(i));
    LevelBand(e, i);
    Cond(CondTab(e, gWeaponTabAttack), 'IsInList', '==', 1, HexOf(gBoundList), False, False);
  end;

  Info('player perk: ' + IntToStr(gPriority) + ' entries');
end;

// Условия рубежа i на вкладке Perk Owner перка призыва.
procedure MilestoneConditions(entry: IInterface; i: Integer);
var
  p: Integer;
  pc: IInterface;
begin
  p := SummonMilestoneFirst + i * SummonMilestoneStep;
  pc := CondTab(entry, 0);
  Cond(pc, 'GetLevel', '>=', p, '', True, False);                        // уровень игрока
  Cond(pc, 'GetLevel', '<', p, '', False, False);                         // призыв ниже рубежа
  Cond(pc, 'GetLevel', '>=', SummonMinLevel(i), '', False, True);         // потолок 2x ...
  Cond(pc, 'HasKeyword', '==', 1, HexOf(gKwdEndgame), False, False);        // ... или эндгейм
  Cond(pc, 'IsCommandedActor', '==', 1, '', False, False);
  Cond(pc, 'IsHostileToActor', '==', 0, cPlayerRef, False, False);
end;

procedure AbsoluteConjurationConditions(entry: IInterface);
var
  pc: IInterface;
begin
  pc := CondTab(entry, 0);
  Cond(pc, 'HasPerk', '==', 1, HexOf(gPerkConjMaster), True, False);
  Cond(pc, 'GetBaseActorValue', '>=', 100, 'Conjuration', True, False);
  Cond(pc, 'IsCommandedActor', '==', 1, '', False, False);
  Cond(pc, 'IsHostileToActor', '==', 0, cPlayerRef, False, False);
end;

// Перк призванных существ: модули C1, C2.
procedure BuildSummonPerk;
var
  i: Integer;
  e: IInterface;
begin
  gPriority := 0;
  gSummonPerk := NewPerk('FHS_SummonAttunement', 'FHS Summon Resonance',
    'Summoned creatures grow with the summoner.');

  for i := 0 to SummonMilestoneCount - 1 do begin
    e := NewEntry(gSummonPerk, cEPAttack, gTabsAttack, SummonStepMilli(i));
    MilestoneConditions(e, i);
    e := NewEntry(gSummonPerk, cEPSpellMag, gTabsSpellMag, SummonStepMilli(i));
    MilestoneConditions(e, i);
    e := NewEntry(gSummonPerk, cEPIncoming, gTabsIncoming, SummonStepInvMilli(i));
    MilestoneConditions(e, i);
    e := NewEntry(gSummonPerk, cEPIncomingSpell, gTabsIncomingSpell, SummonStepInvMilli(i));
    MilestoneConditions(e, i);
    if gSpellTabIncomingSpell >= 0 then
      ElementalDamageSpell(CondTab(e, gSpellTabIncomingSpell));
  end;

  // C2. Абсолютное Колдовство
  e := NewEntry(gSummonPerk, cEPAttack, gTabsAttack, AbsoluteMilli);
  AbsoluteConjurationConditions(e);
  e := NewEntry(gSummonPerk, cEPSpellMag, gTabsSpellMag, AbsoluteMilli);
  AbsoluteConjurationConditions(e);
  e := NewEntry(gSummonPerk, cEPIncoming, gTabsIncoming, AbsoluteInvMilli);
  AbsoluteConjurationConditions(e);
  e := NewEntry(gSummonPerk, cEPIncomingSpell, gTabsIncomingSpell, AbsoluteInvMilli);
  AbsoluteConjurationConditions(e);
  if gSpellTabIncomingSpell >= 0 then
    ElementalDamageSpell(CondTab(e, gSpellTabIncomingSpell));

  Info('summon perk: ' + IntToStr(gPriority) + ' entries');
end;

// Подзапись DATA магического эффекта. В SSEEdit 4.1.5 она лежит внутри
// структуры "Magic Effect Data", поэтому путь 'DATA\Flags' от записи
// не работает. Add по сигнатуре DATA создаёт эту структуру вместе с DATA.
function MgefData(mgef: IInterface): IInterface;
begin
  Result := FindSub(mgef, 'DATA', 1);
  if Assigned(Result) then
    Exit;
  Add(mgef, 'DATA', True);
  Result := FindSub(mgef, 'DATA', 1);
  if not Assigned(Result) then
    Err('can not create DATA in ' + EditorID(mgef));
end;

// Поле архетипа: в SSEEdit 4.1.5 оно называется "Archtype".
function ArchetypeField(data: IInterface): string;
begin
  Result := FieldName(data, 'Archtype', 'Archetype');
end;

procedure SetDataInt(data: IInterface; field: string; value: Integer);
begin
  SetElementNativeValues(data, field, value);
  if GetElementNativeValues(data, field) <> value then
    Err(EditorID(ContainingMainRecord(data)) + ': ' + field + ' not set');
end;

// Магический эффект для способности (Constant Effect, Self).
function NewEffect(edid: string; fullName: string; desc: string; archetype: Integer; actorValue: Integer; flags: Integer): IInterface;
var
  data: IInterface;
begin
  Result := NewRecord('MGEF', edid);
  SetText(Result, 'FULL', fullName);
  if desc <> '' then
    SetText(Result, 'DNAM', desc);
  data := MgefData(Result);
  if not Assigned(data) then
    Exit;
  // Архетип первым: при его смене xEdit сбрасывает Actor Value и связанные поля.
  SetDataInt(data, ArchetypeField(data), archetype);
  SetDataInt(data, 'Actor Value', actorValue);
  SetDataInt(data, 'Flags', flags);
  SetDataInt(data, 'Magic Skill', -1);
  SetDataInt(data, 'Resist Value', -1);
  SetDataInt(data, 'Casting Type', 0);         // Constant Effect
  SetDataInt(data, 'Delivery', 0);             // Self
  SetDataInt(data, 'Second Actor Value', -1);
  SetElementNativeValues(data, 'Base Cost', 0);
  SetElementNativeValues(data, 'Skill Usage Multiplier', 0);
end;

procedure BuildEffects;
var
  el: IInterface;
begin
  // Носитель перка: Value Modifier на Health с магнитудой 0 ничего не меняет,
  // а поле Perk to Apply выдаёт игроку скрытый перк, пока действует эффект.
  gCarrier := NewEffect('FHS_AttunementCarrier', 'FHS Attunement', '',
    0, cAVHealth, cFlagHideInUI + cFlagNoMagnitude + cFlagNoArea + cFlagNoDuration);
  el := MgefData(gCarrier);
  SetElementEditValues(el, 'Perk to Apply', HexOf(gPlayerPerk));
  if not SameText(EditorID(LinksTo(ElementByName(el, 'Perk to Apply'))), EditorID(gPlayerPerk)) then
    Err(EditorID(gCarrier) + ': Perk to Apply not set');

  // Строки в «Активных эффектах». Архетип Script без скрипта ничего не делает.
  gDisplayResonance := NewEffect('FHS_DisplayResonance', 'Magic Resonance',
    'Destruction damage and Conjuration level limits are increased by <mag>%.',
    1, -1, cFlagNoArea + cFlagNoDuration);
  gDisplayAbsDestr := NewEffect('FHS_DisplayAbsoluteDestruction', 'Absolute Destruction',
    'Destruction spells deal <mag>% more damage.',
    1, -1, cFlagNoArea + cFlagNoDuration);
  gDisplayAbsConj := NewEffect('FHS_DisplayAbsoluteConjuration', 'Absolute Conjuration',
    'Your summoned creatures deal <mag>% more damage and take less damage.',
    1, -1, cFlagNoArea + cFlagNoDuration);
end;

// Эффект внутри заклинания. Первый эффект берём тот, что xEdit создал вместе с записью.
function EffectIsEmpty(eff: IInterface): Boolean;
var
  efid: IInterface;
begin
  efid := FindSub(eff, 'EFID', 0);
  if Assigned(efid) then
    Result := (GetNativeValue(efid) = 0)
  else
    Result := True;
end;

function AddSpellEffect(spell: IInterface; mgef: IInterface; magnitude: Integer): IInterface;
var
  effs, el: IInterface;
begin
  effs := ElementByName(spell, 'Effects');
  Result := nil;
  if Assigned(effs) and (ElementCount(effs) = 1) then
    if EffectIsEmpty(ElementByIndex(effs, 0)) then
      Result := ElementByIndex(effs, 0);
  if not Assigned(Result) then
    Result := NewArrayChild(spell, 'Effects');
  el := EnsureSub(Result, 'EFID');
  SetEditValue(el, HexOf(mgef));
  el := EnsureSub(Result, 'EFIT');
  SetElementNativeValues(el, 'Magnitude', magnitude);
  SetElementNativeValues(el, 'Area', 0);
  SetElementNativeValues(el, 'Duration', 0);
  if not SameText(EditorID(LinksTo(FindSub(Result, 'EFID', 0))), EditorID(mgef)) then
    Err('spell effect not set: ' + EditorID(mgef));
end;

procedure BuildAbility;
var
  i, first: Integer;
  eff, spit: IInterface;
begin
  gAbility := NewRecord('SPEL', 'FHS_AttunementAbility');
  SetText(gAbility, 'FULL', 'Magic Resonance');
  SetText(gAbility, 'DESC', '');
  spit := EnsureSub(gAbility, 'SPIT');
  SetElementNativeValues(spit, 'Base Cost', 0);
  SetDataInt(spit, 'Flags', 1);                              // Manual Cost Calc
  SetElementEditValues(spit, 'Type', 'Ability');
  SetElementNativeValues(spit, 'Charge Time', 0);
  SetDataInt(spit, 'Cast Type', 0);                          // Constant Effect
  SetDataInt(spit, FieldName(spit, 'Target Type', 'Delivery'), 0);   // Self
  SetElementNativeValues(spit, 'Cast Duration', 0);
  SetElementNativeValues(spit, 'Range', 0);
  if not SameText(GetElementEditValues(spit, 'Type'), 'Ability') then
    Err(EditorID(gAbility) + ': spell type is not Ability');

  AddSpellEffect(gAbility, gCarrier, 0);

  // D3. Одна видимая строка на ступеньку уровня
  for i := 0 to DestrBandCount - 1 do begin
    eff := AddSpellEffect(gAbility, gDisplayResonance, DestrPercent(i));
    first := DestrBandFirst + i * DestrBandStep;
    Cond(eff, 'GetLevel', '>=', first, '', False, False);
    if i < DestrBandCount - 1 then
      Cond(eff, 'GetLevel', '<', first + DestrBandStep, '', False, False);
  end;

  eff := AddSpellEffect(gAbility, gDisplayAbsDestr, (AbsoluteMilli - 1000) div 10);
  Cond(eff, 'HasPerk', '==', 1, HexOf(gPerkDestrMaster), False, False);
  Cond(eff, 'GetBaseActorValue', '>=', 100, 'Destruction', False, False);

  eff := AddSpellEffect(gAbility, gDisplayAbsConj, (AbsoluteMilli - 1000) div 10);
  Cond(eff, 'HasPerk', '==', 1, HexOf(gPerkConjMaster), False, False);
  Cond(eff, 'GetBaseActorValue', '>=', 100, 'Conjuration', False, False);
end;

// Квест с алиасом игрока, который раздаёт способность без скриптов.
procedure BuildQuest;
var
  alias, alfr, spells, el: IInterface;
begin
  gQuest := NewRecord('QUST', 'FHS_CoreQuest');
  SetText(gQuest, 'FULL', 'FHS Magic Scaling');
  SetElementNativeValues(gQuest, 'DNAM\Flags', 1);      // Start Game Enabled
  SetElementNativeValues(gQuest, 'DNAM\Priority', 50);
  if GetElementNativeValues(gQuest, 'DNAM\Flags') <> 1 then
    Err('quest is not Start Game Enabled');

  // Алиас ссылки (Reference Alias). xEdit создаёт его вместе с массивом
  // сразу с ALST, ALID, FNAM (флаги 0) и ALED.
  alias := NewArrayChild(gQuest, 'Aliases');
  if not Assigned(alias) then begin
    Err('can not create quest alias');
    Exit;
  end;
  SetElementNativeValues(alias, 'ALST', 0);
  SetElementEditValues(alias, 'ALID', 'Player');
  alfr := EnsureSub(alias, 'ALFR');
  if not Assigned(alfr) then begin
    Err('can not create ALFR (alias reference)');
    Exit;
  end;
  SetEditValue(alfr, cPlayerRef);

  // Alias Spells внутри алиаса создаётся через Add по сигнатуре ALSP:
  // xEdit создаёт массив с одним пустым элементом и возвращает массив.
  spells := ElementByName(alias, 'Alias Spells');
  if not Assigned(spells) then begin
    Add(alias, 'ALSP', True);
    spells := ElementByName(alias, 'Alias Spells');
  end;
  el := nil;
  if ElementCount(spells) = 1 then
    if GetNativeValue(ElementByIndex(spells, 0)) = 0 then
      el := ElementByIndex(spells, 0);
  if not Assigned(el) then
    el := ElementAssign(spells, HighInteger, nil, False);
  SetEditValue(el, HexOf(gAbility));

  SetElementNativeValues(gQuest, 'ANAM', 1);

  if GetElementNativeValues(alias, 'ALST') <> 0 then
    Err('quest alias id not set');
  if not SameText(GetElementEditValues(alias, 'ALID'), 'Player') then
    Err('quest alias name not set');
  if Pos('00000014', GetEditValue(alfr)) = 0 then
    Err('quest alias is not filled with PlayerRef: ' + GetEditValue(alfr));
  if not SameText(EditorID(LinksTo(el)), EditorID(gAbility)) then
    Err('quest alias does not give ' + EditorID(gAbility));
  if GetElementNativeValues(gQuest, 'ANAM') <> 1 then
    Err('quest next alias id not set');
end;

//============================================================================
// C1. Записи призываемых NPC
//============================================================================

function HasTemplateFlag(npc: IInterface; bit: Integer): Boolean;
var
  flags: Integer;
begin
  flags := GetElementNativeValues(npc, 'ACBS\Template Flags');
  Result := ((flags div bit) mod 2) = 1;
end;

// Если NPC берёт данные (bit) из шаблона-NPC, возвращает этот шаблон, иначе сам NPC.
function DataSource(npc: IInterface; bit: Integer): IInterface;
var
  tpl: IInterface;
  depth: Integer;
begin
  Result := npc;
  depth := 0;
  while HasTemplateFlag(Result, bit) and (depth < 5) do begin
    tpl := LinksTo(ElementBySignature(Result, 'TPLT'));
    if not Assigned(tpl) then
      Exit;
    if Signature(tpl) <> 'NPC_' then begin
      Warn(EditorID(npc) + ' takes data from leveled list ' + EditorID(tpl) + '; patching the NPC itself');
      Exit;
    end;
    Result := tpl;
    depth := depth + 1;
  end;
end;

// Правка записи в нашем плагине: уже созданная или новая копия последней
// версии из базовых мастер-файлов.
function OverrideInFile(rec: IInterface): IInterface;
var
  m, src: IInterface;
  i: Integer;
begin
  m := MasterOrSelf(rec);
  for i := 0 to OverrideCount(m) - 1 do
    if SameText(GetFileName(GetFile(OverrideByIndex(m, i))), cPluginName) then begin
      Result := OverrideByIndex(m, i);
      Exit;
    end;
  src := BaseWinner(rec);
  AddRequiredElementMasters(src, gFile, False, True);
  Result := wbCopyElementToFile(src, gFile, False, True);
  if not Assigned(Result) then
    Err('can not copy ' + EditorID(rec) + ' as override');
end;

// Счётчик (PRKZ, KSIZ) перед массивом в записи NPC.
procedure SetCounter(npc: IInterface; sig: string; count: Integer);
var
  el: IInterface;
begin
  el := FindSub(npc, sig, 0);
  if not Assigned(el) then
    el := Add(npc, sig, True);
  if not Assigned(el) then begin
    Err(EditorID(npc) + ': can not create ' + sig);
    Exit;
  end;
  SetNativeValue(el, count);
  if GetNativeValue(el) <> count then
    Err(EditorID(npc) + ': ' + sig + ' not set');
end;

function HasPerkEntry(npc: IInterface; perk: IInterface): Boolean;
var
  perks: IInterface;
  i: Integer;
begin
  Result := False;
  perks := ElementByName(npc, 'Perks');
  if not Assigned(perks) then
    Exit;
  for i := 0 to ElementCount(perks) - 1 do
    if SameText(EditorID(LinksTo(ElementByName(ElementByIndex(perks, i), 'Perk'))), EditorID(perk)) then begin
      Result := True;
      Exit;
    end;
end;

procedure AddPerkToNpc(npc: IInterface);
var
  perks, el: IInterface;
begin
  if HasPerkEntry(npc, gSummonPerk) then
    Exit;
  perks := ElementByName(npc, 'Perks');
  el := nil;
  if Assigned(perks) and (ElementCount(perks) = 1) then
    if GetElementNativeValues(ElementByIndex(perks, 0), 'Perk') = 0 then
      el := ElementByIndex(perks, 0);
  if not Assigned(el) then
    el := NewArrayChild(npc, 'Perks');
  SetElementEditValues(el, 'Perk', HexOf(gSummonPerk));
  SetElementNativeValues(el, 'Rank', 0);
  if not HasPerkEntry(npc, gSummonPerk) then
    Err(EditorID(npc) + ': perk not added');
  // Игра читает перки NPC по счётчику PRKZ, поэтому он должен быть и совпадать
  // с числом записей. Add возвращает существующий PRKZ или создаёт его.
  SetCounter(npc, 'PRKZ', ElementCount(ElementByName(npc, 'Perks')));
end;

procedure AddKeywordToNpc(npc: IInterface; kwd: IInterface);
var
  kwda, k: IInterface;
  i: Integer;
begin
  kwda := FindSub(npc, 'KWDA', 1);
  if not Assigned(kwda) then begin
    k := ElementByName(npc, 'Keywords');
    if not Assigned(k) then
      k := Add(npc, 'Keywords', True);
    if IsSubrecord(k, 'KWDA') then
      kwda := k
    else if Assigned(k) then
      kwda := EnsureSub(k, 'KWDA');
  end;
  if not Assigned(kwda) then begin
    Err('can not add keywords to ' + EditorID(npc));
    Exit;
  end;
  for i := 0 to ElementCount(kwda) - 1 do
    if SameText(EditorID(LinksTo(ElementByIndex(kwda, i))), EditorID(kwd)) then
      Exit;
  if (ElementCount(kwda) = 1) and (GetNativeValue(ElementByIndex(kwda, 0)) = 0) then
    k := ElementByIndex(kwda, 0)
  else
    k := ElementAssign(kwda, HighInteger, nil, False);
  SetEditValue(k, HexOf(kwd));
  if not SameText(EditorID(LinksTo(k)), EditorID(kwd)) then
    Err(EditorID(npc) + ': keyword not added');
  SetCounter(npc, 'KSIZ', ElementCount(kwda));
end;

procedure PatchSummon(fileName: string; objectId: Integer; edid: string; endgame: Boolean);
var
  npc, perkSrc, kwdSrc, o: IInterface;
begin
  npc := BaseRec(fileName, objectId, edid);
  if not Assigned(npc) then begin
    gNpcSkipped := gNpcSkipped + 1;
    Exit;
  end;
  npc := BaseWinner(npc);

  perkSrc := DataSource(npc, 8);        // Template Flags: Spell List (бит 3)
  o := OverrideInFile(perkSrc);
  if not Assigned(o) then begin
    gNpcSkipped := gNpcSkipped + 1;
    Exit;
  end;
  AddPerkToNpc(o);
  if not SameText(EditorID(perkSrc), EditorID(npc)) then
    Info(edid + ': perk goes to template ' + EditorID(perkSrc));

  if endgame then begin
    kwdSrc := DataSource(npc, 4096);    // Template Flags: Keywords (бит 12)
    o := OverrideInFile(kwdSrc);
    if Assigned(o) then
      AddKeywordToNpc(o, gKwdEndgame);
    if not SameText(EditorID(kwdSrc), EditorID(npc)) then
      Info(edid + ': keyword goes to template ' + EditorID(kwdSrc));
  end;

  Info('summon patched: ' + edid + ' (level ' + GetElementEditValues(npc, 'ACBS\Level') + ')');
  gNpcPatched := gNpcPatched + 1;
end;

procedure PatchSummons;
begin
  PatchSummon('Skyrim.esm', $0640B5, 'EncSummonFamiliar', False);
  PatchSummon('Skyrim.esm', $0204C0, 'SummonAtronachFlame', False);
  PatchSummon('Skyrim.esm', $04E940, 'SummonAtronachFlamePotent', False);
  PatchSummon('Skyrim.esm', $0204C1, 'SummonAtronachFrost', False);
  PatchSummon('Skyrim.esm', $04E943, 'SummonAtronachFrostPotent', False);
  PatchSummon('Skyrim.esm', $0204C2, 'SummonAtronachStorm', False);
  PatchSummon('Skyrim.esm', $04E944, 'SummonAtronachStormPotent', False);
  PatchSummon('Skyrim.esm', $07E87D, 'SummonAtronachFlameThrall', True);
  PatchSummon('Skyrim.esm', $0CDECC, 'SummonAtronachFlameThrallPotent', True);
  PatchSummon('Skyrim.esm', $07E87E, 'SummonAtronachFrostThrall', True);
  PatchSummon('Skyrim.esm', $0CDECD, 'SummonAtronachFrostThrallPotent', True);
  PatchSummon('Skyrim.esm', $07E87F, 'SummonAtronachStormThrall', True);
  PatchSummon('Skyrim.esm', $0CDECE, 'SummonAtronachStormThrallPotent', True);
  PatchSummon('Skyrim.esm', $10DDEE, 'SummonEncDremoraLord', True);
  PatchSummon('Dawnguard.esm', $0045B9, 'DLC1SoulCairnBonemanSummon', False);
  PatchSummon('Dawnguard.esm', $0045B7, 'DLC1SoulCairnMistmanSummon', False);
  PatchSummon('Dawnguard.esm', $0045B4, 'DLC1SoulCairnWrathmanSummon', False);
  PatchSummon('Dawnguard.esm', $016907, 'DLC1EncGargoyleSummon', False);
  PatchSummon('Dragonborn.esm', $01EEC9, 'DLC2SummonSeeker', False);
  PatchSummon('Dragonborn.esm', $030CDE, 'DLC2SummonSeekerHigh', False);
  PatchSummon('Dragonborn.esm', $01CDF8, 'DLC2SummonAshSpawn01', False);
  PatchSummon('Dragonborn.esm', $0177B6, 'DLC2SummonAshGuardian', False);
end;

// Сверка: какие существа на самом деле призывают заклинания игрока.
// Всё, чего нет в списке PatchSummons, попадёт в журнал как WARNING.
procedure CheckSpell(fileName: string; objectId: Integer; edid: string);
var
  spell, effs, mgef, data, npc: IInterface;
  i, found: Integer;
begin
  spell := BaseRec(fileName, objectId, edid);
  if not Assigned(spell) then
    Exit;
  spell := BaseWinner(spell);
  found := 0;
  effs := ElementByName(spell, 'Effects');
  for i := 0 to ElementCount(effs) - 1 do begin
    mgef := LinksTo(ElementBySignature(ElementByIndex(effs, i), 'EFID'));
    if not Assigned(mgef) then
      Continue;
    data := FindSub(BaseWinner(mgef), 'DATA', 1);
    if not SameText(GetElementEditValues(data, ArchetypeField(data)), 'Summon Creature') then
      Continue;
    npc := LinksTo(ElementByName(data, 'Assoc. Item'));
    if not Assigned(npc) then
      Continue;
    found := found + 1;
    if not HasPerkEntry(WinningOverride(DataSource(npc, 8)), gSummonPerk) then
      Warn(edid + ' summons ' + EditorID(npc) + ', which is not patched');
  end;
  if found = 0 then
    Warn(edid + ': no Summon Creature effect found, can not check it');
end;

procedure CheckSummonSpells;
begin
  CheckSpell('Skyrim.esm', $0640B6, 'ConjureFamiliar');
  CheckSpell('Skyrim.esm', $0204C3, 'ConjureFlameAtronach');
  CheckSpell('Skyrim.esm', $0204C4, 'ConjureFrostAtronach');
  CheckSpell('Skyrim.esm', $0204C5, 'ConjureStormAtronach');
  CheckSpell('Skyrim.esm', $10DDEC, 'ConjureDremoraLord');
  CheckSpell('Skyrim.esm', $07E5D5, 'FlameThrall');
  CheckSpell('Skyrim.esm', $07E5D6, 'FrostThrall');
  CheckSpell('Skyrim.esm', $07E5D7, 'StormThrall');
  CheckSpell('Dawnguard.esm', $0045BA, 'DLC1ConjureBoneman');
  CheckSpell('Dawnguard.esm', $0045B8, 'DLC1ConjureMistman');
  CheckSpell('Dawnguard.esm', $0045B3, 'DLC1ConjureWrathman');
  CheckSpell('Dragonborn.esm', $033C66, 'DLC2ConjureSeeker');
  CheckSpell('Dragonborn.esm', $01CDF6, 'DLC2ConjureAshSpawn');
end;

//============================================================================
// Точка входа
//============================================================================

function Initialize: Integer;
var
  i: Integer;
begin
  Result := 0;
  gErrors := 0;
  gWarnings := 0;
  gNpcPatched := 0;
  gNpcSkipped := 0;

  Info('FHS Magic Scaling generator');
  if not Assigned(FileByName('Skyrim.esm')) or not Assigned(FileByName('Update.esm'))
    or not Assigned(FileByName('Dawnguard.esm')) or not Assigned(FileByName('Dragonborn.esm')) then begin
    Err('load Skyrim.esm, Update.esm, Dawnguard.esm and Dragonborn.esm before running this script');
    Result := 1;
    Exit;
  end;
  if Assigned(FileByName(cPluginName)) then begin
    Err(cPluginName + ' is already loaded. Close SSEEdit, delete or rename the old file in Data and run again.');
    Result := 1;
    Exit;
  end;

  gFile := AddNewFileName(cPluginName, False);
  if not Assigned(gFile) then begin
    Err('can not create ' + cPluginName + ' (does the file already exist in Data?)');
    Result := 1;
    Exit;
  end;
  AddMasterIfMissing(gFile, 'Skyrim.esm');
  AddMasterIfMissing(gFile, 'Update.esm');
  AddMasterIfMissing(gFile, 'Dawnguard.esm');
  AddMasterIfMissing(gFile, 'Dragonborn.esm');

  LoadVanilla;
  if gErrors > 0 then begin
    Err('vanilla records are missing, stopping');
    Result := 1;
    Exit;
  end;

  DetectTabs;
  BuildKeywordAndList;
  BuildPlayerPerk;
  BuildSummonPerk;
  BuildEffects;
  BuildAbility;
  BuildQuest;
  PatchSummons;
  CheckSummonSpells;
  SortMasters(gFile);

  Info('summons patched: ' + IntToStr(gNpcPatched) + ', skipped: ' + IntToStr(gNpcSkipped));
  Info('masters: ' + IntToStr(MasterCount(gFile)) + ', records: ' + IntToStr(RecordCount(gFile)));
  for i := 0 to MasterCount(gFile) - 1 do
    Info('  master ' + GetFileName(MasterByIndex(gFile, i)));
  Info('errors: ' + IntToStr(gErrors) + ', warnings: ' + IntToStr(gWarnings));
  if gErrors = 0 then
    Info('DONE. Close SSEEdit and save ' + cPluginName + '.')
  else
    Info('DONE WITH ERRORS. Do not save; send the whole log.');
end;

end.
