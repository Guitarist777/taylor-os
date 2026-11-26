#!/usr/bin/python3
# A made-up TAYLOR for the dial's checks (2026-11-21): the two doors the real TAYLOR adds for the desktop, on
# 127.0.0.1:8080, with a made-up token. Not TAYLOR; nothing of hers is in it.
#   GET  /desktop/state  -> the JSON in STATE_FILE (edit it to make her think or have things waiting)
#   POST /desktop/ask    -> {"nonce": ...}; the log gets the text it was sent
#   GET  /?ask=NONCE     -> logged (what her browser would open)
#   Her panel (2026-11-25): POST /devices/local-pair (the made-up token only) -> a made-up device key; GET /whoami;
#   POST /chat/stream -> a made-up reply streamed in pieces, tagged "Sonnet 5.5 · chat" (private: "GLM-5.3 (private chamber)");
#   GET /home/layout -> a made-up day; GET /history -> two made-up turns. The log gets which door, never a key.
# Usage: fake_taylor.py TOKEN STATE_FILE LOG_FILE
import json
import sys
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN, STATE, LOG = sys.argv[1], sys.argv[2], sys.argv[3]
DEVICE = "tdv_madeupDesktopKey0123456789abcdefgh"


def log(line):
    with open(LOG, "a") as f:
        f.write(line + "\n")


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def authed(self):
        return self.headers.get("Authorization", "") == "Bearer " + TOKEN

    def device(self):
        return self.headers.get("Authorization", "") == "Bearer " + DEVICE

    def reply(self, code, body):
        b = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/whoami":
            return self.reply(200 if self.device() else 401, {"kind": "linux"} if self.device() else {})
        if self.path.startswith("/home/layout"):
            if not self.device():
                return self.reply(401, {})
            log("HOME ok")
            return self.reply(200, {"cover": "1 thing is waiting.", "urgent": 0, "big": {"label": "Next", "head": "Made-up meeting", "detail": "Starts at 9:00 PM, in 24 min."},
                                    "rows": [{"label": "Weather", "value": "overcast, 44°F"}, {"label": "Builds", "value": "Nothing running"}],
                                    "strip": [{"kind": "needs", "text": "Where we left off: a made-up question", "action": "open"}]})
        if self.path.startswith("/history"):
            if not self.device():
                return self.reply(401, {})
            log("HISTORY ok")
            return self.reply(200, {"more": False, "turns": [{"user": "made-up hello", "reply": "Made-up hello back.", "model": "anthropic/claude-sonnet-5-5", "category": "chat"}]})
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
        n0 = int(self.headers.get("Content-Length", "0") or 0)
        if self.path == "/devices/local-pair":
            raw = self.rfile.read(n0)
            if not self.authed():
                log("PAIR refused")
                return self.reply(401, {})
            who = (json.loads(raw or b"{}") or {}).get("who", "app")
            log("PAIR ok who=%s" % who)
            return self.reply(200, {"id": "d1", "kind": "linux", "name": "TaylorOS desktop (this PC)", "token": DEVICE})
        if self.path == "/chat/stream":
            raw = self.rfile.read(n0)
            if not self.device():
                log("CHAT refused")
                return self.reply(401, {})
            body = json.loads(raw or b"{}")
            priv = bool(body.get("private"))
            log("CHAT ok private=%s text=%r" % (priv, body.get("message", "")))
            self.send_response(200)
            self.send_header("Content-Type", "application/x-ndjson")
            self.end_headers()
            import time as _t
            for ev in ({"type": "stage", "text": "thinking..."}, {"type": "token", "text": "A made-up "}, {"type": "token", "text": "reply, in pieces."},
                       {"type": "done", "model": "hosted_vllm/glm-5.3" if priv else "anthropic/claude-sonnet-5-5", "category": "private" if priv else "chat"}):
                self.wfile.write((json.dumps(ev) + "\n").encode()); self.wfile.flush(); _t.sleep(0.6)
            return
        if self.path != "/desktop/ask":
            return self.reply(404, {})
        if not self.authed():
            log("ASK refused (no token)")
            return self.reply(401, {"error": "token"})
        try:
            text = json.loads(self.rfile.read(n0)).get("text", "")
        except ValueError:
            text = ""
        nonce = uuid.uuid4().hex
        log("ASK text=%r nonce=%s" % (text, nonce))
        return self.reply(200, {"nonce": nonce, "expires_s": 60})


import os
ThreadingHTTPServer(("127.0.0.1", int(os.environ.get("FAKE_PORT", "8080"))), H).serve_forever()
