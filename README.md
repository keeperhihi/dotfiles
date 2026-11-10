# Dotfiles

## 致程序员

本项目用于管理 macOS / Linux 的 Zsh、Vim、Git、npm、SSH、gh 配置。

### 安装

需要 Zsh 和 Git。要保留的本机设置先让 Agent 整理到 `private/`。

```sh
git clone https://github.com/keeperhihi/dotfiles.git
cd dotfiles
./install.sh
```

第一次安装时自动备份原有配置，之后重装不再覆盖这份备份。安装后关闭旧终端窗口，
从桌面重新打开终端，让新的配置生效并清除旧 Shell 中已导出的环境变量。

### 回滚

```sh
./install.sh -r
```

Zsh 的启动入口只移除 dotfiles 自己的区块，保留 Magpie 等工具的区块及其他内容。其余受管文件恢复成第一次安装之前的样子，成功后删除备份。

### 改配置

共享配置放 `apps/`，本机配置放 `private/`。修改后重新运行 `./install.sh`。

`private/` 不进 Git。

### Zsh 与 Magpie 共存

Zsh 的主体配置生成到 `~/.config/zsh/interactive.zsh` 和
`~/.config/zsh/profile.zsh`，分别对应交互式与登录配置。它们是独立副本，
日常仍编辑仓库中的 `apps/zsh/`、`private/zsh/`，安装后不依赖仓库路径。

`~/.zshrc` 和 `~/.zprofile` 只由 dotfiles 维护下面的入口区块；同一文件中的
Magpie `agy` 区块及其他内容会在重装、回滚时保留：

```zsh
# >>> dotfiles >>>
source "$HOME/.config/zsh/interactive.zsh"
# <<< dotfiles <<<
```

`.zprofile` 加载的是 `profile.zsh`。不需要修改 `ZDOTDIR`。
从旧版整文件生成的启动文件升级时，旧主体被独立生成文件替代，
从第一个 `# >>> …` 工具标记开始的尾部保留；首次接管备份仍保留到回滚。
旧主体中的个人改动应先整理到 `private/zsh/`。

AI 工具的账号、密钥、网关、模型以及 `agy` 启动函数由 Magpie 管理。
Shell 片段中不再导出 AI 接入环境变量，也不再用 `deepseek`、`naive`
之类的函数覆盖模型。切换模型在 Magpie 或客户端中进行。
退出旧终端后重新打开，让旧的环境变量和函数退出当前 Shell。

npm 源仍属于 dotfiles：在 `private/npm/npmrc` 中设置
`registry=https://registry.npmjs.org/`，重装后才会与本机一致。

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
| `~/.config/zsh/interactive.zsh` | 生成的 Zsh 交互配置 |
| `~/.config/zsh/profile.zsh` | 生成的 Zsh 登录配置 |
| `~/.zshrc`、`~/.zprofile` | dotfiles 加载区块与其他工具区块共存的入口 |
| `~/.local/state/dotfiles/backup/` | 第一次安装前的原样 |
