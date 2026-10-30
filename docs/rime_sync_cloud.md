# Rime 每日云同步

运行 `rime_sync_cloud setup` 进入交互配置。macOS 安装用户级 launchd
任务，Linux 安装当前用户的 cron 任务；不需要 sudo。

```bash
rime_sync_cloud setup       # 选择参数、执行一次同步并安装定时任务
rime_sync_cloud run         # 立即执行一次，不受每日去重限制
rime_sync_cloud status      # 查看配置、定时任务和最近运行结果
rime_sync_cloud remove      # 移除自己的定时任务，保留词库和配置
```

## 同步流程

每次完整运行依次执行：

1. `rclone copy`：从远端拉取其他设备目录，排除本机 `/<installation_id>/**`。
2. `rime_sync`：合并刚拉回的其他设备快照，再导出本机用户词库。
3. `rclone copy`：仅将本机 `<sync_dir>/<installation_id>/` 上传到远端同名目录。

本轮就会上传合并后的本机快照；每轮只执行一次本地 Rime 同步。
脚本复用 Rime 的合并逻辑，不自行解析或合并词条，也不假设各设备使用相同词库或文件名。
传输以整个设备目录为单位，包含其中所有未排除的文件和子目录。

`installation_id` 是 Rime 的设备标识，例如 `lara`，不是脚本自动推断的系统名。
每台设备必须使用不同标识。Rime 将本机快照写到
`<sync_dir>/<installation_id>/`，并读取其他设备的快照。

例如，`lara` 只上传 `lara/`、拉取 `roxy/` 等其他目录；`roxy` 只上传 `roxy/`、
拉取 `lara/` 等其他目录。设备名从本机配置读取，脚本不会写死示例中的设备名。
本机目录以本地为准，其他设备目录以远端为准；本机缓存中的其他设备快照不会反向上传。

两次传输都使用 [`copy`](https://rclone.org/commands/rclone_copy/)，更新变化文件但保留目标端多出的文件。
删除本地文件不会自动删除云端文件，云端退役设备目录也不会自动从本地移除；需要明确清理。

## 依赖和默认值

通用依赖：

- Bash、Python 3.9 或更新版本。
- 支持 `copy` 的 rclone。
- 已配置的 rclone remote。R2 的账号和密钥由 `rclone config` 管理，
  本脚本只保存 rclone 配置文件路径。
- 本仓库的 `rime_sync` 和 `common_functions.sh`。

向导会先用定时任务的受限环境，非交互检查 rclone 配置能否读取。
配置和日常运行均不继承交互 shell 中的 `RCLONE_*`、`AWS_*` 等临时凭据变量。
如果加密配置依赖临时的 `RCLONE_CONFIG_PASS` 或 `RCLONE_PASSWORD_COMMAND`，
向导会拒绝安装任务；请先配置后台可用的凭据方式。脚本不会将解密密码写入任务 JSON。

Cloudflare R2 使用只有对象读写权限的 token 时，需在对应 rclone remote 的配置中
设置 `no_check_bucket = true`，避免上传时尝试 `CreateBucket` 而返回 403。
参见 [Cloudflare 的 rclone 配置说明](https://developers.cloudflare.com/r2/examples/rclone/)。

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
本机任务配置、rclone 凭据和运行状态不得放入同步目录。

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

## 升级与恢复

脚本更新后使用 `chezmoi apply` 应用到本机。可以直接运行它更新全部托管配置，
也可以只应用 Rime 云同步及其依赖：

```bash
chezmoi apply \
  ~/.local/xbin/rime_sync_cloud \
  ~/.local/xbin/rime_sync_cloud.py \
  ~/.local/xbin/rime_sync_cloud_scheduler.py \
  ~/.local/xbin/rime_sync \
  ~/.local/xbin/common_functions.sh
```

这里使用实际目标路径。只应用 `~/.local/xbin/rime_sync_cloud` 会更新 Bash 启动脚本，
不会更新相邻的 Python 实现。应用后，已有每日任务下次运行就会使用新脚本，
无需重新 `setup`；需要立即同步时再执行 `rime_sync_cloud run`。
`chezmoi apply` 本身只负责应用这些脚本，不会执行词库云同步。

从旧 bisync 版本升级后，已有配置和每日任务可以继续使用，直接执行
`rime_sync_cloud run` 即可，无需重建基线。
旧 `bisync/` 状态和 `RCLONE_TEST` 标记会保留；新流程不读取这些状态，
拉取时排除根目录的 `RCLONE_TEST`，也不会创建或更新该标记。
兼容旧命令 `resync`（包括 `resync --yes`），按普通 `run` 执行并提示同步方式已改变。

网络失败后重新执行 `run`，或等待下一次定时重试即可。
只有拉取、本地合并和上传三个步骤都成功后，才记录当天成功。

重装系统并复用原 `installation_id` 时，应先备份并恢复云端该设备目录中的快照，
让 Rime 完成词库恢复后再启用日常上传。日常拉取始终排除本机目录，
不会自动从云端恢复本机快照，也不会通过文件时间决定本机与云端的优先级。

## 配置和日志位置

- 配置：`${XDG_CONFIG_HOME:-~/.config}/rime-sync-cloud/config.json`
- 状态：`${XDG_STATE_HOME:-~/.local/state}/rime-sync-cloud/`
- 日志：状态目录下的 `sync.log`
- macOS 定时配置：`~/Library/LaunchAgents/io.github.knothhe.rime-sync-cloud.plist`

每日成功和最近运行结果保存在 `runs/<本机任务标识>/`；标识包含设备名、同步路径和 remote。
状态目录不参与云同步。
可用 `--config /absolute/path/config.json` 指定其他配置文件；
一台机器默认只安装一份此命令管理的每日任务。

```bash
tail -f ~/.local/state/rime-sync-cloud/sync.log
```

定时运行的输出追加到日志，手动运行直接输出到终端。
