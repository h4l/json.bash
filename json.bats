# shellcheck shell=bash
set -o pipefail

load json.bash

setup() {
  cd "${BATS_TEST_DIRNAME:?}"
}

function mktemp_bats() {
  mktemp "${BATS_RUN_TMPDIR:?}/json.bats.XXX" "$@"
}

@test "json.bash.buffer_output" {
  [[ $(json.bash.buffer_output) == "" ]]
  [[ $(json.bash.buffer_output foo) == "foo" ]]
  [[ $(json.bash.buffer_output foo bar) == "foobar" ]]

  local buff
  out=buff json.bash.buffer_output
  [[ ${#buff[@]} == 0 ]]

  out=buff json.bash.buffer_output foo
  [[ ${#buff[@]} == 1 && ${buff[0]} == "foo" ]]

  out=buff json.bash.buffer_output bar $'baz\nboz'
  [[ ${#buff[@]} == 3 && ${buff[0]} == "foo" && ${buff[1]} == "bar" \
    && ${buff[2]} == $'baz\nboz' ]]
}

@test "encode_json_strings" {
  join=,
  [[ $(encode_json_strings) == '' ]]
  [[ $(encode_json_strings "") == '""' ]]
  [[ $(encode_json_strings foo) == '"foo"' ]]
  [[ $(encode_json_strings foo $'bar\nbaz\tboz\n') == '"foo","bar\nbaz\tboz\n"' ]]
  [[ $(join=$'\n' encode_json_strings foo $'bar\nbaz\tboz\n') \
    ==  $'"foo"\n"bar\\nbaz\\tboz\\n"' ]]

  local buff=()
  out=buff encode_json_strings
  [[ ${buff[*]} == "" ]]

  buff=()
  out=buff encode_json_strings ""
  [[ ${#buff[@]} == 1 && ${buff[0]} == '""' ]]

  out=buff encode_json_strings "foo"
  [[ ${#buff[@]} == 2 && ${buff[0]} == '""' && ${buff[1]} == '"foo"' ]]

  out=buff join= encode_json_strings $'bar\nbaz' boz
  [[ ${#buff[@]} == 4 && ${buff[0]} == '""' && ${buff[1]} == '"foo"' \
    && ${buff[2]} == $'"bar\\nbaz"' && ${buff[3]} == '"boz"' ]]

  out=buff join=, encode_json_strings abc def
  [[ ${#buff[@]} == 5 && ${buff[4]} == '"abc","def"' ]]
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

@test "encode_json_strings :: all bytes (other than zero)" {
  # Check we can encode all bytes (other than 0, which bash can't hold in vars)
  bytes=$(all_bytes)
  # encode_json_strings has 3 code paths which we need to test:

  # 1. single strings
  all_bytes_json=$(encode_json_strings "${bytes:?}")
  assert_is_all_bytes_json "${all_bytes_json:?}"

  # 2. multiple strings with un-joined output
  buff=()
  out=buff encode_json_strings "${bytes:?}" "${bytes:?}"
  assert_is_all_bytes_json "${buff[0]:?}"
  assert_is_all_bytes_json "${buff[1]:?}"
  [[ ${#buff[@]} == 2 ]]

  # 3. multiple strings with joined output
  output=$(join=, encode_json_strings "${bytes:?}" "${bytes:?}")
  [[ $output == "${buff[0]},${buff[1]}" ]]
}

@test "encode_json_numbers" {
  join=,
  [[ $(encode_json_numbers) == "" ]]
  [[ $(encode_json_numbers 42) == "42" ]]
  [[ $(encode_json_numbers -1.34e+4 2.1e-4 2e6) == "-1.34e+4,2.1e-4,2e6" ]]
  run encode_json_numbers foo bar
  [[ $status == 1 ]]
  [[ $output == "encode_json_numbers(): not all inputs are numbers: 'foo' 'bar'" ]]
  run encode_json_bools 42,42
  [[ $status == 1 ]]

  local buff=()
  out=buff join= encode_json_numbers 1
  out=buff join= encode_json_numbers 2 3
  out=buff join=$'\n' encode_json_numbers 4 5
  [[ ${#buff[@]} == 4 && ${buff[0]} == '1' && ${buff[1]} == '2' \
    && ${buff[2]} == '3' && ${buff[3]} == $'4\n5' ]]
}

@test "encode_json_bools" {
  join=,
  [[ $(encode_json_bools) == "" ]]
  [[ $(encode_json_bools true) == "true" ]]
  [[ $(encode_json_bools false) == "false" ]]
  [[ $(encode_json_bools false true) == "false,true" ]]
  run encode_json_bools foo bar
  [[ $status == 1 ]]
  [[ $output == "encode_json_bools(): not all inputs are bools: 'foo' 'bar'" ]]
  run encode_json_bools true,true
  [[ $status == 1 ]]

  local buff=()
  out=buff join= encode_json_bools true
  out=buff join= encode_json_bools false true
  out=buff join=$'\n' encode_json_bools true false
  [[ ${#buff[@]} == 4 && ${buff[0]} == 'true' && ${buff[1]} == 'false' \
    && ${buff[2]} == 'true' && ${buff[3]} == $'true\nfalse' ]]
}

@test "encode_json_nulls" {
  join=,
  [[ $(encode_json_nulls) == "" ]]
  [[ $(encode_json_nulls null) == "null" ]]
  [[ $(encode_json_nulls null null) == "null,null" ]]
  run encode_json_nulls foo bar
  [[ $status == 1 ]]
  [[ $output == "encode_json_nulls(): not all inputs are nulls: 'foo' 'bar'" ]]
  run encode_json_nulls null,null
  [[ $status == 1 ]]

  local buff=()
  out=buff join= encode_json_nulls null
  out=buff join= encode_json_nulls null null
  out=buff join=$'\n' encode_json_autos null null
  [[ ${#buff[@]} == 4 && ${buff[0]} == 'null' && ${buff[1]} == 'null' \
    && ${buff[2]} == 'null' && ${buff[3]} == $'null\nnull' ]]
}

@test "encode_json_autos" {
  join=,
  [[ $(encode_json_autos) == '' ]]
  [[ $(encode_json_autos 42) == '42' ]]
  [[ $(encode_json_autos hi) == '"hi"' ]]
  [[ $(encode_json_autos true) == 'true' ]]
  [[ $(encode_json_autos true hi 42) == 'true,"hi",42' ]]
  [[ $(encode_json_autos true,false foo bar 42) == '"true,false","foo","bar",42' ]]
  [[ $(encode_json_autos '"42') == '"\"42"' ]]
  [[ $(encode_json_autos ',"42') == '",\"42"' ]]
  [[ $(encode_json_autos foo '"42' foo '"42') == '"foo","\"42","foo","\"42"' ]]
  [[ $(encode_json_autos foo ',"42' foo ',"42') == '"foo",",\"42","foo",",\"42"' ]]

  local buff=()
  out=buff join= encode_json_autos null
  out=buff join= encode_json_autos hi 42
  out=buff join=$'\n' encode_json_autos abc true
  [[ ${#buff[@]} == 4 && ${buff[0]} == 'null' && ${buff[1]} == '"hi"' \
    && ${buff[2]} == '42' && ${buff[3]} == $'"abc"\ntrue' ]]
}

@test "encode_json_raws" {
  join=,
  [[ $(encode_json_raws) == '' ]]
  [[ $(encode_json_raws '{}') == '{}' ]]
  # invalid JSON is not checked/detected
  [[ $(encode_json_raws '}') == '}' ]]
  [[ $(encode_json_raws '[]' '{}') == '[],{}' ]]

  run encode_json_raws ''
  echo $output >&2
  [[ $status == 1 ]]
  [[ $output =~ "raw JSON value is empty" ]]

  local buff=()
  out=buff join= encode_json_raws 1
  out=buff join= encode_json_raws 2 3
  out=buff join=$'\n' encode_json_raws 4 5
  declare -p buff
  [[ ${#buff[@]} == 4 && ${buff[0]} == '1' && ${buff[1]} == '2' \
    && ${buff[2]} == '3' && ${buff[3]} == $'4\n5' ]]
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
  json_type=number json data=42 | equals_json '{data: 42}'
  # In which case strings need to be explicitly typed
  json_type=number json data=42 msg:string=Hi \
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
  json_type=auto json a=42 b="Hi" c=true d=false e=null f=[] g={} \
    | equals_json '{a: 42, b: "Hi", c: true, d: false, e: null,
                    f: "[]", g: "{}"}'
  # auto can be used selectively like other types
  data=42 json a=42 b:auto=42 c:auto@=data \
    | equals_json '{a: "42", b: 42, c: 42}'
}

@test "json.bash json array types" {
  # Arrays of values can be created using the [] suffix with each type
  json sizes:number[]=42 | equals_json '{sizes: [42]}'
  # Values set in arguments can only create arrays of 1 element
  json names:string[]=Bob | equals_json '{names: ["Bob"]}'
  # To create arrays of variable length, use a bash array
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
}

@test "json.bash json nested JSON with raw type" {
  # Nested objects and arrays are created using the raw type, which allows any
  # value to be inserted. json.bash doesn't implement a JSON parser, so it
  # can't validate raw values, other than not allowing empty values. So long as
  # raw values are created from nested json.bash calls, or known JSON constants,
  # the result will be valid JSON.
  json user:raw='{"name":"Bob Bobson"}' \
    | equals_json '{user: {name: "Bob Bobson"}}'

  user='{"name":"Bob Bobson"}' json @user:raw \
    | equals_json '{user: {name: "Bob Bobson"}}'

  user='{"name":"Bob Bobson"}' json "User":raw@=user \
    | equals_json '{User: {name: "Bob Bobson"}}'

  # Use nested json calls to create nested JSON objects or arrays
  json user:raw="$(json name="Bob Bobson")" \
    | equals_json '{user: {name: "Bob Bobson"}}'

  # Variables can hold JSON values to incrementally build larger objects.
  people=(
    "$(json name="Bob" pet="Tiddles")"
    "$(json name="Alice" pet="Frankie")"
  )
  json type=people status:raw="$(json created_date=yesterday final:false)" \
    users:raw[]@=people \
    | equals_json '{
        type: "people", status: {created_date: "yesterday", final: false},
        users: [
          {name: "Bob", pet: "Tiddles"},
          {name: "Alice", pet: "Frankie"}
        ]
      }'
}

@test "json.bash json errors :: do not produce partial JSON output" {
  # No partial output on errors — either json suceeds with output, or fails with
  # no output.
  run json foo=bar error:number=notanumber
  [[ $status == 1 ]]
  # no JSON in output:
  [[ ! $output =~ '{' ]]
  [[ "$output" == *"failed to encode arg='error:number=notanumber' -> 'notanumber'" ]]

  # Same for array output
  local buff=() err=$(mktemp_bats)
  # Can't use run because it forks, and the fork can't write to our buff
  out=buff json ok:true
  out=buff json foo=bar error:number=notanumber 2> "${err:?}" || status=$?
  out=buff json garbage:false

  [[ ${status:-} == 1 ]]
  [[ ! $(cat "${err:?}") =~ '{' ]]
  [[ $(cat "${err:?}") == \
    *"failed to encode arg='error:number=notanumber' -> 'notanumber'" ]]
  [[ ${#buff[@]} == 2 && ${buff[0]} == '{"ok":true}' \
    && ${buff[1]} == '{"garbage":false}' ]]
}


@test "json.bash json errors" {
  invalid_args=(
    # inline keys cannot start with '-' (to prevent clashes with option flags,
    # although we don't currently have any).
    -foo
    # inline keys can't contain @
    a@b
    # inline keys can't contain : (basically parsed as an invalid type)
    a:b:string
    # invalid types are not allowed
    :string[sdfds]
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
  # And a raw array containing the empty string is an error
  run json a:raw[]=
  [[ $status == 1 && $output =~ "raw JSON value is empty" ]]

  # Invalid typed values are errors
  run json a:number=a
  [[ $status == 1 && $output =~ "failed to encode arg='a:number=a' -> 'a'" ]]
  run json a:number[]=a
  [[ $status == 1 && $output =~ "failed to encode arg='a:number[]=a' -> 'a'" ]]
  run json a:bool=a
  [[ $status == 1 && $output =~ "failed to encode arg='a:bool=a' -> 'a'" ]]
  run json a:null=a
  [[ $status == 1 && $output =~ "failed to encode arg='a:null=a' -> 'a'" ]]
}

@test "json.bash json non-errors" {
  # Edge-cases related to the above errors that are not errors
  # a=b=c is parsed as a value a: "a=b"
  json a=b=c | equals_json '{a: "b=c"}'

  # keys can contain '-' after the first char
  json a-b=c | equals_json '{"a-b": "c"}'

  # type by itself is OK with or without an array marker
  json :string | equals_json '{"": ""}'
  json :string[] | equals_json '{"": [""]}'

  # raw arrays with empty values are not checked for or detected.
  raws=('' '')
  [[ $(json a:raw[]@=raws) == '{"a":[,]}' ]]


  # invalid raw values are not checked for or detected
  [[ $(json a:raw=']  ') == '{"a":]  }' ]]

  # references to missing variables become empty strings
  json @__missing1@=__missing2 | equals_json '{"": ""}'

  # missing arrays become empty arrays
  json a:string[]@=__missing | equals_json '{"a": []}'
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
