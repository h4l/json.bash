#!/usr/bin/env bash
set -euo pipefail
# set -f

# Searching
# Matching a regex on a string array is slower (by ~3x in this test) than
# matching against a single string, joined version of the array.
# Similar for globs. Globs match a tiny bit faster in positive match cases, but
# are much slower on negative matches (negative glob match on the joined string
# is about the same as a regex match on the array).
# e.g:
# time cat json.bash | hack/string_search_bench.bash joined $'[\t\n\v\f\r\x01-\x1f]' 10000
#  (alternating joined vs array as the method)

method=${1:-}
pattern=${2:-}
count=${3:-10}
replacement=${4:-__}
readarray text # remove -t to keep line endings

declare -A globs=(
  [control]='['$'\x01'-$'\x1f\t\n\v\f\r'']'
  [control-no-nl]='['$'\x01'-$'\x1f\t\v\f\r'']'
  [control-no-nltab]='['$'\x01'-$'\x1f\v\f\r'']'
  [questionmark]='[?]'
)

if [[ ${text[-1]} == $'\n' ]]; then unset text[-1]; fi
IFS=''; text_joined="${text[*]}"; IFS=' '

function sub_joined() {
  local glob="${globs["${pattern:?}"]:?}"
  for ((id=0; id<$count; ++id)) do
    local subd="${text_joined//$glob/$replacement}"
    # declare -p subd
  done
}

function sub_array() {
  local glob="${globs["${pattern:?}"]:?}"
  for ((id=0; id<$count; ++id)) do
    local subd=("${text[@]//$glob/$replacement}")
    # declare -p subd
  done
}

echo "sub_${method:?}" >&2
"sub_${method:?}"
