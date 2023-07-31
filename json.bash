#!/usr/bin/env bash
# shellcheck disable=SC2120
shopt -s extglob # required to match our auto glob patterns

JSON_BASH_VERSION=0.1.0

declare -g -A _json_defaults=()

function json.is_compatible() {
  # musl-libc's regex implementation erases previously-matched capture groups,
  # which causes our patterns to not capture correctly. Not sure if their
  # behaviour is valid/correct or not, but it doesn't work right now.
  # shellcheck disable=SC2050
  if [[ 'aba' =~ ^(a|(b)){3}$ && ${BASH_REMATCH[2]} == '' ]]; then
    json.signal_error "json.detect_incompatibility(): detected incompatible" \
      "regex implementation: your shell's regex implementation forgets" \
      "previously-matched capture groups"; return 1
  fi
}

if shopt -q patsub_replacement 2>/dev/null; then declare -g _json_bash_feat_patsub=true; fi

# Generated in hack/argument_pattern.bash
_json_bash_005_p1_key=$'^(\\.*)(($|:)|([+~?]*)([^.+~?:]((::|==|@@)|[^:=@])*)?)'
_json_bash_005_p2_meta=$'^:([a-zA-Z0-9]+)?([{[](.?)(:[a-zA-Z0-9_]+)?[]}])?(/((//|,,|==)|[^/])*/)?'
_json_bash_005_p3_value=$'^([+~?]*)([@=]?)'
_json_bash_type_name_pattern=$'^(auto|bool|false|json|null|number|raw|string|true)$'
_json_bash_number_pattern='-?(0|[1-9][0-9]*)(\.[0-9]*)?([eE][+-]?[0-9]+)?'
_json_bash_auto_pattern="\"(null|true|false|${_json_bash_number_pattern:?})\""
_json_bash_number_glob='?([-])@(0|[1-9]*([0-9]))?([.]+([0-9]))?([eE]?([+-])+([0-9]))'
_json_bash_auto_glob="\"@(true|false|null|$_json_bash_number_glob)\""
_json_in_err="in= must be set when no positional args are given"
_json_bash_validation_type=$'(j|s|n|b|t|f|z|Oj|Os|On|Ob|Ot|Of|Oz|Aj|As|An|Ab|At|Af|Az)'
declare -gA _json_bash_validation_types=(
  ['json']='j' ['string']='s' ['number']='n' ['bool']='b' ['true']='t' ['false']='f' ['null']='z' ['atom']='a' ['auto']='a'
  ['json_object']='Oj' ['string_object']='Os' ['number_object']='On' ['bool_object']='Ob' ['true_object']='Ot' ['false_object']='Of' ['null_object']='Oz' ['atom_object']='Oa' ['auto_object']='Oa'
  ['json_array']='Aj' ['string_array']='As' ['number_array']='An' ['bool_array']='Ab' ['true_array']='At' ['false_array']='Af' ['null_array']='Az' ['atom_array']='Aa' ['auto_array']='Aa'
)
declare -gA _json_bash_escapes=(
                     [$'\x01']='\u0001' [$'\x02']='\u0002' [$'\x03']='\u0003'
  [$'\x04']='\u0004' [$'\x05']='\u0005' [$'\x06']='\u0006' [$'\x07']='\u0007'
  [$'\b']='\b'       [$'\t']='\t'       [$'\n']='\n'       [$'\x0b']='\u000b'
  [$'\f']='\f'       [$'\r']='\r'       [$'\x0e']='\u000e' [$'\x0f']='\u000f'
  [$'\x10']='\u0010' [$'\x11']='\u0011' [$'\x12']='\u0012' [$'\x13']='\u0013'
  [$'\x14']='\u0014' [$'\x15']='\u0015' [$'\x16']='\u0016' [$'\x17']='\u0017'
  [$'\x18']='\u0018' [$'\x19']='\u0019' [$'\x1a']='\u001a' [$'\x1b']='\u001b'
  [$'\x1c']='\u001c' [$'\x1d']='\u001d' [$'\x1e']='\u001e' [$'\x1f']='\u001f')

# Output text, either to stdout or buffer into an array.
#
# If $out is set, arguments are appended to the array variable $out. Otherwise
# arguments go directly to stdout, without any separator between each value.
function json.buffer_output() {
  case "$#:${out:-}" in
  (0:)
    local -n _jbo_in=${in:?"$_json_in_err"};
    printf '%s' "${_jbo_in[@]}";;
  (0:?*)
    local -n _jbo_in=${in:?"$_json_in_err"} _jbo_out=${out:?}
    _jbo_out+=("${_jbo_in[@]}");;
  (*:)
    printf '%s' "$@";;
  (*)
    local -n _jbo_out="${out:?}";
    _jbo_out+=("$@");;
  esac
}

