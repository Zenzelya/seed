# frontend.Dockerfile
FROM node:22-alpine

ARG UID=1000
ARG GID=1000

RUN if getent passwd node; then deluser --remove-home node; fi && \
    if getent group node; then delgroup node; fi && \
    addgroup -g ${GID} node && \
    adduser -u ${UID} -G node -s /bin/sh -D node

WORKDIR /app
RUN mkdir -p /app/node_modules && chown -R node:node /app

ENV PATH="/app/node_modules/.bin:$PATH"

COPY docker/frontend-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node

EXPOSE 4200

ENTRYPOINT ["/entrypoint.sh"]
CMD ["npm", "run", "dev"]
