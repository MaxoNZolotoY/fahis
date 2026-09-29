{ Упрощённая модель скриптового API xEdit для прогона генератора без игры.

  Элементы плагина хранятся деревом узлов в памяти. Модель повторяет только
  то, на что опирается генератор: Add находит или создаёт дочерний элемент,
  ElementAssign добавляет элемент массива, пути разбираются по "\",
  подзаписи называются "SIG - Name". Ванильные записи создаются по запросу
  пустыми, поэтому проверка шаблонов перков (DetectTabs) идёт по запасной
  ветке, а сверка EditorID даёт предупреждения — это ожидаемо.

  VerifyGenerated проверяет итоговую структуру плагина: число записей перков,
  условия и их OR-флаги, значения множителей, эффекты способности, квест
  и правки призывов. }
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
  TNodeKind = (nkFile, nkGroup, nkRecord, nkElement);

  INode = interface
    ['{6F0B7C0A-2B4E-4F4B-9C62-6E1C3C9E7A11}']
    function Node: TObject;
  end;

  TNode = class(TInterfacedObject, INode)
  public
    Kind: TNodeKind;
    DefName: string;
    Sig: string;
    Value: Variant;
    Edid: string;
    FormId: Cardinal;
    Parent: TNode;
    Kids: TInterfaceList;
    constructor Create(aParent: TNode; aKind: TNodeKind; const aName: string);
    destructor Destroy; override;
    function Node: TObject;
    function Kid(i: Integer): TNode;
  end;

var
  Files: TInterfaceList;
  Registry: TStringList;       // FormID в hex -> запись (последняя версия)
  NextFormId: Cardinal = $00800;
  MessagesErrors: Integer = 0;
  Messages: TStringList;

function IsSig(const s: string): Boolean;
var
  c: Char;
begin
  Result := Length(s) = 4;
  if Result then
    for c in s do
      if not CharInSet(c, ['A'..'Z', '0'..'9', '_']) then
        Exit(False);
end;

constructor TNode.Create(aParent: TNode; aKind: TNodeKind; const aName: string);
begin
  inherited Create;
  Kind := aKind;
  DefName := aName;
  if (aKind = nkElement) and IsSig(aName) then
    Sig := aName;
  Parent := aParent;
  Kids := TInterfaceList.Create;
  Value := Unassigned;
  if Assigned(aParent) then
    aParent.Kids.Add(Self as IInterface);
end;

destructor TNode.Destroy;
begin
  Kids.Free;
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

function HexId(id: Cardinal): string;
begin
  Result := IntToHex(id, 8);
end;

procedure RegisterRecord(n: TNode);
var
  idx: Integer;
begin
  idx := Registry.IndexOf(HexId(n.FormId));
  if idx >= 0 then
    Registry.Objects[idx] := n
  else
    Registry.AddObject(HexId(n.FormId), n);
end;

function NewRecordNode(group: TNode; const sig: string; id: Cardinal): TNode;
begin
  Result := TNode.Create(group, nkRecord, sig);
  Result.Sig := sig;
  Result.FormId := id;
  RegisterRecord(Result);
end;

function ChildNamed(n: TNode; const s: string): TNode; forward;

{ API }

procedure AddMessage(const s: string);
begin
  Messages.Add(s);
  if Pos('ERROR', s) > 0 then
    Inc(MessagesErrors);
end;

function FindFile(const s: string): TNode;
var
  k: Integer;
  f: TNode;
begin
  Result := nil;
  for k := 0 to Files.Count - 1 do begin
    f := TNode((Files[k] as INode).Node);
    if SameText(f.DefName, s) then
      Exit(f);
  end;
end;

function FileByName(const s: string): IInterface;
begin
  Result := IntfOf(FindFile(s));
end;

function AddNewFileName(const s: string; aLight: Boolean): IInterface;
var
  f: TNode;
begin
  f := TNode.Create(nil, nkFile, s);
  Files.Add(f as IInterface);
  Result := IntfOf(f);
end;

function AddMasterIfMissing(f: IInterface; const s: string): Variant;
var
  n: TNode;
