FROM node:20-slim

WORKDIR /app

COPY package.json ./
RUN npm install --production

COPY imagine-worker-latest.js ./

EXPOSE 3000

CMD ["node", "imagine-worker-latest.js"]
