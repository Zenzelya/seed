**Модуль: Wiktionary Parser**

**Назначение:** Изолированный сервис для автоматического сбора лингвистических данных (лемма, морфология, формы, переводы) из Wiktionary.

**Алгоритм работы:**

1. **Входные данные:** Получает лемму (слово), исходный язык (например, `de`), целевой язык перевода (например, `ru`) и опциональный `homonym_index` (по умолчанию `0`) — индекс блока на странице при омонимии.
2. **Генерация ресурса:** Динамически формирует URL-адрес страницы на основе языкового кода (например, `https://de.wiktionary.org/wiki/fahren`).
3. **Парсинг и экстракция:** Выполняет асинхронный HTTP-запрос, загружает DOM-дерево страницы и извлекает данные с помощью CSS-селекторов.
4. **Типизация ответа:** Определяет часть речи (`part_of_speech`). Если данные отсутствуют, записывает значение `no data`.

```
parser/
└── modules/
    └── wiktionary/
        ├── __init__.py
        ├── parser.py
        ├── schemas.py
        ├── service.py
        └── router.py
```

---

**Омонимы (Homonyme):** Если на странице несколько лексических блоков (например, `fest` — прилагательное и `Fest` — существительное), парсер выбирает блок по индексу `homonym_index` (по умолчанию `0`).

---

**Форматы выходных данных (JSON):**

---

### Verb — fahren

```json
{
  "static": {
    "lemma": "fahren",
    "language": "de",
    "part_of_speech": "Verb"
  },
  "dynamic": {
    "verb_type": "stark",
    "regularity": "unregelmäßig",
    "is_separable": false,
    "prefix": null,
    "auxiliary_verb": "haben, sein",
    "ipa": "/ˈfaːʁən/",
    "translations": {
      "ru": [
        { "text": "ехать", "link": "https://ru.wiktionary.org/wiki/ехать" }
      ]
    },
    "examples": [
      { "de": "Er fährt jeden Tag mit dem Bus.", "ru": "Он ездит каждый день на автобусе." }
    ],
    "imperative_forms": {
      "du":  { "form": "fahr",       "html": "<span><span class=\"root\">fahr</span></span>" },
      "ihr": { "form": "fahrt",      "html": "<span><span class=\"root\">fahr</span><span class=\"termination\">t</span></span>" },
      "wir": { "form": "fahren wir", "html": "<span><span class=\"root\">fahr</span><span class=\"termination\">en</span> wir</span>" },
      "Sie": { "form": "fahren Sie", "html": "<span><span class=\"root\">fahr</span><span class=\"termination\">en</span> Sie</span>" }
    },
    "konjunktiv_ii_forms": {
      "ich":       { "form": "führe",   "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ü</span>hr</span><span class=\"termination\">e</span></span>" },
      "du":        { "form": "führest", "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ü</span>hr</span><span class=\"termination\">est</span></span>" },
      "er/sie/es": { "form": "führe",   "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ü</span>hr</span><span class=\"termination\">e</span></span>" },
      "wir":       { "form": "führen",  "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ü</span>hr</span><span class=\"termination\">en</span></span>" },
      "ihr":       { "form": "führet",  "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ü</span>hr</span><span class=\"termination\">et</span></span>" },
      "Sie/sie":   { "form": "führen",  "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ü</span>hr</span><span class=\"termination\">en</span></span>" }
    },
    "flexion": [
      {
        "pronoun": "ich",
        "full_form": "fahre",
        "prefix": null,
        "infix": null,
        "root": "fahr",
        "termination": "e",
        "tense": "Präsens",
        "root_changed": false,
        "html": "<span><span class=\"root\">fahr</span><span class=\"termination\">e</span></span>"
      },
      {
        "pronoun": "du",
        "full_form": "fährst",
        "prefix": null,
        "infix": null,
        "root": "fähr",
        "termination": "st",
        "tense": "Präsens",
        "root_changed": true,
        "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ä</span>hr</span><span class=\"termination\">st</span></span>"
      },
      {
        "pronoun": "er/sie/es",
        "full_form": "fährt",
        "prefix": null,
        "infix": null,
        "root": "fähr",
        "termination": "t",
        "tense": "Präsens",
        "root_changed": true,
        "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ä</span>hr</span><span class=\"termination\">t</span></span>"
      },
      {
        "pronoun": "ich",
        "full_form": "fuhr",
        "root": "fuhr",
        "termination": "",
        "tense": "Präteritum",
        "root_changed": true,
        "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">u</span>hr</span></span>"
      },
      {
        "pronoun": "er/sie/es",
        "full_form": "fuhr",
        "root": "fuhr",
        "termination": "",
        "tense": "Präteritum",
        "root_changed": true,
        "is_principal_part": true,
        "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">u</span>hr</span></span>"
      },
      {
        "form": "gefahren",
        "full_form": "gefahren",
        "prefix": null,
        "infix": "ge",
        "root": "fahr",
        "termination": "en",
        "tense": "Partizip II",
        "root_changed": false,
        "auxiliary_verb": "haben, sein",
        "html": "<span><span class=\"infix\">ge</span><span class=\"root\">fahr</span><span class=\"termination\">en</span></span>"
      }
    ],
    "url": "https://de.wiktionary.org/wiki/fahren"
  }
}
```

