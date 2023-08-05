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
  collection_marker=' [{[] (.?) ( : [a-zA-Z0-9_]+ )? []}] '
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

function _object_pattern() {
  type=${1:?'<type> argument not set'}
  echo "(?&ws) \{ (?:
    (?<entry_${type:?}> (?&ws) (?&str) (?&ws) : (?&ws) (?&${type:?}) )
    (?: (?&ws) , (?&entry_${type:?}) )*+
  )?+ (?&ws) \} (?&ws) "
}

function _array_pattern() {
  type=${1:?'<type> argument not set'}
  echo "(?&ws) \[
    (?: (?&ws) (?&${type:?}) (?: (?&ws) , (?&ws) (?&${type:?}) )*+ )?+ (?&ws)
  \] (?&ws)"
}

#
function json_validation_request() {
  local ws string number atom array object json validation_request
  # This is a PCRE regex that matches JSON. This is possible because we use
  # PCRE's recursive patterns to match JSON's nested constructs. And also
  # possessive repetition quantifiers to prevent expensive backtracking on match
  # failure. Backtracking is not required to parse JSON as it's not ambiguous.
  # If a rule fails to match, the input is known to be invalid, there's no
  # possibility of an alternate rule matching, so backtracking is pointless.
  ws='(?<ws> [\x20\x09\x0A\x0D]*+ )'  # space, tab, new line, carriage return
  string='(?<str> " (?:
    [^\x00-\x1F"\\]
    | \\ (?: ["\\/bfnrt] | u [A-Fa-f0-9]{4} )
  )*+ " )'
  number='(?<num>  -?+ (?: 0 | [1-9][0-9]*+ ) (?: \. [0-9]*+ )?+ (?: [eE][+-]?+[0-9]++ )?+ )'
  atom="true | false | null | ${number:?} | ${string:?}"
  array='\[  (?: (?&ws) (?&json) (?: (?&ws) , (?&ws) (?&json) )*+ )?+ (?&ws) \]'
  object='\{ (?:
    (?<entry> (?&ws) (?&str) (?&ws) : (?&ws) (?&json) )
    (?: (?&ws) , (?&entry) )*+
  )?+ (?&ws) \}'
  json="(?<json> ${array:?} | ${object:?} | (?&atom) )"

  validation_request="
    (:? (?<bool> true | false ) (?<true> true ) (?<false> false ) (?<null> null )
        (?<atom> ${atom:?} ) ${ws:?} ${json:?}
    ){0}
    ^ [\w]++ (?:
      (?= (
        (?<pair> : (?&pair)?+ \x1E (?:
            j  (?&ws) (?&json)  (?&ws)
          | s  (?&ws) (?&str)   (?&ws)
          | n  (?&ws) (?&num)   (?&ws)
          | b  (?&ws) (?&bool)  (?&ws)
          | t  (?&ws) (?&true)  (?&ws)
          | f  (?&ws) (?&false) (?&ws)
          | z  (?&ws) (?&null)  (?&ws)
          | a  (?&ws) (?&atom)  (?&ws)
          | Oj $(_object_pattern json)
          | Os $(_object_pattern str)
          | On $(_object_pattern num)
          | Ob $(_object_pattern bool)
          | Ot $(_object_pattern true)
          | Of $(_object_pattern false)
          | Oz $(_object_pattern null)
          | Oa $(_object_pattern atom)
          | Aj $(_array_pattern json)
          | As $(_array_pattern str)
          | An $(_array_pattern num)
          | Ab $(_array_pattern bool)
          | At $(_array_pattern true)
          | Af $(_array_pattern false)
          | Az $(_array_pattern null)
          | Aa $(_array_pattern atom)
        ) ) $
      )
      ) :++
    )?+"

  format_regex_var validation_request "${validation_request:?}"
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
json_validation_request
format_regex_var _json_bash_type_name_pattern "^ ${type_name:?} $"
