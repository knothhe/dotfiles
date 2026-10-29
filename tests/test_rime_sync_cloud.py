"""Regression tests for Rime cloud sync without external commands or services.

Run: python3 -B -m unittest discover -s tests -v
"""

import ast
import contextlib
import datetime
import fcntl
import io
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import types
import unittest
from unittest import mock

LIBRARY = Path(__file__).resolve().parents[1] / "home/dot_local/xbin"
sys.path.insert(0, str(LIBRARY))
import rime_sync_cloud as cloud
import rime_sync_cloud_scheduler as scheduler


NOW = datetime.datetime(2026, 10, 29, 12, 30).astimezone()


class FrozenDatetime:
    @staticmethod
    def now():
        return NOW


def result(code=0, stdout="", stderr=""):
    return subprocess.CompletedProcess([], code, stdout, stderr)


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="rime-cloud-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.user = self.root / "Rime user directory"
        self.sync = self.root / "shared snapshots"
        self.state = self.root / "local state"
        self.user.mkdir()
        self.sync.mkdir()
        self.rclone_config = self.root / "rclone.conf"
        self.rclone_config.write_text("[app-sync]\ntype = s3\n", encoding="utf-8")
        self.settings = {
            "version": 1,
            "platform": "linux",
            "rime_user_dir": str(self.user),
            "sync_dir": str(self.sync),
            "installation_id": "lara",
            "remote": "app-sync:app-sync/rime",
            "daily_time": "03:00",
            "rclone": str(self.root / "bin/rclone"),
            "rclone_config": str(self.rclone_config),
            "rime_sync": str(self.root / "bin/rime_sync"),
            "state_dir": str(self.state),
            "environment": {"PATH": "/usr/bin:/bin"},
        }
        self.write_installation()
        self.patch("platform_name", return_value="linux")
        self.patch("ensure_directory", side_effect=lambda path: Path(path).mkdir(parents=True, exist_ok=True))
        self.patch("require_dependencies")
        self.patch("message")
        self.patch("dt", types.SimpleNamespace(datetime=FrozenDatetime))
        self.external = self.patch("subprocess.run", side_effect=AssertionError("Real subprocess forbidden"))
        self.commands = self.patch("command", return_value="")

    def patch(self, name, *args, **kwargs):
        target = cloud
        components = name.split(".")
        for component in components[:-1]:
            target = getattr(target, component)
        patcher = mock.patch.object(target, components[-1], *args, **kwargs)
        value = patcher.start()
        self.addCleanup(patcher.stop)
        return value

    def write_installation(self, directory=None, installation_id="lara"):
        directory = self.sync if directory is None else directory
        (self.user / "installation.yaml").write_text(
            "installation_id: " + json.dumps(installation_id) + "\n"
            "sync_dir: " + json.dumps(str(directory)) + "\n",
            encoding="utf-8",
        )

    def pair(self):
        return cloud.state_paths(self.settings)[1]

    def initialized(self):
        pair = self.pair()
        pair.mkdir(parents=True, exist_ok=True)
        (pair / "initialized.json").write_text('{"created_at": "earlier"}\n', encoding="utf-8")

    def actions(self):
        return [call.args[0] for call in self.commands.call_args_list]

    def assert_no_daily_success(self):
        self.assertFalse((self.pair() / "daily.json").exists())

    def test_normal_workflow_is_rime_bisync_rime(self):
        self.initialized()
        self.assertTrue(cloud.run_workflow(self.settings))
        actions = self.actions()
        self.assertEqual(actions[0], [self.settings["rime_sync"]])
        self.assertEqual(actions[1][:4], [
            self.settings["rclone"], "bisync", str(self.sync), self.settings["remote"]])
        self.assertEqual(actions[2], [self.settings["rime_sync"]])
        self.assertEqual(len(actions), 3)
        self.assertNotIn("--resync", actions[1])
        self.assertEqual(actions[1][actions[1].index("--exclude") + 1], ".DS_Store")
        self.assertIn("--recover", actions[1])
        self.assertEqual(cloud.read_json(self.pair() / "daily.json")["date"], NOW.date().isoformat())
        environment = self.commands.call_args_list[0].args[1]
        self.assertEqual(environment["RIME_USER_DIR"], str(self.user))
        self.external.assert_not_called()

    def test_missing_baseline_never_triggers_automatic_resync(self):
        with self.assertRaisesRegex(cloud.SyncError, "resync"):
            cloud.run_workflow(self.settings)
        self.commands.assert_not_called()
        self.assert_no_daily_success()

    def test_explicit_initial_resync_is_used_once(self):
        self.assertTrue(cloud.run_workflow(self.settings, resync=True))
        first = self.actions()
        self.assertEqual(len(first), 3)
        self.assertEqual(first[1].count("--resync"), 1)
        self.assertEqual(first[1][first[1].index("--resync-mode") + 1], "newer")
        self.assertTrue((self.pair() / "initialized.json").exists())
        self.commands.reset_mock()
        self.assertTrue(cloud.run_workflow(self.settings))
        self.assertNotIn("--resync", self.actions()[1])

    def test_bisync_failure_does_not_create_baseline_or_daily_success(self):
        self.commands.side_effect = ["", cloud.SyncError("bisync failure")]
        with self.assertRaisesRegex(cloud.SyncError, "bisync failure"):
            cloud.run_workflow(self.settings, resync=True)
        self.assertEqual(self.commands.call_count, 2)
        self.assertFalse((self.pair() / "initialized.json").exists())
        self.assert_no_daily_success()
        self.assertFalse(cloud.read_json(self.pair() / "last-run.json")["success"])

    def test_final_merge_failure_retains_baseline_and_can_retry_without_resync(self):
        self.commands.side_effect = ["", "", cloud.SyncError("final merge failure")]
        with self.assertRaisesRegex(cloud.SyncError, "final merge failure"):
            cloud.run_workflow(self.settings, resync=True)
        self.assertTrue((self.pair() / "initialized.json").exists())
        self.assert_no_daily_success()
        self.assertFalse(cloud.read_json(self.pair() / "last-run.json")["success"])
        self.commands.reset_mock()
        self.commands.side_effect = None
        self.commands.return_value = ""
        self.assertTrue(cloud.run_workflow(self.settings))
        self.assertNotIn("--resync", self.actions()[1])

    def test_first_merge_failure_never_runs_bisync(self):
        self.initialized()
        self.commands.side_effect = cloud.SyncError("first merge failure")
        with self.assertRaisesRegex(cloud.SyncError, "first merge failure"):
            cloud.run_workflow(self.settings)
        self.assertEqual(self.commands.call_count, 1)
        self.assert_no_daily_success()

    def test_scheduled_run_skips_before_daily_time(self):
        self.settings["daily_time"] = "23:59"
        self.assertFalse(cloud.run_workflow(self.settings, scheduled=True))
        self.commands.assert_not_called()

    def test_scheduled_run_skips_after_today_succeeded(self):
        self.initialized()
        (self.pair() / "daily.json").write_text(
            json.dumps({"date": NOW.date().isoformat()}), encoding="utf-8")
        self.assertFalse(cloud.run_workflow(self.settings, scheduled=True))
        self.commands.assert_not_called()

    def test_scheduled_run_retries_after_previous_day(self):
        self.initialized()
        (self.pair() / "daily.json").write_text('{"date": "2026-10-28"}', encoding="utf-8")
        self.assertTrue(cloud.run_workflow(self.settings, scheduled=True))
        self.assertEqual(self.commands.call_count, 3)

    def test_workflow_lock_prevents_overlapping_cloud_and_local_operations(self):
        self.initialized()
        with (self.state / "workflow.lock").open("a") as lock:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertFalse(cloud.run_workflow(self.settings))
        self.commands.assert_not_called()

    def test_installation_directory_mismatch_fails_before_any_sync(self):
        self.initialized()
        self.write_installation(directory=self.root / "different")
        with self.assertRaisesRegex(cloud.SyncError, "sync_dir"):
            cloud.run_workflow(self.settings)
        self.commands.assert_not_called()
        self.assert_no_daily_success()

    def test_installation_id_mismatch_fails_before_any_sync(self):
        self.initialized()
        self.write_installation(installation_id="other-machine")
        with self.assertRaisesRegex(cloud.SyncError, "installation_id"):
            cloud.run_workflow(self.settings)
        self.commands.assert_not_called()
        self.assert_no_daily_success()

    def test_remote_shell_text_is_passed_as_one_literal_argument(self):
        marker = self.root / "must-not-exist"
        remote = "app-sync:app-sync/rime; touch " + str(marker) + " $(false)"
        self.settings["remote"] = remote
        self.initialized()
        self.assertTrue(cloud.run_workflow(self.settings))
        self.assertEqual(self.actions()[1][3], remote)
        self.assertFalse(marker.exists())
        self.external.assert_not_called()

    def test_json_shell_text_is_data_and_environment_injection_is_rejected(self):
        marker = self.root / "must-not-exist"
        path = self.root / "data.json"
        path.write_text(json.dumps({"text": "$(touch " + str(marker) + ")"}), encoding="utf-8")
        self.assertEqual(cloud.read_json(path)["text"], "$(touch " + str(marker) + ")")
        self.assertFalse(marker.exists())
        self.settings["environment"]["BASH_ENV"] = str(path)
        with self.assertRaisesRegex(cloud.SyncError, "环境"):
            cloud.validate_settings(self.settings)
        self.external.assert_not_called()

    def test_workflow_environment_drops_shell_only_credentials_and_keeps_desktop_paths(self):
        self.settings["environment"].update({
            "XAUTHORITY": str(self.root / "desktop/xauthority"),
            "XDG_CONFIG_HOME": str(self.root / "desktop/config"),
            "XDG_DATA_HOME": str(self.root / "desktop/data"),
            "XDG_CACHE_HOME": str(self.root / "desktop/cache"),
            "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus",
        })
        shell_environment = {
            "HOME": str(self.root / "home"), "USER": "tester", "LANG": "en_US.UTF-8",
            "LC_MESSAGES": "C", "PATH": "/interactive/bin", "RCLONE_CONFIG_PASS": "test secret",
            "RCLONE_PASSWORD_COMMAND": "private-helper", "RCLONE_CONFIG_APP_SYNC_SECRET_ACCESS_KEY": "key",
            "AWS_ACCESS_KEY_ID": "id", "AWS_SECRET_ACCESS_KEY": "secret", "BASH_ENV": "startup-code",
        }
        with mock.patch.dict(cloud.os.environ, shell_environment, clear=True):
            cloud.validate_settings(self.settings)
            environment = cloud.environment_for(self.settings)
        self.assertEqual(environment["HOME"], shell_environment["HOME"])
        self.assertEqual(environment["LC_MESSAGES"], "C")
        self.assertEqual(environment["PATH"], self.settings["environment"]["PATH"])
        self.assertEqual(environment["XAUTHORITY"], self.settings["environment"]["XAUTHORITY"])
        self.assertEqual(environment["XDG_DATA_HOME"], self.settings["environment"]["XDG_DATA_HOME"])
        self.assertEqual(environment["RIME_USER_DIR"], str(self.user))
        self.assertFalse(any(key.startswith(("RCLONE_", "AWS_")) for key in environment))
        self.assertNotIn("BASH_ENV", environment)

    def test_background_rclone_preflight_is_noninteractive_and_uses_filtered_environment(self):
        self.commands.return_value = "app-sync:\n"
        with mock.patch.dict(cloud.os.environ, {"RCLONE_CONFIG_PASS": "test secret"}):
            cloud.verify_background_rclone(self.settings)
        arguments, environment, _ = self.commands.call_args.args
        self.assertIn("--ask-password=false", arguments)
        self.assertEqual(arguments[arguments.index("--config") + 1], str(self.rclone_config))
        self.assertNotIn("RCLONE_CONFIG_PASS", environment)

    def test_background_rclone_preflight_rejects_shell_only_remotes(self):
        self.commands.return_value = "other-remote:\n"
        with self.assertRaisesRegex(cloud.SyncError, "定时环境中未找到"):
            cloud.verify_background_rclone(self.settings)

    def test_invalid_json_and_non_object_settings_fail_without_execution(self):
        path = self.root / "config.json"
        path.write_text("__import__('os').system('false')", encoding="utf-8")
        with self.assertRaises(cloud.SyncError):
            cloud.read_json(path)
        with self.assertRaises(cloud.SyncError):
            cloud.validate_settings([])
        self.external.assert_not_called()

    def test_installation_yaml_scalars_are_not_executed(self):
        marker = self.root / "must-not-exist"
        raw = "$(touch " + str(marker) + ")"
        self.write_installation(directory=raw)
        _, _, values = cloud.installation_values(self.user)
        self.assertEqual(values["sync_dir"], raw)
        self.assertFalse(marker.exists())
        self.external.assert_not_called()

    def test_duplicate_installation_keys_are_rejected(self):
        with (self.user / "installation.yaml").open("a", encoding="utf-8") as stream:
            stream.write("installation_id: duplicate\n")
        with self.assertRaisesRegex(cloud.SyncError, "重复"):
            cloud.installation_values(self.user)

    def test_rclone_credentials_inside_sync_tree_are_rejected(self):
        self.settings["rclone_config"] = str(self.sync / "rclone.conf")
        with self.assertRaisesRegex(cloud.SyncError, "凭据"):
            cloud.run_workflow(self.settings, resync=True)
        self.commands.assert_not_called()
        self.assert_no_daily_success()

    def test_changing_rclone_config_uses_a_different_bisync_pair(self):
        original_state, original_pair = cloud.state_paths(self.settings)
        self.settings["rclone_config"] = str(self.root / "other-account/rclone.conf")
        changed_state, changed_pair = cloud.state_paths(self.settings)
        self.assertEqual(original_state, changed_state)
        self.assertNotEqual(original_pair, changed_pair)

    def test_valid_json_non_objects_are_rejected(self):
        path = self.root / "non-object.json"
        for value in ([], None, True, 123, "text"):
            with self.subTest(value=value):
                path.write_text(json.dumps(value), encoding="utf-8")
                with self.assertRaises(cloud.SyncError):
                    cloud.read_json(path)
        self.external.assert_not_called()

    @contextlib.contextmanager
    def setup_stubs(self):
        def setup_command(arguments, environment, description, capture=False):
            if arguments[1:3] == ["config", "file"]:
                return str(self.rclone_config)
            if arguments[1] == "listremotes":
                return "app-sync:"
            if arguments[1:3] == ["bisync", "--help"]:
                return "--resync-mode --recover --resilient --max-lock"
            self.fail("Unexpected setup command: " + repr(arguments))

        def prompt(label, default, *validation):
            return str(self.user) if label == "Rime 用户目录" else default

        with mock.patch.dict(cloud.os.environ, {
                    "XDG_STATE_HOME": str(self.root / "state home"),
                    "PATH": "/usr/bin:/bin",
                }), \
                mock.patch.object(cloud, "RUNNER", self.root / "bin/rime_sync_cloud"), \
                mock.patch.object(cloud.shutil, "which", return_value=str(self.root / "bin/rclone")), \
                mock.patch.object(cloud, "prompt", side_effect=prompt), \
                mock.patch.object(cloud, "confirm", return_value=True), \
                mock.patch.object(cloud, "command", side_effect=setup_command), \
                mock.patch.object(cloud, "run_workflow", return_value=True) as workflow, \
                mock.patch.object(scheduler, "install") as install, \
                contextlib.redirect_stdout(io.StringIO()):
            yield workflow, install

    def test_setup_rejects_task_config_in_sync_tree_without_writing(self):
        config_path = self.sync / "task-config.json"
        installation = self.user / "installation.yaml"
        previous_installation = installation.read_bytes()
        with self.setup_stubs() as (workflow, install):
            with self.assertRaisesRegex(cloud.SyncError, "任务配置"):
                cloud.setup(config_path)
        self.assertFalse(config_path.exists())
        self.assertEqual(installation.read_bytes(), previous_installation)
        workflow.assert_not_called()
        install.assert_not_called()

    def test_setup_with_held_lock_preserves_configuration_and_installation(self):
        config_path = self.root / "existing-config.json"
        config_path.write_text(json.dumps(self.settings), encoding="utf-8")
        installation = self.user / "installation.yaml"
        previous_config = config_path.read_bytes()
        previous_installation = installation.read_bytes()
        state = self.root / "state home/rime-sync-cloud"
        state.mkdir(parents=True)
        with (state / "workflow.lock").open("a") as lock:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            with self.setup_stubs() as (workflow, install):
                with self.assertRaisesRegex(cloud.SyncError, "正在运行"):
                    cloud.setup(config_path)
        self.assertEqual(config_path.read_bytes(), previous_config)
        self.assertEqual(installation.read_bytes(), previous_installation)
        workflow.assert_not_called()
        install.assert_not_called()

    def test_setup_rejects_shell_only_decryption_before_writing_or_installing(self):
        config_path = self.root / "settings/config.json"
        installation = self.user / "installation.yaml"
        previous_installation = installation.read_bytes()
        with self.setup_stubs() as (workflow, install), \
                mock.patch.dict(cloud.os.environ, {"RCLONE_CONFIG_PASS": "test fixture password"}):
            setup_command = cloud.command.side_effect

            def reject_background(arguments, environment, description, capture=False):
                if arguments[1] == "listremotes" and "RCLONE_CONFIG_PASS" not in environment:
                    raise cloud.SyncError("unable to decrypt configuration")
                return setup_command(arguments, environment, description, capture)

            cloud.command.side_effect = reject_background
            with self.assertRaisesRegex(cloud.SyncError, "不能依赖交互 shell"):
                cloud.setup(config_path)
        self.assertFalse(config_path.exists())
        self.assertEqual(installation.read_bytes(), previous_installation)
        workflow.assert_not_called()
        install.assert_not_called()

    def test_setup_uses_installation_values_and_friendly_defaults(self):
        home = self.root / "home"
        default_user = home / ".local/share/fcitx5/rime"
        default_user.mkdir(parents=True)
        (default_user / "installation.yaml").write_text(
            "installation_id: lara\nsync_dir: " + json.dumps(str(self.sync)) + "\n",
            encoding="utf-8",
        )
        config_path = self.root / "settings/config.json"
        prompts = []

        def prompt(label, default, *validation):
            prompts.append((label, default))
            return default

        def setup_command(arguments, environment, description, capture=False):
            if arguments[1:3] == ["config", "file"]:
                return "Configuration file is stored at:\n" + str(self.rclone_config)
            if arguments[1] == "listremotes":
                return "app-sync:"
            if arguments[1:3] == ["bisync", "--help"]:
                return "--resync-mode --recover --resilient --max-lock"
            self.fail("Unexpected setup command: " + repr(arguments))

        with mock.patch.object(cloud.Path, "home", return_value=home), \
                mock.patch.dict(cloud.os.environ, {
                    "XDG_DATA_HOME": str(home / ".local/share"),
                    "XDG_CONFIG_HOME": str(home / ".config"),
                    "XDG_CACHE_HOME": str(home / ".cache"),
                    "XAUTHORITY": str(home / "desktop/xauthority"),
                    "XDG_STATE_HOME": str(home / ".local/state"),
                    "PATH": "/usr/bin:/bin",
                    "RCLONE_CONFIG_PASS": "test fixture password",
                }), \
                mock.patch.object(cloud, "RUNNER", self.root / "bin/rime_sync_cloud"), \
                mock.patch.object(cloud.shutil, "which", return_value=str(self.root / "bin/rclone")), \
                mock.patch.object(cloud, "prompt", side_effect=prompt), \
                mock.patch.object(cloud, "confirm", return_value=True), \
                mock.patch.object(cloud, "command", side_effect=setup_command), \
                mock.patch.object(cloud, "run_workflow", return_value=True) as workflow, \
                mock.patch.object(scheduler, "install") as install, \
                contextlib.redirect_stdout(io.StringIO()):
            cloud.setup(config_path)
        settings = cloud.read_json(config_path)
        self.assertEqual(settings["rime_user_dir"], str(default_user))
        self.assertEqual(settings["sync_dir"], str(self.sync))
        self.assertEqual(settings["installation_id"], "lara")
        self.assertEqual(settings["remote"], cloud.DEFAULT_REMOTE)
        self.assertEqual(settings["daily_time"], "03:00")
        self.assertEqual(settings["environment"]["XAUTHORITY"], str(home / "desktop/xauthority"))
        self.assertEqual(settings["environment"]["XDG_CONFIG_HOME"], str(home / ".config"))
        self.assertEqual(settings["environment"]["XDG_DATA_HOME"], str(home / ".local/share"))
        self.assertEqual(settings["environment"]["XDG_CACHE_HOME"], str(home / ".cache"))
        self.assertNotIn("RCLONE_CONFIG_PASS", settings["environment"])
        self.assertEqual(prompts[0][1], str(default_user))
        workflow.assert_called_once_with(settings, resync=True, lock_held=True)
        self.assertEqual(install.call_args.args[0], "linux")
        self.assertEqual(install.call_args.args[4:6], (3, 0))
        self.external.assert_not_called()


class SchedulerTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="rime-scheduler-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.runner = self.root / "bin with spaces/rime_sync_cloud"
        self.config = self.root / "config.json"
        self.log = self.root / "logs/sync.log"
        patcher = mock.patch.object(scheduler, "_run")
        self.run = patcher.start()
        self.addCleanup(patcher.stop)
        external = mock.patch.object(
            scheduler.subprocess, "run", side_effect=AssertionError("Real subprocess forbidden"))
        self.external = external.start()
        self.addCleanup(external.stop)
        self.plist = self.root / "LaunchAgents/task.plist"
        path_patch = mock.patch.object(scheduler, "_plist_path", return_value=self.plist)
        path_patch.start()
        self.addCleanup(path_patch.stop)

    def install(self, platform="linux", runner=None, config=None, log=None):
        return scheduler.install(
            platform, runner or self.runner, config or self.config,
            log or self.log, 3, 17, "/custom bin:/usr/bin:/bin")

    def test_cron_replacement_preserves_unrelated_entries(self):
        outside = "MAILTO=me@example.test\n5 4 * * * /usr/local/bin/backup\n"
        previous = (outside + scheduler.CRON_BEGIN + "\n0 * * * * old-command\n" +
                    scheduler.CRON_END + "\n")
        self.run.side_effect = [result(stdout=previous), result()]
        self.install()
        content = self.run.call_args_list[1].kwargs["input"]
        self.assertTrue(content.startswith(outside))
        self.assertNotIn("old-command", content)
        self.assertEqual(content.count(scheduler.CRON_BEGIN), 1)
        self.assertIn("\n17 * * * * ", content)
        self.assertIn("run --scheduled --config", content)
        self.assertEqual(self.run.call_args_list[1].args[0], ["crontab", "-"])
        self.external.assert_not_called()

    def test_cron_permission_error_does_not_overwrite_existing_jobs(self):
        self.run.return_value = result(1, stderr="crontab: permission denied")
        with self.assertRaisesRegex(RuntimeError, "Reading"):
            self.install()
        self.run.assert_called_once_with(["crontab", "-l"])

    def test_empty_crontab_error_is_not_treated_as_no_crontab(self):
        self.run.return_value = result(1)
        with self.assertRaises(RuntimeError):
            self.install()
        self.assertEqual(self.run.call_count, 1)

    def test_no_crontab_message_allows_first_installation(self):
        self.run.side_effect = [result(1, stderr="crontab: no crontab for tester\n"), result()]
        self.install()
        self.assertEqual(self.run.call_count, 2)

    def test_cron_percent_characters_are_escaped_after_shell_quoting(self):
        self.run.side_effect = [result(), result()]
        self.install(runner=self.root / "50% tools/runner",
                     config=self.root / "config%name.json", log=self.root / "log%name")
        content = self.run.call_args_list[1].kwargs["input"]
        self.assertIn(r"50\% tools/runner", content)
        self.assertIn(r"config\%name.json", content)
        self.assertIn(r"log\%name", content)
        self.assertNotRegex(content, r"(?<!\\)%")

    def test_unmatched_cron_markers_fail_without_writing(self):
        self.run.return_value = result(stdout=scheduler.CRON_BEGIN + "\nold\n")
        with self.assertRaisesRegex(RuntimeError, "Unmatched"):
            self.install()
        self.assertEqual(self.run.call_count, 1)

    def test_remove_cron_only_removes_its_managed_block(self):
        outside = "0 1 * * * backup\n"
        previous = outside + scheduler.CRON_BEGIN + "\nmanaged\n" + scheduler.CRON_END + "\n"
        self.run.side_effect = [result(stdout=previous), result()]
        scheduler.remove("linux")
        self.assertEqual(self.run.call_args_list[1].kwargs["input"], outside)

    def test_launchd_success_has_literal_arguments_and_catchup_schedule(self):
        self.run.side_effect = [
            result(113, stderr="Could not find service"), result()]
        runner = self.root / "$(false) runner"
        self.assertEqual(self.install(platform="darwin", runner=runner), self.plist)
        specification = plistlib.loads(self.plist.read_bytes())
        self.assertEqual(specification["ProgramArguments"], [
            str(runner), "run", "--scheduled", "--config", str(self.config)])
        self.assertEqual(len(specification["StartCalendarInterval"]), 24)
        self.assertEqual(specification["StartCalendarInterval"][3], {"Hour": 3, "Minute": 17})
        self.assertTrue(specification["RunAtLoad"])
        self.assertEqual(specification["StandardOutPath"], str(self.log))
        self.external.assert_not_called()

    def test_launchd_bootstrap_failure_restores_previous_plist_and_service(self):
        self.plist.parent.mkdir()
        previous = plistlib.dumps({"Label": scheduler.LABEL, "ProgramArguments": ["old-runner"]})
        self.plist.write_bytes(previous)
        self.run.side_effect = [
            result(), result(), result(5, stderr="bootstrap failed"), result()]
        with self.assertRaisesRegex(RuntimeError, "Loading"):
            self.install(platform="darwin")
        self.assertEqual(self.plist.read_bytes(), previous)
        calls = [call.args[0][1] for call in self.run.call_args_list]
        self.assertEqual(calls, ["print", "bootout", "bootstrap", "bootstrap"])

    def test_launchd_first_install_bootstrap_failure_removes_new_plist(self):
        self.run.side_effect = [
            result(113, stderr="Could not find service"), result(5, stderr="bootstrap failed")]
        with self.assertRaisesRegex(RuntimeError, "Loading"):
            self.install(platform="darwin")
        self.assertFalse(self.plist.exists())

    def test_launchd_permission_error_leaves_existing_plist_untouched(self):
        self.plist.parent.mkdir()
        self.plist.write_bytes(b"existing task")
        self.run.return_value = result(1, stderr="Operation not permitted")
        with self.assertRaisesRegex(RuntimeError, "Checking"):
            self.install(platform="darwin")
        self.assertEqual(self.plist.read_bytes(), b"existing task")
        self.assertEqual(self.run.call_count, 1)


class CompatibilityTests(unittest.TestCase):
    def test_modules_parse_as_python_39(self):
        for path in (
            LIBRARY / "rime_sync_cloud.py",
            LIBRARY / "rime_sync_cloud_scheduler.py",
            Path(__file__),
        ):
            with self.subTest(path=path.name):
                ast.parse(path.read_text(encoding="utf-8"), filename=str(path),
                          feature_version=(3, 9))


if __name__ == "__main__":
    unittest.main()
