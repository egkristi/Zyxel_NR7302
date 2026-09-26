#!/usr/bin/env python3
"""Enkel falsk adb for testene. Enhetens filsystem ligger under $FAKE_ADB_ROOT.

Støtter: get-state, wait-for-device, push, pull, shell <kommando>. «reboot» gjør at neste
get-state feiler én gang (enheten er borte). FAKE_ADB_KORRUPT=1 kutter filer ved push.
"""
import os
import re
import shutil
import subprocess
import sys

ROOT = os.environ["FAKE_ADB_ROOT"]
DOWN = os.path.join(ROOT, ".nede")


def dev(path):
    return os.path.join(ROOT, path.lstrip("/"))


def main(args):
    cmd = args[0]
    if cmd == "get-state":
        if os.path.exists(DOWN):
            os.remove(DOWN)
            return 1
        print("device")
    elif cmd == "wait-for-device":
        pass
    elif cmd == "push":
        data = open(args[1], "rb").read()
        if os.environ.get("FAKE_ADB_KORRUPT"):
            data = data[: len(data) // 2]
        with open(dev(args[2]), "wb") as f:
            f.write(data)
    elif cmd == "pull":
        shutil.copy(dev(args[1]), args[2])
    elif cmd == "shell":
        line = " ".join(args[1:])
        if line == "reboot":
            open(DOWN, "w").close()
            return 0
        if "/proc/uptime" in line:
            print("999")
            return 0
        line = re.sub(r"(?<![\w.])/(xdata|tmp)/", lambda m: dev(m.group(0)), line)
        return subprocess.run(["sh", "-c", line]).returncode
    else:
        print(f"fake_adb: ukjent kommando {cmd}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
