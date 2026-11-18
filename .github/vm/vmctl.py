#!/usr/bin/env python3
"""Drive the test virtual PC: its serial console (log in, run commands) and QEMU's monitor (screenshots, keys).

    vmctl.py wait-login TIMEOUT_S              wait for "login:" on the serial console
    vmctl.py run USER PASSWORD OUTFILE CMD...  log in on the serial console, run each CMD, save everything to OUTFILE
    vmctl.py shot FILE.png                     screenshot of the screen
    vmctl.py type TEXT                         type on the keyboard (letters, digits); "\\n" presses Enter
"""
import json
import re
import socket
import sys
import time

SERIAL = "/tmp/vm-serial.sock"
QMP = "/tmp/vm-qmp.sock"
LOG = "/tmp/vm-serial.log"


def serial():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SERIAL)
    s.settimeout(0.5)
    return s


def read_until(s, pattern, timeout):
    buf = ""
    end = time.time() + timeout
    while time.time() < end:
        try:
            chunk = s.recv(65536).decode("utf-8", "replace")
        except socket.timeout:
            continue
        if not chunk:
            break
        buf += chunk
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(chunk)
        if re.search(pattern, buf):
            return buf
    raise TimeoutError(f"no {pattern!r} after {timeout}s; last output: {buf[-600:]!r}")


def send(s, text):
    s.sendall(text.encode())


def wait_login(timeout):
    end = time.time() + timeout
    while time.time() < end:
        try:
            s = serial()
            send(s, "\r")
            read_until(s, r"login:\s*$", 30)
            print("login prompt seen")
            return
        except (TimeoutError, OSError):
            time.sleep(5)
    raise SystemExit(f"no login prompt in {timeout}s")


def run(user, password, outfile, cmds):
    # 2026-11-18, first run: the end marker was matched in the ECHO of the typed command, so every answer was cut off.
    # Now the typed text never contains the marker (printf builds it), and each step waits for the user's own prompt.
    prompt = re.escape(user) + r"@[^:\s]+:~\$ "
    s = serial()
    send(s, "\r")
    read_until(s, r"login:\s*$", 60)
    send(s, user + "\r")
    read_until(s, r"[Pp]assword:\s*$", 30)
    send(s, password + "\r")
    read_until(s, prompt, 90)
    time.sleep(2)
    send(s, "export PAGER=cat SYSTEMD_PAGER=cat TERM=dumb; stty cols 200 -echo\r")
    read_until(s, prompt, 20)
    out = []
    for c in cmds:
        n = len(out)
        send(s, f"{c}; printf '__DO%sNE_%s__\\n' '' {n}\r")
        text = read_until(s, rf"__DONE_{n}__\r?\n", 180)
        out.append(f"$ {c}\n{text}")
    send(s, "exit\r")
    with open(outfile, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print(f"ran {len(cmds)} commands, saved to {outfile}")


def qmp(cmd, args=None):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(QMP)
    f = s.makefile("rw")
    f.readline()
    f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n"); f.flush(); f.readline()
    f.write(json.dumps({"execute": cmd, **({"arguments": args} if args else {})}) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r:
            return r


KEYS = {" ": "spc", "\n": "ret", "-": "minus", ".": "dot", "/": "slash"}


def type_text(text):
    for ch in text.replace("\\n", "\n"):
        k = KEYS.get(ch, ch.lower())
        keys = [{"type": "qcode", "data": k}]
        if ch.isupper():
            keys.insert(0, {"type": "qcode", "data": "shift"})
        qmp("send-key", {"keys": keys})
        time.sleep(0.08)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "wait-login":
        wait_login(int(a[1]))
    elif a[0] == "run":
        run(a[1], a[2], a[3], a[4:])
    elif a[0] == "shot":
        print(qmp("screendump", {"filename": a[1], "format": "png"}))
    elif a[0] == "type":
        type_text(a[1])
