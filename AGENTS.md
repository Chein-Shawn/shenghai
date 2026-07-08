 # AGENTS.md

Read this file before making any changes in this repository.

## Required Reviews

Every product-facing code change must include:

- a `C4 review`
- a `localization review`

Product-facing code change means any change that affects:

- visible UI text
- screen structure or navigation
- user workflow
- app services used by the flow
- domain models or data flow that should appear in the C4 model

## C4 Review Rule

If a change affects screens, flows, app state, data flow, services, or core components, update the C4 model and related architecture docs in the same change.

This is not optional for product-facing work: whenever code changes affect the app behavior, navigation, data flow, or other user-visible structure, the C4 model must be refreshed before the change is considered complete.

## Localization Rule

Every modification to user-visible app text must update all required shipped language variants in the same change.

Do not leave some languages partially translated while others are updated. If a screen or message changes, review every shipped language version and bring them all up to date together.

Current required languages:

- `en`
- `zh-Hant`
- `zh-Hans`
- `yue`
- `es`
- `ar`
- `ru`
- `pt`
- `id`
- `ja`
- `ko`
- `th`
- `it`
- `de`

## Core Boundary Rule

`VocalDiveCore` must stay localization-free.

- Do not call `L10n` from `VocalDiveCore`.
- Do not put app-layer display rendering inside shared domain models.
- If shared models need user-facing copy, expose semantic keys, enums, or structured tokens from core, then localize them in `VocalDiveApp`.

Localized text update includes:

- button labels
- navigation titles
- practice-mode labels
- error labels
- onboarding or support text
- status and empty-state messages

Do not add a new user-facing string as a one-language-only placeholder unless it is clearly temporary and blocked from release.

## Backup Rule

Every time the program is modified, treat backup as part of the same work cycle.

- Review `git status` before finishing.
- Stage and commit meaningful source, docs, and resource changes when the task is ready for backup.
- Push the backup to GitHub when network/auth permissions allow it.
- If push is blocked, explicitly report the backup status and what remains local.

## Local Signing Rule

Keep personal Apple development-team data out of tracked project files.

- Store machine-specific signing data in `ios-app/Config/Signing/LocalDevelopment.xcconfig`.
- Commit only shared signing defaults and the example template.
- Do not hardcode a personal `DEVELOPMENT_TEAM` into `project.pbxproj` unless the user explicitly asks for that shortcut.

## Implementation Guidance

- Keep user-facing copy localizable through the app localization system.
- Do not concatenate translated sentence fragments.
- Keep music and algorithm terminology consistent across languages.
- When text changes, review screenshots or UI layouts where truncation is possible.

## Task Checklist

Before closing a task or PR, confirm:

- `C4 impact checked`
- `Localized strings updated for all shipped languages`
- `Backup status checked and reported`
- `Sample verification run for score-editor / scan changes`
- `Screenshot or UI copy QA completed where needed`

## Public Brand Note

The public product brand is now `VocalDive` in English and `聲潛` in Traditional Chinese.

- User-facing app, website, and active product docs should use the new brand.
- Existing technical identifiers such as `VocalDiveCore`, `VocalDiveApp`, Xcode target names, bundle identifiers, and legacy storage keys may remain temporarily when needed for compatibility.

## Documentation Alignment

When product flow changes:

- update the relevant user-flow or product docs
- update C4 architecture notes if structure or data flow changed
- keep localization strategy consistent with shipped language scope