begin
  n := NodeOf(f);
  if n.Value = Unassigned then
    n.Value := s
  else if Pos(s, VarToStr(n.Value)) = 0 then
    n.Value := VarToStr(n.Value) + ';' + s;
  Result := Null;
end;

function SortMasters(f: IInterface): Variant;
begin
  Result := Null;
end;

function MasterCount(f: IInterface): Integer;
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  try
    sl.Delimiter := ';';
    sl.StrictDelimiter := True;
    sl.DelimitedText := VarToStr(NodeOf(f).Value);
    Result := sl.Count;
  finally
    sl.Free;
  end;
end;

function MasterByIndex(f: IInterface; i: Integer): IInterface;
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  try
    sl.Delimiter := ';';
    sl.StrictDelimiter := True;
    sl.DelimitedText := VarToStr(NodeOf(f).Value);
    Result := FileByName(sl[i]);
  finally
    sl.Free;
  end;
end;

function RecordCount(f: IInterface): Integer;
var
  g, k: Integer;
  n: TNode;
begin
  Result := 0;
  n := NodeOf(f);
  for g := 0 to n.Kids.Count - 1 do
    for k := 0 to n.Kid(g).Kids.Count - 1 do
      Inc(Result);
end;

function GetFileName(f: IInterface): string;
begin
  if Assigned(NodeOf(f)) then
    Result := NodeOf(f).DefName
  else
    Result := '';
end;

function GetFile(e: IInterface): IInterface;
var
  n: TNode;
begin
  n := NodeOf(e);
  while Assigned(n) and (n.Kind <> nkFile) do
    n := n.Parent;
  Result := IntfOf(n);
end;

function GroupBySignature(f: IInterface; const s: string): IInterface;
var
  k: Integer;
  n: TNode;
begin
  Result := nil;
  n := NodeOf(f);
  for k := 0 to n.Kids.Count - 1 do
    if n.Kid(k).DefName = s then
      Exit(IntfOf(n.Kid(k)));
end;

function FileFormIDtoLoadOrderFormID(f: IInterface; formId: Integer): Integer;
begin
  // В модели индекс файла в порядке загрузки равен его номеру в списке файлов.
  Result := (Files.IndexOf(f) shl 24) or (formId and $FFFFFF);
end;

function RecordByFormID(f: IInterface; formId: Integer; allowInjected: Boolean): IInterface;
var
  fn, g: TNode;
  k: Integer;
begin
  fn := NodeOf(f);
  g := ChildNamed(fn, 'VANILLA');
  if not Assigned(g) then
    g := TNode.Create(fn, nkGroup, 'VANILLA');
  for k := 0 to g.Kids.Count - 1 do
    if g.Kid(k).FormId = Cardinal(formId) then
      Exit(IntfOf(g.Kid(k)));
  Result := IntfOf(NewRecordNode(g, 'NPC_', Cardinal(formId)));
end;

function EditorID(e: IInterface): string;
begin
  if Assigned(NodeOf(e)) then
    Result := NodeOf(e).Edid
  else
    Result := '';
end;

function SetEditorID(e: IInterface; const s: string): Variant;
begin
  NodeOf(e).Edid := s;
  Result := Null;
end;

function Signature(e: IInterface): string;
begin
  Result := NodeOf(e).Sig;
end;

function MasterOrSelf(e: IInterface): IInterface;
begin
  Result := e;
end;

function OverrideCount(e: IInterface): Integer;
begin
  Result := 0;
end;

function OverrideByIndex(e: IInterface; i: Integer): IInterface;
begin
  Result := nil;
end;

function WinningOverride(e: IInterface): IInterface;
var
  idx: Integer;
begin
  Result := e;
  if not Assigned(NodeOf(e)) then
    Exit;
  idx := Registry.IndexOf(HexId(NodeOf(e).FormId));
  if idx >= 0 then
    Result := IntfOf(TNode(Registry.Objects[idx]));
end;

function GetLoadOrderFormID(e: IInterface): Cardinal;
begin
  Result := NodeOf(e).FormId;
end;

function ContainingMainRecord(e: IInterface): IInterface;
var
  n: TNode;
