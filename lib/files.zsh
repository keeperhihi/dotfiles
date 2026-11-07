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

# 备份里的 managed 记下接管过的目标。第一次接管的目标从 HOME 存原样，接管过的沿用已存的原样；
# 没有第一次接管的目标时不创建 destination。
snapshot_targets() {
  local destination="$1" record relative renderer mode source_file
  local -a managed=() fresh=()
  [[ ! -f "$backup_dir/managed" ]] || managed=("${(@f)$(<"$backup_dir/managed")}")
  for record in "${targets[@]}"; do
    read -r relative renderer mode <<< "$record"
    (( ${managed[(Ie)$relative]} )) || fresh+=("$relative")
  done
  (( ${#fresh} )) || return 0

  command mkdir -p -m 700 "$destination"
  for relative in "${managed[@]}" "${fresh[@]}"; do
    if (( ${managed[(Ie)$relative]} )); then
      source_file="$backup_dir/$relative"
    else
      source_file="$home_dir/$relative"
    fi
    if [[ -e "$source_file" || -L "$source_file" ]]; then
      command mkdir -p -m 700 "$destination/${relative:h}"
      # -RP 在 BSD/GNU 上都保留链接本身；-p 保留原文件权限。
      command cp -RPp "$source_file" "$destination/$relative"
    fi
  done
  print -rl -- "${managed[@]}" "${fresh[@]}" > "$destination/managed"
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
