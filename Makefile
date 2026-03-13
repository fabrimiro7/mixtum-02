.PHONY: setup dev dev-d prod stop update-mixtum migrate shell logs restart rebuild hard-rebuild

# Project name = nome cartella, così ogni clone ha i propri container e volumi
COMPOSE_PROJECT_NAME := $(shell basename $(CURDIR))

# ─────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────

setup:
	bash scripts/setup.sh

# ─────────────────────────────────────────
# SVILUPPO LOCALE
# ─────────────────────────────────────────

dev:
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	               -f docker/docker-compose.local.yml \
	               -f docker/docker-compose.override.yml up

dev-d:
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	               -f docker/docker-compose.local.yml \
	               -f docker/docker-compose.override.yml up -d

# ─────────────────────────────────────────
# PRODUZIONE
# ─────────────────────────────────────────

prod:
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	               -f docker/docker-compose.prod.yml up -d

# ─────────────────────────────────────────
# GESTIONE
# ─────────────────────────────────────────

stop:
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	              -f docker/docker-compose.local.yml \
	              -f docker/docker-compose.override.yml down

migrate:
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	              -f docker/docker-compose.local.yml \
	              -f docker/docker-compose.override.yml exec web python manage.py migrate

makemigrations:
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	              -f docker/docker-compose.local.yml \
	              -f docker/docker-compose.override.yml exec web python manage.py makemigrations

shell:
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	              -f docker/docker-compose.local.yml \
	              -f docker/docker-compose.override.yml exec web python manage.py shell

logs:
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	              -f docker/docker-compose.local.yml \
	              -f docker/docker-compose.override.yml logs -f web worker

restart:
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	              -f docker/docker-compose.local.yml \
	              -f docker/docker-compose.override.yml restart web worker beat

# ─────────────────────────────────────────
# REBUILD COMPLETO (non interattivo, NON cancella volumi)
# - Ferma e ricrea i container mantenendo i volumi (DB, Redis, file, ecc.)
# - Re-build immagini (nuovi requirements)
# - Applica migrations
# - Riavvia stack locale
# ─────────────────────────────────────────

rebuild:
	# Ferma e rimuove i container del progetto corrente (mantiene i volumi)
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	               -f docker/docker-compose.local.yml \
	               -f docker/docker-compose.override.yml down
	# Rebuild immagini (include nuovi requirements nel Dockerfile)
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	               -f docker/docker-compose.local.yml \
	               -f docker/docker-compose.override.yml build
	# Avvia servizi (web, worker, beat, db, redis, ecc.)
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	               -f docker/docker-compose.local.yml \
	               -f docker/docker-compose.override.yml up -d
	# Applica migrations sul container web già avviato
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	               -f docker/docker-compose.local.yml \
	               -f docker/docker-compose.override.yml exec web python manage.py migrate

# ─────────────────────────────────────────
# HARD REBUILD (cancella ANCHE i volumi - DB compreso)
# Richiede conferma esplicita.
# ─────────────────────────────────────────

hard-rebuild:
	@echo "⚠ ATTENZIONE: questo comando esegue 'docker compose down -v' e CANCELLA anche i volumi (database, redis, ecc.)."
	@read -p "Sei sicuro di voler procedere? (yes/N): " CONFIRM; \
	if [ "$$CONFIRM" = "yes" ]; then \
	  docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	                 -f docker/docker-compose.local.yml \
	                 -f docker/docker-compose.override.yml down -v; \
	  docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	                 -f docker/docker-compose.local.yml \
	                 -f docker/docker-compose.override.yml build; \
	  docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	                 -f docker/docker-compose.local.yml \
	                 -f docker/docker-compose.override.yml up -d; \
	  docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	                 -f docker/docker-compose.local.yml \
	                 -f docker/docker-compose.override.yml exec web python manage.py migrate; \
	else \
	  echo "Hard rebuild annullato."; \
	fi

# ─────────────────────────────────────────
# AGGIORNAMENTO DA MIXTUM
# Usato nei progetti derivati (ED Ticket, Fiscally, ecc.)
# ─────────────────────────────────────────

update-mixtum:
	git fetch mixtum
	@echo ""
	@echo "Modifiche in arrivo da Mixtum:"
	@git diff mixtum/main -- base_modules/ mixtum_core/ --stat
	@echo ""
	@read -p "Vuoi procedere con l'aggiornamento? (y/n) " CONFIRM; \
	if [ "$$CONFIRM" = "y" ]; then \
	    git checkout mixtum/main -- base_modules/ mixtum_core/ scripts/ nginx/ certbot/ Dockerfile docker/ .env.example; \
	    docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	                   -f docker/docker-compose.local.yml \
	                   run --rm web python manage.py migrate; \
	    echo ""; \
	    echo "✓ Mixtum aggiornato. Verifica le modifiche prima di fare commit."; \
	else \
	    echo "Aggiornamento annullato."; \
	fi
