#!/usr/bin/env zsh

# 在临时仓库与 HOME 中验证公开安装入口，不读取本机 private 配置。
emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL POSIX_TRAPS

typeset repo_root="${${(%):-%x}:A:h:h}"
typeset test_root="$(command mktemp -d "${TMPDIR:-/tmp}/dotfiles test.XXXXXX")"
test_root="${test_root:A}"
trap 'command rm -rf "$test_root"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

typeset test_source="$test_root/source" test_home test_platform backup_dir output
typeset -i checks=0
command mkdir -p "$test_source" "$test_root/bin" "$test_root/external"
command cp -R "$repo_root/apps" "$repo_root/lib" "$repo_root/install.sh" "$test_source/"
print -r -- outside > "$test_root/external/config"

# 仅替换平台检测；文件操作始终使用宿主系统的 BSD/GNU 工具。
cat > "$test_root/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "$TEST_PLATFORM"
EOF
command chmod +x "$test_root/bin/uname"

fail() {
  print -u2 -- "失败：$*"
  [[ ! -f "$test_root/output" ]] || command cat "$test_root/output" >&2
  exit 1
}

check() {
  local label="$1"
  shift
  "$@" || fail "$test_platform $label"
  (( checks += 1 ))
}

mode() {
  case "$OSTYPE" in
    darwin*) command stat -f '%Lp' "$1" ;;
    linux*) command stat -c '%a' "$1" ;;
  esac
}

run_install() {
  command env HOME="$test_home" PATH="$test_root/bin:$PATH" \
    TEST_PLATFORM="$test_platform" "$test_source/install.sh" "$@" \
    < /dev/null > "$test_root/output" 2>&1
}

expect_failure() {
  if run_install "$@"; then
    fail "命令应失败：install.sh $*"
  fi
  (( checks += 1 ))
}

new_home() {
  test_home="$test_root/$test_platform $1"
  backup_dir="$test_home/.local/state/dotfiles/backup"
  command mkdir -p "$test_home"
}

for test_platform in Darwin Linux; do
  # 空 HOME 和没有 private 的首次安装；回滚删除所有新增配置。
  command rm -rf "$test_source/private"
  new_home empty
  expect_failure -r
  expect_failure unexpected
  check '无备份时不创建状态目录' test ! -e "$test_home/.local"
  run_install || fail '首次安装失败'
  check '空快照也可以回滚' test -d "$backup_dir"
  check '备份目录权限' test "$(mode "$backup_dir")" = 700
  check 'Zsh 交互配置语法' zsh -n "$test_home/.zshrc"
  check 'Zsh 登录配置语法' zsh -n "$test_home/.zprofile"
  check 'Zsh 交互主体语法' zsh -n "$test_home/.config/zsh/interactive.zsh"
  check 'Zsh 登录主体语法' zsh -n "$test_home/.config/zsh/profile.zsh"
  check 'Zim 配置语法' zsh -n "$test_home/.zimrc"
  check 'Vim 配置可加载' env HOME="$test_home" vim -Nu "$test_home/.vimrc" -i NONE -n -es +'qa!'
  check '共享 Git 配置' test "$(git config --file "$test_home/.gitconfig" http.version)" = HTTP/1.1
  if [[ "$test_platform" == Darwin ]]; then
    check '加载 macOS 片段' grep -q HOMEBREW "$test_home/.config/zsh/profile.zsh"
  elif command grep -q HOMEBREW "$test_home/.config/zsh/profile.zsh"; then
    fail 'Linux 加载了 macOS 片段'
  fi
  run_install -r || fail '空快照回滚失败'
  for output in .zshrc .zprofile .config/zsh/interactive.zsh .config/zsh/profile.zsh .zimrc .vimrc .gitconfig .npmrc .ssh/config .config/gh/config.yml; do
    check "删除新增目标 $output" test ! -e "$test_home/$output"
  done
  check '回滚清理备份' test ! -e "$backup_dir"
  expect_failure -r

  # 原有文件、权限、指向文件/目录的链接及悬空链接都必须可恢复。
  command mkdir -p "$test_source/private/ssh" "$test_source/private/git" "$test_source/private/zsh"
  cat > "$test_source/private/ssh/config" <<'EOF'
