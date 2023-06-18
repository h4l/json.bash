#!/usr/bin/env bash
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../json.bash"

echo "[$(encode_json_strings "$@")]"
