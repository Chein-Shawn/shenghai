# VocalDive 714 OMR worker

This folder is the deployable OMR service for the Windows host named `714`.
It accepts a single PDF of at most 30 pages or a batch of at most 30 score images, with a
50 MiB total upload limit. It stores each job under `data/YYYY-MM-DD/<job-id>/` until the
host owner manually removes completed date folders.

## Install on 714

1. Install a current NVIDIA driver, Python 3.11, Cloudflared, and Git.
2. Copy this folder to `D:\VocalDiveOMR\service`.
3. In PowerShell, run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, then run
   `powershell -ExecutionPolicy Bypass -File .\install.ps1` from this folder.
4. Copy `.env.example` to `.env`; set the intended data drive, public address, and restricted
   Resend sending API key. The key belongs only in this copied `.env` file. The worker uses its
   bundled `certifi` certificate store for the Resend HTTPS connection, so it does not depend on
   the Windows PowerShell certificate configuration.
5. Copy `tokens.example.json` to `D:\VocalDiveOMR\state\tokens.json` and replace the sample
   value with one long random **operator** token. It is only for the host's mode and storage-dashboard APIs.
6. Run `powershell -ExecutionPolicy Bypass -File .\run.ps1` once. Open
   `http://127.0.0.1:8787/v1/health` on 714 and confirm `ready: true`.
7. Create a Cloudflare Tunnel public hostname `omr.vocaldive.com` that forwards to
   `http://127.0.0.1:8787`. Keep FastAPI bound to loopback and do not expose port 8787 through
   the router or Windows firewall.
8. Create the included Scheduled Task using the command printed by `install.ps1`. It starts
   at boot, whether or not a desktop user is logged in.

## Data protection and CRM

714 is the beta OMR, account, device, correction-record, and small CRM server. Cloudflare
Tunnel is only the HTTPS route to the loopback service; it is not a database and does not
store jobs or accounts.

