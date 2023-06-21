#!/usr/bin/env bash
set -euo pipefail

_json_bash=$(command -v json.bash || "$(dirname "${BASH_SOURCE[0]}")/../json.bash" )
# shellcheck source=../json.bash
source "${_json_bash:?}"

method=${1:-json.bash}
count=${2:-10}
data=$(cat ${BASH_SOURCE[0]})
if [[ ${method:?} == json.bash ]]; then
  echo json.bash >&2
  for ((id=0; id<$count; ++id)) do
    json @id:number @data
  done
elif [[ ${method:?} == custom-forking-json.bash ]]; then
  echo custom-json.bash >&2
  # Use json.bash's encode_json_strings function to manually construct JSON
  for ((id=0; id<$count; ++id)) do
    data_json=$(encode_json_strings "$data")
    printf '{"id":%d,"data":%s}\n' "${id:?}" "${data_json:?}"
  done
elif [[ ${method:?} == custom-json.bash ]]; then
  echo custom-json.bash >&2
  # Use json.bash's encode_json_strings function to manually construct JSON
  IFS=
  for ((id=0; id<$count; ++id)) do
    data_json=()
    out=data_json encode_json_strings "$data"
    printf '{"id":%d,"data":%s}\n' "${id:?}" "${data_json[*]:?}"
  done
elif [[ ${method:?} == jq ]]; then
  echo jq >&2
  for ((id=0; id<$count; ++id)) do
    jq -nMec --arg id "$id" --arg data "$data" '{id: ($id | tonumber), $data}'
  done
elif [[ ${method:?} == jo ]]; then
  echo jo >&2
  for ((id=0; id<$count; ++id)) do
    jo -- -n id="$id" -s data="$data"
  done
else
  echo "$0: unsupported method: ${method@A}" >&2
  exit 1
fi
