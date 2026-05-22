# Epic: LexBuild — планы реализации

## Статус задач

| Задача | Репо | Статус | Коммит |
|---|---|---|---|
| TASK-0 · Сброс БД, bitmask схема | back | ✅ выполнен | `7f52fd7` |
| TASK-1 · Parser API + utils/jsonl.py | parser | ✅ выполнен | `66c1dbd` |
| TASK-1 · ParserHttpClient + config | back | ✅ выполнен | `ca63f55` |
| TASK-2 · KaikkiEntry → DeExtractEntry | back | ✅ выполнен | `91ab8fc` |
| TASK-3 · Forms pipeline (Python, dwdsmor) | parser | ✅ выполнен | — |
| TASK-4 · upsertWordForms — bitmask из Python | back | ✅ выполнен | `4eb527b` |
| TASK-5 · pdf-seed + whitelist интеграция | parser | ✅ выполнен | — |
| TASK-6 · Шаг links — DE→RU концепты | back + parser | ✅ выполнен | `a75e4d3` (back) `52ce4fc` (parser) |
| TASK-7 · freq — частотные карты | back + parser | ✅ выполнен | `161f479` |
| TASK-8 · TUI — оркестрация шагов | back | ✅ выполнен | `8905f9d` |
| TASK-9 · Coverage monitor | back | ✅ выполнен | `d6457cb` |
| TASK-10 · Multi-PDF seed из папки | parser + back | ✅ выполнен | — |
| TASK-11 · Pipeline v2 — уровни, мульти-источник, качество форм | parser + back | ✅ выполнен | — |
| TASK-12 · Word properties + полные формы глаголов | parser + back | ✅ выполнен | — |

**Порядок выполнения:** TASK-2 → TASK-5 → TASK-3 → TASK-4 → TASK-6 → TASK-7 → TASK-8 → TASK-9 → TASK-10 → TASK-11 → TASK-12

---

## Оглавление

