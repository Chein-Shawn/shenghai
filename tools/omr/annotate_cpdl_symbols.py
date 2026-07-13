#!/usr/bin/env python3
"""Resumable browser annotator for CPDL symbol-level OMR labels.

The source system manifest is read-only. Annotations are stored in a derived
JSONL manifest on the external SSD. Coordinates are normalized to the source
page for later system-crop conversion.
"""

from __future__ import annotations

import argparse
import html
import json
import mimetypes
import re
import threading
import urllib.parse
from collections import defaultdict
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DEFAULT_VERSION = Path("/Volumes/Crucial X6/vocaldive-ml/choral-omr/prepared/cpdl-v1")
DEFAULT_SYMBOL_KINDS = (
    "notehead", "rest", "barline", "clef", "key_signature", "time_signature", "accidental",
    "stem", "beam", "dot", "articulation", "slur", "tie", "fermata",
    "part_name", "lyric", "dynamic", "crescendo", "decrescendo", "direction", "tempo",
    "rehearsal_mark", "repeat_start", "repeat_end", "ending", "other",
)
DONE = {"annotated", "skipped"}


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_jsonl(path: Path) -> list[dict[str, object]]:
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def load_prediction_paths(path: Path | None) -> dict[str, str]:
    if path is None or not path.exists():
        return {}
    return {
        str(row.get("id")): str(row.get("prediction_preview_path"))
        for row in load_jsonl(path)
        if row.get("id") and row.get("prediction_preview_path")
    }


def write_jsonl(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".part")
    temporary.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows), encoding="utf-8")
    temporary.replace(path)


def normalized(value: object) -> float:
    try:
        return min(1.0, max(0.0, float(value)))
    except (TypeError, ValueError):
        return 0.0


def display_kind(kind: str) -> str:
    labels = {
        "part_name": "Part name",
        "dynamic": "Dynamics (p/f/mp/mf)",
        "crescendo": "Crescendo",
        "decrescendo": "Decrescendo",
        "repeat_start": "Repeat sign (start)",
        "repeat_end": "Repeat sign (end)",
        "key_signature": "Key signature",
        "time_signature": "Time signature",
        "rehearsal_mark": "Rehearsal mark",
    }
    return labels.get(kind, kind.replace("_", " ").capitalize())


