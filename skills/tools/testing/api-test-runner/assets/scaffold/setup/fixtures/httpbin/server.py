#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import cast
from urllib.parse import parse_qs, urlparse


class Handler(BaseHTTPRequestHandler):
    server_version = "local-httpbin/1.0"

    def log_message(self, format: str, *args: object) -> None:
        sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), format % args))

    def _send_json(self, status: int, payload: object) -> None:
        data = json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _read_json(self) -> object | None:
        raw_len = self.headers.get("content-length", "")
        try:
            length = int(raw_len) if raw_len else 0
        except ValueError:
            return None
        payload = self.rfile.read(length) if length > 0 else b""
        if not payload:
            return None
        try:
            return json.loads(payload.decode("utf-8"))
        except Exception:
            return None

    def _as_dict(self, value: object | None) -> dict[str, object] | None:
        if isinstance(value, dict):
            return cast(dict[str, object], value)
        return None

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/health":
            self._send_json(200, {"ok": True})
            return

        if path == "/get":
            query = parse_qs(parsed.query)
            args = {key: values[0] if len(values) == 1 else values for key, values in query.items()}
            host = self.headers.get("host", "127.0.0.1")
            url = f"http://{host}{self.path}"
            self._send_json(200, {"args": args, "url": url})
            return

        self._send_json(404, {"error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/graphql":
            payload = self._as_dict(self._read_json())
            if payload is None:
                self._send_json(400, {"error": "invalid_json"})
                return

            query_value = payload.get("query")
            query = str(query_value) if query_value is not None else ""

            if "health" in query:
                self._send_json(200, {"data": {"health": {"ok": True}}})
                return

            self._send_json(200, {"errors": [{"message": "unknown_operation"}]})
            return

        self._send_json(404, {"error": "not_found"})


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    try:
        server.serve_forever(poll_interval=0.1)
        return 0
    except KeyboardInterrupt:
        return 0
    finally:
        server.server_close()


if __name__ == "__main__":
    raise SystemExit(main())
