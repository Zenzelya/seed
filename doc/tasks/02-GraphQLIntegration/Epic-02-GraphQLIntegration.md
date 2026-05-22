# Epic 02: GraphQLIntegration — Replace mock data with real API

## Оглавление

- [Summary](#summary)
- [Appetite](#appetite)
- [Problem](#problem)
- [Solution](#solution)
- [Non-goals](#non-goals)
- [Dependencies](#dependencies)
- [Schema — что экспозируем](#schema--что-экспозируем)
- [Architecture decisions](#architecture-decisions)
- [Rabbit holes](#rabbit-holes)
- [Open questions](#open-questions)
- [Tasks](#tasks)
- [E2E acceptance](#e2e-acceptance)
- [Rollback](#rollback)

---

## Summary

Подключаем GraphQL к NestJS (code-first) и Apollo Client к Next.js. После эпика фронтенд больше не использует `mock-data.ts` — Dashboard, Auth, SRS-очередь, категории и слово дня загружаются через реальные GraphQL-запросы. DTO-контракт из Epic 01 переходит в GraphQL-типы без изменений.

---

## Appetite

**Лимит:** 8 задач

---

## Problem

- Фронтенд использует статичные mock-данные из `mock-data.ts` — нет связи с реальной БД
- `LoginModal` и `RegisterModal` вызывают `login()` в localStorage — нет реальной авторизации
- Существующий REST API (`AuthController`, `UsersController`) не покрывает Dashboard-данные (SRS, категории, слово дня)
- Нет единой точки входа для фронтенда — разные REST-эндпоинты требуют N запросов

---

## Solution

**Backend (NestJS) — code-first GraphQL:**
1. Установить `@nestjs/graphql` + `@apollo/server` + `graphql`
2. Адаптировать `JwtAuthGuard` для GraphQL execution context
3. `AuthResolver` — mutations: `login`, `register`, `logout`; query: `me`
4. `DashboardResolver` — queries: `srsQueue`, `categories`, `dailyPick`, `activityHeatmap`

**Frontend (Next.js) — Apollo Client:**
5. Установить `@apollo/client` + `graphql`, настроить провайдер
6. Запустить `graphql-codegen` — генерация типов из схемы
7. Заменить `mock-data.ts` → реальные запросы в `page.tsx` и `UserContext`

---

## Non-goals

- [ ] Subscriptions (WebSocket) — не нужны на Dashboard
- [ ] Persisted queries — оптимизация после MVP
- [ ] Batching / DataLoader — добавить когда появятся N+1 запросы
- [ ] GraphQL файловые загрузки — отдельный эпик (Upload модуль остаётся REST)
- [ ] Полный CRUD через GraphQL (Deck, Folder, Card mutations) — только Dashboard queries + Auth mutations
- [ ] Удаление REST API — остаётся параллельно

---

## Dependencies

| Зависимость | Где | Статус |
|---|---|---|
| Epic 01 завершён (DTO контракт, UserContext, Dashboard UI) | frontend | ❌ |
| `@nestjs/graphql` + `@apollo/server` + `graphql` | backend npm | ❌ |
| `@apollo/client` + `graphql` | frontend npm | ❌ |
| `@graphql-codegen/cli` + plugins | frontend devDep | ❌ |
| `AuthModule`, `UsersModule` — существуют | backend | ✅ |
| `JwtAuthGuard`, `@CurrentUser()` — существуют | backend | ✅ |

---

## Schema — что экспозируем

Минимальная схема для Dashboard + Auth:

```graphql
type User {
  id: ID!
  email: String!
  firstName: String
  lastName: String
  role: UserRole!
  createdAt: String!
  # Profile fields (после ProfileModule):
  lang: String
  level: String
  streak: Int
  xp: Int
  uniqueWords: Int
  masteredWords: Int
  dailyGoal: Int
  dailyDone: Int
  weeklyGoal: Int
  weeklyDone: Int
}

type AuthTokens {
  accessToken: String!
}

type SrsCard {
  id: ID!
  word: String!
  translation: String!
  pos: String!
  example: String!
  due: String!
  interval: String!
  mastery: Float!
}

type Category {
  id: ID!
  name: String!
  count: Int!
  mastered: Int!
  color: String!
}

type DailyPick {
  word: String!
  translation: String!
  pos: String!
  etymology: String!
  sentence: String!
}

type HeatmapDay {
  date: String!   # ISO date
  value: Int!     # 0..4
}

type Query {
  me: User                              # @CurrentUser — null если не авторизован
  srsQueue(lang: String!, limit: Int): [SrsCard!]!
  categories: [Category!]!
  dailyPick(lang: String!): DailyPick
  activityHeatmap(weeks: Int): [HeatmapDay!]!
}

type Mutation {
  login(email: String!, password: String!): AuthTokens!
  register(email: String!, password: String!, firstName: String!): AuthTokens!
  logout: Boolean!
}
```

---

## Architecture decisions

### Code-first vs Schema-first

**Решение:** Code-first — декораторы `@ObjectType`, `@Resolver`, `@Query`, `@Mutation`.

**Почему:** вся кодовая база NestJS уже на декораторах (Swagger, class-validator). Code-first не требует отдельных `.graphql` файлов и синхронизации типов. Схема генерируется автоматически в `schema.gql`.

### Apollo Server vs Mercurius

**Решение:** `@apollo/server` — дефолтный выбор `@nestjs/graphql`.

**Почему:** лучшая поддержка в экосистеме, apollo-codegen совместим, больше документации.

### JwtAuthGuard в GraphQL context

**Контекст:** существующий `JwtAuthGuard` читает `request` из HTTP-контекста. GraphQL-запросы приходят через другой execution context.

**Решение:** переопределить `getRequest()` в `JwtAuthGuard`:
```typescript
getRequest(context: ExecutionContext) {
  const ctx = GqlExecutionContext.create(context);
  return ctx.getContext().req;  // HTTP request внутри GraphQL context
}
```
Один guard работает для REST и GraphQL.

### Apollo Client в Next.js App Router

**Контекст:** Apollo Client — клиентская библиотека, `ApolloProvider` требует `'use client'`. RSC не могут использовать Apollo hooks.

**Решение:**
- `ApolloProvider` оборачивает приложение в `app/layout.tsx` (client компонент)
- RSC (page.tsx) — данные через Apollo Client на сервере: `getClient().query()`
- Client компоненты (DashboardClient) — `useQuery`, `useMutation` hooks

```typescript
// src/lib/apollo-client.ts — серверный клиент для RSC
export function getApolloClient() { ... }  // singleton, нет кеша между запросами

// src/lib/apollo-provider.tsx — 'use client', для hooks в клиент-компонентах
export function ApolloProvider({ children }) { ... }
```

### Куки vs Authorization header

**Контекст:** существующий Auth выдаёт JWT в `accessToken` поле и refresh token в httpOnly cookie.

**Решение:** фронтенд хранит `accessToken` в памяти (не localStorage — XSS риск), добавляет в Apollo `Authorization: Bearer ...` header через `authLink`. Refresh через refresh token cookie при 401.

### graphql-codegen

**Решение:** `@graphql-codegen/typescript` + `@graphql-codegen/typescript-operations` + `@graphql-codegen/typescript-react-apollo`.

Генерирует типы и хуки из `.graphql` файлов фронтенда. Запускается:
```bash
cd frontend && yarn codegen   # единоразово или при изменении схемы
```

---

## Rabbit holes

- **`@nestjs/graphql` + SWC** — NestJS swagger plugin (`"builder": "swc"`) может конфликтовать с graphql metadata. Проверить `nest-cli.json` до установки
- **CSRF guard + GraphQL mutations** — `CsrfGuard` ожидает `x-csrf-token` header. Apollo Client нужно настроить для отправки этого заголовка
- **Apollo Client SSR + App Router** — `ApolloClient` не thread-safe между запросами в RSC. Нужен отдельный singleton per request. Используй `import { InMemoryCache } from '@apollo/client'` + `registerApolloClient` из `@apollo/experimental-nextjs-app-support`
- **`@CurrentUser()` в GraphQL** — декоратор читает `req.user`. В GQL context убедиться что `req` передаётся через `context: ({ req }) => ({ req })`
- **N+1 проблема** — `categories` query может триггерить N запросов к БД. Для MVP допустимо, DataLoader добавить позже

---

## Open questions

- [ ] Q1: Dashboard данные (SRS, категории, heatmap) — откуда брать? Модули `Card`, `Deck` ещё не имеют service-методов для Dashboard. Нужны новые сервисные методы или временные заглушки возвращающие mock?
- [ ] Q2: `activityHeatmap` — в какой таблице хранится активность пользователя? Есть ли `UserCardProgress` или аналог?
- [ ] Q3: `dailyPick` — алгоритм выбора слова дня? Рандом из Dictionary или фиксированный по дате?
- [ ] Q4: Refresh token flow — реализовать в этом эпике или оставить на следующий?

---

## Tasks

### TASK-1 · Backend: установка и настройка GraphQL модуля

**Статус:** ❌
**Блокирует:** TASK-2, TASK-3
**Заблокирована:** —

**IN:** `backend/src/app.module.ts`, `backend/nest-cli.json`
**OUT:** `GraphQLModule` в `AppModule`, файл `schema.gql` генерируется при build

**Что сделать:**
- `yarn add @nestjs/graphql @apollo/server graphql`
- Добавить `GraphQLModule.forRootAsync<ApolloDriverConfig>` в `AppModule`
- Конфиг: `driver: ApolloDriver`, `autoSchemaFile: 'schema.gql'`, `context: ({ req }) => ({ req })`
- Проверить совместимость SWC plugin с graphql metadata — если конфликт, отключить SWC для graphql файлов
- `GET /graphql` → GraphQL Playground (dev only)

**Критерии готовности:**
- [ ] `yarn build` без ошибок
- [ ] `schema.gql` генерируется в корне backend
- [ ] `GET http://localhost:3000/graphql` → Playground открывается

---

### TASK-2 · Backend: адаптация JwtAuthGuard для GraphQL

**Статус:** ❌
**Блокирует:** TASK-3
**Заблокирована:** TASK-1

**IN:** `backend/src/modules/auth/guard/jwt-auth.guard.ts`
**OUT:** обновлённый `JwtAuthGuard` с поддержкой GQL execution context

**Что сделать:**
```typescript
import { GqlExecutionContext } from '@nestjs/graphql';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  getRequest(context: ExecutionContext) {
    const ctx = GqlExecutionContext.create(context);
    const gqlReq = ctx.getContext<{ req: Request }>().req;
    return gqlReq ?? context.switchToHttp().getRequest();
  }
}
```
- Убедиться что `@CurrentUser()` декоратор работает в GraphQL resolver'ах
- Добавить `@PublicPoint()` поддержку для `login` и `register` mutations

**Критерии готовности:**
- [ ] `query { me }` без токена → `null` (не 401)
- [ ] `query { me }` с валидным JWT → `{ id, email, ... }`
- [ ] Существующие REST тесты не сломаны

---

### TASK-3 · Backend: AuthResolver

**Статус:** ❌
**Блокирует:** TASK-4
**Заблокирована:** TASK-2

**IN:** существующий `AuthService` (`login`, `register`), `TokensDto`
**OUT:** `backend/src/modules/auth/auth.resolver.ts`

**Mutations и Query:**
```typescript
@Mutation(() => AuthTokensType)
@PublicPoint()
async login(@Args('email') email: string, @Args('password') password: string): Promise<AuthTokens>

@Mutation(() => AuthTokensType)
@PublicPoint()
async register(@Args('email') email: string, @Args('password') password: string, @Args('firstName') firstName: string): Promise<AuthTokens>

@Mutation(() => Boolean)
async logout(@CurrentUser() user: JwtPayloadDto, @Context() ctx): Promise<boolean>

@Query(() => UserType, { nullable: true })
@PublicPoint()
async me(@CurrentUser() user: JwtPayloadDto | null): Promise<User | null>
```

**ObjectTypes:**
```typescript
// backend/src/modules/auth/gql/auth-tokens.type.ts
@ObjectType()
class AuthTokensType {
  @Field() accessToken: string;
}

// backend/src/modules/users/gql/user.type.ts  
@ObjectType()
class UserType {
  @Field(() => ID) id: string;
  @Field() email: string;
  @Field({ nullable: true }) firstName?: string;
  @Field({ nullable: true }) lastName?: string;
  @Field(() => UserRoleEnum) role: UserRole;
  @Field() createdAt: string;
}
```

**Критерии готовности:**
- [ ] `mutation { login(email: "demo@wordlearn.dev", password: "demo1234") { accessToken } }` → токен
- [ ] `mutation { register(...) { accessToken } }` → токен
- [ ] `query { me }` с токеном → данные пользователя

---

### TASK-4 · Backend: DashboardResolver

**Статус:** ❌
**Блокирует:** TASK-5
**Заблокирована:** TASK-3

**IN:** `DictionaryModule`, `CardModule` сервисы; если методов нет — временные заглушки с mock-данными совместимыми с DTO
**OUT:** `backend/src/modules/dashboard/dashboard.resolver.ts`, `dashboard.module.ts`

**Queries:**
```typescript
@Query(() => [SrsCardType])
async srsQueue(@CurrentUser() user: JwtPayloadDto, @Args('lang') lang: string, @Args('limit', { nullable: true }) limit?: number): Promise<SrsCard[]>

@Query(() => [CategoryType])
async categories(): Promise<Category[]>

@Query(() => DailyPickType, { nullable: true })
async dailyPick(@Args('lang') lang: string): Promise<DailyPick | null>

@Query(() => [HeatmapDayType])
async activityHeatmap(@CurrentUser() user: JwtPayloadDto, @Args('weeks', { nullable: true }) weeks?: number): Promise<HeatmapDay[]>
```

**ObjectTypes:** `SrsCardType`, `CategoryType`, `DailyPickType`, `HeatmapDayType` — соответствуют DTO из Epic 01.

**Стратегия данных:** если сервисных методов нет → возвращать данные из `mock-data.ts` (скопированного в backend). Помечать `// TODO: replace with real service` — не блокировать эпик отсутствием StudyModule.

**Критерии готовности:**
- [ ] `query { srsQueue(lang: "de") { word translation } }` → массив карточек
- [ ] `query { categories { name count mastered } }` → массив категорий
- [ ] `query { dailyPick(lang: "de") { word translation } }` → объект

---

### TASK-5 · Frontend: Apollo Client setup + ApolloProvider

**Статус:** ❌
**Блокирует:** TASK-6
**Заблокирована:** TASK-4

**IN:** `frontend/app/layout.tsx`, `frontend/src/lib/user-context.tsx`
**OUT:** `frontend/src/lib/apollo-client.ts`, `frontend/src/lib/apollo-provider.tsx`

**Что сделать:**
- `yarn add @apollo/client graphql`
- `yarn add -D @graphql-codegen/cli @graphql-codegen/typescript @graphql-codegen/typescript-operations @graphql-codegen/typescript-react-apollo`
- `apollo-provider.tsx` — `'use client'`, оборачивает children, `InMemoryCache`, `authLink` (Authorization header из `UserContext`)
- `apollo-client.ts` — серверный клиент для RSC (per-request, без кеша между запросами). Использовать `@apollo/experimental-nextjs-app-support` если совместим
- `app/layout.tsx` → добавить `<ApolloProvider>` внутри `<UserProvider>`
- `codegen.ts` — конфиг codegen: схема из `http://localhost:3000/graphql`, документы из `src/**/*.graphql`, output в `src/lib/gql/`
- Добавить скрипт `"codegen": "graphql-codegen"` в `package.json`

**Критерии готовности:**
- [ ] `yarn codegen` выполняется без ошибок, генерирует файлы в `src/lib/gql/`
- [ ] `useQuery` хук доступен в client компонентах без ошибок

---

### TASK-6 · Frontend: graphql-codegen + .graphql файлы

**Статус:** ❌
**Блокирует:** TASK-7
**Заблокирована:** TASK-5

**IN:** `schema.gql` из backend, сгенерированная схема
**OUT:** `frontend/src/gql/` — `.graphql` файлы операций, `src/lib/gql/__generated__/` — типы и хуки

**Операции:**
```graphql
# src/gql/auth.graphql
mutation Login($email: String!, $password: String!) {
  login(email: $email, password: $password) { accessToken }
}
mutation Register($email: String!, $password: String!, $firstName: String!) {
  register(email: $email, password: $password, firstName: $firstName) { accessToken }
}
query Me { me { id email firstName lastName role createdAt } }

# src/gql/dashboard.graphql
query SrsQueue($lang: String!, $limit: Int) {
  srsQueue(lang: $lang, limit: $limit) { id word translation pos example due interval mastery }
}
query Categories { categories { id name count mastered color } }
query DailyPick($lang: String!) { dailyPick(lang: $lang) { word translation pos etymology sentence } }
query ActivityHeatmap($weeks: Int) { activityHeatmap(weeks: $weeks) { date value } }
```

**Что сделать:**
- Написать `.graphql` файлы
- Запустить `yarn codegen` → сгенерировать typed hooks: `useLoginMutation`, `useRegisterMutation`, `useMeQuery`, `useSrsQueueQuery` и т.д.

---

### TASK-7 · Frontend: замена mock → GraphQL в Dashboard и Auth

**Статус:** ❌
**Блокирует:** TASK-8
**Заблокирована:** TASK-6

**IN:** сгенерированные хуки из TASK-6; `UserContext`, `LoginModal`, `RegisterModal`, `page.tsx`
**OUT:** обновлённые компоненты без import из `mock-data.ts` (кроме DEMO_GUEST для unauthed state)

**Что сделать:**

`UserContext`:
- `login()` → `useMutation(LOGIN)` → сохранить `accessToken` в памяти (ref) → `localStorage.setItem('wl_user', ...)` для профиля
- `register()` → `useMutation(REGISTER)` → аналогично
- `useEffect` на mount → если есть `wl_user` в localStorage → `useQuery(ME)` → синхронизировать с сервером

`page.tsx` (RSC):
- `srsQueue`, `categories`, `dailyPick` → `getApolloClient().query(...)` на сервере
- Данные передаются как props в компоненты (без изменений в самих компонентах)

`LoginModal` / `RegisterModal`:
- Вызов mutation вместо mock `login()`
- Обработка ошибок (неверный пароль → сообщение в форме)

`DashboardClient` (heatmap):
- `useQuery(ACTIVITY_HEATMAP)` для authed пользователя

**Критерии готовности:**
- [ ] `mock-data.ts` больше не импортируется в компонентах Dashboard (только в `user-context.tsx` для DEMO_GUEST)
- [ ] Login через форму → JWT получен → профиль загружен с сервера
- [ ] Flashcard показывает реальные SRS карточки для залогиненного пользователя

---

### TASK-8 · Frontend + Backend: error handling + loading states

**Статус:** ❌
**Блокирует:** —
**Заблокирована:** TASK-7

**IN:** все компоненты из TASK-7
**OUT:** корректная обработка loading/error состояний во всех запросах

**Что сделать:**
- Loading skeleton для `Flashcard`, `Categories`, `WordOfDay` пока грузятся данные
- Error state: если query упал → показать fallback (mock-данные или сообщение)
- `LoginModal` / `RegisterModal` — disabled кнопка во время mutation, inline ошибка при `AuthenticationError`
- `401` от Apollo → `logout()` → возврат к demo-guest

**Критерии готовности:**
- [ ] Медленный интернет → видны skeleton заглушки, не пустые блоки
- [ ] Неверный пароль → inline сообщение в форме, не крэш

---

## E2E acceptance

```bash
# 1. Backend GraphQL Playground
cd backend && npm run start:dev
# GET http://localhost:3000/graphql
# Выполнить: query { me } → null (unauthed)
# Выполнить: mutation { login(email: "demo@wordlearn.dev", password: "demo1234") { accessToken } }
# Скопировать токен → Authorization: Bearer <token>
# Выполнить: query { me } → { id, email, ... }
# Выполнить: query { srsQueue(lang: "de") { word } } → массив карточек

# 2. Frontend codegen
cd frontend && yarn codegen
# Ожидание: src/lib/gql/__generated__/ содержит типы

# 3. Frontend dev
yarn dev
# Открыть http://localhost:4200
# Нажать "Войти" → email: demo@wordlearn.dev, password: demo1234
# Ожидание: пользователь залогинен, данные загружены с сервера, не из mock

# 4. Flashcard данные — реальные SRS
# Ожидание: карточки приходят из query { srsQueue }

# 5. Logout → возврат к demo-guest
# Ожидание: DemoBanner появился, данные вернулись к mock
```

**Done когда:** фронтенд не использует mock-данные для авторизованного пользователя — все данные из GraphQL.

---

## Rollback

1. `backend/src/app.module.ts` — убрать `GraphQLModule`
2. Удалить `backend/src/modules/auth/auth.resolver.ts`, `backend/src/modules/dashboard/`
3. Удалить `backend/schema.gql`
4. `frontend/src/lib/apollo-client.ts`, `apollo-provider.tsx` — удалить
5. `frontend/app/layout.tsx` — убрать `ApolloProvider`
6. `frontend/src/lib/user-context.tsx` — вернуть mock-login
7. `frontend/src/gql/`, `frontend/src/lib/gql/` — удалить
8. `yarn remove @nestjs/graphql @apollo/server graphql` (backend)
9. `yarn remove @apollo/client` (frontend)
