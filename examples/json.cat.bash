#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../json.bash"

JSON_BUFFER_LINES=${JSON_BUFFER_LINES:-256}
[[ "$JSON_BUFFER_LINES" =~ ^[1-9][0-9]*$ ]] || {
    echo "$0: JSON_BUFFER_LINES must be > 0: '$JSON_BUFFER_LINES'" >&2
    exit 1
}

function emit() {
  if [[ ${#lines[@]} == 0 ]]; then return; fi
  local buff IFS=''
  chunk="${lines[*]}"
  out=buff encode_json_strings "$chunk"
  echo -n "${buff[0]:1:-1}" # strip the quotes — we're emitting one string
  lines=()
}

lines=()
 # Read input with cat, and start it via coproc so that we can react if it errors.
coproc CAT { cat -- "$@"; }
cat_pid=$CAT_PID
printf '"'
# Populate the lines array from the cat process, and call emit produce output
readarray <&"${CAT[0]:?}" -C emit -c "${JSON_BUFFER_LINES:?}" lines
emit  # there can be lines remaining
printf '"\n'

# Fail if cat failed (e.g. missing file)
wait $cat_pid || { status=$?; echo "$0: failed to read input" >&2; exit $status; }
