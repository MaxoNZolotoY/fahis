"""Переносит числа из tools/scaling_model.py в генератор для SSEEdit.

Генератор (tools/xedit/FHS_BuildMagicScaling.pas) хранит все множители
в блоке между маркерами BEGIN/END GENERATED VALUES. Этот скрипт
пересобирает блок из модели, поэтому числа в спецификации, модели и
плагине всегда совпадают.

    python3 tools/sync_xedit_values.py          # обновить блок
    python3 tools/sync_xedit_values.py --check  # только проверить (код 1, если блок устарел)

Числа пишутся целыми в тысячных долях (1180 = ×1.18): в скрипте они
делятся на 1000, и дробная запятая системной локали ни на что не влияет.
"""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import scaling_model as m  # noqa: E402

PAS = pathlib.Path(__file__).resolve().parent / "xedit" / "FHS_BuildMagicScaling.pas"
BEGIN = "// BEGIN GENERATED VALUES"
END = "// END GENERATED VALUES"


def milli(x):
    return int(round(x * 1000))


def case_function(name, comment, values):
    lines = [f"// {comment}", f"function {name}(i: Integer): Integer;", "begin", "  case i of"]
    for i, v in enumerate(values):
        lines.append(f"    {i}: Result := {v};")
    lines += ["  else", "    Result := 0;", "  end;", "end;", ""]
    return lines


def const_function(name, value):
    return [f"function {name}: Integer;", "begin", f"  Result := {value};", "end;", ""]


def generate():
    bands = m.DESTR_BANDS
    destr = [m.fhs_destr_mult(b) for b in bands]
    bound = [m.bound_mult(b) for b in bands]
    steps = [m.summon_step(p) for p in m.SUMMON_MILESTONES]

    # Только функции, без секций const: так блок можно ставить среди
    # остальных функций, не завися от того, как JvInterpreter разбирает
    # порядок секций модуля.
    out = [BEGIN + " (tools/sync_xedit_values.py, не править руками)", ""]
    out += const_function("DestrBandCount", len(bands))
    out += const_function("DestrBandFirst", bands[0])
    out += const_function("DestrBandStep", bands[1] - bands[0])
    out += const_function("SummonMilestoneCount", len(m.SUMMON_MILESTONES))
    out += const_function("SummonMilestoneFirst", m.SUMMON_MILESTONES[0])
    out += const_function("SummonMilestoneStep", m.SUMMON_MILESTONES[1] - m.SUMMON_MILESTONES[0])
    out += const_function("AbsoluteMilli", milli(m.ABSOLUTE_DESTRUCTION))
    out += const_function("AbsoluteInvMilli", int(round(1000 / m.ABSOLUTE_DESTRUCTION)))
    out += case_function("DestrMilli", "Резонанс Разрушения и пороги Колдовства, ступенька i (модуль D1, C3)",
                         [milli(v) for v in destr])
    out += case_function("DestrPercent", "То же в процентах прибавки, для строки в «Активных эффектах»",
                         [int(round((v - 1) * 100)) for v in destr])
    out += case_function("BoundMilli", "Призванное оружие, ступенька i (модуль C4)",
                         [milli(v) for v in bound])
    out += case_function("SummonStepMilli", "Шаг рубежа призывов i: урон ×r (модуль C1)",
                         [milli(r) for r in steps])
    out += case_function("SummonStepInvMilli", "Шаг рубежа призывов i: входящий урон ×1/r (модуль C1)",
                         [int(round(1000 / r)) for r in steps])
    out += case_function("SummonMinLevel", "Минимальный уровень призыва для рубежа i (правило 2×)",
                         [int(m.summon_min_level(p)) for p in m.SUMMON_MILESTONES])
    out.append(END)
    return "\n".join(out)


def main():
    text = PAS.read_text(encoding="utf-8")
    start = text.index(BEGIN)
    end = text.index(END) + len(END)
    new = text[:start] + generate() + text[end:]
    if "--check" in sys.argv:
        if new != text:
            print("Блок значений в генераторе устарел: запусти tools/sync_xedit_values.py")
            sys.exit(1)
        print("Значения в генераторе совпадают с моделью.")
        return
    PAS.write_text(new, encoding="utf-8")
    print(f"Обновлено: {PAS}")


if __name__ == "__main__":
    main()
