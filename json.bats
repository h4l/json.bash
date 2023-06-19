# shellcheck shell=bash

setup_file() {
  cd "${BATS_TEST_DIRNAME:?}"
}

setup() {
  source ./json.bash
}

@test "json creates objects" {
  json foo
  [[ $(json foo) == '{"foo":"}' ]]

  bar=("abc 123" $'foo\nbar\n')
  # [[ $(foo=123 json foo "bar:array" "foo:array=My Key") \
  #    == '{"foo":"123","bar":["abc 123","foo\nbar\n"],"My Key":["123"]}' ]]

  # jq --argjson actual "$(\
  #   foo=123
  #   json activate:true disconnect:false parent:null \
  #   foo=auto_foo foo:number=number_foo foo:string=string_foo foo:array=array_foo \
  #   bar:array \
  # )" -ne '$actual == {
  #   activate: true, disconnect: false, parent: null,
  #   auto_foo: 123, number_foo: 123, string_foo: "123", array_foo: ["123"],
  #   bar: ["abc 123", "foo\nbar\n"]
  # }'
}

@test "json creates arrays" {
  jq <<<"$(foo=123 bar="hey lol" json_type=array json foo bar)" -e \
     '. | debug == [123, "hey lol"]'

  bar=("abc 123" $'foo\nbar\n')
  jq <<<"$(\
    foo=123
    json_type=array json _:true _:false _:null \
    foo foo:number foo:string foo:array bar:array \
  )" -e 'debug | . == [
    true, false, null, 123, 123, "123", ["123"], ["abc 123", "foo\nbar\n"]
  ]'
}

@test "encode_json_strings" {
  [[ $(encode_json_strings) == '' ]]
  [[ $(encode_json_strings "") == '""' ]]
  [[ $(encode_json_strings foo) == '"foo"' ]]
  [[ $(encode_json_strings foo $'bar\nbaz\tboz\n') == '"foo","bar\nbaz\tboz\n"' ]]
}

@test "encode_json_numbers" {
  [[ $(encode_json_numbers) == "" ]]
  [[ $(encode_json_numbers 42) == "42" ]]
  [[ $(encode_json_numbers -1.34e+4 2.1e-4 2e6) == "-1.34e+4,2.1e-4,2e6" ]]
  run encode_json_numbers foo bar
  [[ $status == 1 ]]
  [[ $output == "encode_json_numbers(): not all inputs are numbers: 'foo' 'bar'" ]]
  run encode_json_bools 42,42
  [[ $status == 1 ]]
}

@test "encode_json_bools" {
  [[ $(encode_json_bools) == "" ]]
  [[ $(encode_json_bools true) == "true" ]]
  [[ $(encode_json_bools false) == "false" ]]
  [[ $(encode_json_bools false true) == "false,true" ]]
  run encode_json_bools foo bar
  [[ $status == 1 ]]
  [[ $output == "encode_json_bools(): not all inputs are bools: 'foo' 'bar'" ]]
  run encode_json_bools true,true
  [[ $status == 1 ]]
}

@test "encode_json_nulls" {
  [[ $(encode_json_nulls) == "" ]]
  [[ $(encode_json_nulls null) == "null" ]]
  [[ $(encode_json_nulls null null) == "null,null" ]]
  run encode_json_nulls foo bar
  [[ $status == 1 ]]
  [[ $output == "encode_json_nulls(): not all inputs are nulls: 'foo' 'bar'" ]]
  run encode_json_nulls null,null
  [[ $status == 1 ]]
}

@test "encode_json_autos" {
  [[ $(encode_json_autos) == '' ]]
  [[ $(encode_json_autos 42) == '42' ]]
  [[ $(encode_json_autos hi) == '"hi"' ]]
  [[ $(encode_json_autos true) == 'true' ]]
  [[ $(encode_json_autos true hi 42) == 'true,"hi",42' ]]
  [[ $(encode_json_autos true,false foo bar 42) == '"true,false","foo","bar",42' ]]
  
  # strings containing the auto marker are not a problem
  [[ $(encode_json_autos true 'fo_\_o' bar 42) == 'true,"fo_\\_o","bar",42' ]]
}

_pattern_type=$':(auto|bool|null|number|raw|string)(\\[\\])?'

_pattern_ref_key=$'@(\w+)'
_pattern_inline_key=$'([^:=@]+)'

_pattern_ref_value=$'@=(\w+)'
_pattern_inline_value=$'=(.*)'

_pattern_key="${_pattern_ref_key:?}|${_pattern_inline_key:?}"
_pattern_value="${_pattern_ref_value:?}|${_pattern_inline_value:?}"

_pattern_arg="^(${_pattern_key:?})?(${_pattern_type:?})?(${_pattern_value:?})?$"

function parse_arg() {
  printf 'matching: %s\n' "$1"
  if [[ $1 =~ $_pattern_arg ]]; then
    declare -p BASH_REMATCH
  else
    echo "parse_arg(): failed to match: '$1'" >&1
    return 1
  fi
}

@test "parse argument" {
  # foo:bool=true
  # foo:string=value
  # foo:string=@foo
  # abc:string
  # @foo@=val
  printf "pattern:\n%s\n" "${_pattern_arg:?}"
  
  [[ ':number' =~ $_pattern_arg ]]
  [[ ':number[]' =~ $_pattern_arg ]]
  [[ ':number[]' =~ $_pattern_arg ]]

  # parse_arg @foo:string=123
  # parse_arg @foo:string[]=123
  # parse_arg @foo:raw[]='{"a":1,"b":[2]}'
  # parse_arg @foo:raw[]@=things
  parse_arg @foo:raw[]@=things
  parse_arg @foo:raw[]=things
  parse_arg @foo:raw[]=
  parse_arg @foo:raw[]
  false
}