---

### Verb — haben

```json
{
  "static": {
    "lemma": "haben",
    "language": "de",
    "part_of_speech": "Verb"
  },
  "dynamic": {
    "verb_type": "unregelmäßig",
    "regularity": "unregelmäßig",
    "auxiliary_verb": "haben",
    "ipa": "/ˈhaːbən/",
    "translations": {
      "ru": [
        { "text": "иметь",    "link": "https://ru.wiktionary.org/wiki/иметь" },
        { "text": "обладать", "link": "https://ru.wiktionary.org/wiki/обладать" }
      ]
    },
    "examples": [
      { "de": "Ich habe keine Zeit.", "ru": "У меня нет времени." }
    ],
    "imperative_forms": {
      "du":  { "form": "hab",      "html": "<span><span class=\"root\">hab</span></span>" },
      "ihr": { "form": "habt",     "html": "<span><span class=\"root\">hab</span><span class=\"termination\">t</span></span>" },
      "wir": { "form": "haben wir","html": "<span><span class=\"root\">hab</span><span class=\"termination\">en</span> wir</span>" },
      "Sie": { "form": "haben Sie","html": "<span><span class=\"root\">hab</span><span class=\"termination\">en</span> Sie</span>" }
    },
    "konjunktiv_ii_forms": {
      "ich":       { "form": "hätte",   "html": "<span><span class=\"root\">h<span class=\"vowel-changed\">ä</span>tt</span><span class=\"termination\">e</span></span>" },
      "du":        { "form": "hättest", "html": "<span><span class=\"root\">h<span class=\"vowel-changed\">ä</span>tt</span><span class=\"termination\">est</span></span>" },
      "er/sie/es": { "form": "hätte",   "html": "<span><span class=\"root\">h<span class=\"vowel-changed\">ä</span>tt</span><span class=\"termination\">e</span></span>" },
      "wir":       { "form": "hätten",  "html": "<span><span class=\"root\">h<span class=\"vowel-changed\">ä</span>tt</span><span class=\"termination\">en</span></span>" },
      "ihr":       { "form": "hättet",  "html": "<span><span class=\"root\">h<span class=\"vowel-changed\">ä</span>tt</span><span class=\"termination\">et</span></span>" },
      "Sie/sie":   { "form": "hätten",  "html": "<span><span class=\"root\">h<span class=\"vowel-changed\">ä</span>tt</span><span class=\"termination\">en</span></span>" }
    },
    "flexion": [
      {
        "pronoun": "ich",
        "full_form": "habe",
        "root": "hab",
        "termination": "e",
        "tense": "Präsens",
        "root_changed": false,
        "html": "<span><span class=\"root\">hab</span><span class=\"termination\">e</span></span>"
      },
      {
        "pronoun": "du",
        "full_form": "hast",
        "root": "ha",
        "termination": "st",
        "tense": "Präsens",
        "root_changed": true,
        "html": "<span><span class=\"root changed\">ha</span><span class=\"termination\">st</span></span>"
      },
      {
        "pronoun": "er/sie/es",
        "full_form": "hat",
        "root": "ha",
        "termination": "t",
        "tense": "Präsens",
        "root_changed": true,
        "html": "<span><span class=\"root changed\">ha</span><span class=\"termination\">t</span></span>"
      },
      {
        "pronoun": "ich",
        "full_form": "hatte",
        "root": "hat",
        "termination": "te",
        "tense": "Präteritum",
        "root_changed": true,
        "html": "<span><span class=\"root changed\">hat</span><span class=\"termination\">te</span></span>"
      },
      {
        "pronoun": "er/sie/es",
        "full_form": "hatte",
        "root": "hat",
        "termination": "te",
        "tense": "Präteritum",
        "root_changed": true,
        "is_principal_part": true,
        "html": "<span><span class=\"root changed\">hat</span><span class=\"termination\">te</span></span>"
      },
      {
        "form": "gehabt",
        "full_form": "gehabt",
        "prefix": "ge",
        "root": "hab",
        "termination": "t",
        "tense": "Partizip II",
        "root_changed": false,
        "auxiliary_verb": "haben",
        "html": "<span><span class=\"prefix\">ge</span><span class=\"root\">hab</span><span class=\"termination\">t</span></span>"
      }
    ],
    "url": "https://de.wiktionary.org/wiki/haben"
  }
}
```

