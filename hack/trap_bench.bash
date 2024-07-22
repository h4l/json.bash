#!/usr/bin/env bash
set -euo pipefail

# This tests the cost of setting and clearing traps to handle SIGPIPE around a
# write that needs to avoid terminating the whole process on SIGPIPE. We do this
# in json.validate()

method=${1:-}
count=${2:-10}
readarray text  # read lines from stdin

exec {null_fd}>/dev/null

function write_without_trap() {
  for ((id=0; id<$count; ++id)) do
    for line in "${text[@]}"; do
      echo -n "${line?}" >&"${null_fd:?}"
    done
  done
}

function write_with_one_trap() {
  trap -- '' SIGPIPE
  write_without_trap
  trap - SIGPIPE
}

function write_with_trap() {
  for ((id=0; id<$count; ++id)) do
    for line in "${text[@]}"; do
      trap -- '' SIGPIPE
      echo -n "${line?}" >&"${null_fd:?}"
      trap - SIGPIPE
    done
  done
}

echo "write_${method:?}" >&2
"write_${method:?}"
