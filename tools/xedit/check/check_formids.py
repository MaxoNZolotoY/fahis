"""Сверяет FormID и EditorID ванильных записей в генераторе с данными игры.

Генератор ищет записи по «короткому» FormID и сверяет EditorID. Этот скрипт
проверяет каждую пару заранее, без игры: берёт таблицу EditorID -> FormID
из NuGet-пакета Mutagen.Bethesda.FormKeys.SkyrimSE (он сгенерирован из
Skyrim.esm, Update.esm, Dawnguard.esm, Dragonborn.esm).

    pip install dnfile
    python3 tools/xedit/check/check_formids.py
"""

import io
import pathlib
import re
import struct
import sys
import tempfile
import urllib.request
import zipfile

PAS = pathlib.Path(__file__).resolve().parents[1] / "FHS_BuildMagicScaling.pas"
NUPKG = ("https://api.nuget.org/v3-flatcontainer/mutagen.bethesda.formkeys.skyrimse/"
         "3.4.0/mutagen.bethesda.formkeys.skyrimse.3.4.0.nupkg")
DLL = "lib/net8.0/Mutagen.Bethesda.FormKeys.SkyrimSE.dll"
MASTERS = {"Skyrim": "Skyrim.esm", "Update": "Update.esm",
           "Dawnguard": "Dawnguard.esm", "Dragonborn": "Dragonborn.esm"}


def load_formkeys():
    """(файл, EditorID) -> короткий FormID, из IL геттеров в DLL."""
    import dnfile

    data = urllib.request.urlopen(NUPKG, timeout=120).read()
    with tempfile.TemporaryDirectory() as tmp:
        zipfile.ZipFile(io.BytesIO(data)).extract(DLL, tmp)
        pe = dnfile.dnPE(str(pathlib.Path(tmp) / DLL))
        md = pe.net.mdtables
        types = md.TypeDef.rows
        enclosing = {r.NestedClass.row_index: r.EnclosingClass.row_index for r in md.NestedClass.rows}
        result = {}
        for idx, t in enumerate(types, start=1):
            if idx not in enclosing:
                continue
            master = MASTERS.get(str(types[enclosing[idx] - 1].TypeName))
            if not master:
                continue
            for m in t.MethodList:
                row = m.row
                name = str(row.Name)
                if not name.startswith("get_") or not row.Rva:
                    continue
                off = pe.get_offset_from_rva(row.Rva)
                head = pe.__data__[off]
                if head & 3 == 2:
                    code = pe.__data__[off + 1:off + 1 + (head >> 2)]
                else:
                    flags, = struct.unpack_from("<H", pe.__data__, off)
                    size, = struct.unpack_from("<I", pe.__data__, off + 4)
                    code = pe.__data__[off + (flags >> 12) * 4:off + (flags >> 12) * 4 + size]
                pos = code.find(b"\x20")  # ldc.i4 <int32>
                if pos >= 0 and pos + 5 <= len(code):
                    result[(master, name[4:])] = struct.unpack_from("<I", code, pos + 1)[0]
        pe.close()
    return result


def main():
    text = PAS.read_text(encoding="utf-8")
    calls = re.findall(r"\(\s*'([A-Za-z]+\.esm)',\s*\$([0-9A-Fa-f]+),\s*'([A-Za-z0-9_]+)'", text)
    if not calls:
        print("В генераторе не найдено ни одной ссылки на ванильные записи")
        sys.exit(1)
    formkeys = load_formkeys()
    bad = 0
    for master, hexid, edid in sorted(set(calls)):
        expected = formkeys.get((master, edid))
        actual = int(hexid, 16)
        if expected is None:
            print(f"НЕТ В ДАННЫХ  {master} {edid}")
            bad += 1
        elif expected != actual:
            print(f"НЕ СОВПАДАЕТ  {master} {edid}: в скрипте {actual:06X}, в игре {expected:06X}")
            bad += 1
    print(f"Проверено ссылок: {len(set(calls))}, ошибок: {bad}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