---

### Verb — können (Modalverb)

```json
{
  "static": {
    "lemma": "können",
    "language": "de",
    "part_of_speech": "Verb"
  },
  "dynamic": {
    "verb_type": "Modalverb",
    "regularity": "unregelmäßig",
    "auxiliary_verb": "haben",
    "ipa": "/ˈkœnən/",
    "translations": {
      "ru": [
        { "text": "мочь",              "link": "https://ru.wiktionary.org/wiki/мочь" },
        { "text": "уметь",             "link": "https://ru.wiktionary.org/wiki/уметь" },
        { "text": "быть в состоянии",  "link": "https://ru.wiktionary.org/wiki/состояние" }
      ]
    },
    "examples": [
      { "de": "Kannst du mir helfen?", "ru": "Ты можешь мне помочь?" }
    ],
    "imperative_forms": null,
    "konjunktiv_ii_forms": {
      "ich":       { "form": "könnte",   "html": "<span><span class=\"root\">k<span class=\"vowel-changed\">ö</span>nnt</span><span class=\"termination\">e</span></span>" },
      "du":        { "form": "könntest", "html": "<span><span class=\"root\">k<span class=\"vowel-changed\">ö</span>nnt</span><span class=\"termination\">est</span></span>" },
      "er/sie/es": { "form": "könnte",   "html": "<span><span class=\"root\">k<span class=\"vowel-changed\">ö</span>nnt</span><span class=\"termination\">e</span></span>" },
      "wir":       { "form": "könnten",  "html": "<span><span class=\"root\">k<span class=\"vowel-changed\">ö</span>nnt</span><span class=\"termination\">en</span></span>" },
      "ihr":       { "form": "könntet",  "html": "<span><span class=\"root\">k<span class=\"vowel-changed\">ö</span>nnt</span><span class=\"termination\">et</span></span>" },
      "Sie/sie":   { "form": "könnten",  "html": "<span><span class=\"root\">k<span class=\"vowel-changed\">ö</span>nnt</span><span class=\"termination\">en</span></span>" }
    },
    "flexion": [
      {
        "pronoun": "ich",
        "full_form": "kann",
        "root": "kann",
        "termination": "",
        "tense": "Präsens",
        "root_changed": true,
        "html": "<span><span class=\"root changed\">kann</span></span>"
      },
      {
        "pronoun": "du",
        "full_form": "kannst",
        "root": "kann",
        "termination": "st",
        "tense": "Präsens",
        "root_changed": true,
        "html": "<span><span class=\"root changed\">kann</span><span class=\"termination\">st</span></span>"
      },
      {
        "pronoun": "er/sie/es",
        "full_form": "kann",
        "root": "kann",
        "termination": "",
        "tense": "Präsens",
        "root_changed": true,
        "html": "<span><span class=\"root changed\">kann</span></span>"
      },
      {
        "pronoun": "wir",
        "full_form": "können",
        "root": "könn",
        "termination": "en",
        "tense": "Präsens",
        "root_changed": false,
        "html": "<span><span class=\"root\">könn</span><span class=\"termination\">en</span></span>"
      },
      {
        "pronoun": "ich",
        "full_form": "konnte",
        "root": "konn",
        "termination": "te",
        "tense": "Präteritum",
        "root_changed": true,
        "html": "<span><span class=\"root\">k<span class=\"vowel-changed\">o</span>nn</span><span class=\"termination\">te</span></span>"
      },
      {
        "pronoun": "er/sie/es",
        "full_form": "konnte",
        "root": "konn",
        "termination": "te",
        "tense": "Präteritum",
        "root_changed": true,
        "is_principal_part": true,
        "html": "<span><span class=\"root\">k<span class=\"vowel-changed\">o</span>nn</span><span class=\"termination\">te</span></span>"
      },
      {
        "form": "gekonnt",
        "full_form": "gekonnt",
        "prefix": "ge",
        "root": "konn",
        "termination": "t",
        "tense": "Partizip II",
        "root_changed": true,
        "auxiliary_verb": "haben",
        "html": "<span><span class=\"prefix\">ge</span><span class=\"root\">k<span class=\"vowel-changed\">o</span>nn</span><span class=\"termination\">t</span></span>"
      }
    ],
    "url": "https://de.wiktionary.org/wiki/können"
  }
}
```

