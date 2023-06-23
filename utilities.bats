#!/usr/bin/env bats
# shellcheck shell=bash
set -o pipefail

# Tests for the jb-echo jb-cat and jb-stream utilities.

setup() {
  cd "${BATS_TEST_DIRNAME:?}"
}

function mktemp_bats() {
  mktemp "${BATS_RUN_TMPDIR:?}/json.bats.XXX" "$@"
}

@test "jb-echo" {
  run jb-echo
  [[ $status == 0 && $output == '[]' ]]
  run jb-echo "Hello World"
  [[ $status == 0 && $output == '["Hello World"]' ]]
  run jb-echo foo bar baz
  [[ $status == 0 && $output == '["foo","bar","baz"]' ]]
}

@test "jb-cat" {
  run sh -c 'printf "" | jb-cat'
  [[ $status == 0 && $output == '""' ]]
  run sh -c 'printf "\n" | jb-cat'
  [[ $status == 0 && $output == '"\n"' ]]
  run sh -c 'printf "foo\nbar\n" | jb-cat'
  [[ $status == 0 && $output == '"foo\nbar\n"' ]]

  dir=$(mktemp_bats -d)
  printf "foo\nbar\n" > "${dir:?}/a"
  printf "baz\nboz\n" > "${dir:?}/b"

  run jb-cat "${dir:?}/a"
  [[ $status == 0 && $output == '"foo\nbar\n"' ]]
  run jb-cat "${dir:?}/a" "${dir:?}/b"
  [[ $status == 0 && $output == '"foo\nbar\nbaz\nboz\n"' ]]
}

@test "jb-stream" {
  run sh -c 'printf "" | jb-stream'
  [[ $status == 0 && $output == '' ]]
  run sh -c 'printf "\n" | jb-stream'
  [[ $status == 0 && $output == '""' ]]
  run sh -c 'printf "foo\n" | jb-stream'
  [[ $status == 0 && $output == $'"foo"' ]]
  run sh -c 'printf "foo\nbar\n" | jb-stream'
  [[ $status == 0 && $output == $'"foo"\n"bar"' ]]
}
