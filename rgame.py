#!/usr/bin/env python3
"""Build on lap and launch the game in the SSH client's desktop session."""

import argparse
import contextlib
import fcntl
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import shutil
import socket
import stat
import subprocess
import sys
import tempfile
import uuid


sys.dont_write_bytecode = True

HOST = "lap"
PORT = 47623
TOKEN_FILE = Path.home() / ".config" / "rgame" / "token"
MESSAGE_LIMIT = 65536
SYNC_TIMEOUT = 300
IDENTIFIER = re.compile(r"[a-f0-9]{32}")
RSYNC_PROGRESS = re.compile(r"^\s*[0-9,]+B?\s+(\d{1,3})%\s+(\S+/s)\s+([0-9:?]+)(?:\s|$)")
SSH_TRANSPORT = (
    "ssh -o BatchMode=yes -o ConnectTimeout=8 -o ClearAllForwardings=yes "
    "-o ControlMaster=no -o ControlPath=none"
)


def token():
    return TOKEN_FILE.read_text(encoding="ascii").strip()


def bundle_root(uid):
    return Path("/tmp") / f"rgame-{uid}"


def private_bundle_root():
    uid = os.getuid()
    root = bundle_root(uid)
    root.mkdir(mode=0o700, exist_ok=True)
    info = root.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != uid or info.st_mode & 0o077:
        raise RuntimeError(f"{root} must be a private directory owned by the current user.")
    return root


def receive(stream):
    message = stream.readline(MESSAGE_LIMIT + 1)
    if len(message) > MESSAGE_LIMIT or not message.endswith(b"\n"):
        raise ValueError("Incomplete or oversized rgame message.")
    value = json.loads(message)
    if not isinstance(value, dict):
        raise ValueError("Expected an rgame JSON object.")
    return value


def send(connection, value):
    message = json.dumps(value).encode() + b"\n"
    if len(message) > MESSAGE_LIMIT:
        raise ValueError("rgame message is too large.")
    connection.sendall(message)


def show_transfer_progress(percent, status):
    columns = max(1, shutil.get_terminal_size((80, 24)).columns - 1)
    width = min(24, max(5, columns - 34))
    filled = percent * width // 100
    bar = "#" * filled + "-" * (width - filled)
    line = f"Transfer [{bar}] {percent:3}%  {status}"
    print("\r" + line[:columns].ljust(columns), end="", file=sys.stderr, flush=True)


def request(operation, **fields):
    try:
        connection = socket.create_connection(("127.0.0.1", PORT), timeout=3)
    except OSError as error:
        raise RuntimeError("Launcher is unreachable. Reconnect from the desktop with ssh lap.") from error
    show_progress = operation == "launch" and sys.stderr.isatty()
    drew_progress = False
    with connection, connection.makefile("rb") as stream:
        connection.settimeout(SYNC_TIMEOUT + 30)
        send(connection, {"operation": operation, "token": token(), "progress": show_progress, **fields})
        try:
            reply = receive(stream)
            while "progress" in reply:
                if show_progress:
                    percent, status = reply["progress"]
                    show_transfer_progress(percent, status)
                    drew_progress = True
                reply = receive(stream)
        finally:
            if drew_progress:
                print(file=sys.stderr, flush=True)
    if not reply.get("ok"):
        raise RuntimeError(reply.get("error", "The desktop launcher rejected the request."))
    return reply["message"]


@contextlib.contextmanager
def cache_lock(path):
    with path.open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RuntimeError("Another rgame build or transfer is already in progress.") from error
        yield


def build_and_launch(arguments):
    from rgame_bundle import build_bundle

    print(request("check"), flush=True)
    project = Path(subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], text=True,
    ).strip())
    bundles = private_bundle_root() / "outgoing"
    bundles.mkdir(mode=0o700, exist_ok=True)
    build_id = uuid.uuid4().hex
    worktree_key = hashlib.sha256(os.fsencode(project)).hexdigest()
    with tempfile.TemporaryDirectory(prefix=".staging-", dir=bundles) as temporary:
        staged = Path(temporary) / "bundle"
        staged.mkdir(mode=0o700)
        with cache_lock(bundles / f".lock-{worktree_key}"):
            build_bundle(project, staged)
        published = bundles / build_id
        staged.rename(published)
        try:
            print("Build ready. Pulling it to your desktop…", flush=True)
            print(request("launch", build=build_id, uid=os.getuid(), arguments=arguments))
        finally:
            shutil.rmtree(published)


def checked(command, **kwargs):
    result = subprocess.run(command, text=True, capture_output=True, **kwargs)
    if result.returncode:
        detail = (result.stderr or result.stdout).strip()
        raise RuntimeError(f"{command[0]} failed: {detail or result.returncode}")
    return result.stdout


def transfer_bundle(command, report):
    if report is None:
        checked(command, timeout=SYNC_TIMEOUT)
        return

    report(0, "Checking cached files")
    command = [
        "timeout", "--kill-after=5s", f"{SYNC_TIMEOUT}s",
        command[0], "--info=progress2,name0", "--no-inc-recursive", "--outbuf=N",
        *command[1:],
    ]
    percent = 0
    previous = None
    with tempfile.TemporaryFile() as errors, subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=errors, env={**os.environ, "LC_ALL": "C"},
        text=True, encoding="utf-8", errors="replace",
    ) as process:
        try:
            for line in process.stdout:
                match = RSYNC_PROGRESS.match(line)
                if match:
                    percent = max(percent, min(99, int(match[1])))
                    status = match[2]
                    if "(xfr#" not in line:
                        status += f"  ETA {match[3]}"
                    update = (percent, status)
                    if update != previous:
                        report(*update)
                        previous = update
            result = process.wait()
        finally:
            if process.poll() is None:
                process.terminate()
        if result in {124, 137}:
            raise RuntimeError(f"rsync timed out after {SYNC_TIMEOUT} seconds.")
        if result:
            errors.seek(0)
            detail = errors.read(8192).decode(errors="replace").strip()
            raise RuntimeError(f"rsync failed: {detail or result}")
    report(100, "Complete")


