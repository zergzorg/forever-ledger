#!/usr/bin/env python3
"""Build Locales/ruRU.lua from the in-place Russian sources in branch `ru`.

Every string literal of the English tree is paired with the Russian literal at the
same place in `ru`, so the ruRU table is the translation we already run and test,
not a second one. Plural forms and the few messages Russian phrases differently
are listed by hand below. Run from the repository root, on the locale branch:

    python3 tools/build-ru-locale.py           # writes Locales/ruRU.lua
    python3 tools/build-ru-locale.py --report  # says what stayed unpaired
"""
import difflib
import re
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

RU_BRANCH = "ru"
RU_PREFIX = ""
OUT = Path("Locales/ruRU.lua")

LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
CYR = re.compile(r"[А-Яа-яЁё]")
LATIN = re.compile(r"[A-Za-z]{2,}")
SPEC = re.compile(r"%[%\-+#0]*\d*\.?\d*[cdiouxXeEfgGqs]")

# A string is worth pairing when it can be shown: it has a letter and isn't a Lua
# pattern, a path, a link or pure markup.
SKIP_FILES = {"ClassicItems.lua", "ClassicRecipes.lua", "ClassicCrafts.lua",
              "ForeverCrafts.lua"}
TECHNICAL = re.compile(r"^\^|\\|^https?://|^[|%]|^[a-z_]+$|^[A-Z_]+$|"
                       r"^[A-Za-z]+:[A-Za-z0-9]+$")


def literals(line):
    return [m.group(1) for m in LIT.finditer(line)]


def has_cyr(text):
    return CYR.search(text) is not None


COLOR = re.compile(r"^\|c[0-9a-fA-F]{8}|\|r$|^\n+")


def displayable(text):
    body = COLOR.sub("", text)
    if not LATIN.search(body) and not has_cyr(body):
        return False
    return TECHNICAL.search(body) is None


DIAGNOSTIC = ("print(", "Debug(", "logLine(", "trace(", "PreciseTiming")


def diagnostic_keys():
    """English literals that only ever sit on a line of diagnostic output."""
    seen, used = {}, set()
    for name in sorted(p.name for p in Path(".").glob("*.lua")):
        for line in Path(name).read_text(encoding="utf-8").splitlines():
            for lit in literals(line):
                seen[lit] = seen.get(lit, 0) + 1
                if any(mark in line for mark in DIAGNOSTIC):
                    used.add(lit)
    return {lit for lit in used if seen.get(lit) == 1}


