"""Private, single-worker oemer service for VocalDive's 714 beta host."""

from __future__ import annotations

import json
import os
import shutil
import sqlite3
import subprocess
import threading
import time
import uuid
import xml.etree.ElementTree as ET
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterator, Literal

import fitz
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

MAX_TOTAL_BYTES = 50 * 1024 * 1024
MAX_PAGES = 30
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".tif", ".tiff", ".webp"}
PDF_EXTENSION = ".pdf"
TERMINAL_STATES = {"ready", "failed", "cancelled"}
JobState = Literal["queued", "rasterizing", "recognizing", "assembling", "ready", "failed", "cancelled"]
WorkerMode = Literal["available", "quiet", "paused"]


def _path_env(name: str, fallback: str) -> Path:
    return Path(os.environ.get(name, fallback)).expanduser()


DATA_ROOT = _path_env("VOCALDIVE_OMR_DATA_ROOT", r"D:\VocalDiveOMR\data")
STATE_ROOT = _path_env("VOCALDIVE_OMR_STATE_ROOT", r"D:\VocalDiveOMR\state")
TOKENS_FILE = _path_env("VOCALDIVE_OMR_TOKENS_FILE", str(STATE_ROOT / "tokens.json"))
OEMER_EXECUTABLE = os.environ.get("VOCALDIVE_OMR_EXECUTABLE", "oemer")
GPU_BUSY_PERCENT = int(os.environ.get("VOCALDIVE_OMR_GPU_BUSY_PERCENT", "35"))
GPU_BUSY_VRAM_PERCENT = int(os.environ.get("VOCALDIVE_OMR_GPU_BUSY_VRAM_PERCENT", "30"))
DATABASE_PATH = STATE_ROOT / "jobs.sqlite3"


class CreateJobResponse(BaseModel):
    job_id: str
    state: JobState
    total_pages: int


class JobStatusResponse(BaseModel):
    job_id: str
    state: JobState
    source_name: str
    total_pages: int
    completed_pages: int
    detail: str | None = None
    error: str | None = None
    queue_position: int | None = None


class ModeRequest(BaseModel):
    mode: WorkerMode


class ModeResponse(BaseModel):
    mode: WorkerMode


@dataclass(frozen=True)
class AppPaths:
    day_root: Path
    job_root: Path
    input_root: Path
    pages_root: Path
    diagnostics_root: Path
    result_root: Path


