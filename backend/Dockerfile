FROM node:20-alpine

WORKDIR /app

# Copy package files first (layer cache)
COPY package*.json ./
RUN npm ci --only=production

# Copy source
COPY . .

# Remove example env — real env must be injected at runtime
RUN rm -f .env.example

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD wget -qO- http://localhost:5000/health || exit 1

CMD ["node", "server.js"]
