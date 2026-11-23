#!/usr/bin/env python3
"""Open the current directory on lap in a new Kitty tab backed by Screen."""

import argparse
import errno
import json
import os
from pathlib import Path
import re
import shlex
import sys
from uuid import uuid4


DCS = b"\x1bP"
ST = b"\x1b\\"


def screen_passthrough(sequence):
    # Keep each block below Screen's buffer limit and split the inner terminator.
    body = sequence[:-1]
    chunks = [body[i:i + 512] for i in range(0, len(body), 512)]
    return b"".join(DCS + chunk + ST for chunk in (*chunks, sequence[-1:]))


def write_ssh_terminal(path, sequence):
    if not re.fullmatch(r"/dev/pts/[0-9]+", path):
        raise ValueError("--ssh-tty must name a /dev/pts/N device.")
    descriptor = os.open(path, os.O_WRONLY | os.O_NOCTTY | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "wb") as terminal:
        if not terminal.isatty() or os.fstat(descriptor).st_uid != os.geteuid():
            raise ValueError("--ssh-tty must be a terminal owned by the current user.")
        terminal.write(sequence)


def codex_terminal(directory):
    # The detached runner inherits the daemon's SSH environment. Find the
    # live foreground client in this workspace, including its Screen terminal.
    terminals = set()
    for process in Path("/proc").iterdir():
        if not process.name.isdecimal():
            continue
        try:
            if process.stat().st_uid != os.getuid() or (process / "comm").read_text().strip() != "codex":
                continue
            workspace = Path(os.readlink(process / "cwd"))
            if not directory.is_relative_to(workspace):
                continue
            fields = (process / "stat").read_text().rsplit(")", 1)[1].split()
            group, tty_number, foreground = fields[2], int(fields[4]), fields[5]
            if not tty_number or group != foreground:
                continue
            stdout = process / "fd/1"
            device = os.readlink(stdout)
            if not re.fullmatch(r"/dev/pts/[0-9]+", device) or stdout.stat().st_rdev != tty_number:
                continue
            environment = (process / "environ").read_bytes().split(b"\0")
            if any(entry.startswith(b"SSH_CONNECTION=") for entry in environment):
                in_screen = any(entry.startswith(b"STY=") and entry != b"STY=" for entry in environment)
                terminals.add((device, in_screen))
        except OSError:
            continue

    if not terminals:
        raise ValueError("no SSH terminal found for this workspace. Run tt at the SSH shell prompt or use --ssh-tty.")
    if len(terminals) > 1:
        raise ValueError("multiple Codex SSH terminals match this workspace. Use --ssh-tty to select one.")
    return terminals.pop()


def write_current_terminal(sequence, directory):
    try:
        terminal = open("/dev/tty", "wb")
    except OSError as error:
        if error.errno != errno.ENXIO:
            raise
        device, in_screen = codex_terminal(directory)
        write_ssh_terminal(device, screen_passthrough(sequence) if in_screen else sequence)
        return

    with terminal:
        if not os.environ.get("SSH_CONNECTION"):
            raise ValueError("run this from an SSH session on lap.")
        terminal.write(screen_passthrough(sequence) if os.environ.get("STY") else sequence)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ssh-tty", metavar="DEVICE", help="write directly to the SSH transport terminal")
    options = parser.parse_args()

    try:
        directory = Path.cwd()
        session = f"resume-{uuid4().hex}"
        command = (
            f"cd -- {shlex.quote(str(directory))} || cd; "
            f"exec ~/.local/bin/screen5 -q -d -R -S {session}"
        )
        request = {
            "cmd": "launch",
            "version": [0, 26, 0],
            "no_response": True,
            "payload": {
                "type": "tab",
                "self": True,
                "args": [
                    "ssh", "-t",
                    "-o", "ClearAllForwardings=yes",
                    "-o", "ControlMaster=no",
                    "-o", "ControlPath=none",
                    "lap", command,
                ],
            },
        }
        sequence = DCS + b"@kitty-cmd" + json.dumps(request).encode("ascii") + ST
        if options.ssh_tty is not None:
            write_ssh_terminal(options.ssh_tty, sequence)
        else:
            write_current_terminal(sequence, directory)
    except (OSError, ValueError) as error:
        print(f"tt: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
