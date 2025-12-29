# x_launchagent - macOS LaunchAgent 管理工具

## 概述

`x_launchagent` 是一个用于管理 macOS LaunchAgent 的命令行工具，提供查看、新增、修改、删除等完整的管理功能。支持定时任务的创建和管理，采用问答式向导和命令行参数两种操作方式。

## 核心功能

### 1. 查看功能 (List/View)

- **list**: 列出所有已安装的 LaunchAgent 服务
- **status**: 显示特定服务的运行状态
- **show**: 显示服务的完整 plist 配置内容
- **logs**: 快速查看服务的日志文件

### 2. 新增功能 (Add/Create)

- **create**: 交互式创建新的 LaunchAgent
- **create --template**: 使用预定义模板创建
- **create --script**: 指定脚本文件创建

### 3. 修改功能 (Modify/Edit)

- **edit**: 编辑现有 LaunchAgent 的 plist 配置
- **enable**: 启用服务（加载并启动）
- **disable**: 禁用服务（停止并卸载）

### 4. 删除功能 (Remove/Delete)

- **remove**: 安全删除 LaunchAgent 配置
- **remove --backup**: 删除前创建备份

### 5. 控制功能 (Control)

- **start**: 启动指定服务
- **stop**: 停止指定服务
- **restart**: 重启指定服务

## 定时执行支持

### 时间配置方式

1. **StartInterval**: 间隔执行
   - 每隔 N 秒执行一次
   - 示例：每 300 秒（5分钟）执行

2. **StartCalendarInterval**: 日历定时
   - 支持分钟、小时、日、月、星期配置
   - 类似 cron 表达式
   - 示例：每天凌晨 2 点执行

3. **RunAtLoad**: 加载时执行
   - LaunchAgent 加载时立即执行一次

### 配置参数

- **ProgramArguments**: 要执行的命令和参数
- **WorkingDirectory**: 脚本工作目录
- **EnvironmentVariables**: 环境变量设置
- **StandardOutPath**: 标准输出日志路径
- **StandardErrorPath**: 错误输出日志路径
- **UserName**: 执行用户（默认当前用户）

## 命令行用法

### 基本语法
```bash
x_launchagent [command] [options] [arguments]
```

### 查看命令
```bash
# 列出所有 LaunchAgent
x_launchagent list

# 显示服务状态
x_launchagent status <service-name>

# 显示详细配置
x_launchagent show <service-name>

# 查看服务日志
x_launchagent logs <service-name>
```

### 创建命令
```bash
# 交互式创建
x_launchagent create

# 使用模板创建
x_launchagent create --template <template-name>

# 指定脚本创建
x_launchagent create --script /path/to/script.sh

# 命令行参数方式创建
x_launchagent create \
  --name "my-task" \
  --script "/path/to/script.sh" \
  --interval 300 \
  --description "My custom task"
```

### 修改命令
```bash
# 编辑配置
x_launchagent edit <service-name>

# 启用服务
x_launchagent enable <service-name>

# 禁用服务
x_launchagent disable <service-name>

# 重载配置
x_launchagent reload <service-name>
```

### 删除命令
```bash
# 删除服务
x_launchagent remove <service-name>

# 删除前备份
x_launchagent remove <service-name> --backup
```

### 控制命令
```bash
# 启动服务
x_launchagent start <service-name>

# 停止服务
x_launchagent stop <service-name>

# 重启服务
x_launchagent restart <service-name>
```

## 交互式向导

### 创建向导流程

1. **创建模式选择**
   - 自定义创建
   - 使用模板创建

2. **基本信息输入**
   - 服务名称（建议格式：com.username.taskname）
   - 服务描述
   - 要执行的脚本文件路径

3. **定时配置**
   - 选择执行方式：
     - 间隔执行（输入秒数）
     - 日历定时（选择时间规则）
     - 加载时执行（一次性）

4. **环境配置**
   - 工作目录（默认脚本所在目录）
   - 环境变量设置
   - 日志输出路径

5. **确认创建**
   - 显示配置预览
   - 确认后创建并加载

