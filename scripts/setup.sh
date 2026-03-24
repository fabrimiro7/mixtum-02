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
    OVERRIDE_FILE="docker/docker-compose.override.yml"
    if [ ! -f "$OVERRIDE_FILE" ]; then
        echo "ℹ️  Nessun $OVERRIDE_FILE trovato, ne creo uno di default..."
        cat > "$OVERRIDE_FILE" <<'EOF'
# docker-compose override locale (generato da scripts/setup.sh)
# Aggiungi qui volumi, porte, ecc. specifici del tuo ambiente.
EOF
    fi
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

# Compose deve leggere .env dalla root per POSTGRES_PASSWORD (project dir è docker/)
COMPOSE_ENV=""
[ -f "$ROOT_DIR/.env" ] && COMPOSE_ENV="--env-file $ROOT_DIR/.env"

# Project name compose:
# - default: nome cartella (retrocompatibile)
# - opzionale: suffisso istanza per avviare stack paralleli
BASE_PROJECT_NAME="$(basename "$ROOT_DIR")"
read -p "Nome istanza opzionale (es. dev2, lascia vuoto per default): " INSTANCE_NAME
INSTANCE_NAME="$(echo "$INSTANCE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')"

if [ -n "$INSTANCE_NAME" ]; then
    export COMPOSE_PROJECT_NAME="${BASE_PROJECT_NAME}-${INSTANCE_NAME}"
else
    export COMPOSE_PROJECT_NAME="$BASE_PROJECT_NAME"
fi

echo "✓ Docker project name: $COMPOSE_PROJECT_NAME"
if [ -n "$INSTANCE_NAME" ]; then
    MAKE_PREFIX="INSTANCE_NAME=${INSTANCE_NAME} "
else
    MAKE_PREFIX=""
fi

# ─────────────────────────────────────────
# 4. Docker build
# ─────────────────────────────────────────
echo ""
echo "⏳ Build Docker in corso..."
docker compose $COMPOSE_ENV $COMPOSE_FILES build
echo "✓ Build completata"

# ─────────────────────────────────────────
# 5. Avvio database e Redis
# ─────────────────────────────────────────
echo ""
echo "⏳ Avvio database e Redis..."
docker compose $COMPOSE_ENV $COMPOSE_FILES up -d db redis

echo "⏳ Attendo che il database sia pronto..."
until docker compose $COMPOSE_ENV $COMPOSE_FILES exec -T db pg_isready -U "${POSTGRES_USER:-mixtumuser}" > /dev/null 2>&1; do
    sleep 1
done
echo "✓ Database pronto"

# ─────────────────────────────────────────
# 6. Migrations
# ─────────────────────────────────────────
echo ""
echo "⏳ Esecuzione migrations..."
docker compose $COMPOSE_ENV $COMPOSE_FILES run --rm web python manage.py migrate
echo "✓ Migrations completate"

# ─────────────────────────────────────────
# 6b. Struttura progetto ({nome}_core) opzionale
# ─────────────────────────────────────────
echo ""
read -p "Creare struttura progetto per estendere Mixtum? (y/n) " CREATE_PROJECT
if [[ "$CREATE_PROJECT" = "y" || "$CREATE_PROJECT" = "Y" ]]; then
    read -p "Nome del progetto (es. fiscally, ed_ticket) [project]: " PROJECT_NAME
    PROJECT_NAME="${PROJECT_NAME:-project}"
    if [[ -f scripts/create-project.sh ]]; then
        bash scripts/create-project.sh "$PROJECT_NAME"
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
    docker compose $COMPOSE_ENV $COMPOSE_FILES run --rm web python manage.py createsuperuser
fi

# ─────────────────────────────────────────
# 8. Avvio completo
# ─────────────────────────────────────────
echo ""
echo "⏳ Avvio completo del progetto..."
docker compose $COMPOSE_ENV $COMPOSE_FILES up -d

echo ""
echo "✅ Setup completato!"
echo ""
echo "   Backend API  → http://localhost:8000"
echo "   Console      → http://localhost:4200"
echo "   Admin Django → http://localhost:8000/admin"
echo ""
echo "   Comandi utili:"
echo "   ${MAKE_PREFIX}make dev      → avvia in foreground con logs"
echo "   ${MAKE_PREFIX}make logs     → vedi i logs"
echo "   ${MAKE_PREFIX}make shell    → shell Django"
echo "   ${MAKE_PREFIX}make migrate  → esegui migrations"
echo ""