begin
  n := NodeOf(e);
  while Assigned(n) and (n.Kind <> nkRecord) do
    n := n.Parent;
  Result := IntfOf(n);
end;

function Name(e: IInterface): string;
var
  n: TNode;
begin
  n := NodeOf(e);
  if not Assigned(n) then
    Exit('');
  if n.Sig <> '' then
    Result := n.Sig + ' - ' + n.DefName
  else
    Result := n.DefName;
end;

function ElementCount(e: IInterface): Integer;
begin
  if Assigned(NodeOf(e)) then
    Result := NodeOf(e).Kids.Count
  else
    Result := 0;
end;

function ElementByIndex(e: IInterface; i: Integer): IInterface;
begin
  Result := nil;
  if Assigned(NodeOf(e)) and (i >= 0) and (i < NodeOf(e).Kids.Count) then
    Result := IntfOf(NodeOf(e).Kid(i));
end;

function ChildNamed(n: TNode; const s: string): TNode;
var
  k: Integer;
begin
  Result := nil;
  if not Assigned(n) then
    Exit;
  for k := 0 to n.Kids.Count - 1 do
    if SameText(n.Kid(k).DefName, s) then
      Exit(n.Kid(k));
  if IsSig(s) then
    for k := 0 to n.Kids.Count - 1 do
      if n.Kid(k).Sig = s then
        Exit(n.Kid(k));
end;

function ElementByName(e: IInterface; const s: string): IInterface;
begin
  Result := IntfOf(ChildNamed(NodeOf(e), s));
end;

function ResolvePath(n: TNode; const path: string; create: Boolean): TNode;
var
  parts: TStringList;
  k: Integer;
  c: TNode;
begin
  Result := n;
  parts := TStringList.Create;
  try
    parts.Delimiter := '\';
    parts.StrictDelimiter := True;
    parts.DelimitedText := path;
    for k := 0 to parts.Count - 1 do begin
      c := ChildNamed(Result, parts[k]);
      if not Assigned(c) then begin
        if not create then
          Exit(nil);
        c := TNode.Create(Result, nkElement, parts[k]);
      end;
      Result := c;
    end;
  finally
    parts.Free;
  end;
end;

function ElementByPath(e: IInterface; const s: string): IInterface;
begin
  Result := IntfOf(ResolvePath(NodeOf(e), s, False));
end;

function ElementBySignature(e: IInterface; const s: string): IInterface;
var
  k: Integer;
  n: TNode;
begin
  Result := nil;
  n := NodeOf(e);
  if not Assigned(n) then
    Exit;
  for k := 0 to n.Kids.Count - 1 do
    if n.Kid(k).Sig = s then
      Exit(IntfOf(n.Kid(k)));
end;

function Add(e: IInterface; const s: string; silent: Boolean): IInterface;
var
  n, c: TNode;
begin
  n := NodeOf(e);
  if not Assigned(n) then
    Exit(nil);
  case n.Kind of
    nkFile: begin
      c := ChildNamed(n, s);
      if not Assigned(c) then
        c := TNode.Create(n, nkGroup, s);
      Result := IntfOf(c);
    end;
    nkGroup: begin
      Inc(NextFormId);
      Result := IntfOf(NewRecordNode(n, s, (Cardinal(Files.IndexOf(n.Parent as IInterface)) shl 24) or NextFormId));
    end;
  else
    c := ChildNamed(n, s);
    if not Assigned(c) then
      c := TNode.Create(n, nkElement, s);
    Result := IntfOf(c);
  end;
end;

function ElementAssign(e: IInterface; index: Integer; src: IInterface; onlySK: Boolean): IInterface;
begin
  Result := IntfOf(TNode.Create(NodeOf(e), nkElement, '#item'));
end;

function LinksTo(e: IInterface): IInterface;
var
  idx: Integer;
begin
  Result := nil;
  if not Assigned(NodeOf(e)) then
    Exit;
  idx := Registry.IndexOf(UpperCase(VarToStr(NodeOf(e).Value)));
  if idx >= 0 then
    Result := IntfOf(TNode(Registry.Objects[idx]));
end;