def ru_lines(name):
    out = subprocess.run(["git", "show", f"{RU_BRANCH}:{RU_PREFIX}{name}"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        return None
    return out.stdout.splitlines()


WRAPPER = re.compile(r"\bns\.Localize\w+")


def skeleton(line):
    """The line with its strings blanked and the display wrappers dropped: the same code
    in both languages, so entries whose text differs still line up."""
    line = WRAPPER.sub("", LIT.sub('""', line.strip()))
    return re.sub(r"\s+", " ", line.replace("(", "").replace(")", ""))


def pair_lines(pr, ru):
    sm = difflib.SequenceMatcher(None, [skeleton(l) for l in pr],
                                 [skeleton(l) for l in ru], autojunk=False)
    pairs = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal" or (tag == "replace" and i2 - i1 == j2 - j1):
            pairs.extend(zip(range(i1, i2), range(j1, j2)))
    return pairs


HELP_SECTION = re.compile(r'^  \{ "[^"]+", \{\s*$')
HELP_END = "  } },"


def help_sections(lines):
    out, start = [], None
    for i, line in enumerate(lines):
        if start is None and HELP_SECTION.match(line):
            start = i
        elif start is not None and line.startswith(HELP_END):
            out.append((start, i))
            start = None
    return out


def help_pairs(pr, ru):
    """Help topics are all `{ "Title", "Text" }` lines, so a section added or removed
    upstream shifts every later topic onto the wrong translation. Pair sections (and
    their topics) by position and skip a section the other version doesn't have."""
    es, rs = help_sections(pr), help_sections(ru)
    def count(lines, span):
        return sum(1 for i in range(span[0], span[1] + 1) if re.match(r'^    \{ "', lines[i]))
    best = None
    for skip in [None] + list(range(len(rs))):
        keep = [s for k, s in enumerate(rs) if k != skip]
        if len(keep) != len(es):
            continue
        score = sum(1 for a, b in zip(es, keep) if count(pr, a) == count(ru, b))
        if best is None or score > best[0]:
            best = (score, keep)
    if best is None:
        return pair_lines(pr, ru)
    pairs = []
    for esp, rsp in zip(es, best[1]):
        pl, rl = list(range(esp[0], esp[1] + 1)), list(range(rsp[0], rsp[1] + 1))
        if len(pl) == len(rl):
            pairs.extend(zip(pl, rl))
        else:
            inner = pair_lines([pr[i] for i in pl], [ru[i] for i in rl])
            pairs.extend((pl[a], rl[b]) for a, b in inner)
    # The addon lists, overlap labels and popups sit outside the sections.
    first_e, first_r = es[0][0], best[1][0][0]
    head_en, head_ru = list(range(0, first_e)), list(range(0, first_r))
    for a, b in pair_lines([pr[i] for i in head_en], [ru[i] for i in head_ru]):
        pairs.append((head_en[a], head_ru[b]))
    last_e, last_r = es[-1][1] + 1, best[1][-1][1] + 1
    tail_en, tail_ru = list(range(last_e, len(pr))), list(range(last_r, len(ru)))
    for a, b in pair_lines([pr[i] for i in tail_en], [ru[i] for i in tail_ru]):
        pairs.append((tail_en[a], tail_ru[b]))
    return pairs


def collect():
    found, unusable = [], []
    for name in sorted(p.name for p in Path(".").glob("*.lua")):
        if name in SKIP_FILES:
            continue
        pr_lines = Path(name).read_text(encoding="utf-8").splitlines()
        src = ru_lines(name)
        if src is None:
            continue
        pairs = help_pairs(pr_lines, src) if name == "Help.lua" else pair_lines(pr_lines, src)
        for i, j in pairs:
            pl, rl = literals(pr_lines[i]), literals(src[j])
            if not pl:
                continue
            if len(pl) == len(rl):
                for a, b in zip(pl, rl):
                    if a != b and has_cyr(b) and displayable(a):
                        found.append((a, b))
            elif len(rl) > len(pl):
                unusable.append((name, i + 1, pl, rl))
    return found, unusable


# -- Plurals -----------------------------------------------------------------
# Russian needs three forms of a counted noun (1 день, 2 дня, 5 дней). The core
# picks the form by the first number the message shows; each entry here is that
# triple. The English keys are the *rendered* text, so both the singular and the
# plural wording of a message are listed.
def forms(one, few, many):
    return (one, few, many)


PLURAL = {
    # Auction house: cancelling undercut listings.
    "|cffffd100Cancel %d undercut auction and lose its deposit?|r Click again.":
        forms("|cffffd100Отменить %d перебитый лот и потерять его залог?|r Нажмите ещё раз.",
              "|cffffd100Отменить %d перебитых лота и потерять их залоги?|r Нажмите ещё раз.",
              "|cffffd100Отменить %d перебитых лотов и потерять их залоги?|r Нажмите ещё раз."),
    "|cffffd100Cancel %d undercut auctions and lose their deposits?|r Click again.":
        forms("|cffffd100Отменить %d перебитый лот и потерять его залог?|r Нажмите ещё раз.",
              "|cffffd100Отменить %d перебитых лота и потерять их залоги?|r Нажмите ещё раз.",
              "|cffffd100Отменить %d перебитых лотов и потерять их залоги?|r Нажмите ещё раз."),
    # Buy queue: list tags and the shopping list's refresh message.
    "%d item, search":
        forms("%d предмет, поиск", "%d предмета, поиск", "%d предметов, поиск"),
    "%d items, search":
        forms("%d предмет, поиск", "%d предмета, поиск", "%d предметов, поиск"),
    "%s: Up to refreshed from usual prices and this list's allowance for %d item. Change any you like; \"off\" means don't buy it.":
        forms("%s: «До» обновлено по обычным ценам и допуску этого списка: %d предмет. Меняйте как угодно; «выкл» — не покупать.",
              "%s: «До» обновлено по обычным ценам и допуску этого списка: %d предмета. Меняйте как угодно; «выкл» — не покупать.",
              "%s: «До» обновлено по обычным ценам и допуску этого списка: %d предметов. Меняйте как угодно; «выкл» — не покупать."),
    "%s: Up to refreshed from usual prices and this list's allowance for %d items. Change any you like; \"off\" means don't buy it.":
        forms("%s: «До» обновлено по обычным ценам и допуску этого списка: %d предмет. Меняйте как угодно; «выкл» — не покупать.",
              "%s: «До» обновлено по обычным ценам и допуску этого списка: %d предмета. Меняйте как угодно; «выкл» — не покупать.",
              "%s: «До» обновлено по обычным ценам и допуску этого списка: %d предметов. Меняйте как угодно; «выкл» — не покупать."),
    ", %d material short":
        forms(" (не хватает %d материала)", " (не хватает %d материалов)", " (не хватает %d материалов)"),
    ", %d materials short":
        forms(" (не хватает %d материала)", " (не хватает %d материалов)", " (не хватает %d материалов)"),
    "%d item has Up to off, so the queue skips it: type a price to buy it.":
        forms("У %d предмета «До» выкл, очередь его пропускает: введите цену, чтобы купить.",
              "У %d предметов «До» выкл, очередь их пропускает: введите цену, чтобы купить.",
              "У %d предметов «До» выкл, очередь их пропускает: введите цену, чтобы купить."),
    "%d items have Up to off, so the queue skips them: type a price to buy them.":
        forms("У %d предмета «До» выкл, очередь его пропускает: введите цену, чтобы купить.",
              "У %d предметов «До» выкл, очередь их пропускает: введите цену, чтобы купить.",
              "У %d предметов «До» выкл, очередь их пропускает: введите цену, чтобы купить."),
    # Crates: the fill was put on a shopping list of its own.
    "Added %d item for %s to the shopping list \"%s\". Set the crate's Want there to fill more than one; tick Buy from this list in the Buy queue to buy what you're short (/fl lists). The list goes when you fill the last crate.":
        forms("Добавлен %d предмет за %s в список покупок «%s». Задайте «Нужно» у ящика там, чтобы заполнить несколько; отметьте «Покупать из этого списка» в очереди, чтобы докупить недостающее (/fl lists). Список исчезнет после последнего ящика.",
              "Добавлено %d предмета за %s в список покупок «%s». Задайте «Нужно» у ящика там, чтобы заполнить несколько; отметьте «Покупать из этого списка» в очереди, чтобы докупить недостающее (/fl lists). Список исчезнет после последнего ящика.",
              "Добавлено %d предметов за %s в список покупок «%s». Задайте «Нужно» у ящика там, чтобы заполнить несколько; отметьте «Покупать из этого списка» в очереди, чтобы докупить недостающее (/fl lists). Список исчезнет после последнего ящика."),
    "Added %d items for %s to the shopping list \"%s\". Set the crate's Want there to fill more than one; tick Buy from this list in the Buy queue to buy what you're short (/fl lists). The list goes when you fill the last crate.":
        forms("Добавлен %d предмет за %s в список покупок «%s». Задайте «Нужно» у ящика там, чтобы заполнить несколько; отметьте «Покупать из этого списка» в очереди, чтобы докупить недостающее (/fl lists). Список исчезнет после последнего ящика.",
              "Добавлено %d предмета за %s в список покупок «%s». Задайте «Нужно» у ящика там, чтобы заполнить несколько; отметьте «Покупать из этого списка» в очереди, чтобы докупить недостающее (/fl lists). Список исчезнет после последнего ящика.",
              "Добавлено %d предметов за %s в список покупок «%s». Задайте «Нужно» у ящика там, чтобы заполнить несколько; отметьте «Покупать из этого списка» в очереди, чтобы докупить недостающее (/fl lists). Список исчезнет после последнего ящика."),
    # Characters tab.
    "%d character": forms("%d персонаж", "%d персонажа", "%d персонажей"),
    "%d characters": forms("%d персонаж", "%d персонажа", "%d персонажей"),
    # Crates.
    "Shopping list \"%s\": %d crate left to fill.":
        forms("Список покупок «%s»: осталось заполнить %d ящик.",
              "Список покупок «%s»: осталось заполнить %d ящика.",
              "Список покупок «%s»: осталось заполнить %d ящиков."),
    "Shopping list \"%s\": %d crates left to fill.":
        forms("Список покупок «%s»: осталось заполнить %d ящик.",
              "Список покупок «%s»: осталось заполнить %d ящика.",
              "Список покупок «%s»: осталось заполнить %d ящиков."),
    # Deals: the empty state count, the neutral table's summary and the deals'.
    "Nothing here matches the filter: %d deal is hidden by it. Click All, or clear the search box.":
        forms("Ничего не подходит под фильтр: он скрыл %d сделку. Нажмите «Все» или очистите поиск.",
              "Ничего не подходит под фильтр: он скрыл %d сделки. Нажмите «Все» или очистите поиск.",
              "Ничего не подходит под фильтр: он скрыл %d сделок. Нажмите «Все» или очистите поиск."),
    "Nothing here matches the filter: %d deals are hidden by it. Click All, or clear the search box.":
        forms("Ничего не подходит под фильтр: он скрыл %d сделку. Нажмите «Все» или очистите поиск.",
              "Ничего не подходит под фильтр: он скрыл %d сделки. Нажмите «Все» или очистите поиск.",
              "Ничего не подходит под фильтр: он скрыл %d сделок. Нажмите «Все» или очистите поиск."),
    "%d item": forms("%d предмет", "%d предмета", "%d предметов"),
    "%d items": forms("%d предмет", "%d предмета", "%d предметов"),
    "%d deal": forms("%d сделка", "%d сделки", "%d сделок"),
    "%d deals": forms("%d сделка", "%d сделки", "%d сделок"),
    # Quests in tooltips, and the Darkmoon line.
    "and %d more quest": forms("и ещё %d задание", "и ещё %d задания", "и ещё %d заданий"),
    "and %d more quests": forms("и ещё %d задание", "и ещё %d задания", "и ещё %d заданий"),
    # Shopping lists: what was added and what is searched for.
    "Added %d item for %s to shopping list \"%s\". Check Want and Up to there; the Buy queue buys from the list while Buy from this list in the Buy queue is ticked (/fl lists).":
        forms("Добавлен %d предмет для %s в список покупок «%s». Проверьте там «Надо» и «До»; очередь покупает из списка, пока в ней отмечено «Покупать из этого списка» (/fl lists).",
              "Добавлено %d предмета для %s в список покупок «%s». Проверьте там «Надо» и «До»; очередь покупает из списка, пока в ней отмечено «Покупать из этого списка» (/fl lists).",
              "Добавлено %d предметов для %s в список покупок «%s». Проверьте там «Надо» и «До»; очередь покупает из списка, пока в ней отмечено «Покупать из этого списка» (/fl lists)."),
    "Added %d items for %s to shopping list \"%s\". Check Want and Up to there; the Buy queue buys from the list while Buy from this list in the Buy queue is ticked (/fl lists).":
        forms("Добавлен %d предмет для %s в список покупок «%s». Проверьте там «Надо» и «До»; очередь покупает из списка, пока в ней отмечено «Покупать из этого списка» (/fl lists).",
              "Добавлено %d предмета для %s в список покупок «%s». Проверьте там «Надо» и «До»; очередь покупает из списка, пока в ней отмечено «Покупать из этого списка» (/fl lists).",
              "Добавлено %d предметов для %s в список покупок «%s». Проверьте там «Надо» и «До»; очередь покупает из списка, пока в ней отмечено «Покупать из этого списка» (/fl lists)."),
    "Added %d item to shopping list \"%s\" for disenchanting. Check Want and Up to there; the Buy queue buys from the list while Buy from this list in the Buy queue is ticked (/fl lists).":
        forms("Добавлен %d предмет в список покупок «%s» на распыление. Проверьте там «Надо» и «До»; очередь покупает из списка, пока в ней отмечено «Покупать из этого списка» (/fl lists).",
              "Добавлено %d предмета в список покупок «%s» на распыление. Проверьте там «Надо» и «До»; очередь покупает из списка, пока в ней отмечено «Покупать из этого списка» (/fl lists).",
              "Добавлено %d предметов в список покупок «%s» на распыление. Проверьте там «Надо» и «До»; очередь покупает из списка, пока в ней отмечено «Покупать из этого списка» (/fl lists)."),
    "Added %d items to shopping list \"%s\" for disenchanting. Check Want and Up to there; the Buy queue buys from the list while Buy from this list in the Buy queue is ticked (/fl lists).":
        forms("Добавлен %d предмет в список покупок «%s» на распыление. Проверьте там «Надо» и «До»; очередь покупает из списка, пока в ней отмечено «Покупать из этого списка» (/fl lists).",
              "Добавлено %d предмета в список покупок «%s» на распыление. Проверьте там «Надо» и «До»; очередь покупает из списка, пока в ней отмечено «Покупать из этого списка» (/fl lists).",
              "Добавлено %d предметов в список покупок «%s» на распыление. Проверьте там «Надо» и «До»; очередь покупает из списка, пока в ней отмечено «Покупать из этого списка» (/fl lists)."),
    "Added the materials for %d craft of %s to shopping list \"%s\". Check Want and Up to there (/fl lists).":
        forms("Добавлены материалы на %d изготовление %s в список покупок «%s». Проверьте там «Надо» и «До» (/fl lists).",
              "Добавлены материалы на %d изготовления %s в список покупок «%s». Проверьте там «Надо» и «До» (/fl lists).",
              "Добавлены материалы на %d изготовлений %s в список покупок «%s». Проверьте там «Надо» и «До» (/fl lists)."),
    "Added the materials for %d crafts of %s to shopping list \"%s\". Check Want and Up to there (/fl lists).":
        forms("Добавлены материалы на %d изготовление %s в список покупок «%s». Проверьте там «Надо» и «До» (/fl lists).",
              "Добавлены материалы на %d изготовления %s в список покупок «%s». Проверьте там «Надо» и «До» (/fl lists).",
              "Добавлены материалы на %d изготовлений %s в список покупок «%s». Проверьте там «Надо» и «До» (/fl lists)."),
    "Imported %d list (%s) with %d items.":
        forms("Импортирован %d список (%s), предметов: %d.",
              "Импортировано %d списка (%s), предметов: %d.",
              "Импортировано %d списков (%s), предметов: %d."),
    "Imported %d lists (%s) with %d items.":
        forms("Импортирован %d список (%s), предметов: %d.",
              "Импортировано %d списка (%s), предметов: %d.",
              "Импортировано %d списков (%s), предметов: %d."),
    "Searching %d item from %s.":
        forms("Ищу %d предмет в %s.", "Ищу %d предмета в %s.", "Ищу %d предметов в %s."),
    "Searching %d items from %s.":
        forms("Ищу %d предмет в %s.", "Ищу %d предмета в %s.", "Ищу %d предметов в %s."),
    # Shuffles: how many days of scans the usual price rests on, and new deals.
    "Only %d day of your own scans.":
        forms("Всего %d день ваших проверок.", "Всего %d дня ваших проверок.", "Всего %d дней ваших проверок."),
    "Only %d days of your own scans.":
        forms("Всего %d день ваших проверок.", "Всего %d дня ваших проверок.", "Всего %d дней ваших проверок."),
    "%d day of your scans": forms("%d день ваших проверок", "%d дня ваших проверок", "%d дней ваших проверок"),
    "%d days of your scans": forms("%d день ваших проверок", "%d дня ваших проверок", "%d дней ваших проверок"),
    "%d new deal below the usual price: see Gold making, Deals (/fl)":
        forms("%d новая сделка ниже обычной цены: смотрите «Заработок», «Сделки» (/fl)",
              "%d новые сделки ниже обычной цены: смотрите «Заработок», «Сделки» (/fl)",
              "%d новых сделок ниже обычной цены: смотрите «Заработок», «Сделки» (/fl)"),
    "%d new deals below the usual price: see Gold making, Deals (/fl)":
        forms("%d новая сделка ниже обычной цены: смотрите «Заработок», «Сделки» (/fl)",
              "%d новые сделки ниже обычной цены: смотрите «Заработок», «Сделки» (/fl)",
              "%d новых сделок ниже обычной цены: смотрите «Заработок», «Сделки» (/fl)"),
    "%d new deal below the usual price: see Gold making, Deals (/fl).":
        forms("%d новая сделка ниже обычной цены: смотрите «Заработок», «Сделки» (/fl).",
              "%d новые сделки ниже обычной цены: смотрите «Заработок», «Сделки» (/fl).",
              "%d новых сделок ниже обычной цены: смотрите «Заработок», «Сделки» (/fl)."),
    "%d new deals below the usual price: see Gold making, Deals (/fl).":
        forms("%d новая сделка ниже обычной цены: смотрите «Заработок», «Сделки» (/fl).",
              "%d новые сделки ниже обычной цены: смотрите «Заработок», «Сделки» (/fl).",
              "%d новых сделок ниже обычной цены: смотрите «Заработок», «Сделки» (/fl)."),
    # Sync.
    "Sync: filled in %d day of price history from %s.":
        forms("Синхронизация: дополнен %d день истории цен от %s.",
              "Синхронизация: дополнено %d дня истории цен от %s.",
              "Синхронизация: дополнено %d дней истории цен от %s."),
    "Sync: filled in %d days of price history from %s.":
        forms("Синхронизация: дополнен %d день истории цен от %s.",
              "Синхронизация: дополнено %d дня истории цен от %s.",
              "Синхронизация: дополнено %d дней истории цен от %s."),
    "Sync turned off. Removed %d character from %s; the auction prices stay.":
        forms("Синхронизация выключена. Удалён %d персонаж из %s; цены аукциона остались.",
              "Синхронизация выключена. Удалено %d персонажа из %s; цены аукциона остались.",
              "Синхронизация выключена. Удалено %d персонажей из %s; цены аукциона остались."),
    "Sync turned off. Removed %d characters from %s; the auction prices stay.":
        forms("Синхронизация выключена. Удалён %d персонаж из %s; цены аукциона остались.",
              "Синхронизация выключена. Удалено %d персонажа из %s; цены аукциона остались.",
              "Синхронизация выключена. Удалено %d персонажей из %s; цены аукциона остались."),
    # Watch list.
    "%d watched. Green: at or under Up to right now.":
        forms("Наблюдаем: %d предмет. Зелёное — сейчас по «До» или дешевле.",
              "Наблюдаем: %d предмета. Зелёное — сейчас по «До» или дешевле.",
              "Наблюдаем: %d предметов. Зелёное — сейчас по «До» или дешевле."),
    # Chains: how the steps carry on.
    "%d more steps": forms("ещё %d шаг", "ещё %d шага", "ещё %d шагов"),
    # Groups tab: the source appends only "s", so the rendered sentence is the key
    # and the number picks the Russian form of the whole line.
    "Used by %d group: %s. A change here reaches all of them.":
        forms("Используется в %d группе: %s. Изменение здесь затронет всех.",
              "Используется в %d группах: %s. Изменение здесь затронет всех.",
              "Используется в %d группах: %s. Изменение здесь затронет всех."),
    "Used by %d groups: %s. A change here reaches all of them.":
        forms("Используется в %d группе: %s. Изменение здесь затронет всех.",
              "Используется в %d группах: %s. Изменение здесь затронет всех.",
              "Используется в %d группах: %s. Изменение здесь затронет всех."),
    "Delete your rule %s? %d group using it go back to Same as above. This can't be undone.":
        forms("Удалить ваше правило «%s»? %d группа вернётся к «Как выше». Отменить нельзя.",
              "Удалить ваше правило «%s»? %d группы вернутся к «Как выше». Отменить нельзя.",
              "Удалить ваше правило «%s»? %d групп вернутся к «Как выше». Отменить нельзя."),
    "Delete your rule %s? %d groups using it go back to Same as above. This can't be undone.":
        forms("Удалить ваше правило «%s»? %d группа вернётся к «Как выше». Отменить нельзя.",
              "Удалить ваше правило «%s»? %d группы вернутся к «Как выше». Отменить нельзя.",
              "Удалить ваше правило «%s»? %d групп вернутся к «Как выше». Отменить нельзя."),
    "%d item.": forms("%d предмет.", "%d предмета.", "%d предметов."),
    "%d items.": forms("%d предмет.", "%d предмета.", "%d предметов."),
    "%d sellers": forms("%d продавец", "%d продавца", "%d продавцов"),
    # Scan status and sync history: the item or day word is a suffix in the source.
    "Searching %d item from %s.":
        forms("Ищу %d предмет в %s.", "Ищу %d предмета в %s.", "Ищу %d предметов в %s."),
    "Searching %d items from %s.":
        forms("Ищу %d предмет в %s.", "Ищу %d предмета в %s.", "Ищу %d предметов в %s."),
    "Sync: filled in %d day of price history from %s.":
        forms("Синхронизация: дополнено %d день истории цен от %s.",
              "Синхронизация: дополнено %d дня истории цен от %s.",
              "Синхронизация: дополнено %d дней истории цен от %s."),
    "Sync: filled in %d days of price history from %s.":
        forms("Синхронизация: дополнено %d день истории цен от %s.",
              "Синхронизация: дополнено %d дня истории цен от %s.",
              "Синхронизация: дополнено %d дней истории цен от %s."),
    # Ledger, By item: the summary and the tooltip's profit line count one noun each.
    "%d items: spent %s, got %s, resold profit %s%s   %s":
        forms("%d предмет: потрачено %s, получено %s, прибыль с перепродажи %s%s   %s",
              "%d предмета: потрачено %s, получено %s, прибыль с перепродажи %s%s   %s",
              "%d предметов: потрачено %s, получено %s, прибыль с перепродажи %s%s   %s"),
    "Profit on %d resold":
        forms("Прибыль с %d перепроданного", "Прибыль с %d перепроданных", "Прибыль с %d перепроданных"),
}

# -- Messages Russian phrases differently ------------------------------------
MANUAL = {
    # The Groups tab builds these labels from pieces ("Same as " .. name), so the
    # assembled line is the key. The rule names come from KIND_LABEL.
    "Same as %s": "Как в «%s»",
    "Same as above (default)": "Как выше (по умолчанию)",
    "Your rule: %s": "Ваше правило: %s",
    "Changed on %s": "Изменено в «%s»",
    "Default (set on %s)": "По умолчанию (задано в «%s»)",
    "Default post": "По умолчанию: выставление",
    "Default buy": "По умолчанию: покупка",
    "Default vendor": "По умолчанию: торговец",
    "Default craft": "По умолчанию: изготовление",
    "Post rule": "Правило выставления",
    "Buy rule": "Правило покупки",
    "Vendor rule": "Правило торговца",
    "Craft rule": "Правило изготовления",
    "Post · %d": "Выставление · %d",
    "Buy · %d": "Покупка · %d",
    "Vendor · %d": "Торговец · %d",
    "Craft · %d": "Изготовление · %d",
    "%s › %s · %s": "%s › %s · %s",
    "%d items, the first %d shown.": "Предметов: %d, показаны первые %d.",
    "My post rule": "Моё правило: выставление",
    "My buy rule": "Моё правило: покупка",
    "My vendor rule": "Моё правило: торговец",
    "My craft rule": "Моё правило: изготовление",
    # Restoring built-in groups: each count carries its own suffix, so every rendered
    # wording is a key of its own.
    "Restore the built-in groups to their defaults?\n\n%d item you added taken out, %d you took out put back, %d rule you changed back to Default.\n\nYour own groups and saved rules stay. This can't be undone.":
        "Вернуть встроенные группы к наборам по умолчанию?\n\nУйдёт добавленных вами: %d. Вернётся убранных: %d. Правил, которые вы меняли, вернётся к «По умолчанию»: %d.\n\nВаши группы и сохранённые правила останутся. Отменить нельзя.",
    "Restore the built-in groups to their defaults?\n\n%d item you added taken out, %d you took out put back, %d rules you changed back to Default.\n\nYour own groups and saved rules stay. This can't be undone.":
        "Вернуть встроенные группы к наборам по умолчанию?\n\nУйдёт добавленных вами: %d. Вернётся убранных: %d. Правил, которые вы меняли, вернётся к «По умолчанию»: %d.\n\nВаши группы и сохранённые правила останутся. Отменить нельзя.",
    "Restore the built-in groups to their defaults?\n\n%d items you added taken out, %d you took out put back, %d rule you changed back to Default.\n\nYour own groups and saved rules stay. This can't be undone.":
        "Вернуть встроенные группы к наборам по умолчанию?\n\nУйдёт добавленных вами: %d. Вернётся убранных: %d. Правил, которые вы меняли, вернётся к «По умолчанию»: %d.\n\nВаши группы и сохранённые правила останутся. Отменить нельзя.",
    "Restore the built-in groups to their defaults?\n\n%d items you added taken out, %d you took out put back, %d rules you changed back to Default.\n\nYour own groups and saved rules stay. This can't be undone.":
        "Вернуть встроенные группы к наборам по умолчанию?\n\nУйдёт добавленных вами: %d. Вернётся убранных: %d. Правил, которые вы меняли, вернётся к «По умолчанию»: %d.\n\nВаши группы и сохранённые правила останутся. Отменить нельзя.",
    # Writs: two counts in one line, so both read as a colon list and no noun inflects.
    "%d orders, %d with a price.   %s": "Заказов: %d, с ценой: %d.   %s",
    # Writs: the shopping list line counts two nouns, and both words are part of the
    # rendered text, so every word pair is a key of its own; Russian lists the counts.
    **{
        'Shopping list "%s": %d {i} for %d {o}, each up to the highest price the plan '
        'paid.%s Tick Buy from this list in the Buy queue (/fl lists).'.format(i=i, o=o):
        "Список покупок «%s»: предметов: %d, заказов: %d, каждый по самой высокой цене из плана.%s "
        "Отметьте «Покупать из этого списка» в очереди (/fl lists)."
        for i in ("item", "items") for o in ("order", "orders")
    },
    # Essences: the kind is joined in the middle of the label.
    "Combine into Greater %s Essence": "Соединить в большую эссенцию (%s)",
    "Split into Lesser %s Essence": "Разделить на малые эссенции (%s)",
    # Gold making: the who column and the profit unit are joined in the code.
    "Known by %s": "Знает: %s",
    "%s each": "%s за штуку",
    # Tooltips: the colour-coded tail is translated on its own.
    "added by you": "добавлено вами",
    "can't be bought": "нельзя купить",
    # Tooltip: price history line and the Shift/Ctrl hints.
    "  typical, last %d day": forms("  обычно за %d день", "  обычно за %d дня", "  обычно за %d дней"),
    "  typical, last %d days": forms("  обычно за %d день", "  обычно за %d дня", "  обычно за %d дней"),
    "Shift for the ": "Shift — ",
    "Ctrl for price history": "Ctrl — история цен",
    " for a graph": " — график",
    " for a price graph": " — график цены",
    "Hold ": "Удерживайте ",
    "crafts and quests": "изготовление и задания",
    "crafts": "изготовление",
    "quests": "задания",
    # Disenchant bands: "Item level 5-10 green armor".
    "Item level %s blue armor": "Уровень предмета %s: синяя броня",
    "Item level %s blue weapons": "Уровень предмета %s: синее оружие",
    "Item level %s purple armor": "Уровень предмета %s: фиолетовая броня",
    "Item level %s purple weapons": "Уровень предмета %s: фиолетовое оружие",
    "Item level %s green armor": "Зелёная броня, уровень предмета %s",
    "Item level %s green weapons": "Зелёное оружие, уровень предмета %s",
    # Core import summary: two counts, phrased so neither needs a plural form.
    "Imported %d characters and %d prices.": "Импортировано: персонажей — %d, цен — %d.",
    # Ride fund names (Training.lua).
    "Apprentice Riding": "Ученик наездника",
    "Riding at 40": "Езда на 40",
    "Journeyman Riding": "Наездник",
    "Epic riding at 60": "Эпическая езда на 60",
    # Deals: the sell-speed word when there is none yet.
    "None": "Нет",
    # Auction house: the disenchant finder's list name parts.
    "Disenchant: item level ": "Распыление: уровень предмета ",
    " (worth disenchanting)": " (стоит распыления)",
    "armor and weapons": "броня и оружие",
    "no types": "нет типов",
    # Counted sentences that read as a whole.
    "%d of %d items done%s. Open the auction house to search and buy.":
        "%d из %d предметов готово%s. Откройте аукцион для поиска и покупки.",
    "%d of %d done. %d at your price%s: in the buy queue.":
        "%d из %d готово. %d по вашей цене%s: в очереди покупок.",
    "|cff7fd39cYou have all the materials:|r %d to craft, then it's complete.":
        "|cff7fd39cВсе материалы есть:|r изготовить %d, и готово.",
    "Searching %d items from a test list.": "Ищу %d предметов из тестового списка.",
    # Darkmoon tickets: the ticket count would need its own plural form, so the
    # line says how many go in and how many tickets come out without a noun.
    "Darkmoon Faire: %d for %d ticket (%s)": "Ярмарка Новолуния: %d за %d (%s)",
    "Darkmoon Faire: %d for %d tickets (%s)": "Ярмарка Новолуния: %d за %d (%s)",
    # Customers: work log lines are built by concatenation.
    "Enchanted ": "Зачаровано ",
    "Gave ": "Отдал ",
    " more": " ещё ",
    "(this one)": "(этот)",
    # Numbers the sentence itself shows.
    "Gold over %s": "Золото за %s",
    "top: %s": "лучшее: %s",
    "Used by: %s": "Используют: %s",
    "last seen %s": "последний раз %s",
    "New list: %s": "Новый список: %s",
    "Profit %s": "Прибыль %s",
    # Settings help values.
    "Default: %s.": "По умолчанию: %s.",
    "Default: Auto.": "По умолчанию: авто.",
    "Default: %g%s.": "По умолчанию: %g%s.",
    "Default: %d%s.": "По умолчанию: %d%s.",
    "off": "выкл",
    # Crate names have a prefix the addon adds itself.
    "Crate: ": "Ящик: ",
    "  in bags": "  в сумках",
    # Shuffles table pair labels.
    "Based on": "На основе",
    # Recipes tab: "none on AH", the auction house word.
    "  none on AH": "  на аукционе нет",
    "AH": "АУК",
    # UI subtab labels.
    "Sells on the auction house": "Продажа на аукционе",
    "Sells to a vendor": "Продажа торговцу",
    # Help: the one topic the Russian build merged into its neighbours.
    "Also": "Также",
    "Disenchant results, which of your recipes use it, and the cheapest crate fill.":
        "Результаты распыления, какие ваши рецепты его используют, и самое дешёвое заполнение ящика.",
    # Auction house: the deposit in the "cancel undercut" question.
    "its deposit": "его залог",
    "their deposits": "их залоги",
    "the crate": "ящик",
    " Not added (not seen in a scan yet): ": " Не добавлено (ещё не видно в проверках): ",
    # How long ago ("5m ago"): ns.Age builds these before any wrapper sees them.
    "%dm ago": "%d мин назад",
    "%dh ago": "%d ч назад",
    "%dd ago": "%d дн назад",
    # Money ranges ("2g to 3g") read with a dash in Russian.
    # Buy queue: why the last items stayed unbought.
    "That's everything you can buy: the %d left %s more than %s, or %s waiting for a lower price.":
        "Это всё, что можно купить: осталось %d — %s дороже, чем %s, или %s более низкой цены.",
    "costs": "стоит",
    "cost": "стоят",
    "your limit allows": "позволяет лимит",
    "you have": "у вас есть",
    "is": "ждёт",
    "are": "ждут",
    # Essences: greater and lesser, by kind.
    "Combine into Greater Magic Essence": "Соединить в большую эссенцию (магии)",
    "Combine into Greater Astral Essence": "Соединить в большую эссенцию (астральная)",
    "Combine into Greater Mystic Essence": "Соединить в большую эссенцию (мистическая)",
    "Combine into Greater Nether Essence": "Соединить в большую эссенцию (Пустоты)",
    "Combine into Greater Eternal Essence": "Соединить в большую эссенцию (вечная)",
    "Split into Lesser Magic Essence": "Разделить на малые эссенции (магии)",
    "Split into Lesser Astral Essence": "Разделить на малые эссенции (астральная)",
    "Split into Lesser Mystic Essence": "Разделить на малые эссенции (мистическая)",
    "Split into Lesser Nether Essence": "Разделить на малые эссенции (Пустоты)",
    "Split into Lesser Eternal Essence": "Разделить на малые эссенции (вечная)",
    "1 more step": "ещё 1 шаг",
    # Buy queue: "Craft them (2 pcs)".
    "Craft them (%d %s)": "Изготовить (%d %s)",
    "Craft them (%d craft)": "Изготовить (%d шт.)",
    "Craft them (%d crafts)": "Изготовить (%d шт.)",
    "pcs": "шт.",
    # Buy queue: the list header, its version filter and the craft-or-buy tooltip.
    "%s  |cff888888%d to buy|r%s": "%s  |cff888888к покупке: %d|r%s",
    "scroll anywhere here to buy": "прокрутите в любом месте, чтобы купить",
    "scroll here to buy": "прокрутите здесь, чтобы купить",
    "click Buy, or tick Scroll to buy": "нажмите «Купить» или отметьте «Покупка колесом»",
    "%d listed, from %s": "лотов: %d, от %s",
    "%s: none listed": "%s: лотов нет",
    "This list wants only the \"%s\" version; Listed and Cheapest count just that one.":
        "В списке только версия «%s»; «Лотов» и «Минимум» считают только её.",
    "%s is cheaper by %s.%s": "%s дешевле на %s.%s",
    "Crafting": "Изготовление",
    "Buying": "Покупка",
    " Switch it to Craft with the button.": " Переключите на «Изготовление» кнопкой.",
    " Switch it to Buy with the button.": " Переключите на «Покупку» кнопкой.",
    "%d of %d up at the last check. Click an item to look at it on the auction house.":
        "%d из %d выставлено на последней проверке. Клик по предмету — посмотреть на аукционе.",
    "You can afford %d of the %d cheap ones with %s%s, so the profit shown is for those. All %d would make %s.":
        "Вам хватает на %d из %d дешёвых за %s%s, поэтому прибыль показана для них. Все %d дали бы %s.",
    " left to spend": " останется потратить",
    # Dashboard, Ledger and Post.
    "%s a day": "%s в день",
    "%s%d selected:|r in %s, out %s, net %s": "%sвыбрано: %d|r приход %s, расход %s, итог %s",
    "%d in your bags": "%d в сумках",
    "%s. |cff9fe8dcRule from: %s.|r": "%s. |cff9fe8dcПравило: %s.|r",
    # Recipes tab.
    "%d listed, scanned %s": "лотов: %d, проверка %s",
    "%s: %d recipes, %d known. Showing %d%s. (Classic) = original Classic data, unconfirmed in Forever until you see it.":
        "%s: рецептов %d, изучено %d. Показано %d%s. (Classic) — данные оригинального Classic, в Forever не подтверждены, пока вы их не увидите.",
    "%d trainers seen, %d from city guards, %d more from Classic (unconfirmed). Ask a guard for a profession trainer to add Forever's real spot.":
        "Тренеров найдено: %d, от городских стражников: %d, ещё из Classic: %d (не подтверждено). Спросите стражника о тренере профессии, чтобы добавить настоящее место в Forever.",
    "%s has %d recipe recorded, but none match what's chosen above (%s). Choose All to see them.":
        "%s: записано рецептов — %d, но ни один не подходит под выбранное выше (%s). Выберите «Все», чтобы увидеть их.",
    "%s has %d recipes recorded, but none match what's chosen above (%s). Choose All to see them.":
        "%s: записано рецептов — %d, но ни один не подходит под выбранное выше (%s). Выберите «Все», чтобы увидеть их.",
    # Sell advice.
    "%s's %s uses it": "%s использует его (%s)",
    # Shuffles profit line and the status lines above the tables.
    "%sProfit %s %s (%d%%)%s.": "%sПрибыль %s %s (%d%%)%s.",
    "each": "за штуку",
    "per craft": "за изготовление",
    "%d shuffles, %d vendor flips (%s). Click to search the AH, right-click for details.":
        "Цепочек: %d, перепродаж торговцу: %d (%s). Клик — поиск на аукционе, правый клик — подробности.",
    "%d shuffles, %d vendor flips (%s). %s": "Цепочек: %d, перепродаж торговцу: %d (%s). %s",
    "Click to search the AH, right-click for details.": "Клик — поиск на аукционе, правый клик — подробности.",
    "Click a column to sort, a row for details.": "Клик по столбцу — сортировка, по строке — подробности.",
    "%s%s at %s  %s": "%s%s по %s  %s",
    "%d listed": "%d в продаже",
    "from a vendor": "у торговца",
}

# Same English source, different Russian in our tree: pick the one this place wants.
OVERRIDES = {
    "Cancel": "Отмена",
    "Cheap": "Дешёвых",
    "Each": "За шт.",
    "Sells": "Сбыт",
    "Shuffle": "Цепочка",
    "Stop watching": "Не следить",
    "Craft": "Изготовить",
    "Disenchant": "Распылить",
    "New": "Новый",
    "Sold": "Продано",
    "Undercut": "Перебить",
    "Yours": "Ваши",
    "armor": "броня",
    "weapons": "оружие",
    "Full scan: Ready": "Полная проверка: готова",
    "Search my lists": "Искать списки",
    "Rename": "Переименовать",
    "Post anyway": "Всё равно",
    "Add to shopping list": "В список покупок",
    "Auction house": "Аукцион",
    "Vendor": "Торговец",
    "Item": "Предмет",
    "Watch flips": "Следить",
    "Silence": "Приглушить",
    "all time": "всё время",
    "this month": "за месяц",
    "your auctions": "ваши лоты",
    "sell to vendor": "продать торговцу",
    "Sell to vendor": "Продажа торговцу",
    "Export / import": "Экспорт и импорт",
    "Usual price + %g%% (this list's allowance). Refreshed when buying is switched on or on Buy again.":
        "Обычная цена + %g%% (допуск этого списка). Обновляется при включении покупки или по «Купить снова».",
    # The localization branch is still on the version where Deals and Shuffles have
    # their own tabs; 0.27 renamed these keys, so keep the wording that matches it.
    "Buy vendor flips": "Покупайте предметы для перепродажи торговцу",
    "Find deals": "Ищите сделки",
    "Open Deals": "Открыть сделки",
    "Right-click for shuffles.": "Правый клик — цепочки.",
    "The Deals tab (/fl deals list in chat).": "Вкладка «Сделки» (/fl deals list — списком в чате).",
    "The Deals tab lists items selling well below their usual price, to buy and resell.":
        "Вкладка «Сделки» показывает предметы заметно ниже обычной цены — для покупки и перепродажи.",
}


# Our tree merged these into wording the table below covers in full; the generic
# English template would drop a placeholder, so it is not part of the table.
BLACKLIST = {
    "Item level %s %s %s",
}


def lua_string(text):
    return '"' + (text.replace("\\", "\\\\").replace('"', '\\"')
                  .replace("\n", "\\n").replace("\r", "\\r")) + '"'


def main():
    report = "--report" in sys.argv
    found, unusable = collect()
    mapping = defaultdict(Counter)
    for a, b in found:
        mapping[a][b] += 1
    auto = {a: c.most_common(1)[0][0] for a, c in mapping.items()}
    auto.update(OVERRIDES)
    auto.update(MANUAL)
    # A plural form wins over a single translation for the same key.
    table = dict(auto)
    table.update(PLURAL)
    for key in BLACKLIST | diagnostic_keys():
        table.pop(key, None)

    if report:
        print(f"пар: {len(found)}, ключей: {len(auto)}, форм: {len(PLURAL)}, "
              f"строк под ручную работу: {len(unusable)}", file=sys.stderr)
        for name, line, pl, rl in unusable:
            print(f"{name}:{line}  {pl}", file=sys.stderr)
        return

    out = ["if GetLocale() ~= \"ruRU\" then return end",
           "",
           "local _, ns = ...",
           "-- Russian: every message, label and tooltip line Forever Ledger shows, keyed by",
           "-- the English source it replaces. A table of three strings is a counted noun: the",
           "-- core picks the form the number needs (language.forms below).",
           "local language = { strings = {}, short = {}, upper = {} }",
           "",
           "-- The Russian client ships a Cyrillic copy of the UI font; a Latin build of the",
           "-- client doesn't, so it is used only when it loads.",
           "do",
           "  local path = \"Fonts\\\\FRIZQT___CYR.TTF\"",
           "  local probe = CreateFrame(\"Frame\"):CreateFontString()",
           "  local ok, loaded = pcall(probe.SetFont, probe, path, 12, \"\")",
           "  if ok and loaded ~= false and probe:GetFont() then",
           "    language.font = path",
           "  end",
           "end",
           "local dictionary = language.strings",
           ""]
    for key in sorted(table):
        value = table[key]
        if isinstance(value, tuple):
            body = ", ".join(lua_string(v) for v in value)
            out.append(f"dictionary[{lua_string(key)}] = {{ {body} }}")
        else:
            out.append(f"dictionary[{lua_string(key)}] = {lua_string(value)}")
    out.append("")
    out.append("-- Short templates a pattern can match: the core only builds patterns for")
    out.append("-- strings with five letters to spare, and counted nouns are shorter.")
    short = sorted(k for k in table if SPEC.search(k) and
                   len(re.sub(r"[^A-Za-z]", "", SPEC.sub("", k))) < 5)
    for key in short:
        out.append(f"language.short[{lua_string(key)}] = true")
    out.append("")
    out.append("-- A price range the addon builds itself (\"2g 50s to 3g\") reads with a dash.")
    out.append("-- Only a number, its money units and \"to\" between them are touched.")
    out.append("function language.TransformVisible(s)")
    out.append("  return (s:gsub(\"(%d[%w%s]-%s)to(%s%d)\", \"%1—%2\"))")
    out.append("end")
    out.append("")
    out.append("-- Three forms of a counted noun, chosen by the first number shown:")
    out.append("-- 1 день, 2 дня, 5 дней. The core asks for a form only when an entry is a")
    out.append("-- table of three.")
    out.append("function language.forms(n)")
    out.append("  n = math.abs(tonumber(n) or 0)")
    out.append("  local mod100, mod10 = n % 100, n % 10")
    out.append("  if mod100 >= 11 and mod100 <= 14 then return 3 end")
    out.append("  if mod10 == 1 then return 1 end")
    out.append("  if mod10 >= 2 and mod10 <= 4 then return 2 end")
    out.append("  return 3")
    out.append("end")
    out.append("")
    out.append("for english, translated in pairs(language.strings) do")
    out.append("  if type(translated) == \"string\" then")
    out.append("    language.upper[string.upper(english)] = translated")
    out.append("  end")
    out.append("end")
    out.append("ns.RegisterLocale(\"ruRU\", language)")
    out.append("")
    OUT.write_text("\n".join(out), encoding="utf-8")
    print(f"Locales/ruRU.lua: {len([k for k in table])} строк", file=sys.stderr)


if __name__ == "__main__":
    main()
