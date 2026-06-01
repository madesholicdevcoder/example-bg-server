FROM node:20-slim
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY imagine-worker-v2-fixed.js ./imagine-worker-v2-fixed.js
COPY server.js ./server.js
EXPOSE 3000
CMD ["node", "server.js"]
