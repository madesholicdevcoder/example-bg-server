FROM node:20-slim

WORKDIR /app

COPY package.json ./
RUN npm install --production

COPY imagine-worker-v3.js ./

# Environment variables (will be overridden by Railway env vars if set)
ENV SUPABASE_URL=https://vvtiiffhwftiloisywdf.supabase.co
ENV SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2dGlpZmZod2Z0aWxvaXN5d2RmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTMwNzIxNSwiZXhwIjoyMDkwODgzMjE1fQ.QQSzomKoXFYjxy3xohayWraEaefQIohylX13dFW9oaw
ENV WORKER_SECRET=vFXMMRMD-1

EXPOSE 3000

CMD ["node", "imagine-worker-v3.js"]
