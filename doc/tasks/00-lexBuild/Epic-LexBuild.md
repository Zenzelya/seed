# Epic: LexBuild — пайплайн формирования словаря DE→RU

**Дата:** 2026-05-19

## Оглавление

- [0. Конечный результат](#0-конечный-результат)
- [0.1 Решение по схеме БД: JSONB vs INTEGER bitmask](#01-решение-по-схеме-бд-jsonb-vs-integer-bitmask)
- [1. Исследование данных](#1-исследование-данных-backenddata)
- [2. Текущее состояние реализации](#2-текущее-состояние-реализации)
- [3. Источник word_forms — выбор стратегии](#3-источник-word_forms--выбор-стратегии)
- [4. Описание эпика](#4-описание-эпика)
- [5. Схема БД](#5-схема-бд-состояние-до-task-0)
- [6. MVP — список задач](#6-mvp--список-задач)
  - [TASK-0 · Сброс БД и оптимизация схемы](#task-0--сброс-бд-и-оптимизация-схемы)
  - [TASK-1 · Parser API + utils/jsonl.py](#task-1--parser-api--utilsjsonlpy-python)
  - [TASK-2 · Переименовать KaikkiEntry → DeExtractEntry](#task-2--переименовать-kaikkientry--deextractentry-и-дополнить-dto)
  - [TASK-3 · Forms pipeline (Python)](#task-3--forms-pipeline-python--генерация--слияние-с-дампом)
  - [TASK-4 · upsertWordForms — bitmask из Python](#task-4--обновить-upsertwordforms--принимать-bitmask-из-python)
  - [TASK-5 · Шаг pdf-seed + whitelist](#task-5--шаг-pdf-seed--whitelist-интеграция)
  - [TASK-6 · Шаг links — DE→RU концепты](#task-6--шаг-links--deru-концепты-nestjs)
  - [TASK-7 · freq — частотные карты](#task-7--freq--частотные-карты)
  - [TASK-8 · TUI — оркестрация шагов](#task-8--tui--оркестрация-шагов)
  - [TASK-9 · Coverage monitor](#task-9--coverage-monitor--мониторинг-состояния-связей)
- [7. Валидатор лемм](#7-валидатор-лемм)
- [8. Порядок реализации](#8-порядок-реализации)
- [9. Ожидаемый результат MVP](#9-ожидаемый-результат-mvp)
- [10. Тестирование](#10-тестирование)
- [11. Вне скопа MVP](#11-вне-скопа-mvp)
- [12. Разделение ответственности](#12-разделение-ответственности)

---

## 0. Конечный результат

### Что представляет собой система после завершения LexBuild

LexBuild — идемпотентный пайплайн наполнения PostgreSQL словарными данными. База заполняется **по необходимости проекта**: сначала MVP-словарь на основе PDF для отработки схемы и процессов, затем — полный словарь по той же схеме без изменений в архитектуре.

**Стратегия наполнения:**
1. **MVP** — PDF whitelist (~3–5K слов A1–B2): доказываем что схема БД, пайплайн и покрытие переводов работают корректно
2. **Полный словарь** — тот же код, те же процессы, без whitelist-фильтра, все источники данных подключены. Запускается когда MVP отточен до coverage A1–C1 = 100%

---

### Данные в БД после прогона

```
words (леммы)
  ├── ~3 000–5 000 DE-лемм из PDF (A1–C1, с формами и переводами)
  ├── ~1 400–2 400 RU-лемм (созданы из translations[] DE-записей)
  └── частоты из Wikipedia-корпусов

word_forms (словоформы, только DE)
  └── ~27 000–46 000 форм: склонения существительных, спряжения глаголов,
      все степени и типы склонения прилагательных
      каждая форма — 4 байта bitmask (POS + грамматические признаки + статус)

concepts (межъязыковые концепты)
  └── ~7 000–11 000 узлов-связок между DE и RU леммами

word_senses (привязка лемм к концептам)
  └── DE-лемма ←→ concept ←→ RU-лемма
      одно DE-слово может иметь несколько sense (многозначность)

sense_texts (определения)
  └── DE-глоссы из de.wiktionary для каждого sense
```

---

### Как это выглядит для одного слова

```
"Haus" (DE, noun, freq: 85 000)
  │
  ├── word_forms: Hauses, Häuser, Häusern, Haus, ...  (8 форм)
  │   каждая: features=0x0220 → {pos:noun, case:gen, number:sg, gender:n, ...}
  │
  ├── sense[1] → concept#4821
  │   ├── sense_text: "Gebäude, das Menschen als Wohnstätte dient"
  │   └── RU-лемма: "дом" (RU, noun, freq: 120 000)
  │
  └── sense[2] → concept#4822
      ├── sense_text: "Gebäude für einen bestimmten Zweck"
      └── RU-лемма: "здание" (RU, noun, freq: 45 000)
```

---

### Что умеет приложение после наполнения БД

- Показать карточку DE-слова с таблицей склонений/спряжений
- Показать RU-перевод с привязкой к конкретному значению (не "все переводы в кучу")
- Отфильтровать колоду по уровню CEFR (A1–C1), части речи, частоте
- Гарантировать:
  - каждое слово A1–C1 DE имеет хотя бы один RU-перевод
  - каждое слово A1–C1 DE имеет все формы согласно типам слова.
---

### MVP vs Полное решение

MVP — это **не урезанный функционал**. Все таблицы БД заполнены, все шаги пайплайна работают. Разница в источнике лемм и количестве прогонов.

#### MVP — один прогон, только whitelist

Леммы берутся **исключительно из whitelist'ов** (PDF и аналоги). Дампы используются только как источник данных для уже известных слов — форм, переводов, глоссов.

В рамках MVP проверяется: все ли слова whitelist'а есть в дампе (по частотам). Слова, которых нет в дампе — фиксируются как gap, разбираются вручную или через альтернативные источники.

```
whitelist (PDF)
    ↓ фильтр
de-extract.jsonl.gz  →  формы, переводы, глоссы для слов из whitelist
freq corpus          →  частоты + проверка покрытия whitelist'а дампом
```

#### Full — два прогона

**Прогон 1** (тот же что MVP): все слова из whitelist'ов — гарантировано 100% в БД, 100% с переводом.

**Прогон 2**: леммы из дампов викисловаря, предварительно отфильтрованные от мусора.

```
de-extract.jsonl.gz  →  все леммы после фильтрации:
    freq > N (порог по языку)
    длина ≥ 2
    нет мусорных символов
    нет составных форм / redirect-записей
    ... (критерии разрабатываются в таске по парсеру отдельно для каждого языка)
```

> Конкретные правила фильтрации мусора (freq threshold, алфавитные фильтры, POS-фильтры) — разрабатываются на этапе TASK-1 (Parser) отдельно под DE, RU, EN.

| | **MVP** | **Full прогон 1** | **Full прогон 2** |
|---|---|---|---|
| Источник лемм | whitelist (PDF) | whitelist языка | дампы викисловаря |
| Фильтрация | по наличию в дампе | по наличию в дампе | freq, длина, алфавит, POS |
| Гарантия перевода | 100% A1–C1 | **100%** whitelist | best-effort |
| Запуск | сейчас | после MVP отточен | после прогона 1 |

Переход MVP → Full прогон 1: заменить источник whitelist. Прогон 2: новый шаг в TUI. Архитектура и схема не меняются.

---

### Что LexBuild НЕ делает

- Не создаёт пользовательские данные (колоды, прогресс, карточки) — это отдельный модуль
- Не скачивает файлы — данные уже лежат в `backend/data/`
- Не трогает live de.wiktionary.org — только локальные `.jsonl.gz` дампы
- Не хранит RU-словоформы (по дизайну MVP: RU-формы добавляются в post-MVP эпике)

---

## 0.1 Решение по схеме БД: JSONB vs INTEGER bitmask

### Контекст

MVP: 1 000 пользователей, ~100 K лемм на 3 языка, ~570 K word_forms.
Приоритет: **размер БД критичен**, нагрузка — малая.
Основной access pattern: `WHERE word_id = X` → вернуть все формы слова. Фильтрация по отдельным грамматическим признакам (case, gender, tense) в продуктовых запросах **не используется**.

---

### Сравнение схем

#### Размер (570 K word_forms, 100 K лемм)

| Таблица | Строк | JSONB | INTEGER | Экономия |
|---|---|---|---|---|
| `word_forms` | 570 000 | ~123 MB | ~31 MB | **−92 MB** |
| `words` | 100 000 | ~11 MB | ~6 MB | −5 MB |
| `concepts` | 200 000 | ~18 MB | ~6 MB | −12 MB |
| `word_senses` | 175 000 | ~9 MB | ~7 MB | −2 MB |
| `sense_texts` | 150 000 | ~14 MB | ~13 MB | −1 MB |
| **Итого** | | **~175 MB** | **~63 MB** | **−112 MB (−64%)** |

Расчёт: JSONB для noun-формы `{lang,partOfSpeech,case,number,gender,declensionGroup,article}` — ~144 байт бинарного представления + ENUM(4) + timestamps(16) + meta(20) + row header ≈ 232 байт/строку. INTEGER bitmask + id + word_id + spelling + frequency + header ≈ 58 байт/строку.

> **Почему INTEGER, а не SMALLINT:** PostgreSQL `SMALLINT` — знаковый 16-битный тип (max 32767). Бит 15 (`isReflexive`) делает значение отрицательным при записи (например, рефлексивный сильный глагол → 44033 > 32767 → OOM/out-of-range). JavaScript побитовые операторы (`>>`, `&`) работают в 32-битном знаковом пространстве — отрицательные значения дают неочевидные результаты. `INTEGER` (4 байта) решает обе проблемы за +1.14 MB на 570K строк.

---

#### Скорость под нагрузкой

| Тип запроса | JSONB | INTEGER | Победитель | Примечание |
|---|---|---|---|---|
| `WHERE word_id = X` (FK lookup) | ~0.3 ms | ~0.1 ms | **INTEGER** | Строки в 4× меньше → 4× больше строк на странице → лучше cache hit |
| Sequential scan (coverage, stats) | медленнее | **4× быстрее** | **INTEGER** | Меньше страниц для чтения |
| `WHERE case = 'nom'` с GIN-индексом | **быстро** | expression index | **JSONB** | Нужен отдельный expression index на каждый бит |
| `WHERE case = 'nom'` без индекса | медленно | медленно | ничья | Seq scan, оба плохи без индекса |
| Запись (импорт) | простая | +encode step | **JSONB** | encode/decode код в приложении |
| Сетевой трафик (ответ API) | больше | меньше | **INTEGER** | 4× меньше байт в результате |
| Buffer cache (высокая нагрузка) | ~25% hit rate | ~75% hit rate | **INTEGER** | 4× плотность → shared_buffers используется эффективнее |

---

#### Проблемы INTEGER bitmask при высокой нагрузке

| Проблема | Тяжесть | Условие возникновения | Митигация |
|---|---|---|---|
| **Нет GIN-индекса на признаки** | Средняя | Если понадобится `WHERE case = 'nom'` | Expression index: `CREATE INDEX ON word_forms (((features >> 5) & 3))` — по одному на каждый признак |
| **Decode overhead на каждом чтении** | Низкая | Высокая частота `findAllForWord` | Битовые операции — наносекунды; в разы дешевле JSON-парсинга |
| **Неоднозначность IRREGULAR форм** | Средняя | Verb с частичными тегами: person=0 означает "unknown" или "1-е лицо"? | Зарезервировать 0 как "unknown", 1/2/3 как лица — задокументировать в enum |
| **Нет DB-level валидации** | Низкая | Баг в encode → невалидный bitmask записан без ошибки | CHECK constraint + unit-тесты на encode/decode |
| **Эволюция схемы** | Высокая | Добавление нового языка (RU-формы, венгерский) или нового признака | Зарезервировать свободные биты; при переполнении → INT (4 байта, всё равно 8× меньше JSONB) |
| **Отладка** | Низкая | `SELECT features FROM word_forms WHERE id=1` → число, не JSON | `decodeFeatures(n)` в psql через PL/pgSQL функцию или в ORM-слое |

**Расширение языков:**
Текущий bitmask использует биты [0-15]. Биты [16-31] зарезервированы для новых языков. Русские формы (6 падежей, одушевлённость, вид глагола) укладываются в [16-31]. Агглютинативные языки (финский, венгерский, 15+ падежей) потребуют пересмотра раскладки, но INTEGER по-прежнему в 36× меньше JSONB.

---

#### Когда JSONB становится лучше

JSONB выигрывает только при одновременном выполнении трёх условий:
1. Высокая нагрузка на аналитические запросы с фильтрацией по отдельным признакам
2. Часто меняющаяся схема признаков (добавление полей без re-import)
3. Нет жёстких ограничений по размеру БД

В данном проекте ни одно из трёх не выполняется на горизонте MVP и post-MVP.

---

### Решение

**Принять: `features INTEGER` вместо `grammatical_features JSONB + validationStatus ENUM`.**

Экономия 112 MB при масштабировании до 100 K лемм обоснована. `INTEGER` (не `SMALLINT`) выбран принципиально: бит 15 (`isReflexive`) делает SMALLINT-значение отрицательным, что ломает запись в PostgreSQL и побитовые операции в JavaScript.

---

## 1. Исследование данных (`backend/data/`)

### Файлы на диске

| Файл | Размер | Записей | Назначение |
|---|---|---|---|
| `de-extract.jsonl.gz` | 246 MB | 1 308 652 | Дамп de.wiktionary. DE-слова: глоссы (DE), переводы DE→RU/EN, формы, синонимы, примеры |
| `ru-extract.jsonl.gz` | 238 MB | 2 676 657 | Дамп ru.wiktionary. 486 716 RU-записей с русскими глоссами, формами, примерами |
| `raw-wiktextract-data.jsonl.gz` | 2.2 GB | 10 614 125 | Дамп en.wiktionary. EN, DE, RU записи. **Вне скопа MVP.** |
| `deu_wikipedia_2021_1M/` | 472 MB | — | Частотный корпус DE Википедии (`*-words.txt`: rank/слово/частота) |
| `eng_wikipedia_2016_1M/` | 580 MB | — | Частотный корпус EN Википедии |
| `rus_wikipedia_2021_1M/` | 545 MB | — | Частотный корпус RU Википедии |
| `de-ru.txt/CCMatrix.*` | 12 GB | 45 907 514 | Параллельный корпус DE-RU предложений. **Вне скопа MVP.** |
| `68532-vocabulary-list-by-topic.pdf` | 386 KB | — | Тематический список DE-лексики A1–B2 |

### `de-extract.jsonl.gz` — ключевые характеристики

- Всего: 1 308 652 записей
- С RU переводом: 30 456 (2.3%) → 44 237 RU-пар (avg 1.5 RU/слово)
- С EN переводом: 100 601 (7.7%) → 159 415 пар
- Переводы привязаны к `sense_index`: 99.6%
- С формами `forms[]`: 31.9%
- Многозначные (>1 sense): 47.2%
- POS: noun 39% / verb 30% / adj 24% / adv 0.4%

**Структура записи:**
```jsonc
{
  "word": "Haus",
  "pos": "noun",
  "lang_code": "de",
  "tags": ["neuter"],              // gender на лемме, не на форме
  "forms": [
    { "form": "Hauses", "tags": ["genitive", "singular"] },
    { "form": "Häuser", "tags": ["nominative", "plural"] }
  ],
  "senses": [{ "glosses": ["Gebäude zum Wohnen"], "sense_index": "1" }],
  "translations": [
    { "word": "дом", "lang_code": "ru", "sense_index": "1", "tags": ["masculine"] }
  ]
}
```

### `ru-extract.jsonl.gz` — ключевые характеристики

- Всего: 2 676 657 записей (включая redirect-записи без `lang_code`)
- RU-записей (`lang_code == 'ru'`): 486 716
- POS: verb 192K / noun 190K / adj 54K / adv 8.7K
- Глоссы на русском языке — единственный источник RU-определений
- Формы не используются в MVP (по дизайну, RU формы не хранятся)

### Принцип работы с файлами

Все `.jsonl.gz` читаются потоковым стримингом — без распаковки на диск. Никаких промежуточных файлов.

---

## 2. Текущее состояние реализации

### Что уже есть

**Backend — `DictionaryModule`:**
- ✅ Все entity: `Word`, `WordForm`, `WordSense`, `Concept`, `SenseText`, `Language`, `Dictionary`
- ✅ Миграция со всеми таблицами, индексами, UNIQUE-ограничениями
- ✅ `DictionaryFacade`: `upsertWord`, `upsertWordForms`, `findOrCreateWordSense`, `addSenseText`, `upsertWordRelation`
- ✅ `WordImportRepository`: raw SQL batch upserts (работают)
- ✅ Типы форм DE: `DeVerbFeatures`, `DeNounFeatures`, `DeAdjectiveFeatures`, `DePronounFeatures`, `DeArticleFeatures` (`de.types.ts`)
- ✅ Валидаторы форм со стратегиями: `DeNounStrategy`, `DeVerbStrategy`, `DeAdjectiveStrategy`, `DePronounStrategy`, `DeArticleStrategy`
- ✅ `FormValidatorRegistry` — strategy pattern по ключу `lang:pos`

**Backend — `dict-import`:**
- ✅ `WiktionaryPipeline`: читает JSONL батчами, пишет слова + формы (как сырые теги) + senses с EN-глоссом
- ✅ `JsonlReaderService` с `readBatches()` — **только для обычного `.jsonl`, без `.gz`**
- ✅ `FrequencyMapLoader`, `ImportRunService` — есть

**Parser (Python):**
- ✅ `extract_pdf_vocab.py` — PDF-экстракция есть
- ✅ `modules/wiktionary/languages/de.py` — HTML-скрапер de.wiktionary (другая задача)
- ✅ `modules/wiktionary/validator.py` — валидация скрапера

### Что отсутствует / нужно доделать

| # | Что отсутствует | Где проблема |
|---|---|---|
| **A** | `.gz` поддержка в `JsonlReaderService` | `createReadStream` без `zlib.createGunzip()` — `.gz` не читается |
| **B** | NestJS-заглушка `upsertWordForms` | `upsertWordForms` сохраняет `{ tags: [...] }` как `grammaticalFeatures` вместо `features INTEGER` — маппинг тегов переходит в Python (TASK-3, dwdsmor). NestJS-сторона закрывается в TASK-4: `upsertWordForms` принимает готовые признаки от Python и вызывает `encodeFeatures()` |
| **C** | Шаг `links` (DE→RU концепты) | `WiktionaryPipeline` не создаёт RU леммы из `translations[]`, не связывает слова через концепты |
| **D** | `KaikkiEntry` DTO неполный | Нет поля `tags?: string[]` (gender лемм) и `translations?: KaikkiTranslation[]` |
| **E** | Whitelist интеграция | `extract_pdf_vocab.py` не подключён к пайплайну |
| **F** | `lexbuild.py` CLI | Не существует |

---

## 3. Источник `word_forms` — выбор стратегии

### Сравнение подходов

Морфологический модуль (`parser/modules/morphology/`) использует цепочку: dwdsmor → lookup index → spaCy. dwdsmor — двунаправленный FST: умеет и анализировать формы, и генерировать парадигму. Дампы wiktionary (`de-extract.jsonl.gz`) содержат `forms[]` с аттестованными формами, но с неполными тегами.

| Критерий | **① Только генерация** (dwdsmor) | **② Только словари** (dump → lookup → spaCy) | **③ Генерация + словари** |
|---|---|---|---|
| Покрытие лемм | ~100K в `open`-издании; неологизмы, имена — отсутствуют | 31.9% записей имеют `forms[]`; остальные без форм | Генератор даёт базу, дамп закрывает пробелы dwdsmor |
| Полнота признаков | Все поля bitmask всегда присутствуют | Noun: case+number, нет gender на форме. Verb: большинство только tense | Генератор заполняет все поля, дамп подтверждает |
| ValidationStatus | 100% VALIDATED | Adj: VALIDATED. Noun: частично. Verb: большинство IRREGULAR | Совпадение → VALIDATED. Только дамп → IRREGULAR |
| Реальность форм | Теоретические — может генерировать неупотребимые формы | Только аттестованные — реально встречались в текстах | Пересечение = высокая уверенность |
| Нерегулярные глаголы | dwdsmor знает сильные глаголы (ging, fuhr) | Дамп содержит реальные формы включая архаичные | Двойная проверка: FST + аттестация |
| Неологизмы / имена | ❌ нет в dwdsmor | ✅ если есть статья в wiktionary | ✅ дамп покрывает то, что генератор не знает |
| Сложность | Простая | Средняя | Выше, но логика в Python |

### Решение: вариант ③

```
dwdsmor.generate(lemma)       → полная парадигма + типизированные признаки
         +
de-extract.jsonl.gz forms[]   → аттестованные форм-строки
         ↓
Слияние:
  форма есть в обоих           → VALIDATED  (максимальная уверенность)
  только в генераторе          → VALIDATED  (dwdsmor авторитетен по признакам)
  только в дампе               → IRREGULAR  (аттестована, но вне модели)
  расхождение признаков        → IRREGULAR  + флаг для ревью
```

Конкретные правила слияния и обработки конфликтов — разрабатываются в TASK-3 (Python, отдельно для каждого POS и языка).

---

### `ValidationStatus` — схема применения (кодируется в bits[3-4] bitmask)

| bits[3-4] | Статус | Когда |
|---|---|---|
| `0` | `VALIDATED` | Все обязательные поля присутствуют, прошли валидатор |
| `1` | `IRREGULAR` | Частичные теги (глагол без person/number), Partizip, редкие формы |
| `2` | `FAILED` | Валидатор вернул ошибку (несовпадение article/gender и т.п.) |
| `3` | _(corrupt)_ | Зарезервировано — недопустимое значение; `COUNT(*) WHERE (features >> 3) & 3 = 3` должно быть 0 |

> `UNVERIFIED` существовал только как ENUM-заглушка в коде до TASK-0. После перехода на bitmask не используется.


---

## 4. Описание эпика

**LexBuild** — пайплайн импорта словарей из Wiktionary-дампов и частотных корпусов в PostgreSQL.

Принимает на вход: `.jsonl.gz` файлы в `backend/data/`, PDF whitelist, имя словаря.
Производит: записи в `words`, `word_forms`, `concepts`, `word_senses`, `sense_texts`.

**Принципы:**
- **Один проход по файлу.** Каждый шаг читает файл один раз, стримом.
- **Идемпотентность.** Повторный запуск не создаёт дублей.
- **Один источник.** MVP: только `de-extract.jsonl.gz`. Переводы, леммы, формы — всё из него.
- **Переводы только для лемм.** RU-записи создаются из `translations[]` DE-лемм. Формы не переводятся.
- **Строгое разделение.** Python читает все файлы (`.jsonl.gz` и PDF) и отправляет батчи в NestJS по HTTP. NestJS только оркестрирует и пишет в БД. `DictionaryModule` — единственный писатель в БД.
- **100% связанность для A1–C1.** Каждое слово уровней A1–C1 обязано иметь хотя бы один RU-перевод. Словарь не считается готовым к релизу, пока `coverage_pct = 100%` не достигнуто для этих уровней. Отслеживается через TASK-9 (Coverage monitor).

> **TODO / Будущий эпик:** *Epic-TranslationCoverage* — улучшение связанности переводов в словаре.
> Источники для закрытия gap: `ru-extract.jsonl.gz` (RU-определения), EN-bridge через `raw-wiktextract-data.jsonl.gz`, ручная разметка топ-N gap-слов по частоте. Запускать после MVP, ориентир — gap_words из снапшотов TASK-9.

**Словари и режимы (TUI):**

| TUI | Режим | Словарь | Источник лемм | Источник форм | Freq |
|---|---|---|---|---|---|
| 2 | DE→RU MVP | `de-topics-mvp` | `de-extract.jsonl.gz` + PDF whitelist | `forms[]` | `deu_wikipedia` |
| 3 | DE→RU Full | `de-topics-full` | `de-extract.jsonl.gz` (все) | `forms[]` | `deu_wikipedia` |
| 4 | EN→RU MVP | `en-topics-mvp` | `raw-wiktextract-data.jsonl.gz` (EN) + EN whitelist | не хранятся | `eng_wikipedia` |
| 5 | EN→RU Full | `en-topics-full` | `raw-wiktextract-data.jsonl.gz` (EN, все) | не хранятся | `eng_wikipedia` |

RU-леммы создаются из `translations[]` соответствующего источника. RU-формы не хранятся во всех режимах.

---

## 5. Схема БД (состояние до TASK-0)

> После выполнения TASK-0 схема будет изменена согласно §0.1. Этот раздел отражает текущее состояние кодовой базы.

```
words       id | language_id | lemma | part_of_speech | frequency | validation_status | validation_meta
word_forms  id | word_id | spelling | grammatical_features (jsonb) | validation_status | frequency
concepts    id
word_senses id | word_id | concept_id | sense_index
sense_texts id | sense_id | language_id | type | text
```

Схема управляется напрямую на стадии разработки — через дампы, сидеры и прямое изменение БД. Миграции не применяются до релиза.

---

## 6. MVP — список задач

### TASK-0 · Сброс БД и оптимизация схемы

**Статус:** ❌ нужно сделать перед любым прогоном

**Что сделать:** дропнуть и пересоздать БД с оптимизированной схемой. Цель — сократить объём с ~15–18 MB до ~6–8 MB за счёт замены JSONB на bitmask и удаления незначимых колонок.

---

#### 0.1 · Изменения схемы

**`word_forms` — главная оптимизация (~7.6 MB экономии):**

```sql
-- Было:
grammatical_features  JSONB   NOT NULL        -- ~144 байт/строку
validation_status     ENUM    NOT NULL        -- 4 байт/строку
validation_meta       JSONB   NULL            -- ~20 байт/строку
frequency             INT     NOT NULL        -- 4 байта/строку (форм-уровень не нужен, частота на лемме)
created_at            TIMESTAMPTZ NOT NULL    -- 8 байт/строку
updated_at            TIMESTAMPTZ NOT NULL    -- 8 байт/строку

-- Стало:
features              INTEGER NOT NULL        -- 4 байта/строку (bitmask, INT4)
```

Bitmask-кодировка `features INTEGER` (32 бит, используются биты [0-15], [16-31] зарезервированы):
```
Биты [0-2]:  POS        0=noun 1=verb 2=adj 3=pronoun 4=article 5=adv 6=other
Биты [3-4]:  Status     0=VALIDATED 1=IRREGULAR 2=FAILED

noun  [5-6]:case(nom/gen/dat/acc)  [7]:number(sg/pl)  [8-9]:gender(m/f/n)  [10-11]:declensionGroup(strong/n_dekl/mixed)
verb  [5-7]:tense(present/pret/perf/pluperf/fut1/fut2)  [8-9]:mood(ind/konj1/konj2/imp)
      [10-11]:person(0=unknown/1/2/3)  [12]:number  [13-14]:verbClass(weak/strong/mixed/modal)  [15]:isReflexive
adj   [5-6]:case  [7]:number  [8-9]:gender  [10-11]:declensionType(strong/weak/mixed)  [12-13]:degree(pos/comp/sup)
```

**Числовые значения каждого поля — единственный источник истины:**

| Поле | Значение | Число |
|---|---|---|
| **POS** | noun | 0 |
| | verb | 1 |
| | adj | 2 |
| | pronoun | 3 |
| | article | 4 |
| | adv | 5 |
| | other | 6 |
| **Status** | VALIDATED | 0 |
| | IRREGULAR | 1 |
| | FAILED | 2 |
| **case** | nom | 0 |
| | gen | 1 |
| | dat | 2 |
| | acc | 3 |
| **number** | sg | 0 |
| | pl | 1 |
| **gender** | m | 0 |
| | f | 1 |
| | n | 2 |
| **declensionGroup** (noun) | strong | 0 |
| | weak (n-Dekl) | 1 |
| | mixed | 2 |
| **tense** | present | 0 |
| | preterite | 1 |
| | perfect | 2 |
| | pluperfect | 3 |
| | future1 | 4 |
| | future2 | 5 |
| **mood** | indicative | 0 |
| | konjunktiv1 | 1 |
| | konjunktiv2 | 2 |
| | imperative | 3 |
| **person** | unknown | 0 |
| | first | 1 |
| | second | 2 |
| | third | 3 |
| **verbClass** | weak | 0 |
| | strong | 1 |
| | mixed | 2 |
| | modal | 3 |
| **declensionType** (adj) | strong | 0 |
| | weak | 1 |
| | mixed | 2 |
| **degree** | positive | 0 |
| | comparative | 1 |
| | superlative | 2 |

Эти значения должны быть продублированы константами в `word-form-features.ts` (NestJS) и `parser/utils/features.py` (Python). Любое расхождение → битые данные при cross-decode.

`article` для noun вычисляется из gender при чтении (m→der, f→die, n→das), не хранится.
`person=0` означает "неизвестно" — используется для IRREGULAR глагольных форм.

**`words` (~400 KB экономии):**
```sql
-- Удалить:
validation_meta   JSONB   NULL   -- импортный debug, не нужен в проде
total_frequency   INT             -- дублирует frequency
created_at        TIMESTAMPTZ
updated_at        TIMESTAMPTZ
```

**`concepts` (~400 KB экономии):**
```sql
-- Удалить:
image_url           VARCHAR(512)  -- нет изображений в MVP
image_generated_at  TIMESTAMPTZ
created_at          TIMESTAMPTZ
updated_at          TIMESTAMPTZ
```

**`word_senses` (~176 KB экономии):**
```sql
-- Удалить:
created_at   TIMESTAMPTZ
updated_at   TIMESTAMPTZ
```

**`sense_texts` (~40 KB экономии):**
```sql
-- Удалить:
created_at   TIMESTAMPTZ
```

---

#### 0.2 · Обновить entity-файлы в NestJS

| Файл | Что изменить |
|---|---|
| `word-form.entity.ts` | `grammaticalFeatures: GrammaticalFeatures` + `validationStatus` + `validationMeta` + `frequency` + timestamps → `features: number` |
| `word.entity.ts` | удалить `validationMeta`, `totalFrequency`, timestamps |
| `concept.entity.ts` | удалить `imageUrl`, `imageGeneratedAt`, timestamps |
| `word-sense.entity.ts` | удалить timestamps |
| `sense-text.entity.ts` | удалить `createdAt` |

Добавить утилитный модуль `word-form-features.ts` с функциями `encodeFeatures(pos, status, fields): number` и `decodeFeatures(n: number): GrammaticalFeatures & { validationStatus }`.

---

#### 0.2.1 · Константы языков

Таблица `languages` не сбрасывается при reset. Фиксированные ID обязательны — FK в `words.language_id` зависят от них.

**`backend/src/database/seeds/languages.seed.ts`** — только константы, не авто-сид:
```typescript
export const LANGUAGE_SEEDS = [
  { id: 1, name: 'German',  isoCode: 'de' },
  { id: 2, name: 'Russian', isoCode: 'ru' },
  { id: 3, name: 'English', isoCode: 'en' },
] as const;

export const DE_LANG_ID = 1;
export const RU_LANG_ID = 2;
export const EN_LANG_ID = 3;
```

Заполнение `languages` — ручная операция администратора, выполняется один раз после создания БД.

---

#### 0.3 · `DictionaryFacade.resetDictionary()`

Метод очищает все словарные таблицы кроме `languages`. Вызывается администратором отдельно через TUI до любого прогона импорта.

**Таблицы, которые очищаются (TRUNCATE CASCADE в порядке FK):**
```
sense_texts → word_senses → word_forms → word_relations
→ words → concepts → dictionary_words → dictionaries
```

`languages`, `import_runs`, `import_exceptions` — **не трогаются**.

**Интерфейс метода:**
```typescript
// DictionaryFacade
async resetDictionary(): Promise<void>
```

**TUI (TASK-8) — пункт "Reset dictionary data":**
```
⚠  Clear all dictionary data?
   Tables: sense_texts, word_senses, word_forms, word_relations,
           words, concepts, dictionary_words, dictionaries
   languages, import_runs, import_exceptions — preserved

❯  Yes, reset
   Cancel
```

После подтверждения — вызов `DictionaryFacade.resetDictionary()`.

---

#### 0.4 · Проверка наличия слов перед импортом

Перед каждым шагом импорта пайплайн запрашивает текущее количество слов в БД по каждому языку и показывает администратору. Проверка **не блокирует** импорт — только информирует.

```
Dictionary status before import:
  DE words: 3 500
  RU words: 1 200
  EN words: 0
Mode: append (existing words will be updated, not removed)
```

Реализация: `SELECT language_id, COUNT(*) FROM words GROUP BY language_id` в начале каждого пайплайна до первого батча.

---

#### 0.5 · Обработка дублей при импорте

**Точный дубль** (`language_id + lemma + part_of_speech` совпадает):
- `ON CONFLICT DO UPDATE SET frequency = GREATEST(...)` — слово обновляется
- В `import_exceptions` добавляется запись с reason `duplicate_lemma`
- Импорт продолжается

**Омограф** (одно написание, разный POS — например `bank` noun и `bank` verb):
- Оба слова записываются как отдельные строки — это не дубль по схеме
- **TODO:** постпроцессинг через dwds движок для проверки и разрешения омографов

**Регистровый вариант** (`Haus` и `haus` в одном батче):
- Оба пишутся как есть — пользователь гарантирует качество лемм
- Коллизия невозможна: `(language_id, lemma, part_of_speech)` — регистрозависимый UNIQUE

**Добавить в `import_exception_reason_enum`:**
```sql
'duplicate_lemma'  -- word with same (language_id, lemma, pos) already existed in DB
```

---

**Критерии готовности:**

Схема:
- `\d word_forms` → `features INTEGER NOT NULL`, нет колонок `grammatical_features`, `validation_status`, `validation_meta`, `created_at`, `updated_at`
- `\d words` → нет `validation_meta`, `total_frequency`, `created_at`, `updated_at`
- `\d concepts` → нет `image_url`, `image_generated_at`, `created_at`, `updated_at`
- `\d word_senses` → нет `created_at`, `updated_at`
- `\d sense_texts` → нет `created_at`

После `resetDictionary()`:
- `SELECT COUNT(*) FROM words` → 0
- `SELECT COUNT(*) FROM languages` → 3 (не затронута)
- `SELECT COUNT(*) FROM import_runs` — не изменился (не затронута)

Утилита `word-form-features.ts`:
- Файл существует и экспортирует `encodeFeatures` и `decodeFeatures`
- `encodeFeatures` / `decodeFeatures` покрыты unit-тестами для noun, verb (полный + IRREGULAR с person=0), adj
- Числовые значения enum-констант в `word-form-features.ts` совпадают с таблицей из §0.1
- `encodeFeatures('verb','VALIDATED',{tense:'present',mood:'ind',person:3,number:'sg',verbClass:'strong',isReflexive:true})` → результат в диапазоне `0..2147483647` (не отрицательный, не out-of-range для INTEGER)

**F · Ограничение идемпотентности — Ghost data:**

`ON CONFLICT DO UPDATE` добавляет и обновляет, но **не удаляет** записи, исчезнувшие из источника. Если слово убрано из PDF-whitelist или из дампа — его `word_forms` и `word_senses` остаются в БД.

Для MVP это приемлемо: whitelist (PDF) фиксирован между прогонами. При смене whitelist или обновлении дампа — использовать TUI **"-" (удалить данные)** + повторный прогон нужного режима.

Incremental cleanup (`last_seen_run_id`) — post-MVP, разрабатывается в отдельном эпике при необходимости.

**Тест (fixture) — `__tests__/word-form-features.spec.ts`:**
```typescript
it('noun roundtrip', () => {
  const n = encodeFeatures('noun', 'VALIDATED', { case: 'gen', number: 'sg', gender: 'n', declensionGroup: 'strong' });
  expect(decodeFeatures(n)).toMatchObject({ pos: 'noun', status: 'VALIDATED', case: 'gen', number: 'sg', gender: 'n' });
});

it('verb IRREGULAR с person=0 (unknown)', () => {
  const n = encodeFeatures('verb', 'IRREGULAR', { tense: 'pret', mood: 'ind', person: 0, number: 'sg', verbClass: 'strong' });
  const d = decodeFeatures(n);
  expect(d.status).toBe('IRREGULAR');
  expect(d.person).toBe(0); // 0 = unknown, не 1-е лицо
});

it('две разные формы дают разные числа', () => {
  const nom = encodeFeatures('noun', 'VALIDATED', { case: 'nom', number: 'sg', gender: 'n', declensionGroup: 'strong' });
  const gen = encodeFeatures('noun', 'VALIDATED', { case: 'gen', number: 'sg', gender: 'n', declensionGroup: 'strong' });
  expect(nom).not.toBe(gen);
});

it('adj roundtrip с degree=comp', () => {
  const n = encodeFeatures('adj', 'VALIDATED', { case: 'nom', number: 'sg', gender: 'm', declensionType: 'strong', degree: 'comp' });
  expect(decodeFeatures(n)).toMatchObject({ pos: 'adj', degree: 'comp', case: 'nom' });
});
```

---

### TASK-1 · Parser API + `utils/jsonl.py` (Python)

**Статус:** ❌ отсутствует — блокирует всё остальное

**Что сделать:** Python берёт на себя чтение всех файлов. NestJS получает готовые батчи по HTTP. `JsonlReaderService` в NestJS — удалить.

---

**`parser/utils/jsonl.py` — общий стример:**
```python
def stream_jsonl(path: str, batch_size: int = 500):
    opener = gzip.open if path.endswith('.gz') else open
    with opener(path, 'rt', encoding='utf-8') as f:
        batch = []
        for line in f:
            if line.strip():
                batch.append(json.loads(line))
            if len(batch) >= batch_size:
                yield batch
                batch = []
        if batch:
            yield batch
```

---

**`parser/main.py` — FastAPI endpoints для пайплайна:**
```
POST /pipeline/run
  body: {
    step:        "pdf-seed" | "freq" | "lemmas" | "forms" | "links",
    file_path:   str,               // абсолютный путь к файлу — передаёт NestJS из своего конфига
    dict_name:   str,
    lang_code:   str,               // "de" | "ru" | "en" — какой lang_code фильтровать в файле
    whitelist:   list[str] | null,  // null = без фильтра (Full mode)
    word_id_map: dict[str, int] | null  // только для шага "forms": lemma → wordId
  }
  response: chunked NDJSON стрим — одна строка = один готовый батч:
    {"batch": [...500 записей...], "progress": {"done": 500,  "total": -1}}
    {"batch": [...500 записей...], "progress": {"done": 1000, "total": -1}}
    ...
    // total = -1: неизвестно до конца — один проход, считать заранее нельзя

GET /health
```

**Почему `file_path` передаёт NestJS:**
Python — чистая функция: получил путь + параметры → прочитал → вернул батчи. Python не знает о расположении `backend/data/` и не хранит конфиг путей. NestJS конфигурирует пути в одном месте и передаёт конкретный `file_path` в каждом вызове. Это позволяет менять расположение данных без изменений в Python.

**Протокол батчинга:** Python буферизирует 500 записей → пишет одну JSON-строку в стрим → NestJS читает строку целиком → парсит как готовый батч → передаёт в `DictionaryFacade`. NestJS не буферизирует ничего сам.

**B · Backpressure:** NestJS читает HTTP-стрим через `AsyncIterable` (`for await...of`). Следующая строка не читается из сокета пока текущий батч не записан в БД. Запрещено: `response.text()`, `response.json()`, накопление chunks в массив до завершения стрима — это гарантированный OOM на 1.3M записей.

```typescript
for await (const line of responseBodyLines(response)) {
  const { batch } = JSON.parse(line);
  await facade.upsertWordBatch(batch);   // ← следующий chunk ждёт здесь
}
```

**C · Разрыв соединения:** Python может упасть в середине стрима (битый JSONL-узел, OOM, таймаут). NestJS обязан:
- Обернуть весь стрим в `try/catch`
- При ошибке: `importRunService.markFailed(runId, error.message)` + сохранить `progress.done` на момент разрыва
- Продолжить к Coverage-снапшоту (не падать самому)
- Не откатывать уже записанные батчи — частичный прогон лучше потери данных, Coverage покажет реальное состояние

**Передача whitelist:** шаг `pdf-seed` запускается первым и возвращает список лемм в ответе. NestJS сохраняет его в памяти и передаёт как `whitelist` в последующие шаги `lemmas`, `forms`, `links`. Python фильтрует: если `whitelist != null` и `entry.word not in whitelist` → пропустить запись.

**Передача wordIdMap (шаг `forms`):** шаг `lemmas` завершается — NestJS собирает `Map<string, number>` из `RETURNING` clause upsert-запросов: `{ lemma → wordId }`. Карта передаётся Python в теле `POST /pipeline/run` шага `forms` как `word_id_map: Record<string, number>`. Python использует её для подстановки `wordId` в каждую запись `IncomingWordForm`. Если `lemma` отсутствует в карте — форма пропускается с предупреждением.

NestJS (TUI) вызывает `POST /pipeline/run`, читает стрим и передаёт батчи в `DictionaryFacade`.

> **✅ Q2 закрыт:** канонический enum шагов — `"pdf-seed" | "freq" | "lemmas" | "forms" | "links"`. Шаг `"lemmas"` соответствует чтению wiktionary-дампа и фильтрации лемм; `"links"` — отдельный проход по тому же файлу для создания DE→RU концептов. `"de-wiktionary"` и `"ru-wiktionary"` упразднены — язык передаётся через поле `lang_code`.

---

**Удалить из NestJS:**
- `JsonlReaderService` и `readBatches()` — Python читает файлы
- Зависимость `TASK-6` от чтения `.gz` переходит к этому таску

**Критерий готовности:**
- `GET http://parser:8000/health` → 200 OK
- `POST /pipeline/run` с `{ step: "lemmas", file_path: "/data/de-extract.jsonl.gz", lang_code: "de", dict_name: "test", whitelist: null }` → стрим NDJSON, каждая строка — JSON с `batch: [...]` и `progress: {done, total}`
- Последняя строка стрима: `progress.done > 0` (total = -1 допустим)
- `POST /pipeline/run` с `whitelist: ["Haus"]` → в `words` попадает только "Haus", все остальные записи из файла пропущены
- NestJS читает стрим через `AsyncIterable` (`for await...of`) — не буферизирует весь ответ
- При разрыве стрима в середине: `import_run.status = 'FAILED'`, `progress.done` сохранён, Coverage-снапшот запускается, NestJS не падает
- NestJS читает стрим и пишет первые 100 записей в БД без ошибок, используя `DE_LANG_ID = 1`
- `JsonlReaderService` удалён из кодовой базы и не упоминается в импортах

**Тест (fixture) — `parser/tests/test_jsonl.py`:**

Артефакт: `parser/tests/fixtures/de-mini.jsonl.gz` — 5 записей, сжатый gzip.

```python
def test_stream_jsonl_gz_reads_all():
    batches = list(stream_jsonl('tests/fixtures/de-mini.jsonl.gz', batch_size=2))
    assert len(batches) == 3          # [2, 2, 1]
    assert sum(len(b) for b in batches) == 5

def test_stream_jsonl_plain_reads_all():
    batches = list(stream_jsonl('tests/fixtures/de-mini.jsonl', batch_size=500))
    assert len(batches) == 1
    assert len(batches[0]) == 5

def test_pipeline_run_streams_ndjson(test_client, fixture_path):
    resp = test_client.post('/pipeline/run', json={
        'step': 'lemmas',
        'file_path': fixture_path('de-mini.jsonl.gz'),
        'lang_code': 'de',
        'dict_name': 'test',
    }, stream=True)
    assert resp.status_code == 200
    lines = [json.loads(l) for l in resp.iter_lines() if l]
    assert all('batch' in l and 'progress' in l for l in lines)
    assert lines[-1]['progress']['done'] == 5
```

---

### TASK-2 · Переименовать `KaikkiEntry` → `DeExtractEntry` и дополнить DTO

**Статус:** ❌ неполный — блокирует TASK-4 и TASK-5

**Контекст:** `KaikkiEntry` — устаревшее название из эпохи `kaikki.org-dictionary-German.jsonl`, который удалён. Теперь работаем с `de-extract.jsonl.gz`. Формат файла тот же (wiktextract), но DTO нужно переименовать и дополнить полями, которых не хватало.

**Что сделать:** переименовать `kaikki-entry.dto.ts` → `de-extract-entry.dto.ts`, обновить все импорты, добавить недостающие поля.

**Новый DTO:**
```typescript
// de-extract-entry.dto.ts

export interface DeExtractForm {
  form: string;
  tags?: string[];
  source?: string;
}

export interface DeExtractSense {
  id?: string;
  glosses?: string[];
  sense_index?: string;
  synonyms?: { word: string }[];
  antonyms?: { word: string }[];
  tags?: string[];
}

export interface DeExtractTranslation {
  word: string;
  lang_code: string;
  lang?: string;
  sense_index?: string;
  tags?: string[];   // POS переводимого слова
}

export interface DeExtractEntry {
  word: string;
  lang: string;
  lang_code: string;
  pos: string;
  tags?: string[];                        // gender лемм: "neuter", "masculine", "feminine"
  forms?: DeExtractForm[];
  senses?: DeExtractSense[];
  translations?: DeExtractTranslation[];  // DE→RU/EN переводы
  categories?: string[];                  // нужны для определения verbClass
}
```

**Обновить импорты** в `wiktionary.pipeline.ts`, `word-import.repository.ts` и любых других файлах, ссылающихся на `KaikkiEntry`.

**Маппинг POS из Wiktextract в внутренние категории:**

Поле `pos` в `de-extract.jsonl.gz` — строка из Wiktextract. Неизвестные POS нельзя молча скидывать в `other` — теряется грамматика.

| Wiktextract `pos` | Внутренний POS | Примечание |
|---|---|---|
| `noun` | `noun` | |
| `verb` | `verb` | |
| `adj` | `adj` | |
| `adv` | `adv` | |
| `pron` | `pronoun` | |
| `article` | `article` | |
| `det` | `article` | Determinativartikel |
| `participle` | `verb` | Partizip I/II остаётся при verb-лемме |
| `num` / `numeral` | `other` | числительные — без морфологии |
| `prep` | `other` | |
| `conj` | `other` | |
| `intj` | `other` | |
| `suffix` | **SKIP** | не импортируем — не лемма |
| `prefix` | **SKIP** | |
| `affix` | **SKIP** | |
| `phrase` | **SKIP** | фразы, не одиночные леммы |
| `proverb` | **SKIP** | |
| `character` | **SKIP** | |
| `symbol` | **SKIP** | |
| `abbrev` | **SKIP** | |
| неизвестный | **SKIP + лог** | warning в import_exceptions, не молчаливый drop |

Реализуется как `mapWiktextractPos(raw: string): PartOfSpeech | null` в `de-extract-entry.dto.ts` или отдельном утилите. `null` = SKIP.

**Тест (fixture) — compile-time type check:**

Файл `src/modules/dictionary/dto/__tests__/de-extract-entry.fixture.ts` — не запускается, только компилируется:
```typescript
import { DeExtractEntry } from '../de-extract-entry.dto';

// Если поле отсутствует в DTO → ошибка компиляции
const _fixture: DeExtractEntry = {
  word: 'Haus', lang: 'German', lang_code: 'de', pos: 'noun',
  tags: ['neuter'],
  forms: [{ form: 'Hauses', tags: ['genitive', 'singular'] }],
  senses: [{ glosses: ['Gebäude zum Wohnen'], sense_index: '1' }],
  translations: [{ word: 'дом', lang_code: 'ru', sense_index: '1', tags: ['masculine'] }],
  categories: ['Substantive'],
};
// Все поля опциональны кроме word/lang/lang_code/pos — это проверяет TypeScript
```

`tsc --noEmit` в CI — если DTO неполный, сборка падает.

**Критерий готовности:**
- Файл `kaikki-entry.dto.ts` удалён, все импорты обновлены на `de-extract-entry.dto.ts`
- `grep -r "KaikkiEntry" src/` → пусто
- `mapWiktextractPos('noun')` → `'noun'`; `mapWiktextractPos('suffix')` → `null`; `mapWiktextractPos('неизвестно')` → `null` + запись в лог
- `tsc --noEmit` проходит без ошибок

---

### TASK-3 · Forms pipeline (Python) — генерация + слияние с дампом

**Статус:** ❌ отсутствует — ключевая задача для заполнения `word_forms`

**Что сделать:** Python-пайплайн в `parser/pipelines/de_forms.py`, реализующий стратегию ③ из секции 3: dwdsmor-генерация + кросс-валидация с `de-extract.jsonl.gz`.

**Архитектура:**
```
NestJS после шага "lemmas" передаёт Python:
  word_id_map: { "Haus": 42, "gehen": 17, ... }   ← собирается из RETURNING clause upsert

для каждой DE-леммы из word_id_map:
  1. dwdsmor.generate(lemma, pos)     → список {spelling, features} — полная парадигма
  2. dump_forms = entry.forms[]       → список {spelling, tags[]} из дампа
  3. merge(generated, dump_forms)     → список {spelling, features, status}
  4. батч → POST /pipeline/run step=forms → NestJS → word_forms
     каждая запись: { wordId: word_id_map[lemma], spelling, pos, status, fields }
```

**Логика слияния:**
```python
for gen_form in generated:
    dump_match = find_in_dump(gen_form.spelling, dump_forms)
    if dump_match:
        status = VALIDATED   # оба источника согласны
    else:
        status = VALIDATED   # dwdsmor авторитетен

for dump_form in dump_forms:
    if not in_generated(dump_form.spelling):
        features = analyzer.analyze(dump_form.spelling) or partial_from_tags(dump_form.tags)
        status = IRREGULAR   # аттестована, но вне модели dwdsmor
```

**Фильтры (пропустить форму):**
- теги `variant`, `alternative`, `obsolete`, `abbreviation` в дампе
- `['auxiliary', 'perfect']`, составные формы (`extended infinitive`, `processual-passive`)

**Правила по POS — детали разрабатываются в таске:**
- Noun: declensionGroup (n-Deklination по паттерну), article из gender
- Verb: verbClass из `entry.categories` (`"Schwache Verben"` → `weak` и т.д.)
- Adj: все 5 полей покрыты dwdsmor напрямую

**Критерий готовности:**
- `"Haus"` → ровно 8 форм; каждая содержит `{spelling, pos:'noun', status:'VALIDATED', fields:{case,number,gender:'n',declensionGroup}}`; `article` отсутствует в `fields` (вычисляется из gender при чтении)
- `"gehen"` → форма `ging` присутствует, `verbClass='strong'` у всех форм; status `VALIDATED` или `IRREGULAR` — но не `FAILED`
- `"schön"` → ≥ 48 форм (3 declensionType × 16 форм/тип: 12 sg × 3 рода + 4 pl) для каждой из 3 степеней; точное число уточняется первым прогоном dwdsmor на `schön` и фиксируется как константа теста
- Формы с тегами `variant`, `obsolete`, `auxiliary` в dump — не присутствуют в выходном батче
- Выходной батч соответствует интерфейсу `IncomingWordForm` (TASK-4): `{wordId, spelling, pos, status, fields}`
- Числовые значения в `fields` совпадают с enum-таблицей из §0.1

**Тест (fixture) — `parser/tests/test_de_forms.py`:**

Константы в файле теста — не внешние файлы:
```python
HAUS_DUMP = {'word': 'Haus', 'pos': 'noun', 'tags': ['neuter'],
  'forms': [{'form': 'Hauses', 'tags': ['genitive', 'singular']},
            {'form': 'Häuser', 'tags': ['nominative', 'plural']},
            {'form': 'Häusern', 'tags': ['dative', 'plural']}]}

GEHEN_DUMP = {'word': 'gehen', 'pos': 'verb', 'categories': ['Starke Verben'],
  'forms': [{'form': 'ging',     'tags': ['past', 'indicative', 'first-person', 'singular']},
            {'form': 'gegangen', 'tags': ['participle', 'past']}]}

VARIANT_DUMP = {'word': 'Test', 'pos': 'noun', 'tags': ['masculine'],
  'forms': [{'form': 'Testen', 'tags': ['variant', 'genitive', 'singular']}]}

def test_haus_8_forms():
    forms = generate_and_merge('Haus', 'noun', HAUS_DUMP)
    assert len(forms) == 8
    nom_sg = next(f for f in forms if f['case'] == 'nom' and f['number'] == 'sg')
    assert nom_sg['spelling'] == 'Haus'
    assert nom_sg['status'] == 'VALIDATED'
    assert nom_sg['gender'] == 'n'

def test_gehen_verbclass_strong():
    forms = generate_and_merge('gehen', 'verb', GEHEN_DUMP)
    assert all(f['verbClass'] == 'strong' for f in forms)
    # dwdsmor знает ging → VALIDATED; если не знает → IRREGULAR, но форма есть
    gang = next(f for f in forms if f['spelling'] == 'ging')
    assert gang['status'] in ('VALIDATED', 'IRREGULAR')

def test_variant_tag_filtered():
    forms = generate_and_merge('Test', 'noun', VARIANT_DUMP)
    assert not any(f['spelling'] == 'Testen' for f in forms)
```

> **⚠ Открытый вопрос Q4:** `cleanRuLemma` — TypeScript-функция (NestJS) или Python? TASK-6 написан с TypeScript-сигнатурой, но шаг `links` читает `de-extract.jsonl.gz` через Python. Где именно выполняется очистка RU-перевода? Решается на этапе планирования TASK-3/TASK-6.

---

### TASK-4 · Обновить `upsertWordForms` — принимать bitmask из Python

**Статус:** ⚠️ работает как заглушка (сохраняет `{ tags: [...] }` в JSONB вместо `features INTEGER`)

**Контекст:** Python-пайплайн (TASK-3) уже возвращает типизированные батчи. Маппер тегов → признаков живёт в Python (dwdsmor + merge-логика). NestJS только кодирует готовые признаки в bitmask и пишет в БД.

**Что сделать:** адаптировать приём форм от Python HTTP стрима и хранение в новой схеме.

**Требования:**

Батч от Python (`POST /internal/import/forms`) содержит:
```typescript
interface IncomingWordForm {
  wordId: number;
  spelling: string;
  pos: PartOfSpeech;
  status: ValidationStatus;   // VALIDATED | IRREGULAR | FAILED
  fields: Record<string, unknown>;  // {case, number, gender, ...} — типизированные признаки
}
```

В `WiktionaryPipeline` (или новом `FormsImportStep`):
- Принять батч форм из NDJSON стрима
- Для каждой записи вызвать `encodeFeatures(pos, status, fields)` → `number` (INTEGER)
- Передать `{ wordId, spelling, features }` в `DictionaryFacade.upsertWordForms()`

В `WordImportRepository.upsertWordForms()`:
- Принять `{ wordId: number, spelling: string, features: number }[]`
- INSERT в `word_forms(word_id, spelling, features)` с `ON CONFLICT DO UPDATE SET features = EXCLUDED.features`
- Убрать старые поля `grammatical_features`, `validation_status`, `validation_meta`

`ValidationStatus.UNVERIFIED` не должен возникать — статус кодируется в bitmask (биты [3-4]).

**I · Runtime-валидация батча (Zod):**

Python — внешний сервис. На HTTP-границе NestJS валидирует каждый входящий батч:
```typescript
const IncomingWordFormSchema = z.object({
  wordId:  z.number().int().positive(),
  spelling: z.string().min(1),
  pos:     z.enum(['noun','verb','adj','pronoun','article','adv','other']),
  status:  z.enum(['VALIDATED','IRREGULAR','FAILED']),
  fields:  z.record(z.unknown()),
});
const IncomingBatchSchema = z.array(IncomingWordFormSchema);
```
Если батч не проходит Zod — весь батч логируется в `import_exceptions`, пропускается, прогон продолжается. Не допускать частичной записи невалидного батча.

**Критерий готовности:**
- `\d word_forms` → нет колонок `grammatical_features`, `validation_status`, `validation_meta`; есть `features INTEGER NOT NULL`
- `SELECT features FROM word_forms LIMIT 5` → целые числа, не JSON-строки
- Для `Haus`: `SELECT COUNT(*) FROM word_forms WHERE word_id = :haus_id` → 8
- `decodeFeatures(features)` для каждой формы `Haus` возвращает `{pos:'noun', case, number, gender:'n', declensionGroup, status:'VALIDATED'}`
- `SELECT COUNT(*) FROM word_forms WHERE (features >> 3) & 3 NOT IN (0,1,2)` → 0 (нет битовых мусорных значений — невалидный status=3 недопустим)
- Повторный запуск: `COUNT(*)` не изменился (idempotent ON CONFLICT upsert)

**Тест (fixture) — `__tests__/word-import.repository.spec.ts`:**
```typescript
const batch: IncomingWordForm[] = [
  { wordId: 1, spelling: 'Hauses', pos: 'noun', status: 'VALIDATED',
    fields: { case: 'gen', number: 'sg', gender: 'n', declensionGroup: 'strong' } },
  { wordId: 1, spelling: 'Häuser', pos: 'noun', status: 'VALIDATED',
    fields: { case: 'nom', number: 'pl', gender: 'n', declensionGroup: 'strong' } },
  { wordId: 2, spelling: 'ging',   pos: 'verb', status: 'IRREGULAR',
    fields: { tense: 'pret', mood: 'ind', person: 0, number: 'sg', verbClass: 'strong' } },
];

it('encodes and stores bitmask', async () => {
  await repository.upsertWordForms(batch);
  const rows = await db.query('SELECT spelling, features FROM word_forms WHERE word_id = 1 ORDER BY spelling');
  expect(rows).toHaveLength(2);
  expect(decodeFeatures(rows[0].features)).toMatchObject({ case: 'gen', status: 'VALIDATED' });
});

it('IRREGULAR verb stores person=0', async () => {
  await repository.upsertWordForms(batch);
  const row = await db.query('SELECT features FROM word_forms WHERE spelling = $1', ['ging']);
  expect(decodeFeatures(row[0].features)).toMatchObject({ status: 'IRREGULAR', person: 0 });
});

it('idempotent upsert', async () => {
  await repository.upsertWordForms(batch);
  await repository.upsertWordForms(batch);
  const count = await db.query('SELECT COUNT(*) FROM word_forms WHERE word_id IN (1, 2)');
  expect(Number(count[0].count)).toBe(3);
});
```

---

### TASK-5 · Шаг `pdf-seed` + whitelist интеграция

**Статус:** `extract_pdf_vocab.py` существует отдельно, не интегрирован

**Что сделать:** подключить PDF-экстракцию как шаг пайплайна в `WiktionaryPipeline` / `dict-import`.

**Входные данные:** `backend/data/68532-vocabulary-list-by-topic.pdf`

**Требования:**
- Вынести логику PDF-экстракции в `parser/pipelines/pdf_vocab.py` (FastAPI шаг `pdf-seed`)
- Python возвращает whitelist **в ответе**, не сохраняет на диск: `{"batch": ["Haus", "gehen", ...], "progress": {...}}`
- NestJS получает список, хранит в памяти сессии, передаёт как `whitelist` в следующие шаги (см. TASK-1 протокол)
- Нормализация: trim, collapse whitespace, длина ≥ 2, без мусорных символов
- Дубли внутри PDF → один элемент в whitelist (Set)

**G · Регистр в whitelist — немецкий язык:**

Немецкие существительные пишутся с заглавной буквы: `Morgen` (утро, сущ.) ≠ `morgen` (завтра, нареч.) — это разные слова с разным POS. Whitelist **сохраняет оригинальный регистр из PDF**.

Фильтрация при шаге `lemmas` — **case-sensitive**: `entry.word in whitelist` (без нормализации). Если PDF содержит `haus` вместо `Haus` — это gap, фиксируется в Coverage. Не пытаться угадывать регистр автоматически.

Исключение: дубли регистра одного и того же слова в PDF (`Haus` + `haus`) → оба хранятся в whitelist как разные строки. Python при фильтрации проверяет оба варианта: `entry.word in whitelist or entry.word.lower() in {w.lower() for w in whitelist}` — с предупреждением в лог при регистровом конфликте.

**Критерий готовности:**
- Шаг `pdf-seed` возвращает `>= 3000` лемм
- Следующий шаг `de-wiktionary` запускается с `whitelist != null` → только whitelist-слова попадают в БД
- `null`-whitelist (Full mode, без шага pdf-seed) → фильтрация отключена, все леммы принимаются

---

**Тест (fixture):**

Два артефакта в `parser/tests/fixtures/`:

**`test-vocab.pdf`** — минимальный PDF (~1 страница) с ровно 12 словами:

| Слово в PDF | Цель |
|---|---|
| `Haus` | базовый случай, есть в de-fixture |
| `gehen` | есть в de-fixture |
| `schön` | есть в de-fixture |
| `Schloss` | есть в de-fixture (полисемия) |
| `Fahrrad` | есть в de-fixture (gap word) |
| `  Morgen  ` | пробелы вокруг — нормализация: trim |
| `morgen` | то же слово в нижнем регистре — зависит от логики нормализации |
| `Haus` | дубль — whitelist не должен содержать дублей |
| `ABC123` | цифры — должен быть отфильтрован |
| `a` | len=1 — должен быть отфильтрован |
| `Guten Tag` | фраза с пробелом — в зависимости от стратегии: пропустить или split |

После `extract_pdf_vocab(test-vocab.pdf)`:
```python
assert len(whitelist) == 7          # без дублей и мусора
assert 'Haus' in whitelist
assert 'Fahrrad' in whitelist
assert 'ABC123' not in whitelist
assert 'a' not in whitelist
```

**Интеграция с de-fixture.jsonl:**

Прогон `pdf-seed` (test-vocab.pdf) + `lemmas` (de-fixture.jsonl):
- В `words` попадают только слова из пересечения whitelist ∩ fixture
- Слова из de-fixture, которых нет в whitelist → не попадают в `words`
- Повторный прогон: `COUNT(*)` не меняется

---

### TASK-6 · Шаг `links` — DE→RU концепты (NestJS)

**Статус:** ❌ отсутствует — нет связей DE↔RU в БД

**Что сделать:** новый метод в `WiktionaryPipeline` (или отдельный `LinksStep`). Один проход по `de-extract.jsonl.gz` — создать RU леммы и связать с DE через концепты.

**Требования:**

Переводы создаются **только для лемм**, не для словоформ.

**Очистка RU-перевода перед upsert** (`cleanRuLemma(raw: string): string | null`):
```
1. Удалить содержимое скобок:  "дом (здание)"       → "дом"
2. Взять первый вариант:       "здание, сооружение"  → "здание"
3. Удалить стилевые пометки:   "смерть высок."       → "смерть"
   (маркер без скобок в конце строки)
   Маски: /\s+(высок\.|разг\.|устар\.|книжн\.|поэт\.)$/
4. Проверить кириллицу:        нет [а-яёА-ЯЁ] → null (не сохранять)
5. длина < 2                   → null
```
`null` → запись пропускается, лог в `import_exceptions`.

**Разрешение омонимов — накопление sense_index:**

Wiktextract иногда разбивает одну лемму на несколько JSONL-записей (например, два значения "Schloss" — отдельными строками). При обработке второй записи с тем же `word_id`:
```
nextSenseIndex = SELECT MAX(sense_index) FROM word_senses WHERE word_id = X
                 → если NULL (первая запись) = 0
senses[i] → sense_index = nextSenseIndex + i + 1
```
`upsertWordSense` использует `ON CONFLICT (word_id, sense_index) DO NOTHING` — дубли не перезаписывают существующие привязки.

```
для каждой DE-записи где word_id принят:
  base = MAX(sense_index) для word_id (0 если нет)

  для каждого sense[i] из entry.senses:
    concept = facade.findOrCreateConcept()
    sense_id = facade.upsertWordSense(de_word_id, concept_id, base + i + 1)

    если sense.glosses[0] есть:
      facade.addSenseText(sense_id, de_lang_id, 'definition', glosses[0])

    ru_list = translations.filter(t => t.lang_code == 'ru' && t.sense_index == i+1)

    для каждого ru_translation:
      lemma = cleanRuLemma(ru.word)
      если lemma == null → skip
      ru_pos = mapWiktextractPos(ru.tags?.[0]) ?? mapWiktextractPos(de_entry.pos)
      ru_word_id = facade.upsertWord(lemma, RU_LANG_ID, ru_pos, ru_freq)
      facade.upsertWordSense(ru_word_id, concept_id, base + i + 1)
      facade.addToDictionary(dict_id, ru_word_id)

    facade.addToDictionary(dict_id, de_word_id)
```

`DictionaryFacade` нужно дополнить:
- `upsertWordSense(wordId, conceptId, senseIndex)` — INSERT word_senses ON CONFLICT DO NOTHING (уже частично есть через `findOrCreateWordSense`)
- `addToDictionary(dictId, wordId)` — INSERT dictionary_words

**H · Архитектурное ограничение концептов (MVP):**

В текущей реализации один концепт создаётся на каждый DE-sense, а не на каждое универсальное значение. Это означает:

```
"Haus"    → sense1 → concept#X → "дом"
"Gebäude" → sense1 → concept#Y → "дом"
```

`concept#X` и `concept#Y` — разные записи, хотя оба указывают на одно RU-слово. Настоящего межъязыкового выравнивания нет — `concepts` функционирует как таблица `translation_links`.

Для MVP это корректно: переводы отображаются правильно, связи DE↔RU работают. Настоящее слияние концептов (когда `Haus.sense1` и `Gebäude.sense1` должны указывать на один концепт) — задача CCMatrix alignment, post-MVP эпик.

**Критерий готовности:**

Данные:
- `SELECT COUNT(*) FROM concepts` → > 0 после прогона
- `SELECT COUNT(*) FROM word_senses WHERE word_id = :haus_id` → > 0 (DE-сторона)
- `SELECT COUNT(DISTINCT language_id) FROM words JOIN word_senses ON words.id = word_senses.word_id WHERE concept_id IN (SELECT concept_id FROM word_senses WHERE word_id = :haus_id)` → 2 (DE и RU)

cleanRuLemma:
- В `words` нет записей с леммами вида `"дом (здание)"`, `"здание, сооружение"`, `"(высок.)"` — только чистые леммы
- Перевод с пометкой `"разг."` или `"устар."` в скобках → пометка удалена, чистое слово сохранено

Омонимы:
- При двух JSONL-записях с одинаковым `word` + `pos`: sense_index у второй записи продолжает с `MAX + 1`, не перезаписывает первую
- `SELECT COUNT(*) FROM word_senses WHERE word_id = :schloss_id` → 2 (если Schloss в fixture имеет 2 значения)

Idempotency:
- Повторный прогон: `COUNT(*)` по `concepts`, `word_senses`, `sense_texts` не изменился

**Тест (fixture) — после прогона de-fixture.jsonl:**
```sql
-- Schloss: 2 концепта (castle + lock)
SELECT COUNT(*) FROM word_senses
WHERE word_id = (SELECT id FROM words WHERE lemma = 'Schloss');
-- ожидание: 2

-- Schloss sense 1 связан с RU-словом
SELECT rw.lemma FROM word_senses ws
JOIN word_senses ru ON ru.concept_id = ws.concept_id
JOIN words rw ON rw.id = ru.word_id AND rw.language_id = :ru_lang_id
WHERE ws.word_id = (SELECT id FROM words WHERE lemma = 'Schloss')
  AND ws.sense_index = 1;
-- ожидание: непустой результат (RU перевод первого смысла)

-- Haus: DE-глосс сохранён
SELECT text FROM sense_texts st
JOIN word_senses ws ON ws.id = st.sense_id
WHERE ws.word_id = (SELECT id FROM words WHERE lemma = 'Haus')
  AND st.language_id = :de_lang_id;
-- ожидание: 'Gebäude, das Menschen als Wohnstätte dient'

-- Fahrrad: нет RU word_sense (gap)
SELECT COUNT(*) FROM word_senses ws
JOIN word_senses ru ON ru.concept_id = ws.concept_id
JOIN words rw ON rw.id = ru.word_id AND rw.language_id = :ru_lang_id
WHERE ws.word_id = (SELECT id FROM words WHERE lemma = 'Fahrrad');
-- ожидание: 0
```

Повторный прогон де-fixture: все `COUNT(*)` те же самые — idempotency.

---

### TASK-7 · `freq` — частотные карты

**Статус:** `FrequencyMapLoader` существует

**Что сделать:** проверить, что `FrequencyMapLoader` корректно работает с обоими корпусами (DE и RU), покрытие и нормализация.

**Требования:**
- Формат файла: `rank TAB word TAB frequency`
- Ключ: `word.toLowerCase()` — регистронезависимый поиск
- `freqMap.get('haus') > 0` (ищем DE-слово в нижнем регистре)

**Критерий готовности:**
- `FrequencyMapLoader.load('deu_wikipedia_2021_1M-words.txt')` завершается без ошибок
- `freqMap.get('haus')` → число > 0
- `freqMap.get('Haus')` → то же число (case-insensitive)
- После шага `freq` в `words`: `SELECT frequency FROM words WHERE lemma = 'Haus'` → число из корпуса, не 0
- Слова из whitelist, которых нет в корпусе: `frequency = 0` (не NULL, не ошибка)
- `freqMap.get('xyz_несуществующее')` → `undefined` (не бросает исключение)

**Тест (fixture) — `backend/data/test/de-freq-fixture.txt`:**
```
1	der	1234567
2	die	1200000
3	und	1100000
4	Haus	85000
5	gehen	42000
```

```typescript
it('загружает частоты и нормализует ключи', async () => {
  const map = await loader.load('backend/data/test/de-freq-fixture.txt');
  expect(map.get('haus')).toBe(85000);    // lowercase lookup
  expect(map.get('Haus')).toBe(85000);    // case-insensitive
  expect(map.get('der')).toBe(1234567);
  expect(map.get('xyz')).toBeUndefined();
  expect(map.size).toBe(5);
});
```

---

### TASK-9 · Coverage monitor — мониторинг состояния связей

**Статус:** ❌ отсутствует

**Цель:** отслеживать покрытие DE→RU связей по словарю. Для уровней A1–C1 целевой показатель — 100%. Каждый запуск анализа сохраняется как снапшот — видно динамику после каждого прогона пайплайна.

---

#### 9.1 · Новая таблица `dict_coverage_snapshots`

```sql
CREATE TABLE dict_coverage_snapshots (
  id            SERIAL      PRIMARY KEY,
  dictionary_id INT         NOT NULL REFERENCES dictionaries(id) ON DELETE CASCADE,
  ran_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- общее
  words_total       INT NOT NULL,   -- DE слов в словаре
  words_with_ru     INT NOT NULL,   -- DE слов с хотя бы одним RU переводом
  words_without_ru  INT NOT NULL,   -- DE слов без RU перевода (gap)
  coverage_pct      NUMERIC(5,2) NOT NULL, -- words_with_ru / words_total * 100

  -- разбивка по POS
  by_pos  JSONB NOT NULL DEFAULT '{}',
  -- {"noun":{"total":1200,"with_ru":1180,"pct":98.3}, "verb":{...}, ...}

  -- разбивка по уровню CEFR (если заполнен cefr_level)
  by_level JSONB NOT NULL DEFAULT '{}',
  -- {"A1":{"total":300,"with_ru":300,"pct":100}, "A2":{...}, ...}

  -- слова без RU (для drill-down)
  gap_words JSONB NOT NULL DEFAULT '[]'
  -- [{"word":"Fahrrad","pos":"noun","frequency":4200}, ...]
);

CREATE INDEX ON dict_coverage_snapshots (dictionary_id, ran_at DESC);
```

---

#### 9.2 · Поле `cefr_level` на `words`

Для разбивки по уровням нужно знать уровень каждого слова. Источник — PDF (если там есть уровни) или вручную.

```sql
ALTER TABLE words ADD COLUMN cefr_level VARCHAR(2) NULL;
-- Допустимые значения: 'A1', 'A2', 'B1', 'B2', 'C1', 'C2', NULL
```

Добавить в `word.entity.ts` и заполнять при `pdf-seed`, если PDF содержит уровни.
Если PDF уровни не содержит — заполнять через отдельный шаг или оставить NULL (тогда `by_level` пуст).

---

#### 9.3 · `CoverageService` (NestJS, `dictionary` модуль)

```typescript
@Injectable()
class CoverageService {
  // Запустить анализ и сохранить снапшот
  async runSnapshot(dictId: number): Promise<CoverageSnapshot>

  // Получить последний снапшот
  async getLatest(dictId: number): Promise<CoverageSnapshot | null>

  // История снапшотов (для графика динамики)
  async getHistory(dictId: number, limit: number): Promise<CoverageSnapshot[]>
}
```

**SQL-запрос для основных метрик:**
```sql
-- COUNT(*) нельзя — многозначное слово (Schloss: 2 sense) даст 2 строки в JOIN.
-- COUNT(DISTINCT w.id) гарантирует подсчёт уникальных слов, а не строк.
SELECT
  w.part_of_speech                                                         AS pos,
  w.cefr_level                                                             AS level,
  COUNT(DISTINCT w.id)                                                     AS total,
  COUNT(DISTINCT CASE WHEN ws.id IS NOT NULL THEN w.id END)                AS with_concept,
  COUNT(DISTINCT CASE WHEN ru_link.id IS NOT NULL THEN w.id END)           AS with_ru
FROM dictionary_words dw
JOIN words w ON w.id = dw.word_id AND w.language_id = :de_lang_id
LEFT JOIN word_senses ws ON ws.word_id = w.id
LEFT JOIN word_senses ru_link
       ON ru_link.concept_id = ws.concept_id
      AND ru_link.word_id IN (
            SELECT id FROM words WHERE language_id = :ru_lang_id
          )
WHERE dw.dictionary_id = :dict_id
GROUP BY w.part_of_speech, w.cefr_level
```

**Gap words** (без RU) — отдельный запрос, топ-500 по частоте:
```sql
SELECT w.lemma, w.part_of_speech, w.frequency, w.cefr_level
FROM dictionary_words dw
JOIN words w ON w.id = dw.word_id AND w.language_id = :de_lang_id
WHERE dw.dictionary_id = :dict_id
  AND NOT EXISTS (
    SELECT 1 FROM word_senses ws
    JOIN word_senses ru ON ru.concept_id = ws.concept_id
    JOIN words rw ON rw.id = ru.word_id AND rw.language_id = :ru_lang_id
    WHERE ws.word_id = w.id
  )
ORDER BY w.frequency DESC
LIMIT 500
```

---

#### 9.4 · Экран Coverage в TUI

Доступен из главного меню TUI: **Покрытие переводов** → выбор словаря → выбор действия:

```
? Действие:
  ❯ Запустить новый анализ
    Показать последний снапшот
    Назад
```

**Вывод (одинаковый для обоих действий):**
```
══════════════════════════════════════════════════════════
  Coverage: de-topics-mvp  |  2026-05-20 14:32
══════════════════════════════════════════════════════════
  Всего DE слов:    4 218
  С RU переводом:   3 140   (74.4%)  ← текущее состояние
  Без RU перевода:  1 078   (25.6%)  ← gap

  По частям речи:
    noun       1 280 / 1 420   90.1%  ✓
    verb         890 / 1 200   74.2%  ⚠
    adj          710 /   980   72.4%  ⚠
    adv          180 /   350   51.4%  ✗
    other         80 /   268   29.8%  ✗

  По уровням:
    A1    320 /  320   100.0%  ✓✓
    A2    410 /  430    95.3%  ✓
    B1    820 / 1050    78.1%  ⚠
    B2    940 / 1450    64.8%  ✗
    C1    650 /  968    67.2%  ✗

  Топ-10 gap слов (по частоте):
    Fahrrad    (noun, B1, freq 4200)
    eigentlich (adv,  B1, freq 3900)
    ...

  ▲ vs предыдущий прогон: +312 слов получили RU (+8.1%)
══════════════════════════════════════════════════════════
```

"Последний снапшот" читает только `dict_coverage_snapshots`, без запросов к основным таблицам.

---

#### 9.5 · Критерий готовности

Механизм (не зависит от качества данных):
- `CoverageService.runSnapshot(dictId)` сохраняет запись в `dict_coverage_snapshots` и возвращает её
- `SELECT COUNT(*) FROM dict_coverage_snapshots WHERE dictionary_id = :id` → растёт с каждым вызовом (не перезаписывает)
- `getLatest(dictId)` читает только из `dict_coverage_snapshots`, не JOIN с основными таблицами
- `by_pos` и `by_level` — валидный JSON, не пустые `{}`  после прогона с реальными данными
- `gap_words` содержит список `{word, pos, frequency}` — не пустой если coverage < 100%
- `coverage_pct = words_with_ru / words_total * 100` — арифметика корректна (проверяется на fixture: 4 слова, 3 с переводом → 75.00%)

TUI (TASK-8 зависимость):
- После каждого прогона шагов TUI автоматически показывает экран Coverage
- Экран отображается даже если шаг упал с ошибкой

Цель проекта (не критерий TASK-9):
- `coverage_pct = 100%` для A1–C1 — достигается итерациями пайплайна + ручной разметкой gap_words, не является условием готовности самого TASK-9

**Тест (fixture) — после прогона de-fixture.jsonl:**
```typescript
it('снапшот содержит Fahrrad в gap_words', async () => {
  // de-fixture: Fahrrad без перевода → должен быть gap
  const snap = await coverageService.runSnapshot(dictId);
  expect(snap.wordsWithoutRu).toBeGreaterThan(0);
  expect(snap.gapWords.some(w => w.word === 'Fahrrad')).toBe(true);
  expect(snap.coveragePct).toBeLessThan(100);
});

it('два прогона → два снапшота, не перезаписывают друг друга', async () => {
  await coverageService.runSnapshot(dictId);
  await coverageService.runSnapshot(dictId);
  const history = await coverageService.getHistory(dictId, 10);
  expect(history.length).toBe(2);
  expect(history[0].ranAt > history[1].ranAt).toBe(true);
});

it('getLatest возвращает последний снапшот без запросов к основным таблицам', async () => {
  await coverageService.runSnapshot(dictId);
  // мокаем основные таблицы — getLatest не должен к ним обращаться
  const snap = await coverageService.getLatest(dictId);
  expect(snap).not.toBeNull();
  expect(snap!.wordsWithRu).toBeGreaterThan(0);
});
```

---

### TASK-8 · TUI — оркестрация шагов

**Статус:** `WiktionaryPipeline` существует, `dict-import-cli.module.ts` есть — нужно расширить

**Что сделать:** реализовать плоский цифровой TUI с фиксированными режимами генерации. Библиотека — `@clack/prompts`.

**Точка входа:** `nest start dict-import` — без аргументов открывает главное меню.

---

**Главное меню:**
```
┌─ LexBuild ─────────────────────────────────┐
│  Dictionary Import Tool                    │
└────────────────────────────────────────────┘

  1 · показать оценку связанности переводов
  2 · сгенерировать  DE → RU  [MVP]
  3 · сгенерировать  DE → RU  [Full]
  4 · сгенерировать  EN → RU  [MVP]
  5 · сгенерировать  EN → RU  [Full]
  - · удалить данные из таблиц словаря
  0 · выйти
```

---

**Режимы генерации (`PipelineMode`):**

| # | Режим | Источник данных | Whitelist | Шаги |
|---|---|---|---|---|
| 2 | `DE_RU_MVP` | `de-extract.jsonl.gz` | PDF whitelist DE | pdf-seed → freq → lemmas → forms → links |
| 3 | `DE_RU_FULL` | `de-extract.jsonl.gz` | нет | freq → lemmas → forms → links |
| 4 | `EN_RU_MVP` | `raw-wiktextract-data.jsonl.gz` (EN-записи) | PDF whitelist EN | pdf-seed → freq → lemmas → links |
| 5 | `EN_RU_FULL` | `raw-wiktextract-data.jsonl.gz` (EN-записи) | нет | freq → lemmas → links |

> EN-режимы не включают шаг `forms` — EN-словоформы по дизайну не хранятся в MVP.

> **⚠ Открытый вопрос (EN MVP whitelist):** для режимов 4 и 5 требуется EN vocabulary PDF или аналогичный источник whitelist. Файл определяется при реализации EN-пайплайна.

```typescript
enum PipelineMode {
  DE_RU_MVP  = 'DE_RU_MVP',
  DE_RU_FULL = 'DE_RU_FULL',
  EN_RU_MVP  = 'EN_RU_MVP',
  EN_RU_FULL = 'EN_RU_FULL',
}
```

---

**Пункт 1 — Оценка связанности:**

Вызывает `CoverageService.runSnapshot()` и отображает Coverage-отчёт (§9.4) на текущем состоянии БД без повторного прогона данных.

---

**Пункты 2–5 — Генерация:**

После выбора режима — запрос имени словаря:
```
? Словарь:
  ❯ de-topics-mvp        (для режимов 2, 3)
    en-topics-mvp        (для режимов 4, 5)
    ввести вручную
```

Прогресс каждого шага выводится inline:
```
Шаг lemmas [████████░░░░] 67%  |  2 826/4 218  |  2 400/s  |  ETA 28s
  Принято: 2 614   Пропущено: 212   (мусор=18 / POS=70 / whitelist=124)
```

После завершения всех шагов автоматически показывается Coverage-отчёт (аналог пункта 1).

---

**Пункт "-" — Удалить данные:**
```
⚠  Удалить все данные словаря и пересоздать схему?
   Операция: DROP + RECREATE всех таблиц словаря
   Затронутые таблицы: sense_texts, word_senses, word_forms,
                        words, concepts, word_relations,
                        dictionary_words, dictionaries,
                        import_runs, import_exceptions
   languages — не затрагивается

❯  Да, удалить и пересоздать
   Отмена
```
После подтверждения — DROP + RECREATE схемы из §0.1, затем seed `languages`.

---

**D · NestJS Standalone Application:**

TUI запускается не через `NestFactory.create()` (HTTP-сервер), а через:
```typescript
const app = await NestFactory.createApplicationContext(DictImportModule);
// ... TUI + pipeline ...
await app.close();
process.exit(0);
```
Без `app.close()` event loop зависает из-за открытых DB-коннектов. Без `process.exit(0)` — зависает из-за таймеров TypeORM/NestJS. Оба вызова обязательны в `finally`-блоке — даже при ошибке.

**Критерий готовности:**
- `nest start dict-import` без аргументов открывает главное меню с пунктами 0–5 и "-"
- Процесс завершается после "0" (`process.exit` вызван явно)
- При старте: `languages` seed проверяется и применяется до открытия меню
- Пункт "1" показывает Coverage-отчёт без повторного прогона данных
- Пункт "2" (DE\_RU\_MVP): запускает pdf-seed → freq → lemmas → forms → links; Coverage автоматически после завершения
- Пункт "3" (DE\_RU\_FULL): запускает freq → lemmas → forms → links без whitelist
- Пункты "4", "5": если EN-пайплайн не реализован — выводят "EN pipeline: not yet implemented", не крашатся
- Пункт "-": показывает предупреждение + подтверждение; без подтверждения — ничего; после подтверждения — DROP+RECREATE + languages seed
- Coverage-отчёт показывается автоматически после любого из пунктов 2–5, включая завершение с ошибкой
- Прогресс-бар показывает `accepted` / `skipped` счётчики для шага `lemmas`

**Тест (fixture) — оркестратор без TUI:**

TUI (`@clack/prompts`) не тестируется напрямую. Шаги выносятся в `PipelineOrchestrator`:
```typescript
class PipelineOrchestrator {
  async run(mode: PipelineMode, dictName: string): Promise<PipelineResult>
}
```

```typescript
it('DE_RU_MVP запускает все обязательные шаги в правильном порядке', async () => {
  const result = await orchestrator.run(PipelineMode.DE_RU_MVP, 'test-fixture');
  expect(result.steps.map(s => s.name))
    .toEqual(['pdf-seed', 'freq', 'lemmas', 'forms', 'links']);
  expect(result.coverageSnapshot).toBeDefined();
});

it('DE_RU_FULL не включает pdf-seed, whitelist=null', async () => {
  const result = await orchestrator.run(PipelineMode.DE_RU_FULL, 'test-fixture');
  expect(result.steps.map(s => s.name))
    .toEqual(['freq', 'lemmas', 'forms', 'links']);
  expect(result.whitelist).toBeNull();
});

it('coverage-снапшот создаётся даже если шаг упал', async () => {
  jest.spyOn(lemmasStep, 'run').mockRejectedValueOnce(new Error('forced'));
  const result = await orchestrator.run(PipelineMode.DE_RU_MVP, 'test-fixture');
  expect(result.steps.find(s => s.name === 'lemmas')!.status).toBe('error');
  expect(result.coverageSnapshot).toBeDefined();
});
```

---

## 7. Валидатор лемм

Существует в `WiktionaryPipeline` частично (POS-фильтр есть). Нужно добавить остальные проверки.

| Проверка | Условие отклонения | Лог |
|---|---|---|
| POS | `pos not in pos_accept` | `skip_pos` |
| Мусорные символы | содержит `<>{}[]`, управляющие символы, цифры | `skip_garbage` |
| Пробелы | пробел или дефис в начале/конце | `skip_phrase` |
| Алфавит | RU: не кириллица | `skip_alphabet` |
| Длина | `len < 2` | `skip_length` |
| Короткое редкое | `2 ≤ len ≤ 3` И `frequency < short_word_min_freq` | `skip_rare_short` |
| Частота | `frequency < min_freq` | `skip_freq` |

Короткие частые слова (`die`, `der`, `in`, `zu`) должны проходить — они нужны на уровне A1.

---

## 8. Порядок реализации

```
TASK-0 + TASK-4  ⚠ АТОМАРНО         ← один коммит: схема БД + entity-файлы + upsertWordForms
                                        между ними tsc не компилируется
TASK-1  Parser API + utils/jsonl.py  ← разблокирует всё остальное (Python читает файлы)
TASK-2  DeExtractEntry DTO           ← нужен для TASK-3 и TASK-6
TASK-3  Forms pipeline (Python)      ← ключевая задача: dwdsmor + merge с дампом
TASK-5  pdf-seed интеграция          ← независимо от других
TASK-6  links шаг                   ← после TASK-1 и TASK-2
TASK-7  freq проверка               ← быстро, параллельно с другими
TASK-9  coverage monitor            ← таблица (прямой SQL) + сервис + TUI-экран
TASK-8  TUI оркестрация             ← в конце, когда шаги готовы
```

---

## 9. Ожидаемый результат MVP

| Метрика | Оценка |
|---|---|
| DE лемм | ~3 000–5 000 (объём PDF) |
| RU лемм | ~1 400–2 400 (47% DE имеют RU перевод) |
| DE концептов | ~7 000–11 000 |
| word_forms (DE) | ~27 000–46 000 (avg 9 форм/слово) |
| word_forms (RU) | 0 (по дизайну) |
| sense_texts (DE) | ~3 000–5 000 (немецкие глоссы) |

---

## 10. Тестирование

### 10.1 · Unit — `encodeFeatures` / `decodeFeatures`

Roundtrip-тесты до любого прогона данных. Запускаются в CI.

| Кейс | Проверяет |
|---|---|
| noun: encode → decode → те же поля | roundtrip noun |
| verb: encode → decode → те же поля | roundtrip verb |
| adj: encode → decode → те же поля | roundtrip adj |
| verb с `person=0` (unknown) + `status=IRREGULAR` | граничные значения bitmask |
| `status=FAILED`, любой POS | все значения статуса |
| `encodeFeatures` двух разных форм → разные числа | коллизии |

---

### 10.2 · Fixture — интеграционный тест пайплайна

Минимальный файл `backend/data/test/de-fixture.jsonl` (~20 записей). Запускается отдельно через `npm run test:fixture` перед прогоном реальных данных.

| # | Лемма | Что проверяет |
|---|---|---|
| 1 | `Haus` (noun, neuter, forms[]) | noun полный путь: 8 форм, gender, declension |
| 2 | `gehen` (verb, strong, ging/gegangen) | нерегулярный глагол, verbClass=strong |
| 3 | `schön` (adj) | adj: все степени (pos/comp/sup) и типы склонения |
| 4 | `Schloss` (noun, 2 sense, 2 RU перевода) | полисемия: 2 концепта, 4 word_senses |
| 5 | `Fahrrad` (noun, без translations[]) | gap word: нет RU — должен попасть в gap_words |
| 6 | `Haus` — дубль той же записи | идемпотентность: row counts не растут |
| 7 | `x` (len=1) | лемма-фильтр: skip_length |
| 8 | глагол без `forms[]` | word без word_forms: 0 форм, не ошибка |
| 9 | запись с `variant`/`obsolete` тегом на форме | форма-фильтр: не попадает в word_forms |

**Ожидаемое состояние БД после прогона fixture:**

```sql
SELECT COUNT(*) FROM words;           -- фиксированное число (без дублей)
SELECT COUNT(*) FROM word_forms
  WHERE word_id = (SELECT id FROM words WHERE lemma = 'Haus');  -- ровно 8

SELECT COUNT(*) FROM concepts
  WHERE id IN (SELECT concept_id FROM word_senses
    WHERE word_id = (SELECT id FROM words WHERE lemma = 'Schloss'));  -- ровно 2

SELECT COUNT(*) FROM word_senses
  WHERE concept_id IN (...Schloss концепты...);  -- ровно 4 (2 DE + 2 RU)

-- нет форм gehen со статусом FAILED или corrupt bitmask
SELECT COUNT(*) FROM word_forms
  WHERE word_id = (SELECT id FROM words WHERE lemma = 'gehen')
    AND (features >> 3) & 3 IN (2, 3);  -- FAILED=2 или corrupt=3 → ожидание: 0
```

**Повторный прогон fixture:** все `COUNT(*)` те же самые.

---

### 10.3 · Post-run проверка (реальные данные)

После полного MVP-прогона с `de-extract.jsonl.gz` + PDF whitelist:

```sql
-- нет corrupt bitmask (status=3 зарезервировано, недопустимо)
SELECT COUNT(*) FROM word_forms WHERE (features >> 3) & 3 = 3;  -- → 0

-- нет сырых JSONB-остатков
SELECT COUNT(*) FROM word_forms WHERE features IS NULL;  -- → 0

-- известное слово из PDF есть в БД
SELECT lemma FROM words WHERE lemma = 'Haus' AND language_id = :de_lang_id;  -- → 1 строка

-- для Haus есть хотя бы один RU перевод
SELECT rw.lemma FROM word_senses ws
JOIN word_senses ru ON ru.concept_id = ws.concept_id
JOIN words rw ON rw.id = ru.word_id AND rw.language_id = :ru_lang_id
WHERE ws.word_id = (SELECT id FROM words WHERE lemma = 'Haus');  -- → 'дом'

-- повторный прогон не увеличивает строки
-- запустить прогон ещё раз → те же COUNT(*) по всем таблицам
```

**Coverage-критерий:**
- `coverage_pct` для A1 = 100% **или** `gap_words` содержит конкретный список слов для ручной разметки
- `gap_words` пустой = MVP готов к релизу (по критерию §0)

---

### 10.4 · Где запускать

| Тип | Когда | Как |
|---|---|---|
| Unit (encodeFeatures) | при каждом изменении entity/util | `jest` в CI |
| Fixture | перед каждым прогоном реальных данных | `npm run test:fixture` |
| Post-run SQL | после каждого полного прогона | TUI показывает автоматически (Coverage-экран) |

---

## 11. Вне скопа MVP

| Задача | Описание | Когда |
|---|---|---|
| **RU-enrichment** | Обогатить RU-леммы из `ru-extract.jsonl.gz`: русские определения в `sense_texts`, частоты | После MVP |
| **EN forms** | Импорт EN-словоформ (go → went, gone, going) | После EN-pipeline |
| **CCMatrix alignment** | Статистическое выравнивание DE-RU через 45M предложений | Отдельная задача |
| **Full-DE run** | Весь `de-extract.jsonl.gz` без whitelist, фильтр по частоте | TUI пункт 3 |

> **EN→RU pipeline** (пункты 4 и 5 TUI) — реализуется отдельно от DE→RU. Источник: `raw-wiktextract-data.jsonl.gz` (EN-записи). Кнопки 4/5 присутствуют в TUI с первого релиза; до реализации EN-пайплайна выводят "not yet implemented".

> **До первого прогона пайплайна** (не часть итерируемых TASK, но блокирует чистую кодовую базу): удалить устаревший код — `align_de_ru.py`, `wikiextract_de_ru.py`, `generate_definitions.py`, `LemmaAnalysisConsumer`.

---

## 12. Разделение ответственности

```
Python: parser/ (FastAPI :8000)
  • utils/jsonl.py      — stream_jsonl(): читает .jsonl.gz и .jsonl стримом
  • pipelines/          — пайплайны под каждый источник:
      de_wiktionary.py  — de-extract.jsonl.gz           (DE→RU режимы 2, 3)
      en_wiktionary.py  — raw-wiktextract-data.jsonl.gz (EN→RU режимы 4, 5)
      ru_wiktionary.py  — ru-extract.jsonl.gz           (RU-enrichment, post-MVP)
      pdf_vocab.py      — PDF whitelist (DE и EN)
      freq.py           — частотные корпуса
  • main.py             — FastAPI: POST /pipeline/run → NDJSON стрим батчей
  • НЕ пишет в БД напрямую
        │  HTTP POST батчи (~500 записей)
        ▼
NestJS: dict-import
  • TUI (плоское меню: 0–5, "-"), PipelineOrchestrator
  • PipelineMode: DE_RU_MVP | DE_RU_FULL | EN_RU_MVP | EN_RU_FULL
  • Вызывает parser HTTP API, читает NDJSON стрим
  • encodeFeatures(pos, status, fields) → INTEGER bitmask (util из TASK-0)
  • НЕ пишет в БД напрямую
        │  вызовы сервисов
        ▼
NestJS: DictionaryModule  ← ЕДИНСТВЕННЫЙ ПИСАТЕЛЬ В БД
  • DictionaryFacade / WordImportRepository
  • upsertWord / upsertWordForms / findOrCreateWordSense / ...
  • FormValidatorRegistry → стратегии по lang:pos
  • Гарантирует целостность схемы
```

`modules/wiktionary/languages/de.py` — **вне скопа LexBuild**: веб-скрапер de.wiktionary.org, парсит HTML живого сайта, не связан с `.jsonl.gz` дампами.
