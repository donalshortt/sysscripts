#!/usr/bin/env python3
"""Resume the newest interactive Codex chat in this worktree.

Codex 0.164 removed the worktrees feature switch, so resume --last now
includes sibling worktrees. Read its local index and resume an explicit ID.
Use cx --dry-run to print the command without opening a chat.
"""
import os
from pathlib import Path
import re
import shlex
import sqlite3
import subprocess
import sys
import tomllib


def workspace_root(cwd=None):
    directory = Path(cwd or Path.cwd()).resolve()
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], cwd=directory,
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
    )
    return Path(result.stdout.rstrip("\n")).resolve() if result.returncode == 0 else directory


def sqlite_directory():
    config_directory = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    config_path = config_directory / "config.toml"
    config = tomllib.loads(config_path.read_text()) if config_path.exists() else {}
    return Path(os.environ.get("CODEX_SQLITE_HOME") or config.get("sqlite_home") or config_directory).expanduser().resolve()


def select_session(directory, workspace):
    databases = []
    for path in directory.glob("state_*.sqlite"):
        version = re.fullmatch(r"state_(\d+)\.sqlite", path.name)
        if version:
            databases.append((int(version[1]), path))
    if not databases:
        return None
    database = max(databases)[1]
    # The index is private Codex state: read only, and fail visibly on schema changes.
    connection = sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)
    try:
        rows = connection.execute(
            "SELECT id, cwd FROM threads "
            "WHERE archived = 0 AND source IN ('cli', 'vscode') "
            "ORDER BY COALESCE(updated_at_ms, updated_at * 1000) DESC, id DESC"
        )
        for session_id, saved_directory in rows:
            if Path(saved_directory).resolve() == workspace:
                return session_id
        return None
    finally:
        connection.close()


def main(arguments=None):
    arguments = list(sys.argv[1:] if arguments is None else arguments)
    dry_run = arguments[:1] == ["--dry-run"]
    if dry_run:
        arguments.pop(0)
    try:
        workspace = workspace_root()
        session_id = select_session(sqlite_directory(), workspace)
    except (OSError, sqlite3.Error, tomllib.TOMLDecodeError) as error:
        print(f"cx: could not select a saved chat: {error}", file=sys.stderr)
        return 1
    command = ["codex", "--yolo", "-C", str(workspace)]
    if session_id:
        command += ["resume", session_id]
    command += arguments
    if dry_run:
        print(shlex.join(command))
        return 0
    os.execvp(command[0], command)


if __name__ == "__main__":
    sys.exit(main())
