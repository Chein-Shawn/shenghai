# VocalDive Google Sheets Feedback Backend

This folder contains the free v1 feedback backend for VocalDive:

`VocalDive app -> Google Apps Script web app -> Google Sheet -> optional email notification`

## Files

- `VocalDiveFeedbackSheet.gs`
  - receives JSON via `doPost(e)`
  - appends one row to your Google Sheet
  - optionally emails you when feedback arrives

## Setup

1. Create a Google Sheet for VocalDive feedback.
2. Open [Google Apps Script](https://script.google.com/).
3. Create a standalone script project.
4. Paste the contents of `VocalDiveFeedbackSheet.gs`.
5. Replace:
   - `spreadsheetId`
   - `notificationEmail` if needed
6. Deploy as a web app:
   - Execute as: `Me`
   - Who has access: the audience you want to allow
7. Copy the `/exec` URL.
8. Paste that URL into:
   - [FeedbackConfiguration.json](/Users/shawn/Documents/Codex/vocaldive/ios-app/VocalDiveCore/Sources/VocalDiveApp/Resources/FeedbackConfiguration.json)
     - key: `appsScriptEndpoint`

## Google Sheet Columns

The script creates these columns on first write:

1. `Created At`
2. `Category`
3. `Summary`
4. `Details`
5. `Reply Email`
6. `Current Screen Key`
7. `Current Screen Title`
8. `App Version`
9. `Build Number`
10. `Platform`
11. `OS Version`
12. `Display Language`
13. `App Stage`
14. `Source`
15. `Status`
16. `Internal Notes`

## Notes

- The app sends text feedback only in v1.
- The script escapes spreadsheet-formula prefixes such as `=`, `+`, `-`, and `@` before writing cells.
- The endpoint URL is public by nature; do not treat it as a secret.
- Spam protection in v1 is lightweight:
  - hidden honeypot field
  - client cooldown
  - length validation

## Relevant App Files

- [SupportView.swift](/Users/shawn/Documents/Codex/vocaldive/ios-app/VocalDiveCore/Sources/VocalDiveApp/Views/SupportView.swift)
- [FeedbackSubmissionService.swift](/Users/shawn/Documents/Codex/vocaldive/ios-app/VocalDiveCore/Sources/VocalDiveApp/Services/FeedbackSubmissionService.swift)
- [FeedbackConfiguration.swift](/Users/shawn/Documents/Codex/vocaldive/ios-app/VocalDiveCore/Sources/VocalDiveApp/Support/FeedbackConfiguration.swift)
