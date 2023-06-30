#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../json.bash"

count=${COUNT:?}
method=${METHOD:-echo}

readarray -t strings

echo "${count@A} ${method@A} #strings=${#strings[@]}" >&2

if [[ $method == out=echo,in=args ]]; then
  for ((id=0; id<$count; ++id)) do
    out= join=, json.encode_string "${strings[@]}"
  done
elif [[ $method == out=echo,in=array ]]; then
  for ((id=0; id<$count; ++id)) do
    out= join=, in=strings json.encode_string
  done
elif [[ $method == out=buffer,in=args ]]; then
  for ((id=0; id<$count; ++id)) do
    buffer=()
    out=buffer json.encode_string "${strings[@]}"
  done
elif [[ $method == out=buffer,in=array ]]; then
  for ((id=0; id<$count; ++id)) do
    buffer=()
    out=buffer in=strings json.encode_string
  done
else
  echo "$0: unknown ${method@A}" >&2
  exit 1
fi
