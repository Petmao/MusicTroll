FROM node:20-alpine
WORKDIR /app
RUN apk add --no-cache python3 make g++
COPY package.json ./
RUN npm install --omit=dev && apk del python3 make g++
COPY . .
ENV PORT=8787 \
    DB_PATH=/data/data.db \
    AVATAR_DIR=/data/avatars
VOLUME ["/data"]
EXPOSE 8787
CMD ["node","server.js"]
