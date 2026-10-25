#!/usr/bin/env python3
"""A stand-in for the Cockpit's chat routes, for the simulator (chat spec 2026-10-25; Cockpit story 129).

  scripts/native/fake-cockpit.py PORT REPORT

GET /chat, GET /chat/<key>, POST /chat (a new thread), POST /chat/<key>, POST /chat-seen, POST /attachments,
GET /attachments/<ref>. A message resent with an id the thread has is a duplicate, as on the Cockpit. Larry
answers every message of Igor's a second later ("Larry heard: <text>"). Every request is a JSON line in REPORT.
"""

import json
import secrets
import sys
import threading
import time
import urllib.parse
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT, REPORT = int(sys.argv[1]), sys.argv[2]
LOCK = threading.Lock()
THREADS = {
    "igor2-88g.900": {"title": "Should the phone chat poll?", "messages": [], "seen": ""},
}
CREATED = {}
IMAGES = {}


def now():
    return datetime.now().astimezone().isoformat(timespec="seconds")


def row(key, who, text, mid=None, attachments=None):
    r = {"id": mid or secrets.token_hex(6), "ts": now(), "thread": key, "who": who, "text": text,
         "source": "app" if who == "igor" else "cli"}
    if attachments:
        r["attachments"] = attachments
    return r


THREADS["igor2-88g.900"]["messages"] += [
    row("igor2-88g.900", "igor", "Does the phone poll while a thread is open?"),
    row("igor2-88g.900", "larry", "Every four seconds, and the list on each return."),
]


def summary(key, t):
    last = t["messages"][-1]
    larry = [m["ts"] for m in t["messages"] if m["who"] == "larry"]
    unread = len([ts for ts in larry if ts > t["seen"]])
    return {"key": key, "title": t["title"], "count": len(t["messages"]), "last_ts": last["ts"],
            "last_who": last["who"], "last_text": last["text"] or "[image]", "larry_ts": larry,
            "unread": unread, "done": False}


def reply_later(key, text):
    def go():
        time.sleep(1)
        with LOCK:
            THREADS[key]["messages"].append(row(key, "larry", "Larry heard: " + (text or "a picture")))
    threading.Thread(target=go, daemon=True).start()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _json(self, status, obj):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _report(self, extra):
        with open(REPORT, "a") as f:
            f.write(json.dumps({"method": self.command, "path": self.path, **extra}) + "\n")

    def do_GET(self):
        path = urllib.parse.unquote(self.path.split("?")[0])
        self._report({})
        with LOCK:
            if path == "/chat":
                rows = [summary(k, t) for k, t in THREADS.items() if t["messages"]]
                return self._json(200, {"ok": True, "threads": rows})
            if path.startswith("/chat/"):
                t = THREADS.get(path[len("/chat/"):])
                return self._json(200, {"ok": True, "messages": t["messages"] if t else []})
            if path.startswith("/attachments/") and path[len("/attachments/"):] in IMAGES:
                data = IMAGES[path[len("/attachments/"):]]
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                return self.wfile.write(data)
        self._json(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        path = urllib.parse.unquote(self.path.split("?")[0])
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0") or 0))
        if path == "/attachments":
            self._report({"bytes": len(raw), "origin": self.headers.get("Origin")})
            ref = "%s/%s.png" % (datetime.now().strftime("%Y-%m-%d"), secrets.token_hex(8))
            with LOCK:
                IMAGES[ref] = raw
            return self._json(200, {"ok": True, "ref": ref, "url": "/attachments/" + ref})
        data = json.loads(raw or b"{}")
        self._report({"body": {k: v for k, v in data.items() if k != "text"}, "chars": len(data.get("text") or ""),
                      "origin": self.headers.get("Origin")})
        with LOCK:
            if path == "/chat-seen":
                t = THREADS.get(data.get("thread"))
                if t and t["messages"]:
                    t["seen"] = max(m["ts"] for m in t["messages"])
                return self._json(200, {"ok": True, "marked": 1})
            if path == "/chat":
                key = CREATED.get(data.get("id"))
                if not key:
                    key = "igor2-88g.%d" % (901 + len(CREATED))
                    CREATED[data.get("id")] = key
                    THREADS[key] = {"title": data.get("title") or "untitled", "messages": [], "seen": ""}
            elif path.startswith("/chat/"):
                key = path[len("/chat/"):]
                if key not in THREADS:
                    return self._json(404, {"ok": False, "error": "no such thread"})
            else:
                return self._json(404, {"ok": False, "error": "unknown endpoint"})
            t = THREADS[key]
            mine = [m for m in t["messages"] if m["id"] == data.get("id")]
            if mine:
                return self._json(200, {"ok": True, "thread": key, "message": mine[0], "duplicate": True})
            m = row(key, "igor", data.get("text") or "", data.get("id"), data.get("attachments"))
            t["messages"].append(m)
        reply_later(key, data.get("text"))
        self._json(200, {"ok": True, "thread": key, "message": m, "title": t["title"]})


ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
