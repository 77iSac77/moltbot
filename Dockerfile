FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG CLAWDBOT_DOCKER_APT_PACKAGES=""
RUN if [ -n "$CLAWDBOT_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $CLAWDBOT_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN CLAWDBOT_A2UI_SKIP_MISSING=1 pnpm build
ENV CLAWDBOT_PREFER_PNPM=1
RUN pnpm ui:install
RUN pnpm ui:build

ENV NODE_ENV=production

# Criar diretorios de config
RUN mkdir -p /home/node/.clawdbot \
    && mkdir -p /home/node/clawd/memory \
    && mkdir -p /home/node/clawd/skills \
    && chown -R node:node /home/node/.clawdbot \
    && chown -R node:node /home/node/clawd

# Copiar config
COPY --chown=node:node docker-config/moltbot.json /home/node/.clawdbot/moltbot.json
COPY --chown=node:node docker-config/workspace/ /home/node/clawd/

ENV HOME=/home/node
ENV CLAWDBOT_STATE_DIR=/home/node/.clawdbot
ENV CLAWDBOT_CONFIG_PATH=/home/node/.clawdbot/moltbot.json

EXPOSE 18789

USER node

CMD ["node", "moltbot.mjs", "gateway", "--port", "18789", "--bind", "0.0.0.0"]