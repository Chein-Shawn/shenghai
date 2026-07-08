# Google Sheets Feedback Backend

Date: 2026-06-13

## Goal

Keep VocalDive feedback native inside the app, but store it in a free, stable backend that is easy to manage.

Chosen v1 path:

```text
Settings > Feedback
  -> FeedbackSubmissionService
  -> Google Apps Script web app
  -> Google Sheet
  -> optional email notification
```

## Why this path

- free to operate
- easy to inspect manually
- structured enough for bug triage
- no GitHub account required from end users
- easy to expand later into Airtable, Notion, or a full CRM/helpdesk

## Stored fields

- category
- summary
- details
- reply email
- current screen key
- current screen title
- app version
- build number
- platform
- OS version
- display language
- app stage
- source
- status
- internal notes

## Guardrails

- lightweight client cooldown
- honeypot field for simple bot filtering
- input-length limits
- spreadsheet-formula escaping before row append
- no attachments in v1

## Current constraint

The repo now contains the app-side integration and the Apps Script backend file, but the live feedback endpoint only starts working after:

1. you deploy the Apps Script web app
2. you paste the `/exec` URL into [FeedbackConfiguration.json](/Users/shawn/Documents/Codex/vocaldive/ios-app/VocalDiveCore/Sources/VocalDiveApp/Resources/FeedbackConfiguration.json)

Until then, the app shows feedback as unavailable instead of pretending it was sent.
