FROM node:18-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json* ./

RUN npm ci --omit=dev 2>/dev/null || npm install --omit=dev

FROM node:18-alpine

LABEL maintainer="CCIP NFT Bridge Team"
LABEL description="Chainlink CCIP Cross-Chain NFT Bridge CLI"

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules

COPY . .

RUN mkdir -p logs data

CMD ["tail", "-f", "/dev/null"]