### 模板系统

#### 定时任务模板

1. **daily-backup**: 每日备份任务
   - 执行时间：每天凌晨 2:00
   - 适用于备份脚本

2. **hourly-sync**: 每小时同步任务
   - 执行时间：每小时的第 0 分钟
   - 适用于数据同步

3. **weekly-cleanup**: 每周清理任务
   - 执行时间：每周日凌晨 3:00
   - 适用于日志清理、临时文件清理

4. **custom-interval**: 自定义间隔任务
   - 执行时间：用户指定间隔秒数
   - 适用于监控、检查类任务

## 文件位置

### LaunchAgent 配置目录
- 用户目录：`~/Library/LaunchAgents/`
- 系统目录：`/Library/LaunchAgents/`（需要管理员权限）

### 脚本位置
- 自定义脚本建议放在：`~/.local/xbin/tasks/`
- 日志文件默认位置：`~/.local/var/log/`

### 备份位置
- 删除前备份：`~/.local/var/backups/launchagents/`

## 使用示例

### 示例 1：创建定时备份任务
```bash
# 交互式创建
x_launchagent create
# 按提示输入：
# - 名称：com.user.backup-daily
# - 脚本：~/.local/xbin/tasks/backup.sh
# - 时间：每天 2:00 AM
# - 工作目录：$HOME
```

### 示例 2：使用模板创建监控任务
```bash
# 使用每小时模板
x_launchagent create --template hourly-sync --script ~/.local/xbin/tasks/sync-data.sh
```

### 示例 3：管理现有服务
```bash
# 查看所有服务状态
x_launchagent list

# 启动特定服务
x_launchagent start com.user.backup-daily

# 修改服务配置
x_launchagent edit com.user.backup-daily

# 查看服务日志
x_launchagent logs com.user.backup-daily
```

## 技术规格

### 依赖要求
- macOS 10.10+
- Bash 4.0+
- `launchctl` 命令（系统自带）
- `plutil` 命令（系统自带）

### 设计原则
- 遵循 `common_functions.sh` 的 UI 设计规范
- 使用 fzf 进行交互式选择（如果可用）
- 安全操作：删除前备份，重要操作确认
- 跨平台兼容：主要支持 macOS，兼容 Linux systemd

### 错误处理
- 完善的参数验证
- 详细的错误信息提示
- 操作失败的回滚机制
- 依赖检查和提示

## 配置文件格式

### Plist 文件结构
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.username.taskname</string>

    <key>ProgramArguments</key>
    <array>
        <string>/path/to/script.sh</string>
        <string>arg1</string>
        <string>arg2</string>
    </array>

    <key>WorkingDirectory</key>
    <string>/path/to/working/directory</string>

    <key>StartInterval</key>
    <integer>300</integer>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/path/to/stdout.log</string>

    <key>StandardErrorPath</key>
    <string>/path/to/stderr.log</string>
</dict>
</plist>
```

## 注意事项

1. **权限问题**: 确保脚本文件有执行权限
2. **路径问题**: 建议使用绝对路径
3. **日志轮转**: 长期运行的服务注意日志文件大小
4. **资源限制**: 避免创建过于频繁的定时任务
5. **备份重要**: 重要服务删除前务必备份

## 故障排除

### 常见问题

1. **服务无法启动**
   - 检查脚本文件权限
   - 查看错误日志
   - 验证 plist 语法

2. **定时任务不执行**
   - 确认时间配置正确
   - 检查系统时间设置
   - 查看服务状态

3. **脚本执行失败**
   - 检查脚本语法
   - 验证环境变量
   - 查看错误输出日志

### 调试方法
```bash
# 手动加载测试
launchctl load -w ~/Library/LaunchAgents/com.user.task.plist

# 查看详细错误
launchctl error <error-code>

# 查看服务状态
launchctl list | grep com.user.task
```

## 更新日志

- v1.0.0: 初始版本，支持基本的 LaunchAgent 管理功能
- 支持 fzf 交互选择
- 完整的模板系统
- 安全的删除和备份机制