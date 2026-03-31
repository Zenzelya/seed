FROM node:22-alpine

WORKDIR /app

# Код и node_modules монтируются с хоста через volume.
# yarn install запускается при старте контейнера, чтобы подхватить новые зависимости.
# node_modules/.bin добавляется в PATH, чтобы локально установленные бинарники (ng) были доступны.
ENV PATH="/app/node_modules/.bin:$PATH"

EXPOSE 4200
EXPOSE 3001


ENTRYPOINT ["/app-docker/frontend-entrypoint.sh"]
CMD ["yarn", "start"]
