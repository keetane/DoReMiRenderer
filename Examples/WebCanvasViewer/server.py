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
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse


WEB_ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = WEB_ROOT.parent.parent
EXPORTER = PROJECT_ROOT / ".build" / "debug" / "DoReMiRendererWebExport"
MAX_UPLOAD_BYTES = 50 * 1024 * 1024
SUPPORTED_SUFFIXES = {".mxl", ".musicxml", ".xml"}


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


class WebPaletteHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_ROOT), **kwargs)

    def do_POST(self) -> None:  # noqa: N802 - inherited HTTP handler API
        if urlparse(self.path).path != "/api/render":
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        content_length = self.headers.get("Content-Length")
        try:
            size = int(content_length) if content_length else -1
        except ValueError:
            size = -1
        if size < 0 or size > MAX_UPLOAD_BYTES:
            self.send_error(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, "50 MB以下のファイルを選択してください。")
            return

        supplied_name = os.path.basename(unquote(self.headers.get("X-DoReMi-File-Name", "score.musicxml")))
        suffix = Path(supplied_name).suffix.lower()
        if suffix not in SUPPORTED_SUFFIXES:
            self.send_error(HTTPStatus.UNSUPPORTED_MEDIA_TYPE, "MusicXML (.musicxml/.xml) または MXL (.mxl) のみ対応しています。")
            return

        payload = self.rfile.read(size)
        if len(payload) != size:
            self.send_error(HTTPStatus.BAD_REQUEST, "アップロードが途中で終了しました。")
            return

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
                        "--transpose-range", "12",
                    ],
                    cwd=PROJECT_ROOT,
                    capture_output=True,
                    text=True,
                    timeout=90,
                )
                if result.returncode != 0 or not output_path.is_file():
                    detail = (result.stderr or result.stdout or "MusicXML/MXLを変換できませんでした。").strip()
                    raise RuntimeError(detail[-1200:])
                rendered = output_path.read_bytes()
        except subprocess.TimeoutExpired:
            self.send_error(HTTPStatus.GATEWAY_TIMEOUT, "MusicXML/MXLの変換がタイムアウトしました。")
            return
        except Exception as error:  # Keep the HTTP response useful without preserving uploaded content.
            self.send_error(HTTPStatus.UNPROCESSABLE_ENTITY, str(error))
            return

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(rendered)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(rendered)

    def end_headers(self) -> None:
        # The viewer is iterated locally. Never leave a stale module or upload
        # UI in the browser cache after the server-side exporter has changed.
        self.send_header("Cache-Control", "no-store, max-age=0")
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
