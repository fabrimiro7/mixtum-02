#!/usr/bin/env bash
# Crea la struttura project_core per estendere Mixtum (progetto derivato).
# Non sovrascrive file esistenti.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_CORE_BASE="${ROOT_DIR}/project_core/settings/base.py"

if [[ -f "$PROJECT_CORE_BASE" ]]; then
  echo "project_core già presente, skip."
  exit 0
fi

echo "Creazione struttura project_core..."

mkdir -p project_core
mkdir -p project_core/settings/envs

# project_core/__init__.py
if [[ ! -f project_core/__init__.py ]]; then
  touch project_core/__init__.py
fi

# project_core/settings/base.py
cat > project_core/settings/base.py << 'PYEOF'
# Estende Mixtum — non modificare i file in mixtum_core.
# Aggiungi qui le app e gli override del progetto.
from mixtum_core.settings import *

INSTALLED_APPS += [
    # Aggiungi i plugin del progetto, es.:
    # "plugins.ticket_manager",
    # "plugins.project_manager",
]
PYEOF

# project_core/settings/__init__.py
cat > project_core/settings/__init__.py << 'PYEOF'
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

# project_core/settings/envs/local.py
cat > project_core/settings/envs/local.py << 'PYEOF'
# Overlay sviluppo locale
import os
from project_core.settings.base import *

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

# project_core/settings/envs/production.py
cat > project_core/settings/envs/production.py << 'PYEOF'
# Overlay produzione
import os
from project_core.settings.base import *

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

# project_core/settings/envs/__init__.py (per import envs)
if [[ ! -f project_core/settings/envs/__init__.py ]]; then
  touch project_core/settings/envs/__init__.py
fi

# project_core/urls.py
cat > project_core/urls.py << 'PYEOF'
# Estende le url di Mixtum; aggiungi qui le url dei plugin del progetto.
from django.urls import path, include
from mixtum_core.urls import urlpatterns as mixtum_urls

urlpatterns = mixtum_urls + [
    # Es.: path("api/tickets/", include("plugins.ticket_manager.urls")),
]
PYEOF

echo "Struttura project_core creata."
echo ""
echo "Per usare il progetto derivato:"
echo "  1. In .env imposta: DJANGO_SETTINGS_MODULE=project_core.settings.envs.local"
echo "  2. In produzione:   DJANGO_SETTINGS_MODULE=project_core.settings.envs.production"
echo "  3. Aggiungi le app in project_core/settings/base.py (INSTALLED_APPS += ...)"
echo "  4. Aggiungi le url in project_core/urls.py (urlpatterns = mixtum_urls + [...])"
echo ""
