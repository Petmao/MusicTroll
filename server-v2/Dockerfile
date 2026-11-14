FROM node:20-alpine

RUN apk add --no-cache python3 make g++ sqlite-dev curl

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund

COPY . .

ENV NODE_ENV=production \
    PORT=8787 \
    DATA_DIR=/data

RUN mkdir -p /data
VOLUME ["/data"]
EXPOSE 8787

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -fs http://127.0.0.1:8787/api/health || exit 1

CMD ["node", "server.js"]
