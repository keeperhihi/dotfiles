# Dotfiles

## 致程序员

本项目用于管理 macOS / Linux 的 Zsh、Vim、Git、npm、SSH、gh 配置。

### 安装

需要 Zsh 和 Git。要保留的本机设置先让 Agent 整理到 `private/`。

```sh
git clone https://github.com/keeperhihi/dotfiles.git
cd dotfiles
./install.sh
exec zsh -l
```

安装前自动备份，只保留最近一份。

### 回滚

```sh
./install.sh -r
```

回滚直接覆盖当前受管配置，不询问确认，成功后删除备份。

### 改配置

共享配置放 `apps/`，本机配置放 `private/`。修改后重新运行 `./install.sh`。

`private/` 不进 Git。

## 致 Agent

先读 [AGENTS.md](AGENTS.md)，再看 `install.sh`。修改仓库源码，私有内容留在 `private/`。

配置变更在临时 HOME 中验证：

```sh
zsh -df tests/install.zsh
```

真实 HOME 的安装与回滚按用户请求执行。

## 速查

### 配置与命令

| 项目 | 用途 |
| --- | --- |
| Zsh | 彩色提示符、补全、高亮、自动建议 |
| 历史记录 | 跨终端共享、去重 |
| `ls` | 紧凑多列 |
| `tl` / `ta` | tmux 会话 |
| `rsy` | SSH 文件同步 |
| `mosh` | IPv4，UDP 60000–60020 |
| `tgz` / `untgz` | 打包、解包 |
| `cb` | macOS 剪贴板 |
| `zzz` | macOS 关闭显示器 |
| `awake` / `slp` | macOS 禁止睡眠、恢复睡眠并休眠 |
| Vim | Option 按词移动、删词 |
| Git | HTTP/1.1 |
| SSH | keepalive |
| `gh co` | 检出 PR |
| Homebrew | 清华镜像 |
| `>|` | 覆盖已有文件 |
| Vim Esc | 1 秒内的 `b`、`f`、`d`、退格可能触发 Option 映射 |

### 文件位置

| 位置 | 用途 |
| --- | --- |
| `apps/<app>/` | 共享配置 |
| `private/<app>/` | 本机配置 |
| `apps/zsh/manifest.toml` | Zsh 加载顺序 |
| `lib/config.zsh` | 目标清单、渲染 |
| `lib/files.zsh` | 备份、回滚 |
| `~/.local/state/dotfiles/backup/` | 最近一次备份 |
