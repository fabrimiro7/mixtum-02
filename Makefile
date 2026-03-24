.PHONY: setup dev dev-d prod stop update-mixtum migrate shell logs restart rebuild hard-rebuild

# Project name compose:
# - default: nome cartella (retrocompatibile)
# - override 1: INSTANCE_NAME=dev2 make dev-d  -> nomecartella-dev2
# - override 2: COMPOSE_PROJECT_NAME=custom make dev-d
# COMPOSE_PROJECT_NAME: fonte di verità è .env (scritto da setup.sh).
# ":=" + shell command sovrascrive qualsiasi variabile d'ambiente della shell,
# eliminando il bug "COMPOSE_PROJECT_NAME=TEST MIXTUM..." che rompeva i target.
COMPOSE_PROJECT_NAME := $(shell sed -n 's/^COMPOSE_PROJECT_NAME=//p' '$(CURDIR)/.env' 2>/dev/null | sed -n '1p' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g' | sed 's/--*/-/g' | sed 's/^-*//;s/-*$$//')
# Fallback: se .env non esiste o non ha COMPOSE_PROJECT_NAME, usa il nome della cartella normalizzato
ifeq ($(strip $(COMPOSE_PROJECT_NAME)),)
COMPOSE_PROJECT_NAME := $(shell basename '$(CURDIR)' | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$$//')
endif

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
