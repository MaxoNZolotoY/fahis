#!/bin/sh
# Проверка генератора без игры и без xEdit (нужен Free Pascal: apt install fp-compiler).
#   1. Синтаксис: компиляция с заглушками API xEdit (xedit_stub.pas).
#   2. Поведение: прогон с моделью xEdit в памяти (xedit_mock.pas) и проверка
#      итоговой структуры плагина.
# Скрипт xEdit оформлен как "unit UserScript" без interface/implementation,
# поэтому для компилятора он превращается в программу.
set -e
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

build() {
  sed -e "s/^unit UserScript;/program UserScript;\nuses SysUtils, Variants, $1;/" \
      -e "s/^end\.\$/begin\n  Initialize;\n  $2\nend./" \
      "$here/../FHS_BuildMagicScaling.pas" > "$out/UserScript.pas"
  fpc -Mdelphi -vew -Fu"$here" -FU"$out" -o"$out/UserScript" "$out/UserScript.pas" > "$out/fpc.log" 2>&1 \
    || { cat "$out/fpc.log"; exit 1; }
  if grep -q -i "warning" "$out/fpc.log"; then grep -i "warning" "$out/fpc.log"; exit 1; fi
}

echo "== syntax (stubs)"
build xedit_stub ""
echo "compiled without warnings"

echo "== behaviour (mock)"
build xedit_mock "VerifyGenerated;"
"$out/UserScript"
