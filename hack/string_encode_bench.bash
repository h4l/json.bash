#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../json.bash"

count=${COUNT:?}
out_method=${OUT_METHOD:-echo}


echo "${count@A} ${out_method@A}" >&2

if [[ $out_method == echo ]]; then
  for ((id=0; id<$count; ++id)) do
    out= join=, json.encode_strings "$@"
  done
elif [[ $out_method == buffer ]]; then
  for ((id=0; id<$count; ++id)) do
    buffer=()
    out=buffer json.encode_strings "$@"
  done
else
  echo "$0: unknown ${out_method@A}" >&2
  exit 1
fi
