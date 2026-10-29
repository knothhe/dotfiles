# Rime 每日云同步

运行 `rime_sync_cloud setup` 进入交互配置。macOS 安装用户级 launchd
任务，Linux 安装当前用户的 cron 任务；不需要 sudo。

```bash
rime_sync_cloud setup       # 选择参数、初始化并安装定时任务
rime_sync_cloud run         # 立即执行一次，不受每日去重限制
rime_sync_cloud status      # 查看配置、定时任务和最近运行结果
rime_sync_cloud resync      # 明确确认后重建 bisync 基线
rime_sync_cloud remove      # 移除自己的定时任务，保留词库和配置
```

## 同步流程

每次完整运行依次执行：

1. `rime_sync`：合并本地同步目录里已有的其他设备快照，再写出本机快照。
2. `rclone bisync`：将本地同步目录与 R2 远程目录双向同步。
3. `rime_sync`：合并刚从远端拉回的其他设备快照。

本轮上传运行前的本机新增词条，并让其他设备已经上传的词条在本机生效。
第三步产生的本机合并快照留到下次 bisync 上传；其他设备的原始快照已经在同步目录中。
脚本复用 Rime 的合并逻辑，不自行解析或合并词条。

`installation_id` 是 Rime 的设备标识，例如 `lara`，不是脚本自动推断的系统名。
每台设备必须使用不同标识。Rime 将本机快照写到
`<sync_dir>/<installation_id>/`，并读取其他设备的快照。

## 依赖和默认值

通用依赖：

- Bash、Python 3.9 或更新版本。
- 支持 `bisync`、`--resync-mode`、`--recover`、`--resilient` 和
  `--max-lock` 的 rclone。
- 已配置的 rclone remote。R2 的账号和密钥由 `rclone config` 管理，
  本脚本只保存 rclone 配置文件路径。
- 本仓库的 `rime_sync` 和 `common_functions.sh`。

向导会先用定时任务的受限环境，非交互检查 rclone 配置能否读取。
初始化和日常运行均不继承交互 shell 中的 `RCLONE_*`、`AWS_*` 等临时凭据变量。
如果加密配置依赖临时的 `RCLONE_CONFIG_PASS` 或 `RCLONE_PASSWORD_COMMAND`，
向导会拒绝安装任务；请先配置后台可用的凭据方式。脚本不会将解密密码写入任务 JSON。

macOS 使用鼠须管自带的 `rime_dict_manager`、`pgrep`、`open` 和 `launchctl`。
Linux 使用 `rime_dict_manager`、`fcitx5-remote`、`fcitx5`、`pgrep` 和 `crontab`；
Arch 安装 `librime`，Debian/Ubuntu 安装 `librime-bin`。
Linux 还需要发行版提供的 cron 服务处于运行状态。

| 参数 | 默认值 |
| --- | --- |
| Rime 用户目录 | macOS：`~/Library/Rime`；Linux：`${XDG_DATA_HOME:-~/.local/share}/fcitx5/rime` |
| 本地同步目录 | 从 `installation.yaml` 读取 `sync_dir`，未配置则为 Rime 用户目录的 `sync` 子目录 |
| 设备标识 | `installation.yaml` 中的 `installation_id` |
| 远程目录 | `app-sync:app-sync/rime` |
| 每日首次尝试时间 | `03:00` |
| 排除文件 | 所有目录下的 `.DS_Store`，两个系统都排除 |

确认前会展示参数。修改本地同步目录或设备标识时，向导同步更新
`installation.yaml`，确保 Rime 和 rclone 使用相同目录。
本机任务配置、rclone 凭据和 bisync 状态不得放入同步目录。

## 调度与补跑

cron 和 launchd 每小时在选定分钟调用一次 `run --scheduled`。
launchd 还在任务加载或登录时检查，并使用日历触发以便睡眠唤醒后补跑。

- 到达每日时间后，当天尚未成功才执行完整流程。
- 三个步骤全部成功才记录当天成功；网络失败等错误保留日志，后续小时重试。
- 当天成功后跳过剩余检查。手动 `run` 仍可立即同步。
- 使用本机文件锁，避免配置更新、手动执行和定时执行互相重叠。

向导保存当时的 `PATH`、XDG 配置/数据/缓存目录，以及必要的桌面会话变量
`DBUS_SESSION_BUS_ADDRESS`、`XDG_RUNTIME_DIR`、`DISPLAY`、`WAYLAND_DISPLAY`、`XAUTHORITY`。
请在实际使用 Fcitx5 的桌面会话中配置；切换桌面会话后可重新执行 `setup` 更新环境。

macOS 和 Linux 的 `rime_sync` 都会等待原输入法进程退出，用同步 CLI 完成词库操作，
再尝试恢复原先运行的输入法，因此执行期间输入法会短暂重启。

Linux 的任务只更新 `# BEGIN rime_sync_cloud` 到 `# END rime_sync_cloud`
之间的区块，保留其他 cron 条目。macOS 的 label 为
`io.github.knothhe.rime-sync-cloud`。

## 初始化与恢复

首次 `setup` 明确初始化，使用：

```bash
rclone bisync "$sync_dir" "$remote" \
  --config "$rclone_config" --ask-password=false \
  --workdir "$local_state_dir" \
  --exclude '.DS_Store' --resilient --recover --max-lock 2m \
  --resync --resync-mode newer -v
```

初始化合并两端的文件集合。同路径冲突使用较新的文件，不保证保留冲突的两份内容。
正常运行省略 `--resync --resync-mode newer`，避免重建基线掩盖同步错误。
不要把 `--resync` 放入每天运行的命令中。

日常失败不会自动追加 `--resync`。如首次初始化未成功、状态目录丢失，
或 bisync 明确要求重建状态，检查日志后运行 `rime_sync_cloud resync`。
更换同名 remote 背后的账户或存储位置后也应明确重新初始化。

## 配置和日志位置

- 配置：`${XDG_CONFIG_HOME:-~/.config}/rime-sync-cloud/config.json`
- 状态：`${XDG_STATE_HOME:-~/.local/state}/rime-sync-cloud/`
- 日志：状态目录下的 `sync.log`
- macOS 定时配置：`~/Library/LaunchAgents/io.github.knothhe.rime-sync-cloud.plist`

各设备维护独立的 bisync 状态，状态目录不参与云同步。
可用 `--config /absolute/path/config.json` 指定其他配置文件；
一台机器默认只安装一份此命令管理的每日任务。

```bash
tail -f ~/.local/state/rime-sync-cloud/sync.log
```

定时运行的输出追加到日志，手动运行直接输出到终端。
