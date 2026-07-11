#!/usr/bin/env python3
"""Discover and download CPDL choral score resources for private OMR research.

The crawler uses CPDL's public MediaWiki API, keeps a resumable JSONL queue,
and never places downloaded score files in git. It records source and edition
license text because CPDL says individual editions can have different terms.
"""

from __future__ import annotations

import argparse
import hashlib
import http.client
import json
import re
import ssl
import time
import urllib.parse
import urllib.error
import urllib.request
import zipfile
from collections import Counter, deque
from datetime import datetime, timezone
from pathlib import Path
from xml.etree import ElementTree as ET

API = "https://www.cpdl.org/wiki/api.php"
BASE = "https://www.cpdl.org/wiki/"
USER_AGENT = "VocalDive CPDL research crawler/0.1 (support@vocaldive.com)"
try:
    import certifi

    SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    SSL_CONTEXT = ssl.create_default_context()
START_CATEGORIES = [
    "Category:Solo_vocal_music",
    "Category:Choral_solo_music",
    *[f"Category:{number}-part_choral_music" for number in range(1, 9)],
]
VOICE_NAMES = {"S", "A", "T", "B"}


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", value).strip("_")[:180] or "file"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def fetch_json(params: dict[str, str], delay: float) -> dict:
    query = urllib.parse.urlencode({**params, "format": "json"})
    request = urllib.request.Request(f"{API}?{query}", headers={"User-Agent": USER_AGENT})
    last_error: Exception | None = None
    for attempt in range(5):
        time.sleep(delay if attempt == 0 else min(30.0, 2.0 ** attempt))
        try:
            with urllib.request.urlopen(request, timeout=90, context=SSL_CONTEXT) as response:
                return json.loads(response.read().decode("utf-8"))
        except (TimeoutError, OSError, urllib.error.URLError, urllib.error.HTTPError, http.client.RemoteDisconnected) as error:
            last_error = error
            if attempt == 4:
                break
    raise RuntimeError(f"CPDL API request failed after retries: {last_error}") from last_error


def category_members(category: str, namespace: str | None, delay: float) -> list[dict[str, object]]:
    members: list[dict[str, object]] = []
    continuation: dict[str, str] = {}
    while True:
        params = {
            "action": "query",
            "list": "categorymembers",
            "cmtitle": category,
            "cmlimit": "500",
            "cmtype": "page|subcat" if namespace is None else "page",
        }
        if namespace is not None:
            params["cmnamespace"] = namespace
        params.update(continuation)
        payload = fetch_json(params, delay)
        members.extend(payload.get("query", {}).get("categorymembers", []))
        continuation = payload.get("continue", {})
        if not continuation:
            return members


def wikitext_batch(titles: list[str], delay: float) -> dict[str, str]:
    payload = fetch_json(
        {
            "action": "query",
            "prop": "revisions",
            "rvprop": "content",
            "rvslots": "main",
            "titles": "|".join(titles),
            "formatversion": "2",
        },
        delay,
    )
    result: dict[str, str] = {}
    for page in payload.get("query", {}).get("pages", []):
        revisions = page.get("revisions", [])
        if not revisions:
            result[str(page.get("title", ""))] = ""
            continue
        slots = revisions[0].get("slots", {})
        result[str(page.get("title", ""))] = str(slots.get("main", {}).get("content", ""))
    return result


