# ============================================================
# mosgarage/code-server — Home Base Docker Image
# Includes: code-server | Node.js 20 LTS | Express API | PM2
#           GitHub auto-sync (git-setup + git-sync daemon)
# ============================================================

FROM ubuntu:22.04

LABEL maintainer="mosgarage"
LABEL org.opencontainers.image.source="https://github.com/mosgarage/code-server"
LABEL image="docker.io/mosgarage/code-server"
LABEL description="mosgarage home base: code-server + node server + API + GitHub sync"

# ── Prevent interactive prompts ──────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ── Service ports ─────────────────────────────────────────────
ENV CODE_SERVER_PORT=8080
ENV NODE_SERVER_PORT=3000
ENV API_PORT=4000

# ── Auth ──────────────────────────────────────────────────────
ENV CODE_SERVER_PASSWORD=mosgarage
ENV API_KEY=

# ── GitHub sync ───────────────────────────────────────────────
ENV GITHUB_USER=mosgaragedev
ENV GITHUB_ORG=mosgarage
ENV GITHUB_REPO=code-server
ENV GITHUB_TOKEN=
ENV GIT_BRANCH=main
ENV GIT_NAME=mosgaragedev
ENV GIT_EMAIL=mosgaragedev@users.noreply.github.com
ENV GIT_SYNC_INTERVAL=900

# ── Paths ─────────────────────────────────────────────────────
ENV HOME_DIR=/home/mosgarage
ENV APP_DIR=/app
ENV NODE_ENV=production

# ── Base system packages ─────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    python3 \
    python3-pip \
    supervisor \
    openssh-client \
    inotify-tools \
    unzip \
    zip \
    jq \
    htop \
    nano \
    vim \
    net-tools \
    iputils-ping \
    dnsutils \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 20 LTS ───────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && npm install -g pm2 \
    && npm install -g typescript \
    && npm install -g ts-node \
    && rm -rf /var/lib/apt/lists/*

# ── code-server (VS Code in browser) ─────────────────────────
RUN curl -fsSL https://code-server.dev/install.sh | sh \
    && rm -rf /var/lib/apt/lists/*

# ── Create user & directories ─────────────────────────────────
RUN useradd -m -s /bin/bash mosgarage \
    && mkdir -p ${APP_DIR}/server \
    && mkdir -p ${APP_DIR}/api \
    && mkdir -p ${APP_DIR}/workspace \
    && mkdir -p ${HOME_DIR}/.config/code-server \
    && mkdir -p ${HOME_DIR}/.ssh \
    && mkdir -p /var/log/mosgarage

# ── Configs ───────────────────────────────────────────────────
COPY config/code-server-config.yaml ${HOME_DIR}/.config/code-server/config.yaml
COPY config/supervisord.conf        /etc/supervisor/conf.d/mosgarage.conf

# ── Node server ───────────────────────────────────────────────
COPY server/package.json  ${APP_DIR}/server/
COPY server/index.js      ${APP_DIR}/server/
COPY server/routes/       ${APP_DIR}/server/routes/

# ── API server ────────────────────────────────────────────────
COPY api/package.json     ${APP_DIR}/api/
COPY api/index.js         ${APP_DIR}/api/
COPY api/routes/          ${APP_DIR}/api/routes/
COPY api/middleware/      ${APP_DIR}/api/middleware/

# ── PM2 ecosystem ─────────────────────────────────────────────
COPY config/ecosystem.config.js ${APP_DIR}/

# ── Install Node deps ─────────────────────────────────────────
RUN cd ${APP_DIR}/server && npm install --omit=dev \
    && cd ${APP_DIR}/api  && npm install --omit=dev

# ── Scripts → /usr/local/bin ──────────────────────────────────
COPY scripts/startup.sh        /usr/local/bin/startup
COPY scripts/git-setup.sh      /usr/local/bin/git-setup
COPY scripts/git-sync.sh       /usr/local/bin/git-sync
COPY scripts/git-push-now.sh   /usr/local/bin/git-push-now
COPY scripts/git-status.sh     /usr/local/bin/git-status

RUN chmod +x \
    /usr/local/bin/startup \
    /usr/local/bin/git-setup \
    /usr/local/bin/git-sync \
    /usr/local/bin/git-push-now \
    /usr/local/bin/git-status

# ── Workspace welcome file ────────────────────────────────────
COPY scripts/welcome.md ${APP_DIR}/workspace/WELCOME.md

# ── Fix permissions ───────────────────────────────────────────
RUN chown -R mosgarage:mosgarage ${APP_DIR} ${HOME_DIR} /var/log/mosgarage \
    && chmod 700 ${HOME_DIR}/.ssh

# ── Ports ─────────────────────────────────────────────────────
#   8080 → code-server
#   3000 → node-server (HTTP + WebSocket)
#   4000 → api-server  (REST)
EXPOSE 8080 3000 4000

WORKDIR ${APP_DIR}

CMD ["/usr/local/bin/startup"]
