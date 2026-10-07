#!/usr/bin/env python3
"""Last visited native Space, tracked by Mimi's workspace hook; no polling.

Python 3.9+, standard library only. `record` consumes Mimi's hook JSON on stdin;
`sync` and `toggle` query Mimi directly. Existing state files remain compatible.

This is best-effort history, not a desktop-wide transaction: timestamps do not
resolve ties, clock resets, dropped events, Space reordering, or display scope.
State writes are atomic replacements, not power-loss-durable commits.
"""

from __future__ import annotations

from contextlib import contextmanager
from datetime import datetime, timezone
import errno
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

MIMI = "/opt/homebrew/bin/mimi"
STATE = Path.home() / ".local/state/mimi/space-history.json"
COMMAND_TIMEOUT = 5  # Per subprocess, not a deadline for the whole operation.
NANOSECONDS = 1_000_000_000
EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)
RFC3339 = re.compile(
    r"([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})"
    r"(?:\.([0-9]{1,9}))?(Z|[+-][0-9]{2}:[0-9]{2})"
)


@contextmanager
def locked(path: Path, blocking: bool = True):
    """Yield whether the lock was acquired; only nonblocking mode can yield False."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        flags = fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB)
        try:
            fcntl.flock(handle, flags)
        except OSError as error:
            if blocking or error.errno not in (errno.EACCES, errno.EAGAIN):
                raise
            yield False
            return
        try:
            yield True
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def is_space_index(value: object) -> bool:
    """Do not accept bool, which is also an instance of int."""
    return type(value) is int and value > 0


def read_state(path: Path) -> dict:
    """Treat missing or malformed history as empty; surface other I/O failures."""
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, ValueError):
        return {}
    if not isinstance(state, dict) or not is_space_index(state.get("current")):
        return {}
    return state if type(state.get("at", 0)) is int else {}


def write_state(path: Path, state: dict) -> None:
    """Replace the complete file. Caller must hold the separate state lock."""
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent,
            prefix=f".{path.name}.", delete=False,
        ) as handle:
            temporary = Path(handle.name)
            json.dump(state, handle)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def advance_history(state: dict, current: int, stamp: int) -> dict:
    """Pure transition for validated inputs; an older observation changes nothing."""
    if stamp < state.get("at", 0):
        return state
    if current != state.get("current"):
        return {"current": current, "previous": state.get("current"), "at": stamp}
    # Even the same Space advances the timestamp used to reject older events.
    return {**state, "at": stamp}


def observe(path: Path, current: int, stamp: int) -> dict:
    """Serialize read/decide/write, without holding this lock while calling Mimi."""
    if not is_space_index(current):
        return {}
    if type(stamp) is not int:
        raise ValueError("observation timestamp must be an integer")
    with locked(path.with_suffix(".lock")):
        state = read_state(path)
        updated = advance_history(state, current, stamp)
        if updated != state:
            write_state(path, updated)
        return updated


def timestamp_ns(value: str) -> int:
    """Parse Mimi/Go RFC3339 output without losing fractional nanoseconds."""
    match = RFC3339.fullmatch(value) if isinstance(value, str) else None
    if match is None:
        raise ValueError("hook event needs an RFC3339 timestamp with a timezone")
    whole, fraction, zone = match.groups()
    instant = datetime.fromisoformat(whole + zone.replace("Z", "+00:00"))
    delta = instant - EPOCH
    seconds = delta.days * 86_400 + delta.seconds
    return seconds * NANOSECONDS + int((fraction or "").ljust(9, "0"))


def record_hook(path: Path = STATE, stream=None) -> None:
    """Use the event's `at`, not the whole-second mimi_TIMESTAMP environment value."""
    stream = sys.stdin if stream is None else stream
    if stream.isatty():
        raise ValueError("record expects Mimi's workspace event JSON on stdin")
    event = json.loads(stream.readline())
    if not isinstance(event, dict) or event.get("kind") != "workspace_changed":
        raise ValueError("record expects a workspace_changed event")
    extra = event.get("extra") or {}
    if not isinstance(extra, dict):
        raise ValueError("hook event extra must be an object")
    index = extra.get("space_index")
    if isinstance(index, str) and index.isdecimal():
        index = int(index)
    if is_space_index(index):
        observe(path, index, timestamp_ns(event.get("at")))


def current_space() -> dict:
    output = subprocess.check_output(
        [MIMI, "query", "space"], text=True, timeout=COMMAND_TIMEOUT,
    )
    space = json.loads(output)
    if not isinstance(space, dict):
        raise ValueError("mimi query space did not return an object")
    if not all(is_space_index(space.get(key)) for key in ("index", "count")):
        raise ValueError("mimi query space needs positive integer index and count")
    if space["index"] > space["count"]:
        raise ValueError("mimi query space returned an index greater than count")
    return space


def switch(index: int) -> None:
    subprocess.run(
        [MIMI, "action", "space", str(index)], check=True, timeout=COMMAND_TIMEOUT,
    )


def sync(path: Path = STATE, query=current_space) -> tuple[dict, dict]:
    """Timestamp before the query so a slow response cannot claim a later time."""
    stamp = time.time_ns()
    current = query()
    return current, observe(path, current["index"], stamp)


def previous_space(state: dict, current: dict) -> int | None:
    """No target when the snapshot conflicts with newer history or is out of range."""
    if state.get("current") != current["index"]:
        return None
    target = state.get("previous")
    if not is_space_index(target) or target > current["count"]:
        return None
    return target if target != current["index"] else None


def toggle(path: Path = STATE, query=current_space, move=switch) -> None:
    """Drop overlapping toggles; this does not disable keyboard auto-repeat."""
    with locked(path.with_suffix(".toggle.lock"), blocking=False) as acquired:
        if not acquired:
            return
        current, state = sync(path, query)
        target = previous_space(state, current)
        if target is None:
            return
        move(target)
        # Record what a single query reports, never optimistically commit target.
        # If the switch is not yet visible, the later workspace hook can update it.
        sync(path, query)


def main(argv=None) -> None:
    args = sys.argv[1:] if argv is None else argv
    if args == ["record"]:
        record_hook()
    elif args == ["sync"]:
        sync()
    elif args == ["toggle"]:
        toggle()
    else:
        raise SystemExit("Usage: space_history.py record|sync|toggle")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"space_history: {error}", file=sys.stderr)
        raise SystemExit(1)
