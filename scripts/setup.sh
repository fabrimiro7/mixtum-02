#!/bin/bash

set -e

# Run from project root (parent of scripts/)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo ""
echo "🚀 Mixtum — Setup ambiente di sviluppo"
echo "========================================"

# ─────────────────────────────────────────
# 1. Ambiente: locale o produzione
# ─────────────────────────────────────────
echo ""
read -p "Ambiente locale o produzione? (local/prod) [local]: " SETUP_ENV
SETUP_ENV="${SETUP_ENV:-local}"
if [[ "$SETUP_ENV" != "local" && "$SETUP_ENV" != "prod" ]]; then
    echo "Scelta non valida, uso 'local'."
    SETUP_ENV="local"
fi

if [[ "$SETUP_ENV" = "local" ]]; then
    COMPOSE_FILES="-f docker/docker-compose.yml -f docker/docker-compose.local.yml -f docker/docker-compose.override.yml"
    echo "✓ Modalità locale (docker-compose + local + override)"
else
    COMPOSE_FILES="-f docker/docker-compose.yml -f docker/docker-compose.prod.yml"
    echo "✓ Modalità produzione (docker-compose + prod)"
fi

# ─────────────────────────────────────────
# 2. Remote mixtum
# Necessario nei progetti derivati (ED Ticket, Fiscally, ecc.)
# In questo repo è opzionale
# ─────────────────────────────────────────
if ! git remote | grep -q "mixtum"; then
    echo "ℹ️  Nessun remote 'mixtum' trovato (normale se questo è il repo Mixtum)"
else
    echo "✓ Remote mixtum presente"
fi

# ─────────────────────────────────────────
# 3. File .env
# ─────────────────────────────────────────
if [ ! -f .env ]; then
    cp .env.example .env
    echo "✓ File .env creato da .env.example"

    # Genera SECRET_KEY e password DB in modo sicuro se non specificati dall'utente
    if grep -q '^SECRET_KEY=changeme$' .env 2>/dev/null || ! grep -q '^SECRET_KEY=' .env 2>/dev/null; then
        NEW_SECRET="${SECRET_KEY:-$(openssl rand -base64 48)}"
        sed 's|^SECRET_KEY=.*|SECRET_KEY='"$NEW_SECRET"'|' .env > .env.tmp && mv .env.tmp .env
    fi
    if grep -q '^POSTGRES_PASSWORD=mixtumpassword$' .env 2>/dev/null || ! grep -q '^POSTGRES_PASSWORD=' .env 2>/dev/null; then
        NEW_PASS="${POSTGRES_PASSWORD:-$(openssl rand -base64 24)}"
        sed 's|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD='"$NEW_PASS"'|' .env > .env.tmp && mv .env.tmp .env
    fi
    echo "✓ SECRET_KEY e password database generati automaticamente"
    echo ""
    echo "  ℹ️  Controlla .env per eventuali API key (Slack, AWS, Twilio, n8n, ecc.) se necessarie."
    echo ""
else
    echo "✓ File .env già presente"
fi

# ─────────────────────────────────────────
# 4. Docker build
# ─────────────────────────────────────────
echo ""
echo "⏳ Build Docker in corso..."
docker compose $COMPOSE_FILES build
echo "✓ Build completata"

# ─────────────────────────────────────────
# 5. Avvio database e Redis
# ─────────────────────────────────────────
echo ""
echo "⏳ Avvio database e Redis..."
docker compose $COMPOSE_FILES up -d db redis

echo "⏳ Attendo che il database sia pronto..."
until docker compose $COMPOSE_FILES exec -T db pg_isready -U "${POSTGRES_USER:-mixtumuser}" > /dev/null 2>&1; do
    sleep 1
done
echo "✓ Database pronto"

# ─────────────────────────────────────────
# 6. Migrations
# ─────────────────────────────────────────
echo ""
echo "⏳ Esecuzione migrations..."
docker compose $COMPOSE_FILES run --rm web python manage.py migrate
echo "✓ Migrations completate"

# ─────────────────────────────────────────
# 6b. Struttura progetto (project_core) opzionale
# ─────────────────────────────────────────
echo ""
read -p "Creare struttura progetto (project_core) per estendere Mixtum? (y/n) " CREATE_PROJECT
if [[ "$CREATE_PROJECT" = "y" || "$CREATE_PROJECT" = "Y" ]]; then
    if [[ -f scripts/create-project.sh ]]; then
        bash scripts/create-project.sh
    else
        echo "⚠️  scripts/create-project.sh non trovato, skip."
    fi
fi

# ─────────────────────────────────────────
# 7. Superuser opzionale
# ─────────────────────────────────────────
echo ""
read -p "Vuoi creare un superuser admin? (y/n) " CREATE_SUPER
if [ "$CREATE_SUPER" = "y" ]; then
    docker compose $COMPOSE_FILES run --rm web python manage.py createsuperuser
fi

# ─────────────────────────────────────────
# 8. Avvio completo
# ─────────────────────────────────────────
echo ""
echo "⏳ Avvio completo del progetto..."
docker compose $COMPOSE_FILES up -d

echo ""
echo "✅ Setup completato!"
echo ""
echo "   Backend API  → http://localhost:8000"
echo "   Console      → http://localhost:4200"
echo "   Admin Django → http://localhost:8000/admin"
echo ""
echo "   Comandi utili:"
echo "   make dev      → avvia in foreground con logs"
echo "   make logs     → vedi i logs"
echo "   make shell    → shell Django"
echo "   make migrate  → esegui migrations"
echo ""
