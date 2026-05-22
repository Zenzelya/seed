# Error Handling

## Оглавление

- [Ключевые файлы](#ключевые-файлы)
- [Коды ошибок и HTTP-статусы](#коды-ошибок-и-http-статусы)
- [Фабрика AppError](#фабрика-apperror)
- [Словарь строк error-vocabulary.ts](#словарь-строк-error-vocabularyts)
- [HTTP-ответ (RFC 7807)](#http-ответ-rfc-7807-problem-details)
- [Как добавить новый сценарий ошибки](#как-добавить-новый-сценарий-ошибки)
- [Чего не делать](#чего-не-делать)
- [TODO](#todo-низкий-приоритет)

---

Система ошибок построена по принципу **единой точки входа**: вся бизнес-логика бросает объекты `IAppError`, фреймворк ничего не знает о домене. Фильтр на уровне NestJS перехватывает их и отдаёт клиенту RFC 7807 Problem Details.

```
throw/errAsync(AppError.*)
        ↓
  DomainExceptionFilter
        ↓
  RFC 7807 JSON → клиент
```

---

## Ключевые файлы

| Файл | Назначение |
|------|-----------|
| `src/common/domain/error/domain-error-code.enum.ts` | Перечень всех кодов ошибок |
| `src/common/domain/error/error-details-registry.ts` | Типы payload для каждого кода |
| `src/common/domain/error/error-definitions.ts` | `messageResolver` — как строится сообщение |
| `src/common/domain/error/app-error.factory.ts` | **Единственная фабрика** — `AppError` |
| `src/common/domain/error/error-vocabulary.ts` | Словарь строк для `reason` и `action` |
| `src/common/filters/domain-error-code-to-http.map.ts` | Маппинг код → HTTP статус |
| `src/common/filters/domain-exception.filter.ts` | Фильтр, формирующий HTTP-ответ |

---

## Коды ошибок и HTTP-статусы

| Код | HTTP | Когда использовать |
|-----|------|--------------------|
| `RESOURCE_NOT_FOUND` | 404 | Запись не найдена по ID или полю |
| `RESOURCE_ALREADY_EXISTS` | 409 | Нарушение unique-constraint |
| `RESOURCE_STATE_CONFLICT` | 409 | Операция запрещена текущим состоянием |
| `REFERENCE_NOT_FOUND` | 422 | FK-ссылка на несуществующую запись |
| `BUSINESS_RULE_VIOLATION` | 422 | Нарушение бизнес-правила |
| `ACCESS_DENIED` | 403 | Нет прав на действие |
| `NOT_OWNER` | 403 | Попытка изменить чужой ресурс |
| `UNAUTHORIZED` | 401 | Не аутентифицирован |
| `TOKEN_EXPIRED` | 401 | JWT истёк |
| `TOKEN_INVALID` | 401 | JWT невалиден |
| `CSRF_TOKEN_INVALID` | 403 | Невалидный CSRF-токен |
| `INVALID_PASSWORD` | 401 | Неверный текущий пароль |
| `TOKEN_EXPIRED` | 401 | JWT access-токен истёк |
| `TOKEN_INVALID` | 401 | JWT access-токен невалиден |
| `REFRESH_TOKEN_MISSING` | 401 | Refresh-токен отсутствует в cookie |
| `REFRESH_TOKEN_INVALID` | 401 | Refresh-токен невалиден или истёк |
| `REFRESH_TOKEN_MALFORMED` | 401 | В payload refresh-токена отсутствует `sub` |
| `REFRESH_TOKEN_REUSED` | 401 | Refresh-токен уже использован — сессия сброшена |
| `OAUTH_ACCOUNT_REQUIRED` | 401 | Аккаунт создан через OAuth, пароль не задан |
| `OAUTH_PROFILE_INCOMPLETE` | 401 | Google-профиль не содержит email |
| `OAUTH_FAILED` | 401 | Ошибка аутентификации через Google |
| `VALIDATION_FAILED` | 400 | Ошибки валидации полей |
| `INTERNAL_ERROR` | 500 | Инфраструктурная ошибка (БД, внешний сервис) |

---

## Фабрика `AppError`

**Единственный способ создать ошибку в проекте.** Никогда не создавайте объект ошибки вручную.

### `AppError.create(code, details?)` — универсальный метод

TypeScript по коду автоматически выводит, какой `details` обязателен. Неверные поля — compile error.

```ts
// Без details (undefined в registry) — все auth/token/oauth коды
AppError.create(DomainErrorCode.TOKEN_EXPIRED)
AppError.create(DomainErrorCode.INVALID_PASSWORD)
AppError.create(DomainErrorCode.REFRESH_TOKEN_REUSED)
AppError.create(DomainErrorCode.OAUTH_ACCOUNT_REQUIRED)

// С обязательным details
AppError.create(DomainErrorCode.RESOURCE_NOT_FOUND, {
  entity: EntityRegistry.USER,
  identifier: id,
  field: "email",       // опционально — указывает по какому полю искали
})
```

### Хелперы для типовых CRUD-ошибок

Сокращают повторяющийся код в сервисах. Под капотом — те же вызовы `AppError.create`.

```ts
// Запись не найдена
AppError.notFound(entity, identifier, field?)
// → AppError.create(RESOURCE_NOT_FOUND, { entity, identifier, field })

// Нарушение уникальности
AppError.alreadyExists(entity, field, value)
// → AppError.create(RESOURCE_ALREADY_EXISTS, { entity, field, value })

// FK-ссылка не найдена
AppError.referenceNotFound(entity, reference, value)
// → AppError.create(REFERENCE_NOT_FOUND, { entity, reference, value })

// Инфраструктурная ошибка (DB-запрос упал)
AppError.internalFailure(action)
// → AppError.create(INTERNAL_ERROR, { action })
```

### Использование с `neverthrow`

```ts
import { errAsync, okAsync } from "neverthrow";
import { AppError } from "@/common/domain/error/app-error.factory";

// В ResultAsync-цепочке
return this.repository.findById(id)
  .andThen((user) =>
    user
      ? okAsync(user)
      : errAsync(AppError.notFound(EntityRegistry.USER, id))
  );

// Как callback в fromPromise
return ResultAsync.fromPromise(
  this.hashingService.hash(password),
  () => AppError.internalFailure(ErrorActions.USERS.HASH_PASSWORD),
);

// Бросок (в guards, pipes, strategies)
throw AppError.create(DomainErrorCode.TOKEN_INVALID);
throw AppError.create(DomainErrorCode.CSRF_TOKEN_INVALID);
```

---

## Словарь строк `error-vocabulary.ts`

**Никогда не пишите строки inline** в вызовах `AppError`. Все строки должны жить в словаре.

### `ErrorReasons` — для поля `reason`

Используется **только** в `BUSINESS_RULE_VIOLATION` — для объяснения нарушённого бизнес-правила. Auth/token/OAuth коды самодостаточны и не принимают `reason`.

```ts
import { ErrorReasons } from "@/common/domain/error/error-vocabulary";

AppError.create(DomainErrorCode.BUSINESS_RULE_VIOLATION, {
  entity: EntityRegistry.USER,
  rule: "no-self-delete",
  reason: ErrorReasons.USERS.NO_SELF_DELETE,
});
```

TypeScript принимает **только строки из словаря** — произвольная строка вызовет compile error:

```ts
// ❌ Compile error
AppError.create(DomainErrorCode.BUSINESS_RULE_VIOLATION, {
  entity: EntityRegistry.USER,
  rule: "some-rule",
  reason: "Some random string",
});

// ✅ OK
AppError.create(DomainErrorCode.BUSINESS_RULE_VIOLATION, {
  entity: EntityRegistry.WORD,
  rule: "relation-same-word",
  reason: ErrorReasons.WORDS.RELATION_SAME_WORD,
});
```

### `ErrorActions` — для поля `action` в `INTERNAL_ERROR`

Используется для операций **без привязки к сущности** (auth, hashing). Для стандартных CRUD-операций используйте `AppAction`.

```ts
import { ErrorActions } from "@/common/domain/error/error-vocabulary";
import { AppAction } from "@/common/domain/registry/action.registry";

// Специфичная операция — из словаря
AppError.internalFailure(ErrorActions.AUTH.GENERATE_TOKENS);
AppError.internalFailure(ErrorActions.USERS.HASH_PASSWORD);

// Стандартная CRUD-операция — AppAction (работает для любой сущности)
AppError.internalFailure(AppAction.FIND_ONE);
AppError.internalFailure(AppAction.CREATE);
```

Сообщение пользователю: `"Failed to {action}. Please try again later."`

### `dbErrorAction` — для динамических DB-ошибок

Когда `action` зависит от имени сущности:

```ts
import { dbErrorAction } from "@/common/domain/error/error-vocabulary";

AppError.create(DomainErrorCode.INTERNAL_ERROR, {
  action: dbErrorAction.save(entity),       // "save Language"
  reason: ErrorReasons.DB.REQUIRED_FIELD_MISSING,
  nativeCode: err.code,
});
```

---

## HTTP-ответ (RFC 7807 Problem Details)

Все ошибки возвращаются в едином формате:

```json
{
  "type": "https://errors.example.com/resource-not-found",
  "title": "Not Found",
  "status": 404,
  "detail": "User with email 'test@mail.com' was not found",
  "instance": "/api/users",
  "errorCode": "RESOURCE_NOT_FOUND"
}
```

| Поле | Источник | Назначение |
|------|----------|-----------|
| `type` | `errorsBaseUrl` + slug из кода | URI-идентификатор типа ошибки |
| `title` | `HTTP_STATUS_TITLES` | Человекочитаемый HTTP-статус |
| `status` | `DOMAIN_ERROR_CODE_TO_HTTP` | HTTP-код |
| `detail` | `IAppError.message` → `messageResolver` | Сообщение для пользователя |
| `instance` | URL запроса | Какой эндпоинт упал |
| `errorCode` | `DomainErrorCode` | Машиночитаемый код — для ветвления на фронте |

Для `VALIDATION_FAILED` добавляется дополнительное поле:

```json
{
  "status": 400,
  "errorCode": "VALIDATION_FAILED",
  "detail": "Validation failed",
  "validationErrors": [
    { "field": "email", "constraints": ["email must be an email"] },
    { "field": "password", "constraints": ["password is too short"] }
  ]
}
```

---

## Как добавить новый сценарий ошибки

### Сценарий A: существующий код, новая причина для BUSINESS_RULE_VIOLATION

Добавьте строку в словарь и используйте её:

```ts
// error-vocabulary.ts
export const ErrorReasons = {
  USERS: {
    NO_SELF_DELETE: "...",
    ACCOUNT_SUSPENDED: "Your account has been suspended.",  // ← добавили
  },
};

// В сервисе
AppError.create(DomainErrorCode.BUSINESS_RULE_VIOLATION, {
  entity: EntityRegistry.USER,
  rule: "account-suspended",
  reason: ErrorReasons.USERS.ACCOUNT_SUSPENDED,
});
```

### Сценарий B: нужен новый код ошибки

1. Добавьте код в `domain-error-code.enum.ts`:

```ts
export enum DomainErrorCode {
  // ...
  QUOTA_EXCEEDED = "QUOTA_EXCEEDED",
}
```

2. Добавьте тип payload в `error-details-registry.ts`:

```ts
[DomainErrorCode.QUOTA_EXCEEDED]: {
  entity: EntityName;
  limit: number;
};
```

3. Добавьте `messageResolver` в `error-definitions.ts`:

```ts
[DomainErrorCode.QUOTA_EXCEEDED]: {
  type: ErrorType.BUSINESS,
  messageResolver: (d) => `${d.entity} quota of ${d.limit} exceeded`,
},
```

4. Добавьте HTTP-статус в `domain-error-code-to-http.map.ts`:

```ts
[DomainErrorCode.QUOTA_EXCEEDED]: HttpStatus.TOO_MANY_REQUESTS,
```

5. Используйте:

```ts
AppError.create(DomainErrorCode.QUOTA_EXCEEDED, {
  entity: EntityRegistry.WORD,
  limit: 1000,
});
```

### Сценарий C: новая сущность

Только добавьте её в `entity.registry.ts` (или перегенерируйте через `npm run generate:registry`). Никаких изменений в системе ошибок не требуется — коды generic, entity передаётся как данные.

---

## Чего не делать

```ts
// ❌ Создавать объект вручную
const error = { type: "BUSINESS", code: "NOT_FOUND", message: "..." };

// ❌ Бросать NestJS-исключения в домен
throw new NotFoundException("User not found");

// ❌ Писать строки inline
AppError.create(DomainErrorCode.UNAUTHORIZED, { reason: "Some message" });

// ❌ Создавать второй экземпляр фабрики или обёртку над AppError
const MyErrors = { notFound: () => AppError.create(...) };
```

---

## TODO (низкий приоритет)

### 1. Вынести `messageResolver` из доменного слоя

**Проблема:** сообщения (`messageResolver`) живут в domain-слое, хотя это зона ответственности presentation-слоя. При необходимости i18n потребуется рефакторинг.

**Решение:** переместить резолверы в фильтр или отдельный mapper-слой; доменный `IAppError` будет нести только `code` и `details`, а сообщение строить фильтр по локали запроса.

### 2. Расширить `AppError.internalFailure` для полной поддержки `INTERNAL_ERROR`

**Проблема:** `AppError.internalFailure(action)` покрывает только поле `action`. Поля `reason` и `nativeCode` доступны только через `AppError.create(DomainErrorCode.INTERNAL_ERROR, { ... })` напрямую.

**Решение:** добавить опциональные параметры или принять объект `{ action, reason?, nativeCode? }`:

```ts
// Вариант
AppError.internalFailure({ action: "save User", nativeCode: err.code })
```