Host override-test
    HostName 127.0.0.1
    ServerAliveInterval 5
    ServerAliveCountMax 2
    TCPKeepAlive no
EOF
  print -rl -- '[http]' '    version = HTTP/2' > "$test_source/private/git/gitconfig"
  print -r -- 'export DOTFILES_TEST=private' > "$test_source/private/zsh/environment.zsh"
  new_home existing
  command mkdir -p "$test_home/.ssh" "$test_home/.config/gh"
  print -r -- original > "$test_home/.zshrc"
  command chmod 640 "$test_home/.zshrc"
  print -r -- 'Host original' > "$test_home/.ssh/config"
  command chmod 400 "$test_home/.ssh/config"
  print -r -- auth > "$test_home/.config/gh/hosts.yml"
  print -r -- known > "$test_home/.ssh/known_hosts"
  command ln -s "$test_root/external/config" "$test_home/.vimrc"
  command ln -s "$test_root/external" "$test_home/.gitconfig"
  command ln -s missing "$test_home/.npmrc"
  run_install || fail '已有配置安装失败'
  check '备份发生在覆盖之前' test "$(<"$backup_dir/.zshrc")" = original
  check '安装权限' test "$(mode "$test_home/.zshrc")" = 600
  check 'private 文件权限' test "$(mode "$test_source/private/git/gitconfig")" = 600
  check 'private 目录权限' test "$(mode "$test_source/private/git")" = 700
  check 'Git 私有配置优先级' test "$(git config --file "$test_home/.gitconfig" http.version)" = HTTP/2
  check 'Zsh 私有片段最后拼接' test "$(tail -n 2 "$test_home/.config/zsh/interactive.zsh")" = 'export DOTFILES_TEST=private'
  check '入口保留原有内容' grep -qx original "$test_home/.zshrc"
  output="$(ssh -G -F "$test_home/.ssh/config" override-test 2>/dev/null)"
  [[ "$output" == *$'serveraliveinterval 5\n'* \
    && "$output" == *$'serveralivecountmax 2\n'* \
    && "$output" == *$'tcpkeepalive no\n'* ]] || fail 'SSH 私有配置优先级'
  output="$(ssh -G -F "$test_home/.ssh/config" fallback-test 2>/dev/null)"
  [[ "$output" == *$'serveraliveinterval 30\n'* \
    && "$output" == *$'serveralivecountmax 100\n'* \
    && "$output" == *$'tcpkeepalive yes\n'* ]] || fail 'SSH 默认值'
  print -r -- edited > "$test_home/.zshrc"
  print -rl -- '[http]' '    version = HTTP/3' > "$test_source/private/git/gitconfig"
  run_install -r || fail '已有配置回滚失败'
  check '入口回滚保留后续修改' test "$(<"$test_home/.zshrc")" = edited
  check '恢复原始权限' test "$(mode "$test_home/.zshrc")" = 640
  check '恢复只读文件权限' test "$(mode "$test_home/.ssh/config")" = 400
  check '恢复文件链接' test "$(readlink "$test_home/.vimrc")" = "$test_root/external/config"
  check '恢复目录链接' test "$(readlink "$test_home/.gitconfig")" = "$test_root/external"
  check '恢复悬空链接' test "$(readlink "$test_home/.npmrc")" = missing
  check '链接外部文件不变' test "$(<"$test_root/external/config")" = outside
  check '认证文件不变' test "$(<"$test_home/.config/gh/hosts.yml")" = auth
  check '其他 SSH 文件不变' test "$(<"$test_home/.ssh/known_hosts")" = known
  check '回滚不修改源码' test "$(git config --file "$test_source/private/git/gitconfig" http.version)" = HTTP/3
  check '清理已恢复快照' test ! -e "$backup_dir"

  # 只在第一次接管时备份：重装不覆盖原样；渲染失败不写入 HOME。
  new_home repeated
  command mkdir -p "$test_home/.ssh"
  print -r -- first > "$test_home/.zshrc"
  print -r -- 'Host first' > "$test_home/.ssh/config"
  run_install || fail '第一次安装失败'
  print -r -- second > "$test_home/.zshrc"
  command rm "$test_home/.ssh/config"
  run_install || fail '第二次安装失败'
  check '重装不覆盖原样' test "$(<"$backup_dir/.zshrc")" = first
  check '重装保留原样里的文件' test "$(<"$backup_dir/.ssh/config")" = 'Host first'
  check '状态目录只有一个备份' test "$(ls -A "$test_home/.local/state/dotfiles")" = backup
  command cp -RPp "$backup_dir" "$test_root/expected"
  command cp "$test_home/.zshrc" "$test_root/installed"
  command mv "$test_source/apps/vim/vimrc" "$test_root/vimrc"
  expect_failure
  command mv "$test_root/vimrc" "$test_source/apps/vim/vimrc"
  check '渲染失败保留原配置' cmp -s "$test_home/.zshrc" "$test_root/installed"
  check '渲染失败不动原样' diff -r "$backup_dir" "$test_root/expected"

  # 清单新增的目标在第一次安装时补存原样；存原样失败时不写入 HOME，也不动已有原样。
  command cp "$test_source/lib/config.zsh" "$test_root/config.zsh"
  print -r -- "targets+=('.exrc vimrc 644')" >> "$test_source/lib/config.zsh"
  print -r -- mine > "$test_home/.exrc"
  cat > "$test_root/bin/cp" <<'EOF'
