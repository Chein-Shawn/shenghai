#!/usr/bin/env python3
"""Local click-through reviewer for CPDL page/system alignment candidates."""

from __future__ import annotations

import argparse
import json
import mimetypes
import threading
import urllib.parse
import zipfile
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

VERSION_DEFAULT = Path("/Volumes/Crucial X6/vocaldive-ml/choral-omr/prepared/cpdl-v1")


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_rows(path: Path) -> list[dict[str, object]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def write_rows(path: Path, rows: list[dict[str, object]]) -> None:
    temporary = path.with_suffix(path.suffix + ".part")
    temporary.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows), encoding="utf-8")
    temporary.replace(path)


def musicxml_bytes(path: Path) -> bytes:
    """Return plain MusicXML bytes for XML and compressed MXL sources."""
    if path.suffix.lower() != ".mxl":
        return path.read_bytes()
    with zipfile.ZipFile(path) as archive:
        import xml.etree.ElementTree as ET

        root = ET.fromstring(archive.read("META-INF/container.xml"))
        rootfile = next(node for node in root.iter() if node.tag.rsplit("}", 1)[-1] == "rootfile")
        return archive.read(rootfile.attrib["full-path"])


def html() -> str:
    return r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>VocalDive CPDL System Review</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f4f6f8;color:#17202a;font:15px -apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif}
