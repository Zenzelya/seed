# Monorepo — инфраструктура

Один репозиторий — инфраструктура для всех проектов.  
Улучшения в `bin/` и `docker/` применяются ко всем проектам после `git pull`.

---

## Структура

```
bin/
  setup.sh          — первичная настройка машины и проекта
  doc               — управление контейнерами (устанавливается глобально)
  lib-ports.sh      — логика портов (sourced setup.sh и reset-ports.sh)
  reset-ports.sh    — пересчёт портов вручную
  backend.env       — шаблон backend/.env
  frontend-angular.env  — шаблон frontend/.env для Angular
  frontend-nextjs.env   — шаблон frontend/.env для Next.js
  clone_projects.sh — клонирование репозиториев сервисов

docker/
  fragments/        — YAML-блоки сервисов для сборки docker-compose.yml
  *.Dockerfile      — образы сервисов

.env.example        — шаблон переменных (в гите)
```

**Не в гите (генерируется):** `docker-compose.yml`, `.env`, `backend/.env`, `frontend/.env`

---

## Первичная настройка

```bash
git clone <repo> myproject
cd myproject
bin/setup.sh
```

`setup.sh` выполняет:
1. Устанавливает Docker Engine, lazydocker, nvm/Node
2. Показывает меню сервисов — вводишь нужные через `+`:
   ```
   0 — backend   (NestJS)
   1 — frontend  (Angular)   порт 4200
   2 — frontend  (Next.js)   порт 3000
   3 — fastapi   (parser)
   4 — postgres
   5 — redis

   Ввод: 0+1+3+4
   ```
3. Находит свободный слот портов (не конфликтует с другими проектами)
4. Генерирует `.env`, `docker-compose.yml`, `backend/.env`
5. Клонирует репозитории сервисов

---

## Команды doc

Запускать из корня проекта (там где лежит `docker-compose.yml`):

```bash
doc all          # запустить все сервисы
doc rebuild      # пересобрать образы и перезапустить
doc stop         # остановить контейнеры (данные сохраняются)
doc down         # удалить контейнеры и сети (volumes сохраняются)
doc down:app     # удалить app-контейнеры, оставить db и redis
doc nuke         # полное удаление с volumes [требует подтверждения]

doc api          # терминал в backend-контейнере
doc front        # терминал в frontend-контейнере
doc fast         # терминал в parser-контейнере
doc db           # терминал в postgres
doc redis        # терминал в redis
doc logs [svc]   # логи всех или конкретного сервиса
doc ui           # lazydocker
```

`doc all` и `doc rebuild` автоматически проверяют порты перед стартом.  
Если порты заняты другим проектом — слот пересчитывается, `.env` и `docker-compose.yml` обновляются.

---

## Порты и несколько проектов

Каждый проект получает уникальный **слот** (N = 0, 1, 2...):

| Слот | DB    | Redis | API  | Debug | Front |
|------|-------|-------|------|-------|-------|
| 0    | 5432  | 6379  | 3000 | 9230  | 4200  |
| 1    | 5433  | 6380  | 3001 | 9231  | 4201  |
| 2    | 5434  | 6381  | 3002 | 9232  | 4202  |

Слоты хранятся в `~/.config/docker-projects.conf`.  
Данные БД привязаны к имени проекта (`tibician_db-data`), не к порту — смена слота данные не удаляет.

Сбросить порты вручную:
```bash
bin/reset-ports.sh       # первый свободный слот
bin/reset-ports.sh 0     # форсировать слот 0
```

---

## Правила развёртывания

**Что коммитить:**
- `docker/fragments/`, `docker/*.Dockerfile` — определения сервисов
- `bin/` — скрипты инфраструктуры
- `.env.example` — шаблон переменных

**Что НЕ коммитить** (в `.gitignore`):
- `docker-compose.yml` — генерируется под конкретный проект
- `.env` — содержит порты и секреты конкретной машины
- `backend/.env`, `frontend/.env` — генерируются из шаблонов

**Новый проект на той же машине:**
```bash
git clone <repo> другой-проект
cd другой-проект
bin/setup.sh   # получит следующий свободный слот автоматически
```

**Обновить инфраструктуру во всех проектах:**
```bash
git pull       # в каждом проекте обновляет bin/ и docker/fragments/
               # локальные .env и docker-compose.yml не затрагиваются
```
