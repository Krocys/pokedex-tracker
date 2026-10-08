# Данные Pokédex Tracker

## Состав

```
pokedex-data/
├── db/
│   ├── pokedex.db       — база данных SQLite: её открывает приложение (sql.js)
│   └── schema.sql       — описание всех таблиц
├── sprites/             — картинки: <pokemon.code>.png
│   └── shiny/           — шайни-картинки: <pokemon.code>.png
├── data/                — промежуточные JSON, из которых собрана БД
├── scripts/             — как получены данные (сборка и проверка)
└── DATA.md
```

## Таблицы

Справочные таблицы заполнены при сборке. Пользовательские (`users`, `profiles`, `catch_records`) и локации менеджеров заполняет приложение и записывает файл обратно через File System Access API.

| Таблица | Строк | Что хранит | Ссылается на |
|---|---|---|---|
| `games` | 23 | Игры (пары, одиночные) и национальный покедекс | — |
| `versions` | 38 | Версии игр | `games` |
| `regional_dexes` | 29 | Региональные покедексы игр | `games` |
| `regional_dex_entries` | 6380 | Номер вида в региональном дексе | `regional_dexes` |
| `pokemon` | 1387 | Записи покедекса: покемон в форме и поле | `pokemon` (предок) |
| `dex_entries` | 3073 | Место записи в типе декса и порядок | `pokemon` |
| `game_pokemon` | 7406 | Где доступна форма и эксклюзив ли | `games`, `pokemon`, `versions` |
| `locations` | 2027 | Локации игр | `games`, `users` |
| `location_pokemon` | 23 835 | Кто встречается на локации | `locations`, `pokemon`, `versions`, `users` |
| `users` | 1 | Пользователи, роли, тема | — |
| `profiles` | 0 | Профили | `users`, `games` |
| `catch_records` | 0 | Статусы поимки | `profiles`, `pokemon` |

### games

| Поле | Тип | Описание |
|---|---|---|
| `id` | INTEGER, ключ | |
| `code` | TEXT, уникальный | `rb`, `swsh`, `national` |
| `title` | TEXT | `Sword / Shield` |
| `generation` | INTEGER | 1–9; NULL у национального покедекса |

### versions

| Поле | Тип | Описание |
|---|---|---|
| `id` | INTEGER, ключ | |
| `game_id` | → `games` | |
| `code` | TEXT, уникальный | `red`, `sword` |
| `name` | TEXT | `Sword` |

### regional_dexes, regional_dex_entries

| Поле | Тип | Описание |
|---|---|---|
| `regional_dexes.id` | INTEGER, ключ | |
| `regional_dexes.game_id` | → `games` | |
| `regional_dexes.name` | TEXT | `Galar`, `Isle of Armor` |
| `regional_dexes.sort_order` | INTEGER | порядок дексов в игре |
| `regional_dex_entries.dex_id` | → `regional_dexes` | |
| `regional_dex_entries.number` | INTEGER | номер в региональном дексе |
| `regional_dex_entries.national_no` | INTEGER | номер вида (связь с `pokemon.national_no`) |

Номер относится к виду, поэтому все формы вида стоят под одним номером.

### pokemon

| Поле | Тип | Описание |
|---|---|---|
| `id` | INTEGER, ключ | |
| `code` | TEXT, уникальный | `rattata-1`; имя файла картинки |
| `national_no` | INTEGER | номер в национальном покедексе |
| `name` | TEXT | английское имя |
| `form` | TEXT | `Alolan`; NULL — обычная форма |
| `gender` | TEXT | `female` — отдельная запись самки; иначе NULL |
| `type1`, `type2` | TEXT | типы; `type2` может быть NULL |
| `generation` | INTEGER | поколение вида |
| `shiny_available` | 0/1 | существует ли шайни этой формы |
| `evolves_from_id` | → `pokemon` | запись-предок; NULL — нет |

### dex_entries

