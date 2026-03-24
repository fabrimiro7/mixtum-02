.PHONY: setup dev dev-d prod stop update-mixtum migrate shell logs restart rebuild hard-rebuild

# Project name compose:
# - default: nome cartella (retrocompatibile)
# - override 1: INSTANCE_NAME=dev2 make dev-d  -> nomecartella-dev2
# - override 2: COMPOSE_PROJECT_NAME=custom make dev-d
BASE_PROJECT_NAME := $(shell basename $(CURDIR))
# Allineato a scripts/setup.sh: solo [a-z0-9-], niente spazi (altrimenti -p si spezza nella shell)
ENV_INSTANCE_NAME := $(shell [ -f '$(CURDIR)/.env' ] && sed -n 's/^INSTANCE_NAME=//p' '$(CURDIR)/.env' | sed -n '1p' | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$$//')
INSTANCE_NAME ?= $(strip $(ENV_INSTANCE_NAME))
# Nome progetto Docker: da COMPOSE_PROJECT_NAME (env/make) o da cartella+INSTANCE_NAME.
# Obbligatorio normalizzare: Docker accetta solo [a-z0-9_-] (no spazi, no maiuscole).
# Senza questo, export COMPOSE_PROJECT_NAME=... invalido in shell rompe tutti i target.
_COMPOSE_NAME_RAW := $(if $(strip $(COMPOSE_PROJECT_NAME)),$(COMPOSE_PROJECT_NAME),$(if $(strip $(INSTANCE_NAME)),$(BASE_PROJECT_NAME)-$(INSTANCE_NAME),$(BASE_PROJECT_NAME)))
COMPOSE_PROJECT_NAME := $(shell RAW='$(_COMPOSE_NAME_RAW)'; printf '%s' "$$RAW" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g' | sed 's/--*/-/g' | sed 's/^-*//;s/-*$$//')

# Percorsi assoluti quotati: ok anche se la cartella progetto ha spazi nel path
ENV_FILE := $(CURDIR)/.env
F_COMPOSE_BASE := $(CURDIR)/docker/docker-compose.yml
F_COMPOSE_LOCAL := $(CURDIR)/docker/docker-compose.local.yml
F_COMPOSE_OVERRIDE := $(CURDIR)/docker/docker-compose.override.yml
F_COMPOSE_PROD := $(CURDIR)/docker/docker-compose.prod.yml

# ─────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────

setup:
	bash scripts/setup.sh

# ─────────────────────────────────────────
# SVILUPPO LOCALE
# ─────────────────────────────────────────

dev:
	docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	               -f "$(F_COMPOSE_LOCAL)" \
	               -f "$(F_COMPOSE_OVERRIDE)" up

dev-d:
	docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	               -f "$(F_COMPOSE_LOCAL)" \
	               -f "$(F_COMPOSE_OVERRIDE)" up -d

# ─────────────────────────────────────────
# PRODUZIONE
# ─────────────────────────────────────────

prod:
	docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	               -f "$(F_COMPOSE_PROD)" up -d

# ─────────────────────────────────────────
# GESTIONE
# ─────────────────────────────────────────

stop:
	docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	              -f "$(F_COMPOSE_LOCAL)" \
	              -f "$(F_COMPOSE_OVERRIDE)" down

migrate:
	docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	              -f "$(F_COMPOSE_LOCAL)" \
	              -f "$(F_COMPOSE_OVERRIDE)" exec web python manage.py migrate

makemigrations:
	docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	              -f "$(F_COMPOSE_LOCAL)" \
	              -f "$(F_COMPOSE_OVERRIDE)" exec web python manage.py makemigrations

shell:
	docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	              -f "$(F_COMPOSE_LOCAL)" \
	              -f "$(F_COMPOSE_OVERRIDE)" exec web python manage.py shell

logs:
	docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	              -f "$(F_COMPOSE_LOCAL)" \
	              -f "$(F_COMPOSE_OVERRIDE)" logs -f web worker

restart:
	docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	              -f "$(F_COMPOSE_LOCAL)" \
	              -f "$(F_COMPOSE_OVERRIDE)" restart web worker beat

# ─────────────────────────────────────────
# REBUILD COMPLETO (non interattivo, NON cancella volumi)
# - Ferma e ricrea i container mantenendo i volumi (DB, Redis, file, ecc.)
# - Re-build immagini (nuovi requirements)
# - Applica migrations
# - Riavvia stack locale
# ─────────────────────────────────────────

rebuild:
	# Ferma e rimuove i container del progetto corrente (mantiene i volumi)
	docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	               -f "$(F_COMPOSE_LOCAL)" \
	               -f "$(F_COMPOSE_OVERRIDE)" down
	# Rebuild immagini (include nuovi requirements nel Dockerfile)
	docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	               -f "$(F_COMPOSE_LOCAL)" \
	               -f "$(F_COMPOSE_OVERRIDE)" build
	# Avvia servizi (web, worker, beat, db, redis, ecc.)
	docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	               -f "$(F_COMPOSE_LOCAL)" \
	               -f "$(F_COMPOSE_OVERRIDE)" up -d
	# Applica migrations sul container web già avviato
	docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	               -f "$(F_COMPOSE_LOCAL)" \
	               -f "$(F_COMPOSE_OVERRIDE)" exec web python manage.py migrate

# ─────────────────────────────────────────
# HARD REBUILD (cancella ANCHE i volumi - DB compreso)
# Richiede conferma esplicita.
# ─────────────────────────────────────────

hard-rebuild:
	@echo "⚠ ATTENZIONE: questo comando esegue 'docker compose down -v' e CANCELLA anche i volumi (database, redis, ecc.)."
	@read -p "Sei sicuro di voler procedere? (yes/N): " CONFIRM; \
	if [ "$$CONFIRM" = "yes" ]; then \
	  docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	                 -f "$(F_COMPOSE_LOCAL)" \
	                 -f "$(F_COMPOSE_OVERRIDE)" down -v; \
	  docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	                 -f "$(F_COMPOSE_LOCAL)" \
	                 -f "$(F_COMPOSE_OVERRIDE)" build; \
	  docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	                 -f "$(F_COMPOSE_LOCAL)" \
	                 -f "$(F_COMPOSE_OVERRIDE)" up -d; \
	  docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	                 -f "$(F_COMPOSE_LOCAL)" \
	                 -f "$(F_COMPOSE_OVERRIDE)" exec web python manage.py migrate; \
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
	    docker compose -p "$(COMPOSE_PROJECT_NAME)" --env-file "$(ENV_FILE)" -f "$(F_COMPOSE_BASE)" \
	                   -f "$(F_COMPOSE_LOCAL)" \
	                   run --rm web python manage.py migrate; \
	    echo ""; \
	    echo "✓ Mixtum aggiornato. Verifica le modifiche prima di fare commit."; \
	else \
	    echo "Aggiornamento annullato."; \
	fi
