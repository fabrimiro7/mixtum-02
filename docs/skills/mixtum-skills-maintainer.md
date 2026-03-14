# Mixtum — Skills Documentation Maintainer

This document tells an LLM how to keep the Mixtum skills documentation up to date. It applies when the codebase changes in ways that affect the content of:

- [mixtum-architecture-overview.md](mixtum-architecture-overview.md)
- [mixtum-base-modules-basics.md](mixtum-base-modules-basics.md)

It is intended for human developers and AI systems that modify the project and want the skills to stay synchronized with the actual structure and behavior of the code.

---

## Index

1. [Purpose](#1-purpose)
2. [When this skill must be applied](#2-when-this-skill-must-be-applied)
3. [Update workflow for the LLM](#3-update-workflow-for-the-llm)
4. [Formatting and style rules](#4-formatting-and-style-rules)
5. [Safety rules for doc updates](#5-safety-rules-for-doc-updates)

---

## 1. Purpose

- **For LLMs**: After you make (or are about to make) changes that alter the project structure or the role of base modules, run the workflow below to update the two main skills so they remain accurate.
- **For humans**: Use this as a checklist when you add/remove/rename modules or change architectural rules, so that future readers and LLMs still have correct documentation.

This skill does **not** define how to write code; it defines how to **maintain** the two descriptive skills so they stay in sync with the codebase.

---

## 2. When this skill must be applied

Apply this skill after any change that:

- **Adds, removes, or renames** a top-level directory or important Python package (e.g. a new `base_modules.*` or `plugins.*` app).
- **Adds, removes, or renames** a `base_modules` package, or significantly changes its responsibilities (e.g. a new main model or service layer that other code relies on).
- **Changes architectural rules** (e.g. new cross-module constraints, a new integrations family, or a new way plugins are registered or mounted).
- **Changes URL layout** or how base modules/plugins are included in `mixtum_core/urls.py` or `INSTALLED_APPS`.

You do **not** need to update the skills for:

- Small bug fixes or refactors that do not change module boundaries or public behavior.
- Changes limited to a single plugin’s internal implementation that do not affect the architecture or base module descriptions.

When in doubt, apply the workflow; it is better to make a small, accurate edit than to leave the docs outdated.

---

## 3. Update workflow for the LLM

Follow these steps whenever the conditions in section 2 are met.

1. **Identify what changed**
   - List the paths, modules, models, or services that were added, removed, or renamed.
   - Note any changes to `mixtum_core/urls.py`, `mixtum_core/settings/base.py` (e.g. `INSTALLED_APPS`, middleware), or to dependency rules between modules.

2. **Re-read the two skills**
   - Read [mixtum-architecture-overview.md](mixtum-architecture-overview.md) and [mixtum-base-modules-basics.md](mixtum-base-modules-basics.md) in full.
   - Locate every section that describes the changed parts (e.g. the table of layers, the list of base modules, the per-module subsections, URL structure).

3. **Decide which document and sections are affected**
   - **Architecture overview**: Update when top-level structure, layering, dependency rules, or URL/app registration change. Update the table of layers, “Core concepts and boundaries”, and “Expected behavior for LLMs” if the rules change.
   - **Base modules basics**: Update when a base module is added/removed/renamed or when its role, main models, or usage patterns change. Update “Per-module overview” and, if needed, “Global rules” or “Guidelines for LLM modifications”.

4. **Edit the affected sections**
   - Change only the parts that are no longer accurate. Keep language concise, factual, and consistent with the rest of the file.
   - Add new modules or sections when something new exists in the codebase; remove or rewrite sections when something was removed or renamed.
   - Ensure that examples (e.g. “plugins use `request.workspace`”) and lists (e.g. list of base modules) match the current code.

5. **Verify lists and examples**
   - Cross-check every list (e.g. base module names, integration submodules) against the actual `base_modules/` and `plugins/` directories and `INSTALLED_APPS` / `urls.py`. Fix any mismatch.

6. **When unsure**
   - Prefer **under-documenting** a new module (e.g. a short one-line role) rather than **misdescribing** behavior. You can add more detail in a later pass once the implementation is stable.
   - Do not invent modules, URLs, or behavior that do not exist in the codebase.

---

## 4. Formatting and style rules

- **Headings**: Keep the existing heading hierarchy (one H1 for the title, H2 for main sections, H3 for subsections). Do not change the index structure of the two main skills unless the content no longer fits (e.g. a new major section is needed).
- **Language**: Use clear, imperative language when giving instructions to LLMs (e.g. “Read this document before…”, “Prefer additive changes”).
- **Language of content**: Keep all skill content **in English**, even if code comments or `verbose_name` values in the project are in Italian.
- **Tone**: Match the tone of [mixtum-plugin-standard.md](mixtum-plugin-standard.md)—direct, rule-oriented, suitable for both humans and automated agents.
- **Links**: Use relative links between skills (e.g. `[mixtum-architecture-overview.md](mixtum-architecture-overview.md)`). Keep link targets consistent with the actual file names in `docs/skills/`.

---

## 5. Safety rules for doc updates

- **Do not invent**: Never add descriptions of modules, models, or behavior that do not exist in the codebase. If you are not sure whether something exists, search the repo (e.g. for the module name, class name, or URL path) before writing.
- **Removals and renames**: When removing or renaming something in the docs, cross-check the code to confirm it is no longer present or that the new name is correct. Update all references in both skills (e.g. if a base module is renamed, update the architecture overview and the base modules basics).
- **Minimal edits**: Prefer **appending** clarifications or **editing** only the sentences that are wrong, instead of rewriting large sections when not strictly necessary. This reduces the risk of introducing new errors and keeps diffs reviewable.
- **Consistency**: After editing, ensure that the two skills stay consistent with each other (e.g. the list of base modules in the architecture overview matches the per-module sections in the base modules basics).

When you have completed the workflow, the two main skills should accurately reflect the current Mixtum structure and base module roles so that future LLMs and developers can rely on them.