| Поле | Тип | Описание |
|---|---|---|
| `dex_type` | TEXT | `final`, `living`, `living_forms` |
| `pokemon_id` | → `pokemon` | |
| `sort_order` | INTEGER | порядок в этом типе декса (национальный порядок) |

### game_pokemon

| Поле | Тип | Описание |
|---|---|---|
| `game_id` | → `games` | |
| `pokemon_id` | → `pokemon` | |
| `exclusive_version_id` | → `versions` | NULL — в обеих версиях; иначе эксклюзив |

### locations, location_pokemon

| Поле | Тип | Описание |
|---|---|---|
| `locations.id` | INTEGER, ключ | |
| `locations.game_id` | → `games` | |
| `locations.name` | TEXT | `Route 204 (South towards Jubilife City)` |
| `locations.added_by` | → `users` | NULL — из PokeAPI; иначе менеджер |
| `location_pokemon.location_id` | → `locations` | удаляется вместе с локацией |
| `location_pokemon.pokemon_id` | → `pokemon` | |
| `location_pokemon.version_id` | → `versions` | NULL — в обеих версиях |
| `location_pokemon.added_by` | → `users` | NULL — из PokeAPI |

### users, profiles, catch_records

| Поле | Тип | Описание |
|---|---|---|
| `users.login` | TEXT, уникальный | |
| `users.password_hash` | TEXT | SHA-256 пароля |
| `users.role` | TEXT | `user`, `manager`, `admin` |
| `users.theme` | TEXT | `kanto`, `nightBox` |
| `profiles.user_id` | → `users` | удаляется вместе с пользователем |
| `profiles.name` | TEXT | |
| `profiles.game_id` | → `games` | |
| `profiles.dex_type` | TEXT | `final`, `living`, `living_forms` |
| `profiles.shiny` | 0/1 | |
| `profiles.created_at` | TEXT | дата создания |
| `catch_records.profile_id` | → `profiles` | удаляется вместе с профилем |
| `catch_records.pokemon_id` | → `pokemon` | |
| `catch_records.state` | TEXT | `none`, `has_prevo`, `caught` |
| `catch_records.updated_at` | TEXT | дата изменения |

## Правила, которые живут в коде

- После открытия файла выполнить `PRAGMA foreign_keys = ON`, иначе SQLite не проверяет связи и не удаляет профили вместе с пользователем.
- Профиль игры `national` показывает все записи своего типа декса (в `game_pokemon` его нет).
- Шайни-профиль нельзя создать для игры 1 поколения.
- Связь эволюции показывается в профиле, только если обе записи доступны в игре профиля.
- Отсутствие строки в `catch_records` означает статус `none`.
- В БД есть первый администратор: логин `admin`, пароль `admin`. Сменить после первого входа.

## Источники

| Данные | Источник |
|---|---|
| Записи, формы, типы, шайни, формы в играх 8–9 поколения | таблицы Austin John (Pokémon HOME Organizer 1.4, июль 2026) |
| Региональные покедексы, эволюции, локации, картинки, сверка номеров | PokeAPI |
| Эксклюзивы | Bulbapedia, «Version-exclusive Pokémon» (версия от 11.09.2026) |
| Формы в играх 1–7 поколения | правила в `scripts/build_availability.py` |

## Известные ограничения

- Нет локаций для BDSP, Legends: Arceus, Scarlet/Violet, Legends: Z-A; в ORAS локации неполные. Это заполняет менеджер.
- Событийные покемоны (мифические, Pikachu в кепках) считаются доступными, если входят в покедекс игры.
- Доступность форм в играх 1–7 поколения задана правилами и может ошибаться в редких случаях.

## Сборка и проверка

Из корня проекта, по порядку: `build_pokemon.py` → `build_games.py` → `build_availability.py` → `build_locations.py` → `build_sprites.py` → `build_db.py`. Проверка: `check_data.py` (JSON) и `check_db.py` (БД).

`build_db.py` создаёт БД заново — после начала работы приложения его запуск сотрёт пользователей и данные менеджеров.
