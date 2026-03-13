.PHONY: setup dev dev-d prod stop update-mixtum migrate shell logs restart rebuild

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
# REBUILD COMPLETO (containers + volumi + setup)
# ─────────────────────────────────────────

rebuild:
	# Ferma e rimuove TUTTI i container + volumi del progetto corrente
	docker compose -p $(COMPOSE_PROJECT_NAME) --env-file .env -f docker/docker-compose.yml \
	               -f docker/docker-compose.local.yml \
	               -f docker/docker-compose.override.yml down -v
	# Ricostruisce immagini, riesegue le migrations e riavvia tutto
	bash scripts/setup.sh

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
