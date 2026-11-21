#!/usr/bin/python3
# A made-up TAYLOR for the dial's checks (2026-11-21): the two doors the real TAYLOR adds for the desktop, on
# 127.0.0.1:8080, with a made-up token. Not TAYLOR; nothing of hers is in it.
#   GET  /desktop/state  -> the JSON in STATE_FILE (edit it to make her think or have things waiting)
#   POST /desktop/ask    -> {"nonce": ...}; the log gets the text it was sent
#   GET  /?ask=NONCE     -> logged (what her browser would open)
# Usage: fake_taylor.py TOKEN STATE_FILE LOG_FILE
import json
import sys
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN, STATE, LOG = sys.argv[1], sys.argv[2], sys.argv[3]


def log(line):
    with open(LOG, "a") as f:
        f.write(line + "\n")


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def authed(self):
        return self.headers.get("Authorization", "") == "Bearer " + TOKEN

    def reply(self, code, body):
        b = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/desktop/state":
            if not self.authed():
                log("STATE refused (no token)")
                return self.reply(401, {"error": "token"})
            try:
                with open(STATE) as f:
                    st = json.load(f)
            except (OSError, ValueError):
                st = {"up": True, "thinking": False, "waiting": 0, "since": 0}
            log("STATE ok thinking=%s waiting=%s" % (st.get("thinking"), st.get("waiting")))
            return self.reply(200, st)
        if self.path.startswith("/?ask="):
            log("PAGE " + self.path)
        else:
            log("PAGE " + self.path.split("?")[0])
        b = b"<html><body>made-up TAYLOR page</body></html>"
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_POST(self):
        if self.path != "/desktop/ask":
            return self.reply(404, {})
        if not self.authed():
            log("ASK refused (no token)")
            return self.reply(401, {"error": "token"})
        n = int(self.headers.get("Content-Length", "0") or 0)
        try:
            text = json.loads(self.rfile.read(n)).get("text", "")
        except ValueError:
            text = ""
        nonce = uuid.uuid4().hex
        log("ASK text=%r nonce=%s" % (text, nonce))
        return self.reply(200, {"nonce": nonce, "expires_s": 60})


ThreadingHTTPServer(("127.0.0.1", 8080), H).serve_forever()
