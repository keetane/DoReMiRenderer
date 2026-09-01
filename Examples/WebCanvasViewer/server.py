#!/usr/bin/env python3
"""Serve the Web Canvas viewer and convert local MusicXML/MXL uploads with the SDK.

The browser never parses MusicXML or calculates score geometry.  It uploads an
imported score to this loopback-only companion, which delegates parsing and
layout to DoReMiRendererWebExport and returns a ScoreWebRenderBundle.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import tempfile
import time
import threading
import uuid
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse


WEB_ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = WEB_ROOT.parent.parent
EXPORTER = PROJECT_ROOT / ".build" / "debug" / "DoReMiRendererWebExport"
MAX_UPLOAD_BYTES = 50 * 1024 * 1024
SUPPORTED_SUFFIXES = {".mxl", ".musicxml", ".xml"}
SOURCE_CACHE_TTL_SECONDS = 10 * 60
SAMPLE_LIBRARY_ROOT = PROJECT_ROOT / "sample" / "app-bundle-hold"
ALLOWED_ORIGINS = {
    "https://keetane.github.io",
    "http://127.0.0.1:8767",
    "http://127.0.0.1:8765",
    "http://localhost:8767",
    "http://localhost:8765",
    "http://[::1]:8767",
    "http://[::1]:8765",
}
uploaded_sources: dict[str, tuple[bytes, str, float]] = {}
source_cache_lock = threading.Lock()


def ensure_exporter() -> Path:
    if EXPORTER.is_file():
        return EXPORTER
    subprocess.run(
        ["swift", "build", "--product", "DoReMiRendererWebExport"],
        cwd=PROJECT_ROOT,
        check=True,
        capture_output=True,
        text=True,
        timeout=120,
    )
    if not EXPORTER.is_file():
        raise RuntimeError("DoReMiRendererWebExport のビルドに失敗しました。")
    return EXPORTER


def render_score_bundle(payload: bytes, suffix: str) -> bytes:
    """Run the SDK exporter and retain source bytes for on-demand transpose."""
    with tempfile.TemporaryDirectory(prefix="doremipalette-web-") as temporary_directory:
        temporary_root = Path(temporary_directory)
        input_path = temporary_root / f"score{suffix}"
        output_path = temporary_root / "score-web.json"
        input_path.write_bytes(payload)
        result = subprocess.run(
            [
                str(ensure_exporter()),
                "--input", str(input_path),
                "--output", str(output_path),
                "--width", "1024",
                # Initial import stays responsive for large scores.
                # Chosen transpositions are rendered on demand below.
                "--primary-only",
            ],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=90,
        )
        if result.returncode != 0 or not output_path.is_file():
            detail = (result.stderr or result.stdout or "MusicXML/MXLを変換できませんでした。").strip()
            raise RuntimeError(detail[-1200:])
        document = json.loads(output_path.read_text(encoding="utf-8"))

    token = uuid.uuid4().hex
    with source_cache_lock:
        WebPaletteHandler._evict_expired_sources()
        uploaded_sources[token] = (payload, suffix, time.monotonic() + SOURCE_CACHE_TTL_SECONDS)
    document["sourceToken"] = token
    document["availableTransposeSemitones"] = list(range(-6, 6))
    return json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def bundled_sample_entries() -> list[dict[str, str]]:
    if not SAMPLE_LIBRARY_ROOT.is_dir():
        return []
    return [
        {"id": path.name, "name": path.stem.replace("_", " ")}
        for path in sorted(SAMPLE_LIBRARY_ROOT.glob("*.mxl"), key=lambda item: item.name.casefold())
    ]


class WebPaletteHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_ROOT), **kwargs)

    def do_POST(self) -> None:  # noqa: N802 - inherited HTTP handler API
        if urlparse(self.path).path != "/api/render":
            self.send_api_error(HTTPStatus.NOT_FOUND, "API endpoint was not found.")
            return

        content_length = self.headers.get("Content-Length")
        try:
            size = int(content_length) if content_length else -1
        except ValueError:
            size = -1
        if size < 0 or size > MAX_UPLOAD_BYTES:
            self.send_api_error(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, "50 MB以下のファイルを選択してください。")
            return

        supplied_name = os.path.basename(unquote(self.headers.get("X-DoReMi-File-Name", "score.musicxml")))
        suffix = Path(supplied_name).suffix.lower()
        if suffix not in SUPPORTED_SUFFIXES:
            self.send_api_error(HTTPStatus.UNSUPPORTED_MEDIA_TYPE, "MusicXML (.musicxml/.xml) または MXL (.mxl) のみ対応しています。")
            return

        payload = self.rfile.read(size)
        if len(payload) != size:
            self.send_api_error(HTTPStatus.BAD_REQUEST, "アップロードが途中で終了しました。")
            return

        try:
            rendered = render_score_bundle(payload, suffix)
        except subprocess.TimeoutExpired:
            self.send_api_error(HTTPStatus.GATEWAY_TIMEOUT, "MusicXML/MXLの変換がタイムアウトしました。")
            return
        except Exception as error:  # Keep the HTTP response useful without preserving uploaded content.
            self.send_api_error(HTTPStatus.UNPROCESSABLE_ENTITY, str(error))
            return

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(rendered)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(rendered)

    def do_OPTIONS(self) -> None:  # noqa: N802 - inherited HTTP handler API
        """Permit the published Pages viewer to call its local SDK companion."""
        origin = self.headers.get("Origin")
        if origin not in ALLOWED_ORIGINS:
            self.send_response(HTTPStatus.FORBIDDEN)
            self.end_headers()
            return
        self.send_response(HTTPStatus.NO_CONTENT)
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-DoReMi-File-Name")
        self.send_header("Access-Control-Max-Age", "600")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802 - inherited HTTP handler API
        parsed = urlparse(self.path)
        if parsed.path == "/api/health":
            self.send_json({"status": "ok"})
            return
        if parsed.path == "/api/samples":
            self.send_json(bundled_sample_entries())
            return
        if parsed.path == "/api/sample":
            self.render_bundled_sample(parse_qs(parsed.query).get("id", [""])[0])
            return
        if parsed.path != "/api/transpose":
            return super().do_GET()
        parameters = parse_qs(parsed.query)
        token = parameters.get("token", [""])[0]
        try:
            semitones = int(parameters.get("semitones", [""])[0])
        except ValueError:
            semitones = 99
        with source_cache_lock:
            self._evict_expired_sources()
            source = uploaded_sources.get(token)
        if source is None or not -6 <= semitones <= 5:
            self.send_api_error(HTTPStatus.NOT_FOUND, "移調用の一時スコアが見つかりません。もう一度ファイルを開いてください。")
            return
        payload, suffix, _ = source
        try:
            with tempfile.TemporaryDirectory(prefix="doremipalette-web-") as temporary_directory:
                temporary_root = Path(temporary_directory)
                input_path = temporary_root / f"score{suffix}"
                output_path = temporary_root / "score-web.json"
                input_path.write_bytes(payload)
                result = subprocess.run(
                    [
                        str(ensure_exporter()),
                        "--input", str(input_path),
                        "--output", str(output_path),
                        "--width", "1024",
                        "--transpose-semitones", str(semitones),
                    ],
                    cwd=PROJECT_ROOT,
                    capture_output=True,
                    text=True,
                    timeout=90,
                )
                if result.returncode != 0 or not output_path.is_file():
                    detail = (result.stderr or result.stdout or "移調レイアウトを生成できませんでした。").strip()
                    raise RuntimeError(detail[-1200:])
                rendered = output_path.read_bytes()
        except subprocess.TimeoutExpired:
            self.send_api_error(HTTPStatus.GATEWAY_TIMEOUT, "移調レイアウトの生成がタイムアウトしました。")
            return
        except Exception as error:
            self.send_api_error(HTTPStatus.UNPROCESSABLE_ENTITY, str(error))
            return

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(rendered)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(rendered)

    def render_bundled_sample(self, requested_name: str) -> None:
        name = Path(requested_name).name
        candidate = (SAMPLE_LIBRARY_ROOT / name).resolve()
        if (
            candidate.parent != SAMPLE_LIBRARY_ROOT.resolve()
            or candidate.suffix.lower() != ".mxl"
            or not candidate.is_file()
        ):
            self.send_api_error(HTTPStatus.NOT_FOUND, "指定したサンプルは見つかりません。")
            return
        try:
            rendered = render_score_bundle(candidate.read_bytes(), candidate.suffix.lower())
        except subprocess.TimeoutExpired:
            self.send_api_error(HTTPStatus.GATEWAY_TIMEOUT, "サンプルの変換がタイムアウトしました。")
            return
        except Exception as error:
            self.send_api_error(HTTPStatus.UNPROCESSABLE_ENTITY, str(error))
            return
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(rendered)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(rendered)

    @staticmethod
    def _evict_expired_sources() -> None:
        now = time.monotonic()
        for token, (_, _, expiry) in list(uploaded_sources.items()):
            if expiry <= now:
                uploaded_sources.pop(token, None)

    def send_api_error(self, status: HTTPStatus, detail: str) -> None:
        """Return localized API failures as UTF-8 JSON.

        BaseHTTPRequestHandler.send_error writes the supplied text to the
        Latin-1 HTTP status line.  It therefore cannot safely carry the
        Japanese validation messages exposed by this local API.
        """
        payload = json.dumps({"error": detail}, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def send_json(self, value: object) -> None:
        payload = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def end_headers(self) -> None:
        # The viewer is iterated locally. Never leave a stale module or upload
        # UI in the browser cache after the server-side exporter has changed.
        self.send_header("Cache-Control", "no-store, max-age=0")
        origin = self.headers.get("Origin")
        if origin in ALLOWED_ORIGINS:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
        super().end_headers()

    def log_message(self, format: str, *args) -> None:
        print(f"[WebCanvasViewer] {format % args}")


def main() -> None:
    parser = argparse.ArgumentParser(description="DoReMi Palette Web local server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), WebPaletteHandler)
    print(f"DoReMi Palette Web: http://{args.host}:{args.port}/")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
