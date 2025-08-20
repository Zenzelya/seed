FROM node:22-alpine

# Аргументы для передачи UID и GID с хоста
ARG UID=1000
ARG GID=1000
RUN echo "UID=${UID}, GID=${GID}"

# 1. Удаляем стандартного пользователя/группу 'node', чтобы избежать конфликтов,
#    и создаем их заново с UID/GID вашего пользователя.
#    Проверяем существование пользователя/группы перед удалением.
RUN if getent passwd node; then deluser --remove-home node; fi && \
    if getent group node; then delgroup node; fi && \
    addgroup -g ${GID} node && \
    adduser -u ${UID} -G node -s /bin/sh -D node

# Устанавливаем рабочую директорию и делаем node владельцем
WORKDIR /app
RUN chown node:node /app

# 2. Копируем только файлы зависимостей и меняем их владельца
#    Это улучшает кеширование Docker.
COPY --chown=node:node package*.json ./

# Переключаемся на пользователя node ДО установки зависимостей
USER node

# 4. Устанавливаем зависимости уже от имени пользователя 'node'
RUN npm ci

# 5. Копируем остальной код приложения (он автоматически будет принадлежать пользователю 'node')
COPY --chown=node:node . .

# Открываем порты
EXPOSE 3000
EXPOSE 9230

# Запускаем приложение
CMD ["sh", "-c", "echo 'Start debugging...' && npm run start:dev"]
