#!/usr/bin/env bash
set -euo pipefail

# This is the source of the regex/glob patterns in json.bash.
# Bash doesn't support whitespace in regex patterns, so we define them here with
# whitespace to make them easier to read and edit.

# The arguments to the json() function follow grammar defined in
# docs/plans/005-revised-syntax.md.

type_name=' ( auto | bool | false | json | null | number | raw | string | true ) '

# The argument syntax from plans/005-revised-syntax.md
function argument_005() {
  splat=" \.* "
  # unambiguous_key_start=' [^@=:] '
  lenient_flags=" [+~?]* "
  lenient_optional_value_flags=" ( [+~?]* ) ( [@=]? ) "
  #key_prefix=" ( ${lenient_flags:?} ) "
  key_start=" [^.+~?:] " # not a splat, flag or meta-start char


  key_escape=' ( :: | == | @@ ) ' # only need to group this if it helps the decoder
  key_char=" ${key_escape:?} | [^:=@] "
  inline_key=" ( ${key_char:?} )* "

  # We don't attempt to match flags that could be part of a following value. We
  # can do that retroactively and steal them from the key if necessary.
  # p1_key is a key at the start of the argument, up to a subsequent meta or val
  p1_key="^ ( ${splat:?} ) ( ( $ | : ) | ( ${lenient_flags:?} ) ( ${key_start:?} ${inline_key:?} )? )"

  lenient_type_name=' [a-zA-Z0-9]+ '
  collection_marker=' \[.?\] | \{.?\} '
  # The attributes without matching the individual entries. Anything except /,
  # but / can be escaped with //. We capture ,, and == escapes so that we can
  # detect if no escapes are present and skip decoding escapes if so.
  attributes=$' / ( ( // | ,, | == ) | [^/] )* / '

  # p2_meta is 2nd section of the argument grammar — the metadata section
  p2_meta=" ^ : ( ${lenient_type_name:?} )? ( ${collection_marker:?} )? ( ${attributes} )? "

  # p3_value is the 3rd section — the value (the flags and = or @ prefixing it
  # (unless no value follows))
  p3_value=" ^ ${lenient_optional_value_flags:?} "

  strict_flags=" ^ \+? ~? \?{0,2} [@=] $ "
  strict_type_name=' ^ ( auto | bool | false | json | null | number | raw | string | true ) $ '

  format_regex_var _json_bash_005_strict_flags "^ ${strict_flags:?}"
  format_regex_var _json_bash_005_strict_type_name "^ ${strict_type_name:?}"

  format_regex_var _json_bash_005_p1_key "${p1_key:?}"
  format_regex_var _json_bash_005_p2_meta "${p2_meta:?}"
  format_regex_var _json_bash_005_p3_value "${p3_value:?}"
}

function bash_quote() {
  local quoted
  # Force bash to use $'...' syntax by including a non-printable character.
  val=$'\x01'"$1"
  printf -v quoted '%q' "${val:?}"
  if [[ ! $quoted =~ ^\$\'\\001 ]]; then
    echo "bash_quote(): printf quoted the string in an unexpected way: quoted: ${quoted}, input: ${1@Q}"
    return 1
  fi
  printf '%s' "${quoted/#"$'\001"/"$'"}"
}

function format_regex_var() {
  local var=${1:?} regex=${2:?}
  printf "%s=%s\n" "${var:?}" "$(bash_quote "${regex//[$' \n']/}")"
}

# Generate the final pattern used in json.bash (run this script and manually
# insert this output, it doesn't change often.)
argument_005
format_regex_var _json_bash_type_name_pattern "^ ${type_name:?} $"
