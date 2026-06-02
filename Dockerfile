FROM node:20-slim

WORKDIR /app

# Force cache bust
ARG BUILD_DATE=unknown
LABEL build_date=$BUILD_DATE

COPY package.json ./
RUN npm install --production

COPY imagine-worker-latest.js ./

EXPOSE 3000

CMD ["node", "imagine-worker-latest.js"]