---

### Verb — abfahren (trennbar)

```json
{
  "static": {
    "lemma": "abfahren",
    "language": "de",
    "part_of_speech": "Verb"
  },
  "dynamic": {
    "verb_type": "stark",
    "regularity": "unregelmäßig",
    "is_separable": true,
    "prefix": "ab",
    "auxiliary_verb": "sein",
    "ipa": "/ˈapˌfaːʁən/",
    "translations": {
      "ru": [
        { "text": "отъезжать",    "link": "https://ru.wiktionary.org/wiki/отъезжать" },
        { "text": "уезжать",      "link": "https://ru.wiktionary.org/wiki/уезжать" },
        { "text": "отправляться", "link": "https://ru.wiktionary.org/wiki/отправляться" }
      ]
    },
    "examples": [
      { "de": "Der Zug fährt um 10 Uhr ab.", "ru": "Поезд отправляется в 10 часов." }
    ],
    "imperative_forms": {
      "du":  { "form": "fahr ab",       "html": "<span><span class=\"root\">fahr</span> <span class=\"prefix-sep\">ab</span></span>" },
      "ihr": { "form": "fahrt ab",      "html": "<span><span class=\"root\">fahr</span><span class=\"termination\">t</span> <span class=\"prefix-sep\">ab</span></span>" },
      "wir": { "form": "fahren wir ab", "html": "<span><span class=\"root\">fahr</span><span class=\"termination\">en</span> wir <span class=\"prefix-sep\">ab</span></span>" },
      "Sie": { "form": "fahren Sie ab", "html": "<span><span class=\"root\">fahr</span><span class=\"termination\">en</span> Sie <span class=\"prefix-sep\">ab</span></span>" }
    },
    "konjunktiv_ii_forms": {
      "ich":       { "form": "führe ab",   "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ü</span>hr</span><span class=\"termination\">e</span> <span class=\"prefix-sep\">ab</span></span>" },
      "du":        { "form": "führest ab", "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ü</span>hr</span><span class=\"termination\">est</span> <span class=\"prefix-sep\">ab</span></span>" },
      "er/sie/es": { "form": "führe ab",   "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ü</span>hr</span><span class=\"termination\">e</span> <span class=\"prefix-sep\">ab</span></span>" },
      "wir":       { "form": "führen ab",  "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ü</span>hr</span><span class=\"termination\">en</span> <span class=\"prefix-sep\">ab</span></span>" },
      "ihr":       { "form": "führet ab",  "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ü</span>hr</span><span class=\"termination\">et</span> <span class=\"prefix-sep\">ab</span></span>" },
      "Sie/sie":   { "form": "führen ab",  "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ü</span>hr</span><span class=\"termination\">en</span> <span class=\"prefix-sep\">ab</span></span>" }
    },
    "flexion": [
      {
        "pronoun": "ich",
        "full_form": "fahre ab",
        "root": "fahr",
        "termination": "e",
        "prefix": "ab",
        "tense": "Präsens",
        "root_changed": false,
        "html": "<span><span class=\"root\">fahr</span><span class=\"termination\">e</span> <span class=\"prefix-sep\">ab</span></span>"
      },
      {
        "pronoun": "du",
        "full_form": "fährst ab",
        "root": "fähr",
        "termination": "st",
        "prefix": "ab",
        "tense": "Präsens",
        "root_changed": true,
        "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ä</span>hr</span><span class=\"termination\">st</span> <span class=\"prefix-sep\">ab</span></span>"
      },
      {
        "pronoun": "er/sie/es",
        "full_form": "fährt ab",
        "root": "fähr",
        "termination": "t",
        "prefix": "ab",
        "tense": "Präsens",
        "root_changed": true,
        "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">ä</span>hr</span><span class=\"termination\">t</span> <span class=\"prefix-sep\">ab</span></span>"
      },
      {
        "pronoun": "ich",
        "full_form": "fuhr ab",
        "root": "fuhr",
        "termination": "",
        "prefix": "ab",
        "tense": "Präteritum",
        "root_changed": true,
        "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">u</span>hr</span> <span class=\"prefix-sep\">ab</span></span>"
      },
      {
        "pronoun": "er/sie/es",
        "full_form": "fuhr ab",
        "root": "fuhr",
        "termination": "",
        "prefix": "ab",
        "tense": "Präteritum",
        "root_changed": true,
        "is_principal_part": true,
        "html": "<span><span class=\"root\">f<span class=\"vowel-changed\">u</span>hr</span> <span class=\"prefix-sep\">ab</span></span>"
      },
      {
        "form": "abgefahren",
        "full_form": "abgefahren",
        "prefix": "ab",
        "infix": "ge",
        "root": "fahr",
        "termination": "en",
        "tense": "Partizip II",
        "root_changed": false,
        "auxiliary_verb": "sein",
        "html": "<span><span class=\"prefix-sep\">ab</span><span class=\"infix\">ge</span><span class=\"root\">fahr</span><span class=\"termination\">en</span></span>"
      }
    ],
    "url": "https://de.wiktionary.org/wiki/abfahren"
  }
}
```

