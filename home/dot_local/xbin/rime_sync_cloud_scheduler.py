"""User-level cron and launchd scheduling for rime_sync_cloud.

This module only manages its own label or marked crontab block. Configuration,
daily success checks, and desktop-session environment belong to the runner.
"""

import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import plistlib
from typing import Optional

LABEL = "io.github.knothhe.rime-sync-cloud"
CRON_BEGIN = "# BEGIN rime_sync_cloud"
CRON_END = "# END rime_sync_cloud"


def _check_platform(platform: str) -> None:
    if platform not in ("darwin", "linux"):
        raise ValueError("Only darwin and linux scheduling are supported.")


def _run(arguments, **kwargs):
    try:
        return subprocess.run(
            arguments, capture_output=True, text=True, check=False, **kwargs
        )
    except OSError as error:
        raise RuntimeError("Cannot run {}: {}".format(arguments[0], error)) from error


def _failure(action: str, result) -> RuntimeError:
    detail = (result.stderr or result.stdout or "").strip()
    return RuntimeError(
        "{} failed (exit {}): {}".format(action, result.returncode, detail)
    )


def _read_crontab() -> str:
    result = _run(["crontab", "-l"])
    if result.returncode == 0:
        return result.stdout
    message = (result.stderr or result.stdout or "").strip()
    if result.returncode == 1 and re.fullmatch(
        r"(?:crontab:\s*)?no crontab for [^\r\n]+", message, flags=re.IGNORECASE
    ):
        return ""
    raise _failure("Reading the current crontab", result)


def _without_managed_block(content: str) -> str:
    remaining = []
    inside = False
    for line in content.splitlines(keepends=True):
        marker = line.rstrip("\r\n")
        if marker == CRON_BEGIN:
            if inside:
                raise RuntimeError("Nested rime_sync_cloud markers in crontab.")
            inside = True
        elif marker == CRON_END:
            if not inside:
                raise RuntimeError("Unmatched rime_sync_cloud end marker in crontab.")
            inside = False
        elif not inside:
            remaining.append(line)
    if inside:
        raise RuntimeError("Unmatched rime_sync_cloud begin marker in crontab.")
    return "".join(remaining)


def _write_crontab(content: str) -> None:
    result = _run(["crontab", "-"], input=content)
    if result.returncode:
        raise _failure("Installing the crontab", result)


def _plist_path() -> Path:
    return Path.home() / "Library/LaunchAgents" / (LABEL + ".plist")


def _service_target() -> str:
    return "gui/{}/{}".format(os.getuid(), LABEL)


def _launchd_loaded() -> bool:
    result = _run(["launchctl", "print", _service_target()])
    if result.returncode == 0:
        return True
    if "could not find service" in (result.stderr + result.stdout).lower():
        return False
    raise _failure("Checking the launchd service", result)


def _bootout_if_loaded() -> bool:
    loaded = _launchd_loaded()
    if loaded:
        result = _run(["launchctl", "bootout", _service_target()])
        if result.returncode:
            raise _failure("Unloading the launchd service", result)
    return loaded


def _atomic_write(path: Path, data: bytes) -> None:
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=str(path.parent), delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        temporary.chmod(0o644)
        os.replace(str(temporary), str(path))
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def _checked_path(path: Path) -> Path:
    value = Path(path).expanduser().absolute()
    if any(character in str(value) for character in ("\n", "\r", "\x00")):
        raise ValueError("Scheduler paths cannot contain newlines or NUL bytes.")
    return value


