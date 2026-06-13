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

`ShenghaiCore` must stay localization-free.

- Do not call `L10n` from `ShenghaiCore`.
- Do not put app-layer display rendering inside shared domain models.
- If shared models need user-facing copy, expose semantic keys, enums, or structured tokens from core, then localize them in `ShenghaiApp`.

Localized text update includes:

- button labels
- navigation titles
- practice-mode labels
- error labels
- onboarding or support text
- status and empty-state messages

Do not add a new user-facing string as a one-language-only placeholder unless it is clearly temporary and blocked from release.

## Implementation Guidance

- Keep user-facing copy localizable through the app localization system.
- Do not concatenate translated sentence fragments.
- Keep music and algorithm terminology consistent across languages.
- When text changes, review screenshots or UI layouts where truncation is possible.

## Task Checklist

Before closing a task or PR, confirm:

- `C4 impact checked`
- `Localized strings updated for en / zh-Hant / ja`
- `Screenshot or UI copy QA completed where needed`

## Documentation Alignment

When product flow changes:

- update the relevant user-flow or product docs
- update C4 architecture notes if structure or data flow changed
- keep localization strategy consistent with shipped language scope