#!/bin/sh
for value do
  [ "$value" != "$HOME/.exrc" ] || exit 1
done
exec /bin/cp "$@"
EOF
  command chmod +x "$test_root/bin/cp"
  expect_failure
  command rm "$test_root/bin/cp"
  check '备份失败保留原配置' cmp -s "$test_home/.zshrc" "$test_root/installed"
  check '备份失败不写新目标' test "$(<"$test_home/.exrc")" = mine
  check '备份失败不动原样' diff -r "$backup_dir" "$test_root/expected"
  command rm -rf "$test_root/expected"
  run_install || fail '新增目标后安装失败'
  check '新增目标补存原样' test "$(<"$backup_dir/.exrc")" = mine
  check '已有原样不变' test "$(<"$backup_dir/.zshrc")" = first
  run_install -r || fail '回滚失败'
  command mv "$test_root/config.zsh" "$test_source/lib/config.zsh"
  check '入口回滚保留当前用户内容' test "$(<"$test_home/.zshrc")" = second
  check '恢复第一次安装前的文件' test "$(<"$test_home/.ssh/config")" = 'Host first'
  check '恢复新增目标的原样' test "$(<"$test_home/.exrc")" = mine
  run_install || fail '回滚后安装失败'

  # 中途写入失败后，原样仍能用于回滚；回滚失败也不消耗备份。
  print -r -- edited > "$test_home/.zshrc"
  cat > "$test_root/bin/mv" <<'EOF'
#!/bin/sh
for value do
  [ "$value" != "$HOME/.ssh/config" ] || exit 1
done
exec /bin/mv "$@"
EOF
  command chmod +x "$test_root/bin/mv"
  expect_failure
  check '安装失败不动原样' test "$(<"$backup_dir/.zshrc")" = second
  expect_failure -r
  check '回滚失败保留完整备份' test -f "$backup_dir/.ssh/config"
  command rm "$test_root/bin/mv"
  run_install -r || fail '失败后重试回滚失败'
  check '重试回滚保留入口外部内容' test "$(<"$test_home/.zshrc")" = edited
  check '重试成功清理备份' test ! -e "$backup_dir"
  check '失败后无临时文件残留' test -z "$(find "$test_home" \( -name '.dotfiles.*' -o -name '.pending.*' \) -print)"

  # 回滚按接管记录：清单后来删掉的目标放回原样，还没接管的新目标不动。
  new_home changed
  print -r -- 'registry=original' > "$test_home/.npmrc"
  run_install || fail '清单变更前安装失败'
  command cp "$test_source/lib/config.zsh" "$test_root/config.zsh"
  print -rl -- 'targets=("${(@)targets:#.npmrc *}")' "targets+=('.exrc vimrc 644')" >> "$test_source/lib/config.zsh"
  print -r -- mine > "$test_home/.exrc"
  run_install -r || fail '清单变更后回滚失败'
  command mv "$test_root/config.zsh" "$test_source/lib/config.zsh"
  check '恢复已移出清单的目标' test "$(<"$test_home/.npmrc")" = 'registry=original'
  check '不动没接管过的目标' test "$(<"$test_home/.exrc")" = mine

  # 从真实旧布局切换：移走旧生成主体，工具区块在安装、重装和回滚后仍在。
  new_home magpie
  cat > "$test_home/.zshrc" <<'EOF'