header{background:#102a43;color:#fff;padding:18px 28px;display:flex;justify-content:space-between;align-items:center;gap:20px}h1{font-size:20px;margin:0}header small{opacity:.78}
.layout{display:grid;grid-template-columns:minmax(320px,1fr) minmax(420px,1.35fr) 320px;gap:18px;align-items:start}.panel{background:#fff;border:1px solid #d7dee5;border-radius:8px;padding:18px;box-shadow:0 2px 8px #102a4312}.panel h2{font-size:18px;margin:0 0 12px}.page{position:relative;background:#e9edf1;overflow:auto;max-height:72vh;text-align:center;padding:14px}.page img{display:block;max-width:100%;height:auto;margin:auto}.box{position:absolute;border:4px solid #e53935;pointer-events:none;box-shadow:0 0 0 2px #fff8}.score-preview{padding:0;overflow:hidden}.score-preview iframe{display:block;width:100%;height:72vh;min-height:560px;border:0;background:#fff}.preview-note{font-size:13px;color:#607080;margin:0 0 12px}.open-score{display:inline-block;margin-bottom:12px;border:1px solid #b8c4ce;border-radius:6px;padding:8px 10px;color:#17202a;text-decoration:none;background:#f8fafc}
.meta h2{font-size:21px;margin:0 0 8px}.muted{color:#607080}.field{display:flex;flex-direction:column;gap:6px;margin-top:14px}.field label{font-weight:650}.field input,.field textarea{font:inherit;border:1px solid #b8c4ce;border-radius:6px;padding:9px;width:100%}.field textarea{min-height:86px;resize:vertical}.actions{display:grid;grid-template-columns:1fr 1fr;gap:9px;margin-top:18px}.actions button{border:0;border-radius:7px;padding:11px;font:inherit;font-weight:650;cursor:pointer}.correct{background:#167c46;color:#fff}.incorrect{background:#b42318;color:#fff}.skip{background:#e8edf2;color:#17202a}.nav{display:flex;gap:8px;margin-top:12px}.nav button{flex:1;padding:9px;border:1px solid #b8c4ce;border-radius:6px;background:#fff;cursor:pointer}.status{margin-top:12px;min-height:22px;color:#607080}.progress{height:8px;background:#e4e9ee;border-radius:10px;overflow:hidden;margin:8px 0 16px}.progress i{display:block;height:100%;background:#1683d8;width:0}.warning{background:#fff4e5;border:1px solid #f4c17c;padding:10px;border-radius:6px;margin-top:14px;color:#6b3e00}
@media(max-width:1120px){.layout{grid-template-columns:minmax(300px,1fr) minmax(360px,1fr)}.meta{grid-column:1 / -1}.meta .field{display:inline-flex;width:31%;vertical-align:top;margin-right:1.5%}.meta .field textarea{min-height:42px}.meta .actions{grid-template-columns:repeat(4,1fr)}}
@media(max-width:850px){.layout{grid-template-columns:1fr}.meta{grid-column:auto}.meta .field{display:flex;width:auto;margin-right:0}.meta .actions{grid-template-columns:1fr 1fr}.page{max-height:55vh}.score-preview iframe{height:60vh;min-height:440px}header{padding:15px 18px}}
</style></head><body>
<header><div><h1>CPDL System Alignment Review</h1><small>VocalDive research dataset · cpdl-v1</small></div><small id="saveState">Ready</small></header>
<main><div class="bar"><span class="pill" id="count">Loading…</span><span class="pill" id="split"></span><span class="spacer"></span><button class="nav" style="margin:0" onclick="loadRecord(0)">Restart pending</button></div>
<div class="progress"><i id="progress"></i></div><div class="layout"><section class="panel"><h2>Original page</h2><div class="page" id="page"><div class="muted">Loading page…</div></div></section>
<section class="panel score-preview"><h2>Visual MusicXML preview</h2><p class="preview-note">Use the engraved score here to check the candidate measures. The XML file stays hidden behind the preview.</p><a class="open-score" id="openScore" href="#" target="_blank" rel="noopener">Open visual score</a><iframe id="scoreFrame" title="Visual MusicXML score preview"></iframe></section>
<aside class="panel meta"><h2 id="title">Loading…</h2><div class="muted" id="details"></div><div class="warning">The red box is a heuristic system proposal. Confirm that it contains the intended printed system, then compare its first and last measure with the visual score.</div>
<div class="field"><label for="start">MusicXML measure start</label><input id="start" type="number" min="1" placeholder="e.g. 1"></div>
<div class="field"><label for="end">MusicXML measure end</label><input id="end" type="number" min="1" placeholder="e.g. 4"></div>
<div class="field"><label for="note">Review note</label><textarea id="note" placeholder="Optional: wrong edition, crop too wide, unclear barline…"></textarea></div>
<div class="actions"><button class="correct" onclick="save('verified')">Correct</button><button class="incorrect" onclick="save('rejected')">Incorrect</button><button class="skip" onclick="save('skipped')">Skip</button></div>
<div class="nav"><button onclick="previous()">Previous</button><button onclick="next()">Next</button></div><div class="status" id="status"></div></aside></div></main>
<script>
let state={rows:[],index:0};
async function init(){state=await (await fetch('/api/state')).json();document.getElementById('count').textContent=`${state.reviewed} reviewed · ${state.pending} pending · ${state.total} total`;loadRecord(state.firstPending)}
function loadRecord(index){if(!state.rows.length)return;state.index=Math.max(0,Math.min(index,state.rows.length-1));const r=state.rows[state.index];
document.getElementById('title').textContent=r.title;document.getElementById('split').textContent=`${r.split} · page ${r.page_index} · system ${r.system_index}`;document.getElementById('details').textContent=`Candidate ${state.index+1}/${state.rows.length} · ${r.alignment_status}`;
document.getElementById('start').value=r.measure_start||'';document.getElementById('end').value=r.measure_end||'';document.getElementById('note').value=r.review_note||'';document.getElementById('status').textContent='';
const scoreURL='/score/'+encodeURIComponent(r.id),frame=document.getElementById('scoreFrame');frame.src=scoreURL;document.getElementById('openScore').href=scoreURL;
const page=document.getElementById('page');page.innerHTML=`<img src="/image/${encodeURIComponent(r.id)}" onload="placeBox(this)"><div class="box" id="box"></div>`;document.getElementById('progress').style.width=`${Math.round((state.reviewed/state.total)*100)}%`}
function placeBox(img){const r=state.rows[state.index],b=r.bounds_normalized,box=document.getElementById('box');box.style.left=(img.offsetLeft+b[0]*img.offsetWidth)+'px';box.style.top=(img.offsetTop+b[1]*img.offsetHeight)+'px';box.style.width=(b[2]*img.offsetWidth)+'px';box.style.height=(b[3]*img.offsetHeight)+'px'}
async function save(status){const r=state.rows[state.index],payload={id:r.id,status,measure_start:document.getElementById('start').value||null,measure_end:document.getElementById('end').value||null,review_note:document.getElementById('note').value};if(status==='verified'&&(!payload.measure_start||!payload.measure_end)){document.getElementById('status').textContent='Enter both measure numbers before marking Correct.';return}document.getElementById('saveState').textContent='Saving…';const response=await fetch('/api/review',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});if(!response.ok){document.getElementById('status').textContent='Save failed.';return}state=await response.json();document.getElementById('saveState').textContent='Saved';loadRecord(state.firstPending)}
function next(){loadRecord(state.index+1)}function previous(){loadRecord(state.index-1)}
document.addEventListener('keydown',e=>{if(e.key==='ArrowRight')next();if(e.key==='ArrowLeft')previous();if(e.key==='Enter'&&!e.shiftKey)save('verified')});init();
</script></body></html>'''


def score_html(identifier: str) -> str:
    """Render one MusicXML/MXL record with the bundled local OSMD renderer."""
    safe_identifier = json.dumps(identifier, ensure_ascii=False)
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>VocalDive visual score preview</title>
<style>html,body{{margin:0;background:#fff;color:#17202a;font:14px -apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif}}body{{padding:12px}}#status{{color:#607080;margin-bottom:8px}}#score{{min-height:300px;overflow:auto}}svg{{max-width:100%;height:auto}}</style>
<script src="/assets/opensheetmusicdisplay.min.js"></script></head><body>
<div id="status">Loading visual score…</div><div id="score"></div>
<script>
const recordID={safe_identifier};
async function render(){{
  const status=document.getElementById('status'),root=document.getElementById('score');
  try{{
    const response=await fetch('/musicxml/'+encodeURIComponent(recordID));
    if(!response.ok) throw new Error('MusicXML could not be loaded');
    const musicXML=await response.text();
    const osmd=new opensheetmusicdisplay.OpenSheetMusicDisplay(root,{{autoResize:true,drawTitle:true,drawComposer:true,drawLyrics:true,backend:'svg'}});
    await osmd.load(musicXML); osmd.render(); status.textContent='Visual score ready';
  }}catch(error){{ console.error(error); status.textContent='Visual score could not be rendered'; root.innerHTML='<p style="color:#b42318">The MusicXML source could not be rendered. Keep this candidate marked for review.</p>'; }}
}}
render();
</script></body></html>'''


class ReviewServer:
    def __init__(self, manifest: Path, limit_scores: int):
        self.manifest = manifest
        self.lock = threading.Lock()
        self.rows = load_rows(manifest)
        allowed = []
        seen = set()
        for row in self.rows:
            if row["score_id"] not in seen:
                seen.add(row["score_id"])
                if limit_scores and len(seen) > limit_scores:
                    break
            if row["score_id"] in seen:
                allowed.append(row)
        self.rows = allowed

    def state(self) -> dict[str, object]:
        reviewed = sum(row.get("alignment_status") in {"verified", "rejected", "skipped"} for row in self.rows)
        pending = len(self.rows) - reviewed
        first = next((i for i, row in enumerate(self.rows) if row.get("alignment_status") not in {"verified", "rejected", "skipped"}), 0)
        return {"rows": self.rows, "total": len(self.rows), "reviewed": reviewed, "pending": pending, "firstPending": first}

    def review(self, payload: dict[str, object]) -> dict[str, object]:
        with self.lock:
            row = next((row for row in self.rows if row.get("id") == payload.get("id")), None)
            if row is None:
                raise KeyError(payload.get("id"))
            row["alignment_status"] = payload.get("status", "skipped")
            row["reviewed_at"] = now()
            row["review_note"] = str(payload.get("review_note") or "")
            if payload.get("measure_start") is not None:
                row["measure_start"] = int(payload["measure_start"])
            if payload.get("measure_end") is not None:
                row["measure_end"] = int(payload["measure_end"])
            write_rows(self.manifest, load_rows(self.manifest))
            # Replace the corresponding row in the full manifest, preserving rows outside the review subset.
            full = load_rows(self.manifest)
            for item in full:
                if item.get("id") == row.get("id"):
                    item.update(row)
            write_rows(self.manifest, full)
            return self.state()


def make_handler(server: ReviewServer):
    class Handler(BaseHTTPRequestHandler):
        def send_json(self, payload: object, status: int = 200):
            data = json.dumps(payload, ensure_ascii=False).encode()
            self.send_response(status); self.send_header("Content-Type", "application/json; charset=utf-8"); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)

        def do_GET(self):
            path = urllib.parse.urlparse(self.path).path
            if path == "/":
                data = html().encode(); self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8"); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data); return
            if path == "/api/state": self.send_json(server.state()); return
            if path == "/assets/opensheetmusicdisplay.min.js":
                asset = Path(__file__).resolve().parents[2] / "ios-app/VocalDiveCore/Sources/VocalDiveApp/Resources/OSMD/opensheetmusicdisplay.min.js"
                if asset.is_file():
                    data = asset.read_bytes(); self.send_response(200); self.send_header("Content-Type", "application/javascript; charset=utf-8"); self.send_header("Cache-Control", "public, max-age=3600"); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data); return
                self.send_error(404, "Bundled OSMD renderer is missing"); return
            if path.startswith("/image/"):
                ident = urllib.parse.unquote(path.removeprefix("/image/")); row = next((r for r in server.rows if r.get("id") == ident), None)
                if row:
                    image = Path(str(row["image_path"])); data = image.read_bytes(); self.send_response(200); self.send_header("Content-Type", mimetypes.guess_type(image.name)[0] or "image/png"); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data); return
            if path.startswith("/score/"):
                ident = urllib.parse.unquote(path.removeprefix("/score/")); row = next((r for r in server.rows if r.get("id") == ident), None)
                if row:
                    data = score_html(str(row["id"])).encode("utf-8"); self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8"); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data); return
            if path.startswith("/musicxml/"):
                ident = urllib.parse.unquote(path.removeprefix("/musicxml/")); row = next((r for r in server.rows if r.get("id") == ident), None)
                if row:
                    source = Path(str(row["musicxml_path"])); data = musicxml_bytes(source); self.send_response(200); self.send_header("Content-Type", "application/xml; charset=utf-8"); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data); return
            self.send_error(404)

        def do_POST(self):
            if urllib.parse.urlparse(self.path).path != "/api/review": self.send_error(404); return
            length = int(self.headers.get("Content-Length", "0")); payload = json.loads(self.rfile.read(length))
            try: self.send_json(server.review(payload))
            except Exception as error: self.send_json({"error": str(error)}, 400)

        def log_message(self, *_): pass
    return Handler


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", type=Path, default=VERSION_DEFAULT)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--limit-scores", type=int, default=50)
    args = parser.parse_args()
    manifest = args.version.expanduser().resolve() / "manifests/system-candidate-manifest.jsonl"
    server_state = ReviewServer(manifest, args.limit_scores)
    http = ThreadingHTTPServer(("127.0.0.1", args.port), make_handler(server_state))
    print(f"Review server: http://127.0.0.1:{args.port}/", flush=True)
    print(f"Reviewing up to {args.limit_scores} scores from {manifest}", flush=True)
    http.serve_forever()


if __name__ == "__main__":
    raise SystemExit(main())
