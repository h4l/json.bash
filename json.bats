# shellcheck shell=bash

setup_file() {
  cd "${BATS_TEST_DIRNAME:?}"
}

setup() {
  source ./json.bash
}

@test "encode_json_strings" {
  [[ $(encode_json_strings foo) == '"foo"' ]]
  [[ $(encode_json_strings foo $'bar\nbaz\tboz\n') == '"foo","bar\nbaz\tboz\n"' ]]
}

@test "json creates objects" {
  # [[ $(foo=123 bar="hey lol" json foo bar) \
  #    == '{"foo":"123","bar":"hey lol"}' ]]

  bar=("abc 123" $'foo\nbar\n')
  # [[ $(foo=123 json foo "bar:array" "foo:array=My Key") \
  #    == '{"foo":"123","bar":["abc 123","foo\nbar\n"],"My Key":["123"]}' ]]

  jq <<<"$(\
    foo=123
    json activate:true disconnect:false parent:null \
    foo=auto_foo foo:number=number_foo foo:string=string_foo foo:array=array_foo \
    bar:array \
  )" -e 'debug | . == {
    activate: true, disconnect: false, parent: null,
    auto_foo: 123, number_foo: 123, string_foo: "123", array_foo: ["123"],
    bar: ["abc 123", "foo\nbar\n"]
  }'
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

