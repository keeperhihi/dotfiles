#!/usr/bin/env zsh

emulate -LR zsh
# 函数内因 ERR_EXIT 退出时，也必须执行全局清理钩子。
setopt ERR_EXIT NO_UNSET PIPE_FAIL POSIX_TRAPS
umask 077

usage() {
  print -- '用法：./install.sh [-r]'
  print -- '  无参数  安装；第一次接管的配置先备份原样'
  print -- '  -r      恢复成第一次安装之前的样子，成功后删除备份'
}

(( $# <= 1 )) || { usage >&2; exit 2; }
case "${1:-}" in
  '') action=install ;;
  -r) action=restore ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

typeset repo_dir="${${(%):-%x}:A:h}"
source "$repo_dir/lib/files.zsh"
source "$repo_dir/lib/config.zsh"

require_directory HOME "${HOME:-}"
typeset home_dir="${HOME:A}"
typeset private_dir="$repo_dir/private"
typeset state_dir="$home_dir/.local/state/dotfiles"
typeset backup_dir="$state_dir/backup"
typeset staging_dir='' target_staging=''

cleanup() {
  [[ -z "$target_staging" ]] || command rm -rf "$target_staging"
  [[ -z "$staging_dir" ]] || command rm -rf "$staging_dir"
  return 0
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

validate_parent_chain "$backup_dir" "$home_dir"
[[ ! -L "$backup_dir" && ( ! -e "$backup_dir" || -d "$backup_dir" ) ]] \
  || die "备份路径必须是普通目录：$backup_dir"

if [[ "$action" == restore ]]; then
  [[ -d "$backup_dir" ]] || die '没有可回滚的备份'
  # 按接管记录回滚（记录只有相对路径）：清单后来删掉的目标也放回原样，没接管过的目标不动。
  targets=("${(@f)$(<"$backup_dir/managed")}")
  validate_targets "$home_dir"
  validate_targets "$backup_dir"
  write_targets "$backup_dir"
  command rm -rf "$backup_dir"
  print -- '回滚完成，备份已清理，source 后生效。'
  exit 0
fi

validate_targets "$home_dir"

typeset platform
case "$(command uname -s)" in
  Darwin) platform=darwin ;;
  Linux) platform=linux ;;
  *) die '只支持 macOS 和 Linux' ;;
esac

validate_source_tree "$repo_dir/apps"
if [[ -e "$private_dir" || -L "$private_dir" ]]; then
  require_directory private "$private_dir"
  command chmod -R 700 "$private_dir"
  validate_source_tree "$private_dir"
  command find "$private_dir" -type f -exec chmod 600 {} +
fi

command mkdir -p -m 700 "$state_dir"
command chmod 700 "$state_dir"
staging_dir="$(command mktemp -d "$state_dir/.pending.XXXXXX")"

# 渲染和备份全部成功后才写入 HOME。只有第一次接管的目标存原样，存过的不再覆盖。
render_targets "$staging_dir/rendered"
snapshot_targets "$staging_dir/backup"
if [[ -d "$staging_dir/backup" ]]; then
  command rm -rf "$backup_dir"
  command mv "$staging_dir/backup" "$backup_dir"
  print -- "原样已备份：$backup_dir"
fi

write_targets "$staging_dir/rendered"
print -- "安装完成：$platform，source 后生效。"
