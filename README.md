# Dotfiles

## 写给人看

macOS 和 Linux 通用的 Zsh、Vim、Git、npm、SSH、gh 配置。维护仓库里的源码，用 `./install.sh` 备份并安装到本机。生成的是独立的普通文件，仓库移动或删除后仍可使用。

### 包含什么

- Zsh：彩色 `[用户:路径]$` 提示符，Zim 提供补全、语法高亮、自动建议和按输入内容搜索历史。
- `ls`：在终端里按行排成紧凑多列；输出到管道，或使用 `-l`、长选项、多个路径时交给系统 `ls`。
- 历史记录：多个终端共享并去重，空格开头的命令不记录。
- 常用命令：`tl` / `ta` 管理 tmux 会话，`rsy` 通过 SSH 同步文件，`mosh` 固定 IPv4 和 UDP 60000–60020，`tgz` / `untgz` 打包和解包。
- macOS：`cb` 复制文件内容或命令输出，`zzz` 关闭显示器，`awake` / `slp` 禁止睡眠或恢复睡眠并立即休眠。
- Vim：Insert、Normal、命令行模式下，Option+←/→ 按词移动，Option+Backspace / Option+Fn+Backspace 删除前后一个词。终端需发送 Esc 前缀序列，已在 iTerm2 验证。
- Git 使用 HTTP/1.1；SSH 开启 keepalive；gh 提供 `co`（`gh pr checkout`）。

### 安装与回滚

需要 Zsh 和 Git。首次启动交互式 Zsh 时，通过 curl 或 wget 联网安装 Zim 和插件；已安装的 NVM、Homebrew 会自动加载。

安装会整体替换下表中的八个配置文件。要长期保留的本机设置，先整理到 `private/`，见下一节。

```sh
git clone https://github.com/keeperhihi/dotfile.git
cd dotfile
# 准备好 private/ 后安装；没有私有配置也可以直接安装
./install.sh
exec zsh -l
```

安装前自动备份到 `~/.local/state/dotfiles/backup/`，只保留最近一次安装前的状态。每次安装都会更新备份，即使配置内容没有变化。

```sh
./install.sh -r
```

回滚直接覆盖当前受管配置，不询问确认：恢复原文件内容、权限和符号链接，删除安装前不存在的文件，成功后删除备份。回滚不修改仓库源码；没有备份时会报错。

### 改配置

`apps/` 保存可提交到 Git 的共享配置。`private/` 被 Git 忽略，保存身份、token、代理、内网主机和私钥路径等本机设置。修改源码后运行 `./install.sh`；直接修改生成文件，下次安装会覆盖它。

每个目标按下表顺序拼接，private 文件可选：

| 目标 | 来源（按顺序） |
| --- | --- |
| `~/.zprofile` | `apps/zsh` → `private/zsh/environment.zsh` → `private/zsh/profile.zsh` |
| `~/.zshrc` | `apps/zsh` → `private/zsh/environment.zsh` → `private/zsh/interactive.zsh` |
| `~/.vimrc` | `apps/vim/vimrc` → `private/vim/vimrc` |
| `~/.gitconfig` | `apps/git/gitconfig` → `private/git/gitconfig` |
| `~/.npmrc` | `apps/npm/npmrc` → `private/npm/npmrc` |
| `~/.ssh/config` | `private/ssh/config` → `apps/ssh/config` |
| `~/.zimrc` | `apps/zsh/shared/modules/zim.zsh` |
| `~/.config/gh/config.yml` | `apps/gh/config.yml` |

- Zsh 按 `apps/zsh/manifest.toml` 装配：shared → 当前平台片段 → private。新增片段要登记到 manifest。
- 环境变量放 `private/zsh/environment.zsh`；登录 shell 配置放 `profile.zsh`，alias 和函数放 `interactive.zsh`。
- SSH 将 private 放在前面，因为 OpenSSH 的多数选项采用第一次出现的值。

例如设置 Git 身份：

```sh
mkdir -p private/git
git config --file private/git/gitconfig user.name "Your Name"
git config --file private/git/gitconfig user.email "you@example.com"
./install.sh
```

`private/` 需要自行保管，换机器时单独复制。安装备份只保存受管 HOME 文件，不包含这份源码。

