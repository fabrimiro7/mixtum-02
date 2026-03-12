#!/usr/bin/env bash
# Crea la struttura {nome}_core per estendere Mixtum (progetto derivato).
# Uso: create-project.sh [nome_progetto]   (default: project → project_core)
# Non sovrascrive file esistenti.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Nome progetto: primo argomento o default "project"
RAW_NAME="${1:-project}"

# Normalizza a identificatore Python valido: minuscolo, solo [a-z0-9_]
NORMALIZED=$(echo "$RAW_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//')

# Se vuoto o non valido dopo normalizzazione, usa "project"
if [[ -z "$NORMALIZED" ]] || [[ "$NORMALIZED" =~ ^[^a-z] ]]; then
    echo "Nome non valido o vuoto, uso 'project'."
    NORMALIZED="project"
fi

CORE_NAME="${NORMALIZED}_core"

PROJECT_CORE_BASE="${ROOT_DIR}/${CORE_NAME}/settings/base.py"

if [[ -f "$PROJECT_CORE_BASE" ]]; then
  echo "${CORE_NAME} già presente, skip."
  exit 0
fi

echo "Creazione struttura ${CORE_NAME}..."

mkdir -p "${CORE_NAME}"
mkdir -p "${CORE_NAME}/settings/envs"

# ${CORE_NAME}/__init__.py
if [[ ! -f "${CORE_NAME}/__init__.py" ]]; then
  touch "${CORE_NAME}/__init__.py"
fi

# ${CORE_NAME}/settings/base.py
cat > "${CORE_NAME}/settings/base.py" << 'PYEOF'
# Estende Mixtum — non modificare i file in mixtum_core.
# Aggiungi qui le app e gli override del progetto.
from mixtum_core.settings import *

INSTALLED_APPS += [
    # Aggiungi i plugin del progetto, es.:
    # "plugins.ticket_manager",
    # "plugins.project_manager",
]
PYEOF

# ${CORE_NAME}/settings/__init__.py
cat > "${CORE_NAME}/settings/__init__.py" << 'PYEOF'
"""
Settings progetto derivato: carica Mixtum + base progetto, poi overlay env.
"""
import os

from .base import *

SETTINGS_ENV = os.getenv("SETTINGS_ENV", "local").lower()
if SETTINGS_ENV == "production":
    from .envs.production import *
else:
    from .envs.local import *
PYEOF

# ${CORE_NAME}/settings/envs/local.py (heredoc senza quote per espandere CORE_NAME)
cat > "${CORE_NAME}/settings/envs/local.py" << PYEOF
# Overlay sviluppo locale
import os
from ${CORE_NAME}.settings.base import *

DEBUG = True
ALLOWED_HOSTS = ["*"]

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("POSTGRES_DB", "mixtumdb"),
        "USER": os.environ.get("POSTGRES_USER", "mixtumuser"),
        "PASSWORD": os.environ.get("POSTGRES_PASSWORD", "mixtumpassword"),
        "HOST": os.environ.get("POSTGRES_HOST", "db"),
        "PORT": int(os.environ.get("POSTGRES_PORT", "5432")),
        "CONN_MAX_AGE": 60,
    }
}
PYEOF

# ${CORE_NAME}/settings/envs/production.py (heredoc senza quote per espandere CORE_NAME)
cat > "${CORE_NAME}/settings/envs/production.py" << PYEOF
# Overlay produzione
import os
from ${CORE_NAME}.settings.base import *

DEBUG = False
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
ALLOWED_HOSTS = [h.strip() for h in os.environ.get("ALLOWED_HOSTS", "").split(",") if h.strip()]

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("POSTGRES_DB", "mixtumdb"),
        "USER": os.environ.get("POSTGRES_USER", "mixtumuser"),
        "PASSWORD": os.environ.get("POSTGRES_PASSWORD", "mixtumpassword"),
        "HOST": os.environ.get("POSTGRES_HOST", "db"),
        "PORT": int(os.environ.get("POSTGRES_PORT", "5432")),
        "CONN_MAX_AGE": 60,
    }
}
PYEOF

# ${CORE_NAME}/settings/envs/__init__.py (per import envs)
if [[ ! -f "${CORE_NAME}/settings/envs/__init__.py" ]]; then
  touch "${CORE_NAME}/settings/envs/__init__.py"
fi

# ${CORE_NAME}/urls.py
cat > "${CORE_NAME}/urls.py" << 'PYEOF'
# Estende le url di Mixtum; aggiungi qui le url dei plugin del progetto.
from django.urls import path, include
from mixtum_core.urls import urlpatterns as mixtum_urls

urlpatterns = mixtum_urls + [
    # Es.: path("api/tickets/", include("plugins.ticket_manager.urls")),
]
PYEOF

echo "Struttura ${CORE_NAME} creata."
echo ""
echo "Per usare il progetto derivato:"
echo "  1. In .env imposta: DJANGO_SETTINGS_MODULE=${CORE_NAME}.settings.envs.local"
echo "  2. In produzione:   DJANGO_SETTINGS_MODULE=${CORE_NAME}.settings.envs.production"
echo "  3. Aggiungi le app in ${CORE_NAME}/settings/base.py (INSTALLED_APPS += ...)"
echo "  4. Aggiungi le url in ${CORE_NAME}/urls.py (urlpatterns = mixtum_urls + [...])"
echo ""
