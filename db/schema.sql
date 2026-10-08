-- Схема базы данных Pokédex Tracker (SQLite).
-- Справочные таблицы заполняет скрипт scripts/build_db.py,
-- пользовательские (users, profiles, catch_records) и ручные локации — приложение.
-- В приложении после открытия файла выполнить: PRAGMA foreign_keys = ON;

-- ============ Справочник: игры ============

-- Игра: пара версий, одиночная игра или национальный покедекс (code = 'national')
CREATE TABLE games (
    id          INTEGER PRIMARY KEY,
    code        TEXT    NOT NULL UNIQUE,          -- 'rb', 'swsh', 'national'
    title       TEXT    NOT NULL,                 -- 'Sword / Shield'
    generation  INTEGER CHECK (generation BETWEEN 1 AND 9)  -- NULL у национального покедекса
);

-- Версия игры: у пары две, у одиночной игры одна, у национального покедекса нет
CREATE TABLE versions (
    id       INTEGER PRIMARY KEY,
    game_id  INTEGER NOT NULL REFERENCES games(id),
    code     TEXT    NOT NULL UNIQUE,             -- 'red', 'sword'
    name     TEXT    NOT NULL                     -- 'Sword'
);

-- Региональный покедекс игры (у Sword/Shield их три: Galar, Isle of Armor, Crown Tundra)
CREATE TABLE regional_dexes (
    id          INTEGER PRIMARY KEY,
    game_id     INTEGER NOT NULL REFERENCES games(id),
    name        TEXT    NOT NULL,                 -- 'Galar'
    sort_order  INTEGER NOT NULL                  -- порядок дексов внутри игры
);

-- Вид в региональном покедексе и его номер там (номер относится к виду, а не к форме)
CREATE TABLE regional_dex_entries (
    dex_id       INTEGER NOT NULL REFERENCES regional_dexes(id),
    number       INTEGER NOT NULL,                -- номер в региональном дексе
    national_no  INTEGER NOT NULL,                -- номер вида в национальном покедексе
    PRIMARY KEY (dex_id, number),
    UNIQUE (dex_id, national_no)
);

-- ============ Справочник: покемоны ============

-- Запись покедекса: покемон в конкретной форме и (если есть отличие) поле
CREATE TABLE pokemon (
    id               INTEGER PRIMARY KEY,
    code             TEXT    NOT NULL UNIQUE,     -- 'rattata-1'; по нему называются картинки sprites/<code>.png
    national_no      INTEGER NOT NULL CHECK (national_no BETWEEN 1 AND 1025),
    name             TEXT    NOT NULL,            -- 'Rattata'
    form             TEXT,                        -- 'Alolan'; NULL — обычная форма
    gender           TEXT    CHECK (gender = 'female'),  -- 'female' — отдельная запись самки; иначе NULL
    type1            TEXT    NOT NULL,
    type2            TEXT,
    generation       INTEGER NOT NULL CHECK (generation BETWEEN 1 AND 9),
    shiny_available  INTEGER NOT NULL CHECK (shiny_available IN (0, 1)),
    evolves_from_id  INTEGER REFERENCES pokemon(id)  -- запись-предок; NULL — нет предка
);

-- Место покемона в типе декса (final / living / living_forms) и его порядок там
CREATE TABLE dex_entries (
    dex_type    TEXT    NOT NULL CHECK (dex_type IN ('final', 'living', 'living_forms')),
    pokemon_id  INTEGER NOT NULL REFERENCES pokemon(id),
    sort_order  INTEGER NOT NULL,
    PRIMARY KEY (dex_type, pokemon_id),
    UNIQUE (dex_type, sort_order)
);

-- В каких играх доступна именно эта форма; exclusive_version_id — если только в одной версии пары.
-- Национальный покедекс здесь не хранится: в нём доступны все записи (правило в коде).
CREATE TABLE game_pokemon (
    game_id               INTEGER NOT NULL REFERENCES games(id),
    pokemon_id            INTEGER NOT NULL REFERENCES pokemon(id),
    exclusive_version_id  INTEGER REFERENCES versions(id),
    PRIMARY KEY (game_id, pokemon_id)
);

-- ============ Справочник: локации ============

-- Локация в игре. added_by: NULL — из PokeAPI, иначе id менеджера, который её создал
CREATE TABLE locations (
    id        INTEGER PRIMARY KEY,
    game_id   INTEGER NOT NULL REFERENCES games(id),
    name      TEXT    NOT NULL,                   -- 'Route 204 (South towards Jubilife City)'
    added_by  INTEGER REFERENCES users(id),
    UNIQUE (game_id, name)
);

-- Покемон, встречающийся на локации. version_id: NULL — в обеих версиях пары
CREATE TABLE location_pokemon (
    id           INTEGER PRIMARY KEY,
    location_id  INTEGER NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
    pokemon_id   INTEGER NOT NULL REFERENCES pokemon(id),
    version_id   INTEGER REFERENCES versions(id),
    added_by     INTEGER REFERENCES users(id),    -- NULL — из PokeAPI
    UNIQUE (location_id, pokemon_id, version_id)
);

-- ============ Пользовательские данные ============

CREATE TABLE users (
    id             INTEGER PRIMARY KEY,
    login          TEXT    NOT NULL UNIQUE,
    password_hash  TEXT    NOT NULL,              -- SHA-256 пароля в шестнадцатеричном виде
    role           TEXT    NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'manager', 'admin')),
    theme          TEXT    NOT NULL DEFAULT 'kanto' CHECK (theme IN ('kanto', 'nightBox'))
);

-- Профиль: удаляется вместе с пользователем (композиция на диаграмме классов)
CREATE TABLE profiles (
    id          INTEGER PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name        TEXT    NOT NULL,
    game_id     INTEGER NOT NULL REFERENCES games(id),
    dex_type    TEXT    NOT NULL CHECK (dex_type IN ('final', 'living', 'living_forms')),
    shiny       INTEGER NOT NULL DEFAULT 0 CHECK (shiny IN (0, 1)),
    created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- Запись поимки: удаляется вместе с профилем. Строки со статусом 'none' можно не хранить
CREATE TABLE catch_records (
    profile_id  INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    pokemon_id  INTEGER NOT NULL REFERENCES pokemon(id),
    state       TEXT    NOT NULL CHECK (state IN ('none', 'has_prevo', 'caught')),
    updated_at  TEXT    NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (profile_id, pokemon_id)
);

-- ============ Индексы для частых запросов ============

CREATE INDEX idx_game_pokemon_pokemon  ON game_pokemon (pokemon_id);
CREATE INDEX idx_location_pokemon_pkm  ON location_pokemon (pokemon_id);
CREATE INDEX idx_locations_game        ON locations (game_id);
CREATE INDEX idx_pokemon_national_no   ON pokemon (national_no);
CREATE INDEX idx_profiles_user         ON profiles (user_id);
