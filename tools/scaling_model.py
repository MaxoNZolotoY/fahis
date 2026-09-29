"""Численная модель для docs/SPEC_PS5.md.

Считает, насколько заклинания Разрушения и призванные существа отстают от
врагов по мере роста уровня игрока, и какие множители мод FHS должен давать.
Все допущения собраны в начале файла. Запуск: python3 tools/scaling_model.py
Зависимостей нет, нужен только Python 3.8+.
"""

# ---------------------------------------------------------------------------
# Допущения (ванильные формулы и приблизительные данные)
# ---------------------------------------------------------------------------

# Здоровье NPC с автоматическим расчётом характеристик:
#   HP = расовая база + смещение NPC + 5*(L-1) + 10*(L-1)*вес_здоровья/сумма_весов
# Для воинов вес здоровья даёт ещё ~7.5 за уровень.
def hp_warrior(level):
    return 50 + 12.5 * (level - 1)


# Уникальные враги (уровень, здоровье), данные вики.
BOSSES = [
    ("Жрец драконов Хевнорак", 50, 1490),
    ("Древний дракон", 50, 3071),
    ("Почитаемый дракон", 62, 3511),
    ("Эбонитовый воин", 80, 2071),
    ("Легендарный дракон", 75, 4163),
]

# Множители сложности: урон игрока и урон по игроку.
DIFFICULTY = {
    "Новичок": (2.0, 0.5),
    "Ученик": (1.5, 0.75),
    "Адепт": (1.0, 1.0),
    "Эксперт": (0.75, 1.5),
    "Мастер": (0.5, 2.0),
    "Легенда": (0.25, 3.0),
}

# Профиль «чистого мага»: навык Разрушения растёт быстрее уровня.
def destruction_skill(level):
    return min(100.0, 15 + 2.2 * level)


# Лучшее заклинание на одну цель: (название, урон, базовая стоимость).
def best_spell(skill):
    if skill >= 75:
        return ("Испепеление", 60, 171)
    if skill >= 50:
        return ("Огненный шар", 40, 133)
    return ("Огненная стрела", 25, 41)


def augmented(skill):
    if skill >= 60:
        return 1.5
    if skill >= 30:
        return 1.25
    return 1.0


DUAL_MAG = 2.2  # двойное чтение: ×2.2 к силе (стоимость ×2.8 в модели не нужна)


def skill_cost_mult(skill):
    return 1 - (skill / 400) ** 0.65


def school_perk_mult(skill):
    # Перки «Ученик/Адепт/Эксперт школы Разрушения» вдвое снижают стоимость
    # заклинаний своего уровня. Заклинание берём уже того уровня, до которого дорос навык.
    return 0.5 if skill >= 25 else 1.0


def magicka_pool(level):
    # 70% повышений уровня в магию + ~50 от снаряжения после 20 уровня.
    return 100 + 7 * (level - 1) + (50 if level >= 20 else 0)


# ---------------------------------------------------------------------------
# Параметры FHS
# ---------------------------------------------------------------------------

REF_LEVEL = 25                       # уровень, на котором ваниль ещё «в балансе»
DESTR_BANDS = list(range(30, 81, 5))  # 30, 35, ..., 80
ABSOLUTE_DESTRUCTION = 1.2           # пассивный бонус мастера (навык 100 + перк «Мастер»)

SUMMON_MILESTONES = list(range(10, 81, 5))  # 10, 15, ..., 80
SUMMON_CAP_FACTOR = 2.0   # обычный призыв растёт до уровня 2 × свой уровень

BOUND_SHARE = 0.35        # призванное оружие получает 35% прироста Разрушения

# Жетоны сложности (опциональный модуль E): половина штрафа сложности в логарифмах,
# то есть корень из обратного множителя.
DIFFICULTY_TOKEN = {"Эксперт": 1.15, "Мастер": 1.4, "Легенда": 2.0}


def fhs_destr_mult(level):
    bands = [b for b in DESTR_BANDS if b <= level]
    if not bands:
        return 1.0
    return round(hp_warrior(bands[-1]) / hp_warrior(REF_LEVEL), 2)


def bound_mult(level):
    return round(1 + (fhs_destr_mult(level) - 1) * BOUND_SHARE, 2)


def summon_step(p):
    return round(hp_warrior(p) / hp_warrior(p - 5), 3)


