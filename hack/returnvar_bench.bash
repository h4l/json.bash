#!/usr/bin/env bash
set -euo pipefail

function greet() {
  message="Hello ${1:-World}"
  outvar=${outvar:-} echo_or_outvar "$message"
}

function echo_or_outvar() {
  if [[ "${outvar:-}" == "" ]];
  then echo "$1"
  else local -n out="${outvar:?}"; out=$1; fi
}

function greet_buffer_output() {
  message="Hello ${1:-World}"
  out=${out:-} buffer_output "$message"
}

function buffer_output() {
  if [[ "${out:-}" == "" ]];
  then echo "$1"
  else local -n __buffer="${out:?}"; __buffer+=("$1"); fi
}

method=${1:-subshell}
count=${2:-10}
name=${3:-}

if [[ ${method:?} == subshell ]]; then
  for ((id=0; id<$count; ++id)) do
    echo "$(greet "$name")"
  done
elif [[ ${method:?} == echo ]]; then
  for ((id=0; id<$count; ++id)) do
    greet "$name"
  done
elif [[ ${method:?} == outvar ]]; then
  for ((id=0; id<$count; ++id)) do
    result=
    outvar=result greet "$name"
    echo "${result:?}"
  done
elif [[ ${method:?} == array ]]; then
  lines=()
  for ((id=0; id<$count; ++id)) do
    result=
    outvar=result greet "$name"
    lines+=("$result")
  done
  IFS=$'\n'; echo "${lines[*]}"
elif [[ ${method:?} == array-cheating ]]; then
  lines=()
  for ((id=0; id<$count; ++id)) do
    result="Hello $name"
    lines+=("$result")
  done
  IFS=$'\n'; echo "${lines[*]}"
elif [[ ${method:?} == echo-cheating ]]; then
  for ((id=0; id<$count; ++id)) do
    echo "Hello $name"
  done
elif [[ ${method:?} == buffer-output ]]; then
  buffer=()
  for ((id=1; id<=$count; ++id)) do
    out=buffer greet_buffer_output "$name"
  done
  IFS=$'\n'; echo "${buffer[*]}"
elif [[ ${method:?} == buffer-output-echo ]]; then
  for ((id=0; id<$count; ++id)) do
    greet_buffer_output "$name"
  done
else
  echo "$0: unsupported method: ${method@A}" >&2
  exit 1
fi
