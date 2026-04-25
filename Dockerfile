# syntax=docker/dockerfile:1.7

FROM node:24-bookworm AS build

# Install bun (required)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# Copy files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY . .

# Install dependencies (NO cache mounts)
RUN NODE_OPTIONS=--max-old-space-size=2048 pnpm install --frozen-lockfile

# Build
RUN pnpm build:docker
RUN pnpm ui:build

# ---------- Runtime ----------
FROM node:24-bookworm-slim

WORKDIR /app

# Install required packages (NO cache mounts)
RUN apt-get update && apt-get install -y \
    curl git openssl && rm -rf /var/lib/apt/lists/*

# Copy built app
COPY --from=build /app /app

ENV NODE_ENV=production

# Use non-root user
USER node

# Expose port
EXPOSE 18789

# Start server (Railway compatible)
CMD ["sh", "-c", "node openclaw.mjs gateway --allow-unconfigured --port=$PORT --bind=lan --control-ui-allowed-origins=*"]
