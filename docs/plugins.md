# Plugin: struttura e come creare un nuovo plugin

Un **plugin** in Mixtum è un’estensione che aggiunge funzionalità (es. gestione ticket, progetti) usando solo i **base modules**, Django e DRF. Non può importare da altri plugin. Questa guida spiega la struttura obbligatoria e i passi per creare un nuovo plugin.

Per skeleton completi, convenzioni di naming e checklist dettagliata si veda [docs/skills/mixtum-plugin-standard.md](skills/mixtum-plugin-standard.md).

---

## Cos’è un plugin

- È un’**app Django** nella cartella `plugins/`.
- Implementa una feature specifica (modelli, API, logica) **solo** importando da `base_modules.*`, Django, REST Framework e librerie in `requirements.txt`.
- **Vietato**: `from plugins.altro_plugin import ...`. Per far comunicare due plugin si usano Django signals o si passano oggetti già risolti (es. dal view) ai servizi.

---

## Struttura obbligatoria

Ogni plugin deve avere **esattamente** questa struttura. Nessun file obbligatorio può mancare (anche se inizialmente vuoto o minimale).

```
plugins/
└── plugin_name/
    ├── __init__.py
    ├── apps.py
    ├── models.py
    ├── serializers.py
    ├── views.py
    ├── urls.py
    ├── admin.py
    ├── services.py
    ├── migrations/
    │   └── __init__.py
    └── tests/
        ├── __init__.py
        ├── test_models.py
        ├── test_views.py
        └── test_services.py
```

---

## File opzionali

Aggiungere **solo quando servono**, senza creare file vuoti.

| File | Quando usarlo |
|------|----------------|
| `permissions.py` | Logica di accesso per ruoli o ownership |
| `signals.py` | Reazione a eventi di altri modelli (Django signals) |
| `tasks.py` | Operazioni asincrone con Celery |
| `filters.py` | Filtri complessi sulle liste (oltre ai parametri base) |
| `pagination.py` | Paginazione diversa da quella globale |
| `managers.py` | Query complesse e riutilizzabili sui modelli |
| `constants.py` | Costanti condivise tra più file |
| `exceptions.py` | Eccezioni custom del plugin |

---

## Passi per creare un nuovo plugin

### 1. Partire dal template

Copiare la cartella `plugins/plugin_example` e rinominarla con il nome del nuovo plugin in **snake_case** (es. `ticket_manager`, `project_tasks`).

Oppure creare da zero la cartella `plugins/<plugin_name>/` e tutti i file obbligatori (usando gli skeleton in [docs/skills/mixtum-plugin-standard.md](skills/mixtum-plugin-standard.md)).

### 2. Rinominare tutto

- **Cartella**: `plugin_name` (snake_case).
- **AppConfig** in `apps.py`: classe tipo `TicketManagerConfig`, `name = "plugins.ticket_manager"`, `verbose_name = "Ticket Manager"`.
- Nei file: sostituire `PluginExample` / `plugin_example` / `ExampleModel` con i nomi reali (PascalCase per classi, snake_case per modulo e URL).

### 3. Registrare l’app

In `mixtum_core/settings/base.py`, nella lista `INSTALLED_APPS`, aggiungere:

```python
"plugins.ticket_manager",  # esempio
```

(usare il nome reale del plugin).

### 4. Esporre le URL

In `mixtum_core/urls.py`, aggiungere un `path` che include le URL del plugin sotto `/api/`:

```python
path('api/ticket-manager/', include(('plugins.ticket_manager.urls', 'ticket_manager'), namespace='ticket_manager')),
```

Usare **kebab-case** nel path (`ticket-manager`, non `ticket_manager`). Le URL definite nel plugin (es. `examples/`, `examples/<int:pk>/`) saranno quindi sotto `/api/ticket-manager/examples/`, ecc.

### 5. Migrations

Dalla root del progetto (con ambiente attivo o via container):

```bash
# Creare le migrations per il nuovo plugin
python manage.py makemigrations ticket_manager

# Applicarle
python manage.py migrate
```

In locale con Docker/Makefile: `make makemigrations` e `make migrate` (il comando va eseguito nel contesto del container `web` come già configurato nel Makefile).

---

## Regole essenziali

- **Logica di business**: solo in `services.py`. Le view chiamano i servizi; non contengono logica.
- **Modelli**: devono avere almeno `workspace` (FK), `created_by` (FK User, opzionale), `created_at`, `updated_at`, `__str__`, `Meta` con `ordering` e `verbose_name`.
- **View**: sottili; sempre `permission_classes` espliciti (es. `IsAuthenticated`); niente query dirette, solo chiamate ai servizi.
- **URL**: kebab-case con trailing slash (es. `tickets/`, `tickets/<int:pk>/`). In `urls.py` del plugin: `app_name` obbligatorio, ogni path con `name`.
- **Nessun import** da altri plugin.

---

## Esempio concreto: plugin_example

Il plugin di esempio espone:

- **Modello**: `ExampleModel` (workspace, created_by, name, created_at, updated_at) in `plugins/plugin_example/models.py`.
- **API**:
  - `GET/POST /api/plugin-example/examples/` — lista e creazione.
  - `GET/PATCH/DELETE /api/plugin-example/examples/<id>/` — dettaglio, aggiornamento, eliminazione.
- **View**: delegano a `ExampleModelService` in `services.py`; usano `request.workspace` e `request.user`.
- **Servizi**: metodi statici `get_list`, `get_by_id`, `create`, `update`, `delete`.

Puoi usare `plugin_example` come riferimento per struttura, stile e uso di workspace/user; per skeleton completi e convenzioni (serializer read/write, admin, test) vedi [docs/skills/mixtum-plugin-standard.md](skills/mixtum-plugin-standard.md).