def parse_wikitext(title: str, text: str) -> dict[str, object]:
    voicing_match = re.search(r"\{\{\s*Voicing\s*\|([^}]*)\}\}", text, re.I | re.S)
    voicing_args = [part.strip() for part in voicing_match.group(1).split("|")] if voicing_match else []
    voicing = voicing_args[-1] if voicing_args else ""
    voice_matches = re.findall(r"(?<![A-Z])[SATB]+(?:\.[SATB]+)*(?![A-Z])", voicing.upper())
    normalized = "".join(voice_matches)
    counts = Counter(char for char in normalized if char in VOICE_NAMES)
    is_solo = bool(re.search(r"\bSolo\b", voicing, re.I)) or "Solo vocal music" in text
    if is_solo:
        kind = "solo_vocal"
    elif "choral solo" in text.lower():
        kind = "choral_with_solo"
    else:
        kind = "chorus"
    accepted = kind != "chorus" or (
        bool(counts)
        and sum(counts.values()) <= 8
        and all(counts[letter] <= 2 for letter in VOICE_NAMES)
    )
    media = []
    for match in re.finditer(r"\[\[(?:Media|File):([^|\]]+)(?:\|[^\]]*)?\]\]", text, re.I):
        media.append(match.group(1).strip())
    for match in re.finditer(r"https?://[^\s|\]]+\.(?:pdf|mxl|musicxml)(?:\?[^\s|\]]*)?", text, re.I):
        media.append(match.group(0))
    pdfs = [item for item in media if re.search(r"\.pdf(?:$|\?)", item, re.I)]
    xmls = [item for item in media if re.search(r"\.(?:mxl|musicxml)(?:$|\?)", item, re.I)]
    copy_match = re.search(r"\{\{\s*(?:Copy|Copyright|License)\s*\|([^}]*)\}\}", text, re.I | re.S)
    license_text = copy_match.group(1).strip() if copy_match else ""
    if re.search(r"public domain|\bPD\b|CC0", license_text, re.I):
        license_status = "public_domain"
    elif re.search(r"CPDL|GPL", license_text, re.I):
        license_status = "cpdl_license"
    elif re.search(r"Creative Commons|CC-", license_text, re.I):
        license_status = "creative_commons"
    elif any("cpdl.org" not in item.lower() for item in media):
        license_status = "third_party"
    else:
        license_status = "unknown"
    return {
        "score_page_url": BASE + "index.php?title=" + urllib.parse.quote(title.replace(" ", "_")),
        "title": title,
        "voicing": voicing,
        "voice_counts": dict(counts),
        "kind": kind,
        "accepted": bool(accepted),
        "pdf_files": sorted(set(pdfs)),
        "musicxml_files": sorted(set(xmls)),
        "license_text": license_text,
        "license_status": license_status,
        "research_only": True,
        "source_wikitext_sha256": hashlib.sha256(text.encode()).hexdigest(),
    }


def discover(args: argparse.Namespace, root: Path) -> int:
    categories = list(START_CATEGORIES)
    seen_categories: set[str] = set()
    seen_pages: set[str] = set()
    pages: list[dict[str, object]] = []
    while categories:
        category = categories.pop(0)
        if category in seen_categories:
            continue
        seen_categories.add(category)
        for member in category_members(category, None, args.delay):
            title = str(member["title"])
            if int(member.get("ns", 0)) == 14:
                categories.append(title)
            elif title not in seen_pages:
                seen_pages.add(title)
                pages.append({"title": title, "category": category})
        if args.max_pages and len(pages) >= args.max_pages:
            pages = pages[: args.max_pages]
            break

    output = root / "queues" / "cpdl-candidates.jsonl"
    output.parent.mkdir(parents=True, exist_ok=True)
    accepted = 0
    by_kind = Counter()
    by_voicing = Counter()
    with output.open("w", encoding="utf-8") as stream:
        for batch_start in range(0, len(pages), 50):
            batch = pages[batch_start : batch_start + 50]
            texts = wikitext_batch([str(item["title"]) for item in batch], args.delay)
            for item in batch:
                title = str(item["title"])
                record = parse_wikitext(title, texts.get(title, ""))
                record["category"] = item["category"]
                record["discovered_at"] = now()
                if record["accepted"]:
                    accepted += 1
                    by_kind[str(record["kind"])] += 1
                    by_voicing[str(record["voicing"])] += 1
                    stream.write(json.dumps(record, ensure_ascii=False) + "\n")
            index = min(batch_start + len(batch), len(pages))
            print(json.dumps({"pages_checked": index, "accepted": accepted}))
    report = {
        "created_at": now(),
        "categories": sorted(seen_categories),
        "pages_checked": len(pages),
        "accepted": accepted,
        "by_kind": by_kind,
        "by_voicing": by_voicing,
        "queue": str(output),
    }
    (root / "crawl-receipts" ).mkdir(parents=True, exist_ok=True)
    (root / "crawl-receipts" / "cpdl-discovery.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


def resolve_media_batch(names: list[str], delay: float) -> dict[str, str]:
    resolved: dict[str, str] = {name: name for name in names if name.startswith("http")}
    local_names = [name for name in names if not name.startswith("http")]
    for start in range(0, len(local_names), 50):
        batch = local_names[start : start + 50]
        payload = fetch_json(
            {
                "action": "query",
                "titles": "|".join("File:" + name for name in batch),
                "prop": "imageinfo",
                "iiprop": "url",
                "formatversion": "2",
            },
            delay,
        )
        for page in payload.get("query", {}).get("pages", []):
            info = page.get("imageinfo", [])
            if info:
                title = str(page.get("title", ""))
                resolved[title.removeprefix("File:")] = str(info[0].get("url", ""))
    return resolved


def download_url(url: str, destination: Path, delay: float) -> None:
    if destination.exists() and destination.stat().st_size:
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".part")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    time.sleep(delay)
    with urllib.request.urlopen(request, timeout=120, context=SSL_CONTEXT) as response, temporary.open("wb") as stream:
        while True:
            block = response.read(1024 * 1024)
            if not block:
                break
            stream.write(block)
    temporary.replace(destination)