def load_kinds(path: Path) -> list[dict[str, str]]:
    if path.exists():
        raw = json.loads(path.read_text(encoding="utf-8"))
        kinds = []
        for item in raw if isinstance(raw, list) else []:
            if isinstance(item, str):
                kinds.append({"key": item, "label": display_kind(item)})
            elif isinstance(item, dict) and item.get("key"):
                key = str(item["key"])
                kinds.append({"key": key, "label": str(item.get("label") or display_kind(key))})
        if kinds:
            return kinds
    kinds = [{"key": kind, "label": display_kind(kind)} for kind in DEFAULT_SYMBOL_KINDS]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(kinds, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return kinds


def save_kinds(path: Path, kinds: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".part")
    temporary.write_text(json.dumps(kinds, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def normalize_kind_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")[:60]


def make_queue(source: Path, output: Path, limit: int, prediction_paths: dict[str, str]) -> list[dict[str, object]]:
    existing = {str(row.get("id")): row for row in load_jsonl(output)}
    source_rows = []
    for source_row in load_jsonl(source):
        if source_row.get("alignment_status") != "verified":
            continue
        identifier = str(source_row.get("id", ""))
        if not identifier:
            continue
        source_rows.append(source_row)

    queue = []
    for source_row in source_rows:
        identifier = str(source_row["id"])
        if identifier in existing:
            row = dict(existing[identifier])
            if identifier in prediction_paths:
                row["prediction_preview_path"] = prediction_paths[identifier]
            queue.append(row)
    if not limit:
        candidates = source_rows
    else:
        capacity = max(0, limit - len(queue))
        selected_ids = {str(row.get("id")) for row in queue}
        existing_score_ids = {str(row.get("score_id")) for row in queue if row.get("score_id")}
        grouped: dict[str, list[dict[str, object]]] = defaultdict(list)
        for source_row in source_rows:
            identifier = str(source_row["id"])
            if identifier not in selected_ids:
                grouped[str(source_row.get("score_id") or identifier)].append(source_row)
        for rows in grouped.values():
            rows.sort(key=lambda row: (int(row.get("page_index") or 0), int(row.get("system_index") or 0), str(row.get("id"))))
        unseen_scores = sorted(score_id for score_id in grouped if score_id not in existing_score_ids)
        seen_scores = sorted(score_id for score_id in grouped if score_id in existing_score_ids)
        order = unseen_scores + seen_scores
        candidates = []
        while order and len(candidates) < capacity:
            next_order = []
            for score_id in order:
                rows = grouped[score_id]
                if rows and len(candidates) < capacity:
                    candidates.append(rows.pop(0))
                if rows:
                    next_order.append(score_id)
            order = next_order
    for source_row in candidates:
        identifier = str(source_row["id"])
        if identifier in existing:
            continue
        queue.append({
            "id": identifier, "dataset_id": "cpdl_v1", "score_id": source_row.get("score_id"),
            "title": source_row.get("title"), "page_index": source_row.get("page_index"),
            "system_index": source_row.get("system_index"), "image_path": source_row.get("image_path"),
            "system_bounds": source_row.get("bounds"), "system_bounds_normalized": source_row.get("bounds_normalized"),
            "measure_start": source_row.get("measure_start"), "measure_end": source_row.get("measure_end"),
            "source_review_note": source_row.get("review_note", ""), "symbols": [],
            "annotation_status": "pending", "annotation_note": "", "core_annotation_complete": False,
            "prediction_preview_path": prediction_paths.get(identifier),
            "created_at": now(),
        })
    return queue


def page_html(kinds: list[dict[str, str]]) -> str:
    options = "".join(f'<option value="{html.escape(item["key"], quote=True)}">{html.escape(item["label"])}</option>' for item in kinds)
    return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>VocalDive symbol annotation</title>
<style>*{{box-sizing:border-box}}body{{margin:0;background:#f3f5f7;color:#17202a;font:14px -apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif}}header{{background:#102a43;color:#fff;padding:16px 22px;display:flex;justify-content:space-between}}h1{{font-size:19px;margin:0}}main{{display:grid;grid-template-columns:minmax(420px,1fr) 320px;gap:16px;padding:16px;max-width:1500px;margin:auto}}.panel{{background:#fff;border:1px solid #d5dde5;border-radius:8px;padding:14px}}.viewer{{overflow:auto;max-height:82vh;background:#e7ecf0;padding:12px}}#stage{{position:relative;display:inline-block;line-height:0}}#page{{max-width:none;height:auto;display:block}}#overlay{{position:absolute;inset:0;width:100%;height:100%;cursor:crosshair}}.progress{{height:7px;background:#e2e8ee;border-radius:8px;overflow:hidden;margin:10px 0 16px}}.progress i{{display:block;height:100%;background:#1383d6}}label{{font-weight:650;display:block;margin-top:12px;margin-bottom:5px}}select,textarea{{width:100%;font:inherit;border:1px solid #b9c5cf;border-radius:6px;padding:8px}}textarea{{min-height:70px;resize:vertical}}button{{border:1px solid #b9c5cf;background:#fff;border-radius:6px;padding:9px 10px;font:inherit;cursor:pointer}}button.primary{{background:#087f5b;color:#fff;border-color:#087f5b}}button.warn{{background:#fff4e5;border-color:#f4c17c}}.actions,.nav{{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:14px}}.nav button:first-child{{grid-column:1/-1}}#symbols{{display:flex;flex-direction:column;gap:6px;margin-top:12px;max-height:230px;overflow:auto}}.symbol{{display:flex;justify-content:space-between;padding:6px 8px;background:#f3f6f8;border-radius:5px;font-size:12px}}.symbol button{{padding:2px 6px;font-size:12px}}#status{{min-height:24px;margin-top:10px;color:#607080}}@media(max-width:900px){{main{{grid-template-columns:1fr}}.viewer{{max-height:60vh}}}}</style></head><body>
<header><div><h1>VocalDive symbol annotation</h1><small>Reviewed systems only · source manifest is read-only</small></div><span id="saveState">Ready</span></header><main><section class="panel"><div class="viewer"><div id="stage"><img id="page" alt="Score page"><canvas id="overlay"></canvas></div></div></section><aside class="panel"><h2 id="title">Loading…</h2><div class="muted" id="details"></div><div class="progress"><i id="progress"></i></div><div class="muted">Drag a box around one symbol, choose its type, and save.</div><label for="kind">Symbol type</label><select id="kind">{options}</select><div class="type-tools"><input id="newKind" placeholder="New key, e.g. repeat_coda"><input id="newKindLabel" placeholder="Display name (optional)"><button onclick="addKind()">Add type</button><select id="removeKind"></select><button onclick="removeKind()">Remove selected type</button></div><div id="symbols"></div><label for="note">Annotation note</label><textarea id="note" placeholder="Optional: unclear stem, overlapping voices, etc."></textarea><div class="actions"><button class="primary" onclick="save('annotated')">Save annotations</button><button class="warn" onclick="save('skipped')">Skip system</button></div><div class="nav"><button onclick="previous()">Previous</button><button onclick="next()">Next</button></div><div id="status"></div></aside></main>
<script>let state={{rows:[],index:0}},drawing=false,start=null;const page=document.getElementById('page'),overlay=document.getElementById('overlay'),stage=document.getElementById('stage'),ctx=overlay.getContext('2d');async function init(){{state=await (await fetch('/api/state')).json();load(state.firstPending)}}function resize(){{overlay.width=page.naturalWidth;overlay.height=page.naturalHeight;stage.style.width=page.naturalWidth+'px';stage.style.height=page.naturalHeight+'px';render()}}function render(){{ctx.clearRect(0,0,overlay.width,overlay.height);const r=state.rows[state.index];if(!r)return;for(const b of r.symbols||[]){{ctx.strokeStyle='#087f5b';ctx.lineWidth=Math.max(4,overlay.width/1200);ctx.strokeRect(b.x*overlay.width,b.y*overlay.height,b.width*overlay.width,b.height*overlay.height)}}const root=document.getElementById('symbols');root.innerHTML='';(r.symbols||[]).forEach((b,i)=>{{const item=document.createElement('div');item.className='symbol';item.textContent=b.kind+' · '+Math.round(b.x*100)+'%, '+Math.round(b.y*100)+'%';const remove=document.createElement('button');remove.textContent='Remove';remove.onclick=()=>{{r.symbols.splice(i,1);render()}};item.append(remove);root.append(item)}})}}function load(index){{if(!state.rows.length)return;state.index=Math.max(0,Math.min(index,state.rows.length-1));const r=state.rows[state.index];document.getElementById('title').textContent=r.title||r.id;document.getElementById('details').textContent='System '+(state.index+1)+'/'+state.rows.length+' · page '+r.page_index+' · measures '+(r.measure_start||'?')+'–'+(r.measure_end||'?');document.getElementById('note').value=r.annotation_note||'';document.getElementById('progress').style.width=Math.round(state.annotated/state.total*100)+'%';page.onload=resize;page.src='/image/'+encodeURIComponent(r.id);render()}}function point(e){{const r=overlay.getBoundingClientRect();return{{x:(e.clientX-r.left)/r.width,y:(e.clientY-r.top)/r.height}}}}overlay.addEventListener('pointerdown',e=>{{drawing=true;start=point(e);overlay.setPointerCapture(e.pointerId)}});overlay.addEventListener('pointerup',e=>{{if(!drawing)return;drawing=false;const end=point(e),box={{x:Math.min(start.x,end.x),y:Math.min(start.y,end.y),width:Math.abs(start.x-end.x),height:Math.abs(start.y-end.y),kind:document.getElementById('kind').value}};if(box.width>.002&&box.height>.002){{state.rows[state.index].symbols.push(box);render()}}}});async function save(status){{const currentIndex=state.index;const r=state.rows[currentIndex];document.getElementById('saveState').textContent='Saving…';const response=await fetch('/api/annotation',{{method:'POST',headers:{{'Content-Type':'application/json'}},body:JSON.stringify({{id:r.id,status,symbols:r.symbols||[],annotation_note:document.getElementById('note').value}})}});if(!response.ok){{document.getElementById('status').textContent='Save failed';return}}state=await response.json();document.getElementById('saveState').textContent='Saved';load(Math.min(currentIndex+1,state.rows.length-1))}}function next(){{load(state.index+1)}}function previous(){{load(state.index-1)}}window.addEventListener('resize',resize);init()</script></body></html>'''

def page_html(kinds: list[dict[str, str]]) -> str:
    """Current annotation page with runtime-editable type configuration."""
    options = "".join(f'<option value="{html.escape(item["key"], quote=True)}">{html.escape(item["label"])}</option>' for item in kinds)
    return """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>VocalDive symbol annotation</title>
<style>*{box-sizing:border-box}body{margin:0;background:#f3f5f7;color:#17202a;font:14px -apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif}header{background:#102a43;color:#fff;padding:16px 22px;display:flex;justify-content:space-between}h1{font-size:19px;margin:0}main{display:grid;grid-template-columns:minmax(420px,1fr) 360px;gap:16px;padding:16px;max-width:1500px;margin:auto}.panel{background:#fff;border:1px solid #d5dde5;border-radius:8px;padding:14px}.viewer{overflow:auto;max-height:82vh;background:#e7ecf0;padding:12px}#stage{position:relative;display:inline-block;line-height:0}#page{max-width:none;height:auto;display:block}#overlay{position:absolute;inset:0;width:100%;height:100%;cursor:crosshair}.progress{height:7px;background:#e2e8ee;border-radius:8px;overflow:hidden;margin:10px 0 16px}.progress i{display:block;height:100%;background:#1383d6}label{font-weight:650;display:block;margin-top:12px;margin-bottom:5px}select,input,textarea{width:100%;font:inherit;border:1px solid #b9c5cf;border-radius:6px;padding:8px}input,select{margin-bottom:6px}textarea{min-height:70px;resize:vertical}button{border:1px solid #b9c5cf;background:#fff;border-radius:6px;padding:9px 10px;font:inherit;cursor:pointer}button.primary{background:#087f5b;color:#fff;border-color:#087f5b}button.warn{background:#fff4e5;border-color:#f4c17c}.type-tools{border:1px solid #d5dde5;border-radius:6px;padding:8px;margin-top:8px}.actions,.nav{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:14px}.nav button:first-child{grid-column:1/-1}#symbols{display:flex;flex-direction:column;gap:6px;margin-top:12px;max-height:230px;overflow:auto}.symbol{display:flex;justify-content:space-between;padding:6px 8px;background:#f3f6f8;border-radius:5px;font-size:12px}.symbol button{padding:2px 6px;font-size:12px}#status{min-height:24px;margin-top:10px;color:#607080}@media(max-width:900px){main{grid-template-columns:1fr}.viewer{max-height:60vh}}</style></head><body>
<header><div><h1>VocalDive symbol annotation</h1><small>Reviewed systems only · source manifest is read-only</small></div><span id="saveState">Ready</span></header><main><section class="panel"><div class="viewer"><div id="stage"><img id="page" alt="Score page"><canvas id="overlay"></canvas></div></div></section><aside class="panel"><h2 id="title">Loading...</h2><div class="muted" id="details"></div><div class="progress"><i id="progress"></i></div><div class="muted">Box every visible primary symbol: notehead, rest, barline, clef, key/time signature, accidental, stem, beam, and dot.</div><details id="predictionPanel" hidden><summary>Model suggestion (not ground truth)</summary><img id="prediction" alt="Model heatmap suggestion" style="width:100%;margin-top:8px;border:1px solid #b9c5cf"></details><label for="kind">Symbol type</label><select id="kind">__OPTIONS__</select><div class="type-tools"><label for="newKind">Add type</label><input id="newKind" placeholder="Key, e.g. repeat_coda"><input id="newKindLabel" placeholder="Display name (optional)"><button onclick="addKind()">Add type</button><label for="removeKind">Remove type</label><select id="removeKind"></select><button onclick="removeKind()">Remove selected type</button><div class="muted">Use stable English snake_case keys. Removing a type does not erase old annotations.</div></div><div id="symbols"></div><label><input id="coreComplete" type="checkbox"> I boxed every visible primary symbol in this system.</label><label for="note">Annotation note</label><textarea id="note" placeholder="Optional note"></textarea><div class="actions"><button class="primary" onclick="save('annotated')">Save annotations</button><button class="warn" onclick="save('skipped')">Skip system</button></div><div class="nav"><button onclick="previous()">Previous</button><button onclick="next()">Next</button></div><div id="status"></div></aside></main>
<script>let state={rows:[],kinds:[],index:0},drawing=false,start=null;const page=document.getElementById('page'),overlay=document.getElementById('overlay'),stage=document.getElementById('stage'),ctx=overlay.getContext('2d');async function init(){state=await(await fetch('/api/state')).json();refreshKinds();load(state.firstPending)}function refreshKinds(){const select=document.getElementById('kind'),remove=document.getElementById('removeKind');select.innerHTML='';remove.innerHTML='';for(const item of state.kinds||[]){const option=document.createElement('option');option.value=item.key;option.textContent=item.label;select.append(option);if(item.key!=='other'){const removable=option.cloneNode(true);remove.append(removable)}}}async function manageKind(action){const key=document.getElementById(action==='add'?'newKind':'removeKind').value.trim(),label=document.getElementById('newKindLabel').value.trim();if(!key)return;const response=await fetch('/api/kinds',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action,key,label})});if(!response.ok){document.getElementById('status').textContent=await response.text();return}state=await response.json();refreshKinds();if(action==='add'){document.getElementById('newKind').value='';document.getElementById('newKindLabel').value=''}}function addKind(){manageKind('add')}function removeKind(){manageKind('remove')}function resize(){overlay.width=page.naturalWidth;overlay.height=page.naturalHeight;stage.style.width=page.naturalWidth+'px';stage.style.height=page.naturalHeight+'px';render()}function render(){ctx.clearRect(0,0,overlay.width,overlay.height);const row=state.rows[state.index];if(!row)return;for(const box of row.symbols||[]){ctx.strokeStyle='#087f5b';ctx.lineWidth=Math.max(4,overlay.width/1200);ctx.strokeRect(box.x*overlay.width,box.y*overlay.height,box.width*overlay.width,box.height*overlay.height)}const root=document.getElementById('symbols');root.innerHTML='';(row.symbols||[]).forEach((box,index)=>{const item=document.createElement('div');item.className='symbol';item.textContent=box.kind+' · '+Math.round(box.x*100)+'%, '+Math.round(box.y*100)+'%';const remove=document.createElement('button');remove.textContent='Remove';remove.onclick=()=>{row.symbols.splice(index,1);render()};item.append(remove);root.append(item)})}function load(index){if(!state.rows.length)return;state.index=Math.max(0,Math.min(index,state.rows.length-1));const row=state.rows[state.index];document.getElementById('title').textContent=row.title||row.id;document.getElementById('details').textContent='System '+(state.index+1)+'/'+state.rows.length+' · page '+row.page_index+' · measures '+(row.measure_start||'?')+'–'+(row.measure_end||'?');document.getElementById('note').value=row.annotation_note||'';document.getElementById('coreComplete').checked=Boolean(row.core_annotation_complete);const predictionPanel=document.getElementById('predictionPanel'),prediction=document.getElementById('prediction');predictionPanel.hidden=!row.prediction_preview_path;if(row.prediction_preview_path)prediction.src='/prediction/'+encodeURIComponent(row.id);document.getElementById('progress').style.width=Math.round(state.annotated/state.total*100)+'%';page.onload=resize;page.src='/image/'+encodeURIComponent(row.id);render()}function point(event){const rect=overlay.getBoundingClientRect();return{x:(event.clientX-rect.left)/rect.width,y:(event.clientY-rect.top)/rect.height}}overlay.addEventListener('pointerdown',event=>{drawing=true;start=point(event);overlay.setPointerCapture(event.pointerId)});overlay.addEventListener('pointerup',event=>{if(!drawing)return;drawing=false;const end=point(event),box={x:Math.min(start.x,end.x),y:Math.min(start.y,end.y),width:Math.abs(end.x-start.x),height:Math.abs(end.y-start.y),kind:document.getElementById('kind').value};if(box.width>.002&&box.height>.002){state.rows[state.index].symbols.push(box);render()}});async function save(status){const currentIndex=state.index,row=state.rows[currentIndex],coreComplete=document.getElementById('coreComplete').checked;if(status==='annotated'&&!coreComplete){document.getElementById('status').textContent='Confirm that every visible primary symbol is boxed before saving.';return}document.getElementById('saveState').textContent='Saving...';const response=await fetch('/api/annotation',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id:row.id,status,symbols:row.symbols||[],annotation_note:document.getElementById('note').value,core_annotation_complete:coreComplete})});if(!response.ok){document.getElementById('status').textContent='Save failed';return}state=await response.json();refreshKinds();document.getElementById('saveState').textContent='Saved';load(Math.min(currentIndex+1,state.rows.length-1))}function next(){load(state.index+1)}function previous(){load(state.index-1)}window.addEventListener('resize',resize);init()</script></body></html>""".replace("__OPTIONS__", options)


class AnnotationServer:
    def __init__(self, source: Path, output: Path, kinds_config: Path, prediction_manifest: Path | None, limit: int):
        self.output = output
        self.kinds_config = kinds_config
        self.kinds = load_kinds(kinds_config)
        self.lock = threading.Lock()
        self.rows = make_queue(source, output, limit, load_prediction_paths(prediction_manifest))
        write_jsonl(output, self.rows)

    def state(self) -> dict[str, object]:
        done = sum(row.get("annotation_status") in DONE for row in self.rows); first = next((i for i, row in enumerate(self.rows) if row.get("annotation_status") not in DONE), 0)
        complete = sum(row.get("annotation_status") == "annotated" and row.get("core_annotation_complete") is True for row in self.rows)
        return {"rows": self.rows, "kinds": self.kinds, "total": len(self.rows), "annotated": done, "coreComplete": complete, "pending": len(self.rows) - done, "firstPending": first, "index": first}

    def manage_kinds(self, payload: dict[str, object]) -> dict[str, object]:
        action = str(payload.get("action", ""))
        key = normalize_kind_key(str(payload.get("key", "")))
        if action == "add":
            if not key:
                raise ValueError("Type key must contain letters or numbers.")
            if any(item["key"] == key for item in self.kinds):
                raise ValueError(f"Type already exists: {key}")
            label = str(payload.get("label") or display_kind(key)).strip()[:80]
            self.kinds.append({"key": key, "label": label or display_kind(key)})
        elif action == "remove":
            if key == "other":
                raise ValueError("The fallback type 'other' cannot be removed.")
            if not any(item["key"] == key for item in self.kinds):
                raise ValueError(f"Unknown type: {key}")
            self.kinds = [item for item in self.kinds if item["key"] != key]
        else:
            raise ValueError("Action must be add or remove.")
        save_kinds(self.kinds_config, self.kinds)
        return self.state()

    def annotate(self, payload: dict[str, object]) -> dict[str, object]:
        with self.lock:
            row = next((item for item in self.rows if item.get("id") == payload.get("id")), None)
            if row is None: raise KeyError(payload.get("id"))
            status = "skipped" if payload.get("status") == "skipped" else "annotated"
            core_complete = bool(payload.get("core_annotation_complete"))
            if status == "annotated" and not core_complete:
                raise ValueError("Confirm that every visible primary symbol has been boxed before saving annotations.")
            active_keys = {item["key"] for item in self.kinds}
            # Preserve boxes whose type was removed from the active menu.
            symbols = [item for item in row.get("symbols", []) if isinstance(item, dict) and item.get("kind") not in active_keys]
            for item in payload.get("symbols", []) or []:
                if not isinstance(item, dict) or item.get("kind") not in active_keys: continue
                symbols.append({"kind": item["kind"], "x": normalized(item.get("x")), "y": normalized(item.get("y")), "width": normalized(item.get("width")), "height": normalized(item.get("height"))})
            row["symbols"] = symbols; row["annotation_status"] = status; row["core_annotation_complete"] = core_complete if status == "annotated" else False; row["annotation_note"] = str(payload.get("annotation_note") or ""); row["annotated_at"] = now(); write_jsonl(self.output, self.rows); return self.state()


def make_handler(server: AnnotationServer):
    class Handler(BaseHTTPRequestHandler):
        def send_bytes(self, data: bytes, content_type: str, status: int = 200):
            self.send_response(status); self.send_header("Content-Type", content_type); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)
        def send_json(self, payload: object, status: int = 200): self.send_bytes(json.dumps(payload, ensure_ascii=False).encode(), "application/json; charset=utf-8", status)
        def do_GET(self):
            path = urllib.parse.urlparse(self.path).path
            if path == "/": self.send_bytes(page_html(server.kinds).encode(), "text/html; charset=utf-8"); return
            if path == "/api/state": self.send_json(server.state()); return
            if path.startswith("/image/"):
                identifier = urllib.parse.unquote(path.removeprefix("/image/")); row = next((item for item in server.rows if item.get("id") == identifier), None)
                if row:
                    image = Path(str(row["image_path"]))
                    if image.is_file(): self.send_bytes(image.read_bytes(), mimetypes.guess_type(image.name)[0] or "image/png"); return
            if path.startswith("/prediction/"):
                identifier = urllib.parse.unquote(path.removeprefix("/prediction/")); row = next((item for item in server.rows if item.get("id") == identifier), None)
                if row:
                    preview = Path(str(row.get("prediction_preview_path") or ""))
                    if preview.is_file(): self.send_bytes(preview.read_bytes(), "image/png"); return
            self.send_error(404)
        def do_POST(self):
            path = urllib.parse.urlparse(self.path).path
            length = int(self.headers.get("Content-Length", "0")); payload = json.loads(self.rfile.read(length))
            try:
                if path == "/api/kinds": self.send_json(server.manage_kinds(payload)); return
                if path != "/api/annotation": self.send_error(404); return
                self.send_json(server.annotate(payload))
            except Exception as error: self.send_json({"error": str(error)}, 400)
        def log_message(self, *_): pass
    return Handler


def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("--version", type=Path, default=DEFAULT_VERSION); parser.add_argument("--manifest", type=Path); parser.add_argument("--output", type=Path); parser.add_argument("--kinds-config", type=Path); parser.add_argument("--prediction-manifest", type=Path); parser.add_argument("--limit", type=int, default=150, help="Total systems to keep in the diverse queue; 0 means all verified systems"); parser.add_argument("--port", type=int, default=8766)
    args = parser.parse_args(); version = args.version.expanduser().resolve(); source = (args.manifest or version / "manifests/system-candidate-manifest.jsonl").expanduser().resolve(); output = (args.output or version / "symbols/symbol-annotation-manifest.jsonl").expanduser().resolve(); kinds_config = (args.kinds_config or version / "symbols/symbol-kinds.json").expanduser().resolve(); prediction_manifest = args.prediction_manifest.expanduser().resolve() if args.prediction_manifest else None; state = AnnotationServer(source, output, kinds_config, prediction_manifest, args.limit); http = ThreadingHTTPServer(("127.0.0.1", args.port), make_handler(state)); print(f"Symbol annotation server: http://127.0.0.1:{args.port}/", flush=True); print(f"Derived manifest: {output}", flush=True); print(f"Type configuration: {kinds_config}", flush=True); print(f"Prediction manifest: {prediction_manifest or 'not loaded'}", flush=True); http.serve_forever()


if __name__ == "__main__": raise SystemExit(main())
