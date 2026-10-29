"""Native Rime command regressions using disposable command stubs only.

Run: python3 -B -m unittest discover -s tests -v
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

LIBRARY = Path(__file__).resolve().parents[1] / "home/dot_local/xbin"
COMMON = LIBRARY / "common_functions.sh"
TEMPLATE = LIBRARY / "executable_rime_sync.tmpl"

# These tools only write fixture files. They never start or stop real processes.
STUB = r"""#!/bin/bash
name="$(basename "$0")"
printf '%s %s\n' "$name" "$*" >> "$MOCK_CALLS"

ready() {
    local count=0
    if [ -f "$MOCK_ROOT/ready-count" ]; then
        read -r count < "$MOCK_ROOT/ready-count"
    fi
    count=$((count + 1))
    printf '%s\n' "$count" > "$MOCK_ROOT/ready-count"
    [ "$MOCK_READY_NEVER" = 1 ] && return 1
    [ "$count" -ge "$MOCK_READY_AFTER" ]
}

case "$name" in
    pgrep)
        if [ -f "$MOCK_ROOT/restart-requested" ]; then
            ready || exit 1
        elif [ "$MOCK_RUNNING" != 1 ]; then
            exit 1
        fi
        printf '99999999\n'
        ;;
    Squirrel)
        [ "$MOCK_QUIT_FAIL" = 1 ] && exit 3
        ;;
    fcitx5-remote)
        if [ "$*" = "--check -e" ]; then
            [ "$MOCK_QUIT_FAIL" = 1 ] && exit 3
        else
            ready || exit 1
            printf '2\n'
        fi
        ;;
    rime_dict_manager)
        echo "dictionary output"
        if [ "$MOCK_DICT_FAIL" = 1 ]; then
            echo "dictionary failure" >&2
            exit 4
        fi
        ;;
    open|fcitx5)
        [ "$MOCK_RESTART_FAIL" = 1 ] && exit 5
        : > "$MOCK_ROOT/restart-requested"
        ;;