---

### Verb — freuen (reflexiv, Akkusativ)

> `reflexive: true` — `sich` не включается в формы `flexion`. Рефлексивное местоимение подставляется фронтом на основе `reflexive_pronoun_case`.

```json
{
  "static": {
    "lemma": "freuen",
    "language": "de",
    "part_of_speech": "Verb"
  },
  "dynamic": {
    "verb_type": "schwach",
    "regularity": "regelmäßig",
    "is_separable": false,
    "prefix": null,
    "auxiliary_verb": "haben",
    "reflexive": true,
    "reflexive_pronoun_case": "Akkusativ",
    "ipa": "/ˈfʁɔʏ̯ən/",
    "translations": {
      "ru": [
        { "text": "радоваться", "link": "https://ru.wiktionary.org/wiki/радоваться" }
      ]
    },
    "examples": [
      { "de": "Ich freue mich auf den Urlaub.", "ru": "Я с нетерпением жду отпуска." },
      { "de": "Er freut sich über das Geschenk.", "ru": "Он рад подарку." }
    ],
    "imperative_forms": {
      "du":  { "form": "freu dich",        "html": "<span><span class=\"root\">freu</span> dich</span>" },
      "ihr": { "form": "freut euch",       "html": "<span><span class=\"root\">freu</span><span class=\"termination\">t</span> euch</span>" },
      "wir": { "form": "freuen wir uns",   "html": "<span><span class=\"root\">freu</span><span class=\"termination\">en</span> wir uns</span>" },
      "Sie": { "form": "freuen Sie sich",  "html": "<span><span class=\"root\">freu</span><span class=\"termination\">en</span> Sie sich</span>" }
    },
    "konjunktiv_ii_forms": {
      "ich":       { "form": "freute",   "html": "<span><span class=\"root\">freu</span><span class=\"termination\">te</span></span>" },
      "du":        { "form": "freutest", "html": "<span><span class=\"root\">freu</span><span class=\"termination\">test</span></span>" },
      "er/sie/es": { "form": "freute",   "html": "<span><span class=\"root\">freu</span><span class=\"termination\">te</span></span>" },
      "wir":       { "form": "freuten",  "html": "<span><span class=\"root\">freu</span><span class=\"termination\">ten</span></span>" },
      "ihr":       { "form": "freutet",  "html": "<span><span class=\"root\">freu</span><span class=\"termination\">tet</span></span>" },
      "Sie/sie":   { "form": "freuten",  "html": "<span><span class=\"root\">freu</span><span class=\"termination\">ten</span></span>" }
    },
    "flexion": [
      {
        "pronoun": "ich",
        "full_form": "freue",
        "root": "freu",
        "termination": "e",
        "tense": "Präsens",
        "root_changed": false,
        "html": "<span><span class=\"root\">freu</span><span class=\"termination\">e</span></span>"
      },
      {
        "pronoun": "du",
        "full_form": "freust",
        "root": "freu",
        "termination": "st",
        "tense": "Präsens",
        "root_changed": false,
        "html": "<span><span class=\"root\">freu</span><span class=\"termination\">st</span></span>"
      },
      {
        "pronoun": "er/sie/es",
        "full_form": "freut",
        "root": "freu",
        "termination": "t",
        "tense": "Präsens",
        "root_changed": false,
        "html": "<span><span class=\"root\">freu</span><span class=\"termination\">t</span></span>"
      },
      {
        "pronoun": "ich",
        "full_form": "freute",
        "root": "freu",
        "termination": "te",
        "tense": "Präteritum",
        "root_changed": false,
        "html": "<span><span class=\"root\">freu</span><span class=\"termination\">te</span></span>"
      },
      {
        "pronoun": "er/sie/es",
        "full_form": "freute",
        "root": "freu",
        "termination": "te",
        "tense": "Präteritum",
        "root_changed": false,
        "is_principal_part": true,
        "html": "<span><span class=\"root\">freu</span><span class=\"termination\">te</span></span>"
      },
      {
        "form": "gefreut",
        "full_form": "gefreut",
        "infix": "ge",
        "root": "freu",
        "termination": "t",
        "tense": "Partizip II",
        "root_changed": false,
        "auxiliary_verb": "haben",
        "html": "<span><span class=\"infix\">ge</span><span class=\"root\">freu</span><span class=\"termination\">t</span></span>"
      }
    ],
    "url": "https://de.wiktionary.org/wiki/freuen"
  }
}
```

