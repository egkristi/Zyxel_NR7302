#!/usr/bin/env python3
"""Send AT-kommandoer til NR7302 via AT-porten på USB og skriv ut svaret.

  sudo ./modem-at.py 'ATI' 'AT+QCFG="usbcfg"'
  sudo ./modem-at.py --port /dev/ttyUSB0 'AT+CGMR'

Krever at ModemManager ikke holder porten (se ../10-pc-installer-pakker-og-udev.sh).
Alle kommandoer og svar logges i logg/at-<dato>.log.
"""
import argparse
import datetime
import os
import select
import termios
import time

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def open_port(path):
    fd = os.open(path, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0                                   # iflag
    attrs[1] = 0                                   # oflag
    attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    attrs[3] = 0                                   # lflag (raw)
    attrs[4] = attrs[5] = termios.B115200
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    termios.tcflush(fd, termios.TCIOFLUSH)
    return fd


def command(fd, cmd, timeout):
    os.write(fd, (cmd + "\r").encode())
    buf, end = b"", time.time() + timeout
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            buf += os.read(fd, 4096)
            text = buf.decode(errors="replace")
            if any(t in text for t in ("\r\nOK\r\n", "ERROR")):
                break
    return buf.decode(errors="replace").strip()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="/dev/ttyUSB0")
    ap.add_argument("--timeout", type=float, default=5)
    ap.add_argument("cmds", nargs="+")
    a = ap.parse_args()
    fd = open_port(a.port)
    log = os.path.join(BASE, "logg", f"at-{datetime.date.today()}.log")
    with open(log, "a") as lf:
        for c in a.cmds:
            resp = command(fd, c, a.timeout)
            out = f">>> {c}\n{resp}\n"
            print(out)
            lf.write(f"[{datetime.datetime.now():%H:%M:%S}] {out}")
    os.close(fd)
