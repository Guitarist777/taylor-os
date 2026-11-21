#!/usr/bin/env python3
"""Drive the test virtual PC: its serial console (log in, run commands) and QEMU's monitor (screenshots, keys).

    vmctl.py wait-login TIMEOUT_S              wait for "login:" on the serial console
    vmctl.py run USER PASSWORD OUTFILE CMD...  log in on the serial console, run each CMD, save everything to OUTFILE
    vmctl.py shot FILE.png                     screenshot of the screen
    vmctl.py type TEXT                         type on the keyboard (letters, digits); "\\n" presses Enter
    vmctl.py key COMBO                         press keys together, e.g. meta_l-ret
    vmctl.py click X Y SCREEN_W SCREEN_H       left-click at a screen pixel (needs -device usb-tablet)
    vmctl.py move X Y SCREEN_W SCREEN_H        move the pointer there (no click)
    vmctl.py drag X1 Y1 X2 Y2 SCREEN_W SCREEN_H [MOD]  press the left button at X1 Y1, glide to X2 Y2, let go
                                               (MOD: a key held down meanwhile, e.g. meta_l)
    vmctl.py scroll X Y SCREEN_W SCREEN_H N    scroll the wheel N notches there (negative = down)
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


def clean(t):
    t = re.sub(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)", "", t)     # OSC (links, the shell's 3008 marks)
    t = re.sub(r"\x1b\[[0-9;?]*[ -/]*[@-~]", "", t)              # CSI (colours, cursor)
    t = re.sub(r"\x1b[()][A-Za-z0-9]", "", t)
    return t.replace("\r", "")


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
        text = clean(buf)       # Bazzite's prompt and banner are full of colour and terminal-mark codes: match the plain text
        if re.search(pattern, text, re.M):
            return text
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
    # the first login after a start can sit after the welcome banner for minutes (run 3, 2026-11-18): nudge, wait up to 5 min
    for attempt in range(10):
        try:
            read_until(s, prompt, 30)
            break
        except TimeoutError:
            if attempt == 9:
                raise
            send(s, "\r")
    time.sleep(2)
    send(s, "export PAGER=cat SYSTEMD_PAGER=cat TERM=dumb; stty cols 200 -echo\r")
    read_until(s, prompt, 20)
    out = []
    for c in cmds:
        n = len(out)
        send(s, f"{c}; printf '__DO%sNE_%s__\\n' '' {n}\r")
        text = read_until(s, rf"__DONE_{n}__\r?\n", 2400)   # an update download can take many minutes
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


def key_combo(combo):
    """Press keys together, e.g. "meta_l-ret" (QEMU key names)."""
    qmp("send-key", {"keys": [{"type": "qcode", "data": k} for k in combo.split("-")]})


def click(x, y, width, height):
    """Left-click at screen pixel (x, y). Needs the virtual PC's usb-tablet (an absolute pointer)."""
    ax = round(x * 32767 / (width - 1))
    ay = round(y * 32767 / (height - 1))
    qmp("input-send-event", {"events": [{"type": "abs", "data": {"axis": "x", "value": ax}},
                                        {"type": "abs", "data": {"axis": "y", "value": ay}}]})
    time.sleep(0.4)
    for down in (True, False):
        qmp("input-send-event", {"events": [{"type": "btn", "data": {"down": down, "button": "left"}}]})
        time.sleep(0.15)


def _abs(x, y, width, height):
    return [{"type": "abs", "data": {"axis": "x", "value": round(x * 32767 / (width - 1))}},
            {"type": "abs", "data": {"axis": "y", "value": round(y * 32767 / (height - 1))}}]


def move(x, y, width, height):
    qmp("input-send-event", {"events": _abs(x, y, width, height)})


def drag(x1, y1, x2, y2, width, height, mod=None):
    if mod:
        qmp("input-send-event", {"events": [{"type": "key", "data": {"down": True, "key": {"type": "qcode", "data": mod}}}]})
    move(x1, y1, width, height)
    time.sleep(0.4)
    qmp("input-send-event", {"events": [{"type": "btn", "data": {"down": True, "button": "left"}}]})
    time.sleep(0.3)
    steps = 30
    for i in range(1, steps + 1):
        move(x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps, width, height)
        time.sleep(0.04)
    time.sleep(0.6)
    qmp("input-send-event", {"events": [{"type": "btn", "data": {"down": False, "button": "left"}}]})
    if mod:
        time.sleep(0.2)
        qmp("input-send-event", {"events": [{"type": "key", "data": {"down": False, "key": {"type": "qcode", "data": mod}}}]})


def scroll(x, y, width, height, n):
    move(x, y, width, height)
    time.sleep(0.3)
    b = "wheel-up" if n > 0 else "wheel-down"
    for _ in range(abs(n)):
        for down in (True, False):
            qmp("input-send-event", {"events": [{"type": "btn", "data": {"down": down, "button": b}}]})
            time.sleep(0.05)


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
    elif a[0] == "key":
        key_combo(a[1])
    elif a[0] == "click":
        click(int(a[1]), int(a[2]), int(a[3]), int(a[4]))
    elif a[0] == "move":
        move(int(a[1]), int(a[2]), int(a[3]), int(a[4]))
    elif a[0] == "drag":
        drag(int(a[1]), int(a[2]), int(a[3]), int(a[4]), int(a[5]), int(a[6]), a[7] if len(a) > 7 else None)
    elif a[0] == "scroll":
        scroll(int(a[1]), int(a[2]), int(a[3]), int(a[4]), int(a[5]))
