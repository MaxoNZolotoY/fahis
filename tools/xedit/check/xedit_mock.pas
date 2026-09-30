{ Модель скриптового API SSEEdit 4.1.5f для прогона генератора без игры.

  Записи строятся по упрощённым определениям, повторяющим
  wbDefinitionsTES5.pas из xEdit 4.1.5f для тех записей, которые трогает
  генератор (PERK, MGEF, SPEL, QUST, FLST, KYWD, NPC_). Поведение API взято
  из wbImplementation.pas и xejviScriptAdapter.pas той же версии:

  - Add у записи ищет член по имени или по сигнатуре по умолчанию;
    у вложенной структуры (RStruct) — только по первым четырём буквам имени
    как по сигнатуре; если созданный член не отвечает на эту сигнатуру
    (массив структур), xEdit падает на Assert — модель тоже падает;
    у массива Add добавляет элемент.
  - Новая запись получает обязательные члены; новая вложенная структура —
    первый член и обязательные; новый массив — один элемент.
  - Подзапись-объединение (EPFD) хранит значение во вложенном поле, если
    выбранный вариант именован; запись в саму подзапись даёт исключение
    "... can not be edited", как в журнале пользователя.
  - Путь "A\B": сначала имя (Name или DisplayName), потом сигнатура.
    Вложенная структура отвечает на сигнатуру своей первой подзаписи
    ("Magic Effect Data" отвечает на DATA). Setter создаёт недостающий член
    только на уровне записи; иначе пробует Add(последнее имя) и молча
    ничего не делает, если не вышло.
  - Обработчики AfterSet: смена типа PRKE пересоздаёт DATA и параметры,
    Run On сбрасывает Reference, смена архетипа MGEF сбрасывает Actor Value.
  - ElementAssign ловит исключения и возвращает nil, как TwbElement.Assign.
  - wbCopyElementToFile возвращает уже существующую правку без изменений.

  Ванильные записи, на которые ссылается генератор, создаются заранее
  с правдоподобным содержимым. VerifyGenerated проверяет итоговый плагин. }
unit xedit_mock;

{$mode delphi}

interface

uses
  SysUtils, Variants, Classes;

const
  HighInteger = High(Integer);

procedure AddMessage(const s: string);
function FileByName(const s: string): IInterface;
function AddNewFileName(const s: string; aLight: Boolean): IInterface;
function AddMasterIfMissing(f: IInterface; const s: string): Variant;
function SortMasters(f: IInterface): Variant;
function MasterCount(f: IInterface): Integer;
function MasterByIndex(f: IInterface; i: Integer): IInterface;
function RecordCount(f: IInterface): Integer;
function GetFileName(f: IInterface): string;
function GetFile(e: IInterface): IInterface;
function GroupBySignature(f: IInterface; const s: string): IInterface;
function FileFormIDtoLoadOrderFormID(f: IInterface; formId: Integer): Integer;
function RecordByFormID(f: IInterface; formId: Integer; allowInjected: Boolean): IInterface;
function EditorID(e: IInterface): string;
function SetEditorID(e: IInterface; const s: string): Variant;
function Signature(e: IInterface): string;
function MasterOrSelf(e: IInterface): IInterface;
function OverrideCount(e: IInterface): Integer;
function OverrideByIndex(e: IInterface; i: Integer): IInterface;
function WinningOverride(e: IInterface): IInterface;
function GetLoadOrderFormID(e: IInterface): Cardinal;
function ContainingMainRecord(e: IInterface): IInterface;
function Name(e: IInterface): string;
function ElementCount(e: IInterface): Integer;
function ElementByIndex(e: IInterface; i: Integer): IInterface;
function ElementByName(e: IInterface; const s: string): IInterface;
function ElementByPath(e: IInterface; const s: string): IInterface;
function ElementBySignature(e: IInterface; const s: string): IInterface;
function Add(e: IInterface; const s: string; silent: Boolean): IInterface;
function ElementAssign(e: IInterface; index: Integer; src: IInterface; onlySK: Boolean): IInterface;
function LinksTo(e: IInterface): IInterface;
function GetEditValue(e: IInterface): string;
function SetEditValue(e: IInterface; const s: string): Variant;
function GetNativeValue(e: IInterface): Variant;
function SetNativeValue(e: IInterface; v: Variant): Variant;
function GetElementEditValues(e: IInterface; const path: string): string;
function SetElementEditValues(e: IInterface; const path, value: string): Variant;
function GetElementNativeValues(e: IInterface; const path: string): Variant;
function SetElementNativeValues(e: IInterface; const path: string; v: Variant): Variant;
function AddRequiredElementMasters(e, f: IInterface; asNew, silent: Boolean): Boolean;
function wbCopyElementToFile(e, f: IInterface; asNew, deepCopy: Boolean): IInterface;

procedure VerifyGenerated;

implementation

type
  TNode = class;

  TDefKind = (dkRecord, dkSub, dkRStruct, dkRArray, dkRUnion,
    dkInt, dkFloat, dkString, dkFormID, dkBytes, dkStruct, dkArray, dkUnion);

  TDecider = function(n: TNode): Integer;
  TAfterSet = procedure(n: TNode; const oldV, newV: Variant);

  TDef = class
  public
    Kind: TDefKind;
    Sig: string;
    Name: string;
    Members: array of TDef;
    Element: TDef;
    Value: TDef;
    Required: Boolean;
    Enum: TStringList;
    Default: Variant;
    Decider: TDecider;
    AfterSet: TAfterSet;
    function DefaultSig: string;
    function HasSig(const s: string): Boolean;
    function MemberIndexFor(const s: string): Integer;
  end;

  TNodeKind = (nkFile, nkGroup, nkRecord, nkSub, nkRStruct, nkRArray, nkValue);

  INode = interface
    ['{6F0B7C0A-2B4E-4F4B-9C62-6E1C3C9E7A12}']
    function Node: TObject;
  end;

  TNode = class(TInterfacedObject, INode)
  public
    Kind: TNodeKind;
    Def: TDef;
    VDef: TDef;           // подзапись: определение значения, если оно лежит в ней самой
    Parent: TNode;
    Kids: TInterfaceList;
    Value: Variant;
    Slot: Integer;        // номер члена в записи или вложенной структуре
    FileName: string;
    Masters: TStringList;
    LoadIndex: Integer;
    FormId: Cardinal;
    Edid: string;
    MasterRec: TNode;
    Overrides: TList;
    constructor Create(aParent: TNode; aKind: TNodeKind; aDef: TDef; aSlot: Integer);
    destructor Destroy; override;
    function Node: TObject;
    function Kid(i: Integer): TNode;
  end;

var
  AllDefs: TList;
  RecordDefs: TStringList;
  Files: TInterfaceList;
  Registry: TStringList;
  NextObjectId: Cardinal = $800;
  Messages: TStringList;
  MessagesErrors: Integer = 0;
  MessagesWarnings: Integer = 0;

//============================================================================
// Определения
//============================================================================

function TDef.DefaultSig: string;
begin
  case Kind of
    dkSub: Result := Sig;
    dkRStruct, dkRUnion: Result := Members[0].DefaultSig;
    dkRArray: Result := Element.DefaultSig;
  else
    Result := '';
  end;
end;