function GetEditValue(e: IInterface): string;
begin
  if Assigned(NodeOf(e)) then
    Result := VarToStr(NodeOf(e).Value)
  else
    Result := '';
end;

function SetEditValue(e: IInterface; const s: string): Variant;
begin
  if Assigned(NodeOf(e)) then
    NodeOf(e).Value := s;
  Result := Null;
end;

// В xEdit отсутствующий элемент читается как 0; строковые значения модели
// (имена функций условий) считаем ненулевыми.
function NativeOf(n: TNode): Variant;
begin
  if not Assigned(n) or VarIsEmpty(n.Value) or VarIsNull(n.Value) then
    Exit(0);
  if VarIsNumeric(n.Value) then
    Exit(n.Value);
  if VarToStr(n.Value) = '' then
    Result := 0
  else
    Result := 1;
end;

function GetNativeValue(e: IInterface): Variant;
begin
  Result := NativeOf(NodeOf(e));
end;

function SetNativeValue(e: IInterface; v: Variant): Variant;
begin
  if Assigned(NodeOf(e)) then
    NodeOf(e).Value := v;
  Result := Null;
end;

function GetElementEditValues(e: IInterface; const path: string): string;
var
  n: TNode;
begin
  n := ResolvePath(NodeOf(e), path, False);
  if Assigned(n) then
    Result := VarToStr(n.Value)
  else
    Result := '';
end;

function SetElementEditValues(e: IInterface; const path, value: string): Variant;
begin
  ResolvePath(NodeOf(e), path, True).Value := value;
  Result := Null;
end;

function GetElementNativeValues(e: IInterface; const path: string): Variant;
begin
  Result := NativeOf(ResolvePath(NodeOf(e), path, False));
end;

function SetElementNativeValues(e: IInterface; const path: string; v: Variant): Variant;
begin
  ResolvePath(NodeOf(e), path, True).Value := v;
  Result := Null;
end;

function AddRequiredElementMasters(e, f: IInterface; asNew, silent: Boolean): Boolean;
begin
  Result := True;
end;

function wbCopyElementToFile(e, f: IInterface; asNew, deepCopy: Boolean): IInterface;
var
  src, g, r: TNode;
begin
  src := NodeOf(e);
  g := NodeOf(Add(f, src.Sig, True));
  r := TNode.Create(g, nkRecord, src.Sig);
  r.Sig := src.Sig;
  r.Edid := src.Edid;
  r.FormId := src.FormId;
  RegisterRecord(r);
  Result := IntfOf(r);
end;

{ Проверка результата }

var
  Failures: Integer = 0;

procedure Check(ok: Boolean; const what: string);
begin
  if ok then
    WriteLn('ok   ', what)
  else begin
    WriteLn('FAIL ', what);
    Inc(Failures);
  end;
end;

function RecordByEdid(f: TNode; const sig, edid: string): TNode;
var
  g: TNode;
  k: Integer;
begin
  Result := nil;
  g := ChildNamed(f, sig);
  if not Assigned(g) then
    Exit;
  for k := 0 to g.Kids.Count - 1 do
    if g.Kid(k).Edid = edid then
      Exit(g.Kid(k));
end;

function TabNode(entry: TNode; tab: Integer): TNode;
var
  pcs, pc, prkc: TNode;
  k: Integer;
begin
  Result := nil;
  pcs := ChildNamed(entry, 'Perk Conditions');
  if not Assigned(pcs) then
    Exit;
  for k := 0 to pcs.Kids.Count - 1 do begin
    pc := pcs.Kid(k);
    prkc := ChildNamed(pc, 'PRKC');
    if Assigned(prkc) and (NativeOf(prkc) = tab) then
      Exit(pc);
  end;
end;

// Типы условий вкладки через запятую: "96,128" и т. п.
function TabTypes(entry: TNode; tab: Integer): string;
var
  pc, conds, ctda: TNode;
  k: Integer;
