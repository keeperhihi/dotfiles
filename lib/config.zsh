# install.sh 的目标清单与配置渲染；仅供内部加载。
# 每条记录依次为 HOME 相对路径、renderer、安装权限。所有目标均备份。
typeset -a targets=(
  '.zshrc zshrc 600'
  '.zprofile zprofile 600'
  '.config/zsh/interactive.zsh interactive 600'
  '.config/zsh/profile.zsh profile 600'
  '.zimrc zimrc 644'
  '.vimrc vimrc 644'
  '.gitconfig gitconfig 600'
  '.npmrc npmrc 600'
  '.ssh/config ssh_config 600'
  '.config/gh/config.yml gh_config 644'
)

safe_relative_path() {
  local value="$1" component
  [[ -n "$value" && "$value" != /* && "$value" != *$'\n'* \
    && "$value" != *$'\t'* && "$value" != *'//'* ]] || return 1
  for component in "${(@s:/:)value}"; do
    [[ -n "$component" && "$component" != . && "$component" != .. \
      && "$component" != -* ]] || return 1
  done
}

manifest_sources() {
  local section="$1" key="$2"
  local manifest="$repo_dir/apps/zsh/manifest.toml"
  local line trimmed rest value
  local -i in_section=0 collecting=0 found=0
  manifest_fragments=()
  setopt localoptions extendedglob

  # manifest 使用简单双引号路径数组；顺序由文件本身决定。
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%\#*}"
    trimmed="${line##[[:space:]]#}"
    trimmed="${trimmed%%[[:space:]]#}"
    if [[ "$trimmed" == "[$section]" ]]; then
      in_section=1
      collecting=0
      continue
    fi
    if [[ "$trimmed" == \[*\] ]]; then
      in_section=0
      collecting=0
      continue
    fi
    (( in_section )) || continue

    if (( ! collecting )); then
      [[ "$trimmed" == "$key"* ]] || continue
      rest="${trimmed#$key}"
      rest="${rest##[[:space:]]#}"
      [[ "$rest" == '='* ]] || continue
      rest="${rest#=}"
      rest="${rest##[[:space:]]#}"
      [[ "$rest" == \[* ]] || die "manifest 数组格式无效：[$section].$key"
      collecting=1
      found=1
    else
      rest="$trimmed"
    fi

    while [[ "$rest" == *\"* ]]; do
      rest="${rest#*\"}"
      [[ "$rest" == *\"* ]] || die "manifest 存在未闭合字符串：$manifest"
      value="${rest%%\"*}"
      safe_relative_path "$value" || die "manifest 路径不安全：$value"
      manifest_fragments+=("$value")
      rest="${rest#*\"}"
    done
    [[ "$rest" == *\]* ]] && collecting=0
  done < "$manifest"

  (( found && ! collecting && ${#manifest_fragments[@]} > 0 )) \
    || die "manifest 缺少完整的非空数组：[$section].$key"
}

append_fragment() {
  local source_file="$1" output="$2"
  [[ -f "$source_file" && ! -L "$source_file" ]] \
    || die "源码片段必须是普通文件：$source_file"
  command cat "$source_file" >> "$output"
  # 防止没有末尾换行的片段与下一段粘连。
  print -r >> "$output"
}

render_zsh() {
  local section="$1" output="$2"
  local group root fragment source_file
  local -a manifest_fragments
  print -r -- '# 由 install.sh 生成；请编辑 apps/zsh 或 private/zsh。' > "$output"
  print -r >> "$output"
  for group in shared "$platform" private; do
    root="$repo_dir/apps/zsh"
    [[ "$group" != private ]] || root="$private_dir/zsh"
    manifest_sources "$section" "$group"
    for fragment in "${manifest_fragments[@]}"; do
      source_file="$root/$fragment"
      if [[ "$group" == private && ! -e "$source_file" && ! -L "$source_file" ]]; then
        continue
      fi
      append_fragment "$source_file" "$output"
    done
  done
}

# 默认启动文件只持有加载入口；其他工具的区块留在入口文件中。
render_zsh_entry() {
  local relative="$1" fragment="$2" output="$3"
  shell_remainder "$home_dir/$relative" "$output"
  local remainder="$(<"$output")"
  {
    print -r -- '# >>> dotfiles >>>'
    print -r -- "source \"\$HOME/.config/zsh/$fragment.zsh\""
    print -r -- '# <<< dotfiles <<<'
    if [[ -n "$remainder" ]]; then
      print -r
      print -r -- "$remainder"
    fi
  } > "$output"
}

render_plain() {
  local renderer="$1" output="$2"
  local shared_file private_file='' comment
  case "$renderer" in
    zimrc)
      shared_file="$repo_dir/apps/zsh/shared/modules/zim.zsh"
      comment='# 由 install.sh 生成；请编辑 apps/zsh/shared/modules/zim.zsh。'
      ;;
    vimrc)
      shared_file="$repo_dir/apps/vim/vimrc"
      private_file="$private_dir/vim/vimrc"
      comment='" 由 install.sh 生成；请编辑 apps/vim 或 private/vim。'
      ;;
    gitconfig)
      shared_file="$repo_dir/apps/git/gitconfig"
      private_file="$private_dir/git/gitconfig"
      comment='# 由 install.sh 生成；请编辑 apps/git 或 private/git。'
      ;;
    npmrc)
      shared_file="$repo_dir/apps/npm/npmrc"
      private_file="$private_dir/npm/npmrc"
      comment='# 由 install.sh 生成；请编辑 apps/npm 或 private/npm。'
      ;;
    ssh_config)
      shared_file="$repo_dir/apps/ssh/config"
      private_file="$private_dir/ssh/config"
      comment='# 由 install.sh 生成；请编辑 apps/ssh 或 private/ssh。'
      ;;
    gh_config)
      shared_file="$repo_dir/apps/gh/config.yml"
      comment='# 由 install.sh 生成；请编辑 apps/gh/config.yml。'
      ;;
    *) die "未知 renderer：$renderer" ;;
  esac

  print -r -- "$comment" > "$output"
  print -r >> "$output"
  # OpenSSH 采用先出现的值，私有配置放在共享默认值之前。
  [[ "$renderer" == ssh_config ]] || append_fragment "$shared_file" "$output"
  if [[ -n "$private_file" && ( -e "$private_file" || -L "$private_file" ) ]]; then
    append_fragment "$private_file" "$output"
  fi
  [[ "$renderer" != ssh_config ]] || append_fragment "$shared_file" "$output"
}

render_targets() {
  local destination="$1" record relative renderer mode output
  for record in "${targets[@]}"; do
    read -r relative renderer mode <<< "$record"
    output="$destination/$relative"
    command mkdir -p -m 700 "${output:h}"
    case "$renderer" in
      zshrc) render_zsh_entry .zshrc interactive "$output" ;;
      zprofile) render_zsh_entry .zprofile profile "$output" ;;
      interactive|profile) render_zsh "$renderer" "$output" ;;
      *) render_plain "$renderer" "$output" ;;
    esac
    command chmod "$mode" "$output"
  done
}
