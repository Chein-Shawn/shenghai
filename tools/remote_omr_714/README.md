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
- `GET /v1/mode`, `PUT /v1/mode`, and `GET /v1/dashboard/days` require the operator token.

## Email-link access

The App pre-fills `https://omr.vocaldive.com`. A user enters an email address and opens the
one-time link sent as `VocalDive <access@auth.vocaldive.com>` with reply-to
`support@vocaldive.com`. The link expires after fifteen minutes and can only be used once.
The public beta permits ten accepted requests per email and forty per IP address in each
fifteen-minute window. Set `VOCALDIVE_OMR_EMAIL_REQUEST_WINDOW_SECONDS`,
`VOCALDIVE_OMR_EMAIL_REQUEST_LIMIT`, and `VOCALDIVE_OMR_IP_REQUEST_LIMIT` in `.env` to
adjust that policy. A limit response is HTTP `429` with `Retry-After`; a Resend delivery failure
is HTTP `503` and does not consume a request.
The server keeps one account per email hash and creates a different revocable device credential
for each app connection. Device credentials and account ownership limit each account to one queued
or running job and prevent another account from reading its job or MusicXML result.

Resend is the current delivery provider behind a small server-side sending function. Do not add a
mailbox for `access@auth.vocaldive.com`; it is a verified sending identity, while support replies
continue to arrive at `support@vocaldive.com`.

The worker stores filenames, logs, diagnostics, and results locally. Never put the data root,
the generated `.env`, or `tokens.json` in Git.
