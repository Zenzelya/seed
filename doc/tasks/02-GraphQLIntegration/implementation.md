# Epic 02: GraphQLIntegration — план реализации

Детальный план (второй уровень) по эпику [Epic-02-GraphQLIntegration](Epic-02-GraphQLIntegration.md).
Цель: подключить **code-first GraphQL** к NestJS и **Apollo Client** к Next.js, заменить mock-данные
Dashboard на реальные GraphQL-запросы. Аутентификация **остаётся на REST**.

---

## Принятые решения (из обсуждения)

| # | Вопрос | Решение |
|---|---|---|
| 1 | Данные Dashboard (srsQueue/categories/dailyPick/heatmap) | **Mock в резолвере** (совместим с DTO, помечен TODO). Реальные сервисы — позже со StudyModule |
| 2 | Поля профиля (lang, level, streak, xp, …) | **Добавить колонки в `User` entity БЕЗ миграции** (`synchronize`) + **demo-сидер** с тест-данными |
| 3 | Где аутентификация | **Остаётся REST** (login/register/refresh/logout). GraphQL — только `me` + dashboard queries |
| 4 | Refresh-token flow | **Реализовать сейчас:** Apollo `errorLink` ловит 401 → `POST /auth/refresh` (cookie) → retry |
| 5 | Code-first vs schema-first | **Code-first** (`@ObjectType`, `@Resolver`), `autoSchemaFile` |
| 6 | Driver | `@nestjs/apollo` + `@apollo/server` (ApolloDriver) |
| 7 | Хранение accessToken на фронте | **В памяти** (не localStorage — XSS), Bearer через `authLink`, `credentials:'include'` для кук |
| 8 | Адаптация под GQL | **И `JwtAuthGuard`, И `@CurrentUser`** (оба читают HTTP-контекст — оба ломаются в GQL) |

---

## Отклонения от эпика

- **Эпик TASK-3 (AuthResolver) — отменён.** Решение #3: auth остаётся REST. Бек уже выдаёт `accessToken`
  в теле + ставит `refreshToken`/`csrf` куки через `Response`; дублировать это в резолвере (через
  `@Context() res`) дороже и рискованнее. GraphQL экспозирует только `me` (read) + dashboard.
- **Добавлена адаптация `@CurrentUser`** (эпик упоминал только `JwtAuthGuard`).
- **Добавлены поля профиля в `User` + demo-сидер** (закрывает заодно Epic-01 TASK-0).

---

## Статус задач

| Задача | Репо | Статус | Коммит |
|---|---|---|---|
| B1 · GraphQL module setup (deps, driver, SWC-плагин, playground) | back | ❌ | — |
| B2 · GQL-aware `JwtAuthGuard` + `@CurrentUser` | back | ❌ | — |
| B3 · Поля профиля в `User` (без миграции) + demo-сидер | back | ❌ | — |
| B4 · `me` query + `UserType` | back | ❌ | — |
| B5 · `DashboardResolver` + ObjectTypes (mock) | back | ❌ | — |
| F6 · Apollo Client + provider + authLink + RSC-клиент | front | ❌ | — |
| F7 · graphql-codegen + `.graphql` операции | front | ❌ | — |
| F8 · Auth через REST (RestAuthService заменяет mock) | front | ❌ | — |
| F9 · Замена mock Dashboard → GraphQL queries | front | ❌ | — |
| F10 · Refresh-on-401 + loading/error states | front | ❌ | — |

**Порядок выполнения:** B1 → B2 → B3 → B4 → B5 → F6 → F7 → F8 → F9 → F10

**Зависит от:** Epic 01 (DTO-контракт, UserContext, AuthService-абстракция, Dashboard UI).

---

## Оглавление

