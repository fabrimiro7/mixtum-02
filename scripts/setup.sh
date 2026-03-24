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
    compose_files=(
        -f "$ROOT_DIR/docker/docker-compose.yml"
        -f "$ROOT_DIR/docker/docker-compose.local.yml"
        -f "$ROOT_DIR/docker/docker-compose.override.yml"
    )
    echo "✓ Modalità locale (docker-compose + local + override)"
else
    compose_files=(
        -f "$ROOT_DIR/docker/docker-compose.yml"
        -f "$ROOT_DIR/docker/docker-compose.prod.yml"
    )
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
CREATED_NEW_ENV=false
if [ ! -f .env ]; then
    CREATED_NEW_ENV=true
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
# Usa array + quoting: evita word-splitting su path con spazi e argomenti malformati per docker compose
compose_env_args=()
if [ -f "$ROOT_DIR/.env" ]; then
    compose_env_args+=(--env-file "$ROOT_DIR/.env")
fi

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
compose_project_args=(-p "$COMPOSE_PROJECT_NAME")

# Persisti l'istanza in .env per i comandi make successivi
if grep -q '^INSTANCE_NAME=' .env 2>/dev/null; then
    sed 's|^INSTANCE_NAME=.*|INSTANCE_NAME='"$INSTANCE_NAME"'|' .env > .env.tmp && mv .env.tmp .env
else
    printf "\nINSTANCE_NAME=%s\n" "$INSTANCE_NAME" >> .env
fi

echo "✓ Docker project name: $COMPOSE_PROJECT_NAME"
echo "✓ INSTANCE_NAME salvata in .env per i prossimi comandi make"

# Postgres salva la password nel volume alla prima init: se ricrei .env con una
# password nuova, il vecchio volume continua a usare la vecchia → auth fallita.
if [ "$CREATED_NEW_ENV" = true ]; then
    VOL="${COMPOSE_PROJECT_NAME}_postgres_data"
    if docker volume inspect "$VOL" &>/dev/null; then
        echo "ℹ️  Fermo eventuali container che usano il vecchio database..."
        docker compose "${compose_project_args[@]}" "${compose_env_args[@]}" "${compose_files[@]}" down 2>/dev/null || true
        echo "ℹ️  Rimuovo il volume Postgres ($VOL): .env è appena stato creato e deve"
        echo "   allinearsi al database (password nel volume vs .env)."
        docker volume rm "$VOL" || {
            echo "⚠️  Impossibile rimuovere il volume (forse ancora in uso). Esegui:"
            echo "   INSTANCE_NAME=${INSTANCE_NAME} make hard-rebuild"
        }
    fi
fi

# Detect stale Postgres volume initialized with a different password
VOLUME_NAME="${COMPOSE_PROJECT_NAME}_postgres_data"
CURRENT_PASS="$(grep '^POSTGRES_PASSWORD=' .env 2>/dev/null | cut -d= -f2)"
if docker volume ls --format '{{.Name}}' | grep -q "^${VOLUME_NAME}$" && \
   [ "$CURRENT_PASS" = "mixtumpassword" ]; then
    echo ""
    echo "⚠️  ATTENZIONE: .env ha la password di default ('mixtumpassword') ma il volume"
    echo "   '$VOLUME_NAME' esiste già — probabilmente inizializzato con una password"
    echo "   diversa. Se ottieni errori di autenticazione Postgres, esegui:"
    echo "   INSTANCE_NAME=${INSTANCE_NAME} make hard-rebuild"
    echo ""
fi
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
docker compose "${compose_project_args[@]}" "${compose_env_args[@]}" "${compose_files[@]}" build
echo "✓ Build completata"

# ─────────────────────────────────────────
# 5. Avvio database e Redis
# ─────────────────────────────────────────
echo ""
echo "⏳ Avvio database e Redis..."
docker compose "${compose_project_args[@]}" "${compose_env_args[@]}" "${compose_files[@]}" up -d db redis

echo "⏳ Attendo che il database sia pronto..."
until docker compose "${compose_project_args[@]}" "${compose_env_args[@]}" "${compose_files[@]}" exec -T db pg_isready -U "${POSTGRES_USER:-mixtumuser}" > /dev/null 2>&1; do
    sleep 1
done
echo "✓ Database pronto"

# ─────────────────────────────────────────
# 6. Migrations
# ─────────────────────────────────────────
echo ""
echo "⏳ Esecuzione migrations..."
docker compose "${compose_project_args[@]}" "${compose_env_args[@]}" "${compose_files[@]}" run --rm web python manage.py migrate
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
    docker compose "${compose_project_args[@]}" "${compose_env_args[@]}" "${compose_files[@]}" run --rm web python manage.py createsuperuser
fi

# ─────────────────────────────────────────
# 8. Avvio completo
# ─────────────────────────────────────────
echo ""
echo "⏳ Avvio completo del progetto..."
docker compose "${compose_project_args[@]}" "${compose_env_args[@]}" "${compose_files[@]}" up -d

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
