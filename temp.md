
---

# Архитектурные правила разработки (Nest.js)

## Сводная таблица стандартов

| Системный элемент | Реализация (Nest.js / Class) | Кастомная логика / Библиотека | Вывод и правило для LLM |
| :--- | :--- | :--- | :--- |
| **Бизнес-логика** | `@Injectable() class NameService` | `neverthrow` (ResultAsync) | **Обязательно.** Каждый метод сервиса обязан возвращать `ResultAsync<T, AppError>`. Запрещено использовать `throw new Error`. |
| **Обработка ошибок** | Exception Filters | `AppErrors` (Factory) | **Использовать.** Контроллер разворачивает `Result` через хелпер `unwrapResult`. Все ошибки должны быть типизированы в `AppError`. |
| **Доступ к данным** | TypeORM Repository | `BaseRepository` паттерн | **Стандарт.** Использовать `@InjectRepository`. Все запросы к БД оборачивать в `ResultAsync.fromPromise` с обработкой специфичных кодов ошибок (напр. 23505). |
| **Валидация** | DTO + `class-validator` | `plainToInstance` | **Строго.** Все входящие данные в контроллер и исходящие ответы (ResponseDTO) должны быть жестко типизированы и валидированы. |
| **Тестирование** | Jest | `MockType<T>` | **Обязательно.** Для каждого метода сервиса генерировать `.spec.ts` файл с полным моком репозиториев и внешних зависимостей. |
| **Маппинг данных** | Внутри Service | Private methods (`toResponse`) | **Упростить.** Для ускорения прототипирования маппинг сущности в `ResponseDTO` реализовать через приватный метод `toResponse` внутри того же сервиса. |
| **Связи в БД** | TypeORM Entities | `{ eager: true }` | **Скорость.** Для прототипа использовать жадную загрузку (Eager Relations) для всех ключевых связей, чтобы упростить выборку данных. |

---
**Бизнес-логика**

## Подробные инструкции по реализации

### 1. Обработка ошибок (Functional Error Handling)
Мы не используем `try/catch` для управления бизнес-исключениями. Вместо этого используется библиотека `neverthrow`.
* **Правило:** Сервис возвращает объект результата.
* **Пример:**
    ```typescript
    public async findAll(): ResultAsync<UserEntity[], AppError> {
      return ResultAsync.fromPromise(
        this.repository.find(),
        (error) => AppError.DatabaseError(error)
      );
    }
    ```

### 2. Слой контроллеров
Контроллеры отвечают за вызов сервиса и "распаковку" результата для передачи клиенту.
* Использовать хелпер `unwrapResult` для преобразования `Result` в HTTP-ответ или выброса исключения через Exception Filter.

### 3. Работа с базой данных
* Все взаимодействия с TypeORM должны быть изолированы.
* Ошибки базы данных (например, нарушение уникальности `23505`) должны быть перехвачены на уровне репозитория/сервиса и превращены в типизированный `AppError.Conflict()`.

### 4. Тестирование
Для каждого создаваемого сервиса необходимо создавать файл модульных тестов:
* Использовать `Jest`.
* Все внешние зависимости (репозитории, другие сервисы) должны быть замоканы с использованием `MockType`.

### 5. Оптимизация разработки (Прототипирование)
Для ускорения темпов разработки на текущем этапе:
* **Mapping:** Не использовать тяжелые мапперы. Достаточно приватного метода `toResponse(entity: T): ResponseDTO` внутри сервиса.
* **Relations:** Включать `eager: true` в декораторах отношений Entity, если данные почти всегда требуются вместе.

---


## Specification: EventEmitter vs. Circular Dependency
**Core Concept:** Replacing direct service coupling (Dependency Injection) with an asynchronous event bus.
---
### ❌ What NOT to do
* **Inject Service B into Service A** if Service A is already injected into Service B.
* **Use `forwardRef`** as a "silver bullet" solution for general business logic.
* **Create module import chains** that form a loop (circular references).
---
### ✅ What TO do
* **Create an Event Class:** Use DTOs (Data Transfer Objects) containing only data and zero logic.
* **Emitter:** Call `this.eventEmitter.emit('event.name', payload)` within Service A.
* **Listener:** Use the `@OnEvent('event.name')` decorator within Service B.
* **Loose Coupling:** Module A should have no knowledge of Module B's existence.
---
### Example (Strict Mode)
#### Event:
```typescript
export class OrderCreatedEvent {
  constructor(public readonly id: number) {}
}
```
#### Publisher (OrdersService):
```typescript
@Injectable()
export class OrdersService {
  constructor(private eventEmitter: EventEmitter2) {}

  create() {
    this.eventEmitter.emit('order.created', new OrderCreatedEvent(1));
  }
}
```
#### Subscriber (StockService):
```typescript
@Injectable()
export class StockService {
  @OnEvent('order.created')
  handleOrder(event: OrderCreatedEvent) {
    /* logic goes here */
  }
}
```