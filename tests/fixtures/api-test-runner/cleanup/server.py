#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Lock
from typing import cast
from urllib.parse import urlparse


class _State:
    def __init__(self) -> None:
        self._lock = Lock()
        self._rest_items: list[str] = []
        self._graphql_things: list[str] = []
        self._rest_counter = 0
        self._graphql_counter = 0

    def snapshot(self) -> dict[str, list[str]]:
        with self._lock:
            return {
                "restItems": list(self._rest_items),
                "graphqlThings": list(self._graphql_things),
            }

    def create_rest_item(self) -> str:
        with self._lock:
            self._rest_counter += 1
            item_id = f"item-{self._rest_counter}"
            self._rest_items.append(item_id)
            return item_id

    def delete_rest_item(self, item_id: str) -> bool:
        with self._lock:
            if item_id not in self._rest_items:
                return False
            self._rest_items.remove(item_id)
            return True

    def list_rest_items(self) -> list[str]:
        with self._lock:
            return list(self._rest_items)

    def create_graphql_thing(self) -> str:
        with self._lock:
            self._graphql_counter += 1
            thing_id = f"thing-{self._graphql_counter}"
            self._graphql_things.append(thing_id)
            return thing_id

    def delete_graphql_thing(self, thing_id: str) -> bool:
        with self._lock:
            if thing_id not in self._graphql_things:
                return False
            self._graphql_things.remove(thing_id)
            return True


STATE = _State()


def _read_json(handler: BaseHTTPRequestHandler) -> object | None:
    raw_len = handler.headers.get("content-length", "")
    try:
        length = int(raw_len) if raw_len else 0
    except ValueError:
        return None
    payload = handler.rfile.read(length) if length > 0 else b""
    if not payload:
        return None
    try:
        return json.loads(payload.decode("utf-8"))
    except Exception:
        return None


def _as_dict(value: object | None) -> dict[str, object] | None:
    if isinstance(value, dict):
        return cast(dict[str, object], value)
    return None


class Handler(BaseHTTPRequestHandler):
    server_version = "api-test-runner-fixture/1.0"

    def log_message(self, format: str, *args: object) -> None:
        sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), format % args))

    def _send_json(self, status: int, payload: object) -> None:
        data = json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_empty(self, status: int) -> None:
        self.send_response(status)
        self.send_header("content-length", "0")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path

        if path == "/health":
            self._send_json(200, {"ok": True})
            return

        if path == "/items":
            self._send_json(200, {"items": STATE.list_rest_items()})
            return

        if path == "/state":
            self._send_json(200, STATE.snapshot())
            return

        self._send_json(404, {"error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path

        if path == "/items":
            payload = _read_json(self)
            if payload is None:
                self._send_json(400, {"error": "invalid_json"})
                return
            item_id = STATE.create_rest_item()
            self._send_json(201, {"id": item_id})
            return

        if path == "/graphql":
            payload = _as_dict(_read_json(self))
            if payload is None:
                self._send_json(400, {"error": "invalid_json"})
                return

            query_value = payload.get("query")
            query = str(query_value) if query_value is not None else ""
            variables_value = payload.get("variables")
            if not variables_value:
                variables: dict[str, object] = {}
            else:
                variables_opt = _as_dict(variables_value)
                if variables_opt is None:
                    self._send_json(400, {"error": "invalid_variables"})
                    return
                variables = variables_opt

            if "createThing" in query:
                created_id = STATE.create_graphql_thing()
                self._send_json(200, {"data": {"createThing": {"id": created_id}}})
                return

            if "deleteThing" in query:
                input_value = variables.get("input")
                if not input_value:
                    input_obj: dict[str, object] = {}
                else:
                    input_opt = _as_dict(input_value)
                    if input_opt is None:
                        self._send_json(400, {"error": "invalid_input"})
                        return
                    input_obj = input_opt
                thing_id_value = input_obj.get("id")
                if not isinstance(thing_id_value, str) or not thing_id_value:
                    self._send_json(400, {"error": "missing_id"})
                    return
                success = STATE.delete_graphql_thing(thing_id_value)
                self._send_json(200, {"data": {"deleteThing": {"success": success}}})
                return

            self._send_json(400, {"error": "unknown_operation"})
            return

        self._send_json(404, {"error": "not_found"})

    def do_DELETE(self) -> None:  # noqa: N802
        path = urlparse(self.path).path

        if path.startswith("/items/"):
            item_id = path.removeprefix("/items/").strip("/")
            if not item_id:
                self._send_json(400, {"error": "missing_id"})
                return
            ok = STATE.delete_rest_item(item_id)
            if not ok:
                self._send_json(404, {"error": "not_found"})
                return
            self._send_empty(204)
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
