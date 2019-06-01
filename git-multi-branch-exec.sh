#!/usr/bin/env bash
set -eu
set -o pipefail

BLACK=$'\e[30m' RED=$'\e[31m' GREEN=$'\e[32m' YELLOW=$'\e[33m' BLUE=$'\e[34m' PURPLE=$'\e[35m' LIGHT_BLUE=$'\e[36m' WHITE=$'\e[37m' GRAY=$'\e[90m' DEFAULT=$'\e[0m'
function echo_log() {
  echo "${GREEN}[LOG][$GIT_MULTI_BRANCH_EXECUTER_LOG_NAME]${DEFAULT}" "$@" 1>&2
}

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
  [[ $# -lt 1 ]] && echo "-y <path to yml>" 1>&2 && exit 1
  setting_filepath="$(abspath $1)"
  shift 1
fi
[[ $# -lt 1 ]] && echo "$(basename "$0") command" 1>&2 && exit 1
cmd="$1"

app_name="git-multi-branch-executer"
repo_name_suffix=${GIT_MULTI_BRANCH_EXECUTER_SUFFIX_NAME:-_$(date +'%Y-%m-%d-%H-%M-%S')}
repo_name=$(basename $(git rev-parse --show-toplevel))
GIT_MULTI_BRANCH_EXECUTER_LOG_NAME=""

if [[ ! -e $setting_filepath ]]; then
  echo "no setting file: $setting_filepath" 1>&2
  echo "use -y <path to yml>" 1>&2
  exit 1
fi

repo_root=$(git rev-parse --show-toplevel)
relative_setting_filepath=${setting_filepath#$repo_root}
relative_setting_filename=$(basename $relative_setting_filepath)
relative_working_dirpath=$(dirname $relative_setting_filepath)

function echo_tmp_git_repo() {
  local name=$1
  local tmpdir="$HOME/.cache/${app_name}/${repo_name}${repo_name_suffix}"
  echo "$tmpdir"
}

function clean_tmp_git_repo() {
  local name=$1
  echo_log "clean: pattern name is $name"
  local tmpdir=$(echo_tmp_git_repo "$name")
  local new_root="$tmpdir/$name"
  [[ $(basename "$new_root") == ".cache" ]] && echo "invalid tmpdir" 1>&2 && return 1
  rm -rf "$new_root"
}

function new_git_repo() {
  local name=$1
  echo_log "new: pattern name is $name"

  local tmpdir=$(echo_tmp_git_repo "$name")
  echo_log "tmpdir is $tmpdir"
  mkdir -p "$tmpdir"
  local repo_root=$(git rev-parse --show-toplevel)
  local new_root="$tmpdir/$name"
  echo_log "copy $repo_root to $new_root"
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
  echo_log "init: pattern name is $name"
  local yml_data=$(yq -r 'map(select(.["name"] == "'"$name"'"))' "$relative_setting_filename")
  echo_log "yml data of $name"
  echo_log "$yml_data"
  local checkout=$(printf '%s' "$yml_data" | yq -r '.[].checkout')
  if [[ -n "$checkout" ]] && [[ "$checkout" != "null" ]]; then
    echo_log "checkout $checkout with git stash"
    git stash
    git checkout "$checkout"
    git stash pop
  else
    echo_log "no checkout"
  fi
}

function apply_patches() {
  local name=${1-:$(basename $PWD)}
  echo_log "apply patches: pattern name is $name"
  local ret=$(echo_patches "$name")
  for patch in $(printf '%s' "$ret"); do
    echo_log "apply $patch"
    cat $patch | git apply
  done
}

function run_scripts() {
  local name=${1-:$(basename $PWD)}
  echo_log "run scripts: pattern name is $name"
  local ret=$(echo_run_scripts "$name")
  export GIT_MULTI_BRANCH_EXECUTER_NAME=$name
  # -r: Backslash  does not act as an escape character.  The backslash is considered to be part of the line. In particular, a backslash-newline pair can not be used as a line continuation.
  printf '%s' "$ret" | tr '\t' '\n' | while IFS= read -r script || [[ -n "$script" ]]; do
    i=${i:-0}
    local log_file=".${app_name}_run_scripts_$i.log"
    echo_log "run $script > $log_file"
    eval "$script" | tee "$log_file"
    i=$((i + 1))
  done
}

if [[ $cmd == "new" ]]; then
  shift
  for name in $(echo_pattern_names); do
    GIT_MULTI_BRANCH_EXECUTER_LOG_NAME="$name"
    new_git_repo "$name"
  done
  cmd='info'
elif [[ $cmd == "clean" ]]; then
  shift
  for name in $(echo_pattern_names); do
    GIT_MULTI_BRANCH_EXECUTER_LOG_NAME="$name"
    clean_tmp_git_repo "$name"
  done
  cmd='info'
fi

if [[ $cmd == "info" ]]; then
  for name in $(echo_pattern_names); do
    GIT_MULTI_BRANCH_EXECUTER_LOG_NAME="$name"
    echo_log "see $(echo_tmp_git_repo $name)/$name"
  done
  exit $?
fi

echo 1>&2 "Unknown command '$cmd'"
