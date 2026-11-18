#!/usr/bin/env python3
"""SQLite in WAL mode on the Windows drive: does it survive a crash? (2026-11-18, for "one TAYLOR, either side")

A MADE-UP brain only: a throwaway database of random rows, nothing of hers. Standard library only.
TAYLOR keeps several connections to its brain at once (the server, the job worker, the meetings worker), all in WAL
mode with a busy timeout, so this does the same: several writer processes and a reader, each with its own connection.

    wal_proof.py crash DIR [ROUNDS]   writers + reader, kill -9 mid-write, reopen, integrity_check, every acked row there
    wal_proof.py leave DIR            writers, kill -9, and LEAVE the -wal file behind (as when the PC is switched off)
    wal_proof.py verify DIR           open what was left (on any OS / driver), integrity_check, every acked row there

Each line it prints that starts with PASS or FAIL is a result. The acknowledgements ("this writer has committed row
N") are written with fsync to a separate file before the writer goes on, so a row that was acknowledged must be in
the database after the crash.
"""
import json
import os
import random
import signal
import sqlite3
import subprocess
import sys
import time

WRITERS = 4


def connect(db):
    c = sqlite3.connect(db, timeout=20)
    c.execute("PRAGMA journal_mode=WAL")
    c.execute("PRAGMA busy_timeout=20000")
    return c


def setup(dirpath):
    os.makedirs(dirpath, exist_ok=True)
    db = os.path.join(dirpath, "brain_test.db")
    c = connect(db)
    c.execute("CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY, writer INTEGER, n INTEGER, body TEXT, blob BLOB)")
    c.execute("CREATE INDEX IF NOT EXISTS notes_wn ON notes(writer, n)")
    c.execute("CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(body)")   # TAYLOR's notes use FTS5 too
    c.commit()
    c.close()
    return db


def writer(db, wid, ackfile):
    c = connect(db)
    start = c.execute("SELECT COALESCE(MAX(n), 0) FROM notes WHERE writer=?", (wid,)).fetchone()[0]
    n = start
    fd = os.open(ackfile, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    rnd = random.Random(wid * 7919 + int(time.time()))
    while True:
        rows = []
        for _ in range(rnd.randint(1, 20)):
            n += 1
            body = " ".join(rnd.choice(("garden", "tea", "lamp", "river", "piano", "maple", "cloud", "ticket")) for _ in range(12))
            blob = os.urandom(rnd.choice((16, 256, 2048, 2048, 32768)))     # small notes and bigger ones (pages, files)
            rows.append((wid, n, body, blob))
        with c:
            c.executemany("INSERT INTO notes (writer, n, body, blob) VALUES (?,?,?,?)", rows)
            c.executemany("INSERT INTO notes_fts (body) VALUES (?)", [(r[2],) for r in rows])
        os.write(fd, f"{wid} {n}\n".encode())
        os.fsync(fd)
        time.sleep(0.02)                                               # a busy brain, not a disk benchmark


def reader(db):
    c = connect(db)
    while True:
        c.execute("SELECT writer, COUNT(*), MAX(n) FROM notes GROUP BY writer").fetchall()
        c.execute("SELECT COUNT(*) FROM notes_fts WHERE notes_fts MATCH 'piano'").fetchone()
        time.sleep(0.01)


def acked(ackfile):
    best = {}
    if os.path.exists(ackfile):
        for line in open(ackfile):
            parts = line.split()
            if len(parts) == 2:
                best[int(parts[0])] = max(best.get(int(parts[0]), 0), int(parts[1]))
    return best


def check(db, ackfile, label):
    ok = True
    c = sqlite3.connect(db, timeout=20)
    res = c.execute("PRAGMA integrity_check").fetchall()
    good = res == [("ok",)]
    print(("PASS" if good else "FAIL") + f" {label}: integrity_check says {res[0][0] if res else 'nothing'}")
    ok &= good
    mode = c.execute("PRAGMA journal_mode").fetchone()[0]
    print(("PASS" if mode == "wal" else "FAIL") + f" {label}: the database is still in WAL mode ({mode})")
    ok &= mode == "wal"
    a = acked(ackfile)
    have = dict(c.execute("SELECT writer, MAX(n) FROM notes GROUP BY writer").fetchall())
    lost = {w: (n, have.get(w, 0)) for w, n in a.items() if have.get(w, 0) < n}
    total = c.execute("SELECT COUNT(*) FROM notes").fetchone()[0]
    print(("PASS" if not lost else "FAIL") + f" {label}: every acknowledged row is there ({total} rows, acked {sum(a.values())}; lost {lost or 'none'})")
    ok &= not lost
    gaps = c.execute("SELECT writer, COUNT(*), MAX(n) - MIN(n) + 1 FROM notes GROUP BY writer").fetchall()
    holes = [g for g in gaps if g[1] != g[2]]
    print(("PASS" if not holes else "FAIL") + f" {label}: no half-written transaction (no gaps in any writer's rows)")
    ok &= not holes
    fts = c.execute("SELECT COUNT(*) FROM notes_fts").fetchone()[0]
    print(("PASS" if fts == total else "FAIL") + f" {label}: the full-text index matches the table ({fts} = {total})")
    ok &= fts == total
    c.close()
    return ok


def spawn(args):
    return subprocess.Popen([sys.executable, __file__] + args)


def crash_once(db, ackfile, seconds):
    procs = [spawn(["_writer", db, str(w), ackfile]) for w in range(1, WRITERS + 1)] + [spawn(["_reader", db])]
    time.sleep(seconds)
    shm = os.path.exists(db + "-shm")
    wal = os.path.getsize(db + "-wal") if os.path.exists(db + "-wal") else 0
    for p in procs:
        os.kill(p.pid, signal.SIGKILL)
    for p in procs:
        p.wait()
    return shm, wal


def main():
    mode, d = sys.argv[1], sys.argv[2]
    if mode == "_writer":
        return writer(d, int(sys.argv[3]), sys.argv[4])
    if mode == "_reader":
        return reader(d)
    db = setup(d) if mode != "verify" else os.path.join(d, "brain_test.db")
    ackfile = os.path.join(d, "acks.txt")
    ok = True
    if mode == "crash":
        rounds = int(sys.argv[3]) if len(sys.argv) > 3 else 5
        for r in range(1, rounds + 1):
            shm, wal = crash_once(db, ackfile, random.uniform(4, 9))
            print(("PASS" if shm else "FAIL") + f" round {r}: the shared-memory file (-shm) works on this drive")
            ok &= shm
            print(f"     round {r}: killed {WRITERS} writers and a reader mid-write; -wal was {wal} bytes")
            ok &= check(db, ackfile, f"round {r}")
        c = connect(db)
        c.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        busy = c.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()
        c.close()
        print(("PASS" if busy[0] == 0 else "FAIL") + f" a full checkpoint folds the -wal back into the database ({busy})")
        ok &= busy[0] == 0
    elif mode == "leave":
        shm, wal = crash_once(db, ackfile, random.uniform(4, 9))
        left = os.path.exists(db + "-wal") and os.path.getsize(db + "-wal") > 0
        print(("PASS" if left else "FAIL") + f" killed mid-write with a {wal}-byte -wal file left behind")
        ok &= left
        json.dump(acked(ackfile), open(os.path.join(d, "acks_at_leave.json"), "w"))
    elif mode == "verify":
        ok &= check(db, ackfile, "opened after the switch")
    print("ALL PASSED" if ok else "SOME FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main() or 0)
