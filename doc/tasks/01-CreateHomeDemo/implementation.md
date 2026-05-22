# Epic 01: CreateHomeDemo — план реализации

Детальный план (второй уровень) по эпику [Epic-01-CreateHomeDemo](Epic-01-CreateHomeDemo.md).
Задачи разбиты **по элементам Home page**. Цель: максимальное использование **Catalyst UI kit**
с адаптацией под Next.js 16 (`next/link`, `next/image`), перетема в **stone/orange**,
заложенный с самого начала слой **переводов (i18n + translate-сервис)**.

---

## Принятые решения (из обсуждения)

| # | Вопрос | Решение |
|---|---|---|
| 1 | Глубина интеграции Catalyst | **Полная замена** — реальный Catalyst kit в `src/components/ui/`, кастомные компоненты удаляются |
| 2 | Цветовая схема | **Перетема в stone/orange** под бренд dictinory |
| 3 | Изображения | **Иконки/градиенты**; `Avatar` адаптируется под `next/image` для будущих фото |
| 4 | Функциональность | **Визуал + локальная интерактивность + базовый роутинг** (deck → детальная, поиск, nav-страницы) |
| 5 | Переводы | **Заложить с самого начала**: UI-i18n (`useT`) + сервисы `TranslationService` и `TextProcessingService` (stub → API позже) |
| 6 | Тема | **Переключатель light/dark/system**, дефолт **`system`**, persist в `localStorage`, `ThemeProvider` |
| 7 | UI-локали | `ru` \| `en` \| `de` (Q2: +de) |
| 8 | Обработка текста | Реальный флоу: текст → бек → парсер (леммы) → Nest (поиск в БД, known-проверка, формы, перевод) → фронт → выбор слов → **создание карточек и колоды на отдельной странице** (Q3) |
| 9 | `Card` | Кастомный, **на основе `/data/dictinory/`** (catalyst.jsx `Card` + styles.css) — у Catalyst нет аналога |
| 10 | Поиск (E14) | **`Combobox`** с автодополнением по mock-словам |
| 11 | Регистрация (E13) | **`Select` языка обучения** в форме регистрации |
| 12 | Аутентификация | email-mock + регистрация + **Google Sign-In** через `AuthService` (mock сейчас, верификация на беке позже) |

---

## Статус задач

| Задача | Тип | Статус | Коммит |
|---|---|---|---|
| F1 · Интеграция Catalyst kit (deps, copy, тема, Link/Avatar) | foundation | ✅ | — |
| F2 · i18n + TranslationService + TextProcessingService | foundation | ✅ | — |
| F3 · App shell (StackedLayout) + роутинг + ThemeProvider | foundation | ✅ | — |
| F4 · Auth (mock + регистрация + Google Sign-In) | foundation | ✅ | — |
| E1 · Navbar / Header | element | ✅ | — |
| E2 · DemoBanner | element | ✅ | — |
| E3 · Hero (баннер статистики) | element | ✅ | — |
| E4 · Dictionaries (сетка словарей) + deck detail route | element | ✅ | — |
| E5 · UniqueAnalyzer (обработка текста → леммы/перевод) | element | ✅ | — |
| E15 · Deck Builder (создание карточек и колоды, отдельная страница) | element | ✅ | — |
| E6 · Flashcard (SRS) | element | ✅ | — |
| E7 · Goals (цели) | element | ✅ | — |
| E8 · Heatmap (активность) | element | ✅ | — |
| E9 · WordOfDay (слово дня) | element | ✅ | — |
| E10 · Achievements (достижения) | element | ✅ | — |
| E11 · TopicPacks (тематические наборы) | element | ✅ | — |
| E12 · Footer | element | ✅ | — |
| E13 · Modals (Login / Register / AddWord) | element | ✅ | — |
| E14 · Search + nav stub pages | element | ✅ | — |

**Порядок выполнения:** F1 → F2 → F3 → F4 → E1 → E2 → E3 → E13 → E4 → E5 → E15 → E6 → E7 → E8 → E9 → E10 → E11 → E12 → E14

**Вне этого плана:** TASK-0 (backend seed демо-юзера) и TASK-8 (PWA) из эпика — отдельные проходы.

---

## Консольные команды

Все команды выполняются из корня репозитория, если не указано иное.

### Окружение (один раз)

```bash
# убедиться, что контейнеры запущены
docker compose up -d frontend

# войти в контейнер фронтенда (для yarn-команд)
docker exec -it anki-frontend sh
```

### F1 · Catalyst — зависимости и копирование

```bash
# из контейнера (или: docker exec anki-frontend yarn add ...)
cd /app
yarn add @headlessui/react@^2.2 @heroicons/react@^2.2

# копирование всех Catalyst-компонентов (на хосте, из корня репо)
cp frontend/data/catalyst-ui-kit/typescript/*.tsx frontend/src/components/ui/

# глобальная замена zinc → stone в скопированных компонентах
find frontend/src/components/ui -name '*.tsx' \
  -exec sed -i 's/zinc-/stone-/g' {} +

# замена акцента blue → orange (focus-ring, outline)
find frontend/src/components/ui -name '*.tsx' \
  -exec sed -i 's/blue-500/orange-600/g; s/blue-600/orange-600/g' {} +
```

