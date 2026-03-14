# Mixtum — Base Modules Basics

This document is the reference for understanding and safely modifying the `base_modules` of the Mixtum framework. It is intended for human developers and AI systems that generate or modify code. It describes the role of each base module and the rules that LLMs must follow when changing them.

---

## Index

1. [Purpose](#1-purpose)
2. [Global rules for base modules](#2-global-rules-for-base-modules)
3. [Per-module overview](#3-per-module-overview)
4. [Guidelines for LLM modifications in base_modules](#4-guidelines-for-llm-modifications-in-base_modules)

---

## 1. Purpose

- **For LLMs**: Before changing any code under `base_modules/`, read this document and the relevant module section. Prefer additive changes; avoid breaking existing behavior used by plugins or other base modules.
- **For humans**: Use it to see what each base module is responsible for and how plugins typically consume it.

This skill complements the [Mixtum architecture overview](mixtum-architecture-overview.md) and the [plugin development standard](mixtum-plugin-standard.md). When implementing plugin features, follow the plugin standard; when modifying or extending base modules, follow this document.

---

## 2. Global rules for base modules

### 2.1 Role and stability

- **base_modules** provide shared infrastructure consumed by plugins and possibly by external API clients.
- Changes in base modules can impact many plugins. **Backward compatibility** and **stability** are required: avoid renaming or removing public models, service methods, or URL patterns without a clear migration path.

### 2.2 Allowed dependencies

- A base module MAY import from:
  - `django.*`, `rest_framework.*`
  - Other `base_modules.*` packages when needed (e.g. workspace uses user_manager, branding uses workspace).
  - Third-party libraries listed in the project’s `requirements.txt`.
- A base module MUST NOT import from:
  - Any plugin (`plugins.*`).

### 2.3 Code organization

- The same layering as in the plugin standard applies: **business logic in services**, **views thin** (delegate to services), **models** for data structure and simple helpers only. When in doubt, align with [mixtum-plugin-standard.md](mixtum-plugin-standard.md) (serializers, views, services, models rules).

---

## 3. Per-module overview

### 3.1 user_manager

- **Role**: Custom user model, authentication, and permission levels.
- **Key concepts**:
  - **User** (extends Django’s `AbstractBaseUser`, `PermissionsMixin`): email as `USERNAME_FIELD`, permission level (`permission`), user type, profile fields (name, phone, avatar, etc.).
  - **UserManager**: `create_user`, `create_superuser`.
  - Permission levels (e.g. SuperAdmin, Associate, Utente, Employee) and helpers like `is_superadmin()`, `is_associate()`, `is_at_least_associate()`.
  - Optional: Keycloak integration (`integrations/auth_keycloak.py`), headless auth wrapper (`headless_wrapper*.py`) for token-based auth.
- **Typical usage**: Plugins import `from base_modules.user_manager.models import User` and use `User` for FKs (`created_by`, etc.) and permission checks. They do not subclass User.

### 3.2 workspace

- **Role**: Multi-tenancy via workspaces; current workspace per request.
- **Key concepts**:
  - **Workspace**: name, description, logo; no direct FK to User.
  - **WorkspaceUser**: many-to-many between User and Workspace with role; `unique_together = ('user', 'workspace')`.
  - **WorkspaceMiddleware**: reads `X-Workspace-Id` header, resolves the workspace for the authenticated user, sets **`request.workspace`**. If the header is missing, it may use a fallback (e.g. first workspace). Returns 403 if the user is not a member of the requested workspace.
- **Typical usage**: Plugins pass `request.workspace` into their services and scope all workspace-scoped models by `workspace`. Models that belong to a tenant have an FK to `Workspace`.

### 3.3 attachment

- **Role**: Generic file uploads associated with a user (author).
- **Key concepts**:
  - **Attachment**: title, author (FK to User), file, description, creation_date. No GenericForeignKey in the current model; attachments are often linked to other entities by convention (e.g. same app) or by adding FKs in plugins.
- **Typical usage**: Plugins use the attachment API to upload/list/delete files; they may reference attachments by ID or extend usage via their own FKs.

### 3.4 branding

- **Role**: Per-workspace (or global) branding: logos, colors, favicon.
- **Key concepts**:
  - **BrandingSettings**: optional OneToOne to Workspace, fields such as `colors` (JSON), `logo_full`, `logo_compact`, `favicon`, timestamps.
- **Typical usage**: Frontend or other modules read branding via the branding API to render the UI. Changes should preserve the existing API and field semantics.

### 3.5 links

- **Role**: Managed links (URLs) attachable to any model via ContentType (GenericForeignKey).
- **Key concepts**:
  - **Link**: title, description, url, label (e.g. Google Drive, Figma, GitHub), `content_type` + `object_id` for the target object. Used for projects, tickets, tasks, etc.
  - **LINK_LABEL_CHOICES**: stable labels for integrations/filters.
  - **filters.py**: filter logic for link lists.
- **Typical usage**: Plugins create links tied to their models (e.g. ticket, project) via the links API; they use the same ContentType pattern when querying.

### 3.6 mailer

- **Role**: Email sending with templates and queueing (Celery).
- **Key concepts**:
  - **EmailTemplate**: stored templates (name, slug, subject_template, html_template, text_template) using Django template syntax.
  - **Email**: single send record (from_email, to/cc/bcc as JSON, subject, body_text/body_html, optional template + context, status).
  - **EmailStatus**: draft, queued, sending, sent, failed.
  - **Services**: logic to build and enqueue emails.
  - **tasks.py**: Celery tasks for actual sending.
- **Typical usage**: Plugins call mailer services or tasks to send emails; they do not bypass the mailer to send mail directly.

### 3.7 key_manager

- **Role**: Secure storage for configuration keys and sensitive values (e.g. API keys).
- **Key concepts**:
  - **ConfigSetting**: key, value (text), optional description. Used for secrets and config that must live in the DB.
  - **utils**: helpers for reading/using keys (see `key_manager/utils.py`).
- **Typical usage**: Other modules or plugins retrieve config via key_manager instead of hardcoding secrets; do not expose raw values in APIs unnecessarily.

### 3.8 the_watcher

- **Role**: Auditing and logging of errors/events.
- **Key concepts**:
  - **Logs**: message, exception_type, category, timestamp, extra_data (JSON). Used for exception/audit logs.
  - **create_log(...)**: helper to create log entries.
- **Typical usage**: Plugins and base modules call `create_log` or write to Logs for diagnostics and auditing; avoid removing or changing the schema in a way that breaks existing log consumers.

### 3.9 integrations (messaging, notifications, automation, ai)

- **Role**: Integration points with external systems (e.g. Slack, n8n, WhatsApp/Twilio).
- **Key concepts**:
  - **messaging**: WhatsApp/Twilio (e.g. conversations, messages, statuses); webhooks and services for sending/receiving.
  - **notifications**: e.g. Slack-related endpoints and payloads.
  - **automation**: e.g. n8n webhooks or automation triggers.
  - **ai** (if present): AI provider integrations.
- **Typical usage**: External systems call webhooks; internal code calls integration services. Changes to URLs or payload formats can break external clients—document and version where possible.

---

## 4. Guidelines for LLM modifications in base_modules

### 4.1 Prefer additive changes

- Prefer **new** services, **new** methods, **new** fields with safe defaults, **new** URL namespaces or views.
- Avoid removing or renaming public models, fields, or service methods used by plugins or other base modules unless you have an explicit requirement and migration plan.

### 4.2 When modifying models

- Keep existing fields, `verbose_name`, `ordering`, and constraints unless the change is explicitly required.
- Add migrations for any schema change; keep migration and model field names consistent with existing style.
- Preserve `__str__`, `Meta`, and any indexes that are part of the public behavior.

### 4.3 When modifying services, views, serializers

- Follow the same rules as in [mixtum-plugin-standard.md](mixtum-plugin-standard.md): business logic in services, views delegate to services, serializers with explicit `fields` (no `__all__`), read_only for id/created_at/updated_at/created_by where appropriate.
- Do not move business logic from services into views or models.

### 4.4 Before changing a base module

- **Check dependents**: Search the codebase for imports and references to the module, its models, or its services. Assess impact on plugins and other base modules.
- **Update tests**: If behavior changes, update or add tests; do not leave failing tests or untested new behavior.

### 4.5 Summary for LLMs

- Read the relevant section of this document before editing a base module.
- Prefer additive changes; avoid breaking existing callers.
- Keep models/serializers/views/services layering consistent with the plugin standard.
- After changes that add/remove/rename modules or their responsibilities, update [mixtum-architecture-overview.md](mixtum-architecture-overview.md) and this document using the [skills maintainer](mixtum-skills-maintainer.md) workflow.