### 使用注意

- 开启了 `NO_CLOBBER`：`>` 不覆盖已有文件，明确覆盖时使用 `>|`。
- macOS 的 Homebrew 默认使用清华镜像，可在 `apps/zsh/platform/darwin/profile.zsh` 调整三个 `HOMEBREW_*` 变量。
- Vim 中 Esc 后 1 秒内输入的 `b`、`f`、`d`、退格可能被识别为 Option 组合键，会影响快速按 Esc 后执行这些普通按键命令。

## 写给 Agent

先读 `AGENTS.md`。注释和脚本输出用中文，配置改动写入仓库源码。

### 代码入口与约束

- `install.sh` 是用户入口：无参数安装，`-r` 回滚。`lib/` 中的文件仅供内部加载。
- `lib/config.zsh`：`targets` 是安装、备份、回滚共用的唯一目标清单；`render_zsh` 和 `render_plain` 负责拼接。
- `lib/files.zsh`：负责路径检查、快照复制和文件替换。写入前检查全部目标，拒绝目录、特殊文件和符号链接父目录；每个文件在目标父目录中暂存后替换。
- `apps/zsh/manifest.toml`：唯一的 Zsh 加载顺序来源。`manifest_sources` 读取简单双引号路径数组；`apps/zsh/shared/modules/zim.zsh` 单独生成 `.zimrc`，不加入 manifest。
- 生成配置必须自包含，不依赖仓库路径。macOS 专属配置放在 `apps/zsh/platform/darwin/`。
- 安装时 private 目录权限为 `700`、文件为 `600`。`.zshrc`、`.zprofile`、`.gitconfig`、`.npmrc`、`.ssh/config` 安装权限为 `600`，其他目标为 `644`。
- 备份目录权限为 `700`，内部保留原文件权限。全部渲染与备份成功后才替换旧备份并开始安装；写入或回滚失败时保留完整备份，排除错误后可以重试回滚。回滚可能留下空父目录。
- `private/` 的内容不能写入共享源码或强制加入 Git。gh 登录凭据 `~/.config/gh/hosts.yml`、SSH 密钥和 `known_hosts` 不在管理范围内，维护本仓库时不要读写它们。

### 帮用户部署

1. 检查仓库现有的 private 配置，把用户希望保留的 Git 身份、SSH 主机、npm 设置、代理和本机初始化整理到对应的 `private/<app>/`。`.zimrc` 和 gh 配置的共享源码只保存可公开内容。
2. 在临时 HOME 中完成验证。仅修改仓库时，验证也只使用临时 HOME。
3. 用户请求安装时运行 `./install.sh`；请求回滚时运行 `./install.sh -r`。安装自动备份，回滚直接覆盖。
4. 报告执行结果和备份状态，提示新开登录 Shell 或执行 `exec zsh -l`；首次启动 Zsh 会联网安装插件。

### 验证

```sh
zsh -df tests/install.zsh
```

测试自动创建并清理临时仓库和临时 HOME，不读取本机 private。覆盖两种平台的渲染、配置优先级、安装、最近一次备份、回滚、权限、符号链接和失败恢复。测试通过替换平台检测来覆盖 darwin/linux 分支，文件操作使用宿主系统工具。

手动检查生成内容时：

```sh
test_home="$(mktemp -d)"
HOME="$test_home" ./install.sh
zsh -n "$test_home/.zshrc"
zsh -n "$test_home/.zprofile"
HOME="$test_home" vim -Nu "$test_home/.vimrc" -i NONE -n -es +'qa!'
git config --file "$test_home/.gitconfig" --list >/dev/null
ssh -G -F "$test_home/.ssh/config" example.com >/dev/null
HOME="$test_home" ./install.sh -r
rm -rf "$test_home"
```

### 新增受管文件

1. 在 `lib/config.zsh` 的 `targets` 增加相对路径、renderer 和权限，并实现对应渲染分支。
2. 在 `apps/<app>/` 添加共享源码，按需要约定 private 路径。
3. 将新增目标和运行时文件加入 `.gitignore`，检查 `lib/files.zsh` 的备份和回滚行为。
4. 更新上面的来源表和 `tests/install.zsh`，在临时 HOME 验证安装与回滚。
