# Mixtum Framework

Backend Django con **base modules** riutilizzabili (utenti, workspace, email, integrazioni) e **plugin** per estendere le funzionalità. Supporta deployment in sviluppo (locale) e in produzione con SSL automatico Let's Encrypt.

---

## Documentazione

Guide pratiche per sviluppare con Mixtum:

- **[Struttura di Mixtum](docs/structure.md)** — Come è organizzato il progetto e dove si trova ogni parte.
- **[Base modules](docs/base-modules.md)** — Caratteristiche e funzioni dei moduli condivisi (user_manager, workspace, mailer, ecc.).
- **[Plugin](docs/plugins.md)** — Struttura di un plugin e come creare un nuovo plugin.

---

## Requisiti di sistema

- **Docker Engine** (es. 20.10+) e **Docker Compose** v2 (`docker compose`).
- **Make** (opzionale ma consigliato per i comandi sotto).
- Per la **produzione**:
  - Dominio con DNS che punta al server.
  - Porte **80** e **443** aperte in ingresso.

---

## Avvio in locale (sviluppo)

### 1. Clonare il repository ed entrare nella cartella

```bash
cd /path/to/mixtum-02
```

### 2. File `.env`

Crea il file di ambiente dalla copia di esempio:

```bash
cp .env.example .env
```

Opzionale: puoi rigenerare `SECRET_KEY` e `POSTGRES_PASSWORD` per maggiore sicurezza (lo script `setup.sh` può farlo in automatico al primo avvio).

### 3. Primo avvio (setup completo)

Esegui il setup che fa build, avvio di database e Redis, migrations e (a scelta) creazione superuser e struttura progetto:

```bash
make setup
```

Oppure, senza Make:

```bash
bash scripts/setup.sh
```

Lo script chiederà se creare un superuser e se creare la struttura per un progetto derivato.

### Setup di istanze parallele (stesso progetto)

Se vuoi eseguire due stack Docker distinti dello stesso progetto, durante `make setup` inserisci un nome istanza (es. `dev2`) quando richiesto.

Esempio:

```bash
make setup
# Nome istanza opzionale: dev2
```

Da quel momento usa lo stesso prefisso nei comandi `make`:

```bash
INSTANCE_NAME=dev2 make dev-d
INSTANCE_NAME=dev2 make logs
INSTANCE_NAME=dev2 make stop
```

`make setup` salva automaticamente `INSTANCE_NAME` in `.env`, quindi i comandi successivi (incluso `make rebuild`) riusano la stessa istanza anche senza prefisso.

Per un override temporaneo su una singola esecuzione:

```bash
INSTANCE_NAME=altro make rebuild
```

Se lasci il nome istanza vuoto, il comportamento resta identico a prima (stack di default basato sul nome cartella).

### 4. Avvio successivi

Con log in primo piano:

```bash
make dev
```

In background:

```bash
make dev-d
```

### 5. Comandi utili

| Comando | Descrizione |
|--------|-------------|
| `make migrate` | Applica le migrations |
| `make makemigrations` | Crea nuove migrations |
| `make shell` | Shell Django (`manage.py shell`) |
| `make logs` | Log di web e worker |
| `make stop` | Ferma i container (locale) |
| `make rebuild` | Ricostruisce immagini e riavvia senza cancellare i volumi |

### 6. Accesso

- **Backend API**: `http://localhost:8000`
- **Admin Django**: `http://localhost:8000/admin`

In locale i servizi usano `docker/docker-compose.yml` + `docker/docker-compose.local.yml` + `docker/docker-compose.override.yml`; le porte 8000 (web), 5432 (Postgres) e 6379 (Redis) sono esposte.

---

## Avvio in produzione

### 1. Configurare `.env`

Crea o modifica il file `.env` nella root del progetto con almeno:

```bash
SERVER_NAME=tuodominio.it
CERTBOT_EMAIL=you@example.com

POSTGRES_DB=mixtumdb
POSTGRES_USER=mixtumuser
POSTGRES_PASSWORD=password_sicura
```

Per tutte le variabili disponibili fai riferimento a `.env.example` (DB, Celery, CORS, AWS S3, Slack, n8n, Twilio, ecc.).

### 2. Permessi agli script (una tantum)

Rendi eseguibili gli script richiesti da `deploy.sh`:

```bash
chmod +x scripts/deploy.sh nginx/init.sh nginx/ssl-watch.sh certbot/entrypoint.sh scripts/entrypoint.sh
```

### 3. Deploy

Solo backend (API + Nginx con SSL):

```bash
./scripts/deploy.sh
```

Per servire anche il frontend dal container Nginx:

```bash
DEPLOY_PROFILE=frontend ./scripts/deploy.sh
```

### Cosa fa `deploy.sh`

- Build e avvio dello stack in modalità PROD (`docker/docker-compose.yml` + `docker/docker-compose.prod.yml`).
- Verifica che Nginx risponda sulla porta 80 e che il webroot per ACME sia raggiungibile.
- Rilascia il certificato SSL con Certbot (one-shot) se mancante.
- Ricarica Nginx e attiva la configurazione HTTPS.
- Avvia il **loop di rinnovo automatico** Certbot.
- Esegue un `renew --dry-run` per verificare che i rinnovi funzionino.

### Accesso

**https://$SERVER_NAME**

### Comandi Docker in produzione

Per controllare servizi e log usa gli stessi file Compose del deploy:

```bash
docker compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml ps
docker compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml logs --tail=200 nginx
docker compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml logs --tail=200 certbot
```

---

## Frontend (opzionale)

### Sviluppo locale

Per lavorare sul frontend Angular in locale:

```bash
cd frontend
npm install
npm start
```

Configura l’API base nell’environment Angular su `http://localhost:8000` (o usa un proxy).

### Produzione (es. Netlify)

Configurazione tipica:

- Frontend: `https://ticket.tuodominio.it`
- Backend/API: `https://admin.tuodominio.it` (o altro sottodominio)

Nel `.env` del backend imposta CORS:

```bash
CORS_ALLOWED_ORIGINS=https://ticket.tuodominio.it
```

Nel frontend Angular imposta `apiBase` sull’URL del backend (es. `https://admin.tuodominio.it` o `https://admin.tuodominio.it/api`).

---

## Troubleshooting (produzione)

### Verificare i servizi

```bash
docker compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml ps
```

### Log Nginx e Certbot

```bash
docker compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml logs --tail=200 nginx
docker compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml logs --tail=200 certbot
```

### Test rinnovo certificato (dry-run)

```bash
docker compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml run --rm --entrypoint certbot certbot \
  renew --dry-run --webroot -w /var/www/certbot
```

### Problemi SSL comuni

- Il record DNS del dominio non punta al server.
- La porta **80** non è raggiungibile da internet (richiesta per la challenge HTTP-01).
- Con Cloudflare o altro proxy davanti al server: per la prima emissione può essere necessario usare solo DNS (no proxy) sul record.

### Errore Postgres `password authentication failed for user "mixtumuser"`

Questo errore in locale compare spesso quando il volume `postgres_data` era gia stato inizializzato con credenziali diverse rispetto al `POSTGRES_PASSWORD` attuale.

Per evitarlo tra stack paralleli, usa un `INSTANCE_NAME` diverso per ogni istanza (cosi Docker usa risorse separate). Se invece vuoi riutilizzare una stessa istanza, mantieni coerente il valore di `POSTGRES_PASSWORD` nel suo `.env`.
