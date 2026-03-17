# Base modules: caratteristiche e funzioni

I **base modules** sono i blocchi condivisi di Mixtum: forniscono infrastruttura (utenti, workspace, email, integrazioni, ecc.) usata dai plugin e dalle API. Questa guida descrive in modo pratico cosa fa ogni modulo e come si usa durante lo sviluppo.

Per le linee guida su come modificarli in sicurezza (anche per LLM) si veda [docs/skills/mixtum-base-modules-basics.md](skills/mixtum-base-modules-basics.md).

---

## Ruolo dei base modules

- Sono **infrastruttura condivisa**: i plugin non implementano utenti, multi-tenancy o invio email da zero, ma usano questi moduli.
- Le modifiche hanno impatto su più punti: vanno fatte con **retrocompatibilità**. Evitare di rinominare o rimuovere modelli, metodi di servizio o URL usati dai plugin o da altri base modules.
- **Nessun base module** importa da un plugin; possono invece dipendere tra loro (es. workspace usa user_manager, branding usa workspace).

---

## Panoramica per modulo

### user_manager

| Aspetto | Descrizione |
|--------|-------------|
| **Ruolo** | Modello utente custom, autenticazione e livelli di permesso. |
| **Modelli / concetti** | **User** (email come username, livelli permesso, profilo: nome, telefono, avatar). **UserManager** per `create_user` / `create_superuser`. Livelli (es. SuperAdmin, Associate, Utente, Employee) e helper tipo `is_superadmin()`, `is_associate()`. Opzionali: integrazione Keycloak, headless auth (JWT/token) in `headless_wrapper*.py`. |
| **Uso tipico** | Nei plugin: `from base_modules.user_manager.models import User`; FK tipo `created_by`, `request.user`, controlli permesso. Non si creano sottoclassi di User. |

---

### workspace

| Aspetto | Descrizione |
|--------|-------------|
| **Ruolo** | Multi-tenancy: ogni “tenant” è un workspace; la richiesta ha un workspace corrente. |
| **Modelli / concetti** | **Workspace** (nome, descrizione, logo). **WorkspaceUser** (N-N tra User e Workspace con ruolo). **WorkspaceMiddleware**: legge l’header `X-Workspace-Id`, risolve il workspace per l’utente autenticato e imposta **`request.workspace`** (o un fallback). Restituisce 403 se l’utente non è membro del workspace richiesto. |
| **Uso tipico** | Nei plugin: passare `request.workspace` ai servizi; tutti i modelli “per tenant” hanno una FK a `Workspace` e le query sono filtrate per workspace. |

---

### attachment

| Aspetto | Descrizione |
|--------|-------------|
| **Ruolo** | Upload generico di file, associati a un autore (User). |
| **Modelli / concetti** | **Attachment**: titolo, autore (FK User), file, descrizione, data. Il legame ad altre entità (ticket, progetti) può essere per convenzione o tramite FK definite nei plugin. |
| **Uso tipico** | Usare l’API attachment per upload / elenco / eliminazione; i plugin possono referenziare attachment per ID o aggiungere FK nei propri modelli. |

---

### branding

| Aspetto | Descrizione |
|--------|-------------|
| **Ruolo** | Branding per workspace (o globale): logo, colori, favicon. |
| **Modelli / concetti** | **BrandingSettings**: relazione opzionale con Workspace, campi come `colors` (JSON), `logo_full`, `logo_compact`, `favicon`, timestamp. |
| **Uso tipico** | Il frontend (o altri moduli) leggono il branding via API per renderizzare l’interfaccia. Mantenere compatibilità di API e campi. |

---

### links

| Aspetto | Descrizione |
|--------|-------------|
| **Ruolo** | Link gestiti (URL) collegabili a qualsiasi modello tramite ContentType (GenericForeignKey). |
| **Modelli / concetti** | **Link**: titolo, descrizione, url, label (es. Google Drive, Figma, GitHub), `content_type` + `object_id` per l’oggetto target. **LINK_LABEL_CHOICES** per filtri/integrazioni. **filters.py** per la logica di filtro sugli elenchi. |
| **Uso tipico** | I plugin creano link associati ai propri modelli (ticket, progetto, ecc.) tramite l’API links e usano lo stesso schema ContentType per le query. |

---

### mailer

| Aspetto | Descrizione |
|--------|-------------|
| **Ruolo** | Invio email con template e coda (Celery). |
| **Modelli / concetti** | **EmailTemplate** (nome, slug, subject/html/text con sintassi Django). **Email**: record di invio (from, to/cc/bcc in JSON, subject, body, eventuale template+context, stato). **EmailStatus**: draft, queued, sending, sent, failed. Servizi per costruire e mettere in coda; **tasks.py** Celery per l’invio effettivo. |
| **Uso tipico** | I plugin chiamano i servizi o i task del mailer per inviare email; non inviano mail direttamente (es. non usare `send_mail` Django senza passare dal mailer). |

---

### key_manager

| Aspetto | Descrizione |
|--------|-------------|
| **Ruolo** | Memorizzazione sicura di chiavi e valori sensibili (es. API key). |
| **Modelli / concetti** | **ConfigSetting**: chiave, valore (testo), descrizione opzionale. Utility in `key_manager/utils.py` per leggere/usare le chiavi. |
| **Uso tipico** | Plugin e altri moduli leggono la config tramite key_manager invece di hardcodare secret; evitare di esporre i valori in chiaro nelle API. |

---

### the_watcher

| Aspetto | Descrizione |
|--------|-------------|
| **Ruolo** | Audit e log di errori/eventi. |
| **Modelli / concetti** | **Logs**: message, exception_type, category, timestamp, extra_data (JSON). Helper **create_log(...)** per creare voci. |
| **Uso tipico** | Plugin e base modules chiamano `create_log` o scrivono su Logs per diagnostica e audit; evitare modifiche allo schema che rompano chi già consuma i log. |

---

### integrations

| Aspetto | Descrizione |
|--------|-------------|
| **Ruolo** | Punto di integrazione con sistemi esterni: messaggistica, notifiche, automazione, AI. |
| **Sotto-moduli** | **messaging**: WhatsApp/Twilio (conversazioni, messaggi, stati); webhook e servizi per invio/ricezione. **notifications**: endpoint e payload per Slack. **automation**: webhook n8n e trigger. **ai** (se presente): integrazioni provider AI. |
| **Uso tipico** | I sistemi esterni chiamano i webhook; il codice interno usa i servizi delle integrations. Modifiche a URL o formato payload possono rompere i client esterni: documentare e versionare dove possibile. |

---

## Dipendenze tra moduli

- **workspace** può usare **user_manager** (WorkspaceUser lega User e Workspace).
- **branding** può usare **workspace** (BrandingSettings legato al Workspace).
- **attachment** usa **user_manager** (autore = User).
- Nessun base module dipende da un plugin.

Per dettagli sulle regole di modifica e sulla stabilità delle API: [docs/skills/mixtum-base-modules-basics.md](skills/mixtum-base-modules-basics.md).