# Encode the positional arguments as JSON strings.
#
# The output goes to stdout or the $out array if set. If $join is not empty,
# all the arguments are joined into a single value and emitted as one.
#
# Implementation note: For performance reasons we have 3 code paths to optimise
# common usage patterns while supporting output of arrays. The common cases are
# a single string and multiple strings joined by , for arrays, or : for
# key:value object entries.
function json.encode_string() {
  local _jes_string _jes_strings _jes_joined _jes_literal _jes_escape
  # TODO: if out is empty we could nameref string to out to avoid a copy at the end
  case $# in
  (1)
    _jes_string=${1//$'\\'/$'\\\\'}               # escape \
    _jes_string=${_jes_string//$'"'/$'\\"'}       # escape "
    _jes_string=${_jes_string//$'\n'/$'\\n'}      # optimistically escape \n
    _jes_string="\"${_jes_string}\""              # wrap in quotes
    while [[ $_jes_string =~ \
              [$'\x01'-$'\x1f\t\n\v\f\r'] ]]; do  # Escape control chars
      _jes_literal=${BASH_REMATCH[0]:?}
      _jes_escape=${_json_bash_escapes[$_jes_literal]:?}
      _jes_string=${_jes_string//$_jes_literal/$_jes_escape}
    done
    if [[ ${out:-} == '' ]]; then echo -n "$_jes_string"
    else local -n _jes_out=${out:?}; _jes_out+=("$_jes_string"); fi
    return;;
  (0)
    local -n _in=${in:?"$_json_in_err"}
    _jes_strings=("${_in[@]//$'\\'/$'\\\\'}");;    # escape \
  (*)
    _jes_strings=("${@//$'\\'/$'\\\\'}");;         # escape \
  esac

  _jes_strings=("${_jes_strings[@]//$'"'/$'\\"'}")      # escape "
  _jes_strings=("${_jes_strings[@]//$'\n'/$'\\n'}")     # optimistically escape \n
  _jes_strings=("${_jes_strings[@]/#/\"}")              # wrap in quotes
  _jes_strings=("${_jes_strings[@]/%/\"}")
  local IFS=${join:-}; _jes_joined="${_jes_strings[*]}";
  local controls=$'\x01\x02\x03\x04\x05\x06\x07\b\t\x0b\f\r\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f'

  if [[ ${join:-} == '' ]]; then
    while [[ $_jes_joined =~ [$controls] ]]; do  # Escape control chars
      _jes_literal=${BASH_REMATCH[0]:?}
      _jes_escape=${_json_bash_escapes[$_jes_literal]:?"no escape for ${_jes_literal@A}"}
      controls=${controls/$_jes_literal/}
      _jes_strings=("${_jes_strings[@]//$_jes_literal/$_jes_escape}")
    done
    in=_jes_strings json.buffer_output
  else
    while [[ $_jes_joined =~ [$controls] ]]; do  # Escape control chars
      _jes_literal=${BASH_REMATCH[0]:?}
      _jes_escape=${_json_bash_escapes[$_jes_literal]:?"no escape for ${_jes_literal@A}"}
      _jes_joined=${_jes_joined//$_jes_literal/$_jes_escape}
    done
    json.buffer_output "$_jes_joined"
  fi
}

function json._encode_value() {
  local _jev_values _jev_join=${join:-,}
  # escape the join char (no-op unless input is invalid)
  if [[ $# == 0 ]]; then
    local -n _in=${in:?"$_json_in_err"}
    _jev_values=("${_in[@]//"${_jev_join:?}"/"\\${_jev_join:?}"}")
  else
    _jev_values=("${@//"${_jev_join:?}"/"\\${_jev_join:?}"}")
  fi

  local IFS; IFS=${_jev_join:?}; joined="${_jev_values[*]}";
  if [[ ! "${_jev_join}$joined" =~ ^(${_jev_join}(${value_pattern:?}))+$ \
        && ( $# != 0 || ${#_in[@]} != 0 ) ]]; then
    echo "json.encode_${type_name/%s/}(): not all inputs are ${type_name:?}:\
$(printf " '%s'" "${_jev_values[@]}")" >&2
    return 1
  fi
  if [[ ${join:-} == '' ]]; then in=_jev_values json.buffer_output
  else IFS=${join}; json.buffer_output "$joined"; fi
}

function json.encode_number() {
  type_name=numbers value_pattern=${_json_bash_number_pattern:?} \
    json._encode_value "$@"
}

function json.encode_bool() {
  type_name=bools value_pattern="true|false" json._encode_value "$@"
}

function json.encode_false() {
  type_name=false value_pattern="false" json._encode_value "$@"
}

function json.encode_true() {
  type_name=true value_pattern="true" json._encode_value "$@"
}

function json.encode_null() {
  type_name=null value_pattern="null" json._encode_value "$@"
}

function json.encode_auto() {
  if [[ $# == 1 ]]; then
    if [[ \"$1\" =~ ^$_json_bash_auto_pattern$ ]]; then
      json.buffer_output "$1"
    else json.encode_string "$1"; fi
    return
  fi

  # Bash 5.2 supports & match references in substitutions, which would make it
  # easy to remove quotes from things matching the auto pattern. But 5.2 is not
  # yet widely available, so we'll implement with a bash-level loop, which is
  # probably quite slow for large arrays.
  # TODO: Add a conditional branch to implement this with & ref substitutions
  local _jea_strings __jea_autos
  out=_jea_strings join='' json.encode_string "$@"
  __jea_autos=("${_jea_strings[@]//$_json_bash_auto_glob/}")
  for ((i=0; i < ${#_jea_strings[@]}; ++i)); do
    if [[ ${#__jea_autos[$i]} == 0 ]];
    then _jea_strings[$i]=${_jea_strings[$i]:1:-1}; fi
  done

  if [[ ${join:-} == '' ]]; then
    json.buffer_output "${_jea_strings[@]}"
  else
    local IFS=${join};
    json.buffer_output "${_jea_strings[*]}";
  fi
}

function json.encode_raw() {
  # Caller is responsible for ensuring values are valid JSON!
  if [[ $# == 0 ]]; then
    local -n _jer_in=${in:?"$_json_in_err"};
    if [[ ${#_jer_in[@]} == 1 && ${_jer_in[@]::1} == '' ]]; then
      echo "json.encode_raw(): raw JSON value is empty" >&2; return 1
    fi
  elif [[ $# == 1 && $1 == "" ]]; then
    echo "json.encode_raw(): raw JSON value is empty" >&2; return 1
  fi

  case $#:${join:-}:${in:-} in
  (*::*)
    json.buffer_output "$@";;
  (0:?*)
    local IFS=${join:?}; json.buffer_output "${_jer_in[*]}";;
  (*)
    local IFS=${join:?}; json.buffer_output "$*";;
  esac
}

function json.encode_json() {
  if ! type=json json.validate "$@"; then
    if [[ $# == 0 ]]; then local -n _jej_in=${in:?"$_json_in_err"};
    else local _jej_in=("$@"); fi
    echo "json.encode_json(): not all inputs are valid JSON:\
$(printf " %s" "${_jej_in[@]@Q}")" >&2
    return 1
  fi

  case $#:${join:-}:${in:-} in
  (*::*)
    json.buffer_output "$@";;
  (0:*)
    local -n _jej_in=${in:?"$_json_in_err"}
    local IFS=${join:?}; json.buffer_output "${_jej_in[*]}";;
  (*)
    local IFS=${join:?}; json.buffer_output "$*";;
  esac
}

# Create a sequence of JSON object entries with values of a consistent type.
#
# Entries are created from one of:
#  - positional arguments: key1, value1, key2, value2...
#  - in=foo naming an associative array of key, value pairs
#  - in=foo naming an indexed array of pre-encoded JSON objects
#  - in=foo,bar naming two indexed arrays of equal length, containing the keys
#    and values
# $type is the type of each entry's value. Input values must be valid for this
# type — pre-encoded entries are validated to be JSON objects holding values of
# this type (unless the type is 'raw', in which case no validation is done).
# Values from other inputs must be valid inputs to the json.encode_$type
# functions.
function json.encode_object_entries() {
  : ${type:?"json.encode_object(): \$type must be provided"}
  if (( $# > 0 )); then
    if (( $# % 2 == 1 )); then
      echo "json.encode_object_entries(): number of arguments is odd - not all keys have values" >&2
      return 1
    fi
    if [[ ${type:?} == string ]]; then
      local _jeo_strings _jeo_string_entries
      out=_jeo_strings join='' json.encode_string "$@"
      printf -v '_jeo_string_entries' '%s:%s,' "${_jeo_strings[@]:?}"
      _jeo_string_entries=${_jeo_string_entries:0: ${#_jeo_string_entries} - 1 }
      json.buffer_output "${_jeo_string_entries:?}"
      return 0
    fi
    local -A _jeo_entries=();
    local -a _jeo_keys=() _jeo_values=()
    local i j; for ((i=1; i<=$#; i+=2)); do
      j=$((i+1)); _jeo_keys+=("${!i?}") _jeo_values+=("${!j?}")
    done
  else case "${in:?"json.encode_object_entries(""): \$in must be set if arguments are not provided"}" in
  (*?,?*)
    local -n _jeo_keys=${in%,*} _jeo_values=${in#*,}
    if [[ ${#_jeo_keys[@]} != "${#_jeo_values[@]}" ]]; then
      echo "json.encode_objects(): unequal number of keys and values:" \
        "${#_jeo_keys[@]} keys, ${#_jeo_values[@]} values" >&2
      return 1
    fi
    ;;
  (*)
    local -n _jeo_entries=${in:?}
    if [[ ${#_jeo_entries[@]} == 0 ]]; then return;
    elif [[ ${_jeo_entries@a} == *A* ]]; then  # entries is an associative array
      local -a _jeo_keys=("${!_jeo_entries[@]}") _jeo_values=("${_jeo_entries[@]}")
    else
      # entries is a regular array containing complete JSON objects
      if [[ ${type:?} != 'raw' ]]; then
        type="${type:?}_object" in=_jeo_entries json.validate || \
          { echo "json.encode_object_entries(): provided entries are not all" \
            "valid JSON objects with ${type@Q} values." >&2; return 1; }
      fi
        local IFS='' _jeo_encoded_entries
        # Remove the {} and whitespace surrounding the objects' entries, while
        # appending , and immediately removing the , from empty objects, so
        # empty objects become empty strings.
        _jeo_encoded_entries=("${_jeo_entries[@]/%*([$' \t\n\r'])?('}')*([$' \t\n\r'])/','}")
        _jeo_encoded_entries=("${_jeo_encoded_entries[@]/#*([$' \t\n\r'])?('{')*([$' \t\n\r'])?(',')/}")
        _jeo_encoded_entries="${_jeo_encoded_entries[*]}"
        if [[ ${#_jeo_encoded_entries} != 0 ]]; then
          json.buffer_output "${_jeo_encoded_entries:0: ${#_jeo_encoded_entries} - 1 }"
        fi
        return
    fi
  ;;
  esac fi

  if [[ ${#_jeo_keys[@]} == 0 ]]; then return; fi

  local _jeo_encoded_keys _jeo_encoded_values
  in=_jeo_keys join='' out=_jeo_encoded_keys json.encode_string  # can't fail
  in=_jeo_values join='' out=_jeo_encoded_values "json.encode_${type:?}" || return $?

  local _jeo_template
  # To avoid bash-level looping, we create a template that will consume all values
  if [[ ${_json_bash_feat_patsub:-} ]]; then
    printf -v _jeo_template '%s:%%s,' "${_jeo_encoded_keys[@]//["%\\"]/&&}"
  else
    _jeo_encoded_keys=("${_jeo_encoded_keys[@]//'%'/'%%'}")
    printf -v _jeo_template '%s:%%s,' "${_jeo_encoded_keys[@]//"\\"/"\\\\"}"
  fi
  _jeo_template=${_jeo_template/%,/}  # remove the trailing comma
  local -a _jeo_obj=()
  printf -v '_jeo_obj[1]' "${_jeo_template?}" "${_jeo_encoded_values[@]}"
  in='_jeo_obj' json.buffer_output
}

function json.encode_object_entries_from_json() {
  in=${in:?} out=${out?} json.encode_object_entries
}

function json.encode_object_entries_from_attrs() {
  local _jeoefa_keys=() _jeoefa_values=() split=${split:-} in=${in:?}
  # $split is the char used to split file chunks, so this shouldn't occur in the
  # input, and so can be used to escape when parsing. Otherwise use RecordSeparator.
  if [[ ! ${split?} ]]; then
    split=$'\x10' # Data Link Escape — probably not used, but escape regardless
    local -n _jeoefa_in=${in:?}
    local _jeoefa_chunks=("${_jeoefa_in[@]//$'\x10'/$'\x10\x10'}") in=_jeoefa_chunks
  fi
  in=${in:?} out=_jeoefa_keys,_jeoefa_values reserved=${split:?} \
    json.parse_attributes
  in=_jeoefa_keys,_jeoefa_values out=${out?} json.encode_object_entries
}

function json.encode_array_entries_from_json() {
  if [[ $# == 0 ]]; then local -n _jeaefj_in=${in:?}; else _jeaefj_in=("$@"); fi
  # in is an array containing complete JSON arrays
  if [[ ${type:?} != 'raw' ]]; then
    type="${type:?}_array" in=_jeaefj_in json.validate || \
      { echo "json.encode_array_entries_from_json(): provided entries are not all" \
        "valid JSON arrays with ${type@Q} values — ${_jeaefj_in[*]@Q}" >&2; return 1; }
  fi
  local IFS='' _jeaefj_entries
  # Remove the [] and whitespace surrounding the arrays' entries, while
  # appending , and immediately removing the , from empty arrays, so
  # empty arrays become empty strings.
  _jeaefj_entries=("${_jeaefj_in[@]/%*([$' \t\n\r'])?(']')*([$' \t\n\r'])/','}")
  _jeaefj_entries=("${_jeaefj_entries[@]/#*([$' \t\n\r'])?('[')*([$' \t\n\r'])?(',')/}")
  _jeaefj_entries="${_jeaefj_entries[*]}"
  if [[ ${#_jeaefj_entries} != 0 ]]; then
    json.buffer_output "${_jeaefj_entries:0: ${#_jeaefj_entries} - 1 }"
  fi
}

function json.get_entry_encode_fn() {
  local -n _jgeef_out=${out:?}
  case "${collection:?}_${format:?}_${type:?}" in
  (array_json_*) _jgeef_out=json.encode_array_entries_from_json               ;;
  (array_raw_*) _jgeef_out="json.encode_${type:?}"                            ;;
  (object_json_*) _jgeef_out=json.encode_object_entries_from_json             ;;
  (object_attrs_*) _jgeef_out=json.encode_object_entries_from_attrs           ;;
  (*)
    echo "json.get_entry_encode_fn(""): no entry encode function exists for" \
      "${collection@Q} ${format@Q} ${type@Q}" >&2; return 1                   ;;
  esac
}

function json.start_json_validator() {
  if [[ ${_json_validator_pids[$$]:-} != "" ]]; then return 0; fi

  local array validation_request
  # This is a PCRE regex that matches JSON. This is possible because we use
  # PCRE's recursive patterns to match JSON's nested constructs. And also
  # possessive repetition quantifiers to prevent expensive backtracking on match
  # failure. Backtracking is not required to parse JSON as it's not ambiguous.
  # If a rule fails to match, the input is known to be invalid, there's no
  # possibility of an alternate rule matching, so backtracking is pointless.
  #
  # See hack/syntax_patterns.bash for the readable source of this condensed
  # version.
  #
  # It doesn't match JSON directly, but rather it matches a simple validation
  # request protocol. json.validate costructs validation request messages that
  # match this regex when the JSON data is valid for the type specified in the
  # validation request.
  validation_request=$'(:?(?<bool>true|false)(?<true>true)(?<false>false)(?<null>null)(?<atom>true|false|null|(?<num>-?+(?:0|[1-9][0-9]*+)(?:\\.[0-9]*+)?+(?:[eE][+-]?+[0-9]++)?+)|(?<str>"(?:[\\x20-\\x21\\x23-\\x5B\\x5D-\\xFF]|\\\\(?:["\\\\/bfnrt]|u[A-Fa-f0-9]{4}))*+"))(?<ws>[\\x20\\x09\\x0A\\x0D]*+)(?<json>\\[(?:(?&ws)(?&json)(?:(?&ws),(?&ws)(?&json))*+)?+(?&ws)\\]|\\{(?:(?<entry>(?&ws)(?&str)(?&ws):(?&ws)(?&json))(?:(?&ws),(?&entry))*+)?+(?&ws)\\}|(?&atom))){0}^[\\w]++(?:(?=((?<pair>:(?&pair)?+\\x1E(?:j(?&ws)(?&json)(?&ws)|s(?&ws)(?&str)(?&ws)|n(?&ws)(?&num)(?&ws)|b(?&ws)(?&bool)(?&ws)|t(?&ws)(?&true)(?&ws)|f(?&ws)(?&false)(?&ws)|z(?&ws)(?&null)(?&ws)|a(?&ws)(?&atom)(?&ws)|Oj(?&ws)\\{(?:(?<entry_json>(?&ws)(?&str)(?&ws):(?&ws)(?&json))(?:(?&ws),(?&entry_json))*+)?+(?&ws)\\}(?&ws)|Os(?&ws)\\{(?:(?<entry_str>(?&ws)(?&str)(?&ws):(?&ws)(?&str))(?:(?&ws),(?&entry_str))*+)?+(?&ws)\\}(?&ws)|On(?&ws)\\{(?:(?<entry_num>(?&ws)(?&str)(?&ws):(?&ws)(?&num))(?:(?&ws),(?&entry_num))*+)?+(?&ws)\\}(?&ws)|Ob(?&ws)\\{(?:(?<entry_bool>(?&ws)(?&str)(?&ws):(?&ws)(?&bool))(?:(?&ws),(?&entry_bool))*+)?+(?&ws)\\}(?&ws)|Ot(?&ws)\\{(?:(?<entry_true>(?&ws)(?&str)(?&ws):(?&ws)(?&true))(?:(?&ws),(?&entry_true))*+)?+(?&ws)\\}(?&ws)|Of(?&ws)\\{(?:(?<entry_false>(?&ws)(?&str)(?&ws):(?&ws)(?&false))(?:(?&ws),(?&entry_false))*+)?+(?&ws)\\}(?&ws)|Oz(?&ws)\\{(?:(?<entry_null>(?&ws)(?&str)(?&ws):(?&ws)(?&null))(?:(?&ws),(?&entry_null))*+)?+(?&ws)\\}(?&ws)|Oa(?&ws)\\{(?:(?<entry_atom>(?&ws)(?&str)(?&ws):(?&ws)(?&atom))(?:(?&ws),(?&entry_atom))*+)?+(?&ws)\\}(?&ws)|Aj(?&ws)\\[(?:(?&ws)(?&json)(?:(?&ws),(?&ws)(?&json))*+)?+(?&ws)\\](?&ws)|As(?&ws)\\[(?:(?&ws)(?&str)(?:(?&ws),(?&ws)(?&str))*+)?+(?&ws)\\](?&ws)|An(?&ws)\\[(?:(?&ws)(?&num)(?:(?&ws),(?&ws)(?&num))*+)?+(?&ws)\\](?&ws)|Ab(?&ws)\\[(?:(?&ws)(?&bool)(?:(?&ws),(?&ws)(?&bool))*+)?+(?&ws)\\](?&ws)|At(?&ws)\\[(?:(?&ws)(?&true)(?:(?&ws),(?&ws)(?&true))*+)?+(?&ws)\\](?&ws)|Af(?&ws)\\[(?:(?&ws)(?&false)(?:(?&ws),(?&ws)(?&false))*+)?+(?&ws)\\](?&ws)|Az(?&ws)\\[(?:(?&ws)(?&null)(?:(?&ws),(?&ws)(?&null))*+)?+(?&ws)\\](?&ws)|Aa(?&ws)\\[(?:(?&ws)(?&atom)(?:(?&ws),(?&ws)(?&atom))*+)?+(?&ws)\\](?&ws)))$)):++)?+'

  # For some reason Bash seems to close open FDs starting from 63 when it starts
  # a coprocess. (Bash allocates FDs counting down from 63). This causes
  # arguments using process substitution to have their /dev/fd/xx files stop
  # existing. We work around this by duping all sequential existing FDs from 63
  # downwards to new FDs and restoring them after the coproc has started. (Bash
  # allocates FDs from 10 when dup'ing and these aren't closed).
  # https://savannah.gnu.org/support/index.php?110910
  local saved_fds=()
  # Arbitrary hard cap at 20 to avoid running into the FDs we're duping to,
  # which will be 10 upwards.
  for ((i=0; i < 20; ++i)); do
    { exec {saved_fds[i]}<&"$(( 63 - i ))"; } 2>/dev/null || break
  done

  { coproc json_validator ( grep --only-matching --line-buffered \
    -P -e "${validation_request//[$' \n']/}" )
  } 2>/dev/null  # hide interactive job control PID output
  _json_validator_pids[$$]=${json_validator_PID:?}
  # restore FDs bash closed...
  for ((i=0; i < ${#saved_fds[@]}; ++i)); do
    eval "exec $(( 63 - i ))<&${saved_fds[i]:?} {saved_fds[i]}<&-"
  done
  # Bash only allows 1 coproc per bash process, so by creating a coproc we would
  # normally prevent another things in this process from creating one. We can
  # avoid this restriction by duplicating the coproc's pipe FDs to new ones, and
  # closing the originals. (See https://stackoverflow.com/a/47213971/693728 and
  # https://lists.gnu.org/archive/html/help-bash/2021-03/msg00207.html .) To
  # prevent forked shells using this process's coprocess, we store the new FDs
  # in an array indexed by PID, so we only use FDs owned by our process.
  # shellcheck disable=SC1083,SC2102
  exec {_json_validator_out_fds[$$]}<&"${json_validator[0]}"- \
       {_json_validator_in_fds[$$]}>&"${json_validator[1]}"-
}

function json.check_json_validator_running() {
  if [[ ${_json_validator_pids[$$]:-} != "" ]] \
    && ! kill -0 "${_json_validator_pids[$$]}" 2>/dev/null; then
    unset "_json_validator_pids[$$]"
    return 1 # expected to be alive, but dead
  fi
  return 0 # alive or not expected to be alive
}

function json.validate() {
  if [[ ${_json_validator_pids[$$]:-} == "" ]];
  then json.start_json_validator; fi

  local _jv_type=${_json_bash_validation_types[${type:-json}]:?"json.validate: unsupported \$type: ${type@Q}"}

  let "_json_validate_id=${_json_validate_id:-0}+1"; local id=$_json_validate_id
  local count_markers IFS # delimit JSON with Record Separator
  # Ideally we'd use null-terminated "lines" with grep's --null-data, but I can't
  # get consistent reads after writes that way. (The problem appears to be with
  # grep, as if I substitute grep for a hack/alternate_validator.py (which
  # flushes consistently after null bytes) it works fine.) Line buffering with
  # grep works consistently too, so we do that.
  # The grep man page does warn that: "[the -P] option is experimental when
  # combined with the -z (--null-data) option".
  if [[ $# == 0 ]]; then
    local -n _validate_json_in="${in:?$_json_in_err}"
    if [[ ${#_validate_json_in[@]} == 0 ]]; then return 0; fi
    printf -v count_markers ':%.0s' "${!_validate_json_in[@]}"
    {
      printf '%d%s' "${id:?}" "${count_markers:?}"
      # \n is the end of a validation request, so we need to remove \n in JSON
      # input. We map them to \r, which don't JSON affect validity.
      printf "\x1E${_jv_type:?}%s" "${_validate_json_in[@]//$'\n'/$'\r'}"
      printf '\n'
    } >&"${_json_validator_in_fds[$$]:?}"
  else
    IFS=''; count_markers=${*/*/:}
    {
      printf '%d%s' "${id:?}" "${count_markers?}"
      printf "\x1E${_jv_type:?}%s" "${@//$'\n'/$'\r'}"
      printf '\n'
    } >&"${_json_validator_in_fds[$$]:?}"
  fi

  IFS=''
  if ! read -ru "${_json_validator_out_fds[$$]:?}" -t 4 response; then
    if ! json.check_json_validator_running; then
      echo "json.bash: json validator coprocess unexpectedly died" >&2
      return 2
    fi
    echo "json.validate: failed to read json validator response: $? ${response@Q}" >&2
    return 2
  fi
  if [[ $response != "${id:?}${count_markers?}" ]]; then
    if [[ $response != "${id:?}"* ]]; then
      echo "json.validate: mismatched validator response ID: ${id@A}," \
        "${response@A}" >&2; return 2
    fi
    return 1
  fi
}

# Encode a file as a single JSON value, or JSON array of values.
#
# This function will stream the file contents when encoding string and raw
# types, and when encoding arrays of any type. (However, it buffers individual
# array values, so the values themselves can't be larger than memory, but the
# overall array can be.)
function json.encode_from_file() {
  # TODO: remove backwards compat
  if [[ ${array:-} == true ]]; then collection=array; fi
  local entries=${entries:-}
  case "${type:?}_${collection:-}_${entries/true/entries}" in
  # There's not much point in implementing json.stream_encode_json() because
  # grep (which evaluates the validation regex) buffers the entire input in
  # memory while matching, despite not needing to backtrack or output the match.
  (@(string|number|bool|true|false|null|auto|raw|json)_array_entries)
    format=${array_format:?} json.stream_encode_array_entries || return $?                             ;;
  (@(string|number|bool|true|false|null|auto|raw|json)_object_entries)
    format=${object_format:?} json.stream_encode_object_entries || return $?                            ;;
  (@(string|number|bool|true|false|null|auto|raw|json)_array_*)
    json.buffer_output '['
    format=${array_format:?} json.stream_encode_array_entries || return $?
    json.buffer_output ']'                                                    ;;
  (@(string|number|bool|true|false|null|auto|raw|json)_object_*)
    json.buffer_output '{'
    format=${object_format:?} json.stream_encode_object_entries || return $?
    json.buffer_output '}'                                                    ;;
  (@(string|raw)_*)
    "json.stream_encode_${type:?}" || return $?                               ;;
  (@(number|bool|true|false|null|auto|json)_*)
    json.encode_value_from_file || return $?                                  ;;
  (*)
    echo "json.encode_from_file(): unsupported type, collection combination:" \
      "${type@Q}, ${collection@Q}" >&2; return 1                              ;;
  esac
}

# Encode the contents of a file as a JSON string, without buffering the whole
# value.
function json.stream_encode_string() {
  local _jses_chunk _jses_encoded IFS='' eof='' \
    json_chunk_size=${json_chunk_size:-8191} prefix=${prefix:-}

  read -r -d '' -N "${json_chunk_size:?}" _jses_chunk || eof=true
  if [[ ${#_jses_chunk} == 0 ]]; then return 10; fi
  out=_jses_encoded json.encode_string "${_jses_chunk?}"
  json.buffer_output ${prefix?} '"' "${_jses_encoded[0]:1:-1}" # strip the quotes
  "${out_cb:-:}"

  while [[ ! $eof ]]; do
    _jses_encoded=()
    read -r -d '' -N "${json_chunk_size:?}" _jses_chunk || eof=true
    out=_jses_encoded json.encode_string "${_jses_chunk?}"
    json.buffer_output "${_jses_encoded[0]:1:-1}" # strip the quotes
    "${out_cb:-:}"
  done
  json.buffer_output '"'
}

# Encode the contents of a file as a raw JSON value, without buffering the whole
# value.
#
# This behaves the same way as json.encode_raw — any JSON value can be emitted,
# but the caller is responsible for ensuring the input is actually valid JSON,
# as function does no validation of the content, other than failing if the whole
# file is empty.
function json.stream_encode_raw() {
  local _jser_chunk eof= json_chunk_size=${json_chunk_size:-8191} \
    IFS prefix=${prefix:-}
  read -r -d '' -N "${json_chunk_size:?}" _jser_chunk || eof=true
  if [[ ! $_jser_chunk ]]; then return 10; fi
  IFS=''; json.buffer_output ${prefix?} "${_jser_chunk?}"
  "${out_cb:-:}"
  while [[ ! $eof ]]; do
    read -r -d '' -N "${json_chunk_size:?}" _jser_chunk || eof=true
    json.buffer_output "${_jser_chunk?}"
    "${out_cb:-:}"
  done
}

# Read a file (up to the first null byte, if any) and encode it as $type.
#
# This function buffers the entire value in memory.
function json.encode_value_from_file() {
  local _jevff_chunk prefix=${prefix:-} IFS
  # close stdin after reading 1 chunk — we ignore anything after the first null
  # byte. Note: read without -N trims trailing newlines, which we want.
  read -r -d '' _jevff_chunk || true
  if [[ ! ${_jevff_chunk?} ]]; then return 10; fi
  if [[ ${prefix?} ]]; then IFS=''; json.buffer_output ${prefix?}; fi
  "json.encode_${type:?}" "${_jevff_chunk?}"
}
function json._jevff_close_stdin() { exec 0<&-; }

# Stream-encode chunks from a file as JSON array elements.
#
# This function splits the input file (stdin) into chunks using the single
# character delimiter defined by $split. While encoding, it buffers individual
# chunks in memory, but not the file as a whole (so long as the caller flushes
# their $out buffer via the $out_cb callback.)
function json.stream_encode_array_entries() {
  local _jsea_raw_chunks=() _jsea_encoded_chunks=() _jsea_caller_out=${out:-} \
    _jsea_last_emit=4000000000 _jsea_separator=() _jsea_error='' _jseae_encode_entries_fn
  out=_jseae_encode_entries_fn collection=array format=${format:?} type=${type:?} \
    json.get_entry_encode_fn || return 1
  readarray -t -d "${split?}" -C json.__jsea_on_chunks_available \
    -c "${json_buffered_chunk_count:-1024}" _jsea_raw_chunks

  if [[ ${_jsea_last_emit?} == 4000000000 && ${#_jsea_raw_chunks[@]} == 0 ]];
  then return 10; fi
  if [[ $_jsea_error ]]; then return 1; fi

  unset "_jsea_raw_chunks[$_jsea_last_emit]"
  if [[ ${#_jsea_raw_chunks[@]} != 0 ]]; then
    local _jsea_indexes=("${!_jsea_raw_chunks[@]}")
    json.__jsea_on_chunks_available \
      "${_jsea_indexes[-1]}" "${_jsea_raw_chunks[-1]}"
    if [[ $_jsea_error ]]; then return 1; fi
  fi
}

function json.__jsea_on_chunks_available() {
  # To emit new elements as fast as possible, we add the just-read element in $2
  # at index $1 before emitting. Bash does this insert itself after we return (
  # which delays that element until the next set of chunks is ready). This means
  # that we must also remove the first array element to avoid emitting it twice.
  unset "_jsea_raw_chunks[$_jsea_last_emit]"
  _jsea_raw_chunks["${1:?}"]=$2 _jsea_last_emit=$1
  out=$_jsea_caller_out in=_jsea_separator json.buffer_output
  if ! out=$_jsea_caller_out in=_jsea_raw_chunks join=, \
         "${_jseae_encode_entries_fn:?}"; then
    # readarray ignores our exit status, but we can force it to stop by closing
    # stdin, which it's reading.
    exec 0<&-  # close stdin
    _jsea_error=true
    return
  fi
  _jsea_raw_chunks=() _jsea_separator=(',') # separate chunks with , after the first write
  "${out_cb:-:}" # call the out_cb, if provided
}

function json.stream_encode_object_entries() {
  local IFS=''; local _jseoe_raw_chunks=() _jseoe_encoded_chunks=() \
    _jseoe_caller_out=${out:-} _jseoe_last_emit=4000000000 _jseoe_buff=(${prefix:-}) \
    _jseoe_error='' _jseoe_encode_entries_fn
  out=_jseoe_encode_entries_fn collection=object format=${format:?} \
       type=${type:?} json.get_entry_encode_fn || return 1

  readarray -t -d "${split?}" -C json._jseoe_encode_chunks \
    -c "${json_buffered_chunk_count:-1024}" _jseoe_raw_chunks

  if [[ ${_jseoe_last_emit?} == 4000000000 && ${#_jseoe_raw_chunks[@]} == 0 ]]
  then return 10; fi
  if [[ $_jseoe_error ]]; then return 1; fi

  unset "_jseoe_raw_chunks[$_jseoe_last_emit]"
  if [[ ${#_jseoe_raw_chunks[@]} != 0 ]]; then
    local _jseoe_indexes=("${!_jseoe_raw_chunks[@]}")
    json._jseoe_encode_chunks \
      "${_jseoe_indexes[-1]}" "${_jseoe_raw_chunks[-1]}"
    if [[ $_jseoe_error ]]; then return 1; fi
  fi
}

function json._jseoe_encode_chunks() {
  local _jseoe_encoded=()
  unset "_jseoe_raw_chunks[$_jseoe_last_emit]"
  _jseoe_raw_chunks["${1:?}"]=$2 _jseoe_last_emit=$1
  if ! out=_jseoe_buff in=_jseoe_raw_chunks "${_jseoe_encode_entries_fn:?}"; then
    # readarray ignores our exit status, but we can force it to stop by closing
    # stdin, which it's reading.
    exec 0<&-  # close stdin
    _jseoe_error=true
    return
  fi
  _jseoe_raw_chunks=()
  if [[ ${#_jseoe_buff[@]} != 0 && ${_jseoe_buff[-1]:-} != ',' ]]; then
    out=${_jseoe_caller_out?} in=_jseoe_buff json.buffer_output
    "${out_cb:-:}" # call the out_cb, if provided
    _jseoe_buff=(',') # separate chunks with , after the first write
  fi
}

# Signal failure to output JSON data.
#
# This signals the error in two ways, for machine and human audiences. For
# machines, we poison the $out stream by writing a Cancel (␘ / CAN) control
# character (0x18, ^X) This and other control characters are not allowed to
# occur in JSON documents, so it has the effect of rendering the output invalid
# when interpreted as JSON. The character itself indicates that the data
# preceding it is invalid. In our case, the output is truncated, either
# entirely, or partially.
#
# This in-band error signalling is more robust than relying only on
# process/command exit status, as they're easy to ignore, and often hard to
# check (e.g. when running json.bash in a subshell during process substitution
# or as part of a pipeline).
#
# Secondly, we print a description of the error to stderr as normal.
#
# See https://en.wikipedia.org/wiki/Cancel_character
function json.signal_error() {
  if [[ $# != 0 ]]; then echo "${@}" >&2; fi
  json.buffer_output $'\x18'  # Cancel control character
  if [[ ${out?} == '' ]]; then
    # When out is a terminal we write a visual Cancel symbol as well as the
    # actual Cancel, because TTYs don't normally display control chars. We still
    # emit a newline on error to separate our output from adjacent output.
    if [[ -t 1 ]]; then json.buffer_output $'␘\n';
    else json.buffer_output $'\n'; fi
  fi
}

# Internal error handler for json.json().
function json._error() {
  # We always want to write to $_caller_out because $out may be a temp buffer
  # which is discarded on error.
  out=${_caller_out?} json.signal_error "${@}"
}

function json._parse_argument2() {
  local -n _jpa_out=${out:?"\$out must name an Associative Array to hold parsed attributes"}
  # Parsing an argument results in a set of name=value attributes. The argument
  # syntax (other than the [name=value,...] section) is all shorthand for
  # attributes which could be manually specified using attributes.
  # The key pattern is intended to always match, even invalid/empty inputs.
  [[ ${1?} =~ $_json_bash_005_p1_key ]] \
    || { echo "json.parse_argument(): failed to parse argument: ${1@Q}" >&2; return 1; }

  case "${BASH_REMATCH[1]}" in  # splat
  (...) _jpa_out['splat']=true;;
  (?*)  echo "json.parse_argument(""): splat operator must be '...'" >&2; return 1;;
  esac

  local key_prefix=${BASH_REMATCH[5]:0:1} key_value=${BASH_REMATCH[5]:1}
  key_value=${key_value//@@/@}
  key_value=${key_value//::/:}
  key_value=${key_value//==/=}

  case "${BASH_REMATCH[4]}" in  # key flags
  (*'+'*)  _jpa_out['key_flag_strict']='+' ;;&
  (*'~'*)  _jpa_out['key_flag_no']='~'     ;;&
  (*'?'*)  _jpa_out['key_flag_empty']='?'  ;;&
  (*'??'*) _jpa_out['key_flag_empty']='??' ;;&
  esac

  case "${key_prefix?}${key_value:0:2}" in
  ('@/'*|'@./') _jpa_out['key']=${key_value?} _jpa_out['@key']='file' ;;
  ('@'*)        _jpa_out['key']=${key_value?} _jpa_out['@key']='var'  ;;
  ('='*)        _jpa_out['key']=${key_value?} _jpa_out['@key']='str'  ;;
  (?*)          _jpa_out['key']="${key_prefix?}${key_value?}"
                _jpa_out['@key']='str'                                ;;
  esac

  # [3] is a : that occurred at the start of the arg
  p2="${BASH_REMATCH[3]}${1: ${#BASH_REMATCH[0]} }"  # type or value section following the key
  if [[ $p2 =~ $_json_bash_005_p2_meta ]]; then

    case "${BASH_REMATCH[2]}" in  # collection marker
    ('')                                                       ;;
    ('['?']'|'['?:*']') _jpa_out['split']=${BASH_REMATCH[3]:?} ;;&
    ('['*']') _jpa_out['collection']='array'                   ;;&
    ('['*':raw]') _jpa_out['array_format']=raw                 ;;
    ('['*':json]') _jpa_out['array_format']=json               ;;

    ('{'?'}'|'{'?:*'}') _jpa_out['split']=${BASH_REMATCH[3]:?} ;;&
    ('{'*'}') _jpa_out['collection']='object'                  ;;&
    ('{'*':attr'?('s')'}') _jpa_out['object_format']=attrs     ;;
    ('{'*':json}') _jpa_out['object_format']=json              ;;
    (['{[']*:?*[']}'])
      echo "json.parse_argument: unsupported collection :format — ${BASH_REMATCH[4]@Q}" >&2;
      return 1                                                 ;;
    ('{'*'}'|'['*']')                                          ;;
    (*)
      echo "json.parse_argument: collection marker is not structured correctly — ${BASH_REMATCH[2]@Q}" >&2;
      return 1                                                 ;;
    esac

    local _jpa_attributes=${BASH_REMATCH[5]:1:-1}
    p3=${p2:${#BASH_REMATCH[0]}}

    # Handle the type last because the regex match overwrites the matched groups
    local _jpa_unverified_type=${BASH_REMATCH[1]}
    if [[ ${_jpa_unverified_type?} =~ $_json_bash_type_name_pattern ]]; then
      _jpa_out['type']=${_jpa_unverified_type?}
    elif [[ ${_jpa_unverified_type?} ]]; then
      echo "json.parse_argument(): type name must be one of auto, bool, false," \
        "json, null, number, raw, string or true, but was ${_jpa_unverified_type@Q}" >&2
      return 1
    fi
  elif [[ $p2 != :* && ${_jpa_out['key']:-} =~ [+~?]+$ ]]; then
    # move flag characters from the end of the key to the value if no meta section
    _jpa_out['key']=${_jpa_out['key']:0: - ${#BASH_REMATCH[0]} }
    p3="${BASH_REMATCH[0]}${p2?}"
  else
    p3=$p2  # no type section, so value is everything after the key
  fi

  [[ $p3 =~ $_json_bash_005_p3_value ]]  # Always matches, can be 0-length
  case "${BASH_REMATCH[1]}" in
  (*'+'*)  _jpa_out['val_flag_strict']='+' ;;&
  (*'~'*)  _jpa_out['val_flag_no']='~'     ;;&
  (*'?'*)  _jpa_out['val_flag_empty']='?'  ;;&
  (*'??'*) _jpa_out['val_flag_empty']='??' ;;&
  esac

  value=${p3: ${#BASH_REMATCH[0]} }
  case "${BASH_REMATCH[2]}${value:0:2}" in
  ('@/'*|'@./') _jpa_out['val']=${value?} _jpa_out['@val']='file' ;;
  ('@'*)        _jpa_out['val']=${value?} _jpa_out['@val']='var'  ;;
  ('='*)        _jpa_out['val']=${value?} _jpa_out['@val']='str'  ;;
  (?*)
    echo "json.parse_argument(): The argument is not correctly structured:" \
      "The value following the : should look like :string or :number[] or :{}" \
      "or :[,]/empty=null/ or :type[]// . Whereas the value after that must" \
      "come after a = or @ e.g. foo:number=42 @foo:number? foo:[,]=a,b,c" >&2
    return 1
  ;;
  esac

  if [[ ${_jpa_attributes:-} ]]; then
    json.parse_attributes "${_jpa_attributes:?}"
  fi
}

# Parse the attribute syntax used in argument /a=b,c=d/ attributes.
function json.parse_attributes() {
  local _jpa_attrskv=() _jpa_attrsk=() _jpa_attrsv=() _r=${reserved:-/} IFS=','

  if [[ $# != 0 ]]; then local _jpa_in=("$@");
  else local -n _jpa_in=${in:?"json.parse_attributes: \$in must be set when no arguments are provided"}; fi

  if [[ ${#_r} != 1 || $_r == [=,] ]]; then
    echo "json.parse_attributes: \$reserved must be a single char other" \
      "than '=' ',' or — ${_r@Q}" >&2; return 1
  fi

  if [[ ${_jpa_in[*]?} =~ ("${_r:?}${_r:?}"|',,'|'==') ]]; then
    _jpa_attrskv=("${_jpa_in[@]//,,/"\\${_r:?}1"}")  # Re-escape escapes so we can use , and = unambiguously.
    _jpa_attrskv=("${_jpa_attrskv[@]//==/"\\${_r:?}2"}")  # We make use of / in this temporary escape sequence, as / must be escaped as //
    # To remove empty inputs, we normalise commas by adding one at the start and
    # compressing repeated commas into one.
    _jpa_attrskv=",${_jpa_attrskv[*]},"                  # join on ','
    _jpa_attrskv=(${_jpa_attrskv//+(',')/,})             # split on (1 or more) commas
    _jpa_attrskv=("${_jpa_attrskv[@]//"\\${_r:?}1"/,}")  # Restore ,, escapes as ,
    _jpa_attrsk=("${_jpa_attrskv[@]/%=*/}")              # Remove =value suffix to get key
    _jpa_attrsv=("${_jpa_attrskv[@]/#*([^=])?(=)/}")     # Remove key= prefix to get value

    _jpa_attrsk=("${_jpa_attrsk[@]//"\\${_r:?}2"/'='}")   # Restore == escapes as =
    _jpa_attrsv=("${_jpa_attrsv[@]//"\\${_r:?}2"/'=='}")  # Restore == escapes as == (values don't need to escape =, so == is ==).
    _jpa_attrsk=("${_jpa_attrsk[@]//"${_r:?}${_r:?}"/"${_r:?}"}")    # Apply // escapes as /
    _jpa_attrsv=("${_jpa_attrsv[@]//"${_r:?}${_r:?}"/"${_r:?}"}")    # Apply // escapes as /
  else
    _jpa_attrskv=",${_jpa_in[*]},"                    # join on ','
    _jpa_attrskv=(${_jpa_attrskv//+(',')/,})          # split on (1 or more) commas
    _jpa_attrsk=("${_jpa_attrskv[@]/%=*/}")           # Remove =value suffix to get key
    _jpa_attrsv=("${_jpa_attrskv[@]/#*([^=])?(=)/}")  # Remove key= prefix to get value
  fi

  # Handle the split attributes from either of the previous 2 cases, either
  # output separate key and value arrays, or a merged associative array.
  # Note that the first index is always the empty string due to , normalisation.
  case "${out:?"\$out must name an Associative Array to hold parsed attributes"}" in
  (*?,?*)
    local -n _jpa2_outk=${out%,*} _jpa2_outv=${out#*,}
    _jpa2_outk+=("${_jpa_attrsk[@]:1}") _jpa2_outv+=("${_jpa_attrsv[@]:1}") ;;
  (*)
    local -n _jpa2_out=${out:?}
    for ((i=1; i < ${#_jpa_attrsk[@]}; ++i )); do
      _jpa2_out["${_jpa_attrsk["$i"]:-__empty__}"]=${_jpa_attrsv["$i"]}
    done ;;
  esac
}

# Parse a json argument expression into attributes in an associative array.
#
# The argument is not evaluated or checked for semantic validity. e.g. a :bool
# type with a number value parses without error (with the assumption that the
# caller notices the issue when using the parsed argument).
#
# Attributes are not set for syntactic elements not present in the argument. For
# example, no default type is set if the argument has no type present. The
# caller can initialise the output array with defaults, or apply them later.
function json.parse_argument() {
  local -n _jpa_out=${out:?'$out must name an Associative Array to hold parsed attributes'}

  json._parse_argument2 "${1?}" || return $?

  # backwards compatability with array=true/false
  if [[ ${_jpa_out['collection']:-} == 'array' && ${_jpa_out['array']:-} != false ]]; then
    _jpa_out['array']='true'
  fi
}

function json.define_defaults() {
  # We pre-define sets of defaults for two reasons. Firstly to avoid the
  # complications of detecting if an associative array var is set. Secondly, to
  # avoid needing to validate defaults on each json() call.
  local name=${1:?"json.define_defaults(): first argument must be the name for the defaults"} \
    attrs_string=${2:-}
  local var_name="_json_defaults_${name:?}"

  _json_defaults["${name:?}"]="${var_name:?}"
  declare -g -A "${var_name:?}=()"
  local -n defaults="${var_name:?}"
  # Can't fail to parse because we escape ] as ]]
  out="defaults" __jpa_array_default='false' json.parse_argument \
      ":/${attrs_string//'/'/'//'}/"

  if [[ ! ${defaults[type]:-string} =~ $_json_bash_type_name_pattern ]]; then
    local error="json.define_defaults(): defaults contain invalid 'type': ${defaults[type]@Q}"
    unset "_json_defaults[${name:?}]" "${var_name:?}"
    out='' json.signal_error "${error:?}"; return 2
  fi
}
json.define_defaults __empty__ ''

# Encode arguments as JSON objects or arrays and print to stdout.
#
# Each argument is an entry in the JSON object or array created by the call.
# See the --help message for argument syntax.
function json() {
  # vars referenced by arguments cannot start with _, so we prefix our own vars
  # with _ to prevent args referencing locals.
  local IFS _collection _dashdash_seen _encode_fn _array_format _object_format \
        _key _key_array _type _value _value_array _match _splat _split

  local _caller_out=${out:-}
  if [[ ${json_stream:-} != true ]]
  then local out=_json_buff _json_buff=(); fi

  if [[ "${json_defaults:-}" && ! ${_json_defaults["${json_defaults}"]:-} ]]; then
    json._error "json(): json.define_defaults has not been called for" \
      "json_defaults value: ${json_defaults@Q}"; return 2
  fi
  local -n _defaults="${_json_defaults[${json_defaults:-__empty__}]:?}"

  local _json_return=${json_return:-object}
  [[ $_json_return == object || $_json_return == array ]] || {
    json._error "json(): $json_return must be 'object' or 'array' or empty:" \
      "${_json_return@Q}"; return 2
  }

  if [[ $_json_return == object ]]; then json.buffer_output "{"
  else json.buffer_output "["; fi

  local _first=true
  for arg in "$@"; do
    if [[ $arg == '--' && ${_dashdash_seen:-} != true ]]
    then _dashdash_seen=true; continue; fi
    local -A _attrs=()
    if ! out=_attrs json.parse_argument "$arg"; then
      json._error "json(): argument is not structured correctly: ${arg@Q}"; return 2;
    fi
    unset -n {_key,_value}{,_file} _value_array;
    unset {_key,_value}{,_file} _value_array;

    _type=${_attrs[type]:-${_defaults[type]:-string}}
    _splat=${_attrs['splat']:-${_defaults['splat']:-}}
    _array_format=${_attrs['array_format']:-${_defaults['array_format']:-${_array_format:-raw}}}
    if [[ $_splat == true ]] # splat always implies the arg is a collection
    then _collection=${_json_return?}
    else _splat='' _collection=${_attrs['collection']:-${_defaults['collection']:-false}}; fi
    # If no value is set, provide a default
    if [[ ! ${_attrs[val]+isset} ]]; then # arg has no value
      case "${_type}_${_attrs[@key]:-}" in
      (true*|false*|null*)
        _attrs[val]=$_type  # value is the type name
        _attrs[@val]=str
        if [[ $_type != null ]]; then _type=bool; fi ;;
      (*_var)
        _attrs[val]=${_attrs[key]}  # use key ref for value ref
        _attrs[@val]=var            # use key ref name for key
        _attrs[@key]=str ;;
      (*_file)
        _attrs[val]=${_attrs[key]}        # use key ref for value ref
        _attrs[@val]=${_attrs[@key]}      # use key ref name for key
        _attrs[key]=${_attrs[key]/#*\//}  # use the file's basename as the key
        _attrs[@key]=str ;;
      (*) # use inline key value as inline value
        _attrs[val]=${_attrs[key]:-}
        _attrs[@val]=str ;;
      esac
    fi

    case "${_json_return}_${_attrs[@key]:-}" in
    (object_var)
      local -n _key="${_attrs[key]}"
      if [[ ${_key+isset} ]]; then
        if [[ ${_key@a} == *[aA]* ]]; then local -n _key_array=_key; fi
      else # distinguish arrays without [0] from unset vars, see _value below
        : "${_key:=}"
        if [[ ${_key@a} == *[aA]* ]]; then
          unset '_key[0]'
          local -n _key_array=_key
        else
          unset _key
          # Instead of containing the content, a var can contain a filename which
          # contains the value(s).
          if [[ ${_attrs[key]} != *']' ]]  # don't create _FILE refs for array vars
          then local -n _key_file="${_attrs[key]}_FILE"; fi

          if [[ ! ${_key_file:-} =~ ^\.?/ ]]; then
            unset -n _key_file
            json._error "json(): argument references unbound variable:" \
              "\$${_attrs[key]} from ${arg@Q}"; return 3
          fi
        fi
      fi
    ;;
    (object_file) _key_file=${_attrs[key]} ;;
    (*) _key=${_attrs[key]:-} ;;
    esac

    case "${_attrs[@val]}" in
    (var)
      local -n _value="${_attrs[val]}"
      _object_format=json
      if [[ ${_value+isset} ]]; then
        if [[ ${_value@a} == *[aA]* ]]; then local -n _value_array=_value; fi
      else
        # arrays without [0] set are considered unset by the + operator
        : "${_value:=}"  # set [0] so we can safely check flags of potentially-unset var
        if [[ ${_value@a} == *[aA]* ]]; then
          unset '_value[0]'  # _value was array without [0]
          local -n _value_array=_value
        else
          unset _value # _value was not previously set
          if [[ ${_attrs[val]} != *']' ]]  # don't create _FILE refs for array vars
          then local -n _value_file="${_attrs[val]}_FILE"; fi

          if [[ ! ${_value_file:-} =~ ^\.?/ ]]; then
            unset -n _value_file
            json._error "json(): argument references unbound variable:" \
              "\$${_attrs[val]} from ${arg@Q}"; return 3
          fi
        fi
      fi ;;
    (file) _value_file=${_attrs[val]} _object_format=json ;;
    (str) _value=${_attrs[val]} _object_format=attrs ;;
    esac

    if [[ ${_first:?} == true ]]; then _first=false
    else json.buffer_output ","; fi

    # Handle the common object string value case a little more efficiently
    if [[ $_type == string && $_json_return == object && $_collection == false \
          && ! ( ${_key_file:-} || ${_value_file:-} ) ]]; then
      join=':' json.encode_string "$_key" "$_value" || { json._error; return 1; }
      continue
    fi

    if [[ $_json_return == object && $_splat != true ]]; then
      if [[ ${_key_file:-} ]]
      then json.stream_encode_string < "${_key_file:?}" || {
        json._error "json(): failed to read file referenced by argument:" \
          "${_key_file@Q} from ${arg@Q}"; return 4; }
      else json.encode_string "$_key" || { json._error; return 1; } ; fi
      json.buffer_output ":"
    fi
    local _status=0
    _encode_fn="json.encode_${_type:?}"
    if [[ ${_value_file:-} ]]; then
      if [[ ${_attrs[split]+isset} ]]; then _split=${_attrs[split]}
      elif [[ ${_collection} == @(array|object) ]]; then _split=$'\n';
      else _split=''; fi
      _object_format=${_attrs['object_format']:-${_defaults['object_format']:-${_object_format:?}}}

      if ! { { collection=${_collection:?} object_format=${_object_format:?} \
              array_format=${_array_format:?} type=${_type:?} \
              entries=${_splat?} split=${_split?} json.encode_from_file \
              || _status=$?; } < "${_value_file:?}"; }; then
        json._error "json(): failed to read file referenced by argument:" \
          "${_value_file@Q} from ${arg@Q}"; return 4
      fi
      if [[ $_status != 0 ]]; then
        json._error "json(): failed to encode file contents as ${_type:?}:" \
          "${_value_file@Q} from ${arg@Q}"; return 1
      fi
    else
      if [[ ${_collection:?} == @(array|object) ]]; then
        if [[ ! -R _value_array ]]; then # if the value isn't an array, split it
          if [[ ${_attrs[split]+isset} ]]; then _split=${_attrs[split]}
          else _split=''; fi
          IFS=${_split}; _value_array=(${_value})  # intentional splitting
        fi

        if [[ ${_collection} == array ]]; then
          if ! out=_encode_fn collection=array format=${_array_format:?} \
                type=${_type:?} json.get_entry_encode_fn; then
            json._error "json(): array entry format does not exist — ${_array_format@Q}"
            return 2
          fi
          if [[ $_splat == true ]]; then
            join=, in=_value_array type=${_type:?} "$_encode_fn" || _status=$?;
          else
            json.buffer_output '['
            join=, in=_value_array type=${_type:?} "$_encode_fn" || _status=$?;
            json.buffer_output "]"
          fi
        else
          _object_format=${_attrs['object_format']:-${_defaults['object_format']:-${_object_format:?}}}
          if [[ ${_value_array@a} == *A* ]]; then  # assoc arrays are not decoded
            _encode_fn=json.encode_object_entries
          else
            if ! out=_encode_fn collection=object format=${_object_format:?} \
                 type=${_type:?} json.get_entry_encode_fn; then
              json._error "json(): object entry format does not exist — ${_object_format@Q}"
              return 2
            fi
          fi
          if [[ $_splat == true ]]; then
            # A key and value array can be used to define entries
            if [[ -R _key_array && -R _value_array && ${_key_array@a} == *a* \
                  && ${_value_array@a} == *a* ]]; then
              join='' in=_key_array,_value_array type=${_type} json.encode_object_entries
            else
              join='' in=_value_array type=${_type} "${_encode_fn:?}" || _status=$?;
            fi
          else
            json.buffer_output '{'
            join='' in=_value_array type=${_type} "${_encode_fn:?}" || _status=$?;
            json.buffer_output "}"
          fi
        fi
      else "$_encode_fn" "${_value}" || _status=$?; fi
      if [[ $_status != 0 ]]; then
        json._error "json(): failed to encode value as ${_type:?}:" \
          "${_value[*]@Q} from ${arg@Q}"; return 1
      fi
    fi
  done

  if [[ $_json_return == object ]]; then json.buffer_output '}'
  else json.buffer_output ']'; fi
  if [[ ${_caller_out?} == '' ]]; then json.buffer_output $'\n'; fi
  if [[ ${json_stream:-} != true ]]; then
    # By default we emit only complete JSON values, not pieces
    local IFS=''; out=${_caller_out?} json.buffer_output "${_json_buff[*]}"
  fi
}

function json.object() {
  json_return=object json "$@"
}

function json.array() {
  json_return=array json "$@"
}

if ! out='' json.is_compatible; then
  if [[ ${BASH_SOURCE[0]} == "$0" ]]; then exit 2
  else return 2; fi
fi

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then # we're being executed directly
  case ${1:-} in
    -h|--help)
    prog=$(basename "$0"); prog_obj=${prog%?array} prog_array=${prog_obj}-array
    cat <<-EOT
Generate JSON.

Usage:
  ${prog:?} [options] [--] [key][:type][=value]...

Examples:
  $ ${prog_obj:?} msg="Hello World" size:number=42 enable:true data:false
  {"msg":"Hello World","size":42,"enable":true,"data":false}

  # Reference variables with @name
  $ id=42 date=\$(date --iso) ${prog_obj:?} @id created@=date modified@=date
  {"id":"42","created":"2023-06-23","modified":"2023-06-23"}

  # Reference files with absolute paths, or relative paths starting ./
  $ printf hunter2 > /tmp/password; jb @/tmp/password
  {"password":"hunter2"}

  # Nest jb calls using shell process substitution & file references
  $ jb type=club members:json[]@=<(jb name=Bob; jb name=Alice)
  {"type":"club","members":[{"name":"Bob"},{"name":"Alice"}]}

  $ jb counts:number[]@=<(seq 3) names[:]=Bob:Alice
  {"counts":[1,2,3],"names":["Bob","Alice"]}

  # Create arrays with ${prog_array}
  $ ${prog_array:?} '*.md' :json@=<(${prog_obj:?} max_width:number=80)
  ["*.md",{"max_width":80}]

  # Use special OS files to read stdin
  $ printf 'foo\nbar\n' | jb @/dev/stdin[]
  {"stdin":["foo","bar"]}

  # ...or other fun things
  $ jb args[split=]@=/proc/self/cmdline
  {"args":["bash","/workspaces/json.bash/bin/jb","args[split=]@=/proc/self/cmdline"]}

  # In a bash script/shell, source json.bash and use the json function
  $ source json.bash
  $ out=compilerOptions json removeComments:true
  $ files=(a.ts b.ts)
  $ json @compilerOptions:raw @files:string[]
  {"compilerOptions":{"removeComments":true},"files":["a.ts","b.ts"]}

Options:
  -h, --help    Show this message
  --version     Show version info

More:
  https://github.com/h4l/json.bash
EOT
      exit 0;;
    --version)
      json name=json.bash version=${JSON_BASH_VERSION:?} \
        web="https://github.com/h4l/json.bash"; exit 0;;
  esac
  fn=json
  if [[ $0 =~ [^[:alpha:]](array|object)$ ]]; then fn=json.${BASH_REMATCH[1]}; fi
  out='' json_defaults='' json_return='' \
    json_buffered_chunk_count=${JSON_BASH_BUFFERED_ARRAY_ELEMENT_COUNT:-} \
    json_chunk_size=${JSON_BASH_BUFFERED_BYTES_COUNT:-} \
    json_stream=${JSON_BASH_STREAM:-} \
    "${fn:?}" "$@" || exit $?
fi
