#!/usr/bin/env zsh

emulate -LR zsh
# 函数内因 ERR_EXIT 退出时，也必须执行全局清理钩子。
setopt ERR_EXIT NO_UNSET PIPE_FAIL POSIX_TRAPS
umask 077

usage() {
  print -- '用法：./install.sh [-r]'
  print -- '  无参数  备份当前配置，然后安装'
  print -- '  -r      覆盖恢复最近一次备份，成功后删除备份'
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

validate_targets "$home_dir"
validate_parent_chain "$backup_dir" "$home_dir"
[[ ! -L "$backup_dir" && ( ! -e "$backup_dir" || -d "$backup_dir" ) ]] \
  || die "备份路径必须是普通目录：$backup_dir"

if [[ "$action" == restore ]]; then
  [[ -d "$backup_dir" ]] || die '没有可回滚的备份'
  validate_targets "$backup_dir"
  write_targets "$backup_dir"
  command rm -rf "$backup_dir"
  print -- '回滚完成，备份已清理，source 后生效。'
  exit 0
fi

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

# 渲染和备份全部成功后，才替换上一次备份并开始写入 HOME。
render_targets "$staging_dir/rendered"
snapshot_targets "$staging_dir/backup"
command rm -rf "$backup_dir"
command mv "$staging_dir/backup" "$backup_dir"
print -- "备份完成：$backup_dir"

write_targets "$staging_dir/rendered"
print -- "安装完成：$platform，source 后生效。"
