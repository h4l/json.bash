#!/usr/bin/env bash
set -euo pipefail

# This is the source of the regex/glob patterns in json.bash.
# Bash doesn't support whitespace in regex patterns, so we define them here with
# whitespace to make them easier to read and edit.

# The arguments to the json() function follow the following grammar. (This is a
# pseudo-grammar notation, I'm not actually using it with any tool.)
#
#   argument     = [ key ] [ type ] [ attributes ] [ value ]
#   value        = inline-value | ref-value
#   key          = inline-key | ref-key
#
#   type         = ":" ( "string" | "number" | "bool" | "true" | "false"
#                      | "null" | "raw" | "auto" )
#
#   inline-key   = key-char-not-hyphen *key-char
#   ref-key      = "@" key-char *key-char
#   key-char     = /^[^\x00-\x1F\\:=@[]/ | escaped-char
#   key-char-not-hyphen
#                = /^[^\x00-\x1F\\:=@[-]/ | escaped-char

#   inline-value = /^=.*/
#   ref-value    = "@" inline-value
#
#   attributes   = "[" [ attr *( "," attr ) ] "]"
#   attr         = attr-name [ "=" attr-value ]
#   attr-name    = *( /^[^],\=]/ | escaped-char )  # ] , \ = must be escaped
#   attr-value   = *( /^[^],\]/  | escaped-char )  # ] , \   must be escaped
#   escaped-char = /^ \\ ( [][,\\:=abceEfnrtv-] | 0[0-7]{0,3} | x[0-9a-fA-F]{1,2}
#                        | u[0-9a-fA-F]{1,4} | U[0-9a-fA-F]{1,8}) ) /
#
# Notes:
# - \x00-\x1F are the control characters
# - ref-key: can't have an empty value to avoid ambiguity with =value rule.
# - inline-value: escape sequences are not expanded. This is to make it easy to
#   append arbitrary content without worrying about escape processing mangling
#   it. Ideally, only human-written syntax elements should have escapes
#   processed.
# - escaped-char: Our escape sequences are those supported by printf %b, plus
#     :=[]@-, (our own reserved characters, to make it easy to escape them).
#     Maybe we should limit escape processing to just our own reserved chars.
#     I was mainly thinking of them being useful to specify the array split
#     character.

# We capture the (non-initial) final escape sequence, so that we can test if any
# escape sequence occurred, and skip un-escaping if not.

# Ref keys start with @ followed by one non-reserved char or escape sequence.
# Non-ref keys can't start with @ or - .
# After the start comes zero or more non-reserved chars or escape sequences.
key=$'
  (
    @ ( ( \\\\ [^\x01-\x1f\t\n\v\f\r] ) | [^\x01-\x1f\t\n\v\f\r:=[\\@] )
    | \\\\ [^\x01-\x1f\t\n\v\f\r]
    | [^\x01-\x1f\t\n\v\f\r:=[\\@-]
  )
  ( ( \\\\ [^\x01-\x1f\t\n\v\f\r] ) | [^\x01-\x1f\t\n\v\f\r:=[\\@] )*
'

type=' : ( auto | bool | false | json | null | number | raw | string | true ) '

# An escape sequence, or anything except \ ] or control chars.
# We capture the final escape sequence so that we can test if any escape
# sequence occurred, and skip un-escaping if not.
attributes=$'
  \[ ( ( \\\\ [^\x01-\x1f\t\n\v\f\r] ) | [^]\x01-\x1f\t\n\v\f\r\\] )* \]
'

value=' @? = (.*) '

argument="
  ^ ( ${key:?} )? ( ${type:?} )? ( ${attributes:?} )? ( ${value:?} )? $
"

# Generate the final pattern used in json.bash (run this script and manually
# insert this output, it doesn't change often.)
printf "_json_bash_arg_pattern=%q\n" "${argument//[$' \n']/}"
printf "_json_bash_attr_entry_pattern='%s'\n" "${attr_entry//[$' \n']/}"
