# mosgarage/mosgarage · Home Base Docker Image

> Unified cloud dev environment: **code-server** + **Node server** + **REST API** + **GitHub auto-sync** — one container, everything wired.

**Docker Hub:** `docker.io/mosgarage/mosgarage`
**GitHub:** `github.com/mosgarage/mosgaragedev` (user: `mosgaragedev`)

---

## Project Structure

```
mosgarage/
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── config/
│   ├── supervisord.conf       # Manages all processes incl. git-setup, git-sync
│   ├── code-server-config.yaml
│   └── ecosystem.config.js
├── server/                    # Node.js HTTP + WebSocket  (port 3000)
├── api/                       # Express REST API          (port 4000)
├── ssh-keys/                  # Created by gen-deploy-key.sh (gitignored)
└── scripts/
    ├── startup.sh             # Container entrypoint
    ├── git-setup.sh           # Boot: clone/pull repo into workspace
    ├── git-sync.sh            # Daemon: auto-commit + push every N seconds
    ├── git-push-now.sh        # Force immediate sync
    ├── git-status.sh          # Sync state at a glance
    ├── gen-deploy-key.sh      # Generate SSH deploy key (run on host)
    ├── build-push.sh          # Build and push to docker.io
    └── run.sh                 # Quick run without Compose
```

---

## Quick Start

**Step 1 — Configure**

```bash
cp .env.example .env
nano .env   # set CODE_SERVER_PASSWORD and GITHUB_TOKEN
```

**Step 2 — GitHub auth (choose one)**

Option A — Personal Access Token (easiest):
1. github.com → Settings → Developer settings → Personal access tokens
2. Create token with `repo` + `workflow` scopes
3. Set `GITHUB_TOKEN=ghp_...` in `.env`

Option B — SSH Deploy Key (more secure):
```bash
chmod +x scripts/gen-deploy-key.sh && ./scripts/gen-deploy-key.sh
# Follow printed instructions to add public key to GitHub
# Then uncomment the SSH volume in docker-compose.yml
```

**Step 3 — Build, push, run**

```bash
./scripts/build-push.sh          # build + push to docker.io/mosgarage/mosgarage
docker compose up -d             # start all services
docker compose logs -f           # watch logs
```

---

## Ports

| Port | Service |
|------|---------|
| 8080 | code-server (VS Code in browser) |
| 3000 | node-server (HTTP + WebSocket) |
| 4000 | api-server (REST /api/v1/...) |

---

## GitHub Sync Flow

```
Boot → [git-setup] clone/pull workspace from GitHub
     → [git-sync daemon] every GIT_SYNC_INTERVAL seconds:
           fetch + merge  →  git add -A  →  commit  →  push
     → also responds to: touch /tmp/mosgarage-git-push-now
```

**Sync commands:**

```bash
docker exec mosgarage git-push-now      # immediate push
docker exec mosgarage git-status        # sync overview
docker exec mosgarage tail -f /var/log/mosgarage/git-sync.log
```

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| CODE_SERVER_PASSWORD | mosgarage | VS Code browser password |
| CODE_SERVER_PORT | 8080 | code-server port |
| NODE_SERVER_PORT | 3000 | node-server port |
| API_PORT | 4000 | api-server port |
| API_KEY | (empty) | REST API key, blank = open |
| GITHUB_USER | mosgaragedev | GitHub username |
| GITHUB_ORG | mosgarage | GitHub org/owner |
| GITHUB_REPO | mosgaragedev | Repo name |
| GITHUB_TOKEN | (empty) | PAT for HTTPS auth |
| GIT_BRANCH | main | Branch to sync |
| GIT_NAME | mosgaragedev | Commit author name |
| GIT_EMAIL | mosgaragedev@users.noreply.github.com | Commit email |
| GIT_SYNC_INTERVAL | 900 | Seconds between syncs |

---

## Useful Commands

```bash
docker exec mosgarage supervisorctl status          # all service statuses
docker exec mosgarage supervisorctl restart git-sync
docker exec mosgarage supervisorctl restart node-server
docker exec -it mosgarage bash                      # shell into container
```