---

### Substantiv — Tasche

> `flexion` — объект с ключами по падежам. `genitiv_singular` и `plural` — краткие формы для карточки.

```json
{
  "static": {
    "lemma": "Tasche",
    "language": "de",
    "part_of_speech": "Substantiv"
  },
  "dynamic": {
    "gender": "feminin",
    "declension_type": "stark",
    "genitiv_singular": "der Tasche",
    "plural": "Taschen",
    "ipa": "/ˈtaʃə/",
    "translations": {
      "ru": [
        { "text": "сумка",  "link": "https://ru.wiktionary.org/wiki/сумка" },
        { "text": "карман", "link": "https://ru.wiktionary.org/wiki/карман" },
        { "text": "пакет",  "link": "https://ru.wiktionary.org/wiki/пакет" }
      ]
    },
    "examples": [
      { "de": "Die Tasche liegt auf dem Tisch.", "ru": "Сумка лежит на столе." }
    ],
    "flexion": {
      "Nominativ": {
        "singular": {
          "article": "die",
          "form": "Tasche",
          "html": "<span><span class=\"article\">die</span> <span class=\"root\">Tasch</span><span class=\"termination\">e</span></span>"
        },
        "plural": {
          "article": "die",
          "form": "Taschen",
          "html": "<span><span class=\"article\">die</span> <span class=\"root\">Tasch</span><span class=\"termination\">en</span></span>"
        }
      },
      "Genitiv": {
        "singular": {
          "article": "der",
          "form": "Tasche",
          "html": "<span><span class=\"article\">der</span> <span class=\"root\">Tasch</span><span class=\"termination\">e</span></span>"
        },
        "plural": {
          "article": "der",
          "form": "Taschen",
          "html": "<span><span class=\"article\">der</span> <span class=\"root\">Tasch</span><span class=\"termination\">en</span></span>"
        }
      },
      "Dativ": {
        "singular": {
          "article": "der",
          "form": "Tasche",
          "html": "<span><span class=\"article\">der</span> <span class=\"root\">Tasch</span><span class=\"termination\">e</span></span>"
        },
        "plural": {
          "article": "den",
          "form": "Taschen",
          "html": "<span><span class=\"article\">den</span> <span class=\"root\">Tasch</span><span class=\"termination\">en</span></span>"
        }
      },
      "Akkusativ": {
        "singular": {
          "article": "die",
          "form": "Tasche",
          "html": "<span><span class=\"article\">die</span> <span class=\"root\">Tasch</span><span class=\"termination\">e</span></span>"
        },
        "plural": {
          "article": "die",
          "form": "Taschen",
          "html": "<span><span class=\"article\">die</span> <span class=\"root\">Tasch</span><span class=\"termination\">en</span></span>"
        }
      }
    },
    "url": "https://de.wiktionary.org/wiki/Tasche"
  }
}
```

