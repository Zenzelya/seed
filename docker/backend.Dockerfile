FROM node:22-alpine

# Аргументы для передачи UID и GID с хоста
ARG UID=1000
ARG GID=1000
RUN echo "UID=${UID}, GID=${GID}"

# 1. Удаляем стандартного пользователя/группу 'node', чтобы избежать конфликтов,
#    и создаем их заново с UID/GID вашего пользователя.
RUN if getent passwd node; then deluser --remove-home node; fi && \
    if getent group node; then delgroup node; fi && \
    addgroup -g ${GID} node && \
    adduser -u ${UID} -G node -s /bin/sh -D node

# Устанавливаем рабочую директорию и делаем node владельцем
WORKDIR /app
RUN chown node:node /app

# Переключаемся на пользователя node
USER node

# Открываем порты
EXPOSE 3000
EXPOSE 9230

# node_modules монтируются с хоста через volume.
# yarn install запускается при старте контейнера, чтобы подхватить новые зависимости.
CMD ["sh", "-c", "rm -rf node_modules && yarn install && echo 'Start debugging...' && yarn start:dev"]
