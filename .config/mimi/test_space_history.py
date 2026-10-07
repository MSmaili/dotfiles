"""Offline Space history tests; no native Space switches."""

import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import space_history
from space_history import locked, observe, read_state, record_hook, timestamp_ns, toggle


class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "space-history.json"

    def seed(self):
        observe(self.path, 1, 1)
        observe(self.path, 4, 2)

    def test_first_space_has_no_previous(self):
        state = observe(self.path, 1, 1)
        self.assertIsNone(state["previous"])

    def test_duplicate_and_stale_hooks_do_not_change_previous(self):
        self.seed()
        observe(self.path, 4, 3)
        observe(self.path, 2, 1)
        self.assertEqual(read_state(self.path), {"current": 4, "previous": 1, "at": 3})

    def test_toggle_back_and_forth(self):
        self.seed()
        actual = {"index": 4, "count": 9}
        moved = []
        def move(index):
            moved.append(index)
            actual["index"] = index
        for _ in range(4):
            toggle(self.path, query=lambda: dict(actual), move=move)
        self.assertEqual(moved, [1, 4, 1, 4])

    def test_query_repairs_missed_hook(self):
        self.seed()
        actual = {"index": 3, "count": 9}
        moved = []
        def move(index):
            moved.append(index)
            actual["index"] = index
        toggle(self.path, query=lambda: dict(actual), move=move)
        self.assertEqual(moved, [4])
        self.assertEqual(read_state(self.path)["previous"], 3)

    def test_failed_switch_keeps_previous(self):
        self.seed()
        def fail(index):
            raise subprocess.CalledProcessError(1, ["mimi", "action", "space", str(index)])
        with self.assertRaises(subprocess.CalledProcessError):
            toggle(self.path, query=lambda: {"index": 4, "count": 9}, move=fail)
        self.assertEqual(read_state(self.path)["current"], 4)
        self.assertEqual(read_state(self.path)["previous"], 1)

    def test_missing_corrupt_and_out_of_range_history_do_not_switch(self):
        moved = []
        query = lambda: {"index": 4, "count": 9}
        toggle(self.path, query=query, move=moved.append)
        self.path.write_text("broken json")
        toggle(self.path, query=query, move=moved.append)
        self.path.write_text('{"current":4,"previous":99,"at":0}')
        toggle(self.path, query=query, move=moved.append)
        self.assertEqual(moved, [])

    def test_held_shortcut_does_not_queue_switches(self):
        with locked(self.path.with_suffix(".toggle.lock")):
            toggle(self.path, query=lambda: self.fail("must not query while switching"))

    def test_invalid_space_does_not_write_history(self):
        for value in (None, 0, -1, True, "2"):
            observe(self.path, value, 1)
        self.assertFalse(self.path.exists())

    def test_hook_timestamp_preserves_nanoseconds_and_timezones(self):
        base = timestamp_ns("2026-10-07T10:00:00Z")
        for fraction, offset in (("1", 100_000_000), ("123456", 123_456_000), ("123456789", 123_456_789)):
            with self.subTest(fraction=fraction):
                self.assertEqual(timestamp_ns(f"2026-10-07T10:00:00.{fraction}Z"), base + offset)
                self.assertEqual(timestamp_ns(f"2026-10-07T12:00:00.{fraction}+02:00"), base + offset)
        self.assertEqual(timestamp_ns("1969-12-31T23:59:59.999999999Z"), -1)

    def test_invalid_hook_timestamps_are_rejected(self):
        for value in (None, "", "2026-10-07T10:00:00", "2026-10-07T10:00:00.1234567890Z", "2026-99-07T10:00:00Z"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                timestamp_ns(value)

    def test_subsecond_hook_advances_history_and_rejects_older_event(self):
        base = timestamp_ns("2026-10-07T10:00:00Z")
        observe(self.path, 1, base + 100_000_000)
        for index, fraction in (("4", "200000001"), (3, "150000001"), ("2", "300000001")):
            event = {"kind": "workspace_changed", "at": f"2026-10-07T10:00:00.{fraction}Z", "extra": {"space_index": index}}
            record_hook(self.path, io.StringIO(json.dumps(event) + "\n"))
        self.assertEqual(read_state(self.path), {"current": 2, "previous": 4, "at": base + 300_000_001})

    def test_invalid_hook_payloads_do_not_write_history(self):
        for payload in ("", "broken json", "[]", '{"kind":"window_focus"}', '{"kind":"workspace_changed","extra":[1]}', '{"kind":"workspace_changed","extra":{"space_index":"4"}}'):
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                record_hook(self.path, io.StringIO(payload))
        for index in (None, 0, -1, True, "bad"):
            event = {"kind": "workspace_changed", "extra": {"space_index": index}}
            record_hook(self.path, io.StringIO(json.dumps(event)))
        self.assertFalse(self.path.exists())

    def test_same_or_stale_observation_does_not_rewrite_file(self):
        self.seed()
        with patch.object(space_history, "write_state") as write:
            observe(self.path, 4, 2)
            observe(self.path, 3, 1)
            write.assert_not_called()

    def test_query_snapshot_loses_to_newer_hook_without_switching(self):
        self.seed()
        moved = []
        def query():
            observe(self.path, 3, 11)
            return {"index": 4, "count": 9}
        with patch.object(space_history.time, "time_ns", return_value=10):
            toggle(self.path, query=query, move=moved.append)
        self.assertEqual(moved, [])
        self.assertEqual(read_state(self.path), {"current": 3, "previous": 4, "at": 11})

    def test_successful_command_does_not_optimistically_record_destination(self):
        self.seed()
        moved = []
        toggle(self.path, query=lambda: {"index": 4, "count": 9}, move=moved.append)
        self.assertEqual(moved, [1])
        self.assertEqual(read_state(self.path)["current"], 4)
        self.assertEqual(read_state(self.path)["previous"], 1)

    def test_query_and_switch_have_subprocess_timeouts(self):
        with patch.object(space_history.subprocess, "check_output", return_value='{"index":4,"count":9}') as query:
            self.assertEqual(space_history.current_space(), {"index": 4, "count": 9})
            query.assert_called_once_with([space_history.MIMI, "query", "space"], text=True, timeout=space_history.COMMAND_TIMEOUT)
        with patch.object(space_history.subprocess, "run") as move:
            space_history.switch(1)
            move.assert_called_once_with([space_history.MIMI, "action", "space", "1"], check=True, timeout=space_history.COMMAND_TIMEOUT)
        self.seed()
        with patch.object(space_history.subprocess, "run", side_effect=subprocess.TimeoutExpired("mimi", 5)):
            with self.assertRaises(subprocess.TimeoutExpired):
                toggle(self.path, query=lambda: {"index": 4, "count": 9})
        self.assertEqual(read_state(self.path)["previous"], 1)

    def test_invalid_query_responses_are_rejected(self):
        for value in (None, [], {}, {"index": True, "count": 9}, {"index": 4, "count": "9"}, {"index": 10, "count": 9}):
            with self.subTest(value=value), patch.object(space_history.subprocess, "check_output", return_value=json.dumps(value)):
                with self.assertRaises(ValueError):
                    space_history.current_space()

    def test_failed_atomic_replace_keeps_old_file_and_cleans_temporary(self):
        self.seed()
        before = self.path.read_bytes()
        with patch.object(space_history.os, "replace", side_effect=OSError("replacement failed")):
            with self.assertRaises(OSError):
                observe(self.path, 3, 3)
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(list(self.path.parent.glob(f".{self.path.name}.*")), [])

    def test_invalid_history_types_are_treated_as_empty(self):
        for value in (None, [], {"current": True}, {"current": 0}, {"current": 4, "at": "bad"}):
            self.path.write_text(json.dumps(value))
            self.assertEqual(read_state(self.path), {})

    def test_invalid_observation_timestamp_does_not_write(self):
        for stamp in (None, True, "1", 1.5):
            with self.subTest(stamp=stamp), self.assertRaises(ValueError):
                observe(self.path, 4, stamp)
        self.assertFalse(self.path.exists())


if __name__ == "__main__":
    unittest.main()
