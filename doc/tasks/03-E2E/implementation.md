# Epic 03: E2E — план реализации

Детальный план (второй уровень) по эпику [Epic-03-E2E](Epic-03-E2E.md).
Цель: Playwright E2E для фронтенда (golden-path + mobile + PWA), best-practices в `frontend/CLAUDE.md`,
строгий продакшен-режим линтера, dev-эксперимент с визуальным регрессом. **Только моки сети, без CI.**

---

## Принятые решения (из обсуждения)

| # | Вопрос | Решение |
|---|---|---|
| 1 | CI / GitHub Actions / деплой | **Вне эпика** — отдельный deploy-эпик. Actions не настроены |
| 2 | Реальный бэк vs моки | **Только моки** (`page.route()`). Smoke на реальном беке — в deploy-эпике |
| 3 | Визуальный регресс | **Dev-эксперимент** `toHaveScreenshot`, не gating, не CI (TASK-6) |
| 4 | Мобильные + PWA | **Да:** iPhone 14 + Pixel 7; проверка PWA-инсталлируемости (manifest, standalone, SW) |
| 5 | Lint режим | `lint` строгий (`--max-warnings 0`, без fix) + `lint:fix` локально |

---

## Зависимость от Epic 01/02 — важно

Текущий фронт — **первый проход**: `wl_user` в localStorage, единственный роут `/`, mock-логин в модалке,
нет темы/i18n/deck-builder/REST/GraphQL. Полные [Epic 01](../01-CreateHomeDemo/Epic-01-CreateHomeDemo.md)
(Catalyst, i18n, тема, deck builder, REST-auth) и [Epic 02](../02-GraphQLIntegration/Epic-02-GraphQLIntegration.md)
(GraphQL) — **в плане, не построены**.

**Следствие для E2E:**
- Спеки пишутся под **финальные** флоу (после 01/02). Локаторы — семантические (`getByRole`/`getByText`),
  устойчивы к рефактору.
- Моки нацелены на эндпоинты Epic 02: GraphQL `/graphql` (`me`, `srsQueue`, `categories`, `dailyPick`,
  `activityHeatmap`) и REST `/auth/login|refresh|logout`.
- **Фазирование:** инфраструктуру (T1, T2, T4, T5) можно делать сейчас; golden-path спеки (T3) —
  по мере появления флоу из 01/02 (часть, напр. demo-guest, доступна уже сейчас).

**Ключи localStorage** (текущие + плановые): `wl_user`, `wl_uiLocale` (Epic01 F2), `wl_theme` (Epic01 F3).

---

## Статус задач

| Задача | Статус | Коммит |
|---|---|---|
| T1 · Установка + `playwright.config.ts` (chromium + iPhone 14 + Pixel 7) | ❌ | — |
| T2 · Инфраструктура (fixtures, Page Objects, сетевые моки, authed) | ❌ | — |
| T3 · Golden-path спеки (+ PWA + mobile) | ❌ | — |
| T4 · Best-practices → `frontend/CLAUDE.md` | ❌ | — |
| T5 · ESLint продакшен-режим + override для тестов | ❌ | — |
| T6 · Визуальный регресс — dev-эксперимент | ❌ | — |

**Порядок:** T1 → T2 → T5 → T4 → T3 → T6
(T5/T4 не зависят от спеков; T3 — последней, после готовности флоу 01/02; T6 — после T2.)

---

## Оглавление