function TDef.HasSig(const s: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  case Kind of
    dkSub: Result := Sig = s;
    dkRStruct, dkRUnion:
      for i := 0 to High(Members) do
        if Members[i].HasSig(s) then
          Exit(True);
    dkRArray: Result := Element.HasSig(s);
  end;
end;

function TDef.MemberIndexFor(const s: string): Integer;
var
  i: Integer;
begin
  for i := 0 to High(Members) do
    if Members[i].HasSig(s) then
      Exit(i);
  Result := -1;
end;

function NewDef(k: TDefKind; const sig, aName: string): TDef;
begin
  Result := TDef.Create;
  Result.Kind := k;
  Result.Sig := sig;
  Result.Name := aName;
  Result.Default := 0;
  AllDefs.Add(Result);
end;

procedure SetMembers(d: TDef; const m: array of TDef);
var
  i: Integer;
begin
  SetLength(d.Members, Length(m));
  for i := 0 to High(m) do
    d.Members[i] := m[i];
end;

function VInt(const aName: string): TDef;
begin
  Result := NewDef(dkInt, '', aName);
end;

function VEnum(const aName: string; const pairs: array of string): TDef;
var
  i: Integer;
begin
  Result := NewDef(dkInt, '', aName);
  Result.Enum := TStringList.Create;
  for i := 0 to High(pairs) do
    Result.Enum.Add(pairs[i]);
end;

function VFloat(const aName: string): TDef;
begin
  Result := NewDef(dkFloat, '', aName);
  Result.Default := 0.0;
end;

function VStr(const aName: string): TDef;
begin
  Result := NewDef(dkString, '', aName);
  Result.Default := '';
end;

function VFormID(const aName: string): TDef;
begin
  Result := NewDef(dkFormID, '', aName);
end;

function VBytes(const aName: string): TDef;
begin
  Result := NewDef(dkBytes, '', aName);
end;

function VStruct(const aName: string; const fields: array of TDef): TDef;
begin
  Result := NewDef(dkStruct, '', aName);
  SetMembers(Result, fields);
end;

function VArray(const aName: string; el: TDef): TDef;
begin
  Result := NewDef(dkArray, '', aName);
  Result.Element := el;
end;

function VUnion(const aName: string; d: TDecider; const m: array of TDef): TDef;
begin
  Result := NewDef(dkUnion, '', aName);
  Result.Decider := d;
  SetMembers(Result, m);
end;

function WithAfterSet(d: TDef; a: TAfterSet): TDef;
begin
  d.AfterSet := a;
  Result := d;
end;

function WithDefault(d: TDef; v: Variant): TDef;
begin
  d.Default := v;
  Result := d;
end;

function Sub(const sig, aName: string; v: TDef; req: Boolean): TDef;
begin
  Result := NewDef(dkSub, sig, aName);
  Result.Value := v;
  Result.Required := req;
end;

function RStruct(const aName: string; const m: array of TDef; req: Boolean): TDef;
begin
  Result := NewDef(dkRStruct, '', aName);
  SetMembers(Result, m);
  Result.Required := req;
end;

function RArray(const aName: string; el: TDef; req: Boolean): TDef;
begin
  Result := NewDef(dkRArray, '', aName);
  Result.Element := el;
  Result.Required := req;
end;

function RUnion(const aName: string; const m: array of TDef): TDef;
begin
  Result := NewDef(dkRUnion, '', aName);
  SetMembers(Result, m);
end;

procedure DefRecord(const sig: string; const m: array of TDef);
var
  d: TDef;
begin
  d := NewDef(dkRecord, sig, sig);
  SetMembers(d, m);
  RecordDefs.AddObject(sig, d);
end;

//============================================================================
// Узлы
//============================================================================

constructor TNode.Create(aParent: TNode; aKind: TNodeKind; aDef: TDef; aSlot: Integer);
var
  i: Integer;
begin
  inherited Create;
  Kind := aKind;
  Def := aDef;
  Parent := aParent;
  Slot := aSlot;
  Kids := TInterfaceList.Create;
  Overrides := TList.Create;
  Value := Unassigned;
  if Assigned(aParent) then begin
    // В записи и вложенной структуре члены идут в порядке определения.
    i := aParent.Kids.Count;
    if (aSlot >= 0) and (aParent.Kind in [nkRecord, nkRStruct]) then
      while (i > 0) and (aParent.Kid(i - 1).Slot > aSlot) do
        Dec(i);
    aParent.Kids.Insert(i, Self as IInterface);
  end;
end;

destructor TNode.Destroy;
begin
  Kids.Free;
  Overrides.Free;
  Masters.Free;
  inherited;
end;

function TNode.Node: TObject;
begin
  Result := Self;
end;

function TNode.Kid(i: Integer): TNode;
begin
  Result := TNode((Kids[i] as INode).Node);
end;

function NodeOf(e: IInterface): TNode;
var
  x: INode;
begin
  Result := nil;
  if Assigned(e) and Supports(e, INode, x) then
    Result := TNode(x.Node);
end;

function IntfOf(n: TNode): IInterface;
begin
  if Assigned(n) then
    Result := n as IInterface
  else
    Result := nil;
end;

procedure RemoveKid(n: TNode);
begin
  if Assigned(n) and Assigned(n.Parent) then
    n.Parent.Kids.Remove(n as IInterface);
end;

function HexId(id: Cardinal): string;
begin
  Result := IntToHex(id, 8);
end;

function RecordOf(n: TNode): TNode;
begin
  Result := n;
  while Assigned(Result) and (Result.Kind <> nkRecord) do
    Result := Result.Parent;
end;

function FileOf(n: TNode): TNode;
begin
  Result := n;
  while Assigned(Result) and (Result.Kind <> nkFile) do
    Result := Result.Parent;
end;

function NodeSignature(n: TNode): string;
var
  i: Integer;
begin
  Result := '';
  if not Assigned(n) then
    Exit;
  case n.Kind of
    nkRecord, nkSub: Result := n.Def.Sig;
    nkRStruct, nkRArray:
      for i := 0 to n.Kids.Count - 1 do
        if n.Kid(i).Kind = nkSub then
          Exit(n.Kid(i).Def.Sig);
  end;
end;

function NodeName(n: TNode): string;
begin
  Result := '';
  if not Assigned(n) then
    Exit;
  case n.Kind of
    nkFile: Result := n.FileName;
    nkGroup: Result := 'GRUP Top "' + VarToStr(n.Value) + '"';
    nkRecord: Result := n.Edid + ' [' + n.Def.Sig + ':' + HexId(n.FormId) + ']';
    nkSub: Result := n.Def.Sig + ' - ' + n.Def.Name;
  else
    Result := n.Def.Name;
  end;
end;

function DisplayName(n: TNode): string;
begin
  Result := NodeName(n);
  if Assigned(n) and (n.Kind = nkSub) and not Assigned(n.VDef) and (n.Kids.Count = 1)
     and Assigned(n.Def.Value) and (n.Def.Value.Kind = dkUnion) then
    Result := n.Def.Sig + ' - ' + n.Kid(0).Def.Name;
end;

function KidByName(n: TNode; const s: string): TNode;
var
  i: Integer;
begin
  Result := nil;
  if not Assigned(n) then
    Exit;
  for i := 0 to n.Kids.Count - 1 do
    if SameText(NodeName(n.Kid(i)), s) then
      Exit(n.Kid(i));
  for i := 0 to n.Kids.Count - 1 do
    if SameText(DisplayName(n.Kid(i)), s) then
      Exit(n.Kid(i));
end;

function KidBySig(n: TNode; const s: string): TNode;
var
  i: Integer;
begin
  Result := nil;
  if not Assigned(n) then
    Exit;
  for i := 0 to n.Kids.Count - 1 do
    if NodeSignature(n.Kid(i)) = s then
      Exit(n.Kid(i));
end;

function KidBySlot(n: TNode; slot: Integer): TNode;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to n.Kids.Count - 1 do
    if n.Kid(i).Slot = slot then
      Exit(n.Kid(i));
end;

//============================================================================
// Создание элементов
//============================================================================

function CreateMember(parent: TNode; def: TDef; slot: Integer): TNode; forward;

function CreateValue(parent: TNode; def: TDef): TNode;
var
  i: Integer;
begin
  Result := TNode.Create(parent, nkValue, def, -1);
  if def.Kind = dkStruct then begin
    for i := 0 to High(def.Members) do
      CreateValue(Result, def.Members[i]);
  end else if def.Kind <> dkArray then
    Result.Value := def.Default;
end;

// Разбор значения подзаписи при создании (TwbSubRecord.Init): безымянная
// структура раскладывается на поля прямо в подзаписи, именованный вариант
// объединения становится вложенным элементом, а значение самой подзаписи
// становится нередактируемым.
procedure InitSubValue(n: TNode);
var
  v, m: TDef;
  i: Integer;
begin
  n.Kids.Clear;
  n.VDef := nil;
  v := n.Def.Value;
  if not Assigned(v) then
    Exit;
  case v.Kind of
    dkUnion: begin
      m := v.Members[v.Decider(n)];
      if m.Name <> '' then
        CreateValue(n, m)
      else begin
        n.VDef := m;
        n.Value := m.Default;
      end;
    end;
    dkStruct:
      if v.Name = '' then begin
        for i := 0 to High(v.Members) do
          CreateValue(n, v.Members[i]);
      end else
        CreateValue(n, v);
    dkArray: n.VDef := v;
  else
    n.VDef := v;
    n.Value := v.Default;
  end;
end;

function CreateSub(parent: TNode; def: TDef; slot: Integer): TNode;
begin
  Result := TNode.Create(parent, nkSub, def, slot);
  InitSubValue(Result);
end;

function CreateRStruct(parent: TNode; def: TDef; slot: Integer): TNode;
var
  i: Integer;
begin
  Result := TNode.Create(parent, nkRStruct, def, slot);
  for i := 0 to High(def.Members) do
    if (i = 0) or def.Members[i].Required then
      CreateMember(Result, def.Members[i], i);
end;

function AppendElement(arr: TNode): TNode;
var
  el: TDef;
begin
  el := arr.Def.Element;
  while el.Kind = dkRUnion do
    el := el.Members[0];
  if el.Kind = dkSub then
    Result := CreateSub(arr, el, -1)
  else
    Result := CreateRStruct(arr, el, -1);
end;

function CreateRArray(parent: TNode; def: TDef; slot: Integer): TNode;
begin
  Result := TNode.Create(parent, nkRArray, def, slot);
  AppendElement(Result);
end;

function CreateMember(parent: TNode; def: TDef; slot: Integer): TNode;
begin
  while def.Kind = dkRUnion do
    def := def.Members[0];
  case def.Kind of
    dkSub: Result := CreateSub(parent, def, slot);
    dkRStruct: Result := CreateRStruct(parent, def, slot);
    dkRArray: Result := CreateRArray(parent, def, slot);
  else
    raise Exception.Create('mock: bad member kind');
  end;
end;

//============================================================================
// Значения
//============================================================================

function EnumName(d: TDef; v: Integer): string;
var
  i: Integer;
begin
  for i := 0 to d.Enum.Count - 1 do
    if StrToInt(d.Enum.ValueFromIndex[i]) = v then
      Exit(d.Enum.Names[i]);
  Result := '<Unknown: ' + IntToStr(v) + '>';
end;

function EnumValue(d: TDef; const s: string): Integer;
var
  i: Integer;
begin
  for i := 0 to d.Enum.Count - 1 do
    if SameText(d.Enum.Names[i], s) then
      Exit(StrToInt(d.Enum.ValueFromIndex[i]));
  if not TryStrToInt(s, Result) then
    raise Exception.Create('"' + s + '" is not a valid value for ' + d.Name);
end;

function RecordByLoadOrderId(id: Cardinal): TNode;
var
  i: Integer;
begin
  Result := nil;
  i := Registry.IndexOf(HexId(id));
  if i >= 0 then
    Result := TNode(Registry.Objects[i]);
end;

function FormIdEdit(id: Cardinal): string;
var
  r: TNode;
begin
  if id = 0 then
    Exit('NULL - Null Reference [00000000]');
  r := RecordByLoadOrderId(id);
  if Assigned(r) then
    Result := r.Edid + ' [' + r.Def.Sig + ':' + HexId(id) + ']'
  else
    Result := '[' + HexId(id) + '] < Error: Could not be resolved >';
end;

// Как TwbFormIDDefFormater.FromEditValue: 8 hex-цифр или "... [SIG:XXXXXXXX]".
function ParseFormId(const s: string): Cardinal;
var
  t: string;
  i: Integer;
begin
  t := Trim(s);
  i := LastDelimiter('[', t);
  if i > 0 then begin
    t := Copy(t, i + 1, Length(t));
    i := Pos(']', t);
    if i > 0 then
      t := Copy(t, 1, i - 1);
    if (Length(t) = 13) and (t[5] = ':') then
      Delete(t, 1, 5);
  end;
  if Length(t) <> 8 then
    raise Exception.Create('mock: bad FormID "' + s + '"');
  Result := Cardinal(StrToInt64('$' + t));
end;

// Определение, которое действует для узла сейчас (объединение — по решателю).
function EffectiveDef(n: TNode): TDef;
begin
  Result := nil;
  case n.Kind of
    nkSub: Result := n.VDef;
    nkValue: Result := n.Def;
  end;
  if Assigned(Result) and (Result.Kind = dkUnion) then
    Result := Result.Members[Result.Decider(n)];
end;

function FloatStr(v: Double): string;
var
  fs: TFormatSettings;
begin
  fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  Result := FormatFloat('0.000000', v, fs);
end;

function NodeEdit(n: TNode): string;
var
  d: TDef;
begin
  Result := '';
  if not Assigned(n) or not (n.Kind in [nkSub, nkValue]) then
    Exit;
  d := EffectiveDef(n);
  if not Assigned(d) or (d.Kind in [dkStruct, dkArray]) then
    Exit;
  case d.Kind of
    dkInt:
      if Assigned(d.Enum) then
        Result := EnumName(d, n.Value)
      else
        Result := IntToStr(Integer(n.Value));
    dkFloat: Result := FloatStr(n.Value);
    dkFormID: Result := FormIdEdit(Cardinal(Int64(n.Value)));
    dkString: Result := VarToStr(n.Value);
    dkBytes: Result := '00 00 00 00';
  end;
end;

function NodeNative(n: TNode): Variant;
var
  d: TDef;
begin
  Result := Unassigned;
  if not Assigned(n) then
    Exit;
  if (n.Kind = nkSub) and not Assigned(n.VDef) then begin
    if Assigned(n.Def.Value) and (n.Def.Value.Kind = dkUnion) then
      Result := Null;
    Exit;
  end;
  if not (n.Kind in [nkSub, nkValue]) then
    Exit;
  d := EffectiveDef(n);
  if Assigned(d) and not (d.Kind in [dkStruct, dkArray]) then
    Result := n.Value;
end;

procedure StoreValue(n: TNode; d: TDef; v: Variant);
var
  old: Variant;
begin
  old := n.Value;
  case d.Kind of
    dkInt, dkBytes: n.Value := Integer(Round(Double(v)));
    dkFloat: n.Value := Double(v);
    dkFormID: n.Value := Int64(Round(Double(v)));
    dkString: n.Value := VarToStr(v);
  else
    raise Exception.Create(d.Name + ' is not editable.');
  end;
  if Assigned(n.Def.AfterSet) then
    n.Def.AfterSet(n, old, n.Value);
end;

procedure CheckEditable(n: TNode);
begin
  if not Assigned(n) then
    raise Exception.Create('mock: nil element');
  if (n.Kind = nkSub) and not Assigned(n.VDef) then
    raise Exception.Create(NodeName(n) + ' can not be edited');
  if not (n.Kind in [nkSub, nkValue]) then
    raise Exception.Create(NodeName(n) + ' can not be edited.');
end;

procedure NodeSetNative(n: TNode; v: Variant);
begin
  CheckEditable(n);
  StoreValue(n, EffectiveDef(n), v);
end;

procedure NodeSetEdit(n: TNode; const s: string);
var
  d: TDef;
  fs: TFormatSettings;
begin
  CheckEditable(n);
  d := EffectiveDef(n);
  case d.Kind of
    dkInt:
      if Assigned(d.Enum) then
        StoreValue(n, d, EnumValue(d, s))
      else
        StoreValue(n, d, StrToInt(s));
    dkFloat: begin
      fs := DefaultFormatSettings;
      fs.DecimalSeparator := '.';
      StoreValue(n, d, StrToFloat(s, fs));
    end;
    dkFormID: StoreValue(n, d, Int64(ParseFormId(s)));
    dkString: StoreValue(n, d, s);
  else
    raise Exception.Create(d.Name + ' is not editable.');
  end;
end;

//============================================================================
// Add, ElementAssign и пути (как в wbImplementation.pas 4.1.5f)
//============================================================================

function NewRecordIn(group: TNode; const sig: string; id: Cardinal): TNode;
var
  i, idx: Integer;
  d: TDef;
begin
  idx := RecordDefs.IndexOf(sig);
  if idx < 0 then
    raise Exception.Create('mock: no definition for ' + sig);
  d := TDef(RecordDefs.Objects[idx]);
  Result := TNode.Create(group, nkRecord, d, -1);
  Result.FormId := id;
  for i := 0 to High(d.Members) do
    if d.Members[i].Required then
      CreateMember(Result, d.Members[i], i);
  if Registry.IndexOf(HexId(id)) < 0 then
    Registry.AddObject(HexId(id), Result);
end;

function GroupOf(f: TNode; const sig: string; create: Boolean): TNode;
var
  i: Integer;
begin
  for i := 0 to f.Kids.Count - 1 do
    if VarToStr(f.Kid(i).Value) = sig then
      Exit(f.Kid(i));
  Result := nil;
  if create then begin
    Result := TNode.Create(f, nkGroup, nil, -1);
    Result.Value := sig;
  end;
end;

function NodeAdd(n: TNode; const s: string): TNode;
var
  i: Integer;
  sig: string;
begin
  Result := nil;
  if not Assigned(n) then
    Exit;
  case n.Kind of
    nkFile: Result := GroupOf(n, s, True);
    nkGroup: begin
      Inc(NextObjectId);
      Result := NewRecordIn(n, s, (Cardinal(FileOf(n).LoadIndex) shl 24) or NextObjectId);
    end;
    nkRecord:
      // TwbMainRecord.Add: член по имени или по сигнатуре по умолчанию
      for i := 0 to High(n.Def.Members) do
        if SameText(n.Def.Members[i].Name, s) or SameText(n.Def.Members[i].DefaultSig, s) then begin
          Result := KidBySlot(n, i);
          if not Assigned(Result) then
            Result := CreateMember(n, n.Def.Members[i], i);
          Exit;
        end;
    nkRStruct: begin
      // TwbSubRecordStruct.Add: только по сигнатуре (первые 4 буквы имени)
      if Length(s) < 4 then
        Exit;
      sig := Copy(s, 1, 4);
      Result := KidBySig(n, sig);
      if Assigned(Result) then
        Exit;
      i := n.Def.MemberIndexFor(sig);
      if i < 0 then
        Exit;
      CreateMember(n, n.Def.Members[i], i);
      Result := KidBySig(n, sig);
      if not Assigned(Result) then
        raise Exception.Create('Assertion failure (TwbSubRecordStruct.Add ' + s + ' in ' + NodeName(n) + ')');
    end;
    nkRArray: Result := AppendElement(n);
    nkSub:
      if Assigned(n.VDef) and (n.VDef.Kind = dkArray) then
        Result := CreateValue(n, n.VDef.Element);
  end;
end;

function NodeAssign(n: TNode; index: Integer): TNode;
begin
  Result := nil;
  if not Assigned(n) then
    Exit;
  case n.Kind of
    nkRArray:
      if index >= 0 then
        Result := AppendElement(n);
    nkRecord, nkRStruct:
      if (index >= 0) and (index <= High(n.Def.Members)) then begin
        Result := KidBySlot(n, index);
        if not Assigned(Result) then
          Result := CreateMember(n, n.Def.Members[index], index);
      end;
    nkSub:
      if Assigned(n.VDef) and (n.VDef.Kind = dkArray) and (index >= 0) then
        Result := CreateValue(n, n.VDef.Element);
  end;
end;

procedure SplitPath(const path: string; out first, rest: string);
var
  i: Integer;
begin
  i := Pos('\', path);
  if i > 0 then begin
    first := Copy(path, 1, i - 1);
    rest := Copy(path, i + 1, Length(path));
  end else begin
    first := path;
    rest := '';
  end;
end;

// TwbContainer.ResolveElementName (+ создание члена записи в TwbMainRecord).
function ResolveFirst(n: TNode; const path: string; out rest: string; canCreate: Boolean): TNode;
var
  first: string;
  i: Integer;
begin
  Result := nil;
  SplitPath(path, first, rest);
  if not Assigned(n) then
    Exit;
  if first = '..' then
    Exit(n.Parent);
  if (Length(first) > 2) and (first[1] = '[') and (first[Length(first)] = ']') then begin
    i := StrToIntDef(Copy(first, 2, Length(first) - 2), 0);
    if (i >= 0) and (i < n.Kids.Count) then
      Result := n.Kid(i);
    Exit;
  end;
  Result := KidByName(n, first);
  if not Assigned(Result) and (Length(first) = 4) then
    Result := KidBySig(n, first);
  if not Assigned(Result) and canCreate and (n.Kind = nkRecord) and (Length(first) = 4) then begin
    i := n.Def.MemberIndexFor(first);
    if i >= 0 then begin
      CreateMember(n, n.Def.Members[i], i);
      Result := KidBySig(n, first);
    end;
  end;
end;

function NodeByPath(n: TNode; const path: string): TNode;
var
  rest: string;
begin
  Result := ResolveFirst(n, path, rest, False);
  if Assigned(Result) and (rest <> '') then
    Result := NodeByPath(Result, rest);
end;

procedure PathSet(n: TNode; const path: string; v: Variant; asEdit: Boolean);
var
  rest: string;
  el: TNode;
begin
  el := ResolveFirst(n, path, rest, True);
  if not Assigned(el) then begin
    if rest = '' then begin
      // TwbContainer.SetMemberEditValue: Add(имя) и запись в результат
      el := NodeAdd(n, path);
      if Assigned(el) then
        NodeSetEdit(el, VarToStr(v));
    end;
    Exit;
  end;
  if rest <> '' then
    PathSet(el, rest, v, asEdit)
  else if asEdit then
    NodeSetEdit(el, VarToStr(v))
  else
    NodeSetNative(el, v);
end;

//============================================================================
// Решатели объединений и обработчики AfterSet
//============================================================================

function DecideEPFD(n: TNode): Integer;
var
  t: TNode;
begin
  Result := 0;
  t := KidBySig(n.Parent, 'EPFT');
  if Assigned(t) and not VarIsEmpty(t.Value) then
    Result := t.Value;
  if (Result < 0) or (Result > 7) then
    Result := 0;
end;

function DecidePerkData(n: TNode): Integer;
var
  prke: TNode;
begin
  Result := 0;
  prke := KidBySig(n.Parent, 'PRKE');
  if Assigned(prke) then
    Result := KidByName(prke, 'Type').Value;
end;

function DecideCompValue(n: TNode): Integer;
begin
  Result := 0;
  if (Integer(KidByName(n.Parent, 'Type').Value) and 4) <> 0 then
    Result := 1;
end;

// Тип параметра #1 по функции условия (упрощённо: нет / AV / FormID).
function DecideParam1(n: TNode): Integer;
begin
  case Integer(KidByName(n.Parent, 'Function').Value) of
    277, 696: Result := 1;                       // GetBaseActorValue, EPMagic_SpellHasSkill
    182, 372, 448, 560, 693, 699, 719: Result := 2;   // WornHasKeyword, IsInList, HasPerk, HasKeyword, EPMagic_SpellHasKeyword, HasMagicEffectKeyword, IsHostileToActor
  else
    Result := 0;
  end;
end;

function DecideReference(n: TNode): Integer;
begin
  Result := 0;
  if Integer(KidByName(n.Parent, 'Run On').Value) = 2 then
    Result := 1;
end;

function DecideFirst(n: TNode): Integer;
begin
  Result := 0;
end;

procedure SetSibling(n: TNode; const aName: string; v: Variant);
var
  s: TNode;
begin
  s := KidByName(n.Parent, aName);
  if Assigned(s) then
    NodeSetNative(s, v);
end;

// wbPERKPRKETypeAfterSet
procedure AfterPrkeType(n: TNode; const oldV, newV: Variant);
var
  eff: TNode;
  i: Integer;
begin
  if oldV = newV then
    Exit;
  eff := n.Parent.Parent;
  RemoveKid(KidBySig(eff, 'DATA'));
  i := eff.Def.MemberIndexFor('DATA');
  CreateMember(eff, eff.Def.Members[i], i);
  RemoveKid(KidByName(eff, 'Perk Conditions'));
  if newV <> 2 then
    Exit;
  NodeAdd(eff, 'EPFT');
  PathSet(eff, 'DATA\Entry Point\Function', 2, False);
end;

// wbCTDARunOnAfterSet
procedure AfterRunOn(n: TNode; const oldV, newV: Variant);
begin
  if (oldV <> newV) and (newV <> 2) then
    SetSibling(n, 'Reference', 0);
end;

// wbCtdaTypeAfterSet
procedure AfterCtdaType(n: TNode; const oldV, newV: Variant);
begin
  if VarIsEmpty(oldV) then
    Exit;
  if (Integer(oldV) and 4) <> (Integer(newV) and 4) then
    SetSibling(n, 'Comparison Value', 0);
end;

// wbMGEFArchtypeAfterSet
procedure AfterArchtype(n: TNode; const oldV, newV: Variant);
begin
  if oldV = newV then
    Exit;
  if (newV < $FF) and (oldV < $FF) then begin
    SetSibling(n, 'Assoc. Item', 0);
    case Integer(newV) of
      6, 8: SetSibling(n, 'Actor Value', 0);
      7, 24, 38, 42: SetSibling(n, 'Actor Value', 1);
      11: SetSibling(n, 'Actor Value', 54);
      21: SetSibling(n, 'Actor Value', 53);
    else
      SetSibling(n, 'Actor Value', -1);
    end;
    SetSibling(n, 'Second Actor Value', -1);
    SetSibling(n, 'Second AV Weight', 0.0);
  end;
end;

//============================================================================
// Определения записей (подмножество wbDefinitionsTES5.pas 4.1.5f)
//============================================================================

function ActorValueEnum(const aName: string): TDef;
begin
  Result := VEnum(aName, ['None=-1', 'Aggression=0', 'Confidence=1', 'OneHanded=6', 'Block=9',
    'Alteration=18', 'Conjuration=19', 'Destruction=20', 'Illusion=21', 'Restoration=22',
    'Health=24', 'Magicka=25', 'Stamina=26']);
end;

function FunctionEnum: TDef;
begin
  Result := VEnum('Function', ['GetWantBlocking=0', 'GetLevel=80', 'WornHasKeyword=182', 'IsBlocking=250',
    'GetBaseActorValue=277', 'IsInList=372', 'HasPerk=448', 'HasKeyword=560',
    'EPMagic_SpellHasKeyword=693', 'EPMagic_SpellHasSkill=696', 'HasMagicEffectKeyword=699',
    'IsCommandedActor=700', 'IsHostileToActor=719']);
end;

function Conditions(req: Boolean): TDef;
var
  ctda: TDef;
begin
  ctda := Sub('CTDA', '', VStruct('', [
    WithAfterSet(VInt('Type'), AfterCtdaType),
    VBytes('Unused'),
    VUnion('Comparison Value', DecideCompValue, [VFloat('Comparison Value - Float'), VFormID('Comparison Value - Global')]),
    FunctionEnum,
    VBytes('Unused'),
    VUnion('Parameter #1', DecideParam1, [VBytes('None'), ActorValueEnum('Actor Value'), VFormID('FormID')]),
    VUnion('Parameter #2', DecideFirst, [VBytes('None')]),
    WithAfterSet(VEnum('Run On', ['Subject=0', 'Target=1', 'Reference=2', 'Combat Target=3',
      'Linked Reference=4', 'Quest Alias=5', 'Package Data=6', 'Event Data=7']), AfterRunOn),
    VUnion('Reference', DecideReference, [VInt('Unused'), VFormID('Reference')]),
    WithDefault(VInt('Parameter #3'), -1)
  ]), False);
  Result := RArray('Conditions', RStruct('Condition', [ctda, Sub('CIS1', 'Parameter #1', VStr(''), False),
    Sub('CIS2', 'Parameter #2', VStr(''), False)], False), req);
end;

function KWDA: TDef;
begin
  Result := Sub('KWDA', 'Keywords', VArray('', VFormID('Keyword')), False);
end;

procedure BuildDefs;
var
  perkEffect, epData, fp, spellEffect, refAlias, locAlias: TDef;
begin
  DefRecord('KYWD', [Sub('EDID', 'Editor ID', VStr(''), False)]);
  DefRecord('WEAP', [Sub('EDID', 'Editor ID', VStr(''), False), Sub('KSIZ', 'Keyword Count', VInt(''), False), KWDA]);
  DefRecord('ACHR', [Sub('EDID', 'Editor ID', VStr(''), False)]);
  DefRecord('RACE', [Sub('EDID', 'Editor ID', VStr(''), False),
    Sub('DATA', '', VStruct('', [VFloat('Starting Health'), VFloat('Starting Magicka')]), True)]);
  DefRecord('FLST', [Sub('EDID', 'Editor ID', VStr(''), True),
    RArray('FormIDs', Sub('LNAM', 'FormID', VFormID(''), False), False)]);

  // PERK
  epData := VStruct('Entry Point', [
    VEnum('Entry Point', ['Calculate Weapon Damage=0', 'Mod Spell Magnitude=29', 'Mod Attack Damage=35',
      'Mod Incoming Damage=36', 'Mod Spell Cost=38', 'Mod Incoming Spell Magnitude=41']),
    VEnum('Function', ['Unknown 0=0', 'Set Value=1', 'Add Value=2', 'Multiply Value=3',
      'Add Range To Value=4', 'Add Actor Value Mult=5']),
    VInt('Perk Condition Tab Count')]);
  fp := RStruct('Function Parameters', [
    Sub('EPFT', 'Type', VEnum('', ['None=0', 'Float=1', 'Float/AV,Float=2', 'LVLI=3',
      'SPEL,lstring,flags=4', 'SPEL=5', 'string=6', 'lstring=7']), False),
    Sub('EPF2', 'Button Label', VStr(''), False),
    Sub('EPF3', 'Script Flags', VStruct('', [VInt('Script Flags'), VInt('Fragment Index')]), False),
    Sub('EPFD', 'Data', VUnion('', DecideEPFD, [VBytes('Unknown'), VFloat('Float'),
      VStruct('Float, Float', [VFloat('Float 1'), VFloat('Float 2')]), VFormID('Leveled Item'),
      VFormID('Spell'), VFormID('Spell'), VStr('Text'), VStr('Text')]), False)
  ], False);
  perkEffect := RStruct('Effect', [
    Sub('PRKE', 'Header', VStruct('', [
      WithAfterSet(VEnum('Type', ['Quest + Stage=0', 'Ability=1', 'Entry Point=2']), AfterPrkeType),
      VInt('Rank'), VInt('Priority')]), False),
    Sub('DATA', 'Effect Data', VUnion('', DecidePerkData, [
      VStruct('Quest + Stage', [VFormID('Quest'), VInt('Quest Stage'), VBytes('Unused')]),
      VFormID('Ability'),
      epData]), True),
    RArray('Perk Conditions', RStruct('Perk Condition', [
      Sub('PRKC', 'Run On (Tab Index)', VInt(''), False),
      Conditions(True)], False), False),
    fp,
    Sub('PRKF', 'End Marker', nil, True)
  ], False);
  DefRecord('PERK', [
    Sub('EDID', 'Editor ID', VStr(''), False),
    Sub('FULL', 'Name', VStr(''), False),
    Sub('DESC', 'Description', VStr(''), True),
    Conditions(False),
    Sub('DATA', 'Data', VStruct('', [VInt('Trait'), VInt('Level'), VInt('Num Ranks'), VInt('Playable'), VInt('Hidden')]), True),
    Sub('NNAM', 'Next Perk', VFormID(''), False),
    RArray('Effects', perkEffect, False)]);

  // MGEF: DATA лежит внутри структуры "Magic Effect Data"
  DefRecord('MGEF', [
    Sub('EDID', 'Editor ID', VStr(''), False),
    Sub('FULL', 'Name', VStr(''), False),
    Sub('KSIZ', 'Keyword Count', VInt(''), False),
    KWDA,
    RStruct('Magic Effect Data', [
      Sub('DATA', 'Data', VStruct('', [
        VInt('Flags'), VFloat('Base Cost'),
        VUnion('Assoc. Item', DecideFirst, [VFormID('Assoc. Item')]),
        ActorValueEnum('Magic Skill'), ActorValueEnum('Resist Value'), VInt('Counter Effect count'),
        VBytes('Unused'), VFormID('Casting Light'), VFloat('Taper Weight'), VFormID('Hit Shader'),
        VFormID('Enchant Shader'), VInt('Minimum Skill Level'),
        VStruct('Spellmaking', [VInt('Area'), VFloat('Casting Time')]),
        VFloat('Taper Curve'), VFloat('Taper Duration'), VFloat('Second AV Weight'),
        WithAfterSet(VEnum('Archtype', ['Value Modifier=0', 'Script=1', 'Dispel=2', 'Bound Weapon=17',
          'Summon Creature=18', 'Reanimate=22', 'Banish=42']), AfterArchtype),
        ActorValueEnum('Actor Value'), VFormID('Projectile'), VFormID('Explosion'),
        VEnum('Casting Type', ['Constant Effect=0', 'Fire and Forget=1', 'Concentration=2']),
        VEnum('Delivery', ['Self=0', 'Touch=1', 'Aimed=2', 'Target Actor=3', 'Target Location=4']),
        ActorValueEnum('Second Actor Value'), VFormID('Casting Art'), VFormID('Hit Effect Art'),
        VFormID('Impact Data'), VFloat('Skill Usage Multiplier'),
        VStruct('Dual Casting', [VFormID('Art'), VFloat('Scale')]),
        VFormID('Enchant Art'), VFormID('Hit Visuals'), VFormID('Enchant Visuals'),
        VFormID('Equip Ability'), VFormID('Image Space Modifier'), VFormID('Perk to Apply'),
        VInt('Casting Sound Level'), VStruct('Script Effect AI', [VFloat('Score'), VFloat('Delay Time')])
      ]), True)], False),
    RArray('Counter Effects', Sub('ESCE', 'Effect', VFormID(''), False), False),
    Sub('DNAM', 'Magic Item Description', VStr(''), False),
    Conditions(False)]);

  // SPEL
  spellEffect := RStruct('Effect', [
    Sub('EFID', 'Base Effect', VFormID(''), False),
    Sub('EFIT', '', VStruct('', [VFloat('Magnitude'), VInt('Area'), VInt('Duration')]), True),
    Conditions(False)], True);
  DefRecord('SPEL', [
    Sub('EDID', 'Editor ID', VStr(''), False),
    Sub('OBND', 'Object Bounds', VBytes(''), True),
    Sub('FULL', 'Name', VStr(''), False),
    Sub('KSIZ', 'Keyword Count', VInt(''), False),
    KWDA,
    Sub('MDOB', 'Menu Display Object', VFormID(''), False),
    Sub('ETYP', 'Equipment Type', VFormID(''), False),
    Sub('DESC', 'Description', VStr(''), True),
    Sub('SPIT', 'Data', VStruct('', [VInt('Base Cost'), VInt('Flags'),
      VEnum('Type', ['Spell=0', 'Disease=1', 'Power=2', 'Lesser Power=3', 'Ability=4', 'Poison=5']),
      VFloat('Charge Time'),
      VEnum('Cast Type', ['Constant Effect=0', 'Fire and Forget=1', 'Concentration=2']),
      VEnum('Target Type', ['Self=0', 'Touch=1', 'Aimed=2', 'Target Actor=3', 'Target Location=4']),
      VFloat('Cast Duration'), VFloat('Range'), VFormID('Half-cost Perk')]), True),
    RArray('Effects', spellEffect, True)]);

  // QUST
  refAlias := RStruct('Alias', [
    Sub('ALST', 'Reference Alias ID', VInt(''), True),
    Sub('ALID', 'Alias Name', VStr(''), True),
    Sub('FNAM', 'Alias Flags', VStruct('', [VInt('Flags'), VInt('Additional Flags')]), True),
    Sub('ALFI', 'Force Into Alias When Filled', VInt(''), False),
    Sub('ALFL', 'Specific Location', VFormID(''), False),
    Sub('ALFR', 'Forced Reference', VFormID(''), False),
    Sub('ALUA', 'Unique Actor', VFormID(''), False),
    RStruct('Location Alias Reference', [Sub('ALFA', 'Alias', VInt(''), False),
      Sub('KNAM', 'Keyword', VFormID(''), False), Sub('ALRT', 'Ref Type', VFormID(''), False)], False),
    RStruct('External Alias Reference', [Sub('ALEQ', 'Quest', VFormID(''), False),
      Sub('ALEA', 'Alias', VInt(''), False)], False),
    Conditions(False),
    Sub('KSIZ', 'Keyword Count', VInt(''), False),
    KWDA,
    Sub('ALDN', 'Display Name', VFormID(''), False),
    RArray('Alias Spells', Sub('ALSP', 'Spell', VFormID(''), False), False),
    RArray('Alias Factions', Sub('ALFC', 'Faction', VFormID(''), False), False),
    RArray('Alias Package Data', Sub('ALPC', 'Package', VFormID(''), False), False),
    Sub('VTCK', 'Voice Types', VFormID(''), False),
    Sub('ALED', 'Alias End', nil, True)], False);
  locAlias := RStruct('Alias', [
    Sub('ALLS', 'Location Alias ID', VInt(''), False),
    Sub('ALID', 'Alias Name', VStr(''), False),
    Sub('ALED', 'Alias End', nil, True)], False);
  DefRecord('QUST', [
    Sub('EDID', 'Editor ID', VStr(''), False),
    Sub('FULL', 'Name', VStr(''), False),
    Sub('DNAM', 'General', VStruct('', [VInt('Flags'), VInt('Priority'), VInt('Form Version'),
      VBytes('Unknown'), VInt('Type')]), True),
    Sub('ENAM', 'Event', VStr(''), False),
    Sub('NEXT', 'Marker', nil, True),
    Conditions(False),
    Sub('ANAM', 'Next Alias ID', VInt(''), True),
    RArray('Aliases', RUnion('Alias', [refAlias, locAlias]), False),
    Sub('NNAM', 'Description', VStr(''), False)]);

  // NPC_
  DefRecord('NPC_', [
    Sub('EDID', 'Editor ID', VStr(''), False),
    Sub('OBND', 'Object Bounds', VBytes(''), True),
    Sub('ACBS', 'Configuration', VStruct('', [VInt('Flags'), VInt('Magicka Offset'), VInt('Stamina Offset'),
      VUnion('Level', DecideFirst, [VInt('Level')]), VInt('Calc min level'), VInt('Calc max level'),
      VInt('Speed Multiplier'), VInt('Disposition Base (unused)'), VInt('Template Flags'),
      VInt('Health Offset'), VInt('Bleedout Override')]), True),
    RArray('Factions', Sub('SNAM', 'Faction', VStruct('', [VFormID('Faction'), VInt('Rank')]), False), False),
    Sub('INAM', 'Death item', VFormID(''), False),
    Sub('VTCK', 'Voice', VFormID(''), False),
    Sub('TPLT', 'Template', VFormID(''), False),
    Sub('RNAM', 'Race', VFormID(''), True),
    Sub('SPCT', 'Count', VInt(''), False),
    RArray('Actor Effects', Sub('SPLO', 'Actor Effect', VFormID(''), False), False),
    Sub('WNAM', 'Worn Armor', VFormID(''), False),
    Sub('PRKZ', 'Perk Count', VInt(''), False),
    RArray('Perks', Sub('PRKR', 'Perk', VStruct('', [VFormID('Perk'), VInt('Rank'), VBytes('Unused')]), False), False),
    Sub('COCT', 'Count', VInt(''), False),
    Sub('AIDT', 'AI Data', VBytes(''), True),
    Sub('KSIZ', 'Keyword Count', VInt(''), False),
    KWDA,
    Sub('CNAM', 'Class', VFormID(''), True),
    Sub('FULL', 'Name', VStr(''), False),
    Sub('DATA', 'Marker', nil, True)]);
end;

//============================================================================
// API
//============================================================================

procedure AddMessage(const s: string);
begin
  WriteLn(s);
  Messages.Add(s);
  if Pos('ERROR', s) > 0 then
    Inc(MessagesErrors);
  if Pos('WARNING', s) > 0 then
    Inc(MessagesWarnings);
end;

function FindFile(const s: string): TNode;
var
  k: Integer;
begin
  Result := nil;
  for k := 0 to Files.Count - 1 do
    if SameText(TNode((Files[k] as INode).Node).FileName, s) then
      Exit(TNode((Files[k] as INode).Node));
end;

function FileByName(const s: string): IInterface;
begin
  Result := IntfOf(FindFile(s));
end;

function NewFile(const s: string; const masters: array of string): TNode;
var
  i: Integer;
begin
  Result := TNode.Create(nil, nkFile, nil, -1);
  Result.FileName := s;
  Result.Masters := TStringList.Create;
  for i := 0 to High(masters) do
    Result.Masters.Add(masters[i]);
  Result.LoadIndex := Files.Count;
  Files.Add(Result as IInterface);
end;

function AddNewFileName(const s: string; aLight: Boolean): IInterface;
begin
  Result := IntfOf(NewFile(s, []));
end;

function AddMasterIfMissing(f: IInterface; const s: string): Variant;
begin
  if NodeOf(f).Masters.IndexOf(s) < 0 then
    NodeOf(f).Masters.Add(s);
  Result := Null;
end;

function SortMasters(f: IInterface): Variant;
begin
  Result := Null;
end;

function MasterCount(f: IInterface): Integer;
begin
  Result := NodeOf(f).Masters.Count;
end;

function MasterByIndex(f: IInterface; i: Integer): IInterface;
begin
  Result := FileByName(NodeOf(f).Masters[i]);
end;

function RecordCount(f: IInterface): Integer;
var
  g: Integer;
  n: TNode;
begin
  Result := 0;
  n := NodeOf(f);
  for g := 0 to n.Kids.Count - 1 do
    Inc(Result, n.Kid(g).Kids.Count);
end;

function GetFileName(f: IInterface): string;
begin
  Result := '';
  if Assigned(NodeOf(f)) then
    Result := NodeOf(f).FileName;
end;

function GetFile(e: IInterface): IInterface;
begin
  Result := IntfOf(FileOf(NodeOf(e)));
end;

function GroupBySignature(f: IInterface; const s: string): IInterface;
begin
  Result := IntfOf(GroupOf(NodeOf(f), s, False));
end;

function FileFormIDtoLoadOrderFormID(f: IInterface; formId: Integer): Integer;
var
  n: TNode;
  hi: Integer;
begin
  n := NodeOf(f);
  hi := Cardinal(formId) shr 24;
  if hi < n.Masters.Count then
    hi := FindFile(n.Masters[hi]).LoadIndex
  else
    hi := n.LoadIndex;
  Result := Integer((Cardinal(hi) shl 24) or (Cardinal(formId) and $FFFFFF));
end;

function RecordByFormID(f: IInterface; formId: Integer; allowInjected: Boolean): IInterface;
var
  n, g: TNode;
  i, k: Integer;
begin
  Result := nil;
  n := NodeOf(f);
  for i := 0 to n.Kids.Count - 1 do begin
    g := n.Kid(i);
    for k := 0 to g.Kids.Count - 1 do
      if g.Kid(k).FormId = Cardinal(formId) then
        Exit(IntfOf(g.Kid(k)));
  end;
end;

function EditorID(e: IInterface): string;
begin
  Result := '';
  if Assigned(NodeOf(e)) and (NodeOf(e).Kind = nkRecord) then
    Result := NodeOf(e).Edid;
end;

function SetEditorID(e: IInterface; const s: string): Variant;
var
  n, edid: TNode;
begin
  n := NodeOf(e);
  n.Edid := s;
  edid := KidBySig(n, 'EDID');
  if not Assigned(edid) then
    edid := CreateMember(n, n.Def.Members[0], 0);
  edid.Value := s;
  Result := Null;
end;

function Signature(e: IInterface): string;
begin
  Result := NodeSignature(NodeOf(e));
end;

function MasterNode(n: TNode): TNode;
begin
  Result := n;
  if Assigned(n) and Assigned(n.MasterRec) then
    Result := n.MasterRec;
end;

function MasterOrSelf(e: IInterface): IInterface;
begin
  Result := IntfOf(MasterNode(NodeOf(e)));
end;

function OverrideCount(e: IInterface): Integer;
begin
  Result := NodeOf(e).Overrides.Count;
end;

function OverrideByIndex(e: IInterface; i: Integer): IInterface;
begin
  Result := IntfOf(TNode(NodeOf(e).Overrides[i]));
end;

function WinningOverride(e: IInterface): IInterface;
var
  m: TNode;
begin
  Result := e;
  m := MasterNode(NodeOf(e));
  if not Assigned(m) then
    Exit;
  if m.Overrides.Count > 0 then
    Result := IntfOf(TNode(m.Overrides[m.Overrides.Count - 1]))
  else
    Result := IntfOf(m);
end;

function GetLoadOrderFormID(e: IInterface): Cardinal;
begin
  Result := 0;
  if Assigned(NodeOf(e)) then
    Result := NodeOf(e).FormId;
end;

function ContainingMainRecord(e: IInterface): IInterface;
begin
  Result := IntfOf(RecordOf(NodeOf(e)));
end;

function Name(e: IInterface): string;
begin
  Result := NodeName(NodeOf(e));
end;

function ElementCount(e: IInterface): Integer;
begin
  Result := 0;
  if Assigned(NodeOf(e)) then
    Result := NodeOf(e).Kids.Count;
end;

function ElementByIndex(e: IInterface; i: Integer): IInterface;
begin
  Result := nil;
  if Assigned(NodeOf(e)) and (i >= 0) and (i < NodeOf(e).Kids.Count) then
    Result := IntfOf(NodeOf(e).Kid(i));
end;

function ElementByName(e: IInterface; const s: string): IInterface;
begin
  Result := IntfOf(KidByName(NodeOf(e), s));
end;

function ElementByPath(e: IInterface; const s: string): IInterface;
begin
  Result := IntfOf(NodeByPath(NodeOf(e), s));
end;

function ElementBySignature(e: IInterface; const s: string): IInterface;
begin
  Result := IntfOf(KidBySig(NodeOf(e), s));
end;

function Add(e: IInterface; const s: string; silent: Boolean): IInterface;
begin
  Result := IntfOf(NodeAdd(NodeOf(e), s));
end;

function ElementAssign(e: IInterface; index: Integer; src: IInterface; onlySK: Boolean): IInterface;
begin
  try
    Result := IntfOf(NodeAssign(NodeOf(e), index));
  except
    on ex: Exception do begin
      AddMessage('Error assigning to [' + NodeName(NodeOf(e)) + ']: ' + ex.Message);
      Result := nil;
    end;
  end;
end;

function LinksTo(e: IInterface): IInterface;
var
  n: TNode;
  d: TDef;
begin
  Result := nil;
  n := NodeOf(e);
  if not Assigned(n) or not (n.Kind in [nkSub, nkValue]) then
    Exit;
  d := EffectiveDef(n);
  if Assigned(d) and (d.Kind = dkFormID) and not VarIsEmpty(n.Value) then
    Result := IntfOf(RecordByLoadOrderId(Cardinal(Int64(n.Value))));
end;

function GetEditValue(e: IInterface): string;
begin
  Result := NodeEdit(NodeOf(e));
end;

function SetEditValue(e: IInterface; const s: string): Variant;
begin
  if Assigned(NodeOf(e)) then
    NodeSetEdit(NodeOf(e), s);
  Result := Null;
end;

function GetNativeValue(e: IInterface): Variant;
begin
  Result := NodeNative(NodeOf(e));
end;

function SetNativeValue(e: IInterface; v: Variant): Variant;
begin
  if Assigned(NodeOf(e)) then
    NodeSetNative(NodeOf(e), v);
  Result := Null;
end;

function GetElementEditValues(e: IInterface; const path: string): string;
begin
  Result := NodeEdit(NodeByPath(NodeOf(e), path));
end;

function SetElementEditValues(e: IInterface; const path, value: string): Variant;
begin
  if Assigned(NodeOf(e)) then
    PathSet(NodeOf(e), path, value, True);
  Result := Null;
end;

// Отсутствующий элемент xEdit отдаёт как Unassigned, а JvInterpreter (Delphi)
// сравнивает его с числом как 0. В Free Pascal это не так, поэтому модель
// сразу отдаёт 0.
function GetElementNativeValues(e: IInterface; const path: string): Variant;
begin
  Result := NodeNative(NodeByPath(NodeOf(e), path));
  if VarIsEmpty(Result) then
    Result := 0;
end;

function SetElementNativeValues(e: IInterface; const path: string; v: Variant): Variant;
begin
  if Assigned(NodeOf(e)) then
    PathSet(NodeOf(e), path, v, False);
  Result := Null;
end;

function AddRequiredElementMasters(e, f: IInterface; asNew, silent: Boolean): Boolean;
begin
  Result := True;
end;

function CopyNode(src, parent: TNode): TNode;
var
  i: Integer;
begin
  Result := TNode.Create(parent, src.Kind, src.Def, src.Slot);
  Result.VDef := src.VDef;
  Result.Value := src.Value;
  Result.Edid := src.Edid;
  Result.FormId := src.FormId;
  for i := 0 to src.Kids.Count - 1 do
    CopyNode(src.Kid(i), Result);
end;

function wbCopyElementToFile(e, f: IInterface; asNew, deepCopy: Boolean): IInterface;
var
  src, m, r: TNode;
  i: Integer;
begin
  src := NodeOf(e);
  m := MasterNode(src);
  // Правка уже есть в этом файле: xEdit возвращает её без изменений
  // (aAllowOverwrite = False в скриптовом варианте функции).
  for i := 0 to m.Overrides.Count - 1 do
    if FileOf(TNode(m.Overrides[i])) = NodeOf(f) then
      Exit(IntfOf(TNode(m.Overrides[i])));
  r := CopyNode(src, GroupOf(NodeOf(f), src.Def.Sig, True));
  r.MasterRec := m;
  m.Overrides.Add(r);
  Result := IntfOf(r);
end;

//============================================================================
// Ванильные записи
//============================================================================

function Van(const fileName: string; objectId: Cardinal; const sig, edid: string): IInterface;
var
  f: TNode;
begin
  f := FindFile(fileName);
  Result := IntfOf(NewRecordIn(GroupOf(f, sig, True), sig, (Cardinal(f.LoadIndex) shl 24) or objectId));
  SetEditorID(Result, edid);
end;

function VanId(const fileName: string; objectId: Cardinal): string;
begin
  Result := HexId((Cardinal(FindFile(fileName).LoadIndex) shl 24) or objectId);
end;

function VanRec(const fileName: string; objectId: Cardinal): IInterface;
begin
  Result := IntfOf(RecordByLoadOrderId(StrToInt64('$' + VanId(fileName, objectId))));
end;

// Запись перка-образца: точка входа и число вкладок.
function VanPerkEntry(perk: IInterface; const ep: string; tabs: Integer): IInterface;
begin
  Result := ElementByIndex(Add(perk, 'Effects', True), 0);
  SetElementNativeValues(Result, 'PRKE\Type', 2);
  SetElementEditValues(Result, 'DATA\Entry Point\Entry Point', ep);
  SetElementEditValues(Result, 'DATA\Entry Point\Function', 'Multiply Value');
  SetElementNativeValues(Result, 'DATA\Entry Point\Perk Condition Tab Count', tabs);
  SetNativeValue(ElementByPath(Result, 'Function Parameters\EPFT'), 1);
end;

// Условие на вкладке tab записи перка-образца (type: 0 — AND, 1 — OR).
procedure VanCond(eff: IInterface; tab: Integer; const func, param: string; value, ctype: Integer);
var
  pcs, pc, cond, ctda: IInterface;
  i: Integer;
begin
  pc := nil;
  pcs := ElementByName(eff, 'Perk Conditions');
  if not Assigned(pcs) then begin
    pcs := ElementAssign(eff, 2, nil, False);
    pc := ElementByIndex(pcs, 0);
    SetElementNativeValues(pc, 'PRKC', tab);
    cond := ElementByIndex(ElementByName(pc, 'Conditions'), 0);
  end else begin
    for i := 0 to ElementCount(pcs) - 1 do
      if GetElementNativeValues(ElementByIndex(pcs, i), 'PRKC') = tab then
        pc := ElementByIndex(pcs, i);
    if Assigned(pc) then
      cond := ElementAssign(ElementByName(pc, 'Conditions'), HighInteger, nil, False)
    else begin
      pc := ElementAssign(pcs, HighInteger, nil, False);
      SetElementNativeValues(pc, 'PRKC', tab);
      cond := ElementByIndex(ElementByName(pc, 'Conditions'), 0);
    end;
  end;
  ctda := ElementBySignature(cond, 'CTDA');
  SetElementEditValues(ctda, 'Function', func);
  SetElementNativeValues(ctda, 'Type', ctype);
  SetElementNativeValues(ctda, 'Comparison Value', value);
  if param <> '' then
    SetElementEditValues(ctda, 'Parameter #1', param);
end;

procedure VanTemplate(const fileName: string; objectId: Cardinal; flags: Integer; const tplFile: string; tplId: Cardinal);
var
  npc: IInterface;
begin
  npc := VanRec(fileName, objectId);
  SetElementNativeValues(npc, 'ACBS\Template Flags', flags);
  SetEditValue(Add(npc, 'TPLT', True), VanId(tplFile, tplId));
end;

procedure VanNpc(const fileName: string; objectId: Cardinal; const edid: string; level: Integer; withPerk: Boolean);
var
  npc, kw, perks: IInterface;
begin
  npc := Van(fileName, objectId, 'NPC_', edid);
  SetElementNativeValues(npc, 'ACBS\Level', level);
  SetElementNativeValues(npc, 'ACBS\Health Offset', 10);
  SetEditValue(ElementBySignature(npc, 'RNAM'), VanId('Skyrim.esm', $0131F5));
  kw := Add(npc, 'KWDA', True);
  SetEditValue(Add(kw, 'Keyword', True), VanId('Skyrim.esm', $013797));
  SetNativeValue(Add(npc, 'KSIZ', True), 1);
  if withPerk then begin
    perks := Add(npc, 'Perks', True);
    SetElementEditValues(ElementByIndex(perks, 0), 'Perk', VanId('Skyrim.esm', $1046BD));
    SetNativeValue(Add(npc, 'PRKZ', True), 1);
  end;
end;

procedure VanSpell(const fileName: string; objectId: Cardinal; const edid: string; const npcFile: string; npcId: Cardinal);
var
  spell, mgef, data: IInterface;
begin
  Inc(NextObjectId);
  mgef := Van('Skyrim.esm', $0F0000 + NextObjectId, 'MGEF', 'Summon' + edid);
  data := ElementBySignature(Add(mgef, 'DATA', True), 'DATA');
  SetElementEditValues(data, 'Archtype', 'Summon Creature');
  SetElementEditValues(data, 'Assoc. Item', VanId(npcFile, npcId));
  spell := Van(fileName, objectId, 'SPEL', edid);
  SetEditValue(ElementBySignature(ElementByIndex(ElementByName(spell, 'Effects'), 0), 'EFID'),
    HexId(GetLoadOrderFormID(mgef)));
end;

procedure VanWeapon(const fileName: string; objectId: Cardinal; const edid: string; withKeyword: Boolean);
var
  w: IInterface;
begin
  w := Van(fileName, objectId, 'WEAP', edid);
  if withKeyword then begin
    SetEditValue(Add(Add(w, 'KWDA', True), 'Keyword', True), VanId('Skyrim.esm', $01E711));
    SetNativeValue(Add(w, 'KSIZ', True), 1);
  end;
end;

procedure BuildVanilla;
var
  p, e: IInterface;
begin
  NewFile('Skyrim.esm', []);
  NewFile('Update.esm', ['Skyrim.esm']);
  NewFile('Dawnguard.esm', ['Skyrim.esm', 'Update.esm']);
  NewFile('Dragonborn.esm', ['Skyrim.esm', 'Update.esm']);

  Van('Skyrim.esm', $000014, 'ACHR', 'PlayerRef');
  SetElementNativeValues(Van('Skyrim.esm', $0131F5, 'RACE', 'AtronachFlameRace'), 'DATA\Starting Health', 100);
  Van('Skyrim.esm', $01CEAD, 'KYWD', 'MagicDamageFire');
  Van('Skyrim.esm', $01CEAE, 'KYWD', 'MagicDamageFrost');
  Van('Skyrim.esm', $01CEAF, 'KYWD', 'MagicDamageShock');
  Van('Skyrim.esm', $101BDE, 'KYWD', 'MagicVampireDrain');
  Van('Skyrim.esm', $013797, 'KYWD', 'ActorTypeDaedra');
  Van('Skyrim.esm', $01E711, 'KYWD', 'WeapTypeSword');
  Van('Skyrim.esm', $0965B2, 'KYWD', 'ArmorShield');
  Van('Skyrim.esm', $0C44C2, 'PERK', 'DestructionMaster100');
  Van('Skyrim.esm', $0C44BE, 'PERK', 'ConjurationMaster100');
  Van('Skyrim.esm', $10FCF8, 'PERK', 'AugmentedFlames60');

  // Условия ванильных перков — как в журнале настоящей сборки в SSEEdit 4.1.5f.
  p := Van('Skyrim.esm', $0581E7, 'PERK', 'AugmentedFlames');
  e := VanPerkEntry(p, 'Mod Spell Magnitude', 3);
  VanCond(e, 0, 'HasPerk', VanId('Skyrim.esm', $10FCF8), 0, 0);
  VanCond(e, 1, 'EPMagic_SpellHasKeyword', VanId('Skyrim.esm', $01CEAD), 1, 0);
  p := Van('Skyrim.esm', $0BABE4, 'PERK', 'Armsman00');
  e := VanPerkEntry(p, 'Mod Attack Damage', 3);
  VanCond(e, 1, 'HasKeyword', VanId('Skyrim.esm', $01E711), 1, 1);
  p := Van('Skyrim.esm', $1046BD, 'PERK', 'crDragonResistNPCs');
  VanPerkEntry(p, 'Mod Incoming Damage', 3);
  Van('Skyrim.esm', $109639, 'PERK', 'DragonhideSpellPerk');
  p := Van('Skyrim.esm', $058F69, 'PERK', 'ElementalProtection');
  e := VanPerkEntry(p, 'Mod Incoming Spell Magnitude', 2);
  VanCond(e, 0, 'WornHasKeyword', VanId('Skyrim.esm', $0965B2), 1, 0);
  VanCond(e, 0, 'IsBlocking', '', 1, 0);
  VanCond(e, 1, 'HasKeyword', VanId('Skyrim.esm', $01CEAD), 1, 1);
  VanCond(e, 1, 'HasKeyword', VanId('Skyrim.esm', $01CEAE), 1, 1);
  VanCond(e, 1, 'HasKeyword', VanId('Skyrim.esm', $01CEAF), 1, 1);
  p := Van('Skyrim.esm', $0F2CA8, 'PERK', 'DestructionNovice00');
  e := VanPerkEntry(p, 'Mod Spell Cost', 2);
  VanCond(e, 1, 'EPMagic_SpellHasSkill', 'Destruction', 1, 0);

  VanWeapon('Skyrim.esm', $058F5F, 'BoundWeaponSword', True);
  VanWeapon('Skyrim.esm', $0424F9, 'BoundWeaponSwordMystic', True);
  VanWeapon('Skyrim.esm', $0BA30E, 'BoundWeaponSwordRightHand', True);
  VanWeapon('Skyrim.esm', $058F5E, 'BoundWeaponBattleaxe', True);
  VanWeapon('Skyrim.esm', $0424F7, 'BoundWeaponBattleaxeMystic', True);
  VanWeapon('Skyrim.esm', $058F60, 'BoundWeaponBow', True);
  VanWeapon('Skyrim.esm', $0424F8, 'BoundWeaponBowMystic', True);
  VanWeapon('Dragonborn.esm', $01CE02, 'DLC2BoundWeaponDagger', True);
  VanWeapon('Dragonborn.esm', $01CE03, 'DLC2BoundWeaponDaggerMystic', False);

  // Общие шаблоны, из которых призывы берут список заклинаний (как в журнале).
  VanNpc('Skyrim.esm', $023AA6, 'EncAtronachFlame', 5, False);
  VanNpc('Skyrim.esm', $023AA7, 'EncAtronachFrost', 16, False);
  VanNpc('Skyrim.esm', $016FF8, 'EncDremoraMelee06', 46, True);

  VanNpc('Skyrim.esm', $0640B5, 'EncSummonFamiliar', 2, False);
  VanNpc('Skyrim.esm', $0204C0, 'SummonAtronachFlame', 5, False);
  VanNpc('Skyrim.esm', $04E940, 'SummonAtronachFlamePotent', 10, False);
  VanNpc('Skyrim.esm', $0204C1, 'SummonAtronachFrost', 16, False);
  VanNpc('Skyrim.esm', $04E943, 'SummonAtronachFrostPotent', 24, False);
  VanNpc('Skyrim.esm', $0204C2, 'SummonAtronachStorm', 30, False);
  VanNpc('Skyrim.esm', $04E944, 'SummonAtronachStormPotent', 35, False);
  VanNpc('Skyrim.esm', $07E87D, 'SummonAtronachFlameThrall', 30, False);
  VanNpc('Skyrim.esm', $0CDECC, 'SummonAtronachFlameThrallPotent', 35, False);
  VanNpc('Skyrim.esm', $07E87E, 'SummonAtronachFrostThrall', 30, False);
  VanNpc('Skyrim.esm', $0CDECD, 'SummonAtronachFrostThrallPotent', 35, False);
  VanNpc('Skyrim.esm', $07E87F, 'SummonAtronachStormThrall', 30, False);
  VanNpc('Skyrim.esm', $0CDECE, 'SummonAtronachStormThrallPotent', 35, False);
  VanNpc('Skyrim.esm', $10DDEE, 'SummonEncDremoraLord', 1, False);
  VanNpc('Dawnguard.esm', $0045B9, 'DLC1SoulCairnBonemanSummon', 6, False);
  VanNpc('Dawnguard.esm', $0045B7, 'DLC1SoulCairnMistmanSummon', 13, False);
  VanNpc('Dawnguard.esm', $0045B4, 'DLC1SoulCairnWrathmanSummon', 30, False);
  VanNpc('Dawnguard.esm', $016907, 'DLC1EncGargoyleSummon', 13, False);
  VanNpc('Dragonborn.esm', $01EEC9, 'DLC2SummonSeeker', 21, False);
  VanNpc('Dragonborn.esm', $030CDE, 'DLC2SummonSeekerHigh', 42, False);
  VanNpc('Dragonborn.esm', $01CDF8, 'DLC2SummonAshSpawn01', 20, False);
  VanNpc('Dragonborn.esm', $0177B6, 'DLC2SummonAshGuardian', 30, False);
  VanTemplate('Skyrim.esm', $0204C0, 8, 'Skyrim.esm', $023AA6);            // Use Spell List
  VanTemplate('Skyrim.esm', $04E940, 8, 'Skyrim.esm', $023AA6);
  VanTemplate('Skyrim.esm', $04E943, 8, 'Skyrim.esm', $023AA7);
  VanTemplate('Skyrim.esm', $07E87D, 4096, 'Skyrim.esm', $023AA6);         // Use Keywords
  VanTemplate('Skyrim.esm', $10DDEE, 8 + 2 + 4096, 'Skyrim.esm', $016FF8);  // + Use Stats
  VanTemplate('Dragonborn.esm', $030CDE, 8, 'Dragonborn.esm', $01EEC9);

  VanSpell('Skyrim.esm', $0640B6, 'ConjureFamiliar', 'Skyrim.esm', $0640B5);
  VanSpell('Skyrim.esm', $0204C3, 'ConjureFlameAtronach', 'Skyrim.esm', $0204C0);
  VanSpell('Skyrim.esm', $0204C4, 'ConjureFrostAtronach', 'Skyrim.esm', $0204C1);
  VanSpell('Skyrim.esm', $0204C5, 'ConjureStormAtronach', 'Skyrim.esm', $0204C2);
  VanSpell('Skyrim.esm', $10DDEC, 'ConjureDremoraLord', 'Skyrim.esm', $10DDEE);
  VanSpell('Skyrim.esm', $07E5D5, 'FlameThrall', 'Skyrim.esm', $07E87D);
  VanSpell('Skyrim.esm', $07E5D6, 'FrostThrall', 'Skyrim.esm', $07E87E);
  VanSpell('Skyrim.esm', $07E5D7, 'StormThrall', 'Skyrim.esm', $07E87F);
  VanSpell('Dawnguard.esm', $0045BA, 'DLC1ConjureBoneman', 'Dawnguard.esm', $0045B9);
  VanSpell('Dawnguard.esm', $0045B8, 'DLC1ConjureMistman', 'Dawnguard.esm', $0045B7);
  VanSpell('Dawnguard.esm', $0045B3, 'DLC1ConjureWrathman', 'Dawnguard.esm', $0045B4);
  VanSpell('Dragonborn.esm', $033C66, 'DLC2ConjureSeeker', 'Dragonborn.esm', $030CDE);
  VanSpell('Dragonborn.esm', $01CDF6, 'DLC2ConjureAshSpawn', 'Dragonborn.esm', $01CDF8);
end;

//============================================================================
// Проверка результата
//============================================================================

var
  Failures: Integer = 0;
  Plugin: TNode;

procedure Check(ok: Boolean; const what: string);
begin
  if ok then
    WriteLn('ok   ', what)
  else begin
    WriteLn('FAIL ', what);
    Inc(Failures);
  end;
end;

function RecByEdid(const sig, edid: string): TNode;
var
  g: TNode;
  k: Integer;
begin
  Result := nil;
  g := GroupOf(Plugin, sig, False);
  if Assigned(g) then
    for k := 0 to g.Kids.Count - 1 do
      if g.Kid(k).Edid = edid then
        Exit(g.Kid(k));
end;

function Nat(n: TNode; const path: string): Variant;
begin
  Result := NodeNative(NodeByPath(n, path));
  if VarIsEmpty(Result) or VarIsNull(Result) then
    Result := -999999;
end;

function Edit(n: TNode; const path: string): string;
begin
  Result := NodeEdit(NodeByPath(n, path));
end;

function Near(v: Variant; x: Double): Boolean;
begin
  Result := Abs(Double(v) - x) < 1e-6;
end;

function Kids(n: TNode; const aName: string): Integer;
var
  a: TNode;
begin
  Result := 0;
  a := KidByName(n, aName);
  if Assigned(a) then
    Result := a.Kids.Count;
end;

function Entry(perk: TNode; i: Integer): TNode;
begin
  Result := KidByName(perk, 'Effects').Kid(i);
end;

function TabNode(entry: TNode; tab: Integer): TNode;
var
  pcs: TNode;
  k: Integer;
begin
  Result := nil;
  pcs := KidByName(entry, 'Perk Conditions');
  if Assigned(pcs) then
    for k := 0 to pcs.Kids.Count - 1 do
      if Nat(pcs.Kid(k), 'PRKC') = tab then
        Exit(pcs.Kid(k));
end;

function FirstWord(const s: string): string;
begin
  Result := Copy(s, 1, Pos(' ', s + ' ') - 1);
end;

// Условия элемента (вкладки перка или эффекта): "Функция(параметр) тип значение [@ссылка]".
function CondList(holder: TNode): string;
var
  conds, ctda: TNode;
  k: Integer;
  p: string;
begin
  Result := '-';
  if not Assigned(holder) then
    Exit;
  conds := KidByName(holder, 'Conditions');
  Result := '';
  if not Assigned(conds) then
    Exit;
  for k := 0 to conds.Kids.Count - 1 do begin
    ctda := KidBySig(conds.Kid(k), 'CTDA');
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + Edit(ctda, 'Function');
    p := Edit(ctda, 'Parameter #1');
    if (p <> '') and (p <> '00 00 00 00') then
      Result := Result + '(' + FirstWord(p) + ')';
    Result := Result + ' ' + VarToStr(Nat(ctda, 'Type')) + ' ' + FloatToStr(Double(Nat(ctda, 'Comparison Value')));
    if Nat(ctda, 'Run On') = 2 then
      Result := Result + ' @' + FirstWord(Edit(ctda, 'Reference'));
  end;
end;

function TabConds(entry: TNode; tab: Integer): string;
begin
  Result := CondList(TabNode(entry, tab));
end;

function EntryOk(entry: TNode; const ep: string; tabs: Integer; value: Double): Boolean;
begin
  Result := (Edit(entry, 'DATA\Entry Point\Entry Point') = ep)
    and (Edit(entry, 'DATA\Entry Point\Function') = 'Multiply Value')
    and (Nat(entry, 'DATA\Entry Point\Perk Condition Tab Count') = tabs)
    and (Nat(entry, 'Function Parameters\EPFT') = 1)
    and Near(Nat(entry, 'Function Parameters\EPFD\Float'), value);
end;

function NoEmptyTabs(perk: TNode): Boolean;
var
  i, k: Integer;
  pcs: TNode;
begin
  Result := True;
  for i := 0 to Kids(perk, 'Effects') - 1 do begin
    pcs := KidByName(Entry(perk, i), 'Perk Conditions');
    if not Assigned(pcs) then
      Exit(False);
    for k := 0 to pcs.Kids.Count - 1 do
      if Pos('GetWantBlocking', CondList(pcs.Kid(k))) > 0 then
        Exit(False);
  end;
end;

function HasLink(arr: TNode; const field, edid: string): Boolean;
var
  k: Integer;
  el: TNode;
begin
  Result := False;
  if not Assigned(arr) then
    Exit;
  for k := 0 to arr.Kids.Count - 1 do begin
    el := arr.Kid(k);
    if field <> '' then
      el := KidByName(el, field);
    if FirstWord(NodeEdit(el)) = edid then
      Exit(True);
  end;
end;

const
  Elemental = 'EPMagic_SpellHasKeyword(MagicDamageFire) 1 1, EPMagic_SpellHasKeyword(MagicDamageFrost) 1 1, '
    + 'EPMagic_SpellHasKeyword(MagicDamageShock) 1 1, EPMagic_SpellHasKeyword(MagicVampireDrain) 0 1';
  IncomingElemental = 'HasKeyword(MagicDamageFire) 1 1, HasKeyword(MagicDamageFrost) 1 1, '
    + 'HasKeyword(MagicDamageShock) 1 1, HasKeyword(MagicVampireDrain) 0 1';
  Weapons: array[0..8] of string = ('BoundWeaponSword', 'BoundWeaponSwordMystic', 'BoundWeaponSwordRightHand',
    'BoundWeaponBattleaxe', 'BoundWeaponBattleaxeMystic', 'BoundWeaponBow', 'BoundWeaponBowMystic',
    'DLC2BoundWeaponDagger', 'DLC2BoundWeaponDaggerMystic');
  Endgame: array[0..6] of string = ('SummonAtronachFlameThrall', 'SummonAtronachFlameThrallPotent',
    'SummonAtronachFrostThrall', 'SummonAtronachFrostThrallPotent', 'SummonAtronachStormThrall',
    'SummonAtronachStormThrallPotent', 'SummonEncDremoraLord');
  Summons: array[0..21] of string = ('EncSummonFamiliar', 'SummonAtronachFlame', 'SummonAtronachFlamePotent',
    'SummonAtronachFrost', 'SummonAtronachFrostPotent', 'SummonAtronachStorm', 'SummonAtronachStormPotent',
    'SummonAtronachFlameThrall', 'SummonAtronachFlameThrallPotent', 'SummonAtronachFrostThrall',
    'SummonAtronachFrostThrallPotent', 'SummonAtronachStormThrall', 'SummonAtronachStormThrallPotent',
    'SummonEncDremoraLord', 'DLC1SoulCairnBonemanSummon', 'DLC1SoulCairnMistmanSummon',
    'DLC1SoulCairnWrathmanSummon', 'DLC1EncGargoyleSummon', 'DLC2SummonSeeker', 'DLC2SummonSeekerHigh',
    'DLC2SummonAshSpawn01', 'DLC2SummonAshGuardian');

function VanByEdid(const edid: string): TNode;
var
  k: Integer;
begin
  Result := nil;
  for k := 0 to Registry.Count - 1 do
    if TNode(Registry.Objects[k]).Edid = edid then
      Exit(TNode(Registry.Objects[k]));
end;

function LogHas(const text: string): Boolean;
var
  k: Integer;
begin
  Result := False;
  for k := 0 to Messages.Count - 1 do
    if Pos(text, Messages[k]) > 0 then
      Exit(True);
end;

procedure VerifyGenerated;
var
  perk, sperk, e, mgef, data, spell, eff, quest, alias, npc, src, spells, kw: TNode;
  k, i: Integer;
  allOk: Boolean;
  s: string;
begin
  WriteLn;
  WriteLn('--- checks ---');

  Plugin := FindFile('FHS_MagicScaling.esp');
  Check(Assigned(Plugin), 'plugin created');
  if not Assigned(Plugin) then
    Halt(1);
  Check(MessagesErrors = 0, 'no ERROR lines in the log');
  Check(MessagesWarnings = 0, 'no WARNING lines in the log');
  Check(Plugin.Masters.Count = 4, 'four masters');

  Check(Assigned(RecByEdid('KYWD', 'FHS_BoundWeapon')) and not Assigned(RecByEdid('KYWD', 'FHS_SummonEndgame')),
    'keyword FHS_BoundWeapon, no endgame keyword');
  allOk := True;
  for i := 0 to High(Weapons) do begin
    npc := NodeOf(WinningOverride(IntfOf(VanByEdid(Weapons[i]))));
    kw := KidBySig(npc, 'KWDA');
    if (FileOf(npc) <> Plugin) or not HasLink(kw, '', 'FHS_BoundWeapon') or (Nat(npc, 'KSIZ') <> kw.Kids.Count) then begin
      allOk := False;
      WriteLn('     not marked: ', Weapons[i]);
    end;
  end;
  Check(allOk, 'all 9 bound weapons carry FHS_BoundWeapon, KSIZ matches');
  e := RecByEdid('FLST', 'FHS_EndgameSummons');
  allOk := Assigned(e) and (Kids(e, 'FormIDs') = 7);
  if allOk then
    for k := 0 to 6 do
      if FirstWord(NodeEdit(KidByName(e, 'FormIDs').Kid(k))) <> Endgame[k] then
        allOk := False;
  Check(allOk, 'endgame list: the 6 thralls and the Dremora Lord records themselves');

  // Перк игрока: D1 (11) + D2 (1) + C3 (11) + C4 (11)
  perk := RecByEdid('PERK', 'FHS_Attunement');
  Check(Assigned(perk) and (Kids(perk, 'Effects') = 34), 'player perk has 34 entries');
  Check((Nat(perk, 'DATA\Hidden') = 1) and (Nat(perk, 'DATA\Playable') = 0) and (Nat(perk, 'DATA\Num Ranks') = 1),
    'player perk is hidden, not playable, 1 rank');
  Check(NoEmptyTabs(perk), 'player perk: every entry has condition tabs, none left empty');
  e := Entry(perk, 0);
  Check(EntryOk(e, 'Mod Spell Magnitude', 3, 1.18), 'D1: Mod Spell Magnitude, 3 tabs, Multiply 1.18 in EPFD\Float');
  Check(TabConds(e, 0) = 'GetLevel 96 30, GetLevel 128 35', 'D1 level band: >= 30 and < 35 [' + TabConds(e, 0) + ']');
  s := 'EPMagic_SpellHasSkill(Destruction) 0 1, ' + Elemental;
  Check(TabConds(e, 1) = s, 'D1 spell tab: skill AND (fire OR frost OR shock OR drain)');
  if TabConds(e, 1) <> s then
    WriteLn('     got: ', TabConds(e, 1));
  e := Entry(perk, 10);
  Check(EntryOk(e, 'Mod Spell Magnitude', 3, 2.96) and (TabConds(e, 0) = 'GetLevel 96 80'), 'D1 last band: only >= 80, 2.96');
  e := Entry(perk, 11);
  Check(EntryOk(e, 'Mod Spell Magnitude', 3, 1.2)
    and (TabConds(e, 0) = 'HasPerk(DestructionMaster100) 0 1, GetBaseActorValue(Destruction) 96 100'),
    'D2 absolute destruction [' + TabConds(e, 0) + ']');
  e := Entry(perk, 12);
  Check(EntryOk(e, 'Mod Spell Magnitude', 3, 1.18) and (TabConds(e, 1) = 'EPMagic_SpellHasSkill(Conjuration) 0 1'),
    'C3 conjuration level limits');
  e := Entry(perk, 23);
  Check(EntryOk(e, 'Mod Attack Damage', 3, 1.06) and (TabConds(e, 1) = 'HasKeyword(FHS_BoundWeapon) 0 1'),
    'C4 bound weapons: HasKeyword on the Weapon tab, like vanilla Armsman');

  // Перк призывов: 15 рубежей x 4 точки входа + 4 записи C2
  sperk := RecByEdid('PERK', 'FHS_SummonAttunement');
  Check(Assigned(sperk) and (Kids(sperk, 'Effects') = 64), 'summon perk has 64 entries');
  Check(NoEmptyTabs(sperk), 'summon perk: no empty condition tabs');
  allOk := True;
  for k := 0 to 59 do begin
    s := TabConds(Entry(sperk, k), 0);
    if (Pos('GetLevel 96 ', s) <> 1) or (Pos(' @PlayerRef, GetLevel 128 ', s) = 0) or (Pos(', GetLevel 97 ', s) = 0)
       or (Pos('IsInList(FHS_EndgameSummons) 0 1, IsCommandedActor 0 1, IsHostileToActor(PlayerRef) 0 0', s) = 0) then
      allOk := False;
  end;
  Check(allOk, 'every milestone: player>=P AND own<P AND (own>=P/2 OR endgame) AND commanded AND not hostile');
  WriteLn('     first milestone: ', TabConds(Entry(sperk, 0), 0));
  Check(EntryOk(Entry(sperk, 0), 'Mod Attack Damage', 3, 1.625), 'first milestone: attack x1.625');
  Check(EntryOk(Entry(sperk, 1), 'Mod Spell Magnitude', 3, 1.625), 'first milestone: spells x1.625');
  Check(EntryOk(Entry(sperk, 2), 'Mod Incoming Damage', 3, 0.615), 'first milestone: incoming damage x0.615');
  e := Entry(sperk, 3);
  Check(EntryOk(e, 'Mod Incoming Spell Magnitude', 2, 0.615) and (TabConds(e, 1) = IncomingElemental),
    'first milestone: incoming elemental spells x0.615, HasKeyword on the Spell tab like vanilla Block');
  if TabConds(e, 1) <> IncomingElemental then
    WriteLn('     got: ', TabConds(e, 1));
  e := Entry(sperk, 60);
  Check(EntryOk(e, 'Mod Attack Damage', 3, 1.2)
    and (TabConds(e, 0) = 'HasPerk(ConjurationMaster100) 0 1 @PlayerRef, GetBaseActorValue(Conjuration) 96 100 @PlayerRef, '
      + 'IsCommandedActor 0 1, IsHostileToActor(PlayerRef) 0 0'), 'C2 absolute conjuration');

  // Магические эффекты
  mgef := RecByEdid('MGEF', 'FHS_AttunementCarrier');
  data := NodeByPath(mgef, 'Magic Effect Data\DATA');
  Check(Assigned(data), 'MGEF DATA is inside Magic Effect Data');
  Check((Edit(data, 'Archtype') = 'Value Modifier') and (Edit(data, 'Actor Value') = 'Health')
    and (Nat(data, 'Flags') = 32768 + 1024 + 2048 + 512) and (Edit(data, 'Casting Type') = 'Constant Effect')
    and (Edit(data, 'Delivery') = 'Self') and (Nat(data, 'Magic Skill') = -1),
    'carrier: Value Modifier / Health, hidden, constant self');
  Check(NodeOf(LinksTo(IntfOf(KidByName(data, 'Perk to Apply')))) = perk, 'carrier applies FHS_Attunement');
  mgef := RecByEdid('MGEF', 'FHS_DisplayResonance');
  data := NodeByPath(mgef, 'Magic Effect Data\DATA');
  Check((Edit(data, 'Archtype') = 'Script') and (Nat(data, 'Actor Value') = -1)
    and (Pos('<mag>', Edit(mgef, 'DNAM')) > 0), 'display effect: Script archetype, description with <mag>');

  // Способность
  spell := RecByEdid('SPEL', 'FHS_AttunementAbility');
  Check(Assigned(spell) and (Kids(spell, 'Effects') = 14), 'ability: carrier + 11 bands + 2 mastery lines');
  Check((Edit(spell, 'SPIT\Type') = 'Ability') and (Edit(spell, 'SPIT\Cast Type') = 'Constant Effect')
    and (Edit(spell, 'SPIT\Target Type') = 'Self') and (Nat(spell, 'SPIT\Flags') = 1), 'ability: constant self, manual cost');
  eff := KidByName(spell, 'Effects').Kid(0);
  Check((FirstWord(Edit(eff, 'EFID')) = 'FHS_AttunementCarrier') and not Assigned(KidByName(eff, 'Conditions')),
    'ability effect 1: carrier without conditions');
  eff := KidByName(spell, 'Effects').Kid(1);
  Check((FirstWord(Edit(eff, 'EFID')) = 'FHS_DisplayResonance') and Near(Nat(eff, 'EFIT\Magnitude'), 18)
    and (CondList(eff) = 'GetLevel 96 30, GetLevel 128 35'), 'ability effect 2: +18% line for levels 30-34');
  eff := KidByName(spell, 'Effects').Kid(13);
  Check((FirstWord(Edit(eff, 'EFID')) = 'FHS_DisplayAbsoluteConjuration')
    and (CondList(eff) = 'HasPerk(ConjurationMaster100) 0 1, GetBaseActorValue(Conjuration) 96 100'),
    'ability effect 14: absolute conjuration line');

  // Квест
  quest := RecByEdid('QUST', 'FHS_CoreQuest');
  Check(Assigned(quest) and (Nat(quest, 'DNAM\Flags') = 1) and (Nat(quest, 'ANAM') = 1), 'quest: Start Game Enabled, next alias 1');
  alias := KidByName(quest, 'Aliases').Kid(0);
  Check((Nat(alias, 'ALST') = 0) and (Edit(alias, 'ALID') = 'Player') and (Nat(alias, 'FNAM\Flags') = 0)
    and Assigned(KidBySig(alias, 'ALED')), 'alias: Reference Alias "Player"');
  Check(FirstWord(Edit(alias, 'ALFR')) = 'PlayerRef', 'alias filled with PlayerRef');
  spells := KidByName(alias, 'Alias Spells');
  Check(Assigned(spells) and (spells.Kids.Count = 1) and (NodeOf(LinksTo(IntfOf(spells.Kid(0)))) = spell),
    'alias gives the ability');

  // Призывы
  allOk := True;
  for i := 0 to High(Summons) do begin
    src := VanByEdid(Summons[i]);
    if (Integer(Nat(src, 'ACBS\Template Flags')) and 8) <> 0 then
      src := NodeOf(LinksTo(IntfOf(KidBySig(src, 'TPLT'))));
    npc := NodeOf(WinningOverride(IntfOf(src)));
    if (FileOf(npc) <> Plugin) or not HasLink(KidByName(npc, 'Perks'), 'Perk', 'FHS_SummonAttunement')
       or (Nat(npc, 'PRKZ') <> Kids(npc, 'Perks')) then begin
      allOk := False;
      WriteLn('     not patched: ', Summons[i]);
    end;
    if Assigned(KidBySig(npc, 'KWDA')) and (KidBySig(npc, 'KWDA').Kids.Count <> 1) then begin
      allOk := False;
      WriteLn('     keywords changed: ', Summons[i]);
    end;
  end;
  Check(allOk, 'all 22 summons (or their spell-list templates) carry the summon perk, PRKZ matches, keywords untouched');
  npc := NodeOf(WinningOverride(IntfOf(VanByEdid('EncDremoraMelee06'))));
  Check(Kids(npc, 'Perks') = 2, 'Dremora Lord template keeps its own perk and gets ours');
  npc := NodeOf(WinningOverride(IntfOf(VanByEdid('EncAtronachFlame'))));
  Check(Kids(npc, 'Perks') = 1, 'shared template EncAtronachFlame gets the perk once');
  Check(LogHas('summon patched: SummonEncDremoraLord (level 46, health 100.000000 + 10, stats from EncDremoraMelee06)'),
    'log shows effective level and health from the stats template');
  Check(LogHas('bound weapons marked: 9'), 'log: bound weapons marked: 9');
  Check(LogHas('vanilla DestructionNovice00 / Mod Spell Cost'), 'log: DestructionNovice00 dump');

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL CHECKS PASSED')
  else begin
    WriteLn(Failures, ' CHECK(S) FAILED');
    Halt(1);
  end;
end;

initialization
  AllDefs := TList.Create;
  RecordDefs := TStringList.Create;
  Files := TInterfaceList.Create;
  Registry := TStringList.Create;
  Messages := TStringList.Create;
  BuildDefs;
  BuildVanilla;
end.
