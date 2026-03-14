# Mixtum — Architecture Overview

This document defines the high-level structure of the Mixtum framework. It is intended for human developers and AI systems that generate or modify code in the project. It provides a mental model of the codebase before making changes. This is a **descriptive, read-only** reference: it does not teach how to implement features step by step.

---

## Index

1. [Purpose](#1-purpose)
2. [High-level architecture](#2-high-level-architecture)
3. [Django project layout](#3-django-project-layout)
4. [Core concepts and boundaries](#4-core-concepts-and-boundaries)
5. [Expected behavior for LLMs using this skill](#5-expected-behavior-for-llms-using-this-skill)

---

## 1. Purpose

- **For LLMs**: Read this document before performing large refactors or when creating new modules or plugins. It establishes the layering and boundaries you must preserve.
- **For humans**: Use it as the single source of truth for "where things live" and "what depends on what" in Mixtum.

This skill does **not** replace:
- The plugin development standard ([mixtum-plugin-standard.md](mixtum-plugin-standard.md)) for how to build plugins.
- The base modules reference ([mixtum-base-modules-basics.md](mixtum-base-modules-basics.md)) for details on `base_modules`.

---

## 2. High-level architecture

Mixtum is a **Django-based backend** whose application logic is organized as follows:

| Layer | Path | Role |
|-------|------|------|
| **Core** | `mixtum_core/` | Django project: settings, root URL configuration, global middleware. |
| **Base modules** | `base_modules/` | Reusable building blocks: users, workspaces, attachments, branding, mailer, integrations, etc. |
| **Plugins** | `plugins/` | Feature-specific extensions that depend only on `base_modules` and follow the plugin standard. |
| **Documentation** | `docs/` | Project docs; `docs/skills/` contains LLM-oriented skills and standards. |
| **Deployment** | Root + `docker/`, `nginx/`, `scripts/` | `Makefile`, `.env`, `Dockerfile`, docker-compose files, nginx configs, deploy scripts. |

Important constraints:

- **Plugins** MUST NOT import from other plugins. They MAY import from `base_modules.*`, Django, DRF, and project-wide dependencies.
- **Base modules** provide shared infrastructure; they MUST NOT depend on any specific plugin.

---

## 3. Django project layout

### 3.1 `mixtum_core/`

- **Responsibility**: Global Django configuration.
- **Contents**:
  - `settings/` — base, auth, and environment-specific settings.
  - `urls.py` — root URL routing; includes `base_modules` and `plugins` URLconfs under `/api/...`.
- **LLM note**: Changing URLs or middleware here affects the whole application. Prefer adding new `path(...)` or `include(...)` entries rather than removing or rewriting existing ones without explicit requirement.

### 3.2 How apps are registered and exposed

- **INSTALLED_APPS** (in `mixtum_core/settings/base.py`): All `base_modules.*` apps and plugin apps are listed here. New plugins or base modules must be added to `INSTALLED_APPS` and, for HTTP API, to `mixtum_core/urls.py`.
- **URL structure**: Base modules and plugins are mounted under `/api/...` (e.g. `/api/v1/users/`, `/api/workspace/`, `/api/plugin-example/`). Each app exposes its own `urls.py` via `include()`.

---

## 4. Core concepts and boundaries

### 4.1 Separation of concerns

- **base_modules** provide:
  - **user_manager** — custom User model, authentication, permissions.
  - **workspace** — workspaces as tenants; middleware for current workspace.
  - **attachment** — generic file uploads linked to other models.
  - **branding** — branding configuration (logos, colors, names).
  - **links** — managed links/URLs and filters.
  - **mailer** — email sending (models, services, Celery tasks).
  - **key_manager** — secure storage for API keys/sensitive data.
  - **the_watcher** — auditing/logging/tracking.
  - **integrations** — messaging, notifications, automation (and AI where present): integration points with external systems.

- **plugins** implement business features (e.g. ticket management, project management) on top of `base_modules`. They use `User`, `Workspace`, and other base_module services; they do not define core identity or multi-tenancy.

### 4.2 Boundaries that must not be broken

- **Dependency direction**: Plugins → base_modules → Django/DRF/dependencies. Never: base_modules → plugins, or plugin A → plugin B.
- **Cross-plugin communication**: Use Django signals or pass already-resolved objects (e.g. from the view) into services. Do not import from another plugin.

---

## 5. Expected behavior for LLMs using this skill

When modifying the Mixtum project:

1. **Read this document** before large refactors or when creating new modules or plugins.
2. **Preserve** the existing architectural layering and import rules (plugins do not import plugins; base_modules do not import plugins).
3. **Prefer extending via plugins** instead of changing `base_modules` unless the change is clearly foundational (e.g. a new shared service used by many plugins).
4. **When adding** a new base module or plugin: add it to `INSTALLED_APPS` and, if it exposes HTTP API, to `mixtum_core/urls.py` with a consistent path pattern (e.g. `/api/<module-name>/`).
5. **When removing or renaming** a module: update settings, URLs, and any references in other base_modules or in documentation; do not leave broken imports or URL includes.
