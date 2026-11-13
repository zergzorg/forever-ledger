# Автор, репозиторий и вклад (на 12.11.2026)

## Официальный репозиторий

- GitHub: <https://github.com/ivellos/forever-ledger>
- Автор: **ivellos**
- Лицензия: **MIT** (форк и распространение разрешены)
- Issues и pull request'ы включены; репозиторий активен (последний push 11.11.2026).
- Страницы аддона: [CurseForge](https://www.curseforge.com/wow/addons/forever-ledger), [Wago](https://addons.wago.io/addons/forever-ledger).
- Discord: <https://discord.gg/WKsCtvupeC> — автор просит сообщать об ошибках и идеях туда (`/bug`, `/idea`).

## Состояние на 13.11.2026

- `main` ушёл на **0.23.0** (плюс `/fl api` после релиза); ядро локализации из PR #17 в `main` ещё не влито.
- 13.11 подтянуты новые коммиты: подсказка «продать или оставить» в подсказках предметов, «Все профессии» в цепочках и исправление истории цен при синхронизации.
- Ветка `ru` содержит полный перевод **0.23.0** и установлена в игру.
- Ветка `locale-ru` (отдельные `Locale.lua` и `Locales/ruRU.lua`) остаётся на базе 0.21.1 и ждёт слияния ядра из PR #17.

## Локализация в основной ветке

В `main` **нет** локализации: `GetLocale()` встречается только в тестовых заглушках.
Все строки английские, встроенного механизма переводов нет.

## Китайский PR — важный прецедент

- PR **#17**: «Add zhCN localization and optional ROI sorting for vendor flips»
- Автор: **yippp**, открыт 09.11.2026, обновлён 12.11.2026, **не влит**.
- 43 файла, +4419/−468; `mergeable: true`, но `mergeStateStatus: UNSTABLE`; ревью людей нет.
- Подход: отдельные `Locale_zhCN.lua`, `Translations_zhCN.lua`,
  `ExtraTranslations_zhCN.lua`, `LocaleHooks_zhCN.lua` + обёртки
  `ns.LocalizeText(...)` в местах вывода. Английский источник сохраняется,
  перевод подставляется во время показа; шрифты и денежные единицы — в `Theme`/хуках.
- В PR есть и посторонняя функция (сортировка vendor flips по ROI), из-за чего
  он не чистый «только перевод».

## Что это значит для русского

1. Готовый PR с переводом возможен, но в формате PR #17: таблица переводов +
   обёртки вывода, а не замена английского текста в файлах.
2. Сначала стоит согласовать формат: PR #17 ещё не принят, архитектура может
   измениться. Разумный шаг — issue (или комментарий в #17) с предложением
   ruRU и готовым объёмом перевода.
3. Наш текущий перевод — 2000+ строк; его можно перенести в таблицу
   `Translations_ruRU.lua`, но обёртки `ns.LocalizeText` всё равно нужно
   расставить по местам вывода (в PR #17 их 217).
4. Если автор согласится, перевод уходит в upstream и перестаёт теряться при
   обновлениях. Если нет — работает локальная схема с ветками `upstream`/`ru`.

## Черновик обращения (английский)

> Hi! I've made a full Russian (ruRU) localization of Forever Ledger 0.20.0:
> every tab, tooltip, setting, help topic and chat message, plus Cyrillic fonts,
> Russian plural forms, money units (g/s/c) and date formats.
>
> I saw PR #17 adds zhCN as a runtime translation layer with `ns.LocalizeText`.
> Is that the direction you want for other locales? If yes, I can prepare ruRU
> the same way (translation table + display hooks + font fallback) and open a PR.
> If you'd rather keep localization out of the addon, I'll publish it as a
> separate fork/addon instead.
>
> The translation is ready and tested on a ruRU client; nothing in WTF or saved
> data is touched.