- [T1 · Setup + config](#t1--setup--config)
- [T2 · Инфраструктура](#t2--инфраструктура)
- [T3 · Golden-path спеки](#t3--golden-path-спеки)
- [T4 · Best-practices → CLAUDE.md](#t4--best-practices--claudemd)
- [T5 · ESLint продакшен-режим](#t5--eslint-продакшен-режим)
- [T6 · Визуальный регресс](#t6--визуальный-регресс)
- [Соглашения](#соглашения)
- [Структура каталога e2e/](#структура-каталога-e2e)

---

## T1 · Setup + config

**IN:** `frontend/package.json`, `.gitignore`
**OUT:** `@playwright/test` в devDeps, `playwright.config.ts`, скрипты, smoke-спек

**Шаги:**
- `yarn add -D @playwright/test`
- `npx playwright install --with-deps chromium webkit`
  (chromium — desktop + Pixel 7; webkit — iPhone 14).
- `playwright.config.ts`:
  ```ts
  import { defineConfig, devices } from '@playwright/test'

  export default defineConfig({
    testDir: './e2e',
    testMatch: '**/*.spec.ts',
    fullyParallel: true,
    forbidOnly: !!process.env.CI,
    retries: 0,
    reporter: [['html', { open: 'never' }], ['list']],
    use: {
      baseURL: 'http://localhost:4200',
      trace: 'on-first-retry',
      screenshot: 'only-on-failure',
    },
    webServer: {
      command: 'yarn dev',
      url: 'http://localhost:4200',
      reuseExistingServer: true,
      timeout: 120_000,
    },
    projects: [
      { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
      { name: 'iphone-14', use: { ...devices['iPhone 14'] } },
      { name: 'pixel-7',   use: { ...devices['Pixel 7'] } },
    ],
  })
  ```
- `package.json` скрипты:
  ```json
  "e2e": "playwright test",
  "e2e:ui": "playwright test --ui",
  "e2e:update": "playwright test --update-snapshots"
  ```
- `.gitignore`: `/test-results`, `/playwright-report`, `/playwright/.cache`
- Smoke: `e2e/smoke.spec.ts` — `await page.goto('/'); await expect(page).toHaveTitle(/WordLearn/)`

**Критерии:**
- [ ] `yarn e2e` поднимает dev и гоняет smoke зелёным на всех 3 проектах
- [ ] Артефакты в `.gitignore`

---

## T2 · Инфраструктура

**OUT:** `e2e/fixtures/`, `e2e/pages/`, `e2e/mocks/`, `e2e/utils/`

### Сетевые моки (только моки, Q2)

`e2e/mocks/graphql.ts` — фикстуры ответов под DTO Epic 01:
```ts
export const meAuthed = { data: { me: { id: 'demo', email: 'demo@wordlearn.dev',
  firstName: 'Demo', lastName: null, role: 'CUSTOMER', createdAt: '2024-03-14T00:00:00Z',
  lang: 'de', level: 'A2', streak: 4, xp: 1240, uniqueWords: 47, masteredWords: 12,
  dailyGoal: 8, dailyDone: 5, weeklyGoal: 25, weeklyDone: 14 } } }
export const meGuest = { data: { me: null } }
export const srsQueueDe = { data: { srsQueue: [/* SrsCardDto[] */] } }
export const categories = { data: { categories: [/* CategoryDto[] */] } }
export const dailyPickDe = { data: { dailyPick: {/* DailyPickDto */} } }
export const activityHeatmap = { data: { activityHeatmap: [/* HeatmapDay[] */] } }
```

`e2e/mocks/handlers.ts` — диспетчер по `operationName`:
```ts
import type { Page } from '@playwright/test'
export async function mockGraphql(page: Page, overrides: Record<string, unknown> = {}) {
  await page.route('**/graphql', async (route) => {
    const body = route.request().postDataJSON() as { operationName?: string }
    const map: Record<string, unknown> = { Me: meGuest, SrsQueue: srsQueueDe,
      Categories: categories, DailyPick: dailyPickDe, ActivityHeatmap: activityHeatmap, ...overrides }
    const payload = map[body.operationName ?? ''] ?? { data: {} }
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(payload) })
  })
}
```

`e2e/mocks/rest-auth.ts` — REST `/auth/*`:
```ts
export async function mockAuth(page: Page, opts: { authed: boolean } = { authed: false }) {
  await page.route('**/auth/login', (r) => r.fulfill({ status: 200, contentType: 'application/json',
    body: JSON.stringify({ user: meAuthed.data.me, accessToken: 'fake.jwt.token' }) }))
  await page.route('**/auth/refresh', (r) => opts.authed
    ? r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ accessToken: 'fake.jwt.token' }) })
    : r.fulfill({ status: 401, body: '' }))
  await page.route('**/auth/logout', (r) => r.fulfill({ status: 200, body: '' }))
}
```

### Authed-состояние (без storageState)

accessToken — **в памяти** (Epic 02 #7), поэтому storageState бесполезен. Authed достигается мокam:
`mockAuth(page, { authed: true })` → на старте приложение дёргает `/auth/refresh` → получает токен →
`me` возвращает юзера. Demo-guest: `refresh` → 401, `me` → null.

### Fixtures

`e2e/fixtures/test.ts` — расширенный `test`:
```ts
import { test as base, expect } from '@playwright/test'
export const test = base.extend<{ mockedGuest: void; mockedAuthed: void }>({
  mockedGuest: [async ({ page }, use) => {
    await mockAuth(page, { authed: false }); await mockGraphql(page, { Me: meGuest }); await use()
  }, { auto: false }],
  mockedAuthed: [async ({ page }, use) => {
    await mockAuth(page, { authed: true }); await mockGraphql(page, { Me: meAuthed }); await use()
  }, { auto: false }],
})
export { expect }
```
+ авто-очистка localStorage (`wl_user`/`wl_uiLocale`/`wl_theme`) через `page.addInitScript` или `context`.

### Page Objects

`e2e/pages/` — `dashboard.page.ts`, `header.page.ts`, `auth-modal.page.ts`, `deck-builder.page.ts`.
Методы на role-локаторах, напр.:
```ts
export class HeaderNav {
  constructor(private page: Page) {}
  loginButton = () => this.page.getByRole('button', { name: 'Войти' })
  themeToggle = () => this.page.getByRole('button', { name: /тема|theme/i })
  uiLocale = () => this.page.getByRole('button', { name: /язык интерфейса|ru|en|de/i })
}
```

**Критерии:**
- [ ] Спек может вызвать `mockedAuthed`/`mockedGuest` и получить детерминированный экран
- [ ] localStorage чистится между тестами
- [ ] Все локаторы — role/label/text, без CSS-классов

---

## T3 · Golden-path спеки

**OUT:** `e2e/*.spec.ts`. Каждый — на mock-фикстурах, прогон на всех проектах (mobile-набор — подмножество).

| Файл | Сценарий | Ключевые проверки |
|---|---|---|
| `demo-guest.spec.ts` | первый визит, нет `wl_user` | виден DemoBanner («Демо-режим»), mock-дашборд, кнопка «Войти» |
| `auth.spec.ts` | login через модалку (`mockedAuthed`) | модалка → «Загрузить мой словарь» → баннер исчез, профиль в хедере; logout → demo |
| `persistence.spec.ts` | reload после login | `refresh` мок → сессия восстановлена, остаётся authed |
| `i18n.spec.ts` | переключение UI-локали ru→en→de | подписи nav/hero меняются; `wl_uiLocale` сохранён |
| `learning-lang.spec.ts` | смена языка обучения | меняются SRS-карточки и текст анализатора |
| `theme.spec.ts` | light→dark→system | класс `dark` на `<html>` появляется/исчезает; `wl_theme` сохранён |
| `flashcard.spec.ts` | SRS | клик по карте → flip (видна обратная сторона); кнопка «Хорошо» → следующая карта, счётчик растёт |
| `text-to-deck.spec.ts` | анализатор → колода | вставить текст → «Обработать текст» → выбрать слова → «Создать колоду» → `/dictionaries/new`, карточки на месте |
| `pwa.spec.ts` | PWA (Q4) | `/manifest.json` 200 + валидные поля; `display-mode: standalone` определяется; SW не ломает навигацию |
| `mobile.spec.ts` | адаптив (Q4) | флоу demo-guest + login на проектах `iphone-14`/`pixel-7`, ничего не обрезано/перекрыто |

**Принципы (см. T4):** web-first assertions (`await expect(locator).toBeVisible()`), без `waitForTimeout`;
анимации (flip/модалки) — ждём конечное состояние; сеть — только моки.

**Критерии:**
- [ ] Все спеки зелёные локально на desktop + mobile
- [ ] Нет `waitForTimeout`, нет хардкод-задержек

---

## T4 · Best-practices → CLAUDE.md

**IN:** `frontend/CLAUDE.md`
**OUT:** новый раздел «## Testing (Playwright)»

**Содержание (что записать):**
- **Локаторы:** `getByRole`/`getByLabel`/`getByText`; `data-testid` — только когда нет семантики
  (тогда `getByTestId`). Запрет CSS/XPath-селекторов по классам.
- **Assertions:** web-first (`await expect(...).toBeVisible()`) — авто-ожидание. **Запрет `waitForTimeout`**.
- **Изоляция:** чистый контекст и localStorage на каждый тест; не зависеть от порядка/других тестов.
- **Сеть:** мок через `page.route()`; реальный бэк не дёргаем (см. deploy-эпик для smoke).
- **Auth:** токен в памяти → не storageState, а мок `/auth/refresh` + `me` (фикстуры `mockedAuthed`).
- **Структура:** Page Object Model (`e2e/pages/`), fixtures (`e2e/fixtures/`), моки (`e2e/mocks/`). Имена `*.spec.ts`.
- **Что НЕ тестировать E2E:** чистую логику (юнит на критпуть), сторонние либы, стили.
- **Запуск:** `yarn e2e`, `yarn e2e:ui`, trace-viewer при падении; визуальные — отдельно (T6).

**Критерии:**
- [ ] Раздел в стиле существующих правил `frontend/CLAUDE.md`, со ссылками на `e2e/`

---

## T5 · ESLint продакшен-режим

**Контекст:** правила фронта уже зеркалят бек (`recommendedTypeChecked` + `stylisticTypeChecked`,
`no-explicit-any: error`, …). Меняем **режим запуска** + добавляем override для тестов.

**IN:** `frontend/package.json`, `frontend/eslint.config.mjs`
**OUT:** строгие lint-скрипты + override-блок

**Шаги:**
- `package.json`:
  ```json
  "lint": "eslint . --max-warnings 0",
  "lint:fix": "eslint . --fix"
  ```
- `eslint.config.mjs` — override для тестов (как `*.spec.ts` на беке):
  ```js
  {
    files: ["e2e/**", "**/*.spec.ts"],
    rules: {
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/unbound-method": "off",
    },
  }
  ```
- Убедиться, что `e2e/**` попадает под typed-lint (`projectService: true` уже включён) и не в `globalIgnores`.
- Pre-commit: локально `lint:fix`, в гейте — строгий `lint`.

**Критерии:**
- [ ] `yarn lint` падает при любом warning/error
- [ ] Тестовые файлы не триггерят `any`/unsafe
- [ ] `yarn lint:fix` доступен локально

---

## T6 · Визуальный регресс

**Цель (Q3):** посмотреть инструмент. Локально, dev, **не gating**, не в CI.

**OUT:** `e2e/visual.spec.ts`, бейзлайны (в `.gitignore` — смотрим локально)

**Шаги:**
- Спек на 2-3 экранах:
  ```ts
  test('dashboard demo-guest', async ({ page }) => {
    await page.goto('/'); await expect(page).toHaveScreenshot('dashboard-guest.png', { fullPage: true })
  })
  ```
  + Deck Builder, + тёмная тема (toggle → screenshot).
- Первый прогон: `yarn e2e:update` создаёт бейзлайны; повтор — сравнение.
- Тег `@visual` или отдельный `testDir`, чтобы **не** попадал в обычный `yarn e2e`.
- `.gitignore`: `e2e/**/*-snapshots/` (бейзлайны не коммитим — это разведка).
- Заметка в `frontend/CLAUDE.md`/комментарии: что это, как обновлять, почему не в гейте.

**Критерии:**
- [ ] `npx playwright test e2e/visual.spec.ts` создаёт и сравнивает скриншоты
- [ ] Не входит в обязательный `yarn e2e`
- [ ] Вывод «стоит ли визуальный gate позже» → в Q-лог deploy-эпика

---

## Соглашения

- **Только моки** сети (`page.route()`); реальный бэк — deploy-эпик.
- **Role-based локаторы**, web-first assertions, **без `waitForTimeout`**.
- Изоляция: чистый контекст + localStorage на каждый тест.
- Authed — через мок `/auth/refresh` + `me`, не storageState (токен в памяти).
- TS в `e2e/` — строгий lint с override для тестовых правил.
- Каждая задача — отдельный коммит с тегом `[03-E2E T#]`.
- Pre-commit фронта: `lint:fix → tsc --noEmit → build` (+ `e2e` локально перед PR).

---

## Структура каталога e2e/

```
frontend/
  playwright.config.ts
  e2e/
    smoke.spec.ts
    demo-guest.spec.ts
    auth.spec.ts
    persistence.spec.ts
    i18n.spec.ts
    learning-lang.spec.ts
    theme.spec.ts
    flashcard.spec.ts
    text-to-deck.spec.ts
    pwa.spec.ts
    mobile.spec.ts
    visual.spec.ts            # T6, dev-эксперимент
    fixtures/
      test.ts                 # extended test + mockedGuest/mockedAuthed
    pages/
      dashboard.page.ts
      header.page.ts
      auth-modal.page.ts
      deck-builder.page.ts
    mocks/
      graphql.ts              # фикстуры ответов (me, srsQueue, …)
      rest-auth.ts            # /auth/* моки
      handlers.ts             # диспетчер page.route по operationName/path
    utils/
      storage.ts              # очистка/сид localStorage
```
