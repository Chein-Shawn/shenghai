# VocalDive 714 OMR worker

This folder is the deployable, private-beta OMR service for the Windows host named `714`.
It accepts a single PDF of at most 30 pages or a batch of at most 30 score images, with a
50 MiB total upload limit. It stores each job under `data/YYYY-MM-DD/<job-id>/` until the
host owner manually removes completed date folders.

## Install on 714

1. Install a current NVIDIA driver, Python 3.11, Tailscale, and Git.
2. Copy this folder to `D:\VocalDiveOMR\service`.
3. In PowerShell, run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, then run
   `powershell -ExecutionPolicy Bypass -File .\install.ps1` from this folder.
4. Copy `.env.example` to `.env`; set the intended data drive if `D:` is not appropriate.
5. Copy `tokens.example.json` to `D:\VocalDiveOMR\state\tokens.json` and replace the sample
   value with a long random token for each beta tester.
6. Run `powershell -ExecutionPolicy Bypass -File .\run.ps1` once. Open
   `http://127.0.0.1:8787/v1/health` on 714 and confirm `ready: true`.
7. In an elevated PowerShell, run `tailscale serve --https=443 http://127.0.0.1:8787`, then
   run `tailscale serve status`. Copy the resulting `https://<machine>.<tailnet>.ts.net`
   address into VocalDive Settings on each beta device with that device's separate token.
   Do not run `tailscale funnel` and do not expose port 8787 to the public internet.
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
- `GET /v1/mode`, `PUT /v1/mode`
- `POST /v1/jobs` multipart field `files`, header `Authorization: Bearer <token>`, optional
  header `Idempotency-Key`
- `GET /v1/jobs/{job_id}`, `GET /v1/jobs/{job_id}/result`, `DELETE /v1/jobs/{job_id}`
- `GET /v1/dashboard/days`

The worker stores filenames, logs, diagnostics, and results locally. Never put the data root,
the generated `.env`, or `tokens.json` in Git.