---

### Substantiv — Name (N-Deklination / schwache Deklination)

```json
{
  "static": {
    "lemma": "Name",
    "language": "de",
    "part_of_speech": "Substantiv"
  },
  "dynamic": {
    "gender": "maskulin",
    "declension_type": "schwach",
    "genitiv_singular": "des Namens",
    "plural": "Namen",
    "ipa": "/ˈnaːmə/",
    "translations": {
      "ru": [
        { "text": "имя",       "link": "https://ru.wiktionary.org/wiki/имя" },
        { "text": "название",  "link": "https://ru.wiktionary.org/wiki/название" }
      ]
    },
    "examples": [
      { "de": "Wie ist dein Name?", "ru": "Как тебя зовут?" }
    ],
    "flexion": {
      "Nominativ": {
        "singular": { "article": "der", "form": "Name",  "html": "<span><span class=\"article\">der</span> <span class=\"root\">Nam</span><span class=\"termination\">e</span></span>" },
        "plural":   { "article": "die", "form": "Namen", "html": "<span><span class=\"article\">die</span> <span class=\"root\">Nam</span><span class=\"termination\">en</span></span>" }
      },
      "Genitiv": {
        "singular": { "article": "des", "form": "Namens", "html": "<span><span class=\"article\">des</span> <span class=\"root\">Nam</span><span class=\"termination\">ens</span></span>" },
        "plural":   { "article": "der", "form": "Namen",  "html": "<span><span class=\"article\">der</span> <span class=\"root\">Nam</span><span class=\"termination\">en</span></span>" }
      },
      "Dativ": {
        "singular": { "article": "dem", "form": "Namen", "html": "<span><span class=\"article\">dem</span> <span class=\"root\">Nam</span><span class=\"termination\">en</span></span>" },
        "plural":   { "article": "den", "form": "Namen", "html": "<span><span class=\"article\">den</span> <span class=\"root\">Nam</span><span class=\"termination\">en</span></span>" }
      },
      "Akkusativ": {
        "singular": { "article": "den", "form": "Namen", "html": "<span><span class=\"article\">den</span> <span class=\"root\">Nam</span><span class=\"termination\">en</span></span>" },
        "plural":   { "article": "die", "form": "Namen", "html": "<span><span class=\"article\">die</span> <span class=\"root\">Nam</span><span class=\"termination\">en</span></span>" }
      }
    },
    "url": "https://de.wiktionary.org/wiki/Name"
  }
}
```

---

### Adjektiv — privat (nicht steigerbar)

```json
{
  "static": {
    "lemma": "privat",
    "language": "de",
    "part_of_speech": "Adjektiv"
  },
  "dynamic": {
    "is_comparable": false,
    "ipa": "/pʁiˈvaːt/",
    "translations": {
      "ru": [
        { "text": "частный",    "link": "https://ru.wiktionary.org/wiki/частный" },
        { "text": "приватный",  "link": "https://ru.wiktionary.org/wiki/приватный" }
      ]
    },
    "examples": [
      { "de": "Das ist eine private Angelegenheit.", "ru": "Это частное дело." }
    ],
    "comparative_forms": null,
    "url": "https://de.wiktionary.org/wiki/privat"
  }
}
```

---

### Adjektiv — groß (steigerbar)

