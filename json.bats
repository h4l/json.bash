#!/usr/bin/env bats
# shellcheck shell=bash
set -u -o pipefail

bats_require_minimum_version 1.5.0

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

  run json.encode_number ''
  [[ $status == 1 && $output == *"not all inputs are numbers: ''" ]]

  input=('')
  in=input run json.encode_number
  [[ $status == 1 && $output == *"not all inputs are numbers: ''" ]]

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

  for invalid in "${invalid_json[@]:?}"; do
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

# Verify that a json.encode_${type} function handles in & out parameters correctly
function assert_input_encodes_to_output_under_all_calling_conventions() {
  : "${input?}" "${output:?}" "${join?}"
  local buff1=() buff2=() IFS
  local stdout1=$(mktemp_bats); local stdout2=$(mktemp_bats)
  # Note: join is passed implicitly/automatically

  # There are 4 ways to call - {in array, in args} x {out stdout, out array}
  out=''    in=''    "json.encode_${type:?}" "${input[@]}"   > "${stdout1:?}"
  out=''    in=input "json.encode_${type:?}"                 > "${stdout2:?}"
  out=buff1 in=''    "json.encode_${type:?}" "${input[@]}"
  out=buff2 in=input "json.encode_${type:?}"


  IFS=${join?}; joined_output=${output[*]}
  echo -n "$joined_output" | diff -u - "${stdout1:?}"
  echo -n "$joined_output" | diff -u - "${stdout2:?}"

  # When a join character is set, the encode fn joins inputs and outputs 1 result
  if [[ $join ]]; then
    [[ ${#buff1[@]} == 1 ]]
    [[ ${#buff2[@]} == 1 ]]
    [[ ${buff1[0]} == "${joined_output:?}" ]]
    [[ ${buff2[0]} == "${joined_output:?}" ]]
  else
    [[ ${#buff1[@]} == "${#output[@]}" ]]
    [[ ${#buff2[@]} == "${#output[@]}" ]]
    for i in "${!buff1[@]}"; do
      [[ ${buff1[$i]} == "${output[$i]}" ]]
      [[ ${buff2[$i]} == "${output[$i]}" ]]
    done
  fi
}

@test "json.encode_* in/out calling convention" {
  # Verify that the encode functions correctly handle in and out parameters
  local input=() buff=()
  local -A examples=(
    [string_in]=$'a b\nc d\n \n' [string_out]='"a b\nc d\n \n"'
    [number_in]='-42.4e2'        [number_out]='-42.4e2'
    [bool_in]='false'            [bool_out]='false'
    [true_in]='true'             [true_out]='true'
    [false_in]='false'           [false_out]='false'
    [null_in]='null'             [null_out]='null'
    [auto_in]='hi'               [auto_out]='"hi"'
    [raw_in]='{"msg":"hi"}'      [raw_out]='{"msg":"hi"}'
    [json_in]='{"msg":"hi"}'     [json_out]='{"msg":"hi"}'
  )

  # for type in auto; do
  for type in string number bool true false null auto raw json; do
    raw="${examples[${type:?}_in]:?}" enc="${examples[${type:?}_out]:?}"

    if [[ $type != @(string|auto) ]]; then
      run "json.encode_${type:?}" ''
      [[ $status == 1 && $output =~ "json.encode_${type:?}(): ".+ ]]

      out=buff run "json.encode_${type:?}" ''
      [[ $status == 1 && $output =~ "json.encode_${type:?}(): ".+ ]]

      input=('')
      in=input run "json.encode_${type:?}"
      [[ $status == 1 && $output =~ "json.encode_${type:?}(): ".+ ]]

      in=input out=buff run "json.encode_${type:?}"
      [[ $status == 1 && $output =~ "json.encode_${type:?}(): ".+ ]]
    else
      # Single empty
      input=('') output=('""')
      join=''  assert_input_encodes_to_output_under_all_calling_conventions
      join=',' assert_input_encodes_to_output_under_all_calling_conventions
    fi

    # Multiple inputs
    input=("${raw:?}" "${raw:?}") output=("${enc:?}" "${enc:?}")
    join=''  assert_input_encodes_to_output_under_all_calling_conventions
    join=',' assert_input_encodes_to_output_under_all_calling_conventions
    # Multiple inputs
    input=("${raw:?}" "${raw:?}") output=("${enc:?}" "${enc:?}")
    join=''  assert_input_encodes_to_output_under_all_calling_conventions
    join=',' assert_input_encodes_to_output_under_all_calling_conventions
  done
}

@test "json.stream_encode_string" {
  local json_chunk_size=2 buff=()
  for json_chunk_size in '' 2; do
    run json.stream_encode_string < <(printf 'foo')
    [[ $status == 0 && $output == '"foo"' ]]

    run json.stream_encode_string < <(printf 'foo bar\nbaz boz\nabc')
    [[ $status == 0 && $output == '"foo bar\nbaz boz\nabc"' ]]
  done

  # out_cb names a function that's called for each encoded chunk
  stdout_file=$(mktemp_bats)
  json_chunk_size=2
  out=buff out_cb=__json.stream_encode_cb json.stream_encode_string \
    < <(printf 'abcdefg') > "${stdout_file:?}"

  # out_cb is called incrementally. It's not called after the initial or ending
  # " though.
  [[ $(<"${stdout_file:?}") == $'CB: ab\nCB: cd\nCB: ef\nCB: g' ]]

  [[ ${#buff[@]} == 6 && ${buff[0]} == '"' && ${buff[1]} == 'ab' \
    && ${buff[2]} == 'cd' && ${buff[3]} == 'ef' && ${buff[4]} == 'g' \
    && ${buff[5]} == '"'  ]]
}

function __json.stream_encode_cb() {
  printf 'CB: %s\n' "${buff[-1]}"
}

@test "json.stream_encode_raw" {
  local json_chunk_size=2 buff=()
  for json_chunk_size in '' 2; do
    # As with json.encode_raw, it fails if the input is empty
    run json.stream_encode_raw < <(printf '')
    [[ $status == 1 && $output == \
      'json.stream_encode_raw(): raw JSON value is empty' ]]

    run json.stream_encode_raw < <(printf '{"foo":true}')
    echo "$status $output"
    [[ $status == 0 && $output == '{"foo":true}' ]]

    # Trailing newlines are not striped from file contents
    diff <(json.stream_encode_raw < <(printf '{\n  "foo": true\n}\n')) \
         <(printf '{\n  "foo": true\n}\n')
  done

  # out_cb names a function that's called for each encoded chunk
  stdout_file=$(mktemp_bats)
  json_chunk_size=2
  out=buff out_cb=__json.stream_encode_cb json.stream_encode_raw \
    < <(printf '["abc"]') > "${stdout_file:?}"

  [[ $(<"${stdout_file:?}") == $'CB: ["\nCB: ab\nCB: c"\nCB: ]' ]]

  [[ ${#buff[@]} == 4 && ${buff[0]} == '["' && ${buff[1]} == 'ab' \
    && ${buff[2]} == 'c"' && ${buff[3]} == ']' ]]
}

function get_value_encode_examples() {
  example_names=(string_notrim string_trim number bool{1,2} true false null auto{1,2} raw json)
  examples+=(
    # json.stream_encode_string preserves trailing whitespace/newlines
    [string_notrim_in]=$'a b\nc d\n \n' [string_notrim_out]='"a b\nc d\n \n"' [string_notrim_type]=string [string_notrim_cb]=2
    # json.encode_value_from_file trims trailing whitespace. However it's not
    # currently called via json(), because json.encode_from_file always uses
    # json.stream_encode_string.
    [string_trim_in]=$'a b\nc d\n \n'   [string_trim_out]='"a b\nc d"'        [string_trim_type]=string

    [number_in]='-42.4e2'        [number_out]='-42.4e2'
    [bool1_in]='true'            [bool1_out]='true'             [bool1_type]=bool
    [bool2_in]='false'           [bool2_out]='false'            [bool2_type]=bool
    [true_in]='true'             [true_out]='true'
    [false_in]='false'           [false_out]='false'
    [null_in]='null'             [null_out]='null'
    [auto1_in]='hi'              [auto1_out]='"hi"'             [auto1_type]=auto
    [auto2_in]='42'              [auto2_out]='42'               [auto2_type]=auto
    [raw_in]='{"msg":"hi"}'      [raw_out]='{"msg":"hi"}'       [raw_cb]=2
    [json_in]='{"msg":"hi"}'     [json_out]='{"msg":"hi"}'
  )
}

@test "json.encode_value_from_file" {
  local actual buff json_chunk_size=8 cb_count=0
  local example_names; local -A examples; get_value_encode_examples

  for name in "${example_names[@]:?}"; do
    type=${examples[${name}_type]:-${name:?}}

    # json.encode_value_from_file trims whitespace from the file contents before
    # encoding.
    if [[ $name == string_notrim ]]; then continue; fi

    # output to stdout
    out='' type=${type:?} run json.encode_value_from_file \
      < <(echo -n "${examples["${name:?}_in"]}" )
    [[ $status == 0 && $output == "${examples[${name:?}_out]:?}" ]]

    # output to array
    buff=()
    out=buff type=${type:?} json.encode_value_from_file \
      < <(echo -n "${examples["${name:?}_in"]}" )

    printf "expected:\n%s\n" "${examples[${name:?}_out]:?}"
    printf "actual:\n%s\n" "${buff[0]}"

    [[ $status == 0 && ${#buff[@]} == 1 \
      && ${buff[0]} == "${examples[${name:?}_out]:?}" ]]
  done
}

@test "json.encode_value_from_file :: stops reading after null byte" {
  type=string run json.encode_value_from_file \
      < <(printf "foo\x00"; timeout 3 yes )
  [[ $status == 0 && $output == '"foo"' ]]
}

@test "json.encode_from_file :: single value" {
  local actual buff json_chunk_size=8 cb_count
  local tmp=$(mktemp_bats)
  local example_names; local -A examples; get_value_encode_examples

  for name in "${example_names[@]:?}"; do
    type=${examples[${name}_type]:-${name:?}}

    # When encoding strings, json.encode_from_file always uses
    # json.stream_encode_string, never json.encode_value_from_file, so it
    # preserves trailing whitespace.
    if [[ $name == string_trim ]]; then continue; fi

    # output to stdout
    cb_count=0
    type=${type:?} out_cb=_increment_cb_count json.encode_from_file \
      < <(echo -n "${examples["${name:?}_in"]}" ) > "${tmp:?}"
    echo -n "${examples[${name:?}_out]:?}" | diff - "${tmp:?}"
    [[ $cb_count == ${examples[${name:?}_cb]:-0} ]]

    # output to array
    buff=() cb_count=0
    out=buff type=${type:?} out_cb=_increment_cb_count json.encode_from_file \
      < <(echo -n "${examples["${name:?}_in"]}" )
    printf -v actual '%s' "${buff[@]}"
    [[ $actual == "${examples[${name:?}_out]:?}" ]]
    [[ $cb_count == ${examples[${name:?}_cb]:-0} ]]
  done
}

function _increment_cb_count() { let ++cb_count; }

function get_array_encode_examples() {
  example_names=(string number bool true false null auto raw json)
  examples+=(
    [string_in]=$'a b\nc d\n \n'     [string_out]=$'"a b","c d"," "'
    [number_in]=$'1\n2\n3\n'         [number_out]=$'1,2,3'
    [bool_in]=$'true\nfalse\n'       [bool_out]=$'true,false'
    [true_in]=$'true\ntrue\n'        [true_out]=$'true,true'
    [false_in]=$'false\nfalse\n'     [false_out]=$'false,false'
    [null_in]=$'null\nnull\n'        [null_out]=$'null,null'
    [auto_in]=$'hi\n42\ntrue\n'      [auto_out]=$'"hi",42,true'
    [raw_in]=$'{"msg":"hi"}\n42\n'   [raw_out]=$'{"msg":"hi"},42'
    [json_in]=$'{"msg":"hi"}\n42\n'  [json_out]=$'{"msg":"hi"},42'
  )
}

@test "json.encode_from_file :: array" {
  local json_buffered_chunk_count=2 cb_count
  local tmp=$(mktemp_bats)
  local example_names; local -A examples; get_array_encode_examples

  for type in "${example_names[@]:?}"; do
    # output to stdout
    cb_count=0
    array=true split=$'\n' out_cb=_increment_cb_count json.encode_from_file \
      < <(echo -n "${examples["${type:?}_in"]}" ) > "${tmp:?}"
    echo -n "[${examples[${type:?}_out]:?}]" | diff - "${tmp:?}"
    echo "${cb_count@Q}"
    [[ $cb_count == 1 ]]

    # output to array
    buff=() cb_count=0
    out=buff array=true split=$'\n' out_cb=_increment_cb_count \
      json.encode_from_file < <(echo -n "${examples["${type:?}_in"]}" )
    printf -v actual '%s' "${buff[@]}"
    [[ "${actual:?}" == "[${examples[${type:?}_out]:?}]" ]]
    [[ $cb_count == 1 ]]
  done
}

@test "json.stream_encode_array :: stops reading file on error" {
  local json_buffered_chunk_count=2
  # We stop reading the stream if an element is invalid
  split=$'\n' type=number run json.stream_encode_array \
    < <(seq 3; timeout 3 yes ) # stream a series of non-int values forever

  [[ $status == 1 && $output == \
    "[1,2,json.encode_number(): not all inputs are numbers: '3' 'y'" ]]
}

@test "json.stream_encode_array :: json_buffered_chunk_count=1 callback" {
  # json_buffered_chunk_count=1 results in readarray invoking the chunks
  # available callback with an empty array, which is a bit of an edge case.
  json_buffered_chunk_count=1 split=$'\n' type=string \
    run json.stream_encode_array < <(printf '' )
  [[ $status == 0 && $output == '[]' ]]
  json_buffered_chunk_count=1 split=$'\n' type=string \
    run json.stream_encode_array < <(printf 'foo\n' )
  [[ $status == 0 && $output == '["foo"]' ]]
  json_buffered_chunk_count=1 split=$'\n' type=string \
    run json.stream_encode_array < <(printf 'foo\nbar\n' )
  [[ $status == 0 && $output == '["foo","bar"]' ]]
}

@test "json.stream_encode_array" {
  local buff json_buffered_chunk_count=2
  local example_names; local -A examples; get_array_encode_examples
  for type in "${example_names[@]:?}"; do
    # Empty file
    split=$'\n' type=${type:?} run json.stream_encode_array < <(echo -n '' )
    [[ $status == 0 && $output == "[]" ]]

    buff=() output=''
    out=buff split=$'\n' type=${type:?} json.stream_encode_array < <(echo -n '' )
    printf -v output '%s' "${buff[@]}"
    [[ $status == 0 && $output == "[]" ]]

    # Non-empty file
    split=$'\n' type=${type:?} run json.stream_encode_array \
      < <(echo -n "${examples["${type:?}_in"]}" )
    [[ $status == 0 && $output == "[${examples[${type:?}_out]:?}]" ]]

    buff=() output=''
    out=buff split=$'\n' type=${type:?} json.stream_encode_array \
      < <(echo -n "${examples["${type:?}_in"]}" )
    printf -v output '%s' "${buff[@]}"
    [[ $status == 0 && $output == "[${examples[${type:?}_out]:?}]" ]]
  done

  # out_cb names a function that's called for each encoded chunk
  buff=()
  stdout_file=$(mktemp_bats)
  out=buff out_cb=__json.stream_encode_cb split=',' type=string \
    json.stream_encode_array < <(printf 'a,b,c,d,e,f,g') > "${stdout_file:?}"

  # out_cb is called incrementally. It's not called after the initial or ending
  # [ ] though.
  echo -n $'CB: "a","b"\nCB: "c","d"\nCB: "e","f"\n' | diff -u - "${stdout_file:?}"

  local expected=('[' '"a","b"' ',' '"c","d"' ',' '"e","f"' ',' '"g"' ']')
  assert_array_equals expected buff
}

@test "json file input trailing newline handling" {
  local chunk lines expected
  # We mirror common shell behaviour of trimming newlines on input and creating
  # them on output.
  # e.g. command substitution trims newlines
  [[ $'foo\nbar' == "$(printf 'foo\nbar\n')" ]]
  # As does read (unless -N is used)
  read -r -d '' chunk < <(printf 'foo\nbar\n') || true
  [[ $'foo\nbar' == "$chunk" ]]
  # readarray preserves by default, but trims if -t is specified
  readarray -t chunk < <(printf 'foo\nbar\n')
  expected=(foo bar)
  assert_array_equals expected chunk
  # And word splitting
  lines=$'foo\nbar\n'
  chunk=($lines)
  assert_array_equals expected chunk

  # We trim whitespace when reading all types, except string and raw values.
  # e.g. json output is terminated by a newline
  diff <(json) <(printf '{}\n')
  # But the newline is trimed when inserting one json call into another:
  diff <(json a:json@=<(json)) <(printf '{"a":{}}\n')
  # Notice that the shell's own command substitution does the same thing
  diff <(json a:json="$(json)") <(printf '{"a":{}}\n')
  # This behaviour means numbers parse from files without needing to explicitly
  # support trailing whitespace json.encode_number:
  diff <(json a:number="$(echo 1)" b:number@=<(echo 2)) <(printf '{"a":1,"b":2}\n')
  # And similarly, arrays of numbers are trimmed of whitespace with the default
  # newline delimiter
  diff <(json a:number[]="$(seq 2)" b:number[]@=<(seq 2)) <(printf '{"a":[1,2],"b":[1,2]}\n')

  # The first exception is string values, which preserve trailing newlines. This
  # is the default behaviour because a string exactly represents a text file's
  # contents, and newlines are significant content. If we trimmed them then
  # users would have no easy way to put them back. But users are able to trim
  # them themselves if they don't want them.
  diff <(json nl@=<(printf 'foo\n')) <(printf '{"nl":"foo\\n"}\n')
  diff <(json no_nl@=<(echo -n 'foo')) <(printf '{"no_nl":"foo"}\n')

  # The second execption is raw values. The raw type serves as an escape hatch,
  # passing JSON as-is, without validation, so it seems natural to not modify
  # their data by trimming newlines.
  diff <(json formatted:raw@=<(printf '\n{\n  "msg": "hi"\n}\n')) \
       <(printf '{"formatted":\n{\n  "msg": "hi"\n}\n}\n')
  # Note that, when creating raw arrays with the (default) newline delmiter, the
  # delimiter is removed from the each value. This is the same as for arrays of
  # all types — the delimiter is not considered to be part of the value.
  diff <(json formatted:raw[]@=<(printf '{}\n[]\n"hi"\n')) \
       <(printf '{"formatted":[{},[],"hi"]}\n')
  # Users can exercise precise control using null-terminated entries:
  diff <(json formatted:raw[split=]@=<(printf '{\n}\n\n\x00[\n]\n\n\x00"hi"\n\n\x00')) \
       <(printf '{"formatted":[{\n}\n\n,[\n]\n\n,"hi"\n\n]}\n')
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

  # The default split character is line feed (\n), so each line is an array
  # element. This integrates with line-oriented command-line tools:
  json sizes[]="$(seq 3)" | equals_json '{sizes: ["1","2","3"]}'
  json sizes:number[]="$(seq 3)" | equals_json '{sizes: [1, 2, 3]}'

  # The same applies when reading arrays from files
  # (Note that <(seq 3) is a shell construct (process substitution) that prints
  # the path to a file containing the output of the `seq 3` command (1 2 3 on
  # separate lines.)
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

  # Property names can come from files
  json @<(printf prop_name)=value | equals_json '{prop_name: "value"}'
}

@test "json.bash json errors :: do not produce partial JSON output" {
  # No partial output on errors — either json suceeds with output, or fails with
  # no output.
  run json foo=bar error:number=notanumber
  [[ $status == 1 ]]
  # no JSON in output:
  [[ ! $output =~ '{' ]]
  echo "${output@Q}"
  [[ "$output" == *"failed to encode value as number: 'notanumber' from 'error:number=notanumber'"* ]]

  # Same for array output
  local buff=() err=$(mktemp_bats)
  # Can't use run because it forks, and the fork can't write to our buff
  out=buff json ok:true
  out=buff json foo=bar error:number=notanumber 2> "${err:?}" || status=$?
  out=buff json garbage:false

  [[ ${status:-} == 1 ]]
  [[ ! $(cat "${err:?}") =~ '{' ]]
  [[ $(cat "${err:?}") == \
    *"failed to encode value as number: 'notanumber' from 'error:number=notanumber'"* ]]
  declare -p buff
  [[ ${#buff[@]} == 3 && ${buff[0]} == '{"ok":true}' \
    && ${buff[1]} == $'\x18' && ${buff[2]} == '{"garbage":false}' ]]
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
  for arg in "${invalid_args[@]:?}"; do
    run json "${arg:?}"
    [[ $status == 2 && $output =~ "invalid argument: '${arg:?}'" ]] || {
      echo "arg '$arg' did not fail: $output" >&2; return 1
    }
  done

  # Invalid type in json_defaults is an error
  json_defaults=type=cheese run json
  [[ $status == 2 && $output =~ "json_defaults contains invalid 'type': 'cheese'" ]]
  declare -g -A json_defaults=([type]=peas)
  run json
  [[ $status == 2 && $output =~ "json_defaults contains invalid 'type': 'peas'" ]]
  unset json_defaults

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
  [[ $status == 3 && $output =~ \
    "argument references unbound variable: \$__missing from '@__missing" ]]

  missing_file=$(mktemp_bats --dry-run)
  # references to missing files are errors
  # ... when used as keys
  run json @${missing_file:?}=value
  [[ $status == 4 && $output =~ \
    "json(): failed to read file referenced by argument: '${missing_file:?}' from '@${missing_file:?}=value'" ]]

  # ... and when used as values
  run json key@=${missing_file:?}
  echo "$output"
  [[ $status == 4 && $output =~ \
    "json(): failed to read file referenced by argument: '${missing_file:?}' from 'key@=${missing_file:?}'" ]]
}

@test "json errors are signaled in-band by writing a 0x18 Cancel control character" {
  local bad_number=abc
  local bad_number_file=$(mktemp_bats); printf def > "${bad_number_file:?}"
  declare -A examples=(
    [bad_defaults_cmd]='ok'            [bad_defaults_status]=2     [bad_defaults_defaults]='type=bad'
    [arg_syntax_error_cmd]='foo[=bar'  [arg_syntax_error_status]=2
    [bad_return_cmd]='ok'              [bad_return_status]=2       [bad_return_return]='bad'

    [unbound_key_var_cmd]='@__bad='      [unbound_key_var_status]=3
    [unbound_val_var_cmd]='a@=__bad'     [unbound_val_var_status]=3
    [missing_key_file_cmd]='@./__bad='   [missing_key_file_status]=4
    [missing_val_file_cmd]='a@=./__bad=' [missing_val_file_status]=4

    [invalid_val_file_cmd]="a:number@=${bad_number_file:?}"         [invalid_val_file_status]=1
    [invalid_val_array_file_cmd]="a:number[]@=${bad_number_file:?}" [invalid_val_array_file_status]=1
    [invalid_val_var_cmd]="a:number@=bad_number"                    [invalid_val_var_status]=1
    [invalid_val_array_var_cmd]="a:number[]@=bad_number"            [invalid_val_array_var_status]=1
    [invalid_val_str_cmd]="a:number=bad"                            [invalid_val_str_status]=1
    [invalid_val_array_str_cmd]="a:number[]=bad"                    [invalid_val_array_str_status]=1
  )
  readarray -t example_names < \
    <(grep -P '_cmd$' <(printf '%s\n' "${!examples[@]}") | sed -e 's/_cmd$//' | sort)

  for name in "${example_names[@]:?}"; do
    local defaults=${examples[${name:?}_defaults]:-}
    local return=${examples[${name:?}_return]:-}
    local expected_status=${examples[${name:?}_status]:?}
    local cmd=${examples[${name:?}_cmd]:?}

    for json_stream in '' true; do
      json_return=${return?} json_defaults=${defaults?} \
        run --separate-stderr json "${cmd:?}"
      [[ $status == $expected_status && $stderr =~ "json():" \
        && ${output:(( ${#output} - 1 ))} == $'\x18' ]]

      local buff=() status=0
      json_return=${return?} json_defaults=${defaults?} out=buff json "${cmd:?}" || status=$?
      [[ $status == $expected_status && ${buff[-1]} == $'\x18' ]]
      echo "name=${name@Q} json_stream=${json_stream@Q}"
    done
  done
}

@test "json.bash the stream-poisoning Cancel character is visually marked with ␘ when the output is an interactive terminal" {
  local stdout=$(mktemp_bats) stderr=$(mktemp_bats) status=0

  # Running under script simulates an interactive terminal
  SHELL=$(command -v bash) ERR=${stderr:?} \
    script -qefc '. json.bash; json a:number=oops 2> "${ERR:?}"' /dev/null \
    > "${stdout:?}" || status=$?

  # Output contains both a real 0x18 Cancel char, and a symbolic version:
  diff -u <(printf '\x18␘\r\n') "${stdout:?}"
  # Note: We see \r\n despite printing \n because TTYs translate \n into \r\n,
  # e.g. see: https://pexpect.readthedocs.io/en/stable/overview.html#find-the-end-of-line-cr-lf-conventions

  err="json.encode_number(): not all inputs are numbers: 'oops'
json(): failed to encode value as number: 'oops' from 'a:number=oops'
"
  diff -u <(printf "${err:?}") "${stderr:?}"
  [[ $status == 1 ]]
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

@test "json streaming output with json_stream=true :: arrays" {
  # By default json collects output in a buffer and only emits it in one go.
  # This behaviour is intended to prevent partial output in the case of errors.
  # But incremental output can be desirable when stream-encoding from a pipe or
  # large file.
  in_pipe=$(mktemp_bats --dry-run); out_pipe=$(mktemp_bats --dry-run)
  mkfifo "${in_pipe:?}" "${out_pipe:?}"

  json_buffered_chunk_count=1 json_stream=true \
    json before="I am first!" content:json[]@=${in_pipe:?} after="I am last!" \
    > "${out_pipe:?}" &

  exec 7<"${out_pipe:?}"  # open the in/out pipes
  exec 6>"${in_pipe:?}"

  expect_read 7 '{"before":"I am first!","content":['
  json msg="Knock knock!" >&6
  expect_read 7 '{"msg":"Knock knock!"}'
  json msg="Who is there?" >&6
  expect_read 7 ',{"msg":"Who is there?"}'
  exec 6>&-  # close the input
  expect_read 7 $'],"after":"I am last!"}\n'
  exec 7>&-  # close the output
  wait %1
}

@test "json streaming output with json_stream=true :: string/raw" {
  # As well as arrays, the string and raw types support streamed output from
  # files. The result of this is that string and raw values are written out
  # incrementally, without buffering the whole value in memory. This test
  # demonstrates this by writing string and raw values across several separate
  # writes, while reading the partial output as it's emitted.
  in_key=$(mktemp_bats --dry-run) in_string=$(mktemp_bats --dry-run);
  in_raw=$(mktemp_bats --dry-run); out_pipe=$(mktemp_bats --dry-run);
  mkfifo "${in_key:?}" "${in_string:?}" "${in_raw:?}" "${out_pipe:?}"

  json_chunk_size=12 json_stream=true json \
    streamed_string@="${in_string:?}" \
    @"${in_key:?}=My property name is streamed" \
    streamed_raw:raw@="${in_raw:?}" \
    > "${out_pipe:?}" &

  exec 7<"${out_pipe:?}"  # open the output that json is writing to

  # Generate the string value of the first property
  exec 6>"${in_string:?}"  # open the pipe that json is reading the string from
  expect_read 7 '{"streamed_string":"'
  printf 'This is the ' >&6
  expect_read 7 'This is the '
  printf 'content of t' >&6
  expect_read 7 'content of t'
  printf 'he string.\n\n' >&6
  expect_read 7 'he string.\n\n'
  exec 6>&-  # close in_string

  # Generate the property name of the second property
  exec 6>"${in_key:?}"
  printf 'This is the property name' >&6
  expect_read 7 '","This is the property nam'
  printf '. It could be quite long, but probably best not to do that.' >&6
  expect_read 7 'e. It could be quite long, but probably best not'
  exec 6>&-  # close in_key

  expect_read 7 ' to do that.":"My property name is streamed","streamed_raw":'

  # Generate the raw value of the third property
  exec 6>"${in_raw:?}"
  printf '[' >&6
  json msg="I'm in ur script" >&6
  expect_read 7 '[{"msg":"I'\''m in ur scrip'
  printf ',' >&6
  json msg="generating JSON" >&6
  printf ']' >&6
  expect_read 7 $'t"}\n,{"msg":"generating '
  exec 6>&-  # close in_raw
  expect_read 7 $'JSON"}\n]}\n'

  exec 7>&-  # close the output
  wait %1
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

function assert_array_equals() {
  local -n left=${1:?} right=${2:?}
  declare -p left right
  if [[ ${left@a} != *a* ]]; then
    echo "assert_array_equals: left is not an array var" >&2; return 1
  fi
  if [[ ${right@a} != *a* ]]; then
    echo "assert_array_equals: right is not an array var" >&2; return 1
  fi

  if [[ ${#left[@]} != ${#right[@]} ]]; then
    echo "assert_array_equals: arrays have different lengths:" \
      "${#left[@]} != ${#right[@]}" >&2; return 1;
  fi

  for i in "${!left[@]}"; do
    if [[ ${left[$i]} != ${right[$i]} ]]; then
      echo "assert_array_equals: arrays are unequal at index $i:" \
        "${left[$i]@Q} != ${right[$i]@Q}" >&2
      return 1
    fi
  done
}

function expect_read() {
  local fd=${1:?} expected=${2:?} status=0
  read -r -t 1 -N "${#expected}" -u "${fd:?}" actual || status=$?
  if (( $status > 128 )); then
    echo "expect_read: read FD ${fd:?} timed out" >&2
    return 1
  elif (( $status > 0 )); then
    echo "expect_read: read returned status=$status" >&2
  fi

  if [[ $expected != "$actual" ]]; then
    echo "expect_read: read result did not match expected:" \
      "expected=${expected@Q}, actual=${actual@Q}" >&2
    return 1
  fi
}
