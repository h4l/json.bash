#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../json.bash"

count=${COUNT:?}
method=${METHOD:?}

function pass_array_in_args() {
  local IFS=','; echo "${*}"
}

function pass_array_by_arg_ref() {
  local -n _array=${1:?}
  local IFS=','; echo "${_array[*]}"
}

function pass_array_by_env_ref() {
  local -n _array=${in:?}
  local IFS=','; echo "${_array[*]}"
}

readarray -t values

echo "${count@A} ${method@A} #values=${#values[@]}" >&2

if [[ $method == array-in-args ]]; then
  for ((id=0; id<$count; ++id)) do
    pass_array_in_args "${values[@]}"
  done
elif [[ $method == array-by-arg-ref ]]; then
  for ((id=0; id<$count; ++id)) do
    pass_array_by_arg_ref "values"
  done
elif [[ $method == array-by-env-ref ]]; then
  for ((id=0; id<$count; ++id)) do
    in=values pass_array_by_env_ref
  done
else
  echo "$0: unknown ${method@A}" >&2
  exit 1
fi
