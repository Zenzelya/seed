# backend.Dockerfile
FROM node:22-alpine

ARG UID=1000
ARG GID=1000

RUN if getent passwd node; then deluser --remove-home node; fi && \
    if getent group node; then delgroup node; fi && \
    addgroup -g ${GID} node && \
    adduser -u ${UID} -G node -s /bin/sh -D node

WORKDIR /app
RUN chown node:node /app

ENV PATH="/app/node_modules/.bin:$PATH"

USER node

EXPOSE 3000
EXPOSE 9230

CMD ["yarn", "start:dev"]