esac
exit 0
"""


class NativeRimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        chezmoi = shutil.which("chezmoi")
        if not chezmoi:
            raise unittest.SkipTest("chezmoi is required to render platform templates")
        cls.rendered = {}
        for platform in ("darwin", "linux"):
            cls.rendered[platform] = subprocess.run(
                [chezmoi, "execute-template", "--override-data",
                 '{"chezmoi":{"os":"' + platform + '"}}', "--file", str(TEMPLATE)],
                check=True, capture_output=True, text=True,
            ).stdout
            subprocess.run(["/bin/bash", "-n"], input=cls.rendered[platform],
                           check=True, text=True)

    def fixture(self, platform, **overrides):
        temporary = tempfile.TemporaryDirectory(prefix="rime-native-test-")
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name).resolve()
        tools = root / "bin"
        tools.mkdir()
        app = root / "Input Methods/Squirrel.app"
        app_binary = app / "Contents/MacOS"
        app_binary.mkdir(parents=True)
        user = root / "Rime user directory"
        user.mkdir()
        shutil.copy(COMMON, root / "common_functions.sh")
        for name in ("pgrep", "sleep", "open", "fcitx5", "fcitx5-remote"):
            executable = tools / name
            executable.write_text(STUB, encoding="utf-8")
            executable.chmod(0o755)
        for name in ("Squirrel", "rime_dict_manager"):
            executable = (app_binary if platform == "darwin" else tools) / name
            executable.write_text(STUB, encoding="utf-8")
            executable.chmod(0o755)
        script = root / "rime_sync"
        script.write_text(self.rendered[platform].replace(
            "/Library/Input Methods/Squirrel.app", str(app)), encoding="utf-8")
        environment = dict(os.environ)
        environment.update({
            "PATH": str(tools) + ":/usr/bin:/bin",
            "RIME_USER_DIR": str(user),
            "MOCK_ROOT": str(root),
            "MOCK_CALLS": str(root / "calls"),
            "MOCK_RUNNING": "1",
            "MOCK_READY_AFTER": "1",
            "MOCK_READY_NEVER": "0",
            "MOCK_QUIT_FAIL": "0",
            "MOCK_DICT_FAIL": "0",
            "MOCK_RESTART_FAIL": "0",
            "SUPPRESS_COMPLETION_MESSAGES": "",
        })
        environment.update(overrides)
        completed = subprocess.run(
            ["/bin/bash", str(script)], env=environment, capture_output=True,
            text=True, timeout=10,
        )
        calls = (root / "calls").read_text().splitlines()
        return completed, calls, root

    def assert_failure(self, completed):
        self.assertNotEqual(completed.returncode, 0)
        output = completed.stdout + completed.stderr
        self.assertNotIn("Rime user dictionaries synced locally", output)
        self.assertNotIn("All tasks completed successfully!", output)

    def test_restart_request_success_is_not_enough_without_ready_process_or_service(self):
        for platform in ("darwin", "linux"):
            with self.subTest(platform=platform):
                completed, calls, root = self.fixture(platform, MOCK_READY_NEVER="1")
                self.assert_failure(completed)
                self.assertEqual((root / "ready-count").read_text().strip(), "50")
                self.assertIn("after the restart request", completed.stdout)
                self.assertEqual(sum(call.startswith("rime_dict_manager ") for call in calls), 1)

    def test_restart_waits_until_process_or_service_is_ready(self):
        for platform in ("darwin", "linux"):
            with self.subTest(platform=platform):
                completed, calls, root = self.fixture(platform, MOCK_READY_AFTER="3")
                self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
                self.assertEqual((root / "ready-count").read_text().strip(), "3")
                self.assertIn("Rime user dictionaries synced locally", completed.stdout)

    def test_failed_dictionary_sync_still_restores_without_reporting_success(self):
        for platform in ("darwin", "linux"):
            with self.subTest(platform=platform):
                completed, calls, root = self.fixture(platform, MOCK_DICT_FAIL="1")
                self.assert_failure(completed)
                self.assertIn("dictionary failure", completed.stderr)
                self.assertTrue((root / "restart-requested").exists())
                self.assertTrue((root / "ready-count").exists())

    def test_failed_quit_restores_without_running_dictionary_sync(self):
        for platform in ("darwin", "linux"):
            with self.subTest(platform=platform):
                completed, calls, root = self.fixture(platform, MOCK_QUIT_FAIL="1")
                self.assert_failure(completed)
                self.assertFalse(any(call.startswith("rime_dict_manager ") for call in calls))
                self.assertTrue((root / "restart-requested").exists())

    def test_restart_command_failure_is_not_retried_as_success(self):
        for platform in ("darwin", "linux"):
            with self.subTest(platform=platform):
                completed, calls, root = self.fixture(platform, MOCK_RESTART_FAIL="1")
                self.assert_failure(completed)
                self.assertFalse((root / "ready-count").exists())
                starter = "open " if platform == "darwin" else "fcitx5 "
                self.assertEqual(sum(call.startswith(starter) for call in calls), 1)

    def test_initially_stopped_input_method_stays_stopped(self):
        for platform in ("darwin", "linux"):
            with self.subTest(platform=platform):
                completed, calls, root = self.fixture(platform, MOCK_RUNNING="0")
                self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
                self.assertFalse((root / "restart-requested").exists())
                self.assertFalse((root / "ready-count").exists())
                self.assertEqual(sum(call.startswith("rime_dict_manager ") for call in calls), 1)


class CommandWaitTests(unittest.TestCase):
    def bash(self, commands):
        return subprocess.run(
            ["/bin/bash", "-c", 'source "$1"; ' + commands, "wait-test", str(COMMON)],
            capture_output=True, text=True, timeout=10,
        )

    def test_wait_returns_after_first_success(self):
        completed = self.bash(
            'count=0; probe() { count=$((count + 1)); [ "$count" -ge 3 ]; }; '
            'wait_for_command 5 0 probe && [ "$count" -eq 3 ]'
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

    def test_wait_stops_at_attempt_limit(self):
        completed = self.bash(
            'count=0; probe() { count=$((count + 1)); return 1; }; '
            'if wait_for_command 4 0 probe; then exit 1; fi; [ "$count" -eq 4 ]'
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

    def test_invalid_wait_parameters_fail(self):
        completed = self.bash('if wait_for_command 0 0 true; then exit 1; fi')
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)


if __name__ == "__main__":
    unittest.main()
