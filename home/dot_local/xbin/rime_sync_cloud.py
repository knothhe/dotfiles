"""Configuration and workflow for rime_sync_cloud; launched by its Bash wrapper."""

import argparse
import contextlib
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

import rime_sync_cloud_scheduler as scheduler

COMMON = Path(__file__).with_name("common_functions.sh")
RUNNER = Path(__file__).with_name("rime_sync_cloud")
SESSION_KEYS = (
    "DBUS_SESSION_BUS_ADDRESS", "XDG_RUNTIME_DIR", "DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY",
    "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME",
)
BASE_ENVIRONMENT_KEYS = ("HOME", "USER", "LOGNAME", "SHELL", "PATH", "TMPDIR", "LANG", "LANGUAGE", "TZ")
DEFAULT_REMOTE = "app-sync:app-sync/rime"
EXCLUDES = [".DS_Store"]


class SyncError(Exception):
    """A failure that should be shown without a Python traceback."""


def common(function, *arguments, capture=False, check=True):
    """Reuse the repository's Bash UI, prompts, directories and dependency checks."""
    result = subprocess.run(
        ["/bin/bash", "-c", 'set -e; source "$1"; shift; "$@"',
         "rime-sync-cloud", str(COMMON), function] + [str(item) for item in arguments],
        stdout=subprocess.PIPE if capture else None, text=True,
    )
    if check and result.returncode:
        raise SyncError("操作被取消，或公共函数执行失败：" + function)
    return result


def message(function, text):
    common(function, text)


def ensure_directory(path):
    common("ensure_directory", path, capture=True)


def require_dependencies(*commands):
    if common("check_dependencies", *commands, check=False).returncode:
        raise SyncError("请先安装上面列出的依赖。")


def prompt(label, default, pattern="", error=""):
    return common("prompt_input", label, default, pattern, error, capture=True).stdout.strip()


def confirm(label):
    return common("confirm_action", label, "y", check=False).returncode == 0


def platform_name():
    if sys.platform == "darwin":
        return "darwin"
    if sys.platform.startswith("linux"):
        return "linux"
    raise SyncError("仅支持 macOS 和 Linux。")


def default_config_path():
    return Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "rime-sync-cloud/config.json"


def absolute_path(value):
    if not value or any(character in value for character in ("\n", "\r", "\0")):
        raise SyncError("路径不能为空或包含换行符。")
    return Path(value).expanduser().absolute()


