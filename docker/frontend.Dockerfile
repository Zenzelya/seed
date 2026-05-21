# frontend.Dockerfile
FROM node:22-alpine

WORKDIR /app
ENV PATH="/app/node_modules/.bin:$PATH"

EXPOSE 4200
EXPOSE 3001

CMD ["yarn", "dev"]