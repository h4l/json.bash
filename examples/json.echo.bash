#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../json.bash"
# Print a JSON array containing the program's command-line arguments.

JSON_TYPE=${JSON_TYPE:-string}
[[ $JSON_TYPE =~ ^(string|number|bool|null|true|false|auto)$ ]] || {
    echo "$0: invalid JSON_TYPE: '$JSON_TYPE'" >&2
    exit 1
}
values=()
out=values "encode_json_${JSON_TYPE}s" "$@"
IFS=,; echo "[${values[*]}]"