# 由 install.sh 生成；请编辑 apps/zsh 或 private/zsh。
export OLD_AI_ROUTE=old

# >>> magpie agy >>>
agy() { print -r -- magpie; }
# <<< magpie agy <<<
EOF
  cat > "$test_root/magpie" <<'EOF'
# >>> magpie agy >>>
agy() { print -r -- magpie; }
# <<< magpie agy <<<
EOF
  run_install || fail '旧版 Zsh 入口交接失败'
  check '旧生成主体已移出入口' test "$(grep -c OLD_AI_ROUTE "$test_home/.zshrc" || true)" = 0
  check 'Magpie 区块仍在' grep -q 'agy()' "$test_home/.zshrc"
  command cp "$test_home/.zshrc" "$test_root/entry"
  run_install || fail '与 Magpie 共存时重装失败'
  check '重复安装入口不变化' cmp -s "$test_root/entry" "$test_home/.zshrc"
  check '只存在一个 dotfiles 区块' test "$(grep -c '^# >>> dotfiles >>>$' "$test_home/.zshrc")" = 1
  # 验证实际 source 链，不启动 Zim 或其他外部程序。
  print -r -- 'export DOTFILES_ENTRY_TEST=loaded' > "$test_home/.config/zsh/interactive.zsh"
  output="$(env HOME="$test_home" zsh -df -c 'source "$HOME/.zshrc"; print -r -- "$DOTFILES_ENTRY_TEST"; agy')"
  check '默认入口同时加载主体和 Magpie 函数' test "$output" = $'loaded\nmagpie'
  print -r -- 'export AFTER_INSTALL=kept' >> "$test_home/.zshrc"
  run_install -r || fail 'Magpie 共存回滚失败'
  check '回滚保留 Magpie 函数' grep -q 'agy()' "$test_home/.zshrc"
  check '回滚保留后加配置' grep -qx 'export AFTER_INSTALL=kept' "$test_home/.zshrc"
  check '回滚只撤下自己的区块' test "$(grep -c '^# >>> dotfiles >>>$' "$test_home/.zshrc" || true)" = 0

  new_home malformed
  print -rl -- '# >>> dotfiles >>>' 'unfinished' > "$test_home/.zshrc"
  command cp "$test_home/.zshrc" "$test_root/entry"
  expect_failure
  check '区块损坏不覆盖入口' cmp -s "$test_root/entry" "$test_home/.zshrc"
  check '区块损坏不提前安装主体' test ! -e "$test_home/.config/zsh/interactive.zsh"

  # 对所有目标提前检查，避免遇到靠后的危险路径时已经写入前面的配置。
  for output in .ssh .local; do
    new_home "parent $output"
    print -r -- safe > "$test_home/.zshrc"
    command ln -s "$test_root/external" "$test_home/$output"
    expect_failure
    check '拒绝符号链接父目录前不写入' test "$(<"$test_home/.zshrc")" = safe
  done
  new_home directory
  print -r -- safe > "$test_home/.zshrc"
  command mkdir -p "$test_home/.config/gh/config.yml"
  expect_failure
  check '拒绝目录目标前不写入' test "$(<"$test_home/.zshrc")" = safe
done

print -- "通过：$checks 项检查，覆盖 darwin/linux 渲染、安装、首次接管备份、回滚及失败恢复。"
