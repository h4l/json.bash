#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../json.bash"

JSON_TYPE=${JSON_TYPE:-strings}
[[ $JSON_TYPE =~ ^(strings|numbers|bools|nulls)$ ]] || {
    echo "$0: invalid JSON_TYPE: '$JSON_TYPE'" >&2
    exit 1
}
values=$("encode_json_$JSON_TYPE" "$@")
echo "[$values]"
