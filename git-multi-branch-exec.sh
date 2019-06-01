#!/usr/bin/env bash
set -eux

! git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo 1>&2 "run in git repo" && exit 1

# NOTE: required yq

# ----
# util function
# ----

function abspath() {
  local target=${1:-.}
  if [[ $(uname) == "Darwin" ]]; then
    if [[ $target =~ ^/.* ]]; then
      printf '%s' "$target"
    else
      printf '%s' "$PWD/${target#./}"
    fi
  else
    readlink -f $target
  fi
}

# ----

setting_filepath="git-multi-branch-exec.yml"
if [[ $1 == '-y' ]]; then
  shift 1
  [[ $# -lt 1 ]] && echo "-y <path to yml>" 2>&1 && exit 1
  setting_filepath="$(abspath $1)"
  shift 1
fi
[[ $# -lt 1 ]] && echo "$(basename "$0") command" 2>&1 && exit 1
cmd="$1"

app_name="git-multi-branch-executer"
app_name_suffix=${GIT_MULTI_BRANCH_EXECUTER_SUFFIX_NAME:-_$(date +'%Y-%m-%d-%H-%M-%S')}
repo_name=$(basename $(git rev-parse --show-toplevel))

if [[ ! -e $setting_filepath ]]; then
  echo "no setting file: $setting_filepath" 2>&1
  echo "use -y <path to yml>" 2>&1
  exit 1
fi

repo_root=$(git rev-parse --show-toplevel)
relative_setting_filepath=${setting_filepath#$repo_root}
relative_setting_filename=$(basename $relative_setting_filepath)
relative_working_dirpath=$(dirname $relative_setting_filepath)

function echo_tmp_git_repo() {
  local name=$1
  local tmpdir="$HOME/.cache/${app_name}${app_name_suffix}/$repo_name"
  echo "$tmpdir"
}

function clean_tmp_git_repo() {
  local name=$1
  local tmpdir=$(echo_tmp_git_repo "$name")
  local new_root="$tmpdir/$name"
  [[ $(basename "$new_root") == ".cache" ]] && echo "invalid tmpdir" 2>&1 && return 1
  rm -rf "$new_root"
}

function new_git_repo() {
  local name=$1
  local tmpdir=$(echo_tmp_git_repo "$name")
  echo "[LOG] tmpdir is $tmpdir" 2>&1
  mkdir -p "$tmpdir"
  local repo_root=$(git rev-parse --show-toplevel)
  local new_root="$tmpdir/$name"
  echo "[LOG] new $repo_root to $new_root" 2>&1
  cp -r "$repo_root" "$new_root"

  local _PWD="$PWD"
  cd "$new_root/$relative_working_dirpath"
  init "$name" | tee ".${app_name}_init.log"
  apply_patches "$name" | tee ".${app_name}_apply_patches.log"
  run_scripts "$name" | tee ".${app_name}_run_scripts.log"
  cd "$_PWD"
}

function echo_filtered_param() {
  local name="$1"
  local target="$2"
  yq -r -c 'map(select(.["name"] == "'"$name"'")) | .[].'"$target"' | @tsv' "$relative_setting_filename"
}
function echo_patches() {
  local name="$1"
  echo_filtered_param "$name" "patches"
}
function echo_run_scripts() {
  local name="$1"
  echo_filtered_param "$name" "scripts"
}

function echo_pattern_names() {
  yq -r '.[].name' "$relative_setting_filename"
}

# NOTE: cpされたディレクトリ上のWDで実行されることを意図するscript
function init() {
  local name=${1-:$(basename $PWD)}
  local yml_data=$(yq -r 'map(select(.["name"] == "'"$name"'"))' "$relative_setting_filename")
  echo "[LOG] yml data of $name" 2>&1
  echo $yml_data
  local checkout=$(printf '%s' "$yml_data" | yq -r '.[].checkout')
  if [[ -n "$checkout" ]] && [[ "$checkout" != "null" ]]; then
    echo "[LOG] checkout $checkout with git stash" 2>&1
    git stash
    git checkout "$checkout"
    git stash pop
  else
    echo "[LOG] no checkout" 2>&1
  fi
}

function apply_patches() {
  local name=${1-:$(basename $PWD)}
  local ret=$(echo_patches "$name")
  for patch in $(printf '%s' "$ret"); do
    echo $patch
    cat $patch | git apply
  done
}

function run_scripts() {
  local name=${1-:$(basename $PWD)}
  local ret=$(echo_run_scripts "$name")
  export GIT_MULTI_BRANCH_EXECUTER_NAME=$name
  for script in $(printf '%s' "$ret"); do
    echo $script
    eval "$script"
  done
}

# TODO: Add clean command

if [[ $cmd == "new" ]]; then
  shift
  for name in $(echo_pattern_names); do
    echo "[LOG] new: pattern name $name"
    new_git_repo "$name"
  done
  exit $?
elif [[ $cmd == "clean" ]]; then
  shift
  for name in $(echo_pattern_names); do
    echo "[LOG] clean: pattern name $name"
    clean_tmp_git_repo "$name"
  done
  exit $?
fi

echo 1>&2 "Unknown command '$cmd'"