### F4 · Auth — зависимости и env

```bash
# из контейнера
yarn add @react-oauth/google

# на хосте: создать .env.local (если нет)
echo "NEXT_PUBLIC_GOOGLE_CLIENT_ID=" >> frontend/.env.local
# заполнить реальным Client ID или оставить пустым для mock-режима
```

### Pre-commit gate (перед каждым коммитом)

```bash
# в контейнере
yarn lint            # ESLint
npx tsc --noEmit     # TypeScript
yarn build           # Next.js production build
```

### Быстрая проверка типов во время разработки

```bash
# запустить в отдельном терминале внутри контейнера
npx tsc --noEmit --watch
```

### Перезапуск контейнера (сброс кэша .next)

```bash
# если Turbopack подхватывает старую версию — рестарт очищает .next
docker restart anki-frontend
docker logs -f anki-frontend   # следить за запуском
```

### Отладка зависимостей в контейнере

```bash
# убедиться, что пакет установлен внутри контейнера
docker exec anki-frontend yarn list --pattern "@headlessui/react"
docker exec anki-frontend yarn list --pattern "@heroicons/react"
docker exec anki-frontend yarn list --pattern "@react-oauth/google"
```

### Структура файлов — создать директории

```bash
mkdir -p frontend/src/lib/i18n/messages
mkdir -p frontend/src/lib/translation
mkdir -p frontend/src/lib/auth
mkdir -p frontend/src/lib/theme
mkdir -p frontend/src/lib/deck-builder
mkdir -p "frontend/app/(app)/dictionaries/[id]"
mkdir -p "frontend/app/(app)/dictionaries/new"
mkdir -p frontend/app/(app)/training
mkdir -p frontend/app/(app)/progress
```

---

## Оглавление

