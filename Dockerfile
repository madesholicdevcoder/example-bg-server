FROM node:20-slim
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY imagine-worker-v3.js ./imagine-worker-v3.js
EXPOSE 3000
CMD ["node", "imagine-worker-v3.js"]
