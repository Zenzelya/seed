# Epic 03: E2E — Playwright end-to-end тесты + строгий lint-gate

## Оглавление

- [Summary](#summary)
- [Appetite](#appetite)
- [Problem](#problem)
- [Solution](#solution)
- [Non-goals](#non-goals)
- [Dependencies](#dependencies)
- [Architecture decisions](#architecture-decisions)
- [Rabbit holes](#rabbit-holes)
- [Open questions](#open-questions)
- [Tasks](#tasks)
- [E2E acceptance](#e2e-acceptance)
- [Rollback](#rollback)

---

## Summary

Добавляем **Playwright** для end-to-end тестов фронтенда. Покрываем golden-path флоу (demo-guest →
логин → authed-дашборд, переключение языка обучения / UI-локали / темы, обработка текста → конструктор
колоды). Документируем best-practices написания тестов в `frontend/CLAUDE.md`. Переводим фронт-линтер
в строгий **продакшен-режим** (как на беке) с отдельным override для тестовых файлов. Интегрируем
прогон в CI.

---

## Appetite

**Лимит:** 6 задач

---

## Problem

- Нет автоматических проверок UX-флоу — регрессии ловятся вручную в браузере
- Свап mock → GraphQL (Epic 02) может незаметно сломать Dashboard — нет защитной сетки
- Фронт-линтер не в строгом CI-режиме: скрипт — голый `eslint` (без `--max-warnings 0`, без fail-gate),
  нет override для тестовых файлов (в которых допустимы `any`/unsafe — как `*.spec.ts` на беке)
- Нет конвенций по написанию тестов в `frontend/CLAUDE.md`

---

## Solution

1. Установить `@playwright/test`, конфиг (`playwright.config.ts`), структура `e2e/`
2. Инфраструктура: fixtures, Page Object Model, **сетевые моки** через `page.route()` (GraphQL/REST),
   storage state для authed-сессии
3. Golden-path спеки на ключевые флоу
4. Раздел «Testing» в `frontend/CLAUDE.md` — best-practices Playwright
5. Фронт-линтер → строгий продакшен-режим + override для `e2e/**`
6. Визуальный регресс — dev-эксперимент `toHaveScreenshot` (не gating)

> CI/Actions/деплой — **вне эпика** (Q1), отдельный deploy-эпик.

---

## Non-goals

- [ ] **CI / GitHub Actions / деплой** — вне этого эпика (Actions не настроены), отдельный **deploy-эпик** (Q1)
- [ ] **Реальный бэкенд в тестах** — в этом эпике только моки сети; smoke на реальном беке — в deploy-эпике (Q2)
- [ ] **Визуальный регресс как gate** — нет; в этом эпике только **dev-эксперимент** `toHaveScreenshot`, не блокирующий (TASK-6, Q3)
- [ ] Полная кросс-браузерная матрица — старт на chromium + мобильные iPhone/Pixel (Q4)
- [ ] Юнит/компонентные тесты (Jest/Vitest) на фронте — проект держит юнит только на критпуть; фронт покрываем E2E
- [ ] Нагрузочное / performance-тестирование
- [ ] Тесты для backend (там Jest + `*.int.spec.ts` уже есть)

---

## Dependencies

| Зависимость | Где | Статус |
|---|---|---|
| Epic 01 (Home UI, demo-guest, модалки) | frontend | ⏳ в работе |
| Epic 02 (GraphQL/REST-auth — для authed-флоу; можно мокать) | back+front | ⏳ план |
| `@playwright/test` | frontend devDep | ❌ |
| Frontend dev server (`yarn dev`, :4200) | frontend | ✅ |

---

## Architecture decisions

### Playwright vs Cypress

**Решение:** Playwright. Быстрее, нативная мультибраузерность (chromium/webkit/firefox), авто-ожидания
(web-first assertions), хорошо работает с PWA и App Router, встроенный trace-viewer.

### Моки сети vs реальный бэк (Q2)

**Решение:** в этом эпике — **только моки** через `page.route()` (перехват GraphQL `/graphql` и REST
`/auth/*`). Стабильно, изолированно, не зависит от состояния БД, запускается локально без поднятого бэка.
Smoke на реальном беке — отложен в **deploy-эпик** (вместе с CI).

**Почему:** demo-guest флоу backend не нужен вовсе; authed-флоу с моками детерминирован. Реальный smoke
ценен прежде всего в CI, а CI вынесен в отдельный эпик — поэтому здесь не дублируем инфраструктуру.

### Мобильные вьюпорты + PWA (Q4)

**Решение:** projects в `playwright.config.ts` — desktop chromium + **iPhone 14** + **Pixel 7**
(пресеты `devices[...]`). Проверяем PWA-инсталлируемость на уровне, доступном браузеру: наличие/валидность
`manifest.json`, регистрация SW (вне dev), `display: standalone` через `matchMedia('(display-mode: standalone)')`.

**Почему:** приложение — устанавливаемая PWA на телефон (цель Epic 01); мобильные вьюпорты ловят
регрессии адаптива, которых не видно на десктопе.

### Визуальный регресс — только dev-эксперимент (Q3)

**Решение:** `toHaveScreenshot` на 2-3 ключевых экранах, запускается **локально в dev** (TASK-6),
**не gating**, не в CI. Бейзлайны держим локально (или в `.gitignore`), чтобы посмотреть, как это работает.

**Почему:** интересно оценить инструмент без обязательств; полноценный визуальный gate — отдельно, когда будет CI.

### Структура и переиспользование

**Решение:** каталог `e2e/` рядом с `src/` (вне `src/`, чтобы не попадал в сборку). Page Object Model
для страниц/виджетов, fixtures для общего setup. Storage state для «уже залогиненного» контекста.

### Линтер — единый strict, тесты — override

**Решение:** правила фронта уже зеркалят бек (`recommendedTypeChecked` + `stylisticTypeChecked`).
В продакшен-режиме: `--max-warnings 0`, fail-on-error, без `--fix` в CI (отдельный `lint:fix` для локалки),
+ блок override для `e2e/**` и `*.spec.ts` (как `*.spec.ts` на беке — гасим `no-explicit-any`,
`no-unsafe-*`, `unbound-method`).

---

## Rabbit holes

- **PWA service worker** мешает тестам (кеширование, перехват сети) → отключать SW в test/CI-режиме
  (`disable` уже стоит для dev — убедиться, что в Playwright SW не регистрируется)
- **Анимации** (flip-карта, модалки, fadein/risein) → ждать состояния через web-first assertions,
  не хардкодить `waitForTimeout`
- **`next/font` + сеть в CI** → шрифты self-hosted (next/font), но проверить, что прогон не зависит от внешней сети
- **localStorage между тестами** (`wl_user`, `wl_uiLocale`, `wl_theme`) → чистить storage в fixtures, изоляция контекста
- **Apollo InMemoryCache** в authed-флоу → свежий браузер-контекст на тест, не шарить кеш
- **Порт/baseURL** → `webServer` в `playwright.config.ts` поднимает `yarn dev` на :4200 (или reuse существующего)
- **PWA-инсталляция** → реальную установку в ОС Playwright не сэмулирует; проверяем косвенно (manifest валиден,
  SW регистрируется вне dev, `display-mode: standalone`). `beforeinstallprompt` — только chromium

---

## Open questions

**Все закрыты.**

- [x] ~~Q1: CI~~ → **вне эпика**, Actions не настроены, отдельный **deploy-эпик**.
- [x] ~~Q2: реальный бэк~~ → **только моки** в этом эпике; smoke на реальном беке — в deploy-эпике.
- [x] ~~Q3: визуальный регресс~~ → **dev-эксперимент** `toHaveScreenshot` (TASK-6), не gating, не CI.
- [x] ~~Q4: мобильные + PWA~~ → **да**: iPhone 14 + Pixel 7, проверка PWA-инсталлируемости.
- [ ] Q5: `lint:fix` локально, строгий `lint` без fix — подтвердить в TASK-5 (дефолт: да).

---

## Tasks

> Двухуровневое планирование: ниже — shallow-описание задач. Детальный план (структура файлов,
> сигнатуры fixtures, перечень моков) — в `implementation.md` перед исполнением.

### TASK-1 · Установка и конфиг Playwright

**Статус:** ❌  **Блокирует:** TASK-2  **Заблокирована:** —

**IN:** `frontend/package.json`
**OUT:** `@playwright/test` в devDeps, `playwright.config.ts`, скрипт `e2e`, каталог `e2e/`

**Что сделать:**
- `yarn add -D @playwright/test` + `npx playwright install --with-deps chromium`
- `playwright.config.ts`: `testDir: 'e2e'`, `baseURL: 'http://localhost:4200'`,
  `webServer` (поднимает `yarn dev`, `reuseExistingServer` локально),
  projects: **desktop chromium + iPhone 14 + Pixel 7** (`...devices['iPhone 14']`, `...devices['Pixel 7']`),
  `trace: 'on-first-retry'`
- Скрипты: `"e2e": "playwright test"`, `"e2e:ui": "playwright test --ui"`
- `.gitignore`: `/test-results`, `/playwright-report`, `/.playwright`

**Критерии:**
- [ ] `yarn e2e` стартует dev-сервер и гоняет пустой smoke-спек зелёным
- [ ] Артефакты отчётов в `.gitignore`

---

### TASK-2 · Тестовая инфраструктура

**Статус:** ❌  **Блокирует:** TASK-3  **Заблокирована:** TASK-1

**IN:** структура флоу из Epic 01/02
**OUT:** `e2e/fixtures/`, `e2e/pages/` (Page Objects), `e2e/mocks/` (network), `e2e/utils/storage.ts`

**Что сделать:**
- Fixtures: чистый контекст (сброс `localStorage`: `wl_user`/`wl_uiLocale`/`wl_theme`), `mockApi` fixture
- **Сетевые моки** (`page.route()`): GraphQL `me`/`srsQueue`/`categories`/`dailyPick`/`activityHeatmap`;
  REST `/auth/login`/`/auth/refresh`/`/auth/logout`. Фикстуры-ответы в `e2e/mocks/`
- Page Objects: `DashboardPage`, `HeaderNav`, `AuthModal`, `DeckBuilderPage`
- `authedContext` через storageState (предзалогиненный)

**Критерии:**
- [ ] Спек может замокать GraphQL/REST и получить детерминированный дашборд
- [ ] Локаторы — role-based (`getByRole`/`getByLabel`), без брит­тл-селекторов

---

### TASK-3 · Golden-path спеки

**Статус:** ❌  **Блокирует:** —  **Заблокирована:** TASK-2

**OUT:** `e2e/*.spec.ts` на ключевые флоу:
1. **demo-guest:** первый визит → виден DemoBanner + mock-дашборд
2. **login (REST):** открыть LoginModal → креды → authed, баннер исчез, профиль в хедере
3. **persistence:** reload после login → сессия сохранена (refresh-cookie / storage)
4. **lang обучения:** смена языка → меняются SRS-карточки и текст анализатора
5. **UI-локаль:** ru/en/de → меняются подписи интерфейса
6. **тема:** light/dark/system — переключение применяется
7. **flashcard:** flip по клику + SRS-кнопки листают очередь
8. **text → deck:** вставить текст → «Обработать» → выбрать слова → «Создать колоду» → `/dictionaries/new`
9. **logout:** → возврат к demo-guest + DemoBanner
10. **PWA (Q4):** `manifest.json` валиден/доступен; `display-mode: standalone` определяется; SW не ломает навигацию
11. **mobile (Q4):** ключевые флоу (1, 2, 8) прогоняются на проектах iPhone 14 / Pixel 7 — адаптив не сломан

**Критерии:**
- [ ] Все спеки зелёные локально (с моками), на desktop + mobile проектах
- [ ] Web-first assertions (авто-ожидание), без `waitForTimeout`

---

### TASK-4 · Best-practices тестов → frontend/CLAUDE.md

**Статус:** ❌  **Блокирует:** —  **Заблокирована:** TASK-1

**IN:** `frontend/CLAUDE.md`
**OUT:** новый раздел «Testing (Playwright)»

**Что задокументировать:**
- Локаторы: `getByRole`/`getByLabel`/`getByText`; `data-testid` — только когда нет семантики
- Web-first assertions (`await expect(...).toBeVisible()`) — авто-ожидание; **запрет** `waitForTimeout`
- Изоляция: чистый контекст/`localStorage` на каждый тест; не зависеть от порядка
- Сеть: мок через `page.route()`; не ходить в реальный бэк в CI
- Auth: storageState вместо повторного логина в каждом тесте
- Структура: Page Object Model, fixtures; именование `*.spec.ts`
- Что НЕ тестировать E2E: чистую логику (юнит на критпуть), сторонние либы
- Запуск: `yarn e2e`, `yarn e2e:ui`, trace-viewer при падении

**Критерии:**
- [ ] Раздел в `frontend/CLAUDE.md` согласован со стилем существующих правил

---

### TASK-5 · ESLint production mode (фронт) + override для тестов

**Статус:** ❌  **Блокирует:** —  **Заблокирована:** —

**Контекст:** правила уже зеркалят бек; меняем **режим запуска** и добавляем override для тестов.

**IN:** `frontend/eslint.config.mjs`, `frontend/package.json`
**OUT:** строгий lint-скрипт + блок override для `e2e/**`/`*.spec.ts`

**Что сделать:**
- Скрипты: `"lint": "eslint . --max-warnings 0"` (CI, fail-on-error, без `--fix`),
  `"lint:fix": "eslint . --fix"` (локально)
- Override-блок (как `*.spec.ts` на беке): для `e2e/**`, `**/*.spec.ts` — выключить
  `@typescript-eslint/no-explicit-any`, `no-unsafe-*`, `unbound-method`
- Убедиться, что `e2e/` не игнорируется и попадает под typed-lint (или отдельный tsconfig для тестов)

**Критерии:**
- [ ] `yarn lint` падает при любом warning/error (как бек)
- [ ] Тестовые файлы не триггерят `any`/unsafe-правила
- [ ] `yarn lint:fix` доступен локально

---

### TASK-6 · Визуальный регресс — dev-эксперимент (Q3)

**Статус:** ❌  **Блокирует:** —  **Заблокирована:** TASK-2

**Цель:** посмотреть, как работает screenshot-тестирование Playwright. Локально, в dev, **не gating**.

**OUT:** `e2e/visual.spec.ts` (2-3 экрана), бейзлайны (локально / в `.gitignore`)

**Что сделать:**
- `await expect(page).toHaveScreenshot()` на ключевых экранах: Dashboard (demo-guest), Deck Builder,
  опц. тёмная тема
- Первый прогон создаёт бейзлайны (`--update-snapshots`), повторный — сравнивает
- Зафиксировать в заметке: что это, как обновлять бейзлайны, почему пока не в CI
- **Не** добавлять в обязательный прогон/гейт — это разведка инструмента

**Критерии:**
- [ ] `npx playwright test e2e/visual.spec.ts` создаёт и сравнивает скриншоты
- [ ] Понятно, что такое visual regression и стоит ли включать его как gate позже (вывод — в Q-лог deploy-эпика)

> CI/Actions/деплой — **вне этого эпика** (Q1), отдельный deploy-эпик: lint+tsc+build+e2e в пайплайне,
> smoke на реальном беке, визуальный gate.

---

## E2E acceptance

```bash
cd frontend
yarn lint                              # строгий, --max-warnings 0
npx tsc --noEmit
yarn build
yarn e2e                               # golden-path спеки (с моками), desktop + iPhone 14 + Pixel 7
yarn e2e:ui                            # локальный дебаг
npx playwright test e2e/visual.spec.ts # dev-эксперимент: визуальный регресс (не gating)
```

**Done когда:** golden-path флоу (вкл. PWA-проверку и мобильные вьюпорты) покрыты Playwright-спеками и
зелены **локально с моками**; фронт-линтер в строгом продакшен-режиме с override для тестов;
best-practices задокументированы в `frontend/CLAUDE.md`; визуальный регресс опробован в dev.
CI и реальный smoke — в deploy-эпике.

---

## Rollback

1. `yarn remove -D @playwright/test`
2. Удалить `e2e/`, `playwright.config.ts`, скрипты `e2e`/`e2e:ui`, бейзлайны скриншотов
3. Откатить `frontend/package.json` lint-скрипты и override-блок в `eslint.config.mjs`
4. Удалить раздел «Testing» из `frontend/CLAUDE.md`