def atomic_text(path, content):
    ensure_directory(path.parent)
    descriptor, temporary = tempfile.mkstemp(prefix="." + path.name + ".", dir=str(path.parent))
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def write_json(path, value):
    atomic_text(path, json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def read_json(path):
    try:
        with path.open(encoding="utf-8") as stream:
            value = json.load(stream)
        if not isinstance(value, dict):
            raise ValueError("JSON 顶层必须是对象")
        return value
    except (OSError, ValueError) as error:
        raise SyncError("无法读取配置或状态文件 " + str(path) + ": " + str(error))


def installation_values(user_directory):
    """Read the two top-level scalars in Rime's standard installation.yaml."""
    path = user_directory / "installation.yaml"
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as error:
        raise SyncError("无法读取 " + str(path) + "；请先启动并配置 Rime。\n" + str(error))
    values = {}
    for key in ("sync_dir", "installation_id"):
        matches = re.findall(r"^" + key + r":[ \t]*(.*)$", text, flags=re.MULTILINE)
        if len(matches) > 1:
            raise SyncError(str(path) + " 中有重复的 " + key)
        if not matches:
            continue
        raw = matches[0].strip()
        if not raw:
            continue
        if raw.startswith('"'):
            try:
                value, end = json.JSONDecoder().raw_decode(raw)
            except ValueError:
                raise SyncError(str(path) + " 的 " + key + " 请使用普通字符串或标准双引号字符串。")
            tail = raw[end:].strip()
            if tail and not tail.startswith("#"):
                raise SyncError("不支持的 Rime 配置格式：" + key)
        elif raw.startswith("'"):
            match = re.fullmatch(r"'((?:[^']|'')*)'[ \t]*(?:#.*)?", raw)
            if not match:
                raise SyncError("不支持的 Rime 配置格式：" + key)
            value = match.group(1).replace("''", "'")
        else:
            value = re.split(r"\s+#", raw, maxsplit=1)[0].strip()
            if value.startswith(("[", "{", "&", "*", "|", ">")):
                raise SyncError("Rime 的 " + key + " 必须是字符串。")
        if not isinstance(value, str) or not value:
            raise SyncError("无效的 Rime 配置：" + key)
        values[key] = value
    return path, text, values


def effective_sync_directory(user_directory, values):
    value = values.get("sync_dir", "sync")
    path = Path(value).expanduser()
    return (path if path.is_absolute() else user_directory / path).resolve()


def update_installation(user_directory, sync_directory, installation_id):
    path, text, _ = installation_values(user_directory)
    for key, value in (("sync_dir", str(sync_directory)), ("installation_id", installation_id)):
        line = key + ": " + json.dumps(value, ensure_ascii=False)
        if re.search(r"^" + key + ":", text, re.MULTILINE):
            text = re.sub(r"^" + key + r":.*$", lambda match: line, text, flags=re.MULTILINE)
        else:
            text = text.rstrip("\n") + "\n" + line + "\n"
    atomic_text(path, text)


def nested_in(path, parent):
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def validate_settings(settings):
    required = ("rime_user_dir", "sync_dir", "installation_id", "remote", "daily_time",
                "rclone", "rclone_config", "rime_sync", "state_dir", "platform", "environment")
    if not isinstance(settings, dict) or settings.get("version") != 1:
        raise SyncError("配置版本不支持，请重新执行 setup。")
    if any(key not in settings for key in required):
        raise SyncError("配置不完整，请重新执行 setup。")
    if settings["platform"] != platform_name():
        raise SyncError("这份配置属于其他系统，请在本机重新执行 setup。")
    for key in required:
        if key != "environment" and not isinstance(settings[key], str):
            raise SyncError("配置字段必须是字符串：" + key)
    if not re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d", settings["daily_time"]):
        raise SyncError("每天的时间应使用 HH:MM，例如 03:00。")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", settings["installation_id"]):
        raise SyncError("设备名应使用 1–64 个字母、数字、点、下划线或连字符。")
    remote = settings["remote"]
    if ":" not in remote or not remote.split(":", 1)[0] or not remote.split(":", 1)[1].strip("/"):
        raise SyncError("远程目录格式应为 remote:bucket/path，不能使用 remote 根目录。")
    if any(character in remote for character in ("\n", "\r", "\0")):
        raise SyncError("远程目录不能包含换行符。")
    for key in ("rime_user_dir", "sync_dir", "rclone", "rclone_config", "rime_sync", "state_dir"):
        path = absolute_path(settings[key])
        if not Path(settings[key]).is_absolute():
            raise SyncError("配置路径必须是绝对路径：" + key)
    sync_directory = Path(settings["sync_dir"])
    if nested_in(Path(settings["rime_user_dir"]), sync_directory):
        raise SyncError("同步目录不能等于或包含整个 Rime 用户目录。")
    if nested_in(Path(settings["state_dir"]), sync_directory):
        raise SyncError("本机状态目录必须放在同步目录之外。")
    if nested_in(Path(settings["rclone_config"]), sync_directory):
        raise SyncError("rclone 配置包含凭据，必须放在同步目录之外。")
    environment = settings["environment"]
    if not isinstance(environment, dict) or not isinstance(environment.get("PATH"), str):
        raise SyncError("配置缺少任务运行环境 PATH。")
    if any(key not in SESSION_KEYS + ("PATH",) or not isinstance(value, str)
           or "\0" in value or "\n" in value for key, value in environment.items()):
        raise SyncError("任务环境配置包含不支持的字段或内容。")


def state_paths(settings):
    identity = json.dumps([str(Path(settings["sync_dir"]).resolve()), settings["remote"],
                           str(Path(settings["rclone_config"]).resolve()), EXCLUDES])
    pair = hashlib.sha256(identity.encode()).hexdigest()[:20]
    state = Path(settings["state_dir"])
    return state, state / "bisync" / pair


def environment_for(settings):
    # Setup and scheduled runs must not depend on shell-only RCLONE_*/AWS_* secrets.
    environment = {
        key: value for key, value in os.environ.items()
        if key in BASE_ENVIRONMENT_KEYS or key.startswith("LC_")
    }
    environment.update(settings["environment"])
    environment["RIME_USER_DIR"] = settings["rime_user_dir"]
    environment["SUPPRESS_COMPLETION_MESSAGES"] = "1"
    return environment


def verify_background_rclone(settings):
    """Reject configuration that cannot be opened without interactive-shell secrets."""
    try:
        remotes = command(
            [settings["rclone"], "listremotes", "--config", settings["rclone_config"],
             "--ask-password=false"],
            environment_for(settings), "检查定时环境中的 rclone 配置", capture=True,
        ).splitlines()
    except SyncError as error:
        raise SyncError(
            "rclone 配置无法在定时任务环境下读取。不能依赖交互 shell 临时设置的 "
            "RCLONE_CONFIG_PASS 或 RCLONE_PASSWORD_COMMAND；请先配置后台可用的凭据方式，"
            "再运行 setup。脚本不会保存解密密码。"
        ) from error
    if settings["remote"].split(":", 1)[0] + ":" not in remotes:
        raise SyncError("定时环境中未找到所选 remote，请将它配置到 rclone 配置文件后重新运行 setup。")


def command(arguments, environment, description, capture=False):
    result = subprocess.run(arguments, env=environment, stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE if capture else None, text=True)
    if result.returncode:
        raise SyncError(description + "失败，退出码 " + str(result.returncode))
    return result.stdout.strip() if capture else ""


def verify_installation(settings):
    user_directory = Path(settings["rime_user_dir"])
    _, _, values = installation_values(user_directory)
    if effective_sync_directory(user_directory, values) != Path(settings["sync_dir"]).resolve():
        raise SyncError("installation.yaml 的 sync_dir 与任务配置不一致，请重新执行 setup。")
    if values.get("installation_id") != settings["installation_id"]:
        raise SyncError("installation.yaml 的 installation_id 已改变，请重新执行 setup。")


def run_workflow(settings, scheduled=False, resync=False, lock_held=False):
    validate_settings(settings)
    state, pair = state_paths(settings)
    ensure_directory(state)
    # The workflow lock covers both local dictionary operations and cloud transfer.
    lock_context = contextlib.nullcontext(None) if lock_held else (state / "workflow.lock").open("a")
    with lock_context as lock:
        if lock is not None:
            try:
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                message("print_warning", "另一个 Rime 云同步任务正在运行，本次跳过。")
                return False
        now = dt.datetime.now().astimezone()
        today = now.date().isoformat()
        daily_path = pair / "daily.json"
        if scheduled:
            if now.strftime("%H:%M") < settings["daily_time"]:
                return False
            if daily_path.exists() and read_json(daily_path).get("date") == today:
                return False
        ensure_directory(pair)
        initialized = pair / "initialized.json"
        if not initialized.exists() and not resync:
            raise SyncError("bisync 尚未初始化或本机状态已丢失，请执行 rime_sync_cloud resync；不会自动 --resync。")
        environment = environment_for(settings)
        try:
            require_dependencies(settings["rclone"], settings["rime_sync"])
            verify_installation(settings)
            if not Path(settings["rclone_config"]).is_file():
                raise SyncError("rclone 配置文件不存在，请重新执行 rclone config 和 setup。")
            message("print_title", "Rime Cloud Sync · " + now.strftime("%Y-%m-%d %H:%M:%S"))
            message("print_progress", "1/3 合并已有快照并导出本机用户词库…")
            command([settings["rime_sync"]], environment, "本机 Rime 同步")
            message("print_progress", "2/3 使用 rclone bisync 上传并拉取其他设备快照…")
            arguments = [
                settings["rclone"], "bisync", settings["sync_dir"], settings["remote"],
                "--config", settings["rclone_config"], "--ask-password=false",
                "--workdir", str(pair), "--exclude", ".DS_Store",
                "--resilient", "--recover", "--max-lock", "2m", "-v",
            ]
            if resync:
                arguments.extend(["--resync", "--resync-mode", "newer"])
            command(arguments, environment, "rclone bisync")
            # Record successful baseline creation even if the final local merge fails.
            if resync:
                write_json(initialized, {"created_at": dt.datetime.now().astimezone().isoformat()})
            message("print_progress", "3/3 合并刚拉回的其他设备用户词库…")
            command([settings["rime_sync"]], environment, "拉取后的 Rime 合并")
            completed = dt.datetime.now().astimezone()
            write_json(daily_path, {"date": completed.date().isoformat(), "completed_at": completed.isoformat()})
            write_json(pair / "last-run.json", {"success": True, "time": dt.datetime.now().astimezone().isoformat()})
            message("print_success", "本轮 Rime 用户词库同步完成。")
            return True
        except (SyncError, OSError) as error:
            write_json(pair / "last-run.json",
                       {"success": False, "time": dt.datetime.now().astimezone().isoformat(), "error": str(error)})
            raise


def setup(config_path):
    require_dependencies("rclone", str(RUNNER.with_name("rime_sync")))
    platform = platform_name()
    if platform == "darwin":
        require_dependencies("/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel",
                             "/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_dict_manager",
                             "pgrep", "open", "sleep", "launchctl")
    else:
        require_dependencies("rime_dict_manager", "fcitx5-remote", "fcitx5", "pgrep", "sleep", "crontab")
    previous = read_json(config_path) if config_path.exists() else {}
    default_user = Path.home() / "Library/Rime" if platform == "darwin" else (
        Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "fcitx5/rime")
    message("print_title", "配置 Rime 每日云同步")
    user_directory = absolute_path(prompt("Rime 用户目录", previous.get("rime_user_dir", str(default_user)))).resolve()
    _, _, installation = installation_values(user_directory)
    native_sync_directory = effective_sync_directory(user_directory, installation)
    default_sync = previous.get("sync_dir", str(native_sync_directory))
    sync_directory = absolute_path(prompt("本地同步目录（会写入 installation.yaml 的 sync_dir）", default_sync)).resolve()
    installation_id = prompt("本机设备名 installation_id（每台设备必须不同）",
                             installation.get("installation_id", os.uname().nodename.split(".")[0]),
                             "^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$", "设备名格式不正确，请重新输入。")
    rclone = str(Path(shutil.which("rclone")).absolute())
    raw_environment = dict(os.environ)
    config_output = command([rclone, "config", "file", "--ask-password=false"],
                            raw_environment, "查找 rclone 配置", capture=True)
    if not config_output:
        raise SyncError("rclone 未返回配置文件路径，请先运行 rclone config。")
    rclone_config = str(absolute_path(config_output.splitlines()[-1]))
    remotes = command([rclone, "listremotes", "--config", rclone_config, "--ask-password=false"],
                      raw_environment, "读取 rclone remotes", capture=True).splitlines()
    if not remotes:
        raise SyncError("尚未配置 rclone remote，请先运行 rclone config。")
    message("print_info", "可用 rclone remotes：" + " ".join(remotes))
    remote = prompt("远程目录", previous.get("remote", DEFAULT_REMOTE))
    if remote.split(":", 1)[0] + ":" not in remotes:
        raise SyncError("未找到指定 remote，请先运行 rclone config。")
    daily_time = prompt("每天首次尝试时间 HH:MM（失败后每小时重试）",
                        previous.get("daily_time", "03:00"),
                        "^([01][0-9]|2[0-3]):[0-5][0-9]$", "请输入有效时间，例如 03:00。")
    path_environment = os.environ.get("PATH", "/usr/local/bin:/usr/bin:/bin")
    environment = {"PATH": path_environment}
    for key in SESSION_KEYS:
        if os.environ.get(key):
            environment[key] = os.environ[key]
    if platform == "linux":
        runtime = Path("/run/user/" + str(os.getuid()))
        if "XDG_RUNTIME_DIR" not in environment and runtime.is_dir():
            environment["XDG_RUNTIME_DIR"] = str(runtime)
        if "DBUS_SESSION_BUS_ADDRESS" not in environment and (runtime / "bus").exists():
            environment["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=" + str(runtime / "bus")
    state_directory = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "rime-sync-cloud"
    settings = {
        "version": 1, "platform": platform, "rime_user_dir": str(user_directory),
        "sync_dir": str(sync_directory), "installation_id": installation_id,
        "remote": remote, "daily_time": daily_time, "rclone": rclone,
        "rclone_config": rclone_config, "rime_sync": str(RUNNER.with_name("rime_sync")),
        "state_dir": str(state_directory.absolute()), "environment": environment,
    }
    validate_settings(settings)
    if nested_in(config_path, sync_directory):
        raise SyncError("任务配置必须放在同步目录之外。")
    verify_background_rclone(settings)
    capabilities = command([rclone, "bisync", "--help"], environment_for(settings), "检查 rclone bisync", capture=True)
    if any(flag not in capabilities for flag in ("--resync-mode", "--recover", "--resilient", "--max-lock")):
        raise SyncError("当前 rclone 缺少所需 bisync 参数，请先升级 rclone。")
    message("print_info", "配置预览")
    print(json.dumps({
        "Rime 用户目录": str(user_directory), "本地同步目录": str(sync_directory),
        "设备名": installation_id, "远程目录": remote, "每日时间": daily_time,
        "排除文件": EXCLUDES, "调度方式": "launchd" if platform == "darwin" else "cron",
        "配置文件": str(config_path), "日志": str(state_directory / "sync.log"),
    }, ensure_ascii=False, indent=2), flush=True)
    message("print_warning", "首次初始化会合并两端文件；同路径冲突使用较新的文件。各设备的 installation_id 必须唯一。")
    if not confirm("保存配置、执行一次同步并安装每日任务？"):
        raise SyncError("未保存配置。")
    state, pair = state_paths(settings)
    ensure_directory(state)
    with (state / "workflow.lock").open("a") as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SyncError("同步任务正在运行，未修改配置，请稍后重新执行 setup。")
        ensure_directory(sync_directory)
        update_installation(user_directory, sync_directory, installation_id)
        write_json(config_path, settings)
        # First setup explicitly initializes the baseline; background runs never resync.
        run_workflow(settings, resync=not (pair / "initialized.json").exists(), lock_held=True)
        hour, minute = (int(value) for value in daily_time.split(":"))
        scheduler.install(platform, RUNNER, config_path, state_directory / "sync.log",
                          hour, minute, path_environment)
    message("print_success", "每日任务已安装；每天 " + daily_time + " 起每小时检查，成功后当天跳过。")


def show_status(settings, config_path):
    validate_settings(settings)
    _, pair = state_paths(settings)
    message("print_info", "配置文件：" + str(config_path))
    print(json.dumps(settings, ensure_ascii=False, indent=2))
    print("调度：" + scheduler.status(settings["platform"]))
    print("bisync 已初始化：" + ("是" if (pair / "initialized.json").exists() else "否"))
    for name in ("daily.json", "last-run.json"):
        if (pair / name).exists():
            print(name + ": " + json.dumps(read_json(pair / name), ensure_ascii=False))
    print("日志：" + str(Path(settings["state_dir"]) / "sync.log"))


def main(argv=None):
    global COMMON, RUNNER
    parser = argparse.ArgumentParser(prog="rime_sync_cloud", description="交互配置 Rime 云同步；Linux cron / macOS launchd")
    parser.add_argument("--common", type=Path, default=COMMON, help=argparse.SUPPRESS)
    parser.add_argument("--runner", type=Path, default=RUNNER, help=argparse.SUPPRESS)
    parser.add_argument("action", nargs="?", choices=("setup", "run", "resync", "status", "remove"), default="setup")
    parser.add_argument("--config", type=Path, default=default_config_path(), help="本机 JSON 配置文件")
    parser.add_argument("--scheduled", action="store_true", help="按每日成功记录去重；供定时任务使用")
    parser.add_argument("--yes", action="store_true", help="确认手动 resync")
    arguments = parser.parse_args(argv)
    COMMON, RUNNER = arguments.common.absolute(), arguments.runner.absolute()
    config_path = arguments.config.expanduser().absolute()
    try:
        if arguments.action == "setup":
            setup(config_path)
        elif arguments.action == "remove":
            scheduler.remove(platform_name())
            message("print_success", "已移除每日任务；配置、状态和词库保留。")
        else:
            if not config_path.exists():
                raise SyncError("尚未配置，请先运行 rime_sync_cloud setup。")
            settings = read_json(config_path)
            validate_settings(settings)
            if nested_in(config_path, Path(settings.get("sync_dir", str(config_path.parent)))):
                raise SyncError("任务配置必须放在同步目录之外，请重新配置。")
            if arguments.action == "status":
                show_status(settings, config_path)
            else:
                resync = arguments.action == "resync"
                if resync and not arguments.yes:
                    message("print_warning", "resync 会重新建立两端基线；同路径冲突使用较新的文件。")
                    if not confirm("确认重新初始化并同步？"):
                        raise SyncError("已取消。")
                run_workflow(settings, scheduled=arguments.scheduled, resync=resync)
        return 0
    except (SyncError, OSError, RuntimeError, ValueError) as error:
        message("print_error", str(error))
        return 1
    except KeyboardInterrupt:
        message("print_warning", "操作已中断；下次任务不会自动 resync。")
        return 130


if __name__ == "__main__":
    sys.exit(main())
