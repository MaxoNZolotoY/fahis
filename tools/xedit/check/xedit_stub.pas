{ Заглушки функций скриптового API xEdit (JvInterpreter) для проверки
  синтаксиса генератора компилятором Free Pascal. Логики здесь нет:
  генератор проверяется только на то, что он корректно написан. }
unit xedit_stub;

{$mode delphi}

interface

uses
  SysUtils, Variants;

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

implementation

procedure AddMessage(const s: string); begin WriteLn(s); end;
function FileByName(const s: string): IInterface; begin Result := nil; end;
function AddNewFileName(const s: string; aLight: Boolean): IInterface; begin Result := nil; end;
function AddMasterIfMissing(f: IInterface; const s: string): Variant; begin Result := Null; end;
function SortMasters(f: IInterface): Variant; begin Result := Null; end;
function MasterCount(f: IInterface): Integer; begin Result := 0; end;
function MasterByIndex(f: IInterface; i: Integer): IInterface; begin Result := nil; end;
function RecordCount(f: IInterface): Integer; begin Result := 0; end;
function GetFileName(f: IInterface): string; begin Result := ''; end;
function GetFile(e: IInterface): IInterface; begin Result := nil; end;
function GroupBySignature(f: IInterface; const s: string): IInterface; begin Result := nil; end;
function FileFormIDtoLoadOrderFormID(f: IInterface; formId: Integer): Integer; begin Result := formId; end;
function RecordByFormID(f: IInterface; formId: Integer; allowInjected: Boolean): IInterface; begin Result := nil; end;
function EditorID(e: IInterface): string; begin Result := ''; end;
function SetEditorID(e: IInterface; const s: string): Variant; begin Result := Null; end;
function Signature(e: IInterface): string; begin Result := ''; end;
function MasterOrSelf(e: IInterface): IInterface; begin Result := e; end;
function OverrideCount(e: IInterface): Integer; begin Result := 0; end;
function OverrideByIndex(e: IInterface; i: Integer): IInterface; begin Result := nil; end;
function WinningOverride(e: IInterface): IInterface; begin Result := e; end;
function GetLoadOrderFormID(e: IInterface): Cardinal; begin Result := 0; end;
function ContainingMainRecord(e: IInterface): IInterface; begin Result := nil; end;
function Name(e: IInterface): string; begin Result := ''; end;
function ElementCount(e: IInterface): Integer; begin Result := 0; end;
function ElementByIndex(e: IInterface; i: Integer): IInterface; begin Result := nil; end;
function ElementByName(e: IInterface; const s: string): IInterface; begin Result := nil; end;
function ElementByPath(e: IInterface; const s: string): IInterface; begin Result := nil; end;
function ElementBySignature(e: IInterface; const s: string): IInterface; begin Result := nil; end;
function Add(e: IInterface; const s: string; silent: Boolean): IInterface; begin Result := nil; end;
function ElementAssign(e: IInterface; index: Integer; src: IInterface; onlySK: Boolean): IInterface; begin Result := nil; end;
function LinksTo(e: IInterface): IInterface; begin Result := nil; end;
function GetEditValue(e: IInterface): string; begin Result := ''; end;
function SetEditValue(e: IInterface; const s: string): Variant; begin Result := Null; end;
function GetNativeValue(e: IInterface): Variant; begin Result := 0; end;
function SetNativeValue(e: IInterface; v: Variant): Variant; begin Result := Null; end;
function GetElementEditValues(e: IInterface; const path: string): string; begin Result := ''; end;
function SetElementEditValues(e: IInterface; const path, value: string): Variant; begin Result := Null; end;
function GetElementNativeValues(e: IInterface; const path: string): Variant; begin Result := 0; end;
function SetElementNativeValues(e: IInterface; const path: string; v: Variant): Variant; begin Result := Null; end;
function AddRequiredElementMasters(e, f: IInterface; asNew, silent: Boolean): Boolean; begin Result := False; end;
function wbCopyElementToFile(e, f: IInterface; asNew, deepCopy: Boolean): IInterface; begin Result := nil; end;

end.
