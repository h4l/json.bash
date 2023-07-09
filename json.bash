#!/usr/bin/env bash
shopt -s extglob # required to match our auto glob patterns

JSON_BASH_VERSION=0.1.0

# Generated in hack/argument_pattern.bash
_json_bash_arg_pattern=$'^((@(::|==|@@|\\[\\[|[^:=[@]))?((::|==|@@|\\[\\[)|[^:=[@])*)?(:(auto|bool|false|json|null|number|raw|string|true))?(\\[((\\]\\]|,,|==)|[^]])*\\])?(@?=|$)'
_json_bash_simple_arg_pattern=$'^((@[^:=[@]+)|([^:=[@]+))?(:(auto|bool|false|json|null|number|raw|string|true))?((\\[([^]:=[@,])?\\]))?(@=\\.?/?|=|$)'
_json_bash_type_name_pattern=$'^(auto|bool|false|json|null|number|raw|string|true)$'
_json_bash_number_pattern='-?(0|[1-9][0-9]*)(\.[0-9]*)?([eE][+-]?[0-9]+)?'
_json_bash_auto_pattern="\"(null|true|false|${_json_bash_number_pattern:?})\""
_json_bash_number_glob='?([-])@(0|[1-9]*([0-9]))?([.]+([0-9]))?([eE]?([+-])+([0-9]))'
_json_bash_auto_glob="\"@(true|false|null|$_json_bash_number_glob)\""
_json_in_err="in= must be set when no positional args are given"
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
  if ! json.validate "$@"; then
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