begin
  Result := '-';
  pc := TabNode(entry, tab);
  if not Assigned(pc) then
    Exit;
  conds := ChildNamed(pc, 'Conditions');
  Result := '';
  if not Assigned(conds) then
    Exit;
  for k := 0 to conds.Kids.Count - 1 do begin
    ctda := ChildNamed(conds.Kid(k), 'CTDA');
    if Result <> '' then
      Result := Result + ',';
    Result := Result + VarToStr(NativeOf(ChildNamed(ctda, 'Type')));
  end;
end;

function EntryValue(entry: TNode): Double;
begin
  Result := NativeOf(ResolvePath(entry, 'Function Parameters\EPFD', False));
end;

function EntryPoint(entry: TNode): string;
begin
  Result := VarToStr(ResolvePath(entry, 'DATA\Entry Point\Entry Point', False).Value);
end;

procedure VerifyGenerated;
var
  f, perk, eff, spell, quest, alias, npcGroup, npc, perks, kw: TNode;
  k, withPerk, withKeyword: Integer;
  allOk: Boolean;
begin
  WriteLn;
  WriteLn('--- generator log ---');
  for k := 0 to Messages.Count - 1 do
    if (Pos('ERROR', Messages[k]) > 0) or (Pos('DONE', Messages[k]) > 0)
       or (Pos('entries', Messages[k]) > 0) or (Pos('tabs', Messages[k]) > 0) then
      WriteLn(Messages[k]);
  WriteLn('--- checks ---');

  f := FindFile('FHS_MagicScaling.esp');
  Check(Assigned(f), 'plugin created');
  if not Assigned(f) then
    Halt(1);
  Check(MessagesErrors = 0, 'no ERROR lines in the log');
  Check(MasterCount(IntfOf(f)) = 4, 'four masters');

  Check(Assigned(RecordByEdid(f, 'KYWD', 'FHS_SummonEndgame')), 'keyword FHS_SummonEndgame');
  Check(Assigned(RecordByEdid(f, 'FLST', 'FHS_BoundWeapons'))
    and (ChildNamed(RecordByEdid(f, 'FLST', 'FHS_BoundWeapons'), 'FormIDs').Kids.Count = 9), 'bound weapons list has 9 items');

  // Перк игрока: D1 (11) + D2 (1) + C3 (11) + C4 (11)
  perk := RecordByEdid(f, 'PERK', 'FHS_Attunement');
  Check(Assigned(perk) and (ChildNamed(perk, 'Effects').Kids.Count = 34), 'player perk has 34 entries');
  eff := ChildNamed(perk, 'Effects').Kid(0);
  Check(EntryPoint(eff) = 'Mod Spell Magnitude', 'D1 entry point');
  Check(Abs(EntryValue(eff) - 1.18) < 1e-9, 'D1 first band value 1.18');
  Check(TabTypes(eff, 0) = '96,128', 'D1 level band: >= and <');
  Check(TabTypes(eff, 1) = '0,1,1,1,0', 'D1 spell: skill AND (fire OR frost OR shock OR drain)');
  eff := ChildNamed(perk, 'Effects').Kid(10);
  Check((TabTypes(eff, 0) = '96') and (Abs(EntryValue(eff) - 2.96) < 1e-9), 'D1 last band: only >= 80, value 2.96');
  eff := ChildNamed(perk, 'Effects').Kid(11);
  Check((TabTypes(eff, 0) = '0,96') and (Abs(EntryValue(eff) - 1.2) < 1e-9), 'D2 absolute destruction');
  eff := ChildNamed(perk, 'Effects').Kid(12);
  Check((TabTypes(eff, 1) = '0') and (Abs(EntryValue(eff) - 1.18) < 1e-9), 'C3 conjuration level limits');
  eff := ChildNamed(perk, 'Effects').Kid(23);
  Check((EntryPoint(eff) = 'Mod Attack Damage') and (TabTypes(eff, 1) = '0')
    and (Abs(EntryValue(eff) - 1.06) < 1e-9), 'C4 bound weapons');

  // Перк призывов: 15 рубежей x 4 точки входа + 4 записи C2
  perk := RecordByEdid(f, 'PERK', 'FHS_SummonAttunement');
  Check(Assigned(perk) and (ChildNamed(perk, 'Effects').Kids.Count = 64), 'summon perk has 64 entries');
  allOk := True;
  for k := 0 to 59 do
    if TabTypes(ChildNamed(perk, 'Effects').Kid(k), 0) <> '96,128,97,0,0,0' then
      allOk := False;
  Check(allOk, 'every milestone: player>=P AND own<P AND (own>=P/2 OR endgame) AND commanded AND not hostile');
  eff := ChildNamed(perk, 'Effects').Kid(0);
  Check(Abs(EntryValue(eff) - 1.625) < 1e-9, 'first milestone step 1.625');
  eff := ChildNamed(perk, 'Effects').Kid(2);
  Check((EntryPoint(eff) = 'Mod Incoming Damage') and (Abs(EntryValue(eff) - 0.615) < 1e-9), 'incoming damage 1/1.625');
  eff := ChildNamed(perk, 'Effects').Kid(60);
  Check((TabTypes(eff, 0) = '0,96,0,0') and (Abs(EntryValue(eff) - 1.2) < 1e-9), 'C2 absolute conjuration');

  // Магические эффекты и способность
  Check(Assigned(RecordByEdid(f, 'MGEF', 'FHS_AttunementCarrier'))
    and (VarToStr(ResolvePath(RecordByEdid(f, 'MGEF', 'FHS_AttunementCarrier'), 'DATA\Perk to Apply', False).Value)
         = HexId(RecordByEdid(f, 'PERK', 'FHS_Attunement').FormId)), 'carrier applies FHS_Attunement');
  spell := RecordByEdid(f, 'SPEL', 'FHS_AttunementAbility');
  Check(Assigned(spell) and (ChildNamed(spell, 'Effects').Kids.Count = 14), 'ability: carrier + 11 bands + 2 mastery lines');
  Check(VarToStr(ResolvePath(spell, 'SPIT\Type', False).Value) = 'Ability', 'spell type Ability');

  // Квест
  quest := RecordByEdid(f, 'QUST', 'FHS_CoreQuest');
  Check(Assigned(quest) and (NativeOf(ResolvePath(quest, 'DNAM\Flags', False)) = 1), 'quest is Start Game Enabled');
  alias := ChildNamed(quest, 'Aliases').Kid(0);
  Check(VarToStr(ResolvePath(alias, 'ALFR', False).Value) = '00000014', 'alias filled with PlayerRef');
  Check(VarToStr(ChildNamed(alias, 'Alias Spells').Kid(0).Value) = HexId(spell.FormId), 'alias gives the ability');

  // Призывы
  npcGroup := ChildNamed(f, 'NPC_');
  withPerk := 0;
  withKeyword := 0;
  if Assigned(npcGroup) then
    for k := 0 to npcGroup.Kids.Count - 1 do begin
      npc := npcGroup.Kid(k);
      perks := ChildNamed(npc, 'Perks');
      if Assigned(perks) and (perks.Kids.Count = 1) then
        if VarToStr(ChildNamed(perks.Kid(0), 'Perk').Value) = HexId(perk.FormId) then
          Inc(withPerk);
      kw := ResolvePath(npc, 'Keywords\KWDA', False);
      if Assigned(kw) and (kw.Kids.Count = 1) then
        Inc(withKeyword);
    end;
  Check(withPerk = 22, 'all 22 summon NPCs get the summon perk (' + IntToStr(withPerk) + ')');
  Check(withKeyword = 7, 'seven endgame summons get the keyword (' + IntToStr(withKeyword) + ')');

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL CHECKS PASSED')
  else begin
    WriteLn(Failures, ' CHECK(S) FAILED');
    Halt(1);
  end;
end;

initialization
  Files := TInterfaceList.Create;
  Registry := TStringList.Create;
  Messages := TStringList.Create;
  Files.Add(TNode.Create(nil, nkFile, 'Skyrim.esm') as IInterface);
  Files.Add(TNode.Create(nil, nkFile, 'Update.esm') as IInterface);
  Files.Add(TNode.Create(nil, nkFile, 'Dawnguard.esm') as IInterface);
  Files.Add(TNode.Create(nil, nkFile, 'Dragonborn.esm') as IInterface);
end.