def validate_xml(path: Path) -> bool:
    try:
        if path.suffix.lower() == ".mxl":
            with zipfile.ZipFile(path) as archive:
                container = ET.fromstring(archive.read("META-INF/container.xml"))
                rootfile = next(node for node in container.iter() if node.tag.rsplit("}", 1)[-1] == "rootfile")
                ET.fromstring(archive.read(rootfile.attrib["full-path"]))
        else:
            ET.parse(path)
        return True
    except (ET.ParseError, KeyError, zipfile.BadZipFile, StopIteration):
        return False


def download(args: argparse.Namespace, root: Path) -> int:
    queue = root / "queues" / "cpdl-candidates.jsonl"
    if not queue.exists():
        raise SystemExit("Run discover before download.")
    pdf_root, xml_root, license_root = root / "pdf", root / "musicxml", root / "licenses"
    manifest = root.parent.parent / "normalized" / "cpdl" / "manifests" / "cpdl-manifest.jsonl"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    latest: dict[str, dict[str, object]] = {}
    if manifest.exists():
        for line in manifest.read_text(encoding="utf-8").splitlines():
            try:
                previous = json.loads(line)
                title = str(previous.get("title", ""))
                if title:
                    latest[title] = previous
            except json.JSONDecodeError:
                continue
    count = 0
    pending_records: list[dict[str, object]] = []
    pending_seen = 0
    for line in queue.read_text(encoding="utf-8").splitlines():
        record = json.loads(line)
        title = str(record.get("title", ""))
        previous = latest.get(title)
        if previous and previous.get("pairing_status") in {"paired", "pdf_only", "musicxml_only"}:
            continue
        if args.paired_only and not (record.get("pdf_files") and record.get("musicxml_files")):
            continue
        if pending_seen < args.offset:
            pending_seen += 1
            continue
        pending_records.append(record)
        if args.limit and len(pending_records) >= args.limit:
            break
    media_names = sorted({
        str(name)
        for record in pending_records
        for name in (record.get("pdf_files", []) + record.get("musicxml_files", []))
    })
    media_urls = resolve_media_batch(media_names, args.delay)
    for record in pending_records:
            title = str(record.get("title", ""))
            previous = latest.get(title)
            if previous and previous.get("pairing_status") in {"paired", "pdf_only", "musicxml_only"}:
                continue
            page_slug = safe_name(str(record["title"]))
            record.update({"downloaded_at": now(), "pdf_path": None, "musicxml_path": None, "pairing_status": "missing"})
            license_path = license_root / f"{page_slug}.txt"
            license_path.parent.mkdir(parents=True, exist_ok=True)
            license_path.write_text(json.dumps({"page": record["score_page_url"], "license_text": record["license_text"], "status": record["license_status"]}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            if record["pdf_files"]:
                name = str(record["pdf_files"][0])
                url = media_urls.get(name)
                if url:
                    path = pdf_root / f"{page_slug}.pdf"
                    try:
                        download_url(url, path, args.delay)
                        if path.read_bytes()[:4] == b"%PDF":
                            record["pdf_path"], record["pdf_url"], record["pdf_sha256"] = str(path), url, sha256(path)
                    except Exception as error:
                        record["pdf_error"] = str(error)
            if record["musicxml_files"]:
                name = str(record["musicxml_files"][0])
                url = media_urls.get(name)
                if url:
                    suffix = ".mxl" if name.lower().endswith(".mxl") else ".musicxml"
                    path = xml_root / f"{page_slug}{suffix}"
                    try:
                        download_url(url, path, args.delay)
                        record["musicxml_parseable"] = validate_xml(path)
                        if record["musicxml_parseable"]:
                            record["musicxml_path"], record["musicxml_url"], record["musicxml_sha256"] = str(path), url, sha256(path)
                    except Exception as error:
                        record["musicxml_error"] = str(error)
            if record["pdf_path"] and record["musicxml_path"]:
                record["pairing_status"] = "paired"
            elif record["pdf_path"]:
                record["pairing_status"] = "pdf_only"
            elif record["musicxml_path"]:
                record["pairing_status"] = "musicxml_only"
            latest[title] = record
            write_manifest(latest, manifest)
            count += 1
            if count % 25 == 0:
                print(json.dumps({"downloaded_records": count}))
    print(json.dumps({"manifest": str(manifest), "records": count}, indent=2))
    return 0


def write_manifest(records: dict[str, dict[str, object]], destination: Path) -> None:
    """Rewrite the compact latest-state manifest after each completed record."""
    temporary = destination.with_suffix(destination.suffix + ".part")
    with temporary.open("w", encoding="utf-8") as stream:
        for title in sorted(records):
            stream.write(json.dumps(records[title], ensure_ascii=False) + "\n")
    temporary.replace(destination)


def organize(args: argparse.Namespace, root: Path) -> int:
    """Copy verified CPDL files into explicit research dataset tiers."""
    import shutil

    manifest = root.parent.parent / "normalized" / "cpdl" / "manifests" / "cpdl-manifest.jsonl"
    if not manifest.exists():
        raise SystemExit("Run download before organize.")
    normalized = root.parent.parent / "normalized" / "cpdl"
    records = [json.loads(line) for line in manifest.read_text(encoding="utf-8").splitlines() if line.strip()]
    counts = Counter()
    for record in records:
        status = str(record.get("pairing_status", "review-needed"))
        tier = status if status in {"paired", "pdf_only", "musicxml_only"} else "review-needed"
        destination = normalized / tier
        destination.mkdir(parents=True, exist_ok=True)
        for key in ("pdf_path", "musicxml_path"):
            source = record.get(key)
            if source and Path(str(source)).is_file():
                shutil.copy2(str(source), destination / Path(str(source)).name)
        counts[tier] += 1
    receipt = {"created_at": now(), "manifest": str(manifest), "records": len(records), "tiers": dict(counts)}
    (normalized / "manifests" / "cpdl-organize.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt, indent=2))
    return 0


def compact(args: argparse.Namespace, root: Path) -> int:
    manifest = root.parent.parent / "normalized" / "cpdl" / "manifests" / "cpdl-manifest.jsonl"
    if not manifest.exists():
        raise SystemExit("No manifest to compact.")
    latest: dict[str, dict[str, object]] = {}
    for line in manifest.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        record = json.loads(line)
        title = str(record.get("title", ""))
        if title:
            latest[title] = record
    write_manifest(latest, manifest)
    result = {"manifest": str(manifest), "records": len(latest)}
    print(json.dumps(result, indent=2))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["discover", "download", "organize", "compact"])
    parser.add_argument("--delay", type=float, default=1.0)
    parser.add_argument("--max-pages", type=int, default=0)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--paired-only", action="store_true", help="download only candidates with both PDF and MusicXML links")
    args = parser.parse_args()
    root = Path("/Volumes/Crucial X6/vocaldive-ml/choral-omr/raw/cpdl")
    root.mkdir(parents=True, exist_ok=True)
    if args.command == "discover":
        return discover(args, root)
    if args.command == "download":
        return download(args, root)
    if args.command == "organize":
        return organize(args, root)
    return compact(args, root)


if __name__ == "__main__":
    raise SystemExit(main())
