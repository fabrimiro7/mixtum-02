#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Setup iniziale server Ubuntu per Mixtum
# =============================================================================
# Uso:
#   chmod +x bootstrap.sh
#   ./bootstrap.sh
#
# Cosa fa:
#   1. Aggiorna il sistema
#   2. Installa Docker + Docker Compose plugin
#   3. Aggiunge l'utente corrente al gruppo docker
#   4. Installa Git
#   5. (Opzionale) Clona il repository
#   6. Configura UFW
# =============================================================================

set -euo pipefail

# ── Colori ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()     { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Parametri configurabili ───────────────────────────────────────────────────
REPO_URL="${REPO_URL:-}"          # es. https://github.com/tuo-org/mixtum-02.git
PROJECT_DIR="${PROJECT_DIR:-/home/ubuntu/mixtum-02}"
CLONE_REPO="${CLONE_REPO:-false}" # passa CLONE_REPO=true per clonare il repo

# ── Controlli preliminari ─────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] && error "Non eseguire questo script come root. Usare un utente normale con sudo."

log "Avvio bootstrap Mixtum su $(lsb_release -ds 2>/dev/null || uname -sr)"
echo ""

# ── 1. Aggiornamento sistema ──────────────────────────────────────────────────
log "1/6 — Aggiornamento pacchetti di sistema..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get autoremove -y
ok "Sistema aggiornato."
echo ""

# ── 2. Installazione Docker ───────────────────────────────────────────────────
log "2/6 — Installazione Docker Engine..."

if command -v docker &>/dev/null; then
    warn "Docker già installato ($(docker --version)). Salto l'installazione."
else
    sudo apt-get install -y ca-certificates curl

    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    ok "Docker installato: $(docker --version)"
fi

# Verifica Docker Compose
if docker compose version &>/dev/null; then
    ok "Docker Compose disponibile: $(docker compose version)"
else
    error "Docker Compose plugin non trovato. Controlla l'installazione di Docker."
fi
echo ""

# ── 3. Permessi Docker per l'utente corrente ──────────────────────────────────
log "3/6 — Configurazione permessi Docker per l'utente '${USER}'..."

if groups "$USER" | grep -q '\bdocker\b'; then
    warn "L'utente '${USER}' è già nel gruppo docker."
else
    sudo usermod -aG docker "$USER"
    ok "Utente '${USER}' aggiunto al gruppo docker."
    warn "IMPORTANTE: le nuove sessioni SSH erediteranno il gruppo docker."
    warn "           Dopo il termine dello script, esegui: newgrp docker"
    warn "           oppure disconnettiti e riconnettiti via SSH."
fi
echo ""

# ── 4. Installazione Git ──────────────────────────────────────────────────────
log "4/6 — Installazione Git..."

if command -v git &>/dev/null; then
    warn "Git già installato ($(git --version)). Salto."
else
    sudo apt-get install -y git
    ok "Git installato: $(git --version)"
fi
echo ""

# ── 5. (Opzionale) Clone del repository ──────────────────────────────────────
log "5/6 — Clone repository..."

if [[ "$CLONE_REPO" == "true" ]]; then
    if [[ -z "$REPO_URL" ]]; then
        warn "REPO_URL non impostata. Salto il clone."
        warn "Puoi clonare manualmente con:"
        warn "  git clone <URL-DEL-REPO> ${PROJECT_DIR}"
    else
        if [[ -d "$PROJECT_DIR/.git" ]]; then
            warn "Repository già presente in ${PROJECT_DIR}. Eseguo git pull."
            git -C "$PROJECT_DIR" pull
        else
            git clone "$REPO_URL" "$PROJECT_DIR"
            ok "Repository clonato in ${PROJECT_DIR}."
        fi
    fi
else
    warn "Clone saltato (CLONE_REPO=false)."
    warn "Clona manualmente il repo oppure esegui:"
    warn "  CLONE_REPO=true REPO_URL=<url> ./bootstrap.sh"
fi
echo ""

# ── 6. Configurazione UFW ─────────────────────────────────────────────────────
log "6/6 — Configurazione firewall UFW..."

sudo apt-get install -y ufw

# Assicurati che SSH sia sempre consentito PRIMA di abilitare UFW
sudo ufw allow 22/tcp  comment 'SSH'
sudo ufw allow 80/tcp  comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Abilita solo se non già attivo
if sudo ufw status | grep -q "Status: active"; then
    warn "UFW già attivo. Regole aggiornate."
else
    sudo ufw --force enable
    ok "UFW abilitato."
fi

sudo ufw status numbered
echo ""

# ── Riepilogo finale ──────────────────────────────────────────────────────────
echo "============================================================"
echo -e "${GREEN}  Bootstrap completato con successo!${NC}"
echo "============================================================"
echo ""
echo "  Prossimi passi:"
echo ""
echo "  1. Applica il gruppo docker senza riloggare:"
echo "       newgrp docker"
echo ""
echo "  2. Vai nella cartella del progetto:"
echo "       cd ${PROJECT_DIR}"
echo ""
echo "  3. Crea il file .env a partire dall'esempio:"
echo "       cp .env.example .env && nano .env"
echo ""
echo "  4. Dai i permessi agli script e avvia il deploy:"
echo "       chmod +x scripts/entrypoint.sh scripts/deploy.sh"
echo "       chmod +x nginx/init.sh nginx/ssl-watch.sh certbot/entrypoint.sh"
echo "       ./scripts/deploy.sh"
echo ""
echo "  Documentazione completa: docs/deploy-aws-ec2.md"
echo "============================================================"