# ============================================================
# mosgarage · Makefile
# Usage: make <target>
# ============================================================

IMAGE     := docker.io/mosgarage/mosgarage
CONTAINER := mosgarage
VERSION   ?= latest

.PHONY: help build push run stop shell logs status git-sync git-status \
        clean deploy key setup-secrets update

# ── Default ───────────────────────────────────────────────────
help:
	@echo ""
	@echo "╔══════════════════════════════════════════════════╗"
	@echo "║  mosgarage · Makefile targets                    ║"
	@echo "╠══════════════════════════════════════════════════╣"
	@echo "║  make setup          First-time setup            ║"
	@echo "║  make build          Build Docker image          ║"
	@echo "║  make push           Push to docker.io           ║"
	@echo "║  make deploy         Build + push + up           ║"
	@echo "║  make up             docker compose up -d        ║"
	@echo "║  make down           docker compose down         ║"
	@echo "║  make restart        Restart container           ║"
	@echo "║  make shell          Shell into container        ║"
	@echo "║  make logs           Follow all logs             ║"
	@echo "║  make status         Container + git status      ║"
	@echo "║  make git-sync       Force git push now          ║"
	@echo "║  make git-status     Show git sync status        ║"
	@echo "║  make key            Generate SSH deploy key     ║"
	@echo "║  make update         Pull latest & restart       ║"
	@echo "║  make clean          Remove volumes + images     ║"
	@echo "╚══════════════════════════════════════════════════╝"
	@echo ""

# ── First-time setup ──────────────────────────────────────────
setup:
	@[[ -f .env ]] || { cp .env.example .env; echo "✅ .env created — edit it now!"; }
	@[[ -x scripts/gen-deploy-key.sh ]] && chmod +x scripts/*.sh || true
	@echo "Next: edit .env, then run: make deploy"

# ── Build ─────────────────────────────────────────────────────
build:
	@echo "🔨 Building $(IMAGE):$(VERSION)..."
	docker build \
	  --platform linux/amd64 \
	  --tag $(IMAGE):$(VERSION) \
	  --tag $(IMAGE):latest \
	  --label "build.date=$$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
	  --label "build.commit=$$(git rev-parse --short HEAD 2>/dev/null || echo dev)" \
	  .
	@echo "✅ Build complete"

# ── Multi-arch build + push ───────────────────────────────────
push:
	@echo "🚀 Building multi-arch and pushing to Docker Hub..."
	docker buildx build \
	  --platform linux/amd64,linux/arm64 \
	  --tag $(IMAGE):$(VERSION) \
	  --tag $(IMAGE):latest \
	  --push \
	  .
	@echo "✅ Pushed $(IMAGE):$(VERSION)"

# ── Compose operations ────────────────────────────────────────
up:
	@[[ -f .env ]] || { echo "❌ .env missing — run: make setup"; exit 1; }
	docker compose up -d
	@echo "✅ mosgarage is running"
	@echo "   https://localhost  (Nginx — all services)"
	@echo "   http://localhost:8080  (code-server direct)"

down:
	docker compose down

restart:
	docker compose restart mosgarage

deploy: push up
	@echo "✅ Deploy complete"

# ── Management ────────────────────────────────────────────────
shell:
	docker exec -it $(CONTAINER) bash

logs:
	docker compose logs -f $(CONTAINER)

log-git:
	docker exec $(CONTAINER) tail -f /var/log/mosgarage/git-sync.log

log-api:
	docker exec $(CONTAINER) tail -f /var/log/mosgarage/api-server.log

log-nginx:
	docker exec $(CONTAINER) tail -f /var/log/mosgarage/nginx-access.log

status:
	@echo ""
	@docker ps --filter name=$(CONTAINER) --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@docker exec $(CONTAINER) supervisorctl status 2>/dev/null || true
	@echo ""

git-sync:
	docker exec $(CONTAINER) git-push-now

git-status:
	docker exec $(CONTAINER) git-status

# ── SSH deploy key ────────────────────────────────────────────
key:
	@chmod +x scripts/gen-deploy-key.sh
	@./scripts/gen-deploy-key.sh

# ── Auto-update (pull latest image) ──────────────────────────
update:
	docker compose pull
	docker compose up -d --force-recreate
	@echo "✅ Updated to latest image"

# ── GitHub secrets helper ─────────────────────────────────────
setup-secrets:
	@command -v gh >/dev/null || { echo "❌ Install GitHub CLI: https://cli.github.com"; exit 1; }
	@[[ -n "$$DOCKERHUB_USERNAME" ]] || { echo "❌ Set DOCKERHUB_USERNAME env var"; exit 1; }
	@[[ -n "$$DOCKERHUB_TOKEN"    ]] || { echo "❌ Set DOCKERHUB_TOKEN env var"; exit 1; }
	gh secret set DOCKERHUB_USERNAME --body "$$DOCKERHUB_USERNAME" --repo mosgarage/mosgaragedev
	gh secret set DOCKERHUB_TOKEN    --body "$$DOCKERHUB_TOKEN"    --repo mosgarage/mosgaragedev
	@echo "✅ GitHub secrets set for mosgarage/mosgaragedev"

# ── Clean ─────────────────────────────────────────────────────
clean:
	@echo "⚠️  This removes all volumes (data will be lost)!"
	@read -p "  Are you sure? [y/N] " c && [[ "$$c" == "y" ]] || exit 1
	docker compose down -v
	docker rmi $(IMAGE):latest $(IMAGE):$(VERSION) 2>/dev/null || true
	@echo "🧹 Clean complete"
