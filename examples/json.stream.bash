#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../json.bash"

JSON_TYPE=${JSON_TYPE:-string}
[[ $JSON_TYPE =~ ^(string|number|bool|null|true|false|auto)$ ]] || {
    echo "$0: invalid JSON_TYPE: '$JSON_TYPE'" >&2
    exit 1
}
JSON_BUFFER_LINES=${JSON_BUFFER_LINES:-256}
[[ "$JSON_BUFFER_LINES" =~ ^[1-9][0-9]*$ ]] || {
    echo "$0: JSON_BUFFER_LINES must be > 0: '$JSON_BUFFER_LINES'" >&2
    exit 1
}

function emit() {
  if [[ ${#lines[@]} == 0 ]]; then return; fi
  join=$'\n' out= "encode_json_${JSON_TYPE}s" "${lines[@]}"
  printf '\n'
  lines=()
}

lines=()
readarray -t -C emit -c "${JSON_BUFFER_LINES:?}" lines
emit