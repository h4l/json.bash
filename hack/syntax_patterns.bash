#!/usr/bin/env bash
set -euo pipefail

# This is the source of the regex/glob patterns in json.bash.
# Bash doesn't support whitespace in regex patterns, so we define them here with
# whitespace to make them easier to read and edit.

# The arguments to the json() function follow the following grammar. (This is a
# pseudo-grammar notation, I'm not actually using it with any tool.)
#
#   argument     = [ key ] [ type ] [ attributes ] [ value ]
#   value        = ref-value | inline-value
#   key          = ref-key | inline-key
#
#   type         = ":" ( "string" | "number" | "bool" | "true" | "false"
#                      | "null" | "raw" | "auto" )
#
#   inline-key   = *key-char
#   ref-key      = "@" key-char *key-char
#   key-char     = /^[^:=@[]/ | key-escape
#   key-escape   = ( "::" | "==" | "@@" | "[[" )
#
#   inline-value = /^=.*/
#   ref-value    = "@" inline-value
#
#   attributes   = "[" [ attr *( "," attr ) ] "]"
#   attr         = attr-name [ "=" attr-value ]
#   attr-name    = *( /^[^],=]/ | attr-name-escape )   # ] , \ = must be escaped
#   attr-value   = *( /^[^],]/  | attr-value-escape )  # ] , must be escaped
#
#   attr-name-escape  = ( "==" | ",," | "]]" )
#   attr-value-escape = ( ",," | "]]" )
#
# Notes:
# - ref-key: can't have an empty value to avoid ambiguity with =value rule.
# - Escaping: We use doubles of reserved characters to escape them. e.g. the key
#   @@foo::bar becomes @foo:bar.
#
#   - Escapes only apply in contexts where the characters are reserved. So keys
#     don't reserve the ] character, and attributes don't reserve the [
#     character. A natural result of this is that the final values have no
#     escape sequences, as there are no further syntax elements beyond them that
#     could conflict.
#
# We capture the (non-initial) final escape sequence, so that we can test if any
# escape sequence occurred, and skip un-escaping if not.

# Ref keys start with @ followed by one non-reserved char or escape sequence.
# Non-ref keys can't start with @ or - .
# After the start comes zero or more non-reserved chars or escape sequences.
key=$'
  ( @ ( :: | == | @@ | \[\[ | [^:=[@] ) )?
  ( ( :: | == | @@ | \[\[ ) | [^:=[@] )*
'

type_name=' ( auto | bool | false | json | null | number | raw | string | true ) '
type=" : ${type_name:?} "

# The attributes without matching the individual entries. Anything except  ],
# except ] can be escaped with ]]. We capture ,, and == escapes so that we can
# detect if no escapes are present and skip decoding escapes if so.
attributes=$' \[ ( ( \]\] | ,, | == ) | [^]] )* \] '

# Don't match or capture the arg value as we can retrieve it with a substring
# starting from the length of the overall argument match.
value=' @? = '

argument="
  ^ ( ${key:?} )? ( ${type:?} )? ( ${attributes:?} )? ( ${value:?} | $ )
"

# A reduced and more-common subset of the argument syntax that we can parse
# more efficiently. No escapes, no named attributes.
function simple_argument() {
  local key=$'
    ( @ [^:=[@]+ ) | ( [^:=[@]+ )
  '
  local type=' : ( auto | bool | false | json | null | number | raw | string | true ) '
  local attributes=$'
    ( \[ ([^]:=[@,])? \] )
  '
  local value=' ( @? = ) ( [^=] .? | $ ) '

  echo "
    ^ ( ${key:?} )? ( ${type:?} )? ( ${attributes:?} )? ( ${value:?} | $ )
  "
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
format_regex_var __attributes "${attributes:?}"
format_regex_var _json_bash_arg_pattern "${argument:?}"
format_regex_var _json_bash_simple_arg_pattern "$(simple_argument)"
format_regex_var _json_bash_type_name_pattern "^ ${type_name:?} $"