function json.start_json_validator() {
  if [[ ${_json_validator_pids[$$]:-} != "" ]]; then return 0; fi

  local ws string number atom array object json validation_request
  # This is a PCRE regex that matches JSON. This is possible because we use
  # PCRE's recursive patterns to match JSON's nested constructs. And also
  # possessive repetition quantifiers to prevent expensive backtracking on match
  # failure. Backtracking is not required to parse JSON as it's not ambiguous.
  # If a rule fails to match, the input is known to be invalid, there's no
  # possibility of an alternate rule matching, so backtracking is pointless.
  ws='(?<ws> [\x20\x09\x0A\x0D]*+ )'  # space, tab, new line, carriage return
  string='(?<str> " (?:
    [\x20-\x21\x23-\x5B\x5D-\xFF]
    | \\ (?: ["\\/bfnrt] | u [A-Fa-f0-9]{4} )
  )*+ " )'
  number='-?+ (?: 0 | [1-9][0-9]*+ ) (?: \. [0-9]*+ )?+ (?: [eE][+-]?+[0-9]++ )?+'
  atom="true | false | null | ${number:?} | ${string:?}"
  array='\[  (?: (?&ws) (?&json) (?: (?&ws) , (?&ws) (?&json) )*+ )?+ (?&ws) \]'
  object='\{ (?:
    (?<entry> (?&ws) (?&str) (?&ws) : (?&ws) (?&json) )
    (?: (?&ws) , (?&entry) )*+
  )?+ (?&ws) \}'
  json="(?<json> ${ws:?} (?: ${array:?} | ${object:?} | ${atom:?} ) (?&ws) )"

  validation_request="
    ^ [\w]++ (?:
      (?=
        (?<pair> : (?&pair)?+ \x1E ${json:?} ) $
      ) :++
    )?+"

  { coproc json_validator ( grep --null-data --only-matching --line-buffered \
    -P -e "${validation_request//[$' \n']/}" )
  } 2>/dev/null  # hide interactive job control PID output
  _json_validator_pids[$$]=json_validator_PID

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

  let "_json_validate_id=${_json_validate_id:-0}+1"; local id=$_json_validate_id
  local count_markers IFS # delimit JSON with Record Separator
  # Send a null-terminated JSON validation request to the validator process and
  # read the response to determine if the JSON was valid.
  if [[ $# == 0 ]]; then
    local -n _validate_json_in="${in:?$_json_in_err}"
    if [[ ${#_validate_json_in[@]} == 0 ]]; then return 0; fi
    printf -v count_markers ':%.0s' "${!_validate_json_in[@]}"
    IFS=$'\x1E'; printf '%d%s\x1E%s\x00' "${id:?}" "${count_markers?}" \
      "${_validate_json_in[*]}" >&"${_json_validator_in_fds[$$]:?}"
  else
    IFS=''; count_markers=${*/*/:}
    IFS=$'\x1E'; printf '%d%s\x1E%s\x00' "${id:?}" "${count_markers?}" \
      "$*" >&"${_json_validator_in_fds[$$]:?}"
  fi

  IFS=''
  if ! read -ru "${_json_validator_out_fds[$$]:?}" -t 4 -d '' response; then
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
# types, and when encoding arrays of any time. (However, it buffers individual
# array values, so the values themselves can't be larger than memory, but the
# overall array can be.)
function json.encode_from_file() {
  case "${type:?}_${array:-}" in
  # There's not much point in implementing json.stream_encode_json() because
  # grep (which evaluates the validation regex) buffers the entire input in
  # memory while matching, despite not needing to backtrack or output the match.
  (@(string|number|bool|true|false|null|auto|raw|json)_true)
    json.stream_encode_array || return $? ;;
  (@(string|raw)_*)
    "json.stream_encode_${type:?}" || return $? ;;
  (@(number|bool|true|false|null|auto|json)_*)
    json.encode_value_from_file || return $? ;;
  (*)
    echo "json.encode_from_file(): unsupported type: ${type@Q}" >&2; return 1 ;;
  esac
}

# Encode the contents of a file as a JSON string, without buffering the whole
# value.
function json.stream_encode_string() {
  local _jses_chunk _jses_encoded IFS='' eof=
  json.buffer_output '"'
  while [[ ! $eof ]]; do
    _jses_encoded=()
    read -r -d '' -N "${json_chunk_size:-8191}" _jses_chunk || eof=true
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
  local _jser_chunk eof=
  read -r -d '' -N "${json_chunk_size:-8191}" _jser_chunk || eof=true
  if [[ ! $_jser_chunk ]]; then
    echo "json.stream_encode_raw(): raw JSON value is empty" >&2; return 1
  fi
  json.buffer_output "${_jser_chunk}"
  "${out_cb:-:}"
  while [[ ! $eof ]]; do
    read -r -d '' -N "${json_chunk_size:-8191}" _jser_chunk || eof=true
    json.buffer_output "${_jser_chunk}"
    "${out_cb:-:}"
  done
}

# Read a file (up to the first null byte, if any) and encode it as $type.
#
# This function buffers the entire value in memory.
function json.encode_value_from_file() {
  local _jevff_chunk
  # close stdin after reading 1 chunk — we ignore anything after the first null
  # byte. Note: read without -N trims trailing newlines, which we want.
  read -r -d '' _jevff_chunk || true
  "json.encode_${type:?}" "${_jevff_chunk}"
}
function json._jevff_close_stdin() { exec 0<&-; }

# Stream-encode chunks from a file as JSON array elements.
#
# This function splits the input file (stdin) into chunks using the single
# character delimiter defined by $split. While encoding, it buffers individual
# chunks in memory, but not the file as a whole (so long as the caller flushes
# their $out buffer via the $out_cb callback.)
function json.stream_encode_array() {
  local _jsea_raw_chunks=() _jsea_encoded_chunks=() _jsea_caller_out=${out:-} \
    _jsea_last_emit= _jsea_separator=() _jsea_error=
  out=$_jsea_caller_out json.buffer_output '['
  readarray -t -d "${split?}" -C json.__jsea_on_chunks_available \
    -c "${json_buffered_chunk_count:-1024}" _jsea_raw_chunks
  if [[ $_jsea_error ]]; then return 1; fi
  unset "_jsea_raw_chunks[$_jsea_last_emit]"
  if [[ ${#_jsea_raw_chunks[@]} != 0 ]]; then
    out=$_jsea_caller_out in=_jsea_separator json.buffer_output
    out=$_jsea_caller_out in=_jsea_raw_chunks join=, "json.encode_${type:?}" \
      || return 1
  fi
  out=$_jsea_caller_out json.buffer_output ']'
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
         "json.encode_${type:?}"; then
    # readarray ignores our exit status, but we can force it to stop by closing
    # stdin, which it's reading.
    exec 0<&-  # close stdin
    _jsea_error=true
    return
  fi
  _jsea_raw_chunks=()
  : ${_jsea_separator:=,} # separate chunks with , after the first write
  "${out_cb:-:}" # call the out_cb, if provided
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
  local -n _jpa_out=${out:?'$out must name an Associative Array to hold parsed attributes'} \
    _jpa_keyfull=BASH_REMATCH[1] _jpa_keyref=BASH_REMATCH[2] _jpa_keyref1=BASH_REMATCH[3] \
    _jpa_keyesc=BASH_REMATCH[5] _jpa_type=BASH_REMATCH[7] \
    _jpa_attrsfull=BASH_REMATCH[8] _jpa_attrsesc=BASH_REMATCH[10] \
    _jpa_valeq=BASH_REMATCH[11]
  local IFS _jpa_attrskv _jpa_val
  # Parsing an argument results in a set of name=value attributes. The argument
  # syntax (other than the [name=value,...] section) is all shorthand for
  # attributes which could be manually specified using attributes.
  if [[ ! ${1} =~ $_json_bash_arg_pattern ]]; then
    echo "json(): invalid argument: '$1'" >&2; return 1;
  fi
  _jpa_val=${1:${#BASH_REMATCH[0]}}
  if [[ $_jpa_type != '' ]]; then _jpa_out[type]=${_jpa_type:?}; fi

  case "${_jpa_valeq}${_jpa_val:0:2}" in
  (?*)        _jpa_out[val]=${_jpa_val};;&  # continue testing the rest
  (@=/*|@=./) _jpa_out[@val]=file;;
  (@=*)       _jpa_out[@val]=var;;
  (=*)        _jpa_out[@val]=${_jpa_out[@val]:-str};;
  esac

  case "${_jpa_keyref:0:1}_${_jpa_keyfull:0:3}" in
  (@_@/*|@_@./) _jpa_out[key]=${_jpa_keyfull:1}; _jpa_out[@key]=file;;
  (@_*) _jpa_out[key]=${_jpa_keyfull:1}; _jpa_out[@key]=var;;
  (_?*) _jpa_out[key]=${_jpa_keyfull} _jpa_out[@key]=${_jpa_out[@key]:-str};;
  esac

  case "${_jpa_keyref1}_${_jpa_keyesc}" in # unescape key only if escapes exist
  ([@:[=]?_*|*_[@:[=]?) # detect double-char escape after initial @ or later
    _jpa_out[key]=${_jpa_out[key]//@@/@}
    _jpa_out[key]=${_jpa_out[key]//::/:}
    _jpa_out[key]=${_jpa_out[key]//'[['/[}
    _jpa_out[key]=${_jpa_out[key]//==/=}
  ;;
  esac

  # bash bug? the string length of a nameref pointing to an array element is always 0
  case "${#BASH_REMATCH[8]}_$_jpa_attrsesc" in
  (0_) ;;  # No [] section
  (2_)  # Empty [] section ( just [] )
    _jpa_out[array]=${__jpa_array_default:-true}
  ;;
  (*_??)  # Non-empty with at least 1 escape
    _jpa_attrskv="${_jpa_attrsfull:1:-1}"   # Remove the enclosing [ ]
    _jpa_attrskv=${_jpa_attrskv//,,/'\]1'}  # Re-escape escapes so we can use , and = unambiguously.
    _jpa_attrskv=${_jpa_attrskv//==/'\]2'}  # We make use of ] in this temporary escape sequence, as ] can't occur by itself because of the surrounding [ ].

    IFS=,; _jpa_attrskv=(${_jpa_attrskv})             # Split on commas
    _jpa_attrskv=("${_jpa_attrskv[@]//'\]1'/,}")      # Restore ,, escapes as ,
    _jpa_attrsk=("${_jpa_attrskv[@]/%=*/}")           # Remove =value suffix to get key
    _jpa_attrsv=("${_jpa_attrskv[@]/#*([^=])?(=)/}")  # Remove key= prefix to get value

    _jpa_attrsk=("${_jpa_attrsk[@]//'\]2'/=}")  # Restore == escapes as =
    _jpa_attrsv=("${_jpa_attrsv[@]//'\]2'/=}")  # Restore == escapes as == (values don't need to escape =, so == is ==).
    _jpa_attrsk=("${_jpa_attrsk[@]//']]'/]}")   # Apply ]] escapes as ]
    _jpa_attrsv=("${_jpa_attrsv[@]//']]'/]}")   # Apply ]] escapes as ]
   ;;&  # continue matching
  (*_)  # Non-empty without escapes
    _jpa_attrskv="${_jpa_attrsfull:1:-1}"             # Remove the enclosing [ ]
    IFS=,; _jpa_attrskv=(${_jpa_attrskv})             # Split on commas
    _jpa_attrsk=("${_jpa_attrskv[@]/%=*/}")           # Remove =value suffix to get key
    _jpa_attrsv=("${_jpa_attrskv[@]/#*([^=])?(=)/}")  # Remove key= prefix to get value
  ;;&  # continue matching
  (*)  # Handle the split attributes from either of the previous 2 cases
    _jpa_out[array]=${__jpa_array_default:-true}  # Any [*] value is array=true by default. (Can include [array=false] to opt out)
    # Split char shorthand: The first attribute can be a single char, which implies split=<char>.
    if (( ${#_jpa_attrsk[0]} == 1 )) \
      && [[ ${_jpa_attrsk[0]} == "${_jpa_attrskv[0]}" \
        || "${_jpa_attrskv[0]}" == "]]" \
        || "${_jpa_attrskv[0]}" == "\]2" ]]
    then _jpa_attrsv[0]=${_jpa_attrsk[0]}; _jpa_attrsk[0]=split; fi

    for i in "${!_jpa_attrsk[@]}"; do
      _jpa_out["${_jpa_attrsk["$i"]:-__empty__}"]=${_jpa_attrsv["$i"]}
    done
  ;;
  esac
}

# Encode arguments as JSON objects or arrays and print to stdout.
#
# Each argument is an entry in the JSON object or array created by the call.
# See the --help message for argument syntax.
function json() {
  # vars referenced by arguments cannot start with _, so we prefix our own vars
  # with _ to prevent args referencing locals.
  local IFS _array _dashdash_seen _encode_fn _key _type _value _value_array _match _split

  local _caller_out=${out:-}
  if [[ ${json_stream:-} != true ]]
  then local out=_json_buff _json_buff=(); fi

  local -A _defaults
  if [[ -v json_defaults || -v json_defaults[@] ]]; then
    if [[ ${json_defaults@a} == *A* ]]; then
      unset _defaults; local -n _defaults=json_defaults
    elif [[ ${json_defaults:-} ]]; then
      # Can't fail to parse because we escape ] as ]]
      out=_defaults __jpa_array_default='false' json.parse_argument \
        "[${json_defaults//']'/']]'}]"
    fi
    if [[ ! ${_defaults[type]:-string} =~ $_json_bash_type_name_pattern ]]; then
      json._error "json(): json_defaults contains invalid 'type':" \
        "${_defaults[type]@Q}"; return 2
    fi
  fi

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
    # Optimisation: Most patterns don't use escapes or named attributes, so use
    # a cut-down, faster parsing strategy for common/simple patterns
    if [[ $arg =~ $_json_bash_simple_arg_pattern ]]; then
      case "${BASH_REMATCH[1]}:${BASH_REMATCH[5]}[${BASH_REMATCH[6]}]${BASH_REMATCH[9]}" in
      (@*)          _attrs[key]=${BASH_REMATCH[1]:1} _attrs[@key]=var ;;&
      ('@'@(./|/)*) _attrs[@key]=file ;;&
      ([^@]*:*)     _attrs[key]=${BASH_REMATCH[1]} _attrs[@key]=str ;;&
      (*:?*'['*)    _attrs[type]=${BASH_REMATCH[5]} ;;&
      (*'[[]]'*)    _attrs[array]=true ;;&
      (*'[['?']']*) _attrs[array]=true _attrs[split]=${BASH_REMATCH[8]} ;;&
      (*=)          _attrs[val]=${arg:${#BASH_REMATCH[0]}} _attrs[@val]=str ;;&
      (*@=@(./|/))  _attrs[val]="${BASH_REMATCH[9]:2}${arg:${#BASH_REMATCH[0]}}" _attrs[@val]=file ;;
      (*@=)         _attrs[@val]=var ;;&
      esac
    else
      if ! out=_attrs json.parse_argument "$arg"; then
        json._error "json(): argument is not structured correctly: ${arg@Q}"; return 2;
      fi
    fi
    unset -n {_key,_value}{,_file}; unset {_key,_value}{,_file};

    _type=${_attrs[type]:-${_defaults[type]:-string}}
    _array=${_attrs[array]:-${_defaults[array]:-false}}
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
      if [[ ! ${_key+isset} ]]; then
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
    ;;
    (object_file) _key_file=${_attrs[key]} ;;
    (*) _key=${_attrs[key]:-} ;;
    esac

    case "${_attrs[@val]}" in
    (var)
      local -n _value="${_attrs[val]}"
      if [[ ! ${_value+isset} ]]; then
        if [[ ${_attrs[val]} != *']' ]]  # don't create _FILE refs for array vars
        then local -n _value_file="${_attrs[val]}_FILE"; fi

        if [[ ! ${_value_file:-} =~ ^\.?/ ]]; then
          unset -n _value_file
          json._error "json(): argument references unbound variable:" \
            "\$${_attrs[val]} from ${arg@Q}"; return 3
        fi
      fi ;;
    (file) _value_file=${_attrs[val]} ;;
    (str) _value=${_attrs[val]} ;;
    esac

    if [[ ${_first:?} == true ]]; then _first=false
    else json.buffer_output ","; fi

    # Handle the common object string value case a little more efficiently
    if [[ $_type == string && $_json_return == object && $_array != true \
          && ! ( ${_key_file:-} || ${_value_file:-} ) ]]; then
      join=':' json.encode_string "$_key" "$_value" || { json._error; return 1; }
      continue
    fi

    if [[ $_json_return == object ]]; then
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
      elif [[ ${_attrs[array]:-} == true ]]; then _split=$'\n';
      else _split=''; fi

      if ! { { array=${_array:?} type=${_type:?} split=${_split?} \
              json.encode_from_file || _status=$?; } < "${_value_file:?}"; }; then
        json._error "json(): failed to read file referenced by argument:" \
          "${_value_file@Q} from ${arg@Q}"; return 4
      fi
      if [[ $_status != 0 ]]; then
        json._error "json(): failed to encode file contents as ${_type:?}:" \
          "${_value_file@Q} from ${arg@Q}"; return 1
      fi
    else
      if [[ $_array == true ]]; then
        json.buffer_output "["
        if [[ ${_value@a} != *a* ]]; then # if the value isn't an array, split it
          if [[ ${_attrs[split]+isset} ]]; then _split=${_attrs[split]}
          elif [[ ${_attrs[array]:-} == true ]]; then _split=$'\n';
          else _split=''; fi

          IFS=${_split}; _value_array=(${_value})  # intentional splitting
          join=, in=_value_array "$_encode_fn" || _status=$?;
        else join=, in=_value "$_encode_fn" || _status=$?; fi
        json.buffer_output "]"
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