```json
{
  "static": {
    "lemma": "groß",
    "language": "de",
    "part_of_speech": "Adjektiv"
  },
  "dynamic": {
    "is_comparable": true,
    "ipa": "/ɡʁoːs/",
    "translations": {
      "ru": [
        { "text": "большой",  "link": "https://ru.wiktionary.org/wiki/большой" },
        { "text": "великий",  "link": "https://ru.wiktionary.org/wiki/великий" }
      ]
    },
    "examples": [
      { "de": "Das ist ein großes Haus.", "ru": "Это большой дом." }
    ],
    "comparative_forms": {
      "positiv": {
        "form": "groß",
        "html": "<span><span class=\"root\">groß</span></span>"
      },
      "komparativ": {
        "form": "größer",
        "html": "<span><span class=\"root\">gr<span class=\"vowel-changed\">ö</span>ß</span><span class=\"termination\">er</span></span>"
      },
      "superlativ": {
        "form": "am größten",
        "html": "<span><span class=\"particle\">am</span> <span class=\"root\">gr<span class=\"vowel-changed\">ö</span>ßt</span><span class=\"termination\">en</span></span>"
      }
    },
    "url": "https://de.wiktionary.org/wiki/groß"
  }
}
```

---

### Adverb — gestern

```json
{
  "static": {
    "lemma": "gestern",
    "language": "de",
    "part_of_speech": "Adverb"
  },
  "dynamic": {
    "is_comparable": false,
    "ipa": "/ˈɡɛstɐn/",
    "translations": {
      "ru": [{ "text": "вчера", "link": "https://ru.wiktionary.org/wiki/вчера" }]
    },
    "examples": [
      { "de": "Ich war gestern zu Hause.", "ru": "Вчера я был дома." }
    ],
    "comparative_forms": null,
    "flexion": null,
    "url": "https://de.wiktionary.org/wiki/gestern"
  }
}
```

---

### Präposition — mit (nur Dativ)

```json
{
  "static": {
    "lemma": "mit",
    "language": "de",
    "part_of_speech": "Präposition"
  },
  "dynamic": {
    "governed_case": ["Dativ"],
    "is_wechselpräposition": false,
    "ipa": "/mɪt/",
    "translations": {
      "ru": [
        { "text": "с",   "link": "https://ru.wiktionary.org/wiki/с" },
        { "text": "со",  "link": "https://ru.wiktionary.org/wiki/со" }
      ]
    },
    "examples": [
      { "de": "Ich fahre mit dem Bus.", "ru": "Я еду на автобусе." },
      { "de": "Sie kommt mit ihrer Freundin.", "ru": "Она приходит со своей подругой." }
    ],
    "url": "https://de.wiktionary.org/wiki/mit"
  }
}
```

---

### Präposition — in (Wechselpräposition: Dativ/Akkusativ)

```json
{
  "static": {
    "lemma": "in",
    "language": "de",
    "part_of_speech": "Präposition"
  },
  "dynamic": {
    "governed_case": ["Dativ", "Akkusativ"],
    "is_wechselpräposition": true,
    "ipa": "/ɪn/",
    "translations": {
      "ru": [
        { "text": "в",   "link": "https://ru.wiktionary.org/wiki/в" },
        { "text": "во",  "link": "https://ru.wiktionary.org/wiki/во" }
      ]
    },
    "examples": [
      { "de": "Das Buch liegt in der Tasche. (Dativ — wo?)",    "ru": "Книга лежит в сумке." },
      { "de": "Ich lege das Buch in die Tasche. (Akkusativ — wohin?)", "ru": "Я кладу книгу в сумку." }
    ],
    "url": "https://de.wiktionary.org/wiki/in"
  }
}
```

---

### Pronomen — (структура, TODO)

> Местоимения имеют нестандартную таблицу склонения. Структура `flexion` для них аналогична существительному (объект по падежам), но добавляется поле `pronoun_type` (Personal, Possessiv, Reflexiv, Relativ, Demonstrativ и т.д.) и при необходимости `person` + `number`.

```json
{
  "static": {
    "lemma": "ich",
    "language": "de",
    "part_of_speech": "Pronomen"
  },
  "dynamic": {
    "pronoun_type": "Personalpronomen",
    "person": "1",
    "number": "Singular",
    "ipa": "/ɪç/",
    "translations": {
      "ru": [{ "text": "я", "link": "https://ru.wiktionary.org/wiki/я" }]
    },
    "examples": [],
    "flexion": {
      "Nominativ": { "form": "ich",   "html": "<span>ich</span>" },
      "Genitiv":   { "form": "meiner","html": "<span>meiner</span>" },
      "Dativ":     { "form": "mir",   "html": "<span>mir</span>" },
      "Akkusativ": { "form": "mich",  "html": "<span>mich</span>" }
    },
    "url": "https://de.wiktionary.org/wiki/ich"
  }
}
```