def summon_min_level(p):
    """Минимальный уровень призыва, при котором рубеж p ещё действует (правило 2×)."""
    return -(-p // SUMMON_CAP_FACTOR)  # потолок деления


def fhs_summon_mult(player_level, summon_level, endgame=False):
    m = 1.0
    for p in SUMMON_MILESTONES:
        if p > player_level or summon_level >= p:
            continue
        if endgame or summon_level >= summon_min_level(p):
            m *= summon_step(p)
    return m


# Призывы: (название, уровень, здоровье, эндгейм — растёт без потолка).
# Уровни и здоровье приблизительные, их надо сверить в CK на записях
# SummonAtronach*/SummonEncDremoraLord.
SUMMONS = [
    ("Огненный атронах", 5, 111, False),
    ("Ледяной атронах", 16, 667, False),
    ("Грозовой атронах", 25, 391, False),
    ("Лорд дремора", 46, 545, True),
    ("Огненный раб (эндгейм)", 5, 111, True),
    ("Ледяной раб (эндгейм)", 16, 667, True),
    ("Грозовой раб (эндгейм)", 25, 391, True),
]

LEVELS = [10, 20, 30, 40, 50, 60, 70, 80]


def fmt(x, nd=1):
    return f"{x:.{nd}f}".rstrip("0").rstrip(".") if nd else f"{x:.0f}"


def mage_row(level, fhs):
    s = destruction_skill(level)
    name, dmg, cost = best_spell(s)
    mult = augmented(s)
    if fhs:
        mult *= fhs_destr_mult(level)
        if s >= 100:
            mult *= ABSOLUTE_DESTRUCTION
    single = dmg * mult
    cast_cost = cost * skill_cost_mult(s) * school_perk_mult(s)
    hp = hp_warrior(level)
    ctk = hp / single
    ctk_dual = hp / (single * DUAL_MAG)
    kills_per_bar = magicka_pool(level) / (ctk * cast_cost)
    return name, s, single, ctk, ctk_dual, cast_cost, kills_per_bar


def main():
    print("## Множители FHS для Разрушения (по уровню игрока)\n")
    print("| Уровень игрока | " + " | ".join(f"{b}+" for b in DESTR_BANDS) + " |")
    print("|---|" + "---|" * len(DESTR_BANDS))
    print("| Множитель урона | " + " | ".join(f"×{fhs_destr_mult(b):.2f}" for b in DESTR_BANDS) + " |")

    print("\n## Маг против воина своего уровня (сложность «Адепт»)\n")
    print("| Уровень | Навык | Заклинание | HP врага | Урон ваниль | Кастов ваниль | Двойных ваниль | Убийств на запас маны | Урон FHS | Кастов FHS | Двойных FHS | Убийств на запас FHS |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for L in LEVELS:
        v = mage_row(L, False)
        f = mage_row(L, True)
        print(f"| {L} | {v[1]:.0f} | {v[0]} | {hp_warrior(L):.0f} | {v[2]:.0f} | {v[3]:.1f} | {v[4]:.1f} | {v[6]:.1f} | {f[2]:.0f} | {f[3]:.1f} | {f[4]:.1f} | {f[6]:.1f} |")

    print("\n## Боссы: сколько двойных «Испепелений» нужно (Адепт, без сопротивлений)\n")
    print("| Враг | Уровень | HP | Ваниль | FHS |")
    print("|---|---|---|---|---|")
    for name, L, hp in BOSSES:
        v = mage_row(L, False)
        f = mage_row(L, True)
        print(f"| {name} | {L} | {hp} | {hp / (v[2] * DUAL_MAG):.0f} | {hp / (f[2] * DUAL_MAG):.0f} |")

    print("\n## Сложность: кастов на воина своего уровня, уровень 50, одиночные касты\n")
    v = mage_row(50, False)
    f = mage_row(50, True)
    print("| Сложность | Ваниль | FHS |")
    print("|---|---|---|")
    for d, (dealt, _) in DIFFICULTY.items():
        print(f"| {d} | {v[3] / dealt:.1f} | {f[3] / dealt:.1f} |")

    print("\n## Рубежи множителя призывов\n")
    print("| Рубеж (уровень игрока) | " + " | ".join(str(p) for p in SUMMON_MILESTONES) + " |")
    print("|---|" + "---|" * len(SUMMON_MILESTONES))
    print("| Шаг: ×урон, ÷входящий урон | " + " | ".join(f"×{summon_step(p):.3f}" for p in SUMMON_MILESTONES) + " |")
    print("| Уровень призыва меньше | " + " | ".join(str(p) for p in SUMMON_MILESTONES) + " |")
    print("| …и не меньше (кроме эндгейм-призывов) | " + " | ".join(f"{summon_min_level(p):.0f}" for p in SUMMON_MILESTONES) + " |")

    print("\n## Итоговый множитель призыва по уровню игрока\n")
    print("| Призыв (ур.) | " + " | ".join(str(L) for L in LEVELS) + " |")
    print("|---|" + "---|" * len(LEVELS))
    for name, ls, _, endgame in SUMMONS:
        print(f"| {name} ({ls}) | " + " | ".join(f"×{fhs_summon_mult(L, ls, endgame):.2f}" for L in LEVELS) + " |")

    print("\n## Эффективное здоровье призыва / здоровье воина уровня игрока\n")
    print("| Призыв | " + " | ".join(f"{L}: ваниль → FHS" for L in (30, 50, 70, 80)) + " |")
    print("|---|---|---|---|---|")
    for name, ls, hp, endgame in SUMMONS:
        cells = []
        for L in (30, 50, 70, 80):
            van = hp / hp_warrior(L)
            fhs = hp * fhs_summon_mult(L, ls, endgame) / hp_warrior(L)
            cells.append(f"{van:.2f} → {fhs:.2f}")
        print(f"| {name} | " + " | ".join(cells) + " |")

    print("\n## Призванное оружие и пороги уровня (воскрешение, изгнание)\n")
    print("| Уровень игрока | " + " | ".join(f"{b}+" for b in DESTR_BANDS) + " |")
    print("|---|" + "---|" * len(DESTR_BANDS))
    print("| Призванное оружие | " + " | ".join(f"×{bound_mult(b):.2f}" for b in DESTR_BANDS) + " |")
    for name, cap in (("Поднять зомби", 6), ("Оживить труп", 13), ("Ревенант", 21), ("Жуткий зомби", 30)):
        print(f"| {name} (ур. ≤ {cap}) | " + " | ".join(str(int(cap * fhs_destr_mult(b))) for b in DESTR_BANDS) + " |")

    print("\n## Жетоны сложности (модуль E): кастов на воина 50 уровня\n")
    f = mage_row(50, True)
    print("| Сложность | Ваниль | FHS | FHS + жетон |")
    print("|---|---|---|---|")
    for d, (dealt, _) in DIFFICULTY.items():
        tok = DIFFICULTY_TOKEN.get(d, 1.0)
        v = mage_row(50, False)
        print(f"| {d} | {v[3] / dealt:.1f} | {f[3] / dealt:.1f} | {f[3] / dealt / tok:.1f} |")

if __name__ == "__main__":
    main()
