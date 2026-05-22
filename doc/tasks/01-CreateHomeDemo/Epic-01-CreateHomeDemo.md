# Epic 01: CreateHomeDemo — Home page demo with design system & PWA

## Оглавление

- [Summary](#summary)
- [Appetite](#appetite)
- [Problem](#problem)
- [Solution](#solution)
- [Non-goals](#non-goals)
- [Dependencies](#dependencies)
- [Shared DTOs — Frontend ↔ Backend contract](#shared-dtos--frontend--backend-contract)
- [Architecture decisions](#architecture-decisions)
- [Rabbit holes](#rabbit-holes)
- [Open questions](#open-questions)
- [Tasks](#tasks)
- [E2E acceptance](#e2e-acceptance)
- [Rollback](#rollback)

---

## Summary

Создаём полноценную Home page на основе дизайна `dictinory`-шаблона. Анонимный посетитель видит работающее приложение с данными `demo-guest`: флэшкарты, цели, тепловую карту, анализатор текста. Приложение устанавливается на телефон как PWA. После входа — переключение на данные реального пользователя через `localStorage`. Данные демо-гостя и реального пользователя соответствуют DTO-контракту бэкенда — фронтенд сразу готов к подключению API.

---

## Appetite

**Лимит:** 10 задач (TASK-0 backend + TASK-1..8 frontend)

---

## Problem

- Фронтенд — чистый `create-next-app`, нет дизайна, нет компонентов
- Анонимный посетитель видит пустую страницу — не понимает что делает приложение
- `dictinory`-шаблон и Catalyst UI kit лежат в `data/` — не интегрированы
- Нет PWA: приложение не устанавливается на телефон
- Нет DTO-контракта между фронтом и беком: mock-данные не совместимы с реальным API

---

## Solution

1. Tailwind v4 токены + шрифты из `dictinory` (Inter Tight, Instrument Serif, JetBrains Mono)
2. Catalyst UI компоненты → `src/components/ui/`
3. App layout: sticky Header + AppLayout
4. `UserContext` + `localStorage`: `demo-guest` → реальный пользователь
5. Dashboard компоненты из `dictinory/app.jsx` как Next.js RSC + Client компоненты
6. Модальные окна: Login, Register, AddWord + `DemoBanner` с CTA
7. PWA: `manifest.json`, иконки, service worker

**UX flow:**
```
Первый визит
  → UserContext.init() → нет данных в localStorage
  → Dashboard с demo-guest данными + DemoBanner ["Войти" | "Зарегистрироваться"]
  → Пользователь кликает → Modal → submit
  → localStorage.setItem('wl_user', ...) → app переключается на real user
  → Повторный визит → localStorage есть → сразу real user, без demo
```

---

## Non-goals

- [ ] Backend авторизация (JWT, OAuth) — в этом эпике mock-login в localStorage; TASK-0 seed только для dev
- [ ] Расширенные seed-данные (колоды, карточки, прогресс SRS) — после реализации соответствующих модулей
- [ ] Подключение к API — данные статичные, совместимые с DTO
- [ ] GraphQL клиент — отдельный эпик
- [ ] Offline data sync — отдельный эпик
- [ ] Другие экраны (Словарь, Тренировки, Прогресс) — только Dashboard
- [ ] Финальные иконки — placeholder
- [ ] Тёмная тема — только светлая на старте

---

## Dependencies

| Зависимость | Где | Статус |
|---|---|---|
| `@ducanh2912/next-pwa` | frontend npm | ✅ установлен |
| `@headlessui/react` | frontend npm | ❌ установить |
| `sharp` | frontend devDep | ❌ установить |
| `clsx` + `tailwind-merge` | frontend npm | ❌ установить |
| Catalyst TypeScript компоненты | `frontend/data/catalyst-ui-kit/typescript/` | ✅ |
| dictinory шаблон | `frontend/data/dictinory/` | ✅ |

---

## Shared DTOs — Frontend ↔ Backend contract

Все mock-данные во фронтенде структурированы по DTO-контракту бэкенда. При подключении API замена mock → fetch без изменений компонентов.

### UserDto
```typescript
// frontend/src/lib/dto/user.dto.ts
// Соответствует: backend/src/modules/users/dto/user-response.dto.ts (будущий)
interface UserDto {
  id: string           // UUID
  name: string
  email: string
  lang: LangCode       // 'en' | 'es' | 'de' | 'fr' | 'jp'
  level: string        // 'A1' | 'A2' | 'B1' | 'B2' | 'C1' | 'C2'
  streak: number
  xp: number
  uniqueWords: number
  masteredWords: number
  dailyGoal: number
  dailyDone: number
  weeklyGoal: number
  weeklyDone: number
  joinedAt: string     // ISO date string
}
```

### SrsCardDto
```typescript
// Соответствует: backend StudyModule — UserCardProgress + Word + WordMeaning
interface SrsCardDto {
  id: string           // UUID карточки
  word: string         // лемма
  translation: string  // перевод
  pos: string          // часть речи
  example: string      // пример предложения
  due: string          // 'сейчас' | 'сегодня' | 'завтра' | ...
  interval: string     // '7 дн' | '1 мин' | ...
  mastery: number      // 0..1
}
```

### CategoryDto
```typescript
// Соответствует: backend CategoryModule
interface CategoryDto {
  id: string
  name: string
  count: number
  mastered: number
  color: string        // oklch(...)
}
```

### DailyPickDto
```typescript
// Соответствует: backend — Word of the Day endpoint
interface DailyPickDto {
  word: string
  translation: string
  pos: string
  etymology: string
  sentence: string
}
```

### StoredUser (localStorage schema)
```typescript
// ключ: 'wl_user'
// Подмножество UserDto — сохраняется после login/register
interface StoredUser {
  id: string
  name: string
  email: string
  lang: LangCode
  level: string
  streak: number
  xp: number
  uniqueWords: number
  masteredWords: number
  dailyGoal: number
  dailyDone: number
  weeklyGoal: number
  weeklyDone: number
  joinedAt: string
}
```

---

## Architecture decisions

### RSC vs Client компоненты

**Решение:** Dashboard page — RSC (передаёт mock-данные как props). Client (`'use client'`):
- `UserProvider`, `Header`, `DashboardClient` — auth state, dropdown
- `Flashcard` — flip анимация, SRS кнопки
- `UniqueAnalyzer` — textarea, useMemo

**Почему:** SSR даёт быстрый FCP на мобиле — важно для PWA.

### UserContext — без Redux/Zustand

**Решение:** React Context + localStorage. Один `UserContext` хранит `user` + `lang`.

**Когда пересмотреть:** 3+ независимых глобальных стейта → Zustand.

### Шрифты через next/font

**Решение:** `next/font/google` — self-hosting. Шрифты попадают в SW кеш → доступны offline.

### Tailwind v4 — токены через @theme

**Решение:** Конфиг только в `globals.css` через `@theme {}`. Нет `tailwind.config.js`.

### PWA — @ducanh2912/next-pwa

**Решение:** Единственный форк с нативной поддержкой App Router. SW отключён в dev.

---

## Rabbit holes

- **Catalyst + Tailwind v4** — Catalyst под v3. Копировать только нужные компоненты, адаптировать по мере необходимости
- **`@headlessui/react` v2 + React 19** — проверить совместимость перед установкой
- **SW ломает hot reload** → `disable: process.env.NODE_ENV === 'development'`
- **`start_url` === `scope`** → оба `/`, иначе Chrome отказывает в установке
- **Apple + manifest** → нужны отдельные `<meta name="apple-mobile-web-app-*">` теги

---

## Open questions

- [ ] Q1: Название приложения — `WordLearn` или `WordsLearn`?
- [ ] Q2: `theme_color` — `#1c1917` (stone-900) или другой?
- [ ] Q3: Нижняя навигация на мобиле (bottom nav bar) — в этом эпике?
- [ ] Q4: `cleanRuLemma` в UniqueAnalyzer — оставить клиентскую логику или вынести в API?

---

## Tasks

### TASK-0 · Backend seed — demo user + dev data

**Статус:** ❌
**Блокирует:** —
**Заблокирована:** —

**IN:** `UserDto` контракт из секции [Shared DTOs](#shared-dtos--frontend--backend-contract); существующий `UsersModule`, `AuthModule`
**OUT:** `backend/src/modules/users/seed/demo-user.seed.ts`, запись в `yarn seed` скрипте

**Назначение:** при сбросе БД (`docker-compose down -v && up`) разработчик запускает `yarn seed` и получает готового демо-пользователя с реалистичными данными — тот же профиль, что видит анонимный посетитель на фронтенде.

**Данные демо-пользователя:**
```typescript
// Соответствует DEMO_GUEST в frontend/src/lib/mock-data.ts
const DEMO_USER_SEED = {
  email:    'demo@wordlearn.dev',
  password: 'demo1234',           // bcrypt-хеш при сохранении
  name:     'Demo User',
  role:     UserRole.CUSTOMER,
  // профиль (когда появится ProfileModule):
  lang:         'de',
  level:        'A2',
  streak:       4,
  xp:           1240,
  dailyGoal:    8,
  weeklyGoal:   25,
};
```

**Что сделать:**
- `demo-user.seed.ts` — функция `seedDemoUser(dataSource: DataSource): Promise<void>`
- INSERT пользователя с `ON CONFLICT (email) DO NOTHING` — идемпотентно
- Пароль хешировать через `bcrypt` (тот же путь что `AuthModule`)
- Зарегистрировать в `backend/src/database/data-loader.ts` (или аналогичном entry-point `yarn seed`)
- Добавить в `README` раздел "Dev setup": `yarn seed` после `docker-compose up`

**Критерии готовности:**
- [ ] `yarn seed` выполняется без ошибок на чистой БД
- [ ] `yarn seed` повторно — не падает, не создаёт дубль
- [ ] `SELECT email FROM users WHERE email = 'demo@wordlearn.dev'` → 1 строка
- [ ] Логин через `POST /auth/login` с `demo@wordlearn.dev` / `demo1234` → JWT токен (когда Auth подключён к фронту)

---

### TASK-1 · Tailwind v4 дизайн-токены + шрифты

**Статус:** ❌
**Блокирует:** TASK-2, TASK-3
**Заблокирована:** —

**IN:** `dictinory/index.html` (font-families, keyframes, tailwind.config)
**OUT:** `frontend/app/globals.css` с `@theme` блоком; шрифты в `layout.tsx` через `next/font/google`

**Что сделать:**
- `globals.css` → `@theme { --font-sans, --font-serif, --font-mono; @keyframes fadein/risein }`
- `layout.tsx` → заменить Geist на Inter Tight + Instrument Serif + JetBrains Mono
- Установить `clsx` + `tailwind-merge`, создать `src/lib/cx.ts`

---

### TASK-2 · Catalyst UI компоненты → src/components/ui/

**Статус:** ❌
**Блокирует:** TASK-4
**Заблокирована:** TASK-1

**IN:** `frontend/data/catalyst-ui-kit/typescript/` — Button, Badge, Input, Dropdown, Dialog
**OUT:** `frontend/src/components/ui/button.tsx`, `badge.tsx`, `input.tsx`, `dropdown.tsx`, `dialog.tsx`

**Что сделать:**
- Установить `@headlessui/react` (проверить React 19 совместимость)
- Скопировать только 5 компонентов используемых в dictinory
- Адаптировать импорты под Tailwind v4

---

### TASK-3 · Примитивы из dictinory/catalyst.jsx

**Статус:** ❌
**Блокирует:** TASK-4
**Заблокирована:** TASK-1

**IN:** `frontend/data/dictinory/catalyst.jsx` — Card, Icon, Heading, Modal, Field, IconButton
**OUT:** `frontend/src/components/ui/card.tsx`, `icon.tsx`, `modal.tsx`, `field.tsx`, `icon-button.tsx`

**Что сделать:**
- Перенести примитивы, типизировать
- `Icon` — инлайн SVG (search, plus, bell, flame, arrow, check, lock, target, refresh, chev)

---

### TASK-4 · App layout — Header + AppLayout

**Статус:** ❌
**Блокирует:** TASK-4b
**Заблокирована:** TASK-2, TASK-3

**IN:** `Header` из `dictinory/app.jsx`
**OUT:** `frontend/src/components/layout/header.tsx` (`'use client'`), `app-layout.tsx`

**Что сделать:**
- Sticky header: логотип, nav (Dashboard активен, остальные disabled), поиск, LangSwitch, StreakChip, кнопка "Добавить"
- Мобильная версия: скрыть nav, оставить лого + кнопки
- `AppLayout` с max-w-[1440px] grid

---

### TASK-4b · UserContext + localStorage

**Статус:** ❌
**Блокирует:** TASK-5, TASK-6, TASK-7
**Заблокирована:** TASK-3

**IN:** DTO-контракт из секции [Shared DTOs](#shared-dtos--frontend--backend-contract)
**OUT:** `frontend/src/lib/user-context.tsx`, `use-user.ts`, `mock-data.ts`, `dto/` типы

**Что сделать:**
- `frontend/src/lib/dto/` — TypeScript интерфейсы: `UserDto`, `SrsCardDto`, `CategoryDto`, `DailyPickDto`, `StoredUser`
- `mock-data.ts` — `DEMO_GUEST` (UserDto, authed: false), SRS_WORDS, CATEGORIES, DAILY_PICK из `data.js`, типизировать
- `UserContext` — `user`, `lang`, `login(StoredUser)`, `logout()`, `setLang()`
- `UserProvider` — `useEffect` на mount: `localStorage.getItem('wl_user')` → authed user или DEMO_GUEST
- `useUser()` — хук

**Критерии готовности:**
- [ ] Первый визит → `user.authed === false`
- [ ] После `login()` → localStorage содержит данные, `user.authed === true`
- [ ] Перезагрузка → пользователь остаётся залогиненным
- [ ] `logout()` → localStorage очищен, возврат к DEMO_GUEST

---

### TASK-5 · Dashboard RSC компоненты

**Статус:** ❌
**Блокирует:** TASK-6
**Заблокирована:** TASK-3, TASK-4

**IN:** `dictinory/app.jsx` компоненты, типы из TASK-4b
**OUT:** `frontend/src/components/dashboard/hero.tsx`, `goals.tsx`, `heatmap.tsx`, `categories.tsx`, `word-of-day.tsx`, `achievements.tsx`, `topic-packs.tsx`

**Что сделать:**
- Перенести компоненты без state как RSC, типизировать через DTO
- Hero — RSC, принимает `UserDto` + `LangCode` как props
- Все компоненты принимают типизированные props, без глобального APP_DATA

---

### TASK-6 · Flashcard + UniqueAnalyzer (Client)

**Статус:** ❌
**Блокирует:** TASK-7
**Заблокирована:** TASK-5

**IN:** `Flashcard`, `UniqueAnalyzer` из `dictinory/app.jsx`, `SrsCardDto`
**OUT:** `frontend/src/components/dashboard/flashcard.tsx` и `unique-analyzer.tsx` с `'use client'`

**Что сделать:**
- `Flashcard`: flip CSS `[perspective]` + `[transform-style:preserve-3d]`, SRS кнопки
- `UniqueAnalyzer`: textarea + `useMemo` анализ, добавление слов (для authed) или CTA (для demo)
- Props типизированы через `SrsCardDto[]`

---

### TASK-7 · Dashboard page + demo-guest flow + модалки

**Статус:** ❌
**Блокирует:** TASK-8
**Заблокирована:** TASK-5, TASK-6, TASK-4b

**IN:** все компоненты выше + `UserContext`
**OUT:** обновлённый `frontend/app/page.tsx`, `demo-banner.tsx`, `login-modal.tsx`, `register-modal.tsx`, `add-word-modal.tsx`

**Что сделать:**
- `page.tsx` — RSC: `UserProvider` + grid (main left + right sidebar)
- `DashboardClient` — `'use client'`: читает `useUser()`, передаёт user во все компоненты, Toast
- `DemoBanner` — если `!user.authed`: оранжевая плашка с CTA "Войти" + "Зарегистрироваться"
- `LoginModal` — email + пароль → `login(userData)` (mock, без API)
- `RegisterModal` — имя + email + lang + пароль → `login(newUser)`
- `AddWordModal` — для authed; для demo-guest → показывает CTA войти

---

### TASK-8 · PWA — manifest, иконки, service worker

**Статус:** ❌
**Блокирует:** —
**Заблокирована:** TASK-7

**IN:** готовое приложение из TASK-7
**OUT:** `frontend/public/manifest.json`, `public/icons/`, обновлённый `frontend/next.config.ts`

**Что сделать:**
- Установить `sharp` devDep, написать `scripts/generate-icons.ts` → 192×192, 512×512, 180×180
- `public/manifest.json`: `display: standalone`, `theme_color`, `start_url: /`
- `next.config.ts` → `withPWA({ dest: 'public', disable: dev })`
- `layout.tsx` → `metadata`: `manifest`, `themeColor`, `appleWebApp`
- `public/sw.js` + `public/workbox-*.js` → `.gitignore`

**Критерии готовности:**
- [ ] `yarn build` успешен, `sw.js` сгенерирован
- [ ] Chrome DevTools → Application → Manifest: нет ошибок installability
- [ ] Lighthouse PWA score ≥ 90

---

## E2E acceptance

```bash
# 1. Dev — визуальная проверка
cd frontend && yarn dev
# http://localhost:4200
# Ожидание: Dashboard как dictinory шаблон, DemoBanner сверху

# 2. Demo-guest flow
# Открыть приватное окно → нет localStorage
# Ожидание: user.authed = false, показаны демо-данные

# 3. Login flow
# Нажать "Войти" → заполнить форму → submit
# Ожидание: DemoBanner исчез, header показывает имя пользователя
# localStorage['wl_us er'] содержит данные

# 4. Перезагрузка
# Ожидание: пользователь остался залогиненным

# 5. PWA (prod build)
yarn build && yarn start
# Открыть на телефоне → Chrome предлагает установку
# Ожидание: standalone режим, иконка на рабочем столе

# 6. Lighthouse (DevTools → Lighthouse → PWA)
# Ожидание: PWA ≥ 90, Performance ≥ 75
```

**Done когда:** Dashboard визуально соответствует `dictinory`-шаблону, demo-guest → auth flow работает, приложение устанавливается на Android/iOS.

---

## Rollback

1. `git revert` коммитов эпика (каждый таск — отдельный коммит)
2. `frontend/src/components/`, `frontend/src/lib/` — удалить
3. `frontend/next.config.ts` — убрать `withPWA`
4. `frontend/public/manifest.json`, `public/icons/` — удалить
5. Восстановить `app/page.tsx`, `app/layout.tsx` из git