def install(
    platform: str,
    runner: Path,
    config_path: Path,
    log_path: Path,
    hour: int,
    minute: int,
    path_env: str,
) -> Optional[Path]:
    """Install hourly catch-up attempts; the runner enforces the daily time."""
    _check_platform(platform)
    if not 0 <= hour <= 23 or not 0 <= minute <= 59:
        raise ValueError("The daily time must be between 00:00 and 23:59.")
    if any(character in path_env for character in ("\n", "\r", "\x00")):
        raise ValueError("PATH cannot contain newlines or NUL bytes.")
    runner = _checked_path(runner)
    config_path = _checked_path(config_path)
    log_path = _checked_path(log_path)
    log_path.parent.mkdir(parents=True, exist_ok=True)

    arguments = [
        str(runner), "run", "--scheduled", "--config", str(config_path)
    ]
    if platform == "linux":
        previous = _read_crontab()
        remaining = _without_managed_block(previous)
        if remaining and not remaining.endswith("\n"):
            remaining += "\n"
        # cron interprets percent signs before passing the command to the shell,
        # even inside shell quotes. Escape them after shell-quoting each value.
        command = "{} >> {} 2>&1".format(
            " ".join(shlex.quote(item) for item in [
                "/usr/bin/env", "PATH=" + path_env
            ] + arguments),
            shlex.quote(str(log_path)),
        ).replace("%", r"\%")
        replacement = "{}\n{} * * * * {}\n{}\n".format(
            CRON_BEGIN, minute, command, CRON_END
        )
        _write_crontab(remaining + replacement)
        return None

    target = _plist_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    specification = {
        "Label": LABEL,
        "ProgramArguments": arguments,
        "StartCalendarInterval": [
            {"Hour": current_hour, "Minute": minute} for current_hour in range(24)
        ],
        "RunAtLoad": True,
        "LowPriorityIO": True,
        "Nice": 10,
        "ProcessType": "Background",
        "EnvironmentVariables": {"PATH": path_env},
        "StandardOutPath": str(log_path),
        "StandardErrorPath": str(log_path),
    }
    previous_data = target.read_bytes() if target.exists() else None
    was_loaded = _bootout_if_loaded()
    try:
        _atomic_write(target, plistlib.dumps(specification))
        result = _run([
            "launchctl", "bootstrap", "gui/{}".format(os.getuid()), str(target)
        ])
        if result.returncode:
            raise _failure("Loading the launchd service", result)
    except (OSError, RuntimeError) as error:
        # Restore an existing task when replacement fails. Never claim that the
        # new schedule is active after a failed bootstrap.
        rollback_errors = []
        try:
            if previous_data is None:
                if target.exists():
                    target.unlink()
            else:
                _atomic_write(target, previous_data)
                if was_loaded:
                    result = _run([
                        "launchctl", "bootstrap",
                        "gui/{}".format(os.getuid()), str(target)
                    ])
                    if result.returncode:
                        rollback_errors.append(str(_failure(
                            "Restoring the previous launchd service", result
                        )))
        except (OSError, RuntimeError) as rollback_error:
            rollback_errors.append(str(rollback_error))
        if rollback_errors:
            raise RuntimeError(
                "{}; rollback: {}".format(error, "; ".join(rollback_errors))
            ) from error
        raise
    return target


def remove(platform: str) -> None:
    """Remove only this script's task, leaving configuration and logs intact."""
    _check_platform(platform)
    if platform == "linux":
        previous = _read_crontab()
        remaining = _without_managed_block(previous)
        if remaining != previous:
            _write_crontab(remaining)
        return
    _bootout_if_loaded()
    target = _plist_path()
    if target.exists():
        target.unlink()


def status(platform: str) -> str:
    """Describe whether this script's scheduler entry is installed."""
    _check_platform(platform)
    if platform == "linux":
        content = _read_crontab()
        remaining = _without_managed_block(content)
        if remaining == content:
            return "cron: not installed"
        lines = content.splitlines()
        start = lines.index(CRON_BEGIN)
        finish = lines.index(CRON_END, start + 1)
        return "cron: installed\n" + "\n".join(lines[start + 1:finish])
    loaded = _launchd_loaded()
    target = _plist_path()
    if loaded:
        return "launchd: loaded ({})\n{}".format(LABEL, target)
    if target.exists():
        return "launchd: configured but not loaded\n{}".format(target)
    return "launchd: not installed"