- [F1 · Интеграция Catalyst kit](#f1--интеграция-catalyst-kit)
- [F2 · i18n + TranslationService + TextProcessingService](#f2--i18n--translationservice--textprocessingservice)
- [F3 · App shell + роутинг](#f3--app-shell--роутинг)
- [F4 · Auth (mock + Google)](#f4--auth-mock--google)
- [E1 · Navbar / Header](#e1--navbar--header)
- [E2 · DemoBanner](#e2--demobanner)
- [E3 · Hero](#e3--hero)
- [E4 · Dictionaries + deck detail](#e4--dictionaries--deck-detail)
- [E5 · UniqueAnalyzer](#e5--uniqueanalyzer)
- [E15 · Deck Builder](#e15--deck-builder)
- [E6 · Flashcard](#e6--flashcard)
- [E7 · Goals](#e7--goals)
- [E8 · Heatmap](#e8--heatmap)
- [E9 · WordOfDay](#e9--wordofday)
- [E10 · Achievements](#e10--achievements)
- [E11 · TopicPacks](#e11--topicpacks)
- [E12 · Footer](#e12--footer)
- [E13 · Modals](#e13--modals)
- [E14 · Search + nav pages](#e14--search--nav-pages)
- [Соглашения](#соглашения)
- [Открытые вопросы](#открытые-вопросы)

---

## F1 · Интеграция Catalyst kit

**Цель:** заменить кастомные `src/components/ui/*` на реальные компоненты Catalyst,
перетемизировать под stone/orange, адаптировать под Next.js.

**IN:** `frontend/data/catalyst-ui-kit/typescript/*.tsx` (27 компонентов)
**OUT:** `frontend/src/components/ui/*.tsx` (реальный Catalyst), обновлённый `globals.css`

### Шаги

1. **Зависимости:**
   ```
   yarn add @headlessui/react@^2.2 @heroicons/react@^2.2
   ```
   `@headlessui/react` ≥ 2.2 — поддержка React 19 (закрывает rabbit hole из эпика).
   Проверить: `Dialog`, `Menu`, `Listbox`, `Combobox` рендерятся без warning в React 19.

2. **Копирование компонентов** из `data/catalyst-ui-kit/typescript/` → `src/components/ui/`.
   Используемый набор (остальные копируем, но используем по мере надобности):

   | Catalyst | Применение в Home |
   |---|---|
   | `button` | везде (CTA, SRS-кнопки) |
   | `badge` | POS-теги, уровни CEFR, счётчики due |
   | `input`, `textarea` | поиск, анализатор, формы |
   | `fieldset` (Field/Label/…) | формы в модалках |
   | `dialog` | Login/Register/AddWord |
   | `dropdown` | меню юзера, переключатель языка обучения |
   | `listbox` | переключатель UI-локали |
   | `navbar`, `stacked-layout` | header + app shell |
   | `avatar` | аватар юзера (next/image-ready) |
   | `heading`, `text`, `divider` | заголовки, текст, разделители |
   | `link` | все ссылки (next/link) |
   | `table`, `pagination` | список слов в deck detail |
   | `description-list` | этимология/метаданные |

3. **Адаптация `link.tsx` под Next.js** (критично — там стоит TODO):
   ```tsx
   import * as Headless from '@headlessui/react'
   import NextLink, { type LinkProps } from 'next/link'
   import React, { forwardRef } from 'react'

   export const Link = forwardRef(function Link(
     props: LinkProps & React.ComponentPropsWithoutRef<'a'>,
     ref: React.ForwardedRef<HTMLAnchorElement>
   ) {
     return (
       <Headless.DataInteractive>
         <NextLink {...props} ref={ref} />
       </Headless.DataInteractive>
     )
   })
   ```

4. **Адаптация `avatar.tsx` под next/image** (решение #3 — фото пока нет, но закладываем):
   - Текущий `<img className="size-full" src={src} alt={alt} />`.
   - Завести вариант: если `src` задан → `next/image` (`fill`, `sizes="40px"`), иначе fallback на инициалы (градиент) как сейчас.
   - На Home аватар всегда инициалы → реально рендерится градиент; путь с `next/image` готов к подключению фото.

5. **Перетема в stone/orange** (решение #2). Catalyst по умолчанию zinc + blue.
   - В скопированных компонентах глобально заменить нейтраль `zinc` → `stone`
     (find/replace по `src/components/ui/`: `zinc-` → `stone-`).
   - Акцент/фокус: `blue-500`/`blue-600` → `orange-600` (focus ring, outline).
   - `button.tsx`: в map `colors` добавить ключи `orange` (solid CTA) и `stone`;
     в `outline`/`plain` нейтраль уже стала stone после замены.
   - `badge.tsx`: добавить `orange`, `stone`, `amber`, `emerald`, `red` (под текущие бейджи).
   - `globals.css`: токены `@theme` (шрифты уже есть) + переменные фокуса, если используются.

6. **Удаление кастомных компонентов** после миграции импортов:
   `card.tsx`, `icon-button.tsx`, `modal.tsx`, `toast.tsx`, `field.tsx`, `heading.tsx`
   — заменяются на Catalyst-эквиваленты, где они есть.
   - `Card` (решение #9) — у Catalyst нет «карточки» → кастомный `card.tsx` **на основе `/data/dictinory/`**:
     взять `Card`/`CardHeader` из `data/dictinory/catalyst.jsx` и стили скруглений/теней из `data/dictinory/styles.css`,
     типизировать, перетемизировать под stone/orange. Единственный осознанный кастом вне Catalyst.
   - `icon.tsx` — оставляем (инлайн-SVG, решение #3); по возможности заменяем на `@heroicons` где иконка совпадает.
   - `modal.tsx` → Catalyst `dialog`; `toast.tsx` — нет в Catalyst → оставляем кастомный.

**Критерии готовности:**
- [ ] `yarn add` без peer-warning по React 19
- [ ] `npx tsc --noEmit` чисто после копирования и замены импортов
- [ ] `yarn build` проходит
- [ ] Кнопки/бейджи/инпуты визуально в stone/orange, не zinc/blue

---

## F2 · i18n + TranslationService + TextProcessingService

**Цель (новое требование):** заложить слой переводов и обработки текста с самого начала, чтобы
UI-строки не были захардкожены, и чтобы были abstraction-point'ы для перевода и анализа текста
через API позже (бек → парсер → БД).

**Два независимых, отдельно переключаемых языка (подтверждено пользователем):**
- **UI-локаль** (`uiLocale`) — язык интерфейса (`ru` | `en`). Свой переключатель в navbar (`Listbox`, E1).
  Хранится в `localStorage['wl_uiLocale']`.
- **Язык обучения** (`lang`: en/es/de/fr/jp) — в `UserContext`, меняет контент карточек.
  Свой переключатель в navbar (`Dropdown`, E1).

Оба переключателя — first-class элементы хедера и работают независимо: смена UI-локали не трогает
язык обучения и наоборот.

**OUT:**
- `src/lib/i18n/messages/{ru,en,de}.ts` — словари UI-строк (Q2: три локали)
- `src/lib/i18n/index.ts` — типы `Messages`, `UiLocale = 'ru' | 'en' | 'de'`
- `src/lib/i18n/locale-context.tsx` — `LocaleProvider` + `useT()`
- `src/lib/translation/translation-service.ts` — `TranslationService` (stub)
- `src/lib/translation/text-processing-service.ts` — `TextProcessingService` (stub)
- `src/lib/translation/use-translation.ts` — хуки `useTranslate()`, `useProcessText()`

### i18n (UI-строки)

- Плоский словарь по неймспейсам: `nav.dashboard`, `header.add`, `hero.guestTitle`, `srs.again`, …
- `messages/ru.ts` — заполнить из текущих строк компонентов (источник истины — то, что уже на экране).
- `messages/en.ts` — английские эквиваленты.
- `LocaleProvider`:
  - `uiLocale` (`ru` | `en` | `de`, default `ru`), persist в `localStorage['wl_uiLocale']`;
  - `t(key, params?)` — берёт строку из активного словаря, подставляет `{n}`-параметры;
  - `setUiLocale(locale)`.
- `useT()` → `{ t, uiLocale, setUiLocale }`.
- Подключить `LocaleProvider` рядом с `UserProvider` (тот же клиентский корень, см. F3).
- **Все** UI-строки в element-тасках идут через `t('...')` — не хардкодить.

### TranslationService (перевод контента)

Абстракция «перевести слово/текст» — заглушка сейчас, реальный провайдер (API парсера/словаря) позже.

```ts
export interface TranslateRequest {
  text: string
  from: LangCode      // язык обучения
  to: UiLocale        // язык пользователя
}
export interface TranslateResult {
  text: string
  translation: string
  source: 'mock' | 'api'
}
export interface TranslationService {
  translate(req: TranslateRequest): Promise<TranslateResult>
}
```

- `MockTranslationService` — ищет в `mock-data` (KNOWN/SRS) или возвращает плейсхолдер `«…»`.
- `useTranslate()` — оборачивает вызов, отдаёт `{ translate, pending }`.
- Точки подключения: `AddWordModal` (автоперевод по вводу слова), `WordOfDay` (кнопка «перевести»).

### TextProcessingService (обработка текста → леммы, Q3)

Главный сервис анализатора (E5). Реальный флоу (заложить интерфейс под него, сейчас mock):

```
текст → POST /text/process (Nest)
      → parser извлекает леммы каждого слова
      → Nest ищет леммы в БД, проверяет, есть ли слово уже у юзера (known)
      → собирает: { lemma, forms[], pos, translation, known }
      → фронт: юзер выбирает слова → создаёт карточки → колоду (E15)
```

```ts
export interface ProcessTextRequest {
  text: string
  lang: LangCode          // язык обучения
  uiLocale: UiLocale      // для языка перевода
}
export interface ProcessedWord {
  lemma: string           // базовая форма
  forms: string[]         // словоформы из текста
  pos: string             // часть речи
  translation: string     // перевод на uiLocale
  known: boolean          // уже в словаре юзера
  freq: number            // частота в тексте
}
export interface TextProcessingService {
  processText(req: ProcessTextRequest): Promise<ProcessedWord[]>
}
```

- `MockTextProcessingService` — повторяет текущую клиентскую лемматизацию + `KNOWN_WORDS` +
  переводы из `SRS_WORDS`, чтобы вернуть реалистичный ответ. Позже — HTTP-вызов в Nest `/text/process`
  (который дергает парсер LexBuild). Контракт ответа уже совпадает с будущим API.
- `useProcessText()` → `{ process, pending, result }`.

**Критерии готовности:**
- [ ] Переключение `uiLocale` (ru/en/de) меняет видимые строки header/hero
- [ ] `uiLocale` сохраняется после перезагрузки
- [ ] `useTranslate().translate(...)` возвращает результат от mock-сервиса
- [ ] `useProcessText().process(text, lang)` возвращает `ProcessedWord[]` (леммы, формы, перевод, known)
- [ ] Нет захардкоженных строк в element-компонентах (всё через `t`)

---

## F3 · App shell + роутинг

**Цель:** каркас приложения на Catalyst `StackedLayout` (верхний navbar) + скелет роутов App Router.

**OUT:**
- `app/layout.tsx` — шрифты, metadata, `suppressHydrationWarning` на `<html>` (для темы)
- `app/providers.tsx` — `'use client'`: `ThemeProvider` → `LocaleProvider` → `UserProvider`
- `src/lib/theme/theme-context.tsx` — `ThemeProvider` + `useTheme()` (light/dark/system)
- `app/(app)/layout.tsx` — `StackedLayout` (navbar + мобильный sidebar)
- `app/(app)/page.tsx` — Dashboard (Home)
- `app/(app)/dictionaries/page.tsx` — список словарей (stub)
- `app/(app)/dictionaries/[id]/page.tsx` — детальная словаря (E4)
- `app/(app)/training/page.tsx`, `app/(app)/progress/page.tsx` — stub-страницы (E14)

### Решения по архитектуре

- **Провайдеры — в одном клиентском поддереве.** Урок из прошлого прохода: контекст не проходит
  через RSC-границу, если провайдер в `layout.tsx` (RSC), а потребитель — в `page.tsx`.
  → Все провайдеры (`ThemeProvider`, `LocaleProvider`, `UserProvider`) монтируются в клиентском
  компоненте `app/providers.tsx` (`'use client'`), который оборачивает `{children}` в `app/layout.tsx`.
- **Тема (решение #6):** `ThemeProvider` хранит `theme: 'light'|'dark'|'system'` в
  `localStorage['wl_theme']`, **дефолт `system`** (следует `prefers-color-scheme`), ставит/снимает
  класс `dark` на `<html>`. Anti-FOUC: инлайн-скрипт в `<head>` (`app/layout.tsx`) применяет тему
  до гидратации; `<html suppressHydrationWarning>`. Слушать `matchMedia('(prefers-color-scheme: dark)')`
  пока выбран `system`. Tailwind v4: `@variant dark (&:where(.dark, .dark *))` в `globals.css`.
- **StackedLayout**: `navbar={<AppNavbar/>}` + `sidebar={<AppSidebar/>}` (моб. меню) + `children`.
- Группа роутов `(app)` — общий layout с navbar для всех страниц приложения.

**Критерии готовности:**
- [ ] `/` рендерит Dashboard внутри StackedLayout, navbar сверху
- [ ] Переходы по `/dictionaries`, `/training`, `/progress` работают (client-side, без перезагрузки)
- [ ] Контекст (`useUser`, `useT`, `useTheme`) доступен на всех страницах группы `(app)`
- [ ] Тёмная/светлая тема переключается, сохраняется, без FOUC при перезагрузке

---

## F4 · Auth (mock + Google)

**Цель (решение #12):** заложить аутентификацию — email-mock (как сейчас) + регистрация +
**Google Sign-In**. Сервис-абстракция: mock сейчас, реальная верификация на беке позже.

**IN:** `useUser().login(StoredUser)`, env `NEXT_PUBLIC_GOOGLE_CLIENT_ID`
**OUT:**
- `src/lib/auth/auth-service.ts` — `AuthService` + `MockAuthService`
- `src/lib/auth/use-auth.ts` — хук `useAuth()`
- `GoogleOAuthProvider` в `app/providers.tsx`

```ts
export interface AuthCredentials {
  email: string
  password?: string
  name?: string
  lang?: LangCode
}
export interface AuthResult {
  user: StoredUser
  token?: string          // JWT с бека (позже)
}
export interface AuthService {
  loginEmail(c: AuthCredentials): Promise<AuthResult>
  register(c: AuthCredentials): Promise<AuthResult>
  loginWithGoogle(idToken: string): Promise<AuthResult>   // позже — верификация на беке
  logout(): Promise<void>
}
```

### Google Sign-In (frontend)

- Пакет `@react-oauth/google` (поддержка React 19). `GoogleOAuthProvider clientId={env}` в `app/providers.tsx`.
- Кнопка через `useGoogleLogin` / `<GoogleLogin>`: по `credentialResponse` декодировать ID-token (JWT)
  → профиль (`email`, `name`, `picture`) → собрать `StoredUser` → `useUser().login()`.
- `picture` из Google → `Avatar src` (путь `next/image` уже готов из F1; для demo всё ещё инициалы).

### Mock / fallback

- `MockAuthService`: если `NEXT_PUBLIC_GOOGLE_CLIENT_ID` не задан — кнопка Google **имитирует** успешный
  вход (фейковый Google-юзер), чтобы демо работало без реального Client ID.
- `loginEmail`/`register` — текущий mock (как в прошлом проходе), но через единый `AuthService`.

### Бек (deferred)

- Реальный флоу: фронт отправляет Google ID-token в Nest → верификация Google + выдача JWT/сессии.
  Контракт `loginWithGoogle(idToken)` уже под это. Epic Non-goal на бек-OAuth сохраняется — фронт готов к свопу.

**Зависимости:**
```bash
docker exec anki-frontend yarn add @react-oauth/google
```

**Критерии готовности:**
- [ ] Кнопка «Войти через Google» в Login и Register (E13)
- [ ] С `NEXT_PUBLIC_GOOGLE_CLIENT_ID` — реальный popup Google, профиль → `login()`
- [ ] Без env — mock-Google вход работает, демо не падает
- [ ] Email-login и регистрация идут через `AuthService` (не прямой `login()` в компоненте)

---

## E1 · Navbar / Header

**Catalyst:** `Navbar`, `NavbarSection`, `NavbarItem`, `NavbarSpacer`, `NavbarLabel`, `NavbarDivider`,
`Dropdown` (меню юзера), `Listbox` (UI-локаль), `Avatar`, `Input` (поиск), `Button`, `Badge`.
**IN:** `useUser()` (user, lang, setLang, logout), `useT()` (t, uiLocale, setUiLocale), `useTheme()`
**OUT:** `src/components/layout/app-navbar.tsx` (`'use client'`), `app-sidebar.tsx` (моб.)

**Состав:**
- Лого `WordLearn` + бейдж версии (`Badge`).
- `NavbarSection` с `NavbarItem href=...`: Дашборд (active), Словари, Тренировки, Прогресс — реальные ссылки (`next/link` через Catalyst Link).
- `NavbarSpacer`.
- Поиск (`Input`) — десктоп; на мобиле скрыт (E14 даёт логику).
- **Переключатель языка обучения** — `Dropdown` (флаг + название, меняет `setLang`).
- **Переключатель UI-локали** — `Listbox` (`ru`/`en`/`de`, меняет `setUiLocale`).
- **Переключатель темы** — `Button`-иконка (sun/moon) или `Dropdown` (light/dark/system), меняет `useTheme().setTheme`.
- StreakChip (`Badge` с иконкой flame + `user.streak`).
- Кнопка «Добавить» (`Button color="orange"`) → открывает AddWordModal (E13).
- Авторизация: `user.authed` → `Avatar` (инициалы) + `Dropdown` (профиль, выйти); иначе `Button` «Войти».

**Адаптация:** все nav-ссылки через адаптированный `Link` (next/link). Строки через `t('nav.*')`.

**Критерии:** активный пункт подсвечен по `usePathname()`; смена UI-локали мгновенно меняет подписи nav;
переключатель темы меняет light/dark.

---

## E2 · DemoBanner

**Catalyst:** `Button`/`Link`. **IN:** `useUser().authed`, `useT()`.
**OUT:** `src/components/dashboard/demo-banner.tsx`

- Показывается только при `!authed`. Тонкая оранжевая плашка над navbar.
- Пульсирующая точка + `t('demo.title')` + CTA `t('demo.cta')` → открывает Login (E13).
- Без Catalyst-карточки (это полоса), но кнопка-ссылка — Catalyst `Button variant="plain"`.

**Критерии:** при `authed` баннер отсутствует; клик CTA открывает LoginModal.

---

## E3 · Hero

**Catalyst:** `Heading`, `Text`, `Strong`, `Badge`. **IN:** `UserDto`, `LangMeta`, `useT()`.
**OUT:** `src/components/dashboard/hero.tsx`, кастомный `card.tsx` как контейнер.

- Мета-строка: дата/режим · язык обучения · уровень (`Badge`).
- Заголовок (`Heading`, сериф): гость vs `t('hero.welcomeBack', { name })`.
- Лид-текст (`Text`).
- Сетка 4 метрик: уникальные/освоено/серия/XP с дельта-бейджами (`Badge color="emerald|stone"`).
- Числа: `toLocaleString(uiLocale === 'ru' ? 'ru' : 'en')`.

**Критерии:** строки и формат чисел зависят от `uiLocale`; данные — из `user` (demo/real).

---

## E4 · Dictionaries + deck detail

**Catalyst:** `Heading`, `Badge`, `Button`, `Link`, `Table`+`Pagination` (на детальной), `Divider`.
**IN:** новый `DeckDto` (см. ниже), `useT()`. **OUT:**
- `src/lib/dto/index.ts` — добавить `DeckDto`
- `src/lib/mock-data.ts` — `DEMO_DECKS: DeckDto[]`
- `src/components/dashboard/dictionaries.tsx` — сетка карточек (заменяет Categories)
- `app/(app)/dictionaries/[id]/page.tsx` — детальная: список слов (`Table`)

```ts
export interface DeckDto {
  id: string
  name: string
  lang: LangCode
  wordCount: number
  masteredCount: number
  dueCount: number
  lastStudied: string   // ISO | человекочитаемо (mock)
  color: string         // oklch
}
```

- Карточка словаря: имя, флаг (`Badge`), 3 метрики, прогресс-бар, кнопка
  «Повторить» (`color="orange"`, если `dueCount>0`) / «Изучать» (`outline`).
- **Роутинг (решение #4):** клик по карточке/кнопке → `Link href={\`/dictionaries/${id}\`}`.
- Детальная страница: заголовок словаря + `Table` слов (слово, перевод, POS, mastery) + `Pagination` (mock).

**Критерии:** клик ведёт на `/dictionaries/[id]` без перезагрузки; детальная показывает слова deck'а.

---

## E5 · UniqueAnalyzer

**Реальный флоу (Q3):** юзер вставляет текст → жмёт **«Обработать текст»** → `useProcessText().process()`
(сейчас mock, позже бек→парсер→БД) → возвращается `ProcessedWord[]` (леммы, формы, POS, перевод, known) →
юзер отмечает нужные слова → жмёт **«Создать колоду»** → переход на Deck Builder (E15) с выбранными словами.

**Catalyst:** `Heading`, `Textarea`, `Button`, `Badge`, `Checkbox`. **IN:** `lang.code`, `authed`,
`useT()`, `useProcessText()`, `useDeckDraft()` (из E15-стора). **OUT:**
`src/components/dashboard/unique-analyzer.tsx` (`'use client'`).

- `Textarea` (Catalyst) + кнопки «Пример»/«Очистить» (`Button variant="plain"`) + **«Обработать текст»** (`Button color="orange"`).
- На обработке — `pending` (спиннер); по готовности — рендер результата из `ProcessedWord[]`:
  - 4 метрики (всего/уникальных/новых/known);
  - чипы **новых** слов с чекбоксом выбора (показывают лемму, `freq`, перевод по `uiLocale`);
  - **known**-слова — зачёркнуты, без выбора.
- Нижняя панель: счётчик выбранных + **«Создать колоду из N слов»** → кладёт выбор в `DeckDraft` (E15)
  и `router.push('/dictionaries/new')`. Для demo-guest → CTA войти (`!authed`).
- Перевод приходит уже в ответе `processText`; отдельный `useTranslate()` тут не нужен.
- Все подписи через `t('analyzer.*')`.

**Критерии:** «Обработать текст» вызывает `processText` и рендерит леммы/перевод/known; выбор слов +
«Создать колоду» переносит выбор на `/dictionaries/new`; demo-guest видит CTA.

---

## E6 · Flashcard

**Catalyst:** `Heading`, `Badge`, `Button`. **IN:** `SrsCardDto[]`, `useT()`.
**OUT:** `src/components/dashboard/flashcard.tsx` (`'use client'`).

- Flip-карта (CSS `perspective`/`preserve-3d`/`backface-visibility`) — без Catalyst-аналога, кастом.
- POS/интервал — `Badge`. SRS-кнопки (Снова/Трудно/Хорошо/Легко) — `Button` с вариантами цвета.
- Прогресс сессии — кастомный bar. Подписи через `t('srs.*')`.

**Критерии:** flip по клику; кнопки листают очередь; счётчик сессии растёт.

---

## E7 · Goals

**Catalyst:** `Heading`. **IN:** `UserDto`, `useT()`. **OUT:** `src/components/dashboard/goals.tsx`.

- Два кольца (conic-gradient) дневная/недельная цель + прогресс-бары. Контейнер — `card.tsx`.
- Проценты из `user.dailyDone/dailyGoal`, `weeklyDone/weeklyGoal`. Подписи `t('goals.*')`.

**Критерии:** проценты соответствуют данным юзера.

---

## E8 · Heatmap

**Catalyst:** `Heading`. **IN:** `number[]` (генератор), `useT()`.
**OUT:** `src/components/dashboard/heatmap.tsx`.

- Сетка 7×N (`grid-flow-col grid-rows-7`), 5 уровней интенсивности orange.
- Легенда меньше/больше, счётчик активных дней. Контейнер — `card.tsx`. Подписи `t('activity.*')`.

**Критерии:** рендерит ~119 дней; интенсивность зависит от `authed`.

---

## E9 · WordOfDay

**Catalyst:** `Button`, `DescriptionList` (этимология/POS), `Badge`. **IN:** `DailyPickDto`,
`useT()`, `useTranslate()`. **OUT:** `src/components/dashboard/word-of-day.tsx`.

- Слово (сериф) + POS/этимология (`DescriptionList`) + перевод + пример.
- Кнопки: «В словарь» (`color="orange"`) → toast; «Перевести» → `useTranslate()` (F2).
- Контейнер — `card.tsx` с градиентом. Подписи `t('wordOfDay.*')`.

**Критерии:** кнопка «перевести» вызывает TranslationService и показывает результат.

---

## E10 · Achievements

**Catalyst:** `Heading`, `Badge`, `Divider`. **IN:** `AchievementDto[]`, `useT()`.
**OUT:** `src/components/dashboard/achievements.tsx`.

- Список 6 ачивок: иконка (check/lock), имя, описание, дата/прогресс (`Badge`).
- Разделители — `Divider`. Контейнер — `card.tsx`. Подписи `t('achievements.*')`
  (имена ачивок — данные, остаются в mock; UI-обвязка — через `t`).

**Критерии:** earned/locked различимы; счётчик earned/total корректен.

---

## E11 · TopicPacks

**Catalyst:** `Heading`, `Badge`, `Button`, `Link`. **IN:** статические паки, `useT()`.
**OUT:** `src/components/dashboard/topic-packs.tsx`.

- Список наборов: уровень (`Badge`), название, количество. Кнопка/ссылка → `/dictionaries` (E14).
- Контейнер — `card.tsx`. Подписи `t('packs.*')`.

**Критерии:** клик ведёт на список словарей.

---

## E12 · Footer

**Catalyst:** `Link`, `Input`, `Button`, `Divider`. **IN:** `useT()`.
**OUT:** `src/components/layout/footer.tsx`.

- Колонки ссылок (`Link`/next/link), подписка (`Input`+`Button`), нижняя строка с локалями.
- Все ссылки/подписи через `t('footer.*')`.

**Критерии:** ссылки — клиентские; формат «build {дата}» стабилен.

---

## E13 · Modals

**Catalyst:** `Dialog`, `DialogTitle`, `DialogDescription`, `DialogBody`, `DialogActions`,
`Fieldset`/`Field`/`Label`/`Input`/`Select`, `Button`, `Divider`. **IN:** `useAuth()` (F4), `useUser()`,
`useT()`, `useTranslate()`. **OUT:**
- `src/components/dashboard/login-modal.tsx`
- `src/components/dashboard/register-modal.tsx` (новый)
- `src/components/dashboard/add-word-modal.tsx`

- Все три — на Catalyst `Dialog` (заменяет кастомный `modal.tsx`).
- **Login:** Field email/пароль → `useAuth().loginEmail()`; `Divider` «или»; **кнопка «Войти через Google»** (F4).
- **Register:** имя + email + язык обучения (`Select`, решение #11) + пароль → `useAuth().register()`;
  также **кнопка «Войти через Google»**.
- **AddWord:** слово (`Input`) + перевод; **автоперевод** через `useTranslate()` при вводе слова (F2);
  кнопка «Добавить» → toast. Для demo-guest → CTA войти.
- Подписи через `t('auth.*')`, `t('addWord.*')`.

**Критерии:** Dialog открывается/закрывается (Esc, клик вне); email-login и Google-login переключают
на real user через `AuthService`; addWord автозаполняет перевод от TranslationService.

---

## E14 · Search + nav pages

**Catalyst:** `Combobox` (поиск с автодополнением) или `Input`, `Table`, `Heading`, `Text`.
**IN:** `mock-data` (слова всех словарей), `useT()`. **OUT:**
- Логика поиска в `app-navbar.tsx` (E1)
- `app/(app)/dictionaries/page.tsx`, `training/page.tsx`, `progress/page.tsx` — наполнить stub'ы

- **Поиск (решение #4):** `Combobox` по объединённому списку слов mock-данных;
  выбор → переход на `/dictionaries/[id]` или показ карточки. Минимум — фильтр по подстроке.
- **Nav-страницы:** простые экраны-заглушки с `Heading` + `Text` «в разработке», но реальные роуты.

**Критерии:** ввод в поиск фильтрует mock-слова; nav-ссылки ведут на непустые страницы.

---

## E15 · Deck Builder

**Цель (Q3):** отдельная страница, где юзер из выбранных в анализаторе (E5) слов собирает карточки
и создаёт колоду для изучения.

**Маршрут:** `app/(app)/dictionaries/new/page.tsx`
**Catalyst:** `Heading`, `Text`, `Fieldset`/`Field`/`Label`/`Input`/`Select`, `Table` (`TableHead`/`TableBody`/`TableRow`/`TableCell`), `Textarea`, `Checkbox`, `Button`, `Badge`, `Divider`.
**IN:** `DeckDraft` (выбранные `ProcessedWord[]`), `useUser()` (lang), `useT()`. **OUT:**
- `src/lib/deck-builder/deck-draft-context.tsx` — `DeckDraftProvider` + `useDeckDraft()`
- `src/lib/dto/index.ts` — `CardDraftDto`, `DeckDraftDto`
- `app/(app)/dictionaries/new/page.tsx` — страница билдера

```ts
export interface CardDraftDto {
  lemma: string
  forms: string[]
  pos: string
  front: string         // обычно lemma (редактируемо)
  back: string          // перевод (редактируемо)
  example?: string      // редактируемо
  include: boolean      // включать ли в колоду
}
export interface DeckDraftDto {
  name: string
  lang: LangCode
  cards: CardDraftDto[]
}
```

**Передача данных E5 → E15:** `DeckDraftProvider` в `app/providers.tsx` (тот же клиентский корень).
Анализатор кладёт выбор через `useDeckDraft().setFromProcessed(words)`; черновик persist в
`sessionStorage['wl_deck_draft']` (переживает навигацию/перезагрузку). Билдер читает `useDeckDraft()`.

**Экран билдера:**
- Заголовок `t('deck.title')` + `Text` подсказка.
- `Fieldset`: имя колоды (`Input`), язык (`Select`, префилл из `user.lang`).
- `Table` карточек: чекбокс `include`, лемма+формы (`Badge`), редактируемые `front`/`back`/`example` (`Input`/`Textarea`), POS.
- Действия (`DialogActions`-стиль внизу): «Отмена» (`outline`) → назад; «Создать колоду» (`color="orange"`).
- Создание: mock — добавить `DeckDto` в стор/`localStorage` словарей → toast → `router.push('/dictionaries/{id}')`.
  Контракт под будущий `POST /decks` (бек создаёт колоду + карточки).

**Критерии:**
- [ ] Страница `/dictionaries/new` получает выбранные слова из анализатора
- [ ] Карточки редактируются (front/back/example), можно исключать чекбоксом
- [ ] «Создать колоду» формирует `DeckDraftDto`, добавляет колоду (mock) и ведёт на её детальную
- [ ] Прямой заход на `/dictionaries/new` без черновика — пустое состояние с CTA «Обработать текст»

---

## Соглашения

- **Catalyst-first:** для любого элемента сперва ищем готовый компонент Catalyst; кастом — только
  если эквивалента нет (`Card`, `Toast`, flip-карта, кольца целей, heatmap).
- **Темизация:** нейтраль — `stone`, акцент — `orange`. Никакого `zinc`/`blue` в `src/`.
- **Ссылки:** только адаптированный Catalyst `Link` (next/link). Никаких голых `<a href>` для внутренних роутов.
- **Изображения:** `next/image` через `Avatar`; голый `<img>` запрещён (правило CLAUDE.md).
- **Строки:** все видимые UI-строки — через `t('...')`. Контентные данные (имена ачивок, слова) — в mock.
- **Клиентские границы:** провайдеры в одном `'use client'` поддереве (F3).
- **Pre-commit:** `yarn lint` → `npx tsc --noEmit` → `yarn build`. Каждый element-таск — отдельный коммит
  с тегом `[01-CreateHomeDemo E#]`.

---

## Открытые вопросы

**Все вопросы закрыты.**

- [x] ~~Q1: `Card`~~ → кастомный **на основе `/data/dictinory/`** (решение #9).
- [x] ~~Q2: UI-локали~~ → **ru/en/de** (решение #7).
- [x] ~~Q3: флоу анализатора~~ → **текст → бек/парсер → леммы → БД(known)+формы+перевод → выбор → колода** (E5+E15).
- [x] ~~Q4: Поиск~~ → **`Combobox`** с автодополнением (решение #10).
- [x] ~~Q5: Регистрация~~ → **`Select` языка обучения** в форме (решение #11).
- [x] ~~Q6: Тема~~ → дефолт **`system`** (решение #6).
