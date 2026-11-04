# install.sh 的文件操作；仅供内部加载。

die() {
  print -u2 -- "错误：$*"
  exit 1
}

require_directory() {
  local label="$1" directory="$2"
  [[ "$directory" == /* && "${directory:A}" != / \
    && "$directory" != *$'\n'* && "$directory" != *$'\t'* \
    && -d "$directory" && ! -L "$directory" ]] \
    || die "$label 必须是存在的绝对目录，且不能是符号链接：$directory"
}

validate_parent_chain() {
  local file_path="$1" root="$2"
  local parent="${file_path:h}"
  while [[ "$parent" == "$root"/* ]]; do
    [[ ! -L "$parent" && ( ! -e "$parent" || -d "$parent" ) ]] \
      || die "父路径必须是普通目录：$parent"
    parent="${parent:h}"
  done
}

validate_targets() {
  local root="$1" record relative renderer mode target
  for record in "${targets[@]}"; do
    read -r relative renderer mode <<< "$record"
    target="$root/$relative"
    validate_parent_chain "$target" "$root"
    [[ ! -e "$target" || -f "$target" || -L "$target" ]] \
      || die "配置目标必须是文件或符号链接：$target"
  done
}

validate_source_tree() {
  local tree="$1" entry
  require_directory 源码 "$tree"
  entry="$(command find "$tree" ! -type d ! -type f -print -quit)"
  [[ -z "$entry" ]] || die "源码不能包含符号链接或特殊文件：$entry"
}

snapshot_targets() {
  local destination="$1" record relative renderer mode target
  command mkdir -p -m 700 "$destination"
  for record in "${targets[@]}"; do
    read -r relative renderer mode <<< "$record"
    target="$home_dir/$relative"
    if [[ -e "$target" || -L "$target" ]]; then
      command mkdir -p -m 700 "$destination/${relative:h}"
      # -RP 在 BSD/GNU 上都保留链接本身；-p 保留原文件权限。
      command cp -RPp "$target" "$destination/$relative"
    fi
  done
}

write_targets() {
  local source_dir="$1" record relative renderer mode source_file target parent
  for record in "${targets[@]}"; do
    read -r relative renderer mode <<< "$record"
    source_file="$source_dir/$relative"
    target="$home_dir/$relative"
    if [[ ! -e "$source_file" && ! -L "$source_file" ]]; then
      # 安装前不存在的文件，在回滚时恢复为不存在。
      command rm -f "$target"
      continue
    fi

    parent="${target:h}"
    command mkdir -p -m 700 "$parent"
    target_staging="$(command mktemp -d "$parent/.dotfiles.XXXXXX")"
    command cp -RPp "$source_file" "$target_staging/config"
    # BSD/GNU mv 都可能进入指向目录的目标链接，先删除链接本身。
    [[ ! -L "$target" ]] || command rm -f "$target"
    command mv -f "$target_staging/config" "$target"
    command rmdir "$target_staging"
    target_staging=''
  done
}