- [TASK-0 · Сброс БД и оптимизация схемы](#task-0--сброс-бд-и-оптимизация-схемы)
  - [0.1 · Изменения схемы (migration)](#01--изменения-схемы-migration)
  - [0.2 · Entity-файлы](#02--entity-файлы)
  - [0.3 · word-form-features.ts](#03--word-form-featurests)
  - [0.4 · Тесты](#04--тесты)
  - [0.5 · word-import.repository.ts](#05--word-importrepositoryts)
  - [0.6 · DTOs и сервисы — минимальное исправление](#06--dtos-и-сервисы--минимальное-исправление)
  - [0.7 · Константы языков](#07--константы-языков)
  - [0.8 · resetDictionary()](#08--resetdictionary)
  - [0.9 · Проверка перед импортом и обработка дублей](#09--проверка-перед-импортом-и-обработка-дублей)
  - [0.10 · Порядок файлов и коммит](#010--порядок-файлов-и-коммит)
- [TASK-1 · Parser API + utils/jsonl.py](#task-1--parser-api--utilsjsonlpy)
  - [Ключевой принцип](#ключевой-принцип-nestjs-управляет-данными-python-читает)
  - [Типы данных — полные определения](#типы-данных--полные-определения)
  - [Контракт POST /pipeline/run](#контракт-post-pipelinerun)
  - [Что передаёт NestJS для каждого шага](#что-передаёт-nestjs-для-каждого-шага)
  - [NestJS config](#nestjs-config)
  - [Файлы](#файлы)
  - [Порядок реализации](#порядок-реализации)
  - [Детали реализации](#детали-реализации)
- [TASK-2 · DeExtractEntry DTO + IncomingWordForm fix](#task-2--deextractentry-dto--incomingwordform-fix)
- [TASK-5 · pdf-seed pipeline step](#task-5--pdf-seed-pipeline-step)
- [TASK-7 · freq — частотные карты](#task-7--freq--частотные-карты)
- [TASK-3 · Forms pipeline (Python, dwdsmor)](#task-3--forms-pipeline-python-dwdsmor)
- [TASK-4 · Интеграция forms в WiktionaryPipeline](#task-4--интеграция-forms-в-wiktionarypipeline)
- [TASK-6 · links — DE→RU концепты](#task-6--links--deru-концепты)
- [TASK-9 · Coverage monitor](#task-9--coverage-monitor)
- [TASK-8 · TUI — оркестрация шагов](#task-8--tui--оркестрация-шагов)
- [TASK-12 · Word properties + полные формы глаголов](#task-12--word-properties--полные-формы-глаголов)
- [TASK-10 · Multi-PDF seed из папки](#task-10--multi-pdf-seed-из-папки)
- [TASK-11 · Pipeline v2 — уровни CEFR, мульти-источник переводов, качество форм](#task-11--pipeline-v2--уровни-cefr-мульти-источник-переводов-качество-форм)

---

## TASK-0 · Сброс БД и оптимизация схемы

**Статус:** ❌ нужно сделать перед любым прогоном

**Важно:** TASK-0 + TASK-4 — один атомарный коммит. Схема БД, entity-файлы, `encodeFeatures`/`upsertWordForms` идут вместе — частичное применение оставляет код в несогласованном состоянии.

---

### 0.1 · Изменения схемы (migration)

Файл: `src/database/migrations/1748000000000-InitialSchema.ts`

**`word_forms` — главная оптимизация:**

```sql
-- Было:
grammatical_features  JSONB   NOT NULL
validation_status     ENUM    NOT NULL DEFAULT 'UNVERIFIED'
validation_meta       JSONB   NULL
frequency             INT     NOT NULL DEFAULT 0
created_at            TIMESTAMPTZ NOT NULL
updated_at            TIMESTAMPTZ NOT NULL

-- Стало:
features              INTEGER NOT NULL
-- + добавить: CONSTRAINT UQ_word_forms_word_spelling UNIQUE (word_id, spelling)
-- + удалить индекс IDX_word_forms_validation_status
```

**`words`:**

```sql
-- Удалить:
validation_meta     JSONB   NULL
total_frequency     INT     NOT NULL
created_at          TIMESTAMPTZ NOT NULL
updated_at          TIMESTAMPTZ NOT NULL
-- Удалить индекс IDX_words_validation_status
-- Удалить validation_status_enum (DROP TYPE)
```

**`concepts`:**

```sql
-- Удалить:
image_url           VARCHAR(512) NULL
image_generated_at  TIMESTAMPTZ NULL
created_at          TIMESTAMPTZ NOT NULL
updated_at          TIMESTAMPTZ NOT NULL
```

**`word_senses`:**

```sql
-- Удалить:
created_at  TIMESTAMPTZ NOT NULL
updated_at  TIMESTAMPTZ NOT NULL
```

**`sense_texts`:**

```sql
-- Удалить:
created_at  TIMESTAMPTZ NOT NULL
```

**`down()`** — восстановить все удалённые колонки и enum.

---

### 0.2 · Entity-файлы

| Файл | Что изменить |
|---|---|
| `entity/word-form.entity.ts` | Удалить `grammaticalFeatures`, `validationStatus`, `validationMeta`, `frequency`, `createdAt`, `updatedAt`. Добавить `@Column({ type: 'int' }) features: number` |
| `entity/word.entity.ts` | Удалить `validationStatus`, `validationMeta`, `totalFrequency`, `createdAt`, `updatedAt` |
| `entity/concept.entity.ts` | Удалить `imageUrl`, `imageGeneratedAt`, `createdAt`, `updatedAt` — оставить только `id` |
| `entity/word-sense.entity.ts` | Удалить `createdAt`, `updatedAt` |
| `entity/sense-text.entity.ts` | Удалить `createdAt` |

---

### 0.3 · word-form-features.ts

Создать: `src/modules/dictionary/utils/word-form-features.ts`

**Сигнатуры:**

```typescript
export type PosKey    = 'noun' | 'verb' | 'adj' | 'pronoun' | 'article' | 'adv' | 'other';
export type StatusKey = 'VALIDATED' | 'IRREGULAR' | 'FAILED';

export interface DecodedFeatures {
  pos: PosKey;
  status: StatusKey;
  case?: 'nom' | 'gen' | 'dat' | 'acc';
  number?: 'sg' | 'pl';
  gender?: 'm' | 'f' | 'n';
  declensionGroup?: 'strong' | 'weak' | 'mixed';
  tense?: 'present' | 'pret' | 'perf' | 'pluperf' | 'fut1' | 'fut2';
  mood?: 'ind' | 'konj1' | 'konj2' | 'imp';
  person?: 0 | 1 | 2 | 3;
  verbClass?: 'weak' | 'strong' | 'mixed' | 'modal';
  isReflexive?: boolean;
  declensionType?: 'strong' | 'weak' | 'mixed';
  degree?: 'pos' | 'comp' | 'sup';
}

// Маппинг PartOfSpeech (enum) → PosKey (bitmask)
export function posKeyFromPartOfSpeech(pos: PartOfSpeech): PosKey;

export function encodeFeatures(pos: PosKey, status: StatusKey, fields: Record<string, unknown>): number;
export function decodeFeatures(n: number): DecodedFeatures;
```

**Bitmask-раскладка (canonical из Epic §0.1):**

```
bits[0-2]:  POS        noun=0 verb=1 adj=2 pronoun=3 article=4 adv=5 other=6
bits[3-4]:  Status     VALIDATED=0 IRREGULAR=1 FAILED=2

noun  [5-6]:case(nom=0/gen=1/dat=2/acc=3)
      [7]:number(sg=0/pl=1)
      [8-9]:gender(m=0/f=1/n=2)
      [10-11]:declensionGroup(strong=0/weak=1/mixed=2)

verb  [5-7]:tense(present=0/pret=1/perf=2/pluperf=3/fut1=4/fut2=5)
      [8-9]:mood(ind=0/konj1=1/konj2=2/imp=3)
      [10-11]:person(unknown=0/1/2/3)
      [12]:number(sg=0/pl=1)
      [13-14]:verbClass(weak=0/strong=1/mixed=2/modal=3)
      [15]:isReflexive

adj   [5-6]:case  [7]:number  [8-9]:gender
      [10-11]:declensionType(strong=0/weak=1/mixed=2)
      [12-13]:degree(pos=0/comp=1/sup=2)
```

**Примечания:**
- `person=0` означает "неизвестно/IRREGULAR", 1/2/3 — первое/второе/третье лицо
- `article` для noun вычисляется из gender при чтении (m→der, f→die, n→das), не хранится
- `INTEGER` (не `SMALLINT`) — бит 15 (`isReflexive`) даёт значение до 32768+, что выходит за пределы SMALLINT

---

### 0.4 · Тесты

Создать: `src/modules/dictionary/utils/__test__/word-form-features.spec.ts`

```typescript
it('noun roundtrip', () => {
  const n = encodeFeatures('noun', 'VALIDATED', { case: 'gen', number: 'sg', gender: 'n', declensionGroup: 'strong' });
  expect(decodeFeatures(n)).toMatchObject({ pos: 'noun', status: 'VALIDATED', case: 'gen', number: 'sg', gender: 'n' });
});

it('IRREGULAR verb stores person=0 as unknown', () => {
  const n = encodeFeatures('verb', 'IRREGULAR', { tense: 'pret', mood: 'ind', person: 0, number: 'sg', verbClass: 'strong' });
  const d = decodeFeatures(n);
  expect(d.status).toBe('IRREGULAR');
  expect(d.person).toBe(0);
});

it('different case values produce different bitmasks', () => {
  const nom = encodeFeatures('noun', 'VALIDATED', { case: 'nom', number: 'sg', gender: 'n', declensionGroup: 'strong' });
  const gen = encodeFeatures('noun', 'VALIDATED', { case: 'gen', number: 'sg', gender: 'n', declensionGroup: 'strong' });
  expect(nom).not.toBe(gen);
});

it('adj roundtrip with degree=comp', () => {
  const n = encodeFeatures('adj', 'VALIDATED', { case: 'nom', number: 'sg', gender: 'm', declensionType: 'strong', degree: 'comp' });
  expect(decodeFeatures(n)).toMatchObject({ pos: 'adj', degree: 'comp', case: 'nom' });
});

it('reflexive verb encodes to non-negative INTEGER value', () => {
  const n = encodeFeatures('verb', 'VALIDATED', {
    tense: 'present', mood: 'ind', person: 3, number: 'sg', verbClass: 'strong', isReflexive: true,
  });
  expect(n).toBeGreaterThan(0);
  expect(n).toBeLessThanOrEqual(2147483647);
});
```

---

### 0.5 · word-import.repository.ts

Файл: `src/modules/dictionary/repository/word-import.repository.ts`

**`upsertWord` — убрать старые поля:**

```sql
-- Было:
INSERT INTO words (lemma, language_id, part_of_speech, frequency, total_frequency, validation_status, validation_meta)
VALUES ($1, $2, $3, $4, $4, 'UNVERIFIED', '{}')
ON CONFLICT (language_id, lemma, part_of_speech)
DO UPDATE SET frequency = GREATEST(words.frequency, EXCLUDED.frequency)

-- Стало:
INSERT INTO words (lemma, language_id, part_of_speech, frequency)
VALUES ($1, $2, $3, $4)
ON CONFLICT (language_id, lemma, part_of_speech)
DO UPDATE SET frequency = GREATEST(words.frequency, EXCLUDED.frequency)
```

**`upsertWordForms` — новая сигнатура:**

```typescript
// Было:
async upsertWordForms(wordId: number, forms: { spelling: string; tags: string[] }[]): Promise<void>

// Стало:
async upsertWordForms(forms: { wordId: number; spelling: string; features: number }[]): Promise<void>
```

```sql
INSERT INTO word_forms (word_id, spelling, features)
VALUES ($1, $2, $3)
ON CONFLICT (word_id, spelling)
DO UPDATE SET features = EXCLUDED.features
```

Убрать импорты `ValidationStatus`, `GrammaticalFeatures`. Заменить `formRepo.find()` + `formRepo.save()` на прямой SQL.

---

### 0.6 · DTOs и сервисы — минимальное исправление

Изменения сущностей ломают компиляцию в нескольких местах. Минимальные правки:

| Файл | Что изменить |
|---|---|
| `dto/word-form-response.dto.ts` | Удалить `grammaticalFeatures`, `validationStatus`, `validationMeta`, `createdAt`, `updatedAt`. Добавить `features: number` |
| `dto/word-response.dto.ts` | Удалить `validationStatus`, `validationMeta`, `createdAt`, `updatedAt` |
| `dto/word-sense-response.dto.ts` | Удалить `createdAt`, `updatedAt` |
| `dto/create-word-form.dto.ts` | Удалить `validationStatus` |
| `dto/create-word.dto.ts` | Удалить `validationStatus` |
| `service/word-form.service.ts` | `toResponse`: маппить `form.features`. `createForWord`: вызвать `encodeFeatures(posKey, status, validatedFields)` вместо JSONB |
| `service/word.service.ts` | `toResponse`: удалить `validationStatus`, `validationMeta`, `createdAt`, `updatedAt` |
| `service/word-sense.service.ts` | `toResponse`: удалить `createdAt`, `updatedAt` |

**Остальные файлы, ссылающиеся на `ValidationStatus`** (`lemma-analysis.consumer.ts`, стратегии валидаторов, `de.types.ts`) — **не трогать**. Обновляются в TASK-3.

---

### 0.7 · Константы языков

Создать: `src/database/seeds/languages.seed.ts` — только константы для использования в коде, **не авто-сид**.

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

Заполнение таблицы `languages` — ручная операция, выполняется один раз после создания БД.

---

### 0.8 · Порядок файлов и коммит

```
1.  src/modules/dictionary/utils/word-form-features.ts               (создать)
2.  src/modules/dictionary/utils/__test__/word-form-features.spec.ts (создать)
3.  src/database/seeds/languages.seed.ts                             (создать)
4.  src/database/migrations/1748000000000-InitialSchema.ts           (изменить)
5.  src/modules/dictionary/entity/word-form.entity.ts                (изменить)
6.  src/modules/dictionary/entity/word.entity.ts                     (изменить)
7.  src/modules/dictionary/entity/concept.entity.ts                  (изменить)
8.  src/modules/dictionary/entity/word-sense.entity.ts               (изменить)
9.  src/modules/dictionary/entity/sense-text.entity.ts               (изменить)
10. src/modules/dictionary/dto/word-form-response.dto.ts             (изменить)
11. src/modules/dictionary/dto/word-response.dto.ts                  (изменить)
12. src/modules/dictionary/dto/word-sense-response.dto.ts            (изменить)
13. src/modules/dictionary/dto/create-word-form.dto.ts               (изменить)
14. src/modules/dictionary/dto/create-word.dto.ts                    (изменить)
15. src/modules/dictionary/service/word-form.service.ts              (изменить)
16. src/modules/dictionary/service/word.service.ts                   (изменить)
17. src/modules/dictionary/service/word-sense.service.ts             (изменить)
18. src/modules/dictionary/repository/word-import.repository.ts      (изменить)
```

Один коммит: `feat(db): TASK-0+4 bitmask schema — replace JSONB with features INTEGER`

**Критерии готовности:**
- `tsc --noEmit` — без ошибок
- Тесты `word-form-features.spec.ts` — зелёные
- `\d word_forms` → `features INTEGER NOT NULL`, `UNIQUE(word_id, spelling)`, нет старых колонок
- `\d words` → нет `validation_meta`, `total_frequency`, `created_at`, `updated_at`
- `\d concepts` → нет `image_url`, `image_generated_at`, `created_at`, `updated_at`
- `SELECT COUNT(*) FROM languages` → 3

---

### 0.8 · resetDictionary()

Добавить в `DictionaryFacade` (`src/modules/dictionary/dictionary.facade.ts`):

```typescript
async resetDictionary(): Promise<void> {
  await this.wordRepo.manager.query(`
    TRUNCATE TABLE
      sense_texts, word_senses, word_forms, word_relations,
      words, concepts, dictionary_words, dictionaries
    RESTART IDENTITY CASCADE
  `);
}
```

`RESTART IDENTITY` сбрасывает `SERIAL`-счётчики. `CASCADE` снимает необходимость ручного упорядочивания по FK.

**TUI (TASK-8)** — пункт `Reset dictionary data`:
```
⚠  Clear all dictionary data?
   Tables: sense_texts, word_senses, word_forms, word_relations,
           words, concepts, dictionary_words, dictionaries
   languages, import_runs, import_exceptions — preserved

❯  Yes, reset
   Cancel
```

---

### 0.9 · Проверка перед импортом и обработка дублей

**Pre-import word count** — добавить в `DictionaryFacade`:

```typescript
async getWordCountPerLanguage(): Promise<{ languageId: number; count: number }[]> {
  return this.wordRepo.manager.query(
    `SELECT language_id, COUNT(*)::int AS count FROM words GROUP BY language_id`
  );
}
```

Пайплайн вызывает перед первым батчем. TUI выводит и продолжает без блокировки:
```
Dictionary status:
  DE (id=1): 3 500 words
  RU (id=2): 1 200 words
Mode: append
```

---

**Duplicate handling** — когда `upsertWord` срабатывает на `ON CONFLICT` (слово уже есть):

```typescript
// upsertWord returns { id: number; isNew: boolean }
if (!result.isNew) {
  await this.importRunService.logException(runId, {
    word: lemma,
    frequency,
    reason: ImportExceptionReason.DUPLICATE_LEMMA,
  });
}
```

Добавить значение в enum (`import-exception-reason.enum.ts`):
```typescript
export enum ImportExceptionReason {
  TOO_SHORT        = 'too_short',
  ANALYZER_ERROR   = 'analyzer_error',
  VALIDATION_ERROR = 'validation_error',
  DUPLICATE_LEMMA  = 'duplicate_lemma', // word already existed before this run
}
```

Миграция:
```sql
ALTER TYPE "import_exception_reason_enum" ADD VALUE 'duplicate_lemma';
```

**TODO:** омографы (одинаковое написание, разный POS) — проверка через dwds движок. Вне скоупа MVP.

---

### 0.10 · Порядок файлов и коммит

(см. [0.8 · Порядок файлов и коммит](#08--порядок-файлов-и-коммит) — переименован в 0.10)

Добавить к списку файлов из §0.8:
```
19. src/modules/dictionary/dictionary.facade.ts           (изменить — добавить resetDictionary, getWordCountPerLanguage)
20. src/modules/dict-import/domain/enums/import-exception-reason.enum.ts  (изменить — добавить duplicate_lemma)
21. src/database/migrations/1748000000000-InitialSchema.ts                (изменить — ADD VALUE duplicate_lemma)
```

---

## TASK-1 · Parser API + utils/jsonl.py

---

### Ключевой принцип: NestJS управляет данными, Python читает

**NestJS — оркестратор:**
- Хранит в конфиге пути ко всем файлам данных
- Знает какой файл читать, какую схему данных ожидать, в каком порядке запускать шаги
- Передаёт `file_path`, `lang_code`, `whitelist`, `word_id_map` в каждом вызове Python
- Пишет в БД через `DictionaryFacade`

**Python — чистая функция:**
- Не знает о расположении `backend/data/` и не хранит конфиг путей
- Получил `file_path` + параметры → прочитал файл → вернул батчи → забыл
- Та же логика работает с любым файлом по любому пути

```
NestJS config          NestJS orchestrator         Python
──────────────         ───────────────────         ──────
DE_DUMP_PATH ─────────→ POST /pipeline/run  ─────→ stream_jsonl(file_path)
DE_FREQ_PATH           {                           filter(lang_code, whitelist)
DE_PDF_PATH              step: "lemmas",           yield batches
                         file_path: ...,     ←─── [entry, entry, ...]
                         lang_code: "de",
                         whitelist: [...]
                       }
```

---

### Q2 — согласование имён шагов (закрыт)

Канонический enum (из TASK-8, конечного потребителя):

```
"pdf-seed" | "freq" | "lemmas" | "forms" | "links"
```

`"de-wiktionary"` и `"ru-wiktionary"` упразднены. Язык передаётся через `lang_code`.

---

### Типы данных — полные определения

#### Типы батчей (по шагу)

```typescript
// Запись из kaikki/de-extract JSONL для шага "lemmas"
export interface DeExtractEntry {
  word:      string;
  pos:       string;           // 'noun' | 'verb' | 'adj' | ...
  lang_code: string;
  senses:    Array<{
    glosses:   string[];
    synonyms?: Array<{ word: string }>;
    antonyms?: Array<{ word: string }>;
  }>;
  forms?:    Array<{
    form:  string;
    tags?: string[];
  }>;
}

// Запись для шага "forms" (TASK-3)
export interface IncomingWordForm {
  lemma:                string;
  spelling:             string;
  grammatical_features: Record<string, unknown>;
}

// Запись для шага "freq"
export interface FreqEntry {
  word:      string;
  frequency: number;
}

// Запись для шага "links"
export interface LinkEntry {
  de_lemma:    string;
  ru_lemma:    string;
  sense_index: number;
  gloss:       string;
}

// Прогресс стрима
export interface Progress {
  done:  number;
  total: number | null;  // null = неизвестно (один проход без предварительного счёта)
}

// Generic батч — T зависит от шага
export interface PipelineBatch<T> {
  batch:    T[];
  progress: Progress;
}

// Карта типов батчей по шагу
export type StepBatchMap = {
  'pdf-seed': string;
  'freq':     FreqEntry;
  'lemmas':   DeExtractEntry;
  'forms':    IncomingWordForm;
  'links':    LinkEntry;
};
export type PipelineStep = keyof StepBatchMap;
```

#### Контракт запроса

```typescript
export interface PipelineRunRequest<S extends PipelineStep = PipelineStep> {
  step:        S;
  file_path:   string;
  lang_code:   'de' | 'ru' | 'en';
  whitelist:   string[] | null;
  word_id_map: Record<string, number> | null;  // только для step='forms'
  dict_name?:  string;                         // опционально, только для логов
}
```

---

### Контракт POST /pipeline/run

**Request** (Pydantic, Python):

```python
class PipelineRunRequest(BaseModel):
    step:        Literal['pdf-seed', 'freq', 'lemmas', 'forms', 'links']
    file_path:   str = Field(..., min_length=1)
    lang_code:   Literal['de', 'ru', 'en'] = 'de'
    whitelist:   list[str] | None = None
    word_id_map: dict[str, int] | None = None
    dict_name:   str | None = None  # опционально, для логов
```

**Response:** `StreamingResponse`, `Content-Type: application/x-ndjson`

Каждая строка — JSON + `\n`:

```json
{"batch": [...до 500 записей...], "progress": {"done": 500, "total": null}}
```

`total: null` — неизвестно до конца прохода (один проход по файлу).

---

### Что передаёт NestJS для каждого шага

| Step | `file_path` из конфига NestJS | `lang_code` | `whitelist` | `word_id_map` | Python возвращает |
|---|---|---|---|---|---|
| `"pdf-seed"` | `DATA_DE_PDF_PATH` | `"de"` | null | null | `string[]` |
| `"freq"` | `DATA_DE_FREQ_PATH` | `"de"` | null | null | `FreqEntry[]` |
| `"lemmas"` | `DATA_DE_DUMP_PATH` | `"de"` | `string[]` или null | null | `DeExtractEntry[]` |
| `"forms"` | `DATA_DE_DUMP_PATH` | `"de"` | `string[]` или null | `{lemma→id}` | `IncomingWordForm[]` |
| `"links"` | `DATA_DE_DUMP_PATH` | `"de"` | `string[]` или null | null | `LinkEntry[]` |

---

### NestJS config

Новые переменные добавляются в `src/config/schema/env.schema.ts`:

```typescript
// env.schema.ts — добавить в объект envSchema:
PARSER_URL:          z.string().url().default('http://parser:8000'),
DATA_DE_DUMP_PATH:   z.string().min(1).default('/data/de-extract.jsonl.gz'),
DATA_DE_FREQ_PATH:   z.string().min(1).default('/data/deu_wikipedia_2021_1M-words.txt'),
DATA_DE_PDF_PATH:    z.string().min(1).default('/data/vocabulary.pdf'),
DATA_EN_DUMP_PATH:   z.string().min(1).default('/data/raw-wiktextract-data.jsonl.gz'),
DATA_EN_FREQ_PATH:   z.string().min(1).default('/data/eng_wikipedia_2016_1M-words.txt'),
```

Добавить интерфейсы в `src/config/app.contract.ts`:

```typescript
export interface ParserConfig {
  url: string;
}

export interface DataPathsConfig {
  deDump:  string;
  deFreq:  string;
  dePdf:   string;
  enDump:  string;
  enFreq:  string;
}
```

Добавить в `RootConfig`:

```typescript
[CONFIG_NAMESPACE.PARSER]:     ParserConfig;
[CONFIG_NAMESPACE.DATA_PATHS]: DataPathsConfig;
```

Создать `src/config/namespaces/parser.config.ts` и `data-paths.config.ts` по образцу существующих namespace-файлов (`registerAs` + `envSchema.parse(process.env)`).

---

### Файлы

| Действие | Файл |
|---|---|
| Создать | `parser/utils/__init__.py` |
| Создать | `parser/utils/jsonl.py` |
| Создать | `parser/pipelines/__init__.py` |
| Создать | `parser/pipelines/de_wiktionary.py` — шаг `"lemmas"` |
| Изменить | `parser/main.py` — добавить `POST /pipeline/run` |
| Создать | `parser/tests/__init__.py` |
| Создать | `parser/tests/conftest.py` |
| Создать | `parser/tests/fixtures/de-mini.jsonl` |
| Создать | `parser/tests/fixtures/de-mini.jsonl.gz` |
| Создать | `parser/tests/test_jsonl.py` |
| Изменить | `src/config/schema/env.schema.ts` — добавить PARSER_URL, DATA_* |
| Изменить | `src/config/app.contract.ts` — добавить ParserConfig, DataPathsConfig |
| Изменить | `src/config/const.config.ts` — добавить PARSER, DATA_PATHS в CONFIG_NAMESPACE |
| Создать | `src/config/namespaces/parser.config.ts` |
| Создать | `src/config/namespaces/data-paths.config.ts` |
| Изменить | `src/config/index.ts` — зарегистрировать новые namespace |
| Создать | `src/modules/dict-import/dto/pipeline.dto.ts` — все типы батчей |
| Создать | `src/modules/dict-import/clients/parser-http.client.ts` |
| Изменить | `src/modules/dict-import/pipeline/wiktionary.pipeline.ts` |
| Удалить | `src/modules/dict-import/readers/jsonl-reader.service.ts` |
| Удалить | `src/modules/dict-import/readers/file-reader.interface.ts` |
| Изменить | `src/modules/dict-import/dict-import.module.ts` |

---

### Порядок реализации

```
1. parser/utils/jsonl.py + __init__.py
2. parser/pipelines/ + de_wiktionary.py (шаг "lemmas")
3. parser/main.py — POST /pipeline/run
4. parser/tests/ + conftest.py + фикстуры + test_jsonl.py
5. NestJS: env.schema.ts + app.contract.ts + CONFIG_NAMESPACE
6. NestJS: parser.config.ts + data-paths.config.ts + регистрация в index.ts
7. NestJS: pipeline.dto.ts (все типы батчей)
8. NestJS: parser-http.client.ts
9. NestJS: обновить wiktionary.pipeline.ts
10. NestJS: удалить readers/, обновить dict-import.module.ts
```

---

### Детали реализации

#### 1 · parser/utils/jsonl.py

```python
import gzip
import json
from typing import Generator

def stream_jsonl(path: str, batch_size: int = 500) -> Generator[list, None, None]:
    opener = gzip.open if path.endswith('.gz') else open
    with opener(path, 'rt', encoding='utf-8') as f:
        batch: list = []
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

#### 2 · parser/pipelines/de_wiktionary.py — шаг "lemmas"

```python
from typing import Generator
from utils.jsonl import stream_jsonl

def run_lemmas(
    file_path: str,
    lang_code: str,
    whitelist: set[str] | None,
    batch_size: int = 500,
) -> Generator[tuple[list, int], None, None]:
    done = 0
    for raw_batch in stream_jsonl(file_path, batch_size):
        out = [
            e for e in raw_batch
            if e.get('lang_code') == lang_code
            and (whitelist is None or e['word'] in whitelist)
        ]
        done += len(raw_batch)
        if out:
            yield out, done

# Шаги TASK-3, TASK-5, TASK-6, TASK-7 — заглушки
def run_forms(*_args, **_kwargs):
    raise NotImplementedError('forms: implemented in TASK-3')

def run_links(*_args, **_kwargs):
    raise NotImplementedError('links: implemented in TASK-6')

def run_pdf_seed(*_args, **_kwargs):
    raise NotImplementedError('pdf-seed: implemented in TASK-5')

def run_freq(*_args, **_kwargs):
    raise NotImplementedError('freq: implemented in TASK-7')
```

---

#### 3 · parser/main.py — добавить POST /pipeline/run

Существующий код (`/health`, `/parse`, lifespan) — не трогаем. Добавляем:

```python
import json
from pydantic import BaseModel, Field
from typing import Literal
from fastapi import HTTPException
from fastapi.responses import StreamingResponse
from pipelines.de_wiktionary import run_lemmas

class PipelineRunRequest(BaseModel):
    step:        Literal['pdf-seed', 'freq', 'lemmas', 'forms', 'links']
    file_path:   str = Field(..., min_length=1)
    lang_code:   Literal['de', 'ru', 'en'] = 'de'
    whitelist:   list[str] | None = None
    word_id_map: dict[str, int] | None = None
    dict_name:   str | None = None

_ALLOWED_DATA_DIRS = ['/data', '/app/data']

def _validate_file_path(path: str) -> None:
    """Prevent path traversal — file_path must be under an allowed directory."""
    from pathlib import Path
    resolved = str(Path(path).resolve())
    if not any(resolved.startswith(d) for d in _ALLOWED_DATA_DIRS):
        raise HTTPException(status_code=400, detail='file_path outside allowed directories')

@app.post('/pipeline/run')
async def pipeline_run(req: PipelineRunRequest):
    _validate_file_path(req.file_path)

    async def generate():
        if req.step == 'lemmas':
            wl = set(req.whitelist) if req.whitelist else None
            for batch, done in run_lemmas(req.file_path, req.lang_code, wl):
                yield json.dumps({'batch': batch, 'progress': {'done': done, 'total': None}}) + '\n'
        else:
            raise HTTPException(status_code=400, detail=f'Step not implemented: {req.step}')

    return StreamingResponse(generate(), media_type='application/x-ndjson')
```

---

#### 4 · parser/tests/conftest.py

`TestClient` — синхронный, подходит для NDJSON-стрима (читает body целиком). Для unit-тестов пайплайна — обычные функции, не async.

```python
import pytest
from pathlib import Path
from fastapi.testclient import TestClient
from main import app

@pytest.fixture
def client() -> TestClient:
    return TestClient(app)

@pytest.fixture
def fixture_path():
    base = Path(__file__).parent / 'fixtures'
    return lambda name: str(base / name)
```

---

#### 5 · parser/tests/test_jsonl.py

```python
import json
import pytest
from utils.jsonl import stream_jsonl
from pipelines.de_wiktionary import run_lemmas
from fastapi.testclient import TestClient

def test_stream_jsonl_gz_reads_all(fixture_path):
    batches = list(stream_jsonl(fixture_path('de-mini.jsonl.gz'), batch_size=2))
    assert len(batches) == 3          # 5 записей по 2: [2, 2, 1]
    assert sum(len(b) for b in batches) == 5

def test_stream_jsonl_plain_reads_all(fixture_path):
    batches = list(stream_jsonl(fixture_path('de-mini.jsonl'), batch_size=500))
    assert len(batches) == 1
    assert len(batches[0]) == 5

def test_pipeline_run_streams_ndjson(client: TestClient, fixture_path):
    resp = client.post('/pipeline/run', json={
        'step': 'lemmas',
        'file_path': fixture_path('de-mini.jsonl'),
        'lang_code': 'de',
    })
    assert resp.status_code == 200
    lines = [json.loads(l) for l in resp.text.splitlines() if l]
    assert all('batch' in l and 'progress' in l for l in lines)
    assert lines[-1]['progress']['done'] >= 5
    assert lines[-1]['progress']['total'] is None

def test_whitelist_filters_lemmas(fixture_path):
    result = list(run_lemmas(fixture_path('de-mini.jsonl'), lang_code='de', whitelist={'Haus'}))
    words = [e['word'] for batch, _ in result for e in batch]
    assert words == ['Haus']

def test_lang_code_filters_other_languages(fixture_path):
    result = list(run_lemmas(fixture_path('de-mini.jsonl'), lang_code='ru', whitelist=None))
    assert result == []

def test_path_traversal_rejected(client: TestClient):
    resp = client.post('/pipeline/run', json={
        'step': 'lemmas',
        'file_path': '../../etc/passwd',
        'lang_code': 'de',
    })
    assert resp.status_code == 400

def test_invalid_lang_code_rejected(client: TestClient, fixture_path):
    resp = client.post('/pipeline/run', json={
        'step': 'lemmas',
        'file_path': fixture_path('de-mini.jsonl'),
        'lang_code': 'xx',  # не в Literal['de','ru','en']
    })
    assert resp.status_code == 422
```

---

#### 6 · src/modules/dict-import/dto/pipeline.dto.ts

```typescript
export type PipelineStep = 'pdf-seed' | 'freq' | 'lemmas' | 'forms' | 'links';
export type LangCode = 'de' | 'ru' | 'en';

export interface PipelineRunRequest<S extends PipelineStep = PipelineStep> {
  step:        S;
  file_path:   string;
  lang_code:   LangCode;
  whitelist:   string[] | null;
  word_id_map: Record<string, number> | null;
  dict_name?:  string;
}

export interface Progress {
  done:  number;
  total: number | null;
}

export interface PipelineBatch<T> {
  batch:    T[];
  progress: Progress;
}

export interface DeExtractEntry {
  word:      string;
  pos:       string;
  lang_code: string;
  senses:    Array<{
    glosses:   string[];
    synonyms?: Array<{ word: string }>;
    antonyms?: Array<{ word: string }>;
  }>;
  forms?: Array<{ form: string; tags?: string[] }>;
}

export interface IncomingWordForm {
  lemma:                string;
  spelling:             string;
  grammatical_features: Record<string, unknown>;
}

export interface FreqEntry {
  word:      string;
  frequency: number;
}

export interface LinkEntry {
  de_lemma:    string;
  ru_lemma:    string;
  sense_index: number;
  gloss:       string;
}

export type StepBatchMap = {
  'pdf-seed': string;
  'freq':     FreqEntry;
  'lemmas':   DeExtractEntry;
  'forms':    IncomingWordForm;
  'links':    LinkEntry;
};
```

Zod-схема для валидации каждой NDJSON-строки на входе NestJS:

```typescript
import { z } from 'zod';

const ProgressSchema = z.object({
  done:  z.number().int().nonnegative(),
  total: z.number().int().nullable(),
});

export const PipelineBatchSchema = z.object({
  batch:    z.array(z.unknown()),
  progress: ProgressSchema,
});
```

---

#### 7 · src/modules/dict-import/clients/parser-http.client.ts

```typescript
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { type RootConfig } from '@/config/app.contract';
import { CONFIG_NAMESPACE } from '@/config/const.config';
import {
  type PipelineRunRequest,
  type PipelineBatch,
  type PipelineStep,
  type StepBatchMap,
  PipelineBatchSchema,
} from '../dto/pipeline.dto';

@Injectable()
export class ParserHttpClient {
  @InjectPinoLogger(ParserHttpClient.name)
  private readonly logger!: PinoLogger;

  private readonly parserUrl: string;

  constructor(private readonly config: ConfigService<RootConfig, true>) {
    this.parserUrl = config.get(CONFIG_NAMESPACE.PARSER, { infer: true }).url;
  }

  async *runStep<S extends PipelineStep>(
    request: PipelineRunRequest<S>,
  ): AsyncGenerator<PipelineBatch<StepBatchMap[S]>> {
    const response = await fetch(`${this.parserUrl}/pipeline/run`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(request),
    });

    if (!response.ok || !response.body) {
      throw new Error(`Parser responded ${response.status} for step=${request.step}`);
    }

    for await (const line of splitLines(response.body)) {
      const parsed = PipelineBatchSchema.parse(JSON.parse(line));
      yield parsed as PipelineBatch<StepBatchMap[S]>;
    }
  }
}

/** Splits a ReadableStream<Uint8Array> into complete UTF-8 lines. */
async function* splitLines(body: ReadableStream<Uint8Array>): AsyncGenerator<string> {
  const decoder = new TextDecoder();
  let buf = '';
  for await (const chunk of body as unknown as AsyncIterable<Uint8Array>) {
    buf += decoder.decode(chunk, { stream: true });
    const lines = buf.split('\n');
    buf = lines.pop() ?? '';
    for (const line of lines) {
      if (line.trim()) yield line;
    }
  }
  if (buf.trim()) yield buf;
}
```

**Ключевые решения:**
- `runStep<S extends PipelineStep>` — generic, тип батча выводится из шага через `StepBatchMap`
- `PipelineBatchSchema.parse()` — валидация каждой строки через Zod перед кастом
- `splitLines` — корректная обработка chunked transfer (строка может прийти в нескольких chunk)
- **Запрещено:** `response.text()`, `response.json()` — OOM на 1.3M записей

---

#### 8 · Обновить WiktionaryPipeline (NestJS)

```typescript
// before — NestJS читал файл напрямую:
for await (const batch of this.jsonlReader.readBatches(filePath, { batchSize: 200 })) { ... }

// after — NestJS оркестрирует, Python читает:
try {
  for await (const { batch, progress } of this.parserClient.runStep({
    step:      'lemmas',
    file_path: this.dataPaths.deDump,   // из DataPathsConfig через ConfigService
    lang_code: 'de',
    whitelist,
    word_id_map: null,
  })) {
    for (const raw of batch) {          // raw: DeExtractEntry — типизировано
      const { id: wordId } = await this.facade.upsertWord(raw.word, lang.id, partOfSpeech, frequency);
      // ...
    }
    await this.runService.updateProgress(run.id, progress.done, { processed: totalWords, errors: totalErrors });
  }
  await this.runService.markDone(run.id);
} catch (err: unknown) {
  await this.runService.markFailed(run.id);
  throw err;
}
```

`this.dataPaths` — инжектируется через `ConfigService`:
```typescript
private readonly dataPaths: DataPathsConfig;

constructor(..., config: ConfigService<RootConfig, true>) {
  this.dataPaths = config.get(CONFIG_NAMESPACE.DATA_PATHS, { infer: true });
}
```

---

## Критерии готовности

### TASK-0

- `tsc --noEmit` — без ошибок
- Тесты `word-form-features.spec.ts` — зелёные
- `\d word_forms` → `features INTEGER NOT NULL`, `UNIQUE(word_id, spelling)`, нет старых колонок
- `\d words` → нет `validation_meta`, `total_frequency`, `created_at`, `updated_at`
- `\d concepts` → нет `image_url`, `image_generated_at`, `created_at`, `updated_at`
- `SELECT COUNT(*) FROM languages` → 3

### TASK-1

- `GET http://parser:8000/health` → 200 OK
- `POST /pipeline/run {step:"lemmas", file_path:"/data/de-mini.jsonl", lang_code:"de"}` → NDJSON стрим с `total: null`
- `POST /pipeline/run {whitelist:["Haus"]}` → только "Haus" в батчах
- `POST /pipeline/run {file_path:"../../etc/passwd"}` → 400
- `POST /pipeline/run {lang_code:"xx"}` → 422
- `tsc --noEmit` — без ошибок (все типы батчей выведены через `StepBatchMap`)
- `grep -r "JsonlReaderService" src/` → пусто
- `grep -r "process\.env\.DATA_" src/` → только `data-paths.config.ts`
- `grep -r "JsonlReaderService" src/` → пусто

---

## TASK-2 · DeExtractEntry DTO + IncomingWordForm fix

**Репо:** back
**Блокирует:** TASK-3, TASK-4, TASK-6
**Заблокирована:** —

**Проблемы которые решает:**
- `kaikki-entry.dto.ts` существует параллельно с `pipeline.dto.ts` — дублирование
- `DeExtractEntry` в `pipeline.dto.ts` неполный: нет `translations`, `tags`, `categories`
- `IncomingWordForm` в `pipeline.dto.ts` неправильная форма: TASK-4 ждёт `{wordId, spelling, fields, status}`, а сейчас `{lemma, spelling, grammatical_features}`

### IN
- `src/modules/dict-import/dto/kaikki-entry.dto.ts` — старый файл
- `src/modules/dict-import/dto/pipeline.dto.ts` — неполные типы

### OUT
- `kaikki-entry.dto.ts` — **удалён**
- `pipeline.dto.ts` — обновлены `DeExtractEntry`, `IncomingWordForm`, добавлен `mapWiktextractPos()`

### Изменения

**`pipeline.dto.ts` — обновить `DeExtractEntry`:**

```typescript
export interface DeExtractTranslation {
  word: string;
  lang_code: string;
  lang?: string;
  sense_index?: string;
  tags?: string[];
}

export interface DeExtractEntry {
  word: string;
  lang: string;
  lang_code: string;
  pos: string;
  tags?: string[];                       // gender леммы: 'neuter', 'masculine', 'feminine'
  forms?: Array<{ form: string; tags?: string[] }>;
  senses?: Array<{
    glosses?: string[];
    sense_index?: string;
    synonyms?: Array<{ word: string }>;
    antonyms?: Array<{ word: string }>;
    tags?: string[];
  }>;
  translations?: DeExtractTranslation[]; // DE→RU/EN переводы
  categories?: string[];                 // нужны для verbClass ('Starke Verben' → strong)
}
```

**`pipeline.dto.ts` — исправить `IncomingWordForm`:**

```typescript
// Запись для шага "forms" (от Python к NestJS)
export interface IncomingWordForm {
  wordId:   number;                  // из word_id_map переданного NestJS
  spelling: string;
  pos:      'noun' | 'verb' | 'adj' | 'pronoun' | 'article' | 'adv' | 'other';
  status:   'VALIDATED' | 'IRREGULAR' | 'FAILED';
  fields:   Record<string, unknown>; // {case, number, gender, ...} — типизированные признаки
}
```

**`pipeline.dto.ts` — добавить `mapWiktextractPos()`:**

```typescript
const WIKTEXTRACT_POS_MAP: Record<string, PartOfSpeech | null> = {
  noun: PartOfSpeech.Noun,
  name: PartOfSpeech.Noun,
  verb: PartOfSpeech.Verb,
  adj: PartOfSpeech.Adjective,
  adv: PartOfSpeech.Adverb,
  particle: PartOfSpeech.Adverb,
  pron: PartOfSpeech.Pronoun,
  article: PartOfSpeech.Article,
  det: PartOfSpeech.Article,
  num: PartOfSpeech.Numeral,
  prep: null,   // SKIP
  conj: null,
  intj: null,
  suffix: null,
  prefix: null,
  phrase: null,
  symbol: null,
  abbrev: null,
};

export function mapWiktextractPos(raw: string): PartOfSpeech | null {
  if (raw in WIKTEXTRACT_POS_MAP) return WIKTEXTRACT_POS_MAP[raw];
  // unknown POS — log warning (caller decides whether to skip)
  return null;
}
```

**Удалить:** `src/modules/dict-import/dto/kaikki-entry.dto.ts`

**Обновить `wiktionary.pipeline.ts`:** заменить импорт `KAIKKI_POS` на вызов `mapWiktextractPos(entry.pos)`.

### Критерии готовности

- `grep -r "KaikkiEntry\|kaikki-entry" src/` → пусто
- `tsc --noEmit` — без ошибок
- `npm run lint` — без ошибок
- `DeExtractEntry` содержит поля `translations`, `tags`, `categories`
- `IncomingWordForm` содержит `wordId`, `status`, `fields` (не `grammatical_features`)
- `mapWiktextractPos('noun')` → `PartOfSpeech.Noun`, `mapWiktextractPos('suffix')` → `null`

---

## TASK-5 · pdf-seed pipeline step

**Репо:** parser
**Блокирует:** TASK-8 (MVP mode требует whitelist)
**Заблокирована:** TASK-1 ✅

### IN
- `DATA_DE_PDF_PATH` — путь к PDF (передаётся NestJS в `file_path`)
- `step: "pdf-seed"` в `POST /pipeline/run`

### OUT
- `parser/pipelines/pdf_vocab.py` — логика извлечения лемм из PDF
- `POST /pipeline/run {step:"pdf-seed"}` → NDJSON стрим `string[]` батчей
- NestJS получает whitelist в памяти и передаёт в следующие шаги

### Реализация

**`parser/pipelines/pdf_vocab.py`:**

```python
import pdfplumber
from typing import Generator

_MIN_LEN = 2
_GARBAGE_CHARS = set('<>{}[]0123456789')

def run_pdf_seed(file_path: str, batch_size: int = 500) -> Generator[tuple[list[str], int], None, None]:
    seen: set[str] = set()
    batch: list[str] = []
    done = 0

    with pdfplumber.open(file_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text() or ''
            for line in text.splitlines():
                word = line.strip()
                if not word or len(word) < _MIN_LEN:
                    continue
                if any(c in _GARBAGE_CHARS for c in word):
                    continue
                if word in seen:
                    continue
                seen.add(word)
                batch.append(word)
                done += 1
                if len(batch) >= batch_size:
                    yield batch, done
                    batch = []

    if batch:
        yield batch, done
```

**`parser/main.py`** — добавить ветку в `generate()`:

```python
from pipelines.pdf_vocab import run_pdf_seed

# в generate() внутри pipeline_run:
elif req.step == 'pdf-seed':
    for batch, done in run_pdf_seed(req.file_path):
        yield json.dumps({'batch': batch, 'progress': {'done': done, 'total': None}}) + '\n'
```

Добавить `'pdf-seed'` в `_IMPLEMENTED_STEPS`.

**NestJS — `WiktionaryPipeline`:** добавить шаг pdf-seed перед lemmas:

```typescript
// Шаг 0: получить whitelist из PDF
const whitelist: string[] | null = opts.whitelist ?? await this._runPdfSeed();

private async _runPdfSeed(): Promise<string[]> {
  const words: string[] = [];
  for await (const { batch } of this.parserClient.runStep({
    step: 'pdf-seed',
    file_path: this.dePdf,    // из DataPathsConfig
    lang_code: 'de',
    whitelist: null,
    word_id_map: null,
  })) {
    words.push(...(batch as string[]));
  }
  this.logger.info({ count: words.length }, 'pdf-seed whitelist loaded');
  return words;
}
```

### Критерии готовности

- `POST /pipeline/run {step:"pdf-seed", file_path:"/data/vocabulary.pdf"}` → NDJSON с `string[]`
- Результат содержит ≥ 3 000 слов
- Дубли исключены (`Set`-фильтр)
- Слова длиной < 2 и содержащие цифры — исключены
- `PYTHONPATH=. venv/bin/python3 -m pytest tests/test_pdf_seed.py -v` — зелёный
- Whitelist передаётся в шаг `lemmas` → только whitelist-слова попадают в `words`

---

## TASK-7 · freq — частотные карты

**Репо:** back + parser
**Блокирует:** TASK-8 (частоты нужны для Coverage)
**Заблокирована:** TASK-1 ✅

**Проблема:** `FrequencyMapLoader` не нормализует ключи — `freqMap.get('haus')` → `undefined`, хотя в файле `Haus`.

### IN (parser)
- `DATA_DE_FREQ_PATH` — TSV-файл формата `rank TAB word TAB frequency`

### OUT
- Parser: `run_freq()` → `FreqEntry[]` батчи через NDJSON
- Back: `FrequencyMapLoader.load()` исправлен (case-insensitive)
- Back: шаг `freq` в `WiktionaryPipeline` — обновляет `words.frequency`

### Реализация

**Parser — `parser/pipelines/de_wiktionary.py`** добавить `run_freq()`:

```python
def run_freq(file_path: str, lang_code: str, whitelist: set[str] | None,
             batch_size: int = 500) -> Generator[tuple[list, int], None, None]:
    done = 0
    batch = []
    with open(file_path, 'rt', encoding='utf-8') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) < 3:
                continue
            word, freq = parts[1], int(parts[-1])
            if whitelist is not None and word not in whitelist and word.lower() not in {w.lower() for w in whitelist}:
                continue
            batch.append({'word': word, 'frequency': freq})
            done += 1
            if len(batch) >= batch_size:
                yield batch, done
                batch = []
    if batch:
        yield batch, done
```

Добавить `'freq'` в `_IMPLEMENTED_STEPS` и ветку в `generate()`.

**Back — `frequency-map.loader.ts`** — исправить нормализацию:

```typescript
// Было: map.set(word, freq)
// Стало: map.set(word.toLowerCase(), freq)
// При поиске: map.get(word.toLowerCase())
```

**Back — `WiktionaryPipeline`** — добавить шаг freq после lemmas:

```typescript
// После шага lemmas: обновить частоты
for await (const { batch } of this.parserClient.runStep({
  step: 'freq',
  file_path: this.deFreq,
  lang_code: 'de',
  whitelist,
  word_id_map: null,
})) {
  for (const entry of batch as FreqEntry[]) {
    await this.facade.upsertWord(entry.word, lang.id, /* preserve pos */ PartOfSpeech.Noun, entry.frequency);
  }
}
```

> Уточнение: `upsertWord` с `ON CONFLICT DO UPDATE SET frequency = GREATEST(...)` — POS не перезаписывается если слово уже есть.

### Критерии готовности

- `freqMap.get('haus')` → число > 0 (lowercase lookup)
- `freqMap.get('Haus')` → то же число
- После шага freq: `SELECT frequency FROM words WHERE lemma = 'Haus'` → число из корпуса, не 0
- Слова не в whitelist: не попадают в freq-батч (если whitelist задан)
- `npm run lint && npx tsc --noEmit` — без ошибок

---

## TASK-3 · Forms pipeline (Python, dwdsmor)

**Репо:** parser
**Блокирует:** TASK-4
**Заблокирована:** TASK-2 (тип `IncomingWordForm` определён)

**dwdsmor установлен:** v0.18.0 ✅

### IN
- `word_id_map: {lemma: wordId}` — передаётся NestJS в теле запроса
- `file_path` — путь к `de-extract.jsonl.gz` (для dump-форм)
- `lang_code: "de"`

### OUT
- `IncomingWordForm[]` батчи через NDJSON: `{wordId, spelling, pos, status, fields}`
- `fields` содержит типизированные признаки из bitmask-раскладки TASK-0

### Реализация

**`parser/pipelines/de_forms.py`:**

```python
import dwdsmor
from utils.jsonl import stream_jsonl

_FILTER_TAGS = {'variant', 'alternative', 'obsolete', 'abbreviation', 'auxiliary'}

def _dwdsmor_generate(lemma: str, pos: str) -> list[dict]:
    """Generate paradigm via dwdsmor FST."""
    try:
        return dwdsmor.generate(lemma, pos)  # returns list of {form, features}
    except Exception:
        return []

def _merge(generated: list[dict], dump_forms: list[dict]) -> list[dict]:
    dump_spellings = {f['form'] for f in dump_forms
                      if not any(t in _FILTER_TAGS for t in f.get('tags', []))}
    result = []
    for gf in generated:
        status = 'VALIDATED'
        result.append({**gf, 'status': status})
    for df in dump_forms:
        if any(t in _FILTER_TAGS for t in df.get('tags', [])):
            continue
        if df['form'] not in {r['spelling'] for r in result}:
            result.append({'spelling': df['form'], 'status': 'IRREGULAR',
                           'fields': _partial_fields_from_tags(df.get('tags', []))})
    return result

def run_forms(file_path: str, lang_code: str, whitelist: set[str] | None,
              word_id_map: dict[str, int], batch_size: int = 100):
    batch = []
    done = 0
    for raw_batch in stream_jsonl(file_path, batch_size=500):
        for entry in raw_batch:
            if entry.get('lang_code') != lang_code:
                continue
            lemma = entry['word']
            word_id = word_id_map.get(lemma)
            if word_id is None:
                continue
            generated = _dwdsmor_generate(lemma, entry['pos'])
            merged = _merge(generated, entry.get('forms', []))
            for form in merged:
                batch.append({
                    'wordId':   word_id,
                    'spelling': form['spelling'],
                    'pos':      _map_pos(entry['pos']),
                    'status':   form['status'],
                    'fields':   form.get('fields', {}),
                })
                if len(batch) >= batch_size:
                    done += len(batch)
                    yield batch, done
                    batch = []
    if batch:
        done += len(batch)
        yield batch, done
```

**`parser/utils/features.py`** — маппинг тегов dwdsmor → fields для bitmask (matching TASK-0 раскладку):

```python
# Числовые значения ДОЛЖНЫ совпадать с word-form-features.ts
CASE_MAP = {'Nom': 'nom', 'Gen': 'gen', 'Dat': 'dat', 'Acc': 'acc'}
NUMBER_MAP = {'Sg': 'sg', 'Pl': 'pl'}
GENDER_MAP = {'Masc': 'm', 'Fem': 'f', 'Neut': 'n'}
TENSE_MAP = {'Pres': 'present', 'Past': 'pret', 'Perf': 'perf'}
MOOD_MAP = {'Ind': 'ind', 'Konj1': 'konj1', 'Konj2': 'konj2', 'Imp': 'imp'}
PERSON_MAP = {'1': 1, '2': 2, '3': 3}
VERB_CLASS_MAP = {'Weak': 'weak', 'Strong': 'strong', 'Mixed': 'mixed', 'Modal': 'modal'}
DECL_MAP = {'St': 'strong', 'Wk': 'weak', 'Mixed': 'mixed'}
DEGREE_MAP = {'Pos': 'pos', 'Comp': 'comp', 'Sup': 'sup'}
```

**`parser/main.py`** — добавить ветку `forms` и `_IMPLEMENTED_STEPS`.

### Критерии готовности

- `'Haus'` → ровно 8 форм, каждая с `{wordId, spelling, pos:'noun', status:'VALIDATED', fields:{case,number,gender}}`
- `'gehen'` → форма `'ging'` присутствует, `fields.verbClass == 'strong'`
- `'schön'` → ≥ 48 форм (3 степени × 3 типа склонения × 4 падежа × 2 числа)
- Формы с тегами `variant`, `obsolete` — отсутствуют в выходном батче
- `PYTHONPATH=. venv/bin/python3 -m pytest tests/test_de_forms.py -v` — зелёный

---

## TASK-4 · Интеграция forms в WiktionaryPipeline

**Репо:** back
**Блокирует:** TASK-8
**Заблокирована:** TASK-3 (parser forms), TASK-2 (IncomingWordForm тип)

**Статус фасада:** `DictionaryFacade.upsertWordForms({wordId, spelling, features})` ✅ уже реализован

### IN
- `IncomingWordForm[]` батчи от парсера (шаг `"forms"`)
- `word_id_map: Record<string, number>` — собирается из шага `"lemmas"`

### OUT
- `word_forms` таблица заполнена bitmask `features` для всех лемм
- Zod-валидация каждого батча на HTTP-границе

### Реализация

**`src/modules/dict-import/clients/parser-http.client.ts`** — добавить Zod-схему для `IncomingWordForm`:

```typescript
const IncomingWordFormSchema = z.object({
  wordId:   z.number().int().positive(),
  spelling: z.string().min(1),
  pos:      z.enum(['noun', 'verb', 'adj', 'pronoun', 'article', 'adv', 'other']),
  status:   z.enum(['VALIDATED', 'IRREGULAR', 'FAILED']),
  fields:   z.record(z.unknown()),
});
```

**`wiktionary.pipeline.ts`** — после шага `lemmas` запустить `forms`:

```typescript
// Шаг lemmas возвращает word_id_map
const wordIdMap: Record<string, number> = {};
for await (const { batch } of this.parserClient.runStep({
  step: 'lemmas', ...
})) {
  for (const entry of batch) {
    const { id, word } = await this.facade.upsertWord(entry.word, ...);
    wordIdMap[entry.word] = id;  // собираем map
  }
}

// Шаг forms использует word_id_map
const formsBatch: { wordId: number; spelling: string; features: number }[] = [];
for await (const { batch } of this.parserClient.runStep({
  step: 'forms',
  file_path: this.deDump,
  lang_code: langCode as LangCode,
  whitelist,
  word_id_map: wordIdMap,
})) {
  for (const raw of batch as IncomingWordForm[]) {
    const validated = IncomingWordFormSchema.safeParse(raw);
    if (!validated.success) {
      this.logger.warn({ raw }, 'invalid IncomingWordForm — skipped');
      continue;
    }
    const { pos, status, fields, wordId, spelling } = validated.data;
    const posKey = pos as PosKey;
    const statusKey = status as StatusKey;
    const features = encodeFeatures(posKey, statusKey, fields);
    formsBatch.push({ wordId, spelling, features });
    if (formsBatch.length >= 500) {
      await this.facade.upsertWordForms(formsBatch.splice(0));
    }
  }
}
if (formsBatch.length > 0) {
  await this.facade.upsertWordForms(formsBatch);
}
```

### Критерии готовности

- `SELECT COUNT(*) FROM word_forms WHERE word_id = :haus_id` → 8
- `SELECT (features >> 3) & 3 FROM word_forms` — нет значений 3 (corrupt bitmask)
- `decodeFeatures(features)` для формы `Hauses` → `{case:'gen', number:'sg', gender:'n'}`
- Повторный прогон: `COUNT(*)` не растёт (idempotent upsert)
- Невалидный батч от парсера → warn-лог, пропуск, прогон продолжается

---

## TASK-6 · links — DE→RU концепты

**Репо:** back + parser
**Блокирует:** TASK-8
**Заблокирована:** TASK-2 (`DeExtractEntry.translations` определён)

### IN (parser)
- `de-extract.jsonl.gz` — поле `translations[]` каждой записи

### OUT
- Parser: `run_links()` → `LinkEntry[]` батчи: `{de_lemma, ru_lemma, sense_index, gloss}`
- Back: `concepts`, `word_senses`, `sense_texts` заполнены DE↔RU связями

### Недостающие методы фасада

`DictionaryFacade` необходимо дополнить (через `WordImportRepository`):

```typescript
// Создать концепт (один на sense)
findOrCreateConcept(): Promise<{ id: number }>

// Добавить слово в словарь
addToDictionary(dictId: number, wordId: number): Promise<void>

// Upsert word_sense (ON CONFLICT DO NOTHING)
upsertWordSense(wordId: number, conceptId: number, senseIndex: number): Promise<number>
```

SQL для `upsertWordSense`:
```sql
INSERT INTO word_senses (word_id, concept_id, sense_index)
VALUES ($1, $2, $3)
ON CONFLICT (word_id, sense_index) DO NOTHING
RETURNING id
```

### Parser — `de_wiktionary.py` добавить `run_links()`

```python
def _clean_ru_lemma(raw: str) -> str | None:
    import re
    s = re.sub(r'\([^)]*\)', '', raw).strip()          # убрать скобки
    s = s.split(',')[0].strip()                         # взять первый вариант
    s = re.sub(r'\s+(высок\.|разг\.|устар\.|книжн\.|поэт\.)$', '', s).strip()
    if not re.search(r'[а-яёА-ЯЁ]', s):
        return None
    return s if len(s) >= 2 else None

def run_links(file_path: str, lang_code: str, whitelist: set[str] | None,
              batch_size: int = 500):
    done = 0
    batch = []
    for raw_batch in stream_jsonl(file_path, batch_size=500):
        for entry in raw_batch:
            if entry.get('lang_code') != lang_code:
                continue
            if whitelist is not None and entry['word'] not in whitelist:
                continue
            for i, sense in enumerate(entry.get('senses', [])):
                gloss = (sense.get('glosses') or [''])[0]
                for tr in entry.get('translations', []):
                    if tr.get('lang_code') != 'ru':
                        continue
                    sense_idx = tr.get('sense_index') or str(i + 1)
                    if sense_idx != str(i + 1):
                        continue
                    ru_lemma = _clean_ru_lemma(tr['word'])
                    if ru_lemma is None:
                        continue
                    batch.append({
                        'de_lemma':    entry['word'],
                        'ru_lemma':    ru_lemma,
                        'sense_index': i + 1,
                        'gloss':       gloss,
                    })
                    done += 1
                    if len(batch) >= batch_size:
                        yield batch, done
                        batch = []
    if batch:
        yield batch, done
```

### Back — `WiktionaryPipeline._doResolveRelations()`

```typescript
for await (const { batch } of this.parserClient.runStep({
  step: 'links',
  file_path: this.deDump,
  lang_code: opts.langCode as LangCode,
  whitelist: null,
  word_id_map: null,
})) {
  for (const link of batch as LinkEntry[]) {
    const concept = await this.facade.findOrCreateConcept();

    const deWord = await this.facade.upsertWord(link.de_lemma, deLangId, PartOfSpeech.Noun, 0);
    await this.facade.upsertWordSense(deWord.id, concept.id, link.sense_index);

    if (link.gloss) {
      await this.facade.addSenseText(/* senseId */, deLangId, SenseTextType.DEFINITION, link.gloss);
    }

    const ruWord = await this.facade.upsertWord(link.ru_lemma, ruLangId, PartOfSpeech.Noun, 0);
    await this.facade.upsertWordSense(ruWord.id, concept.id, link.sense_index);
  }
}
```

### Критерии готовности

- `SELECT COUNT(*) FROM concepts` → > 0 после прогона
- `SELECT COUNT(DISTINCT language_id) FROM words w JOIN word_senses ws ON ws.word_id = w.id WHERE ws.concept_id IN (SELECT concept_id FROM word_senses WHERE word_id = :haus_id)` → 2
- Переводы с пометками `разг.`, `устар.`, скобками — очищены перед записью
- Повторный прогон: `COUNT(*)` не изменился (idempotent)
- `PYTHONPATH=. venv/bin/python3 -m pytest tests/test_links.py -v` — зелёный

---

## TASK-9 · Coverage monitor

**Репо:** back
**Блокирует:** TASK-8
**Заблокирована:** TASK-6 (нужны данные в word_senses)

### IN
- `dictId: number` — ID словаря
- Данные в `words`, `word_senses`, `dictionary_words`

### OUT
- Новая таблица `dict_coverage_snapshots`
- Новая колонка `words.cefr_level VARCHAR(2)`
- `CoverageService` с тремя методами
- Entity `DictCoverageSnapshot`

### Схема

```sql
ALTER TABLE words ADD COLUMN cefr_level VARCHAR(2) NULL;

CREATE TABLE dict_coverage_snapshots (
  id             SERIAL      PRIMARY KEY,
  dictionary_id  INT         NOT NULL REFERENCES dictionaries(id) ON DELETE CASCADE,
  ran_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  words_total    INT NOT NULL,
  words_with_ru  INT NOT NULL,
  words_without_ru INT NOT NULL,
  coverage_pct   NUMERIC(5,2) NOT NULL,
  by_pos         JSONB NOT NULL DEFAULT '{}',
  by_level       JSONB NOT NULL DEFAULT '{}',
  gap_words      JSONB NOT NULL DEFAULT '[]'
);
CREATE INDEX ON dict_coverage_snapshots (dictionary_id, ran_at DESC);
```

### Файлы

| Действие | Файл |
|---|---|
| Создать | `src/modules/dictionary/entity/dict-coverage-snapshot.entity.ts` |
| Создать | `src/modules/dictionary/service/coverage.service.ts` |
| Изменить | `src/modules/dictionary/entity/word.entity.ts` — добавить `cefrLevel` |
| Изменить | `src/modules/dictionary/dictionary.module.ts` — зарегистрировать entity + service |
| Изменить | `src/modules/dictionary/dictionary.facade.ts` — экспортировать `CoverageService` |

### `CoverageService` — сигнатуры

```typescript
@Injectable()
export class CoverageService {
  async runSnapshot(dictId: number): Promise<DictCoverageSnapshot>
  async getLatest(dictId: number): Promise<DictCoverageSnapshot | null>
  async getHistory(dictId: number, limit: number): Promise<DictCoverageSnapshot[]>
}
```

SQL-запрос для `runSnapshot` — см. Epic §9.3 (использует `COUNT(DISTINCT w.id)`, не `COUNT(*)`).

### Критерии готовности

- `CoverageService.runSnapshot(dictId)` создаёт запись в `dict_coverage_snapshots`
- Два вызова подряд → две записи (не перезаписывает)
- `getLatest()` читает из `dict_coverage_snapshots` без JOIN к основным таблицам
- `coverage_pct` корректен: 3 из 4 слов с переводом → 75.00
- `gap_words` содержит слова без RU — не пустой массив если coverage < 100%
- `tsc --noEmit && npm run build` — без ошибок

---

## TASK-8 · TUI — оркестрация шагов

**Репо:** back
**Блокирует:** —
**Заблокирована:** TASK-3, TASK-4, TASK-5, TASK-6, TASK-7, TASK-9

### IN
- Все pipeline-шаги реализованы
- `@clack/prompts` установлен

### OUT
- `PipelineOrchestrator` — сервис оркестрации без TUI
- `src/cli.ts` — главное меню TUI с пунктами 0–5 и `-`

### Установка

```bash
npm install @clack/prompts
```

### Файлы

| Действие | Файл |
|---|---|
| Создать | `src/modules/dict-import/service/pipeline.orchestrator.ts` |
| Изменить | `src/cli.ts` — добавить TUI меню |
| Изменить | `src/modules/dict-import/dict-import.module.ts` — зарегистрировать `PipelineOrchestrator` |

### `PipelineOrchestrator`

```typescript
export enum PipelineMode {
  DE_RU_MVP  = 'DE_RU_MVP',   // pdf-seed → freq → lemmas → forms → links
  DE_RU_FULL = 'DE_RU_FULL',  // freq → lemmas → forms → links
  EN_RU_MVP  = 'EN_RU_MVP',   // не реализован — выводит "not yet implemented"
  EN_RU_FULL = 'EN_RU_FULL',  // не реализован — выводит "not yet implemented"
}

@Injectable()
export class PipelineOrchestrator {
  async run(mode: PipelineMode, dictName: string): Promise<void>
}
```

**DE_RU_MVP шаги в порядке:**
1. `pdf-seed` → получить whitelist
2. `freq` → обновить частоты (только whitelist-слова)
3. `lemmas` → импорт лемм + senses, собрать `word_id_map`
4. `forms` → импорт словоформ (передать `word_id_map`)
5. `links` → создать концепты DE↔RU
6. Coverage snapshot (автоматически, даже при ошибке в шагах)

**DE_RU_FULL:** то же, без шага `pdf-seed`, `whitelist = null`.

### TUI меню

```
1 · показать оценку связанности переводов
2 · сгенерировать  DE → RU  [MVP]
3 · сгенерировать  DE → RU  [Full]
4 · сгенерировать  EN → RU  [MVP]     ← "not yet implemented"
5 · сгенерировать  EN → RU  [Full]    ← "not yet implemented"
- · удалить данные из таблиц словаря
0 · выйти
```

### Критерии готовности

- `nest start dict-import` открывает меню без аргументов
- Пункт "2" запускает все 5 шагов в правильном порядке + Coverage
- Пункт "3" запускает 4 шага (без pdf-seed) + Coverage
- Пункты "4", "5" — выводят "not yet implemented", не падают
- После пункта "0" процесс завершается (`process.exit(0)`)
- Coverage-экран отображается даже если один из шагов упал с ошибкой
- `npm run build` — без ошибок

---

## TASK-10 · Multi-PDF seed из папки

**Репо:** parser + back
**Статус:** ❌ нужно сделать
**Заблокирована:** TASK-5 ✅
**Блокирует:** —

### Контекст

Текущий шаг `pdf-seed` читает один файл из `DATA_DE_PDF_PATH`. Теперь у нас 5 DE PDF (A1–C1):

| Файл | Формат |
|---|---|
| `A1_SD1_Wortliste_02.pdf` | Строки вида `die Sekunde, -n der Tag, -e` — двухколоночный текст, артикли встроены в строку |
| `Goethe-Zertifikat_A2_Wortliste.pdf` | Многоколоночный, записи `Direktor, -en`, `Deutschland` без артикля |
| `Goethe-Zertifikat_B1_Wortliste.pdf` | Алфавитный список: `parken, parkt, parkte,` + примеры предложений |
| `aspekte-neu-b2-lb-kapitelwortschatz.pdf` | Двухколонный: `begehrt (bei + D.) die Kleinkriminellenstudie, -n` |
| `aspekte-neu-c1-lb-kapitelwortschatz.pdf` | То же что B2 |

**Вызовы нормализации** (все форматы одновременно в одном потоке):
- Артикли `der/die/das/ein/eine` проходят текущий regex-фильтр → попадают в whitelist
- Маркеры рода/числа `m/f/n/v` (1–2 символа) → надо отфильтровать по длине
- Суффиксы склонений `, -n / -en / -e` → надо брать первый токен строки, не все
- Пометки региона `D, A, CH` → отфильтровать как аббревиатуры
- Примеры предложений в B1 → брать только первый токен до запятой
- Инфлектированные формы в B1 (`parkt, parkte`) → второй+ токен после запятой, не нужны

### IN / OUT

```
IN:  file_path = "/data/seed/de"   (директория, передаётся NestJS)
     lang_code = "de"

OUT: string[] батчи немецких лемм (NDJSON стрим, тот же формат что pdf-seed)
```

### Нормализация строки → лемма

Применяется к каждой строке текста (после `page.extract_text()`).

**Правила (приоритет сверху вниз):**

1. **Взять первый токен** от начала строки (split по пробелу, взять `tokens[0]`)
2. **Отрезать суффикс с запятой**: `Sekunde,` → `Sekunde`; `parken,` → `parken`
3. **Отрезать скобочный суффикс**: `begehrt(bei` → `begehrt`
4. **Применить German-word regex** `^[A-ZÄÖÜa-zäöüßé\-]+$`
5. **Отфильтровать стоп-слова**: артикли и функциональные слова

```python
DE_STOP = frozenset({
    'der', 'die', 'das', 'ein', 'eine', 'eines', 'einem', 'einen', 'einer',
    'des', 'dem', 'den',
    'und', 'oder', 'aber', 'nicht', 'ist', 'sind', 'war', 'haben', 'sein',
    'in', 'an', 'auf', 'bei', 'für', 'von', 'zu', 'mit', 'nach', 'aus',
    'über', 'unter', 'zwischen', 'durch', 'gegen', 'ohne', 'um',
    'sich', 'ich', 'du', 'er', 'sie', 'es', 'wir', 'ihr',
    'auch', 'noch', 'schon', 'nur', 'sehr', 'so', 'wie', 'wo', 'was',
})
_MIN_LEN = 3   # было 2 — поднять до 3 чтобы отсечь 'm', 'f', 'n', 'D', 'A'
```

6. **Длина ≥ 3** (сбрасывает `m, f, n, D, A, CH` и похожие аббревиатуры)
7. **Глобальный dedup** через `seen: set[str]` по всем файлам

### Файлы и изменения

#### Parser

**`parser/pipelines/pdf_vocab.py`** — обновить `run_pdf_seed`:

```python
import re
from pathlib import Path
from collections.abc import Generator
import pdfplumber

_MIN_LEN = 3
_DE_WORD_RE = re.compile(r'^[A-ZÄÖÜa-zäöüßé\-]+$')
_DE_STOP = frozenset({
    'der', 'die', 'das', 'ein', 'eine', 'eines', 'einem', 'einen', 'einer',
    'des', 'dem', 'den',
    'und', 'oder', 'aber', 'nicht', 'ist', 'sind', 'war', 'haben', 'sein',
    'in', 'an', 'auf', 'bei', 'für', 'von', 'zu', 'mit', 'nach', 'aus',
    'über', 'unter', 'zwischen', 'durch', 'gegen', 'ohne', 'um',
    'sich', 'ich', 'du', 'er', 'sie', 'es', 'wir', 'ihr',
    'auch', 'noch', 'schon', 'nur', 'sehr', 'so', 'wie', 'wo', 'was',
})


def _extract_lemma(line: str) -> str | None:
    """Extract first German lemma from a line of text."""
    # take first whitespace-token, strip comma/bracket suffix
    first = line.split()[0] if line.split() else ''
    first = first.split(',')[0].split('(')[0]
    first = first.strip("(),.;:!?\"'-")
    if len(first) < _MIN_LEN:
        return None
    if not _DE_WORD_RE.match(first):
        return None
    if first.lower() in _DE_STOP:
        return None
    return first


def run_pdf_seed(
    file_path: str, batch_size: int = 500
) -> Generator[tuple[list[str], int], None, None]:
    """Read a single PDF and yield batches of German lemmas."""
    seen: set[str] = set()
    batch: list[str] = []
    done = 0

    with pdfplumber.open(file_path) as pdf:
        for page in pdf.pages:
            for line in (page.extract_text() or '').splitlines():
                word = _extract_lemma(line.strip())
                if word is None or word in seen:
                    continue
                seen.add(word)
                batch.append(word)
                done += 1
                if len(batch) >= batch_size:
                    yield batch, done
                    batch = []

    if batch:
        yield batch, done


def run_pdf_seed_dir(
    dir_path: str, batch_size: int = 500
) -> Generator[tuple[list[str], int], None, None]:
    """Scan all PDFs in dir_path, yield merged deduplicated German lemma batches."""
    seen: set[str] = set()
    batch: list[str] = []
    done = 0

    pdf_files = sorted(Path(dir_path).glob('*.pdf'))
    for pdf_path in pdf_files:
        with pdfplumber.open(str(pdf_path)) as pdf:
            for page in pdf.pages:
                for line in (page.extract_text() or '').splitlines():
                    word = _extract_lemma(line.strip())
                    if word is None or word in seen:
                        continue
                    seen.add(word)
                    batch.append(word)
                    done += 1
                    if len(batch) >= batch_size:
                        yield batch, done
                        batch = []

    if batch:
        yield batch, done
```

**`parser/main.py`** — добавить новый шаг `pdf-seed-dir`:

```python
from pipelines.pdf_vocab import run_pdf_seed, run_pdf_seed_dir

# В _IMPLEMENTED_STEPS добавить 'pdf-seed-dir'
# В generate() добавить ветку:
elif req.step == 'pdf-seed-dir':
    for batch, done in run_pdf_seed_dir(req.file_path):
        yield json.dumps({'batch': batch, 'progress': {'done': done, 'total': None}}) + '\n'
```

Обновить `PipelineRunRequest.step` Literal — добавить `'pdf-seed-dir'`.

Обновить `_validate_file_path` — разрешить директории (добавить проверку `Path(path).is_dir()` как допустимый вариант, не только файл).

#### NestJS config

**`src/config/schema/env.schema.ts`:**
```typescript
// Добавить (заменяет DATA_DE_PDF_PATH):
DATA_DE_SEED_DIR: z.string().min(1).default('/data/seed/de'),
```

**`src/config/app.contract.ts` → `DataPathsConfig`:**
```typescript
deSeedDir: string;   // добавить, убрать dePdf
```

**`src/config/namespaces/data-paths.config.ts`:**
```typescript
deSeedDir: env.DATA_DE_SEED_DIR,  // добавить, убрать dePdf
```

**`.env`:**
```
# Заменить DATA_DE_PDF_PATH=/data/... на:
DATA_DE_SEED_DIR=/data/seed/de
```

#### NestJS orchestrator

**`src/modules/dict-import/service/pipeline.orchestrator.ts`:**

```typescript
private async _getPdfWhitelist(onProgress?: ProgressCallback): Promise<string[]> {
  const words: string[] = [];
  for await (const { batch, progress } of this.parserClient.runStep({
    step: 'pdf-seed-dir',           // было: 'pdf-seed'
    file_path: this.deSeedDir,      // было: this.dePdf
    lang_code: 'de' as LangCode,
    whitelist: null,
    word_id_map: null,
  })) {
    for (const word of batch) {
      words.push(word);
    }
    onProgress?.('pdf-seed', progress.done, {});
  }
  this.logger.info({ count: words.length }, 'pdf-seed whitelist loaded');
  return words;
}
```

Обновить `this.dePdf` → `this.deSeedDir` в конструкторе.

#### NestJS dto

**`src/modules/dict-import/dto/pipeline.dto.ts`:**

```typescript
// Добавить в PipelineStep:
export type PipelineStep = 'pdf-seed' | 'pdf-seed-dir' | 'freq' | 'lemmas' | 'forms' | 'links';
```

### Порядок реализации

```
1. parser/pipelines/pdf_vocab.py — _extract_lemma + run_pdf_seed_dir
2. parser/main.py — ветка 'pdf-seed-dir' + обновить Literal
3. src/config/schema/env.schema.ts — DATA_DE_SEED_DIR
4. src/config/app.contract.ts — deSeedDir
5. src/config/namespaces/data-paths.config.ts — deSeedDir
6. src/modules/dict-import/dto/pipeline.dto.ts — добавить 'pdf-seed-dir'
7. src/modules/dict-import/service/pipeline.orchestrator.ts — _getPdfWhitelist
8. .env — DATA_DE_SEED_DIR=/data/seed/de
9. npx tsc --noEmit
```

### Критерии готовности

- `POST /pipeline/run {step:"pdf-seed-dir", file_path:"/data/seed/de"}` → NDJSON `string[]` батчи
- Итоговый список содержит ≥ 3 000 уникальных немецких лемм (A1–C1 все уровни)
- Нет артиклей: `der`, `die`, `das`, `ein` — отсутствуют в результате
- Нет 1–2 символьных токенов (`m`, `f`, `n`, `D`, `A`)
- Дубли между файлами исключены (слово из A1 и B1 попадает ровно один раз)
- `tsc --noEmit` — без ошибок
- DE_RU MVP pipeline прогоняется до конца без ошибок с новым whitelist

---

## TASK-11 · Pipeline v2 — уровни CEFR, мульти-источник переводов, качество форм

**Репо:** parser + back
**Статус:** ❌ нужно сделать
**Заблокирована:** TASK-10 ✅
**Блокирует:** —

### Контекст и мотивация

Текущий пайплайн (v1) имеет три проблемы:

1. **Флективные формы в whitelist** — PDF extraction вытаскивает `wurde`, `Jahren`, `ersten` из примеров предложений. Они попадают в словарь как отдельные записи без RU переводов → Coverage 37%.
2. **Нет уровня CEFR** — `words.cefr_level` есть в схеме, но не заполняется. Слова из A1 и C1 не различаются.
3. **Единственный источник переводов** — только de-extract (DE Wiktionary). Если перевода нет → слово без RU.

**Решение (v2):**

```
PDF (по уровням A1–C1)
  → dwdsmor: оставить только base-form слова     ← убирает флективные формы
  → levelMap: {слово → минимальный_уровень}

levelMap.keys()
  → freq step: Wikipedia частота
  → lemmas step: де-экстракт headword lookup + записать cefr_level

whitelist
  → translations step (мульти-источник):
      1. de-extract: translations[].lang_code == 'ru'        (primary)
      2. ru-extract: обратный поиск translations[].lang_code == 'de'  (secondary)
      верификация: если оба источника дали одно слово → verified=true
  → forms step: dwdsmor + de-extract cross-check → quality column
```

### Данные и источники

| Файл | Содержимое | Роль |
|---|---|---|
| `backend/data/seed/de/*.pdf` | A1–C1 vocabulary PDFs | PDF seed |
| `backend/data/deu_wikipedia_2021_1M/deu_wikipedia_2021_1M-words.txt` | Все токены немецкой Вики, 1M | Частота |
| `backend/data/de-extract.jsonl.gz` | DE Wiktionary: 993k DE headword'ов, 29k с RU | Леммы + переводы (primary) |
| `backend/data/ru-extract.jsonl.gz` | RU Wiktionary: 29k RU слов с DE переводами | Переводы (reverse, secondary) |
| `raw-wiktextract-data.jsonl.gz` | EN Wiktionary: только EN headword'ы | ❌ не используется |

### Шаги пайплайна v2

#### Шаг 1 · `pdf-seed-levels` (parser, новый)

```
IN:  file_path — директория /data/seed/de
OUT: [{word: str, level: "A1"|"A2"|"B1"|"B2"|"C1"}]  батчи
```

**Логика:**
- Сканировать PDF файлы в директории
- Определить уровень из имени файла по regex `A1|A2|B1|B2|C1` (case-insensitive)
- Для каждого слова-кандидата: вызвать dwdsmor.analyze(word)
  - Если lemma из анализа == word → это base form, включить
  - Если lemma != word → флективная форма, пропустить
- Глобальный dedup: если слово уже встречалось → оставить с меньшим уровнем
- Уровни в порядке приоритета: A1 < A2 < B1 < B2 < C1

**Маппинг PDF → уровень:**

| Паттерн в имени файла | Уровень |
|---|---|
| `A1` | A1 |
| `A2` | A2 |
| `B1` | B1 |
| `B2` | B2 |
| `C1` | C1 |

#### Шаг 2 · `freq` (без изменений)

Используется `deu_wikipedia_2021_1M-words.txt`. Формат и логика не меняются.

#### Шаг 3 · `lemmas` (изменение в NestJS)

```
IN:  file_path — de-extract.jsonl.gz, whitelist: string[]
OUT: [{word, pos, senses: [{sense_index, gloss}]}]  (не меняется)
```

NestJS при обработке батча: при `upsertWord(...)` передавать `cefr_level = levelMap[entry.word]`.

#### Шаг 4 · `translations` (parser, новый — заменяет `links`)

```
IN:
  file_path       — /data/de-extract.jsonl.gz   (primary)
  aux_files.ru    — /data/ru-extract.jsonl.gz   (secondary)
  whitelist       — string[]
  lang_code       — "de"

OUT батч:
  [{
    de_lemma:    string,
    sense_index: number,
    gloss:       string | null,
    ru_word:     string,
    verified:    boolean   // true если оба источника совпали
  }]
```

**Логика верификации:**
```
de_trans  = de_index[de_lemma]            # из de-extract
ru_trans  = ru_reverse_index[de_lemma]    # из ru-extract (reverse)

for each ru_word in de_trans:
    verified = ru_word in ru_trans
    yield {de_lemma, sense_index, ru_word, verified}

# Дополнительно: RU слова только из ru-extract (без de-extract)
for each ru_word in ru_trans - de_trans:
    yield {de_lemma, sense_index=0, ru_word, verified=False}
```

**Построение индексов** (в памяти при старте шага):
- `de_index`: читаем de-extract, фильтруем `lang='Deutsch' AND word in whitelist` → `{word: [{sense_index, ru_words[], gloss}]}`
- `ru_reverse_index`: читаем ru-extract, для каждой записи `lang_code='ru'` смотрим `translations[].lang_code='de'` → `{de_word: [ru_headword]}`

#### Шаг 5 · `forms` (изменение в parser)

```
OUT батч — добавляется поле quality:
  [{
    wordId:   int,
    spelling: str,
    pos:      str,
    status:   "VALIDATED"|"IRREGULAR"|"FAILED",
    fields:   dict,
    quality:  "matches"|"dictionary"|"generated"   ← NEW
  }]
```

**Логика качества:**
- `matches`   — dwdsmor сгенерировал форму И она есть в de-extract `forms[]`
- `dictionary` — форма есть в de-extract но dwdsmor её не генерирует / не совпадает
- `generated`  — dwdsmor сгенерировал, но в de-extract нет (или слова нет в de-extract)

### Изменения схемы БД

#### Новая колонка `word_forms.quality`

```sql
ALTER TABLE word_forms
  ADD COLUMN quality VARCHAR(12) NOT NULL DEFAULT 'generated';

-- valid values: 'matches', 'dictionary', 'generated'
CREATE INDEX idx_word_forms_quality ON word_forms (quality);
```

**Миграция**: добавить файл `src/database/migrations/XXXX_add_word_form_quality.ts`

### IN/OUT типы (TypeScript)

```typescript
// pipeline.dto.ts
export type PipelineStep =
  | "pdf-seed-levels"   // новый, заменяет pdf-seed-dir
  | "freq"
  | "lemmas"
  | "translations"      // новый, заменяет links
  | "forms"
  | "links"             // оставить для обратной совместимости на время перехода

export interface PdfSeedLevelEntry {
  word: string;
  level: "A1" | "A2" | "B1" | "B2" | "C1";
}

export interface TranslationEntry {
  de_lemma: string;
  sense_index: number;
  gloss: string | null;
  ru_word: string;
  verified: boolean;
}

export interface IncomingWordForm {
  wordId:   number;
  spelling: string;
  pos:      "noun" | "verb" | "adj" | "pronoun" | "article" | "adv" | "other";
  status:   "VALIDATED" | "IRREGULAR" | "FAILED";
  fields:   Record<string, unknown>;
  quality:  "matches" | "dictionary" | "generated";  // NEW
}

// StepBatchMap
export interface StepBatchMap {
  "pdf-seed-levels": PdfSeedLevelEntry;
  "freq":            FreqEntry;           // без изменений
  "lemmas":          LemmaEntry;          // без изменений
  "translations":    TranslationEntry;    // новый
  "forms":           IncomingWordForm;    // расширен quality
}
```

### Изменения в NestJS (pipeline.orchestrator.ts)

```typescript
// Шаг 1: собрать levelMap
const levelMap: Record<string, CefrLevel> = {};
for await (const { batch } of parserClient.runStep({ step: "pdf-seed-levels", ... })) {
  for (const { word, level } of batch) {
    if (!levelMap[word] || CEFR_ORDER[level] < CEFR_ORDER[levelMap[word]]) {
      levelMap[word] = level;
    }
  }
}
const whitelist = Object.keys(levelMap);

// Шаг 3: lemmas — при upsert передавать level
await facade.upsertWord(entry.word, lang.id, pos, 0, levelMap[entry.word]);

// Шаг 4: translations вместо links
for await (const { batch } of parserClient.runStep({ step: "translations", aux_files: { ru: ruExtractPath }, whitelist })) {
  for (const link of batch) {
    // та же логика что links, но с дополнительным полем verified
  }
}

// Шаг 5: forms — принимать quality из батча
// word_form entity: добавить поле quality
```

### Изменения в parser (Python)

```
Изменить:
  parser/pipelines/pdf_vocab.py     — run_pdf_seed_levels() заменяет run_pdf_seed_dir()
  parser/pipelines/de_wiktionary.py — run_translations() заменяет run_links()
  parser/pipelines/de_forms.py      — добавить quality в output
  parser/main.py                    — новые ветки "pdf-seed-levels", "translations" в generate()
                                      PipelineRunRequest: добавить aux_files: dict[str,str] | None

Не менять:
  parser/pipelines/de_wiktionary.py — run_lemmas(), run_freq()
  parser/pipelines/de_forms.py      — базовая логика dwdsmor
```

### Изменения в backend (TypeScript)

```
Изменить:
  src/modules/dict-import/dto/pipeline.dto.ts          — новые типы (см. выше)
  src/modules/dict-import/clients/parser-http.client.ts — StepBatchMap расширен
  src/modules/dict-import/pipeline/wiktionary.pipeline.ts — _doRun + _doResolveRelations переписать
  src/modules/dict-import/service/pipeline.orchestrator.ts — новая последовательность шагов
  src/modules/dictionary/entity/word-form.entity.ts    — добавить quality: WordFormQuality
  src/modules/dictionary/entity/word.entity.ts         — убедиться что cefr_level заполняется
  src/database/migrations/                             — новая миграция quality column
  backend/.env                                         — DATA_RU_EXTRACT_PATH=/data/ru-extract.jsonl.gz
  src/config/schema/env.schema.ts                      — DATA_RU_EXTRACT_PATH
  src/config/app.contract.ts                           — ruExtract: string
  src/config/namespaces/data-paths.config.ts           — ruExtract

Не менять:
  src/modules/dictionary/repository/word-import.repository.ts  — логика upsert не меняется
  src/modules/dictionary/service/coverage.service.ts           — без изменений
```

### Порядок реализации

```
1. DB migration: word_forms.quality column
2. WordForm entity: добавить quality поле
3. parser: run_pdf_seed_levels() + dwdsmor base-form check
4. parser: run_translations() + reverse ru-extract index
5. parser: forms quality в output
6. parser: main.py — новые ветки + aux_files в PipelineRunRequest
7. NestJS: DTO типы (PdfSeedLevelEntry, TranslationEntry, IncomingWordForm.quality)
8. NestJS: ParserHttpClient — обновить схемы
9. NestJS: upsertWord — принимать cefr_level
10. NestJS: pipeline orchestrator — новый порядок шагов
11. NestJS: wiktionary.pipeline.ts — заменить links на translations
12. NestJS config: DATA_RU_EXTRACT_PATH
13. tsc --noEmit
14. Сброс БД + прогон полного пайплайна
```

### Критерии готовности

- `pdf-seed-levels` не возвращает флективные формы (`wurde`, `Jahren` отсутствуют)
- `words.cefr_level` заполнен для всех слов из whitelist (A1–C1)
- `word_forms.quality` заполнен: ненулевой процент `matches` и `dictionary`
- Coverage ≥ 55% (рост с 37% за счёт ru-extract secondary + чистки флективных форм)
- `verified=true` у переводов подтверждённых обоими источниками
- `tsc --noEmit` — без ошибок
- Сброс БД + полный прогон DE_RU_MVP без ошибок
- `SELECT COUNT(DISTINCT part_of_speech) FROM words WHERE language_id = 1` → > 1 (не только noun)

---

## TASK-12 · Word properties + полные формы глаголов

### Проблема

| POS | Что генерируется сейчас | Что теряется |
|---|---|---|
| Noun | 8 форм dwdsmor ✅ | — |
| Adj | 144 атрибутивных форм dwdsmor ✅ | Предикативные формы (`groß`, `größer`) |
| **Verb** | Только dump de-extract ⚠️ | Полная парадигма (Konj. I/II, Imperativ, все лица) |
| Все POS | — | `gender`, `auxiliaryVerb`, `isSeparable`, `verbClass` на уровне слова |

---

### Шаг 1 · `word.entity.ts` — новые колонки

Файл: `src/modules/dictionary/entity/word.entity.ts`

Добавить после `cefrLevel`:

```typescript
@Column({ type: "varchar", length: 1, nullable: true, default: null })
gender: "m" | "f" | "n" | null;

@Column({ type: "varchar", length: 20, nullable: true, default: null })
auxiliaryVerb: string | null;

@Column({ type: "boolean", nullable: true, default: null })
isSeparable: boolean | null;

@Column({ type: "varchar", length: 10, nullable: true, default: null })
verbClass: string | null;
```

TypeORM sync добавит колонки автоматически при следующем рестарте API.  
**После изменения сбросить БД:** `yarn cli reset-dictionary`

---

### Шаг 2 · `de_wiktionary.py` — извлечение word props

Файл: `parser/pipelines/de_wiktionary.py`

**2.1** Перенести `_verbclass_from_categories` из `de_forms.py` в `utils/features.py` (чтобы импортировать из обоих мест).

В `utils/features.py` добавить:

```python
def verbclass_from_categories(categories: list[str]) -> str:
    cats = " ".join(categories).lower()
    if "stark" in cats or "strong" in cats:
        return "strong"
    if "modal" in cats:
        return "modal"
    if "gemischt" in cats or "mixed" in cats:
        return "mixed"
    return "weak"
```

В `de_forms.py` заменить определение `_verbclass_from_categories` на импорт:

```python
from utils.features import verbclass_from_categories as _verbclass_from_categories
```

**2.2** Добавить в `de_wiktionary.py` функцию:

```python
from utils.features import verbclass_from_categories

_GENDER_FROM_ARGS = {"m": "m", "f": "f", "n": "n", "mf": None, "fm": None}

def _extract_word_props(entry: dict) -> dict:
    cats = " ".join(c.lower() for c in entry.get("categories", []))
    pos  = entry.get("pos", "")
    props: dict = {}

    # gender — из head_templates args, fallback из categories
    ht_args = (entry.get("head_templates") or [{}])[0].get("args", {})
    raw_g = ht_args.get("1") or ht_args.get("g")
    if raw_g and raw_g in _GENDER_FROM_ARGS:
        g = _GENDER_FROM_ARGS[raw_g]
        if g:
            props["gender"] = g
    if "gender" not in props:
        if "maskulinum" in cats or "masculinum" in cats:
            props["gender"] = "m"
        elif "femininum" in cats:
            props["gender"] = "f"
        elif "neutrum" in cats:
            props["gender"] = "n"

    # auxiliary verb — из head_templates args или categories
    aux = ht_args.get("aux") or ht_args.get("hilfsverb")
    if aux:
        props["auxiliaryVerb"] = aux.strip()
    elif "hilfsverb-haben" in cats and "hilfsverb-sein" in cats:
        props["auxiliaryVerb"] = "haben,sein"
    elif "hilfsverb-haben" in cats:
        props["auxiliaryVerb"] = "haben"
    elif "hilfsverb-sein" in cats:
        props["auxiliaryVerb"] = "sein"

    # separable
    trennbar = ht_args.get("trennbar")
    if trennbar == "1" or "trennbares verb" in cats or "trennbar" in cats:
        props["isSeparable"] = True

    # verb class
    if pos == "verb":
        props["verbClass"] = verbclass_from_categories(entry.get("categories", []))

    return props
```

**2.3** Изменить `run_lemmas` — добавлять word props к каждому элементу batch:

```python
def run_lemmas(
    file_path: str,
    lang_code: str,
    whitelist: set[str] | None,
    batch_size: int = 500,
) -> Generator[tuple[list, int], None, None]:
    done = 0
    for raw_batch in stream_jsonl(file_path, batch_size):
        out = []
        for e in raw_batch:
            if e.get("lang_code") != lang_code:
                continue
            if whitelist is not None and e["word"] not in whitelist:
                continue
            props = _extract_word_props(e)
            out.append({**e, **props})  # props поля перекрывают ничего важного
        done += len(raw_batch)
        if out:
            yield out, done
```

---

### Шаг 3 · `pipeline.dto.ts` — расширить `DeExtractEntry`

Файл: `src/modules/dict-import/dto/pipeline.dto.ts`

Добавить поля в `DeExtractEntry`:

```typescript
export interface DeExtractEntry {
  word: string;
  lang: string;
  lang_code: string;
  pos: string;
  tags?: string[];
  forms?: { form: string; tags?: string[] }[];
  senses?: { ... }[];
  translations?: DeExtractTranslation[];
  categories?: string[];
  // NEW — word properties (добавлены Python-стороной)
  gender?: "m" | "f" | "n" | null;
  auxiliaryVerb?: string | null;
  isSeparable?: boolean | null;
  verbClass?: string | null;
}
```

---

### Шаг 4 · `word-import.repository.ts` — добавить `upsertWordProps`

Файл: `src/modules/dictionary/repository/word-import.repository.ts`

Добавить метод:

```typescript
async upsertWordProps(
  wordId: number,
  props: {
    gender?: "m" | "f" | "n" | null;
    auxiliaryVerb?: string | null;
    isSeparable?: boolean | null;
    verbClass?: string | null;
  },
): Promise<void> {
  if (!props.gender && !props.auxiliaryVerb && props.isSeparable == null && !props.verbClass) return;
  await this.wordRepo.manager.query(
    `UPDATE words
     SET gender         = COALESCE($2, gender),
         auxiliary_verb = COALESCE($3, auxiliary_verb),
         is_separable   = COALESCE($4, is_separable),
         verb_class     = COALESCE($5, verb_class)
     WHERE id = $1`,
    [wordId, props.gender ?? null, props.auxiliaryVerb ?? null, props.isSeparable ?? null, props.verbClass ?? null],
  );
}
```

`COALESCE` гарантирует: не перезаписывать уже заполненное поле `null`-ом.

---

### Шаг 5 · `dictionary.facade.ts` — делегат

Файл: `src/modules/dictionary/dictionary.facade.ts`

Добавить метод (аналогично `upsertWordCefrLevel`):

```typescript
upsertWordProps(
  wordId: number,
  props: Parameters<WordImportRepository["upsertWordProps"]>[1],
): Promise<void> {
  return this.wordImportRepo.upsertWordProps(wordId, props);
}
```

---

### Шаг 6 · `wiktionary.pipeline.ts` — вызов в lemmas-шаге

Файл: `src/modules/dict-import/pipeline/wiktionary.pipeline.ts`

В методе `_doRun`, внутри `for (const entry of batch)`, после `upsertWordCefrLevel`:

```typescript
const { id: wordId } = await this.facade.upsertWord(...);
wordIdMap[entry.word] = wordId;

if (levelMap?.[entry.word]) {
  await this.facade.upsertWordCefrLevel(wordId, levelMap[entry.word]);
}

// NEW
const hasProps = entry.gender || entry.auxiliaryVerb || entry.isSeparable != null || entry.verbClass;
if (hasProps) {
  await this.facade.upsertWordProps(wordId, {
    gender: entry.gender,
    auxiliaryVerb: entry.auxiliaryVerb,
    isSeparable: entry.isSeparable,
    verbClass: entry.verbClass,
  });
}
```

---

### Шаг 7 · `de_forms.py` — `_generate_verb_forms`

Файл: `parser/pipelines/de_forms.py`

Добавить импорт из utils:

```python
from utils.features import TENSE_MAP, MOOD_MAP, NUMBER_MAP, PERSON_MAP
```

Добавить константы и функцию:

```python
_VERB_CONJ_SPECS = [
    # (dwdsmor_tense, dwdsmor_mood, tense_key, mood_key)
    ("Pres", "Ind",  "present", "ind"),
    ("Pres", "Konj", "present", "konj1"),
    ("Past", "Ind",  "pret",    "ind"),
    ("Past", "Konj", "pret",    "konj2"),
]
_VERB_PERSONS = [
    ("1", "Sg"), ("2", "Sg"), ("3", "Sg"),
    ("1", "Pl"), ("2", "Pl"), ("3", "Pl"),
]


def _generate_verb_forms(analysis: str, word_id: int, verbclass: str) -> list[dict]:
    gen = _get_gen()
    results = []

    for dw_tense, dw_mood, tense_key, mood_key in _VERB_CONJ_SPECS:
        for person_str, number_str in _VERB_PERSONS:
            spec = f"{analysis}<V><{dw_tense}><{dw_mood}><{person_str}><{number_str}>"
            for spelling in generate_words(gen, spec):
                results.append({
                    "wordId": word_id,
                    "spelling": spelling,
                    "pos": "verb",
                    "status": "VALIDATED",
                    "quality": "generated",
                    "fields": {
                        "tense": tense_key,
                        "mood": mood_key,
                        "person": int(person_str),
                        "number": NUMBER_MAP[number_str],
                        "verbClass": verbclass,
                    },
                })

    # Partizip II: тег <PPast>, person/number не применимы → person=0 number=sg
    for spelling in generate_words(gen, f"{analysis}<V><PPast>"):
        results.append({
            "wordId": word_id,
            "spelling": spelling,
            "pos": "verb",
            "status": "VALIDATED",
            "quality": "generated",
            "fields": {"tense": "perf", "mood": "ind", "person": 0, "number": "sg", "verbClass": verbclass},
        })

    # Imperativ: du (2Sg) и ihr (2Pl)
    for number_str in ["Sg", "Pl"]:
        spec = f"{analysis}<V><Imp><2><{number_str}>"
        for spelling in generate_words(gen, spec):
            results.append({
                "wordId": word_id,
                "spelling": spelling,
                "pos": "verb",
                "status": "VALIDATED",
                "quality": "generated",
                "fields": {"tense": "present", "mood": "imp", "person": 2,
                           "number": NUMBER_MAP[number_str], "verbClass": verbclass},
            })

    return results
```

**Обновить ветку `dwdsmor_pos == "V"` в `run_forms`:**

```python
elif dwdsmor_pos == "V" and t:
    verbclass = _verbclass_from_categories(categories)
    forms_out = _generate_verb_forms(t.analysis, word_id, verbclass)
    # cross-check против dump: upgrade качества до "matches"
    dict_spellings = {
        (df.get("form") or "").strip()
        for df in entry.get("forms", [])
        if not any(tag in _FILTER_TAGS for tag in df.get("tags", []))
    }
    for f in forms_out:
        if f["spelling"] in dict_spellings:
            f["quality"] = "matches"
    # dump-extras (неправильные формы которых нет у dwdsmor)
    dwdsmor_spellings = {f["spelling"] for f in forms_out}
    for df in entry.get("forms", []):
        tags = df.get("tags", [])
        if any(tag in _FILTER_TAGS for tag in tags):
            continue
        spelling = (df.get("form") or "").strip()
        if not spelling or spelling in dwdsmor_spellings:
            continue
        fields = fields_from_dump_tags(tags, "verb")
        fields["verbClass"] = verbclass
        forms_out.append({
            "wordId": word_id, "spelling": spelling, "pos": "verb",
            "status": "IRREGULAR", "quality": "dictionary", "fields": fields,
        })
```

Фалбек для глаголов без dwdsmor-анализа:

```python
elif dwdsmor_pos == "V" and not t:
    verbclass = _verbclass_from_categories(categories)
    forms_out = _dump_forms(entry, word_id, "verb", verbclass)
```

---

### Шаг 8 · `de_forms.py` — `_generate_adj_pred_forms`

Добавить функцию:

```python
def _generate_adj_pred_forms(analysis: str, word_id: int) -> list[dict]:
    gen = _get_gen()
    results = []
    for degree in ["Pos", "Comp", "Sup"]:
        spec = f"{analysis}<ADJ><{degree}><Pred>"
        for spelling in generate_words(gen, spec):
            results.append({
                "wordId": word_id,
                "spelling": spelling,
                "pos": "adj",
                "status": "VALIDATED",
                "quality": "generated",
                "fields": {"degree": DEGREE_MAP[degree]},
                # нет case/number/gender → bitmask заполнит нулями (nom/sg/m/strong) — допустимо для pred
            })
    return results
```

Обновить ветку ADJ в `run_forms` — дополнить атрибутивные формы предикативными:

```python
elif dwdsmor_pos == "ADJ" and t:
    forms_out = _generate_adj_forms(t.analysis, word_id)
    forms_out += _generate_adj_pred_forms(t.analysis, word_id)
```

---

### Порядок коммитов

```
[LexBuild TASK-12] feat(parser): move verbclass_from_categories to utils/features
[LexBuild TASK-12] feat(parser): extract word props in run_lemmas
[LexBuild TASK-12] feat(backend): add gender/auxiliaryVerb/isSeparable/verbClass to Word entity
[LexBuild TASK-12] feat(backend): upsertWordProps repository + facade + pipeline
[LexBuild TASK-12] feat(parser): generate verb forms via dwdsmor with dump cross-check
[LexBuild TASK-12] feat(parser): add predicative adjective forms
```

---

### Критерии готовности

```sql
-- gender заполнен ≥ 90% существительных
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE gender IS NOT NULL) / COUNT(*), 1)
FROM words WHERE part_of_speech = 'noun';

-- auxiliary_verb заполнен ≥ 75% глаголов
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE auxiliary_verb IS NOT NULL) / COUNT(*), 1)
FROM words WHERE part_of_speech = 'verb';

-- среднее кол-во форм на глагол ≥ 15
SELECT ROUND(AVG(cnt), 1)
FROM (SELECT COUNT(*) AS cnt FROM word_forms wf
      JOIN words w ON w.id = wf.word_id
      WHERE w.part_of_speech = 'verb' GROUP BY wf.word_id) t;

-- предикативные adj формы присутствуют
SELECT COUNT(*) FROM word_forms wf
JOIN words w ON w.id = wf.word_id
WHERE w.part_of_speech = 'adj'
  AND (wf.features >> 12 & 3) IN (0,1,2)   -- degree = pos/comp/sup
  AND (wf.features >> 5 & 3) = 0            -- case bits = 0 (nom, используется для pred)
  AND (wf.features >> 7 & 1) = 0            -- number bits = 0
  AND (wf.features >> 8 & 3) = 0;           -- gender bits = 0
```

- `tsc --noEmit` без ошибок
- Полный прогон `pipeline:run --mode DE_RU_MVP --dict de-topics-mvp` без ошибок