class JobStore:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS jobs (
                    job_id TEXT PRIMARY KEY,
                    idempotency_key TEXT UNIQUE,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    state TEXT NOT NULL,
                    source_name TEXT NOT NULL,
                    job_root TEXT NOT NULL,
                    total_pages INTEGER NOT NULL,
                    completed_pages INTEGER NOT NULL DEFAULT 0,
                    detail TEXT,
                    error TEXT
                );
                CREATE TABLE IF NOT EXISTS worker_settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                """
            )
            connection.execute(
                "INSERT OR IGNORE INTO worker_settings(key, value) VALUES ('mode', 'available')"
            )

    @contextmanager
    def _connect(self) -> Iterator[sqlite3.Connection]:
        connection = sqlite3.connect(self.path)
        connection.row_factory = sqlite3.Row
        try:
            yield connection
            connection.commit()
        finally:
            connection.close()

    def existing_for(self, key: str) -> sqlite3.Row | None:
        with self._connect() as connection:
            return connection.execute("SELECT * FROM jobs WHERE idempotency_key = ?", (key,)).fetchone()

    def create(self, *, job_id: str, idempotency_key: str, source_name: str, job_root: Path, total_pages: int) -> None:
        now = utc_now()
        with self._connect() as connection:
            connection.execute(
                """INSERT INTO jobs(job_id, idempotency_key, created_at, updated_at, state, source_name, job_root, total_pages)
                   VALUES (?, ?, ?, ?, 'queued', ?, ?, ?)""",
                (job_id, idempotency_key, now, now, source_name, str(job_root), total_pages),
            )

    def get(self, job_id: str) -> sqlite3.Row | None:
        with self._connect() as connection:
            return connection.execute("SELECT * FROM jobs WHERE job_id = ?", (job_id,)).fetchone()

    def next_queued(self) -> sqlite3.Row | None:
        with self._connect() as connection:
            return connection.execute(
                "SELECT * FROM jobs WHERE state = 'queued' ORDER BY created_at LIMIT 1"
            ).fetchone()

    def queue_position(self, row: sqlite3.Row) -> int | None:
        if row["state"] != "queued":
            return None
        with self._connect() as connection:
            ahead = connection.execute(
                "SELECT COUNT(*) FROM jobs WHERE state = 'queued' AND created_at < ?", (row["created_at"],)
            ).fetchone()[0]
        return int(ahead) + 1

    def update(self, job_id: str, *, state: JobState | None = None, completed_pages: int | None = None,
               detail: str | None = None, error: str | None = None) -> None:
        fields = ["updated_at = ?"]
        values: list[object] = [utc_now()]
        for field, value in (("state", state), ("completed_pages", completed_pages), ("detail", detail), ("error", error)):
            if value is not None:
                fields.append(f"{field} = ?")
                values.append(value)
        values.append(job_id)
        with self._connect() as connection:
            connection.execute(f"UPDATE jobs SET {', '.join(fields)} WHERE job_id = ?", values)

    def cancel(self, job_id: str) -> bool:
        with self._connect() as connection:
            cursor = connection.execute(
                "UPDATE jobs SET state = 'cancelled', updated_at = ?, detail = 'Cancelled by user' "
                "WHERE job_id = ? AND state = 'queued'", (utc_now(), job_id)
            )
            return cursor.rowcount == 1

    def mode(self) -> WorkerMode:
        with self._connect() as connection:
            value = connection.execute("SELECT value FROM worker_settings WHERE key = 'mode'").fetchone()["value"]
        return value if value in {"available", "quiet", "paused"} else "available"

    def set_mode(self, mode: WorkerMode) -> None:
        with self._connect() as connection:
            connection.execute("UPDATE worker_settings SET value = ? WHERE key = 'mode'", (mode,))


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def job_paths(job_id: str) -> AppPaths:
    day_root = DATA_ROOT / datetime.now().strftime("%Y-%m-%d")
    job_root = day_root / job_id
    return AppPaths(day_root, job_root, job_root / "input", job_root / "pages", job_root / "diagnostics", job_root / "result")


def load_tokens() -> dict[str, str]:
    try:
        data = json.loads(TOKENS_FILE.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise RuntimeError(f"Token file is missing: {TOKENS_FILE}") from error
    if not isinstance(data, dict) or not all(isinstance(key, str) and isinstance(value, str) for key, value in data.items()):
        raise RuntimeError("tokens.json must be a JSON object mapping tokens to tester names")
    return data


def require_token(authorization: str | None = Header(default=None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing beta token")
    token = authorization.removeprefix("Bearer ").strip()
    if token not in load_tokens():
        raise HTTPException(status_code=401, detail="Invalid beta token")
    return token


def safe_name(name: str) -> str:
    cleaned = Path(name).name.strip()
    if not cleaned:
        raise HTTPException(status_code=400, detail="Every upload requires a filename")
    return cleaned


def inspect_uploads(files: list[UploadFile], paths: AppPaths) -> tuple[int, str]:
    if not files:
        raise HTTPException(status_code=400, detail="Choose one PDF or one to 30 images")
    paths.input_root.mkdir(parents=True, exist_ok=True)
    total_bytes = 0
    names: list[str] = []
    for index, upload in enumerate(files):
        name = safe_name(upload.filename or "")
        destination = paths.input_root / f"{index:02d}-{name}"
        with destination.open("wb") as handle:
            while chunk := upload.file.read(1024 * 1024):
                total_bytes += len(chunk)
                if total_bytes > MAX_TOTAL_BYTES:
                    raise HTTPException(status_code=413, detail="A beta scan is limited to 50 MB total")
                handle.write(chunk)
        names.append(name)

    extensions = [Path(name).suffix.lower() for name in names]
    if len(files) == 1 and extensions == [PDF_EXTENSION]:
        try:
            with fitz.open(next(paths.input_root.iterdir())) as document:
                page_count = document.page_count
        except Exception as error:
            raise HTTPException(status_code=400, detail="The uploaded PDF cannot be opened") from error
        if page_count > MAX_PAGES:
            raise HTTPException(status_code=413, detail="A beta PDF is limited to 30 pages")
        if page_count == 0:
            raise HTTPException(status_code=400, detail="The uploaded PDF has no pages")
        return page_count, names[0]
    if len(files) > MAX_PAGES or any(extension not in IMAGE_EXTENSIONS for extension in extensions):
        raise HTTPException(status_code=400, detail="Upload one PDF or one to 30 supported score images")
    return len(files), names[0] if len(names) == 1 else f"{len(names)} score images"


def gpu_is_quiet() -> bool:
    try:
        query = subprocess.run(
            ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"],
            check=True, capture_output=True, text=True, timeout=10,
        )
        usage, memory_used, memory_total = [int(value.strip()) for value in query.stdout.splitlines()[0].split(",")]
        return usage < GPU_BUSY_PERCENT and memory_used * 100 / max(memory_total, 1) < GPU_BUSY_VRAM_PERCENT
    except Exception:
        return True


def rasterize_job(paths: AppPaths) -> list[Path]:
    paths.pages_root.mkdir(parents=True, exist_ok=True)
    inputs = sorted(paths.input_root.iterdir())
    if len(inputs) == 1 and inputs[0].suffix.lower() == PDF_EXTENSION:
        rendered: list[Path] = []
        with fitz.open(inputs[0]) as document:
            for index, page in enumerate(document):
                pixmap = page.get_pixmap(matrix=fitz.Matrix(2, 2), alpha=False)
                destination = paths.pages_root / f"page-{index + 1:02d}.png"
                pixmap.save(destination)
                rendered.append(destination)
        return rendered
    rendered = []
    for index, source in enumerate(inputs):
        destination = paths.pages_root / f"page-{index + 1:02d}{source.suffix.lower()}"
        shutil.copy2(source, destination)
        rendered.append(destination)
    return rendered


def run_oemer(page: Path, diagnostics_root: Path, index: int) -> Path:
    output_dir = diagnostics_root / f"page-{index + 1:02d}"
    output_dir.mkdir(parents=True, exist_ok=True)
    completed = subprocess.run(
        [OEMER_EXECUTABLE, str(page), "--output-path", str(output_dir)],
        capture_output=True, text=True, timeout=20 * 60,
    )
    (output_dir / "oemer.stdout.log").write_text(completed.stdout, encoding="utf-8")
    (output_dir / "oemer.stderr.log").write_text(completed.stderr, encoding="utf-8")
    if completed.returncode != 0:
        raise RuntimeError(f"oemer exited with code {completed.returncode} on page {index + 1}")
    candidates = sorted(output_dir.rglob("*.musicxml"))
    if not candidates:
        raise RuntimeError(f"oemer did not produce MusicXML for page {index + 1}")
    return candidates[0]


def merge_musicxml(page_results: list[Path], output_path: Path) -> None:
    roots = [ET.parse(path).getroot() for path in page_results]
    if any(root.tag != "score-partwise" for root in roots):
        raise RuntimeError("oemer returned a MusicXML root that VocalDive cannot merge")
    primary = roots[0]
    primary_parts = primary.findall("part")
    for page_root in roots[1:]:
        page_parts = page_root.findall("part")
        if len(page_parts) != len(primary_parts):
            raise RuntimeError("Page MusicXML part layouts differ; manual review is required")
        for destination_part, source_part in zip(primary_parts, page_parts, strict=True):
            if destination_part.get("id") != source_part.get("id"):
                raise RuntimeError("Page MusicXML part identifiers differ; manual review is required")
            for measure in source_part.findall("measure"):
                destination_part.append(measure)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(primary).write(output_path, encoding="utf-8", xml_declaration=True)
    ET.parse(output_path)


def write_metadata(paths: AppPaths, row: sqlite3.Row) -> None:
    metadata = {
        "job_id": row["job_id"], "state": row["state"], "source_name": row["source_name"],
        "total_pages": row["total_pages"], "completed_pages": row["completed_pages"],
        "detail": row["detail"], "error": row["error"], "updated_at": row["updated_at"],
    }
    paths.job_root.mkdir(parents=True, exist_ok=True)
    (paths.job_root / "job.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")


class JobWorker:
    def __init__(self, store: JobStore) -> None:
        self.store = store
        self.thread = threading.Thread(target=self._run, name="vocaldive-omr-worker", daemon=True)
        self.stop_event = threading.Event()

    def start(self) -> None:
        self._recover_interrupted_jobs()
        self.thread.start()

    def _recover_interrupted_jobs(self) -> None:
        with self.store._connect() as connection:
            connection.execute(
                "UPDATE jobs SET state = 'queued', detail = 'Recovered after worker restart', updated_at = ? "
                "WHERE state IN ('rasterizing', 'recognizing', 'assembling')", (utc_now(),)
            )

    def _run(self) -> None:
        while not self.stop_event.wait(2):
            if self.store.mode() == "paused":
                continue
            if self.store.mode() == "quiet" and not gpu_is_quiet():
                continue
            row = self.store.next_queued()
            if row:
                self._process(row)

    def _process(self, row: sqlite3.Row) -> None:
        job_id = row["job_id"]
        paths = AppPaths(
            Path(row["job_root"]).parent,
            Path(row["job_root"]),
            Path(row["job_root"]) / "input",
            Path(row["job_root"]) / "pages",
            Path(row["job_root"]) / "diagnostics",
            Path(row["job_root"]) / "result",
        )
        try:
            self.store.update(job_id, state="rasterizing", detail="Rasterizing source pages")
            pages = rasterize_job(paths)
            self.store.update(job_id, state="recognizing", completed_pages=0, detail="Recognizing page 1")
            page_results: list[Path] = []
            for index, page in enumerate(pages):
                current = self.store.get(job_id)
                if current is None or current["state"] == "cancelled":
                    return
                page_results.append(run_oemer(page, paths.diagnostics_root, index))
                self.store.update(job_id, completed_pages=index + 1, detail=f"Recognized page {index + 1} of {len(pages)}")
            self.store.update(job_id, state="assembling", detail="Validating and combining MusicXML")
            merge_musicxml(page_results, paths.result_root / "candidate.musicxml")
            self.store.update(job_id, state="ready", detail="MusicXML candidate is ready")
        except Exception as error:
            self.store.update(job_id, state="failed", detail="OMR did not complete", error=str(error))
        finally:
            updated = self.store.get(job_id)
            if updated:
                write_metadata(paths, updated)


store = JobStore(DATABASE_PATH)
worker = JobWorker(store)
app = FastAPI(title="VocalDive 714 OMR", version="0.1.0")


@app.on_event("startup")
def startup() -> None:
    DATA_ROOT.mkdir(parents=True, exist_ok=True)
    STATE_ROOT.mkdir(parents=True, exist_ok=True)
    load_tokens()
    worker.start()


@app.get("/v1/health")
def health() -> dict[str, object]:
    return {"ready": True, "mode": store.mode(), "engine": "oemer", "limits": {"total_bytes": MAX_TOTAL_BYTES, "pages": MAX_PAGES}}


@app.get("/v1/mode", response_model=ModeResponse)
def get_mode(_: str = Depends(require_token)) -> ModeResponse:
    return ModeResponse(mode=store.mode())


@app.put("/v1/mode", response_model=ModeResponse)
def set_mode(request: ModeRequest, _: str = Depends(require_token)) -> ModeResponse:
    store.set_mode(request.mode)
    return ModeResponse(mode=request.mode)


@app.post("/v1/jobs", response_model=CreateJobResponse, status_code=202)
def create_job(
    files: list[UploadFile] = File(...),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    _: str = Depends(require_token),
) -> CreateJobResponse:
    key = idempotency_key or uuid.uuid4().hex
    if existing := store.existing_for(key):
        return CreateJobResponse(job_id=existing["job_id"], state=existing["state"], total_pages=existing["total_pages"])
    job_id = uuid.uuid4().hex
    paths = job_paths(job_id)
    try:
        total_pages, source_name = inspect_uploads(files, paths)
        store.create(job_id=job_id, idempotency_key=key, source_name=source_name, job_root=paths.job_root, total_pages=total_pages)
        row = store.get(job_id)
        if row:
            write_metadata(paths, row)
        return CreateJobResponse(job_id=job_id, state="queued", total_pages=total_pages)
    except Exception:
        shutil.rmtree(paths.job_root, ignore_errors=True)
        raise


@app.get("/v1/jobs/{job_id}", response_model=JobStatusResponse)
def get_job(job_id: str, _: str = Depends(require_token)) -> JobStatusResponse:
    row = store.get(job_id)
    if not row:
        raise HTTPException(status_code=404, detail="Unknown OMR job")
    return JobStatusResponse(
        job_id=row["job_id"], state=row["state"], source_name=row["source_name"],
        total_pages=row["total_pages"], completed_pages=row["completed_pages"], detail=row["detail"], error=row["error"],
        queue_position=store.queue_position(row),
    )


@app.get("/v1/jobs/{job_id}/result")
def get_result(job_id: str, _: str = Depends(require_token)) -> FileResponse:
    row = store.get(job_id)
    if not row:
        raise HTTPException(status_code=404, detail="Unknown OMR job")
    result = Path(row["job_root"]) / "result" / "candidate.musicxml"
    if row["state"] != "ready" or not result.exists():
        raise HTTPException(status_code=409, detail="MusicXML is not ready")
    return FileResponse(result, media_type="application/vnd.recordare.musicxml+xml", filename=f"{Path(row['source_name']).stem}.musicxml")


@app.delete("/v1/jobs/{job_id}", response_model=JobStatusResponse)
def cancel_job(job_id: str, _: str = Depends(require_token)) -> JobStatusResponse:
    row = store.get(job_id)
    if not row:
        raise HTTPException(status_code=404, detail="Unknown OMR job")
    if row["state"] not in TERMINAL_STATES and not store.cancel(job_id):
        raise HTTPException(status_code=409, detail="Only queued jobs can be cancelled")
    return get_job(job_id, _)


@app.get("/v1/dashboard/days")
def list_days(_: str = Depends(require_token)) -> list[dict[str, object]]:
    result = []
    for day in sorted((path for path in DATA_ROOT.iterdir() if path.is_dir()), reverse=True):
        size = sum(file.stat().st_size for file in day.rglob("*") if file.is_file())
        active = 0
        for job_file in day.glob("*/job.json"):
            metadata = json.loads(job_file.read_text(encoding="utf-8"))
            active += int(metadata.get("state") not in TERMINAL_STATES)
        result.append({"date": day.name, "bytes": size, "jobs": len(list(day.iterdir())), "active_jobs": active})
    return result
