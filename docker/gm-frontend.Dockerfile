FROM node:22-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --legacy-peer-deps

# Код монтируется из хоста

EXPOSE 4200

CMD ["npm", "start"]
