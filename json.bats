#!/usr/bin/env bats
# shellcheck shell=bash
set -u -o pipefail

load json.bash

setup() {
  cd "${BATS_TEST_DIRNAME:?}"
}

function mktemp_bats() {
  mktemp "${BATS_RUN_TMPDIR:?}/json.bats.XXX" "$@"
}

@test "json.buffer_output :: out stream :: in args" {
  [[ $(json.buffer_output foo) == "foo" ]]
  [[ $(json.buffer_output foo "bar baz" $'boz\n123') == $'foobar bazboz\n123' ]]
}

@test "json.buffer_output :: out stream :: in array" {
  local input=(foo)
  [[ $(in=input json.buffer_output) == "foo" ]]
  input=(foo "bar baz" $'boz\n123')
  [[ $(in=input json.buffer_output) == $'foobar bazboz\n123' ]]
}

@test "json.buffer_output :: out array :: in array" {
  local buff input=()
  out=buff in=input json.buffer_output
  [[ ${#buff[@]} == 0 ]]

  input=(foo)
  out=buff in=input json.buffer_output
  [[ ${#buff[@]} == 1 && ${buff[0]} == "foo" ]]

  input=("bar baz" $'boz\n123')
  out=buff in=input json.buffer_output
  [[ ${#buff[@]} == 3 && ${buff[0]} == "foo" && ${buff[1]} == "bar baz" \
    && ${buff[2]} == $'boz\n123' ]]
}

@test "json.buffer_output :: out array :: in args" {
  local buff input=()

  out=buff json.buffer_output "foo"
  [[ ${#buff[@]} == 1 && ${buff[0]} == "foo" ]]

  out=buff json.buffer_output "bar baz" $'boz\n123'
  [[ ${#buff[@]} == 3 && ${buff[0]} == "foo" && ${buff[1]} == "bar baz" \
    && ${buff[2]} == $'boz\n123' ]]
}

@test "json.buffer_output :: errors" {
  local buff
  # in=arrayname must be set when 0 args are passed. Explicitly calling with 0
  # args is a no-op, and when calling with dynamic args an array ref should be
  # used for efficiency.
  run json.buffer_output
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  out=buff run json.buffer_output
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]
}

@test "json.encode_string" {
  run json.encode_string
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  join=,
  [[ $(json.encode_string "") == '""' ]]
  [[ $(json.encode_string foo) == '"foo"' ]]
  [[ $(json.encode_string foo $'bar\nbaz\tboz\n') == '"foo","bar\nbaz\tboz\n"' ]]
  [[ $(join=$'\n' json.encode_string foo $'bar\nbaz\tboz\n') \
    ==  $'"foo"\n"bar\\nbaz\\tboz\\n"' ]]

  local buff=()
  empty=()
  out=buff in=empty json.encode_string
  [[ ${buff[*]} == "" ]]

  buff=()
  out=buff json.encode_string ""
  [[ ${#buff[@]} == 1 && ${buff[0]} == '""' ]]

  out=buff json.encode_string "foo"
  [[ ${#buff[@]} == 2 && ${buff[0]} == '""' && ${buff[1]} == '"foo"' ]]

  out=buff join= json.encode_string $'bar\nbaz' boz
  [[ ${#buff[@]} == 4 && ${buff[0]} == '""' && ${buff[1]} == '"foo"' \
    && ${buff[2]} == $'"bar\\nbaz"' && ${buff[3]} == '"boz"' ]]

  out=buff join=, json.encode_string abc def
  [[ ${#buff[@]} == 5 && ${buff[4]} == '"abc","def"' ]]

  local input=()
  in=input run json.encode_string
  [[ $status == 0 && $output == '' ]]

  input=(foo $'bar\nbaz\tboz\n')
  [[ $(in=input json.encode_string) == '"foo","bar\nbaz\tboz\n"' ]]
}

# A string containing all bytes (other than 0, which bash can't hold in vars)
function all_bytes() {
  python3 -c 'print("".join(chr(c) for c in range(1, 256)))'
}

# Verify that the first arg is a JSON string containing bytes 1..255 inclusive
function assert_is_all_bytes_json() {
  all_bytes_json="${1:?}" python3 <<< '
import json, os

actual = json.loads(os.environ["all_bytes_json"])
expected = "".join(chr(c) for c in range(1, 256))

if actual != expected:
  raise AssertionError(
    f"Decoded JSON chars did not match:\n  {actual=!r}\n{expected=!r}"
  )
  '
}

@test "json.encode_string :: all bytes (other than zero)" {
  # Check we can encode all bytes (other than 0, which bash can't hold in vars)
  bytes=$(all_bytes)
  # json.encode_string has 3 code paths which we need to test:

  # 1. single strings
  all_bytes_json=$(json.encode_string "${bytes:?}")
  assert_is_all_bytes_json "${all_bytes_json:?}"

  # 2. multiple strings with un-joined output
  buff=()
  out=buff json.encode_string "${bytes:?}" "${bytes:?}"
  assert_is_all_bytes_json "${buff[0]:?}"
  assert_is_all_bytes_json "${buff[1]:?}"
  [[ ${#buff[@]} == 2 ]]

  # 3. multiple strings with joined output
  output=$(join=, json.encode_string "${bytes:?}" "${bytes:?}")
  [[ $output == "${buff[0]},${buff[1]}" ]]
}

@test "json.encode_number" {
  local buff input join
  run json.encode_number
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  input=()
  in=input run json.encode_number
  [[ $status == 0 && $output == '' ]]

  join=,
  [[ $(json.encode_number 42) == "42" ]]
  [[ $(json.encode_number -1.34e+4 2.1e-4 2e6) == "-1.34e+4,2.1e-4,2e6" ]]

  input=(-1.34e+4 2.1e-4 2e6)
  [[ $(in=input json.encode_number) == "-1.34e+4,2.1e-4,2e6" ]]

  run json.encode_number foo bar
  [[ $status == 1 ]]
  [[ $output == "json.encode_number(): not all inputs are numbers: 'foo' 'bar'" ]]
  run json.encode_bool 42,42
  [[ $status == 1 ]]

  buff=()
  out=buff join= json.encode_number 1
  out=buff join= json.encode_number 2 3
  out=buff join=$'\n' json.encode_number 4 5
  [[ ${#buff[@]} == 4 && ${buff[0]} == '1' && ${buff[1]} == '2' \
    && ${buff[2]} == '3' && ${buff[3]} == $'4\n5' ]]
}

@test "json.encode_bool" {
  local buff input join
  run json.encode_bool
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  input=()
  in=input run json.encode_bool
  [[ $status == 0 && $output == '' ]]

  join=,
  [[ $(json.encode_bool true) == "true" ]]
  [[ $(json.encode_bool false) == "false" ]]
  [[ $(json.encode_bool false true) == "false,true" ]]

  input=(false true)
  [[ $(in=input json.encode_bool) == "false,true" ]]

  run json.encode_bool foo bar
  [[ $status == 1 ]]
  [[ $output == "json.encode_bool(): not all inputs are bools: 'foo' 'bar'" ]]
  run json.encode_bool true,true
  [[ $status == 1 ]]

  buff=()
  out=buff join= json.encode_bool true
  out=buff join= json.encode_bool false true
  out=buff join=$'\n' json.encode_bool true false
  [[ ${#buff[@]} == 4 && ${buff[0]} == 'true' && ${buff[1]} == 'false' \
    && ${buff[2]} == 'true' && ${buff[3]} == $'true\nfalse' ]]
}

@test "json.encode_null" {
  local buff input join
  run json.encode_null
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  input=()
  in=input run json.encode_null
  [[ $status == 0 && $output == '' ]]

  join=,
  [[ $(json.encode_null null) == "null" ]]
  [[ $(json.encode_null null null) == "null,null" ]]

  input=(null null)
  [[ $(in=input json.encode_null) == "null,null" ]]

  run json.encode_null foo bar
  [[ $status == 1 ]]
  [[ $output == "json.encode_null(): not all inputs are null: 'foo' 'bar'" ]]
  run json.encode_null null,null
  [[ $status == 1 ]]

  buff=()
  out=buff join= json.encode_null null
  out=buff join= json.encode_null null null
  out=buff join=$'\n' json.encode_auto null null
  [[ ${#buff[@]} == 4 && ${buff[0]} == 'null' && ${buff[1]} == 'null' \
    && ${buff[2]} == 'null' && ${buff[3]} == $'null\nnull' ]]
}

@test "json.encode_auto" {
  local buff input join
  run json.encode_auto
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  input=()
  in=input run json.encode_auto
  [[ $status == 0 && $output == '' ]]

  join=,
  [[ $(json.encode_auto 42) == '42' ]]
  [[ $(json.encode_auto hi) == '"hi"' ]]
  [[ $(json.encode_auto true) == 'true' ]]
  [[ $(json.encode_auto true hi 42) == 'true,"hi",42' ]]
  [[ $(json.encode_auto true,false foo bar 42) == '"true,false","foo","bar",42' ]]
  [[ $(json.encode_auto '"42') == '"\"42"' ]]
  [[ $(json.encode_auto ',"42') == '",\"42"' ]]
  [[ $(json.encode_auto foo '"42' foo '"42') == '"foo","\"42","foo","\"42"' ]]
  [[ $(json.encode_auto foo ',"42' foo ',"42') == '"foo",",\"42","foo",",\"42"' ]]

  input=(foo ',"42' foo ',"42')
  [[ $(in=input json.encode_auto) == '"foo",",\"42","foo",",\"42"' ]]

  buff=()
  out=buff join= json.encode_auto null
  out=buff join= json.encode_auto hi 42
  out=buff join=$'\n' json.encode_auto abc true
  [[ ${#buff[@]} == 4 && ${buff[0]} == 'null' && ${buff[1]} == '"hi"' \
    && ${buff[2]} == '42' && ${buff[3]} == $'"abc"\ntrue' ]]
}

@test "json.encode_raw" {
  local buff join input
  run json.encode_raw
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]

  input=()
  in=input run json.encode_raw
  [[ $status == 0 && $output == '' ]]

  join=,
  [[ $(json.encode_raw '{}') == '{}' ]]
  # invalid JSON is not checked/detected
  [[ $(json.encode_raw '}') == '}' ]]
  [[ $(json.encode_raw '[]' '{}') == '[],{}' ]]

  input=('[]' '{}')
  [[ $(in=input json.encode_raw) == '[],{}' ]]

  run json.encode_raw ''
  echo $output >&2
  [[ $status == 1 ]]
  [[ $output =~ "raw JSON value is empty" ]]

  buff=()
  out=buff join= json.encode_raw 1
  out=buff join= json.encode_raw 2 3
  out=buff join=$'\n' json.encode_raw 4 5
  declare -p buff
  [[ ${#buff[@]} == 4 && ${buff[0]} == '1' && ${buff[1]} == '2' \
    && ${buff[2]} == '3' && ${buff[3]} == $'4\n5' ]]
}
@test "json.encode_json :: in must be set with no args" {
  run json.encode_json
  [[ $status == 1 \
    && $output == *"in: in= must be set when no positional args are given" ]]
}

@test "json.encode_json" {
  local join=','
  [[ $(json.encode_json '{}') == '{}' ]]
  [[ $(json.encode_json '{"foo":["bar","baz"]}') == '{"foo":["bar","baz"]}' ]]
  [[ $(json.encode_json '[123]') == '[123]' ]]
  [[ $(json.encode_json '"hi"') == '"hi"' ]]
  [[ $(json.encode_json '-1.34e+4') == '-1.34e+4' ]]
  [[ $(json.encode_json 'true') == 'true' ]]
  [[ $(json.encode_json 'null') == 'null' ]]
  [[ $(json.encode_json '{"a":1}' '{"b":2}') == '{"a":1},{"b":2}' ]]

  join=''
  [[ $(json.encode_json 'true' '42') == 'true42' ]]

  local buff=() input=()
  out=buff in=input json.encode_json
  [[ ${#buff[@]} == 0 ]]

  input=(42 '"hi"')
  out=buff in=input json.encode_json
  [[ ${#buff[@]} == 2 && ${buff[0]} == '42' && ${buff[1]} == '"hi"' ]]

  join=','
  out=buff in=input json.encode_json
  declare -p buff
  [[ ${#buff[@]} == 3 && ${buff[0]} == '42' && ${buff[1]} == '"hi"' \
    && ${buff[2]} == '42,"hi"' ]]
}

@test "json.encode_json :: recognises valid JSON with insignificant whitespace" {
  local buff
  out=buff json.encode_json ' { "foo" : [ "bar" , 42 ] , "baz" : true } '
  [[ ${#buff[@]} == 1 \
    && ${buff[0]} == ' { "foo" : [ "bar" , 42 ] , "baz" : true } ' ]]
}

@test "json.encode_json :: rejects invalid JSON" {
  invalid_json=('{:}' ' ' '[' '{' '"foo' '[true false]')

  for invalid in "${invalid_json[@]}"; do
    run json.encode_json ''
    [[ $status == 1 \
      && $output == *"json.encode_json(): not all inputs are valid JSON:"* ]]

    run json.encode_json "${invalid:?}"
    [[ $status == 1 \
      && $output == *"json.encode_json(): not all inputs are valid JSON:"* ]]

    run json.encode_json '"ok"' "${invalid:?}"
    [[ $status == 1 \
      && $output == *"json.encode_json(): not all inputs are valid JSON:"* ]]

    run json.encode_json "${invalid:?}" '"ok"'
    [[ $status == 1 \
      && $output == *"json.encode_json(): not all inputs are valid JSON:"* ]]

    local -i tests+=4
  done

  (( ${tests:?} == 4 * 6 ))
}

@test "json argument pattern :: non-matches" {
  # A ref key can't be empty, otherwise it would clash with the @=value syntax.
  # Also, an empty ref is not useful in practice.
  [[ ! '@' =~ $_json_bash_arg_pattern ]]
  [[ ! '@:string' =~ $_json_bash_arg_pattern ]]
}

@test "json argument pattern" {
  keys=('' '@key' 'key')
  types=('' ':string')
  attributes=('' '[]' '[not=parsed,yet]')
  values=('' '=value' '@=value')

  for key in "${keys[@]}"; do
  for type in "${types[@]}"; do
  for attribute in "${attributes[@]}"; do
  for value in "${values[@]}"; do
    example="${key}${type}${attribute}${value}"
    declare -p key type attribute value example
    [[ $example =~ $_json_bash_arg_pattern ]]
    declare -p key type attribute value BASH_REMATCH
    local -n matched_key=BASH_REMATCH[1] \
      matched_type=BASH_REMATCH[6] \
      matched_attribute=BASH_REMATCH[8] \
      matched_value=BASH_REMATCH[11]
    local matched_length=${#BASH_REMATCH[0]}
    local matched_value_full="${matched_value}${example:${matched_length:?}}"

    declare -p matched_key matched_type matched_attribute matched_value_full

    [[ $matched_key == "$key" ]]
    [[ $matched_type == "$type" ]]
    [[ $matched_attribute == "$attribute" ]]
    [[ $matched_value_full == "$value" ]]
  done done done done
}

function assert_arg_parse() {
  expected=$(timeout 1 cat)
  expected=${expected/#+([ $'\n'])/}
  expected=${expected/%+([ $'\n'])/}
  local -A attrs
  out=attrs json.parse_argument "$1" || return 10
  declare -p attrs
  local attr_lines=() line
  for name in "${!attrs[@]}"; do
    printf -v line "%s = '%s'" "$name" "${attrs[$name]}"
    attr_lines+=("${line:?}")
  done
  sorted_attrs=$(local IFS=$'\n'; LC_ALL=C sort <<<"${attr_lines[*]}")
  if [[ $expected != "${sorted_attrs}" ]]; then
    diff -u <(echo "${expected:?}") <(echo "${sorted_attrs}")
    return 1
  fi
}

@test "json.parse_argument" {
  assert_arg_parse '' <<<""  # no attrs
  # keys
  assert_arg_parse a <<<"
@key = 'str'
key = 'a'
"
  assert_arg_parse @a <<<"
@key = 'var'
key = 'a'
"
  assert_arg_parse @/ <<<"
@key = 'file'
key = '/'
"
  assert_arg_parse @./ <<<"
@key = 'file'
key = './'
"
  assert_arg_parse '@@' <<<"
@key = 'str'
key = '@'
"
  assert_arg_parse '@@@' <<<"
@key = 'var'
key = '@'
"
  assert_arg_parse '@@@@' <<<"
@key = 'str'
key = '@@'
"
  # ] and , are not reserved chars in keys — they're not unescaped
  assert_arg_parse '@@f]]o,,[[o==bar' <<<"
@key = 'str'
key = '@f]]o,,[o=bar'
"
  # types
  assert_arg_parse :json <<<"
type = 'json'
"
  # attributes
  assert_arg_parse '[]' <<<"
array = 'true'
"
  # bash doesn't allow empty strings to be keys in associative arrays
  assert_arg_parse '[,]' <<<"
__empty__ = ''
array = 'true'
"
  assert_arg_parse '[=]' <<<"
__empty__ = ''
array = 'true'
"
  assert_arg_parse '[=x]' <<<"
__empty__ = 'x'
array = 'true'
"
  # split on null, like readarray -d ''
  assert_arg_parse '[split=]' <<<"
array = 'true'
split = ''
"
  # split char shorthand
  assert_arg_parse '[,,]' <<<"
array = 'true'
split = ','
"
  assert_arg_parse '[==]' <<<"
array = 'true'
split = '='
"
  assert_arg_parse '[]]]' <<<"
array = 'true'
split = ']'
"
  # split char shorthand does not apply if = is used
  assert_arg_parse '[x=]' <<<"
array = 'true'
x = ''
"
  # split char shorthand does apply with subsequent attrs present
  assert_arg_parse '[x,foo=bar]' <<<"
array = 'true'
foo = 'bar'
split = 'x'
"
  # split char shorthand does not apply with preceding attrs
  assert_arg_parse '[foo=bar,x]' <<<"
array = 'true'
foo = 'bar'
x = ''
"

  assert_arg_parse = <<<"
@val = 'str'
val = ''
"
  assert_arg_parse =42 <<<"
@val = 'str'
val = '42'
"
  assert_arg_parse @= <<<"
@val = 'var'
val = ''
"
  assert_arg_parse @=x <<<"
@val = 'var'
val = 'x'
"
  assert_arg_parse @=/ <<<"
@val = 'file'
val = '/'
"
  assert_arg_parse @=./ <<<"
@val = 'file'
val = './'
"
  assert_arg_parse @@fo==o:number[,,,a=42]@=./stuff <<<"
@key = 'str'
@val = 'file'
a = '42'
array = 'true'
key = '@fo=o'
split = ','
type = 'number'
val = './stuff'
"
}

@test "json.parse_argument :: attributes" {
  local -A attrs=(); out=attrs json.parse_argument '[]'
  [[ ${#attrs[@]} == 1 && ${attrs[array]} == true ]]

  local -A attrs=(); out=attrs json.parse_argument '[foo,bar=,baz=boz]'
  [[ ${#attrs[@]} == 4 && ${attrs[array]} == true && ${attrs[foo]} == '' \
    && ${attrs[bar]} == '' && ${attrs[baz]} == boz ]]
}

# Assert JSON on stdin matches JSON given as the first argument.
function equals_json() {
  if (( $# != 1 )); then
    echo "equals_json: usage: echo '{...}' | equals_json '{...}'" >&2; return 1
  fi

  actual=$(timeout 1 cat) \
    || { echo "equals_json: failed to read stdin" >&2; return 1; }
  expected=$(jq -cne "${1:?}") \
    || { echo "equals_json: jq failed to evalute expected JSON" >&2; return 1; }

  if ! python3 -m json.tool <<<"${actual}" > /dev/null; then
    echo "equals_json: json function output is not valid JSON: '$actual'" >&2; return 1
  fi

  eq=false
  if [[ ${compare:-serialised} == serialised ]]; then
    [[ ${expected:?} == "${actual}" ]] && eq=true
  elif [[ ${compare:-} == parsed ]]; then
    jq -ne --argjson x "${expected:?}" --argjson y "${actual:?}" '$x == $y' > /dev/null \
      && eq=true
  else
    echo "equals_json: Unknown compare value: '${compare:-}'" >&2; return 1;
  fi

  if [[ $eq != true ]]; then
    echo "equals_json: json output did not match expected:
expected: $expected
  actual: $actual" >&2
    expected_f=$(mktemp --suffix=.json.bats.expected)
    actual_f=$(mktemp --suffix=.json.bats.actual)
    python3 -m json.tool <<<"${expected}" > "${expected_f:?}"
    python3 -m json.tool <<<"${actual}" > "${actual_f:?}"
    diff -u "${expected_f:?}" "${actual_f:?}" >&2
    return 1
  fi
}

@test "json.bash json / json.array / json.object functions" {
  # The json function creates JSON objects
  json | equals_json '{}'
  # It creates arrays if json_return=array
  json_return=array json | equals_json '[]'
  # json.array is the same as json with json_return=array set
  json.array | equals_json '[]'
  # json.object is also defined, for consistency
  json.object | equals_json '{}'
}

@test "json.bash json keys" {
  # Keys
  json msg=hi | equals_json '{msg: "hi"}'
  # Keys can contain most characters (except @:=)
  json "🦬 says"=hi | equals_json '{"🦬 says": "hi"}'
  # Key values can come from variables
  key="The Message" json @key=hi | equals_json '{"The Message": "hi"}'
  # Key vars can contain any characters
  key="@key:with=reserved-chars" json @key=hi \
    | equals_json '{"@key:with=reserved-chars": "hi"}'
  # Each argument defines a key
  var=c json a=X b=Y @var=Z | equals_json '{a: "X", b: "Y", c: "Z"}'
  # Keys may be reused, but should not be, because JSON parser behaviour for
  # duplicate keys is undefined.
  [[ $(json a=A a=B a=C) == '{"a":"A","a":"B","a":"C"}' ]]
  json a=A a=B a=C | compare=parsed equals_json '{a: "C"}'
}

@test "json.bash json values" {
  # Property values can be set in the argument
  json message="Hello World" | equals_json '{message: "Hello World"}'
  # Or with a variable
  greeting="Hi there" json message@=greeting \
    | equals_json '{message: "Hi there"}'
  # Variable references without a value are used as the key and value
  greeting="Hi" name=Bob json @greeting @name \
    | equals_json '{greeting: "Hi", name: "Bob"}'
  # This also works (less usefully) for inline entries
  json message | equals_json '{message: "message"}'
  # There are no restrictions on values following a =
  json message=@value:with=reserved-chars \
    | equals_json '{message: "@value:with=reserved-chars"}'
}

@test "json.bash json.array values" {
  # Array values can also be set in the arguments
  json.array Hi "Bob Bobson" | equals_json '["Hi", "Bob Bobson"]'
  # Or via variables
  message=Hi name="Bob Bobson" json.array @message @name \
    | equals_json '["Hi", "Bob Bobson"]'
  # Array values in arguments cannot contain @:= characters, because they would
  # clash with @variable and :type syntax. However, values following a = can
  # contain anything
  json.array ='@foo:bar=baz' ='{"not":"parsed"}' \
    | equals_json '["@foo:bar=baz", "{\"not\":\"parsed\"}"]'
  # Values from variables have no restrictions. Arrays use the same argument
  # syntax as objects, so values in the key or value position work the same.
   s1='@foo:bar=baz' s2='{"not":"parsed"}' json.array @s1 @=s2 \
    | equals_json '["@foo:bar=baz", "{\"not\":\"parsed\"}"]'
  # It's possible to set a key as well as value for array entries, but the key
  # is ignored.
  a=A b=B json.array @a@=a @b=B c=C | equals_json '["A", "B", "C"]'
}

@test "json.bash json types" {
  # Types
  # Values are strings by default
  json data=42 | equals_json '{data: "42"}'
  # Non-string values need explicit types
  json data:number=42 | equals_json '{data: 42}'
  # The default string type can be changed with json_type
  json_defaults=type=number json data=42 | equals_json '{data: 42}'
  # In which case strings need to be explicitly typed
  json_defaults=type=number json data=42 msg:string=Hi \
    | equals_json '{data: 42, msg: "Hi"}'
  # true/false/null have types which don't require redundant values
  json active:true enabled:false data:null \
    | equals_json '{active: true, enabled: false, data: null}'
  # Regardless, they can be given values if desired
  json active:true=true enabled:false=false data:null=null \
    | equals_json '{active: true, enabled: false, data: null}'
  # The bool type allows either true or false values.
  active=true json @active:bool enabled:bool=false \
    | equals_json '{active: true, enabled: false}'
  # The auto type outputs true/false/null and number values. You can opt into
  # this globally by exporting json_type=auto as an environment variable.
  # JSON object and array values are not parsed with auto, only simple values.
  json_defaults=type=auto json a=42 b="Hi" c=true d=false e=null f=[] g={} \
    | equals_json '{a: 42, b: "Hi", c: true, d: false, e: null,
                    f: "[]", g: "{}"}'
  # auto can be used selectively like other types
  data=42 json a=42 b:auto=42 c:auto@=data \
    | equals_json '{a: "42", b: 42, c: 42}'
}

@test "json.bash json array types" {
  # Arrays of values can be created using the [] suffix with each type
  json sizes:number[]=42 | equals_json '{sizes: [42]}'

  # The value is split on the character inside the []
  json names[:]="Alice:Bob:Dr Chris" \
    | equals_json '{names: ["Alice", "Bob", "Dr Chris"]}'

  # Inline values are not split unless a character is provided
  json sizes[]="$(seq 3)" | equals_json '{sizes: ["1\n2\n3"]}'
  json sizes:number[$'\n']="$(seq 3)" | equals_json '{sizes: [1, 2, 3]}'

  # But file references use each line as a value by default
  # (Note that <(seq 3) is a shell construct (process substitution) that
  # produces a file containing 1 2 3 on separate lines.)
  json sizes:number[]@=<(seq 3) | equals_json '{sizes: [1, 2, 3]}'

  # [:] is shorthand for [split=:]
  json names[split=:]="Alice:Bob:Dr Chris" \
    | equals_json '{names: ["Alice", "Bob", "Dr Chris"]}'
  # The last split value wins when used more than once
  json sizes:number[:,split=!,split=/]=1/2/3 | equals_json '{sizes: [1, 2, 3]}'

  # To split on null bytes, use split= (empty string). When used with inline and
  # bash values this effectively inhibits splitting, because bash variables
  # can't contain null bytes.
  printf 'AB\nCD\x00EF\nGH\n\x00' | json nullterm[split=]@=/dev/stdin \
    | equals_json '{nullterm: ["AB\nCD", "EF\nGH\n"]}'

  # @var references can be bash arrays
  names=("Bob Bobson" "Alice Alison")
  sizes=(42 55)
  json @names:string[] @sizes:number[] | equals_json '{
    names: ["Bob Bobson", "Alice Alison"],
    sizes: [42, 55]
  }'
  # json.array values can be arrays too
  json.array @names:string[] @sizes:number[] :null[] :bool[]=true | equals_json '[
    ["Bob Bobson", "Alice Alison"],
    [42, 55],
    [null],
    [true]
  ]'
  # empty inline values are empty arrays
  json str:string[]= num:number[]= bool:bool[]= raw:raw[]= json:json[]= \
    | equals_json '{str: [], num: [], bool: [], raw: [], json: []}'
}

@test "json.bash json nested JSON with :json and :raw types" {
  # Nested objects and arrays are created using the json or raw types. The :raw
  # type allow any value to be inserted (even invalid JSON), whereas :json
  # validates the provided value(s) and fails if they're not actually JSON.
  #
  # The reason for both is that :json depends on grep (with PCRE) being present,
  # so :raw can be used in situations where only bash is available, and
  # validation isn't necessary (e.g. when passing the output of one json.bash
  # call into another).

  for type in json raw; do
    json user:$type='{"name":"Bob Bobson"}' \
      | equals_json '{user: {name: "Bob Bobson"}}'

    user='{"name":"Bob Bobson"}' json @user:$type \
      | equals_json '{user: {name: "Bob Bobson"}}'

    user='{"name":"Bob Bobson"}' json "User":$type@=user \
      | equals_json '{User: {name: "Bob Bobson"}}'

    # Use nested json calls to create nested JSON objects or arrays
    json user:$type="$(json name="Bob Bobson")" \
      | equals_json '{user: {name: "Bob Bobson"}}'

    # Variables can hold JSON values to incrementally build larger objects.
    local people=()
    out=people json name="Bob" pet="Tiddles"
    out=people json name="Alice" pet="Frankie"
    json type=people status:$type="$(json created_date=yesterday final:false)" \
      users:$type[]@=people \
      | equals_json '{
          type: "people", status: {created_date: "yesterday", final: false},
          users: [
            {name: "Bob", pet: "Tiddles"},
            {name: "Alice", pet: "Frankie"}
          ]
        }'
  done
}

@test "json.bash file references" {
  tmp=$(mktemp_bats -d); cd "${tmp:?}"
  printf 'orange #3\nblue #5\n' > colours

  # The @... syntax can be used to reference the content of files. If an @ref
  # starts with / or ./ it's taken to be a file.
  json my_colours@=./colours | equals_json '{my_colours: "orange #3\nblue #5\n"}'
  # The final path segment is used as the key if a key isn't set.
  json @./colours | equals_json '{colours: "orange #3\nblue #5\n"}'
  # Array values split on newlines
  json @./colours[] | equals_json '{colours: ["orange #3", "blue #5"]}'

  printf 'apple:pear:grape' > fruit
  # The file can be split on a different character by naming it in the []
  json @./fruit[:] | equals_json '{fruit: ["apple", "pear", "grape"]}'
  json @./fruit[split=:] | equals_json '{fruit: ["apple", "pear", "grape"]}'

  # Split on null by setting split to the empty string
  printf 'foo\nbar\n\x00bar baz\n\x00' > nullterminated
  json @./nullterminated[split=] \
    | equals_json '{nullterminated: ["foo\nbar\n", "bar baz\n"]}'

  # Read from stdin using the special /dev/stdin file
  seq 3 | json counts:number[]@=/dev/stdin | equals_json '{counts:[1, 2, 3]}'

  # Use process substitution to nest json calls and consume multiple streams.
  json counts:number[]@=<(seq 3) \
       people:json[]@=<(json name=Bob; json name=Alice) \
    | equals_json '{counts:[1, 2, 3], people: [{name: "Bob"},{name: "Alice"}]}'
  #   Aside: if you're not clear on what's happening here, try $ cat <(seq 3)
  #   and also $ echo <(seq 3)

  # Files can be referenced indirectly using a variable.
  # If @var is used and $var is not set, but $var_FILE is, the filename is read
  # from $var_FILE and the content of the file is used.
  printf 'secret123' > db_password
  db_password_FILE=./db_password json @db_password \
    | equals_json '{db_password: "secret123"}'
  # (This pattern is commonly used to pass secrets securely via environment
  # variables.)
}

@test "json.bash json errors :: do not produce partial JSON output" {
  # No partial output on errors — either json suceeds with output, or fails with
  # no output.
  run json foo=bar error:number=notanumber
  [[ $status == 1 ]]
  # no JSON in output:
  [[ ! $output =~ '{' ]]
  [[ "$output" == *"failed to encode value as number: 'notanumber' from 'error:number=notanumber'" ]]

  # Same for array output
  local buff=() err=$(mktemp_bats)
  # Can't use run because it forks, and the fork can't write to our buff
  out=buff json ok:true
  out=buff json foo=bar error:number=notanumber 2> "${err:?}" || status=$?
  out=buff json garbage:false

  [[ ${status:-} == 1 ]]
  [[ ! $(cat "${err:?}") =~ '{' ]]
  [[ $(cat "${err:?}") == \
    *"failed to encode value as number: 'notanumber' from 'error:number=notanumber'" ]]
  [[ ${#buff[@]} == 2 && ${buff[0]} == '{"ok":true}' \
    && ${buff[1]} == '{"garbage":false}' ]]
}


@test "json.bash json option handling" {
  # Keys can start with -. This will conflict with command-line arguments if we
  # were to support them.
  json -a=b | equals_json '{"-a": "b"}'
  # But we support the common idiom of using a -- argument to disambiguate
  # options from arguments, so if we add options then this can be used to
  # future-proof handling of hyphen-prefixed arguments.
  # Note that the first -- is ignored, but the second is not ignored.
  json a=x -- -a=y -- --a=z | equals_json '{a:"x","-a":"y","--":"--","--a":"z"}'
}

@test "json.bash json errors" {
  invalid_args=(
    # inline keys can't contain @
    a@b
    # inline keys can't contain : (basically parsed as an invalid type)
    a:b:string
    # invalid types are not allowed
    :cheese[]
  )
  for arg in "${invalid_args[@]}"; do
    run json "${arg:?}"
    [[ $status == 1 && $output =~ "invalid argument: '${arg:?}'" ]] || {
      echo "arg '$arg' did not fail: $output" >&2; return 1
    }
  done

  # Empty raw values are errors
  run json a:raw=
  [[ $status == 1 && $output =~ "raw JSON value is empty" ]]

  # Invalid typed values are errors
  run json a:number=a
  [[ $status == 1 && $output =~ "failed to encode value as number: 'a' from 'a:number=a'" ]]
  run json a:number[]=a
  [[ $status == 1 && $output =~ "failed to encode value as number: 'a' from 'a:number[]=a'" ]]
  run json a:bool=a
  [[ $status == 1 && $output =~ "failed to encode value as bool: 'a' from 'a:bool=a'" ]]
  run json a:null=a
  [[ $status == 1 && $output =~ "failed to encode value as null: 'a' from 'a:null=a'" ]]

  # Syntax errors in :json type values are errors
  run json a:json=
  [[ $status == 1 && $output =~ "failed to encode value as json: '' from 'a:json='" \
    && $output =~ "json.encode_json(): not all inputs are valid JSON: ''" ]]

  run json a:json='{"foo":'
  [[ $status == 1 \
    && $output =~ " failed to encode value as json: '{\"foo\":' from 'a:json={\"foo\":'" ]]

  local json_things=('true' '["invalid"')
  run json a:json[]@=json_things
  [[ $status == 1 \
    && $output =~ "failed to encode value as json: 'true' '[\"invalid\"' from 'a:json[]@=json_things'" ]]

  # references to missing variables are errors
  run json @__missing
  [[ $status == 1 && $output =~ \
    "argument references unbound variable: \$__missing from '@__missing" ]]
}

@test "json.bash json non-errors" {
  # Edge-cases related to the above errors that are not errors
  # a=b=c is parsed as a value a: "a=b"
  json a=b=c | equals_json '{a: "b=c"}'

  # keys can contain '-' after the first char
  json a-b=c | equals_json '{"a-b": "c"}'

  # type by itself is OK with or without an array marker
  json :string | equals_json '{"": ""}'
  json :string[] | equals_json '{"": []}'

  # raw arrays with empty values are not checked for or detected.
  raws=('' '')
  [[ $(json a:raw[]@=raws) == '{"a":[,]}' ]]

  # invalid raw values are not checked for or detected
  [[ $(json a:raw=']  ') == '{"a":]  }' ]]
}

@test "json.bash CLI :: help" {
  for flag in -h --help; do
    run ./json.bash "$flag"
    [[ $status == 0 ]]
    [[ $output =~ Generate\ JSON\ objects ]]
    [[ $output =~ Usage: ]]
  done
}

@test "json.bash CLI :: version" {
  run ./json.bash --version
  [[ $status == 0 ]]
  [[ $output =~ "json.bash $JSON_BASH_VERSION" ]]
}

@test "json.bash CLI :: object output" {
  # The CLI forwards its arguments to the json() function
  run ./json.bash "The Message"="Hello World" size:number=42
  [[ $status == 0 && $output == '{"The Message":"Hello World","size":42}' ]]
}

@test "json.bash CLI :: array output via prog name" {
  # The CLI uses json_return=array (like json.array()) when the program name has
  # the suffix "array"
  dir=$(mktemp_bats -d)
  ln -s "${BATS_TEST_DIRNAME:?}/json.bash" "${dir:?}/xxx-array"
  run "${dir:?}/xxx-array" foo bar
  [[ $status == 0 && $output == '["foo","bar"]' ]]
}

@test "json validator :: validates valid JSON via arg" {
  initials=('' 'true' '{}' '[]' '42' '"hi"' 'null')
  for initial in "${initials[@]}"; do
    read -ra _initials <<<"$initial" # '' -> (), true -> (true)
    json.validate "${_initials[@]}" 'true'
    json.validate "${_initials[@]}" 'false'
    json.validate "${_initials[@]}" 'null'
    json.validate "${_initials[@]}" '42'
    json.validate "${_initials[@]}" '"abc"'
    json.validate "${_initials[@]}" '[]'
    json.validate "${_initials[@]}" '[-1.34e+4,2.1e-4,2e6]'
    json.validate "${_initials[@]}" '{}'
    json.validate "${_initials[@]}" '{"foo":{"bar":["baz"]}}'
  done
}

@test "json validator :: validates valid JSON via array" {
  in=input
  input=(); json.validate

  initials=('' 'true' '{}' '[]' '42' '"hi"' 'null')
  for initial in "${initials[@]}"; do
    read -ra _initials <<<"$initial" # '' -> (), true -> (true)
    input=("${_initials[@]}" 'true'); json.validate
    input=("${_initials[@]}" 'false'); json.validate
    input=("${_initials[@]}" 'null'); json.validate
    input=("${_initials[@]}" '42'); json.validate
    input=("${_initials[@]}" '"abc"'); json.validate
    input=("${_initials[@]}" '[]'); json.validate
    input=("${_initials[@]}" '[-1.34e+4,2.1e-4,2e6]'); json.validate
    input=("${_initials[@]}" '{}'); json.validate
    input=("${_initials[@]}" '{"foo":{"bar":["baz"]}}'); json.validate
  done
}

@test "json validator :: validates JSON with insignificant whitespace" {
  local ws_chars=($' \t\n\r')
  for i in 0 1 2 3; do
    spaced_json_template=' { "a" : [ "c" , [ { } ] ] , "b" : null } '
    ws="${ws_chars:$i:1}"
    spaced_json=${spaced_json_template// /"${ws:?}"}
    json.validate "${spaced_json:?}"

    ws="${ws_chars:$i:4}${ws_chars:0:$i}"
    spaced_json=${spaced_json_template// /"${ws:?}"}
    json.validate "${spaced_json:?}"
  done
  [[ $i == 3 ]]
}

function expect_json_invalid() {
  if [[ $# == 0 ]]; then return 1; fi
  if json.validate "$@"; then
    echo "expect_invalid: example unexpectedly passed validation: ${1@Q}" >&2
    return 1
  fi
}

@test "json validator :: detects invalid JSON via arg" {
  initials=('' true)
  for initial in "${initials[@]}"; do
    read -ra _initials <<<"$initial" # '' -> (), true -> (true)
    expect_json_invalid "${_initials[@]}" ''
    expect_json_invalid "${_initials[@]}" 'truex'
    expect_json_invalid "${_initials[@]}" 'false_'
    expect_json_invalid "${_initials[@]}" 'nullx'
    expect_json_invalid "${_initials[@]}" '42a'
    expect_json_invalid "${_initials[@]}" '"abc'
    expect_json_invalid "${_initials[@]}" '"ab\z"' # invalid escape
    expect_json_invalid "${_initials[@]}" '"ab""ab"'
    expect_json_invalid "${_initials[@]}" '['
    expect_json_invalid "${_initials[@]}" '[]]'
    expect_json_invalid "${_initials[@]}" '[][]'
    expect_json_invalid "${_initials[@]}" '[a]'
    expect_json_invalid "${_initials[@]}" '{'
    expect_json_invalid "${_initials[@]}" '{}{}'
    expect_json_invalid "${_initials[@]}" '{42:true}'
    expect_json_invalid "${_initials[@]}" '{"foo":}'
  done
}

function expect_json_array_invalid() {
  local input=("$@")
  if in=input json.validate; then
    echo "expect_invalid: example unexpectedly passed validation: ${input[*]@Q}" >&2
    return 1
  fi
}

@test "json validator :: detects invalid JSON via array" {
  expect_json_array_invalid ''
  initials=('' true)
  for initial in "${initials[@]}"; do
    read -ra _initials <<<"$initial" # '' -> (), true -> (true)
    expect_json_array_invalid "${_initials[@]}" 'truex'
    expect_json_array_invalid "${_initials[@]}" 'false_'
    expect_json_array_invalid "${_initials[@]}" 'nullx'
    expect_json_array_invalid "${_initials[@]}" '42a'
    expect_json_array_invalid "${_initials[@]}" '"abc'
    expect_json_array_invalid "${_initials[@]}" '"ab\z"' # invalid escape
    expect_json_array_invalid "${_initials[@]}" '"ab""ab"'
    expect_json_array_invalid "${_initials[@]}" '['
    expect_json_array_invalid "${_initials[@]}" '[]]'
    expect_json_array_invalid "${_initials[@]}" '[][]'
    expect_json_array_invalid "${_initials[@]}" '[a]'
    expect_json_array_invalid "${_initials[@]}" '{'
    expect_json_array_invalid "${_initials[@]}" '{}{}'
    expect_json_array_invalid "${_initials[@]}" '{42:true}'
    expect_json_array_invalid "${_initials[@]}" '{"foo":}'
  done
}