- [B1 · GraphQL module setup](#b1--graphql-module-setup)
- [B2 · GQL-aware JwtAuthGuard + CurrentUser](#b2--gql-aware-jwtauthguard--currentuser)
- [B3 · Поля профиля + demo-сидер](#b3--поля-профиля--demo-сидер)
- [B4 · me query + UserType](#b4--me-query--usertype)
- [B5 · DashboardResolver](#b5--dashboardresolver)
- [F6 · Apollo Client setup](#f6--apollo-client-setup)
- [F7 · graphql-codegen](#f7--graphql-codegen)
- [F8 · Auth через REST](#f8--auth-через-rest)
- [F9 · Замена mock → GraphQL](#f9--замена-mock--graphql)
- [F10 · Refresh-on-401 + states](#f10--refresh-on-401--states)
- [Соглашения](#соглашения)
- [E2E проверка](#e2e-проверка)

---

## B1 · GraphQL module setup

**IN:** `src/app.module.ts`, `nest-cli.json`
**OUT:** `GraphQLModule` в `AppModule`, `schema.gql` (автоген), `/graphql` playground (dev)

**Шаги:**
- `yarn add @nestjs/graphql @nestjs/apollo @apollo/server graphql`
  (эпик упустил `@nestjs/apollo` — это пакет драйвера, обязателен).
- `GraphQLModule.forRootAsync<ApolloDriverConfig>` в `AppModule`:
  ```ts
  driver: ApolloDriver,
  autoSchemaFile: join(process.cwd(), 'schema.gql'),
  sortSchema: true,
  playground: !isProduction,
  context: ({ req, res }) => ({ req, res }),   // req — для guard/CurrentUser
  ```
- **SWC (rabbit hole):** `nest-cli.json` уже использует `builder: "swc"` + swagger-плагин.
  Code-first GraphQL опирается на decorator metadata. Добавить `@nestjs/graphql` плагин в
  `nest-cli.json` → `compilerOptions.plugins` рядом со swagger:
  ```json
  { "name": "@nestjs/graphql/plugin" }
  ```
  Правило проекта: всегда явный `@Field(() => Type)` (не полагаться на вывод типов через SWC).

**Критерии:**
- [ ] `yarn build` без ошибок
- [ ] `schema.gql` генерируется в корне backend
- [ ] `GET http://localhost:3000/graphql` → playground (dev)

---

## B2 · GQL-aware JwtAuthGuard + CurrentUser

**Контекст из кода:** `JwtAuthGuard` — глобальный (`APP_GUARD`), читает HTTP-request через
Passport `super.canActivate()`. `@CurrentUser` читает `ctx.switchToHttp().getRequest()`.
**Оба** ломаются в GraphQL-контексте — адаптировать оба.

**IN:** `src/modules/auth/guard/jwt-auth.guard.ts`, `src/common/decorators/current-user.decorator.ts`
**OUT:** оба с поддержкой GQL execution context

```ts
// jwt-auth.guard.ts — добавить getRequest()
getRequest(context: ExecutionContext) {
  const gqlReq = GqlExecutionContext.create(context).getContext<{ req?: Request }>().req;
  return gqlReq ?? context.switchToHttp().getRequest<Request>();
}
```

```ts
// current-user.decorator.ts — определять тип контекста
export const CurrentUser = createParamDecorator(
  (data: keyof JwtPayloadDto | undefined, ctx: ExecutionContext) => {
    const req =
      ctx.getType<GqlContextType>() === 'graphql'
        ? GqlExecutionContext.create(ctx).getContext<{ req: Request }>().req
        : ctx.switchToHttp().getRequest<Request>();
    const user = req.user as JwtPayloadDto | undefined;
    return data ? user?.[data] : user;
  },
);
```

- `canActivate` (проверка `@PublicPoint`) не трогаем — работает через `Reflector`.
- `me` будет `@PublicPoint()` + nullable → без токена `req.user` undefined → `me` вернёт `null` (не 401).

**Критерии:**
- [ ] `query { me }` без токена → `null` (не 401)
- [ ] `query { me }` с валидным JWT → данные пользователя
- [ ] Существующие REST-тесты auth/users не сломаны

---

## B3 · Поля профиля + demo-сидер

**Решение #2:** добавить колонки профиля в `User` entity **без миграции** (`synchronize` применит),
данные — через сидер. Закрывает заодно **Epic-01 TASK-0** (demo-юзер).

**IN:** `src/modules/users/entity/user.entity.ts`, `src/modules/users/seed/user.seeder.ts` (паттерн)
**OUT:** новые колонки в `User`, `src/modules/users/seed/demo-user.seeder.ts`, правило в `CLAUDE.md` (✅ записано)

**Колонки в `user.entity.ts`** (nullable / с дефолтами, snake_case в БД):
```ts
@Column({ type: 'varchar', length: 2, nullable: true })           lang: string | null;        // 'de'
@Column({ type: 'varchar', length: 4, nullable: true })           level: string | null;       // 'A2'
@Column({ type: 'int', default: 0 })                              streak: number;
@Column({ type: 'int', default: 0 })                              xp: number;
@Column({ name: 'unique_words', type: 'int', default: 0 })        uniqueWords: number;
@Column({ name: 'mastered_words', type: 'int', default: 0 })      masteredWords: number;
@Column({ name: 'daily_goal', type: 'int', default: 0 })          dailyGoal: number;
@Column({ name: 'daily_done', type: 'int', default: 0 })          dailyDone: number;
@Column({ name: 'weekly_goal', type: 'int', default: 0 })         weeklyGoal: number;
@Column({ name: 'weekly_done', type: 'int', default: 0 })         weeklyDone: number;
```
- **Без миграции** — `synchronize: db.sync` добавит колонки. Миграции — после релиза (см. CLAUDE.md).

**`demo-user.seeder.ts`** (паттерн `user.seeder.ts`):
- email `demo@wordlearn.dev`, пароль `demo1234` (bcrypt через тот же путь, что AuthService/UsersFacade),
  `firstName: 'Demo'`, профиль: `lang:'de', level:'A2', streak:4, xp:1240, uniqueWords:47, …`
- Идемпотентность: `ON CONFLICT (email) DO NOTHING` / проверка существования.
- Зарегистрировать в общем seed entry-point (рядом с `admin.seeder`, `languages.seed`).

**Критерии:**
- [ ] После рестарта (`synchronize`) колонки есть в таблице `users`
- [ ] `yarn seed` создаёт demo-юзера; повторный запуск не дублирует
- [ ] `SELECT lang, streak FROM users WHERE email='demo@wordlearn.dev'` → значения профиля

---

## B4 · me query + UserType

**IN:** `User` entity (B3), `@CurrentUser` (B2), `UsersService`/`UsersFacade`
**OUT:** `src/modules/users/gql/user.type.ts`, резолвер `me` (в `users.resolver.ts` или `auth`)

```ts
@ObjectType('User')
export class UserType {
  @Field(() => ID) id: string;
  @Field() email: string;
  @Field({ nullable: true }) firstName?: string;
  @Field({ nullable: true }) lastName?: string;
  @Field(() => UserRoleEnum) role: UserRole;       // registerEnumType(UserRole, …)
  @Field() createdAt: string;                       // ISO
  // профиль (B3):
  @Field({ nullable: true }) lang?: string;
  @Field({ nullable: true }) level?: string;
  @Field(() => Int) streak: number;
  @Field(() => Int) xp: number;
  @Field(() => Int) uniqueWords: number;
  @Field(() => Int) masteredWords: number;
  @Field(() => Int) dailyGoal: number;
  @Field(() => Int) dailyDone: number;
  @Field(() => Int) weeklyGoal: number;
  @Field(() => Int) weeklyDone: number;
}
```

```ts
@Query(() => UserType, { nullable: true })
@PublicPoint()
async me(@CurrentUser() user: JwtPayloadDto | null): Promise<UserType | null> {
  if (!user) return null;
  const result = await this.usersService.findById(user.sub);   // ResultAsync
  if (result.isErr()) return null;
  return mapUserToType(result.value);
}
```

- `registerEnumType(UserRole, { name: 'UserRole' })` — один раз.
- Маппер entity → `UserType` (ISO-дата для `createdAt`).

**Критерии:**
- [ ] `query { me { id email lang streak } }` с токеном demo → профиль
- [ ] Без токена → `null`

---

## B5 · DashboardResolver

**Решение #1:** данные — mock в резолвере (совместимы с DTO Epic-01), помечены `// TODO: real service`.

**IN:** mock-данные (скопировать срез из frontend `mock-data.ts` в backend)
**OUT:** `src/modules/dashboard/dashboard.module.ts`, `dashboard.resolver.ts`,
`gql/{srs-card,category,daily-pick,heatmap-day}.type.ts`, `dashboard.mock.ts`

**ObjectTypes** — 1:1 с DTO Epic-01: `SrsCardType`, `CategoryType`, `DailyPickType`, `HeatmapDayType`.

**Queries:**
```ts
@Query(() => [SrsCardType])
async srsQueue(@CurrentUser() u: JwtPayloadDto, @Args('lang') lang: string,
               @Args('limit', { type: () => Int, nullable: true }) limit?: number): Promise<SrsCardType[]>

@Query(() => [CategoryType])
async categories(): Promise<CategoryType[]>

@Query(() => DailyPickType, { nullable: true })
async dailyPick(@Args('lang') lang: string): Promise<DailyPickType | null>

@Query(() => [HeatmapDayType])
async activityHeatmap(@CurrentUser() u: JwtPayloadDto,
                      @Args('weeks', { type: () => Int, nullable: true }) weeks?: number): Promise<HeatmapDayType[]>
```
- `srsQueue`/`activityHeatmap` — требуют авторизации (без `@PublicPoint`). `categories`/`dailyPick` — публичные.
- `dailyPick` (эпик Q3): mock — фиксированный по языку (как `DAILY_PICK[lang]`); алгоритм по дате — позже.
- `activityHeatmap` (эпик Q2): mock-генератор (нет таблицы прогресса); реальная — со StudyModule.

**Критерии:**
- [ ] `query { srsQueue(lang:"de"){ word translation } }` → массив
- [ ] `query { categories { name count mastered } }` → массив
- [ ] `query { dailyPick(lang:"de"){ word } }` → объект

---

## F6 · Apollo Client setup

**IN:** `frontend/app/providers.tsx` (Epic-01 F3), in-memory accessToken (Epic-01 F4 AuthService)
**OUT:** `src/lib/apollo/apollo-provider.tsx` (`'use client'`), `src/lib/apollo/apollo-client.ts` (RSC)

- `yarn add @apollo/client graphql`
- **Client-провайдер** (`'use client'`): `httpLink` (`uri` = backend `/graphql`, `credentials: 'include'`
  для refresh/csrf кук) + `authLink` (заголовок `Authorization: Bearer ${getAccessToken()}` из памяти) +
  `InMemoryCache`. Монтируется в `app/providers.tsx` внутри `UserProvider`.
- **RSC-клиент** (`apollo-client.ts`): per-request, без шаринга кеша между запросами.
  `@apollo/client-integration-nextjs` (бывш. `@apollo/experimental-nextjs-app-support`) — проверить
  совместимость с Next 16 / React 19; если несовместим — простой `new ApolloClient` per-call в RSC.

**Критерии:**
- [ ] `useQuery` доступен в client-компонентах без ошибок
- [ ] Запросы уходят с `Authorization` (если есть токен) и `credentials: include`

---

## F7 · graphql-codegen

**IN:** `schema.gql` (B1) или `http://localhost:3000/graphql`
**OUT:** `src/gql/*.graphql` (операции), `src/lib/gql/__generated__/` (типы + хуки), `codegen.ts`, скрипт `codegen`

- `yarn add -D @graphql-codegen/cli @graphql-codegen/typescript @graphql-codegen/typescript-operations @graphql-codegen/typescript-react-apollo`
- `.graphql` операции (**без login/register** — auth на REST):
  ```graphql
  query Me { me { id email firstName lastName role createdAt lang level streak xp uniqueWords masteredWords dailyGoal dailyDone weeklyGoal weeklyDone } }
  query SrsQueue($lang: String!, $limit: Int) { srsQueue(lang:$lang, limit:$limit){ id word translation pos example due interval mastery } }
  query Categories { categories { id name count mastered color } }
  query DailyPick($lang: String!) { dailyPick(lang:$lang){ word translation pos etymology sentence } }
  query ActivityHeatmap($weeks: Int) { activityHeatmap(weeks:$weeks){ date value } }
  ```
- `codegen.ts`: schema из бэка, documents `src/**/*.graphql`, output `src/lib/gql/`, preset client/`typescript-react-apollo`.
- `package.json`: `"codegen": "graphql-codegen"`.

**Критерии:**
- [ ] `yarn codegen` генерит `useMeQuery`, `useSrsQueueQuery`, `useCategoriesQuery`, … без ошибок

---

## F8 · Auth через REST

**Решение #3+#7:** заменить `MockAuthService` (Epic-01 F4) на **`RestAuthService`** — реальные вызовы
REST. accessToken — в памяти; refresh/csrf — в куках (браузер сам, `credentials:'include'`).

**IN:** `AuthService`-интерфейс (Epic-01 F4), `LoginModal`/`RegisterModal`, `UserContext`
**OUT:** `src/lib/auth/rest-auth-service.ts`, обновлённые модалки, in-memory token store

- `RestAuthService`:
  - `loginEmail` → `POST /auth/login` (`credentials:'include'`) → `{ user, accessToken }`; токен в память.
  - `register` → `POST /auth/register` → аналогично.
  - `loginWithGoogle` → редирект на бек Google OAuth (существует) — вне MVP, оставить заглушку/редирект.
  - `logout` → `POST /auth/logout` (Bearer) → очистить память + UserContext.
- **Token store:** модульный ref `getAccessToken()/setAccessToken()` — читается `authLink` (F6).
- На старте приложения: токена в памяти нет (reload) → попытка `POST /auth/refresh` (cookie) →
  если успех, получить accessToken + `me` (F9). Если нет — demo-guest.
- Модалки: вызывают `useAuth()` (REST), inline-ошибки при 401/400.

**Критерии:**
- [ ] Login через форму → реальный JWT в памяти, refresh-cookie выставлен
- [ ] Reload страницы → сессия восстановлена через `/auth/refresh` (без повторного логина)

---

## F9 · Замена mock → GraphQL

**IN:** хуки из F7, `me` + dashboard queries
**OUT:** компоненты Dashboard без import из `mock-data.ts` (кроме `DEMO_GUEST` для unauthed)

- **Профиль (authed):** `useMeQuery()` → данные в `UserContext` (заменяет localStorage-профиль).
  Unauthed → `DEMO_GUEST` (mock остаётся для демо-режима).
- **Dashboard:** `useSrsQueueQuery`, `useCategoriesQuery`, `useDailyPickQuery`, `useActivityHeatmapQuery`
  (по `lang`). Передавать данные в `Flashcard`, `Hero`, `Goals`, `Heatmap`, `WordOfDay` без правок их пропсов.
- RSC-вариант (`page.tsx`): по желанию `getClient().query(...)` для первичной отрисовки; иначе всё в client-компонентах.
- `mock-data.ts` остаётся только для `DEMO_GUEST` и demo-режима.

**Критерии:**
- [ ] У авторизованного юзера данные Dashboard — из GraphQL, не из mock
- [ ] Flashcard показывает `srsQueue` с сервера
- [ ] Demo-guest по-прежнему видит mock

---

## F10 · Refresh-on-401 + states

**Решение #4:** реализовать refresh сейчас.

**IN:** Apollo client (F6), REST `/auth/refresh`
**OUT:** `errorLink` в Apollo, loading/error UI

- **`errorLink`** (`@apollo/client/link/error`): при `UNAUTHENTICATED`/401 →
  `POST /auth/refresh` (cookie) → новый accessToken в память → **retry** исходной операции.
  Если refresh упал → `logout()` → demo-guest.
  Защита от гонки: один in-flight refresh (промис-синглтон), остальные ждут его.
- **Loading:** skeleton для `Flashcard`, `Dictionaries`, `WordOfDay` пока грузится.
- **Error:** упал query → fallback (mock или сообщение), не пустой блок.
- Модалки: кнопка disabled во время запроса, inline-ошибка при неверных кредах.

**Критерии:**
- [ ] Протухший accessToken → прозрачный refresh → запрос проходит, юзер не разлогинен
- [ ] refresh упал → возврат к demo-guest без краша
- [ ] Медленная сеть → skeleton, не пустые блоки

---

## Соглашения

- **Бек:** схема — через entity + `synchronize` (без миграций до релиза, см. `backend/CLAUDE.md`);
  сервисы — `ResultAsync` (`isErr()`/`value`); явный `@Field(() => Type)` (SWC); enum — `registerEnumType`.
- **Фронт:** accessToken только в памяти; `credentials:'include'` на всех запросах к беку; типы/хуки —
  только из codegen, не писать вручную; auth — через `AuthService` (REST), не прямой fetch в компонентах.
- **Pre-commit:** бек — `format → lint → tsc → build → test (критпуть)`; фронт — `lint → tsc → build`.
- Каждая задача — отдельный коммит с тегом `[02-GraphQLIntegration B#/F#]`.

---

## E2E проверка

```bash
# 1. Бек: схема + сидер + playground
cd backend && yarn start:dev          # synchronize добавит колонки профиля
yarn seed                              # demo@wordlearn.dev / demo1234
# GET http://localhost:3000/graphql
#   query { me }                       → null
#   (Bearer от REST /auth/login)
#   query { me { email streak } }      → профиль demo
#   query { srsQueue(lang:"de"){word}} → массив

# 2. Фронт: codegen + dev
cd frontend && yarn codegen            # src/lib/gql/__generated__/
yarn dev                               # http://localhost:4200

# 3. Login (REST) → токен в памяти, refresh-cookie
# 4. Dashboard — данные из GraphQL (me + srsQueue/categories/dailyPick/heatmap)
# 5. Reload → сессия восстановлена через /auth/refresh
# 6. Logout → demo-guest + mock
```

**Done когда:** авторизованный юзер видит данные из GraphQL (не mock); сессия переживает reload
через refresh-cookie; auth работает по REST.
