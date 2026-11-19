#!/usr/bin/env python3
"""Fake doxx.net Config and Stats API for tests/run.sh. Test-only, no network.

Serves fixture files from tests/fixtures/<scenario>/:

  POST /<scenario>/v1/            Config API. The endpoint is the form key whose
                                  value is "1". Answer: <endpoint>.<tunnel_token>.json
                                  if the request names a tunnel_token and that file
                                  exists, else <endpoint>.json. If <endpoint>.1.json
                                  exists, the Nth call in the scenario gets
                                  <endpoint>.N.json (the last file repeats).
                                  The answer goes out with HTTP 200, errors
                                  (status "error") included, as many real
                                  handlers send them; a top-level "_http" key
                                  sets another code (the real API sends most
                                  errors with a 4xx) and is removed from the
                                  body. A file <endpoint>.txt is sent instead
                                  as a plain-text 503, like a proxy in front of
                                  the API that has no backend.
  GET|POST /<scenario>/api/stats/<endpoint>
                                  Stats API, answer stats/<endpoint>.json. A file
                                  stats/<endpoint>.txt is sent as a plain-text 401.

The auth token must be "test-token" (form field `token` for Config, header
`X-Auth-Token` for Stats). Every request is appended to the log file as one JSON
line: {api, scenario, endpoint, query, form}, so tests can check what was sent.

Usage: fake_api.py FIXTURES_DIR PORT_FILE LOG_FILE
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

FIXTURES, PORT_FILE, LOG_FILE = sys.argv[1], sys.argv[2], sys.argv[3]
TOKEN = "test-token"
COUNTS = {}


def log(entry):
    with open(LOG_FILE, "a") as f:
        f.write(json.dumps(entry) + "\n")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send(self, code, body, ctype="application/json"):
        data = body.encode() if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def handle_any(self):
        url = urlsplit(self.path)
        parts = url.path.strip("/").split("/")
        query = {k: v[-1] for k, v in parse_qs(url.query).items()}
        length = int(self.headers.get("Content-Length") or 0)
        form = {k: v[-1] for k, v in parse_qs(self.rfile.read(length).decode()).items()} if length else {}
        if len(parts) < 2:
            return self.send(404, "not found", "text/plain")
        scenario, rest = parts[0], parts[1:]
        base = os.path.join(FIXTURES, scenario)

        if rest[:2] == ["api", "stats"] and len(rest) == 3:
            ep = rest[2]
            log({"api": "stats", "scenario": scenario, "endpoint": ep, "query": query, "form": form,
                 "auth_header": self.headers.get("X-Auth-Token") == TOKEN})
            if self.headers.get("X-Auth-Token") != TOKEN:
                return self.send(401, "Unauthorized\n", "text/plain")
            txt = os.path.join(base, "stats", ep + ".txt")
            if os.path.exists(txt):
                return self.send(401, open(txt).read(), "text/plain")
            path = os.path.join(base, "stats", ep + ".json")
            if not os.path.exists(path):
                return self.send(404, "404 page not found\n", "text/plain")
            return self.send(200, open(path).read())

        if rest == ["v1"]:
            eps = [k for k, v in form.items() if v == "1" and k != "token"]
            log({"api": "config", "scenario": scenario, "endpoint": eps[0] if eps else None,
                 "query": query, "form": {k: v for k, v in form.items() if k != "token"},
                 "token_ok": form.get("token") == TOKEN})
            if form.get("token") != TOKEN:
                return self.send(401, json.dumps({"status": "error", "message": "Invalid or missing token"}))
            for ep in eps:
                txt = os.path.join(base, ep + ".txt")
                if os.path.exists(txt):
                    return self.send(503, open(txt).read(), "text/plain")
                tt = form.get("tunnel_token")
                candidates = []
                if tt:
                    candidates.append(os.path.join(base, f"{ep}.{tt}.json"))
                if os.path.exists(os.path.join(base, f"{ep}.1.json")):
                    key = scenario + "/" + ep
                    n = COUNTS[key] = COUNTS.get(key, 0) + 1
                    while n > 1 and not os.path.exists(os.path.join(base, f"{ep}.{n}.json")):
                        n -= 1
                    candidates.append(os.path.join(base, f"{ep}.{n}.json"))
                candidates.append(os.path.join(base, ep + ".json"))
                for path in candidates:
                    if os.path.exists(path):
                        answer = json.load(open(path))
                        code = answer.pop("_http", 200)
                        return self.send(code, json.dumps(answer))
            return self.send(400, json.dumps({"status": "error", "message": "Unknown action"}))

        return self.send(404, "not found", "text/plain")

    do_GET = handle_any
    do_POST = handle_any


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(PORT_FILE + ".tmp", "w") as f:
    f.write(str(server.server_address[1]))
os.replace(PORT_FILE + ".tmp", PORT_FILE)
server.serve_forever()