- `D:\VocalDiveOMR\data\YYYY-MM-DD\<job-id>\` holds raw uploads, rendered pages, oemer
  diagnostics, the candidate, and a completed-correction copy. The owner manages these
  date folders manually.
- `D:\VocalDiveOMR\state\jobs.sqlite3` is the durable worker queue. `crm.sqlite3` holds
  accounts, devices, email-link sessions, consent, profile fields, and training-record
  metadata. The worker migrates existing beta identities into `crm.sqlite3` on startup.
- Email, birthday, and singing goals are ordinary SQLite fields. Device credentials and
  email-link secrets are stored only as SHA-256 hashes. Never add raw credentials to either
  database, a log, or Git.
- Each account/installation pair is unique. Reconnecting the same app installation revokes
  its prior credential and issues one replacement; another device receives a different,
  revocable credential. A verification link is one-use and expires after fifteen minutes.
- Deleting an account revokes every device credential and removes CRM profile data.
  Completed correction records remain without the personal profile so previously accepted
  training material remains traceable by checksum.

Before accepting real beta users, enable BitLocker for the drive that contains
`D:\VocalDiveOMR`, store the recovery key safely, then open an elevated PowerShell and run:

```powershell
cd D:\VocalDiveOMR\service\remote_omr_714
.\harden_state_directory.ps1
.\verify_data_protection.ps1
```

The ACL script limits `D:\VocalDiveOMR\state` and the service `.env` (which contains the
Resend key) to `SYSTEM` and local Administrators. It is transparent to the worker after
installation. Do not run it until the host owner confirms that the worker runs under one of
those identities.

## CRM backup to Google Drive

Only the CRM database, schema version, and checksum audit manifest are backed up. Raw score
files, page images, oemer diagnostics, and date/job folders are deliberately excluded.

1. Install [rclone](https://rclone.org/downloads/) on 714 and create a Google Drive remote:

   ```powershell
   rclone config --config D:\VocalDiveOMR\state\rclone.conf
   ```

2. Add these values to the copied `.env`. The remote path is a Google Drive folder, not a
   public URL:

   ```text
   VOCALDIVE_OMR_CRM_DATABASE=D:\VocalDiveOMR\state\crm.sqlite3
   VOCALDIVE_OMR_RCLONE_CONFIG=D:\VocalDiveOMR\state\rclone.conf
   VOCALDIVE_OMR_GOOGLE_DRIVE_REMOTE=vocaldive-drive:VocalDiveOMR/CRM
   ```

3. Run one backup and a separate-file restore test before scheduling it:

   ```powershell
   .\backup_google_drive.ps1
   .\restore_crm_backup.ps1 -Date 2026-07-29
   ```

4. Once those pass, open elevated PowerShell and install the daily 03:15 task:

   ```powershell
   .\install_crm_backup_task.ps1
   ```

Google Drive protects the backup through the Drive account and its normal transport/storage
encryption. This beta deliberately does not add client-side encrypted archives, so a database
restore remains straightforward.

## Host operation

- The API process is light. A single worker performs GPU OMR one job at a time.
- `Available` starts queued work immediately. `Quiet` starts a job only when NVIDIA GPU
  utilization and VRAM use are below configured thresholds. `Paused` keeps jobs queued.
- If 714 restarts, jobs interrupted while rasterizing, recognizing, or assembling are returned
  to the SQLite queue once. App uploads use a stable idempotency key, so a retry does not create
  a second server job. The app also retains its own staged source copy until it receives MusicXML.
- Use `GET /v1/dashboard/days` to inspect daily storage. Delete only complete date folders
  manually in Explorer or PowerShell; never delete a day with a `running` job.
- oemer accepts images, so PDFs are rasterized locally before page-by-page recognition.
  Page MusicXML outputs are merged only when their part layouts match; otherwise the job
  fails clearly rather than inventing a combined score.

## API

- `GET /v1/health`
- `POST /v1/auth/request-link` sends a one-time email link and returns a short-lived poll session.
- `GET /v1/auth/verify` consumes the email link; `POST /v1/auth/poll` delivers the device credential
  only to the app that requested the link.
- `POST /v1/jobs` multipart field `files`, header `Authorization: Bearer <device credential>`, optional
  header `Idempotency-Key`
- `GET /v1/jobs/{job_id}`, `GET /v1/jobs/{job_id}/result`, `DELETE /v1/jobs/{job_id}`
- `GET`, `PUT`, and `DELETE /v1/account` manage the authenticated account profile.
- `POST /v1/jobs/{job_id}/corrections` records a completed correction once. It requires the
  source job, its candidate MusicXML, completed-correction consent, and valid corrected XML.
  If the host owner deleted the date folder already, it returns `410` and the App asks for a
  new upload instead of creating an incomplete training record.
- `GET /v1/mode`, `PUT /v1/mode`, and `GET /v1/dashboard/days` require the operator token.

## Email-link access

The App pre-fills `https://omr.vocaldive.com`. A user enters an email address and opens the
one-time link sent as `VocalDive <access@auth.vocaldive.com>` with reply-to
`support@vocaldive.com`. The link expires after fifteen minutes and can only be used once.
`POST /v1/auth/request-link` returns its expiry as RFC 3339 UTC in the form
`2026-07-30T12:34:56Z`; the App also accepts earlier fractional-second values while a server
update is rolling out. The App saves the pending poll secret in Keychain and only its non-secret
login metadata in app storage, so returning from the email or reopening VocalDive resumes the
same pending connection. The verification page deliberately tells the user to return to the
device that requested the link: it may be opened on another phone, iPad, Mac, or browser, so a
deep link cannot safely identify the requesting installation.
The public beta permits ten accepted requests per email and forty per IP address in each
fifteen-minute window. Set `VOCALDIVE_OMR_EMAIL_REQUEST_WINDOW_SECONDS`,
`VOCALDIVE_OMR_EMAIL_REQUEST_LIMIT`, and `VOCALDIVE_OMR_IP_REQUEST_LIMIT` in `.env` to
adjust that policy. A limit response is HTTP `429` with `Retry-After`; a Resend delivery failure
is HTTP `503` and does not consume a request.
The server keeps one account per normalized email and creates a different revocable device credential
for each app connection. Device credentials and account ownership limit each account to one queued
or running job and prevent another account from reading its job or MusicXML result.

Resend is the current delivery provider behind a small server-side sending function. Do not add a
mailbox for `access@auth.vocaldive.com`; it is a verified sending identity, while support replies
continue to arrive at `support@vocaldive.com`.

If a link request returns HTTP `503`, keep `run.ps1` open and inspect the matching Resend warning.
It includes the provider's sanitized rejection reason and the configured sender, but never the
recipient address, verification URL, or API key. A `403` normally means that the Resend API key is
not authorized to send as `access@auth.vocaldive.com`, or that the sender domain is not yet verified
for that key. Correct the Resend key/domain configuration in `.env`, then restart the worker.
The direct Python request must also send `User-Agent: VocalDiveOMR/1.0`; Resend rejects a missing
header with error code `1010`, even when the API key and domain are correct.

The worker stores filenames, logs, diagnostics, and results locally. Never put the data root,
the generated `.env`, or `tokens.json` in Git.

## Correction lifecycle

The App exposes two distinct actions in the review workspace:

- `暫存進度` / Save progress persists the edited MusicXML on the Apple device only. It sends
  no correction record to 714.
- `完成校正` / Complete correction first saves the final local MusicXML, then submits one
  idempotent record that links the existing server job, candidate MusicXML, source checksums,
  corrected MusicXML, metadata, account ID, and accepted consent version.

Use direct 714 smoke tests with one small image and one small PDF before testing Xcode:
confirm the job reaches `ready`, download valid MusicXML, and then verify the correction route
after editing it in VocalDive. Keep the original test files outside this source folder; the
actual product uploads from the Apple client.
