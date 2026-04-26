# syntax=docker/dockerfile:1.7

ARG OPENCLAW_EXTENSIONS=""
ARG OPENCLAW_VARIANT=default
ARG OPENCLAW_BUNDLED_PLUGIN_DIR=extensions
ARG OPENCLAW_DOCKER_APT_UPGRADE=1

# ---------- Extension Dependencies ----------
FROM node:24-bookworm AS ext-deps
ARG OPENCLAW_EXTENSIONS
ARG OPENCLAW_BUNDLED_PLUGIN_DIR
RUN --mount=type=bind,source=${OPENCLAW_BUNDLED_PLUGIN_DIR},target=/tmp/${OPENCLAW_BUNDLED_PLUGIN_DIR},readonly \
    mkdir -p /out && \
    for ext in $OPENCLAW_EXTENSIONS; do \
      if [ -f "/tmp/${OPENCLAW_BUNDLED_PLUGIN_DIR}/$ext/package.json" ]; then \
        mkdir -p "/out/$ext" && \
        cp "/tmp/${OPENCLAW_BUNDLED_PLUGIN_DIR}/$ext/package.json" "/out/$ext/package.json"; \
      fi; \
    done

# ---------- BUILD ----------
FROM node:24-bookworm AS build

# Install bun (required)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# Copy files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY . .

# Install dependencies
RUN NODE_OPTIONS=--max-old-space-size=2048 pnpm install --frozen-lockfile

# Build
RUN pnpm build:docker
RUN pnpm ui:build

# ---------- RUNTIME ----------
FROM node:24-bookworm-slim

WORKDIR /app

# Install required packages
RUN apt-get update && apt-get install -y \
    curl git openssl && rm -rf /var/lib/apt/lists/*

# Copy built app
COPY --from=build /app /app

ENV NODE_ENV=production

# Use non-root user
USER node

# Expose port
EXPOSE 18789

# Start server (Railway compatible) - with allowed origins fix
CMD ["sh", "-c", "node openclaw.mjs gateway --allow-unconfigured --port=$PORT --bind=lan --control-ui-allowed-origins=https://openclaw-production-11c4.up.railway.app"]