def start_game(bundle, unit, arguments):
    environment = {**os.environ, "LC_ALL": "C", "LD_LIBRARY_PATH": str(bundle / "lib")}
    if not (bundle / "assets").is_dir():
        raise RuntimeError("The transferred bundle is missing its assets.")
    executables = [path for path in bundle.iterdir() if path.is_file() and os.access(path, os.X_OK)]
    if len(executables) != 1:
        raise RuntimeError("The transferred bundle must contain one game executable.")
    executable = executables[0]
    libraries = checked(["ldd", str(executable)], env=environment, timeout=10)
    missing = [line.strip() for line in libraries.splitlines() if "not found" in line]
    if missing:
        raise RuntimeError("Desktop libraries missing: " + ", ".join(missing))
    checked([
        "systemd-run", "--user", "--quiet", "--collect", "--service-type=exec",
        "--expand-environment=no",
        f"--unit={unit}", f"--working-directory={bundle}",
        f"--setenv=BEVY_ASSET_ROOT={bundle}", f"--setenv=LD_LIBRARY_PATH={bundle / 'lib'}",
        "--", str(executable), *arguments,
    ], timeout=20)


def prune_completed(bundles, current):
    for previous in bundles.iterdir():
        if previous == current or not IDENTIFIER.fullmatch(previous.name):
            continue
        result = subprocess.run(
            ["systemctl", "--user", "is-active", f"rgame-game-{previous.name}.service"],
            text=True, capture_output=True, timeout=10,
        )
        if result.stdout.strip() in {"inactive", "failed", "unknown"}:
            shutil.rmtree(previous)


def pull_and_launch(build_id, source_uid, arguments, report=None):
    bundles = private_bundle_root() / "local"
    bundles.mkdir(mode=0o700, exist_ok=True)
    newest = bundles / "current"
    destination = bundles / build_id
    unit = f"rgame-game-{build_id}.service"
    with cache_lock(bundles / ".lock"):
        if destination.exists():
            raise RuntimeError("This build was already received.")
        with tempfile.TemporaryDirectory(prefix=".staging-", dir=bundles) as temporary:
            staged = Path(temporary) / "bundle"
            staged.mkdir(mode=0o700)
            sync = ["rsync", "-rt", "--perms", "--checksum", "--timeout=30", "-e", SSH_TRANSPORT]
            if newest.is_dir():
                sync.extend(["--link-dest", str(newest.resolve())])
            source = bundle_root(source_uid) / "outgoing" / build_id
            sync.extend([f"{HOST}:{source}/", str(staged) + "/"])
            transfer_bundle(sync, report)
            staged.rename(destination)
            try:
                start_game(destination, unit, arguments)
            except Exception:
                shutil.rmtree(destination)
                raise
            alias = Path(temporary) / "current"
            alias.symlink_to(build_id)
            alias.replace(newest)
        try:
            prune_completed(bundles, destination)
        except (OSError, subprocess.SubprocessError) as error:
            print(f"Could not clean up old rgame bundles: {error}", file=sys.stderr)
    return f"Launched on your desktop. On the desktop, view logs with journalctl --user -u {unit}"


def serve():
    with socket.socket(fileno=0) as connection, connection.makefile("rb") as stream:
        connection.settimeout(5)
        try:
            message = receive(stream)
            supplied = message.get("token")
            if not isinstance(supplied, str) or not hmac.compare_digest(supplied.encode(), token().encode()):
                raise RuntimeError("Unauthorized rgame request.")
            if not (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")):
                raise RuntimeError("The desktop launcher needs a logged-in graphical session.")
            if message.get("operation") == "check":
                result = "Desktop launcher is ready."
            elif message.get("operation") == "launch":
                build_id = message.get("build")
                source_uid = message.get("uid")
                arguments = message.get("arguments")
                if not isinstance(build_id, str) or not IDENTIFIER.fullmatch(build_id):
                    raise ValueError("Invalid build identifier.")
                if type(source_uid) is not int or not 0 <= source_uid < 2**32 - 1:
                    raise ValueError("Invalid build host user ID.")
                if not isinstance(arguments, list) or any(
                    not isinstance(argument, str) or "\0" in argument for argument in arguments
                ):
                    raise ValueError("Invalid game arguments.")
                report = None
                if message.get("progress") is True:
                    def report(percent, status):
                        send(connection, {"progress": [percent, status]})
                result = pull_and_launch(build_id, source_uid, arguments, report)
            else:
                raise ValueError("Unknown rgame operation.")
            send(connection, {"ok": True, "message": result})
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            with contextlib.suppress(OSError):
                send(connection, {"ok": False, "error": str(error)})


def main():
    if sys.argv[1:] == ["--serve"]:
        serve()
        return 0
    parser = argparse.ArgumentParser(
        description="On lap, build the current game worktree and open it on your desktop.",
        epilog="Set RGAME_BIN to select a Cargo binary. Pass game arguments after --.",
    )
    parser.add_argument("--check", action="store_true", help="check the desktop connection")
    parser.add_argument("arguments", nargs=argparse.REMAINDER, help="arguments for the game")
    options = parser.parse_args()
    arguments = options.arguments
    if arguments and arguments[0] == "--":
        arguments = arguments[1:]
    try:
        if options.check:
            print(request("check"))
        else:
            build_and_launch(arguments)
    except KeyboardInterrupt:
        print("rgame: cancelled.", file=sys.stderr)
        return 130
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"rgame: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
