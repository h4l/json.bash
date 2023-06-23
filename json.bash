#!/usr/bin/env bash
shopt -s extglob # required to match our auto glob patterns

JSON_BASH_VERSION=0.1.0
_json_bash_arg_pattern='^(@(\w+)|([^:=@-][^:=@]*))?(:(auto|bool|false|null|number|raw|string|true)(\[\])?)?(@=(\w+)|=(.*))?$'
_json_bash_number_pattern='-?(0|[1-9][0-9]*)(\.[0-9]*)?([eE][+-]?[0-9]+)?'
_json_bash_auto_pattern="\"(null|true|false|${_json_bash_number_pattern:?})\""
_json_bash_number_glob='?([-])@(0|[1-9]*([0-9]))?([.]+([0-9]))?([eE]?([+-])+([0-9]))'
_json_bash_auto_glob="\"@(true|false|null|$_json_bash_number_glob)\""
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
function json.bash.buffer_output() {
  if [[ "${out:-}" == "" ]]; then printf '%s' "$@"
  else local -n __buffer="${out:?}"; __buffer+=("$@"); fi
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
function encode_json_strings() {
  if [[ $# == 1 ]]; then
    local string literal escape
    string=${1//$'\\'/$'\\\\'}             # escape \
    string=${string//$'"'/$'\\"'}          # escape "
    string=${string//$'\n'/$'\\n'}         # optimistically escape \n
    string="\"${string}\""                 # wrap in quotes
    while [[ $string =~ [$'\x01'-$'\x1f\t\n\v\f\r'] ]]; do  # Escape control chars
      literal=${BASH_REMATCH[0]:?}
      escape=${_json_bash_escapes[$literal]:?}
      string=${string//$literal/$escape}
    done
    out=${out:-} json.bash.buffer_output "$string"
    return
  fi

  local strings joined literal escape
  strings=("${@//$'\\'/$'\\\\'}")             # escape \
  strings=("${strings[@]//$'"'/$'\\"'}")      # escape "
  strings=("${strings[@]//$'\n'/$'\\n'}")     # optimistically escape \n
  strings=("${strings[@]/#/\"}")              # wrap in quotes
  strings=("${strings[@]/%/\"}")
  local IFS=${join:-}; joined="${strings[*]}";
  local controls=$'\x01\x02\x03\x04\x05\x06\x07\b\t\x0b\f\r\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f'

  if [[ ${join:-} == '' ]]; then
    while [[ $joined =~ [$controls] ]]; do  # Escape control chars
      literal=${BASH_REMATCH[0]:?}
      escape=${_json_bash_escapes[$literal]:?"no escape for ${literal@A}"}
      controls=${controls/$literal/}
      strings=("${strings[@]//$literal/$escape}")
    done
    out=${out:-} json.bash.buffer_output "${strings[@]}"
  else
    while [[ $joined =~ [$controls] ]]; do  # Escape control chars
      literal=${BASH_REMATCH[0]:?}
      escape=${_json_bash_escapes[$literal]:?"no escape for ${literal@A}"}
      joined=${joined//$literal/$escape}
    done
    out=${out:-} json.bash.buffer_output "$joined"
  fi
}

function _encode_json_values() {
  if [[ $# == 0 ]]; then return; fi
  values=("${@//$','/$'\\,'}")  # escape , (no-op unless input is invalid)
  local validation_join=${join:-,}
  local IFS; IFS=${validation_join:?}; joined="${values[*]}";  # join by ,
  if [[ ! "${validation_join}$joined" =~ \
         ^(${validation_join}(${value_pattern:?}))+$ ]]; then
    echo "encode_json_${type_name:?}(): not all inputs are ${type_name:?}:\
$(printf " '%s'" "$@")" >&2
    return 1
  fi
  if [[ ${join:-} == '' ]]; then out=${out:-} json.bash.buffer_output "$@"
  else IFS=${join}; out=${out:-} json.bash.buffer_output "$joined"; fi
}

function encode_json_numbers() {
  type_name=numbers value_pattern=${_json_bash_number_pattern:?} out=${out:-} \
    join=${join:-} _encode_json_values "$@"
}

function encode_json_bools() {
  type_name=bools value_pattern="true|false" out=${out:-} join=${join:-} \
    _encode_json_values "$@"
}

function encode_json_falses() {
  type_name=false value_pattern="false" out=${out:-} join=${join:-} _encode_json_values "$@"
}

function encode_json_trues() {
  type_name=true value_pattern="true" out=${out:-} join=${join:-} _encode_json_values "$@"
}

function encode_json_nulls() {
  type_name=nulls value_pattern="null" out=${out:-} join=${join:-} _encode_json_values "$@"
}

function encode_json_autos() {
  if [[ $# == 0 ]]; then return; fi
  if [[ $# == 1 ]]; then
    if [[ \"$1\" =~ ^$_json_bash_auto_pattern$ ]]; then
      out=${out:-} json.bash.buffer_output "$1"
    else out=${out:-} encode_json_strings "$1"; fi
    return
  fi

  # Bash 5.2 supports & match references in substitutions, which would make it
  # easy to remove quotes from things matching the auto pattern. But 5.2 is not
  # yet widely available, so we'll implement with a bash-level loop, which is
  # probably quite slow for large arrays.
  # TODO: Add a conditional branch to implement this with & ref substitutions
  local __encode_json_autos  # __ to avoid var clashes...
  out=__encode_json_autos join= encode_json_strings "$@"
  autos=("${__encode_json_autos[@]//$_json_bash_auto_glob/}")
  for ((i=0; i < ${#__encode_json_autos[@]}; ++i)); do
    if [[ ${#autos[$i]} == 0 ]];
    then __encode_json_autos[$i]=${__encode_json_autos[$i]:1:-1}; fi
  done

  if [[ ${join:-} == '' ]]; then
  out=${out:-} json.bash.buffer_output "${__encode_json_autos[@]}"
  else
    local IFS=${join};
    out=${out:-} json.bash.buffer_output "${__encode_json_autos[*]}";
  fi
}

function encode_json_raws() {
  # Caller is responsible for ensuring values are valid JSON!
  if [[ $# == 1 && $1 == "" ]]; then
    echo "json.bash: raw JSON value is empty" >&2; return 1
  fi

  if [[ ${join:-} == '' ]]; then out=${out:-} json.bash.buffer_output "$@"
  else IFS=${join}; out=${out:-} json.bash.buffer_output "$*"; fi
}

# Encode arguments as JSON objects or arrays and print to stdout.
#
# Each argument is an entry in the JSON object or array created by the call.
# Arguments use the syntax:
#
# Examples:
#   json name=Hal  # {"name":"Hal"}
#   name="Hal" json name=@name  # {"name":"Hal"}
#   prop=name name="Hal" json @prop=@name  # {"name":"Hal"}
#   json Length=42 length:string=42  # {"Length":42,length:"42"}
#   json active=true stopped_date=null name:string=null  # {"active":true,"stopped_date":null,"name":"null"}
#   json entry:object={"name":"Bob"} # {"entry":{"name":"Bob"}}
#   data=(4 8 16); json numbers:number[]=@data # {"numbers":[4,8,16]}
#   json @bar:string@foo bar:string="asdfsd"
#
#   argument     = [ key ] [ type ] [ value ]
#   value        = inline-value | ref-value
#   key          = inline-key | ref-key
#
#   type         = ":" ( "string" | "number" | "bool" | "true" | "false"
#                      | "null" | "raw" | "auto" ) [ "[]" ]
#
#   inline-key   = /^([^:=@-][^:=@]*)?/
#   inline-value = /^=.*/
#   ref-key      = "@" ref-name
#   ref-value    = "@=" ref-name
#   ref-name     = /^[a-zA-Z0-9]\w*/
#
function json() {
  # vars referenced by arguments cannot start with _, so we prefix our own vars
  # with _ to prevent args referencing locals.
  local _array _encode_fn _key _type _value _match
  local _caller_out=${out:-} out=_json_buff _json_buff=()

  local _json_return=${json_return:-object}
  [[ $_json_return == object || $_json_return == array ]] || {
    echo "json(): json_return must be object or array or empty: '$_json_return'"
    return 1
  }

  if [[ $_json_return == object ]]; then out=${out:-} json.bash.buffer_output "{"
  else out=${out:-} json.bash.buffer_output "["; fi

  local _first=true
  for arg in "$@"; do
    if [[ $arg =~ $_json_bash_arg_pattern ]]; then
      unset -n _key _value
      _match=("${BASH_REMATCH[@]}")
      _type=${_match[5]:-${json_type:-string}}
      _array=${_match[6]/[]/true}
      # If no value is set, provide a default
      if [[ ${_match[7]} == "" ]]; then  # No value is set
        if [[ $_type == true|| $_type == false || $_type == null ]]; then
          _match[9]=$_type  # inline value is the type
          if [[ $_type != null ]]; then _type=bool; fi # use the bool encode fn
        elif [[ ${_match[2]} != "" ]]; then # key is a ref
          _match[8]=${_match[2]} # use key ref for value ref
          _match[3]=${_match[2]} # use key ref name for key
          _match[2]=
        else # use inline key value as inline value
          _match[9]=${_match[3]}
        fi
      fi
      if [[ ${_match[2]} != "" ]]; then local -n _key="${_match[2]}"
      else _key=${_match[3]}; fi
      if [[ ${_match[8]} != "" ]]; then local -n _value="${_match[8]}"
      else _value=${_match[9]}; fi
    else
      echo "json(): invalid argument: '$arg'" >&2; return 1;
    fi

    if [[ ${_first:?} == true ]]; then _first=false
    else out=${out:-} json.bash.buffer_output ","; fi

    # Handle the common object string value case a little more efficiently
    if [[ $_type == string && $_json_return == object && $_array == false ]]; then
      join=':' out=${out:-} encode_json_strings "$_key" "$_value" || return 1
      continue
    fi

    if [[ $_json_return == object ]]; then
      out=${out:-} encode_json_strings "$_key" || return 1
      out=${out:-} json.bash.buffer_output ":"
    fi
    _encode_fn="encode_json_${_type:?}s"
    local _status=0
    if [[ $_array == true ]]; then
      out=${out:-} json.bash.buffer_output "["
      out=${out:-} join=, "$_encode_fn" "${_value[@]}" || _status=$?
      out=${out:-} json.bash.buffer_output "]"
    else out=${out:-} "$_encode_fn" "${_value}" || _status=$?; fi
    [[ $_status == 0 ]] \
      || { echo "json(): failed to encode ${arg@A} -> ${_value@Q}" >&2; return 1; }
  done

  if [[ $_json_return == object ]]; then out=${out:-} json.bash.buffer_output "}"
  else out=${out:-} json.bash.buffer_output "]"; fi
  # Emit only complete JSON values, not pieces
  local IFS=''; out=${_caller_out?} json.bash.buffer_output "${_json_buff[*]}"
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
Generate JSON objects.

Usage:
  ${prog:?} [key][:type][=value]...

Examples:
  $ ${prog_obj:?} msg="Hello World" size:number=42 enable:true data:false
  {"msg":"Hello World","size":42,"enable":true,"data":false}

  # Reference variables with @name
  $ id=42 date=\$(date --iso) ${prog_obj:?} @id created@=date modified@=date
  {"id":"42","created":"2023-06-23","modified":"2023-06-23"}

  # Create arrays with ${prog_array}
  $ ${prog_array:?} '*.md' :raw="\$(${prog_obj:?} max_width:number=80)"
  ["*.md",{"max_width":80}]

  # Change the default value type with json_type=
  $ json_type=number ${prog_array:?} 1 2 3
  [1,2,3]

  # In a bash script/shell, source ${prog_obj:?} and use the json function
  $ source \$(command -v ${prog_obj:?})
  $ out=compilerOptions json removeComments:true
  $ files=(a.ts b.ts)
  $ json @compilerOptions:raw @files:string[]
  {"compilerOptions":{"removeComments":true},"files":["a.ts","b.ts"]}

More:
  https://github.com/h4l/json.bash
EOT
      exit 0;;
    --version)
      echo -e "json.bash ${JSON_BASH_VERSION:?}\n" \
              "https://github.com/h4l/json.bash"; exit 0;;
  esac
  fn=json
  if [[ $0 =~ [^[:alpha:]](array|object)$ ]]; then fn=json.${BASH_REMATCH[1]}; fi
  out= "${fn:?}" "$@" && echo || exit $?
fi
