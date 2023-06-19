#!/usr/bin/env bash
shopt -s extglob

_json_bash_number_pattern='-?(0|[1-9][0-9]*)(\.[0-9]*)?([eE][+-]?[0-9]+)?'
_json_bash_auto_pattern="\"(null|true|false|${_json_bash_number_pattern:?})\""
_json_bash_number_glob='?([-])@(0|[1-9]*([0-9]))?([.]+([0-9]))?([eE]?([+-])+([0-9]))'
_json_bash_auto_glob="\"@(true|false|null|$_json_bash_number_glob)\""

# Encode the positional arguments as JSON strings, joined by commas.
function encode_json_strings() {
  strings=("${@//$'\\'/$'\\\\'}")             # escape \
  strings=("${strings[@]//$'"'/$'\\"'}")      # escape "
  strings=("${strings[@]/#/\"}")              # wrap in quotes
  strings=("${strings[@]/%/\"}")
  local IFS; IFS=${join:-,}; joined="${strings[*]}";  # join by ,
  while [[ $joined =~ [[:cntrl:]] ]]; do      # Escape special chars if needed
    declare -A escapes=([08]=b [09]=t [0a]=n [0c]=f [0d]=r)
    literal=${BASH_REMATCH[0]}
    hex=$(printf '%02x' "'$literal")
    escape=$(printf '\\%s' "${escapes[$hex]:-u00$hex}")
    joined=${joined//$literal/$escape}
  done
  echo -n "$joined"
}

function _encode_json_values() {
  if [[ $# == 0 ]]; then return; fi
  values=("${@//$','/$'\\,'}")  # escape , (no-op unless input is invalid)
  local IFS; IFS=${join:-,}; joined="${values[*]}";  # join by ,
  if [[ ! ",$joined" =~ ^(,(${value_pattern:?}))+$ ]]; then
    echo "encode_json_${type_name:?}(): not all inputs are ${type_name:?}:$(printf " '%s'" "$@")" >&2
    return 1
  fi
  echo -n "$joined"
}

function encode_json_numbers() {
  type_name=numbers value_pattern=${_json_bash_number_pattern:?} _encode_json_values "$@"
}

function encode_json_bools() {
  type_name=bools value_pattern="true|false" _encode_json_values "$@"
}

function encode_json_nulls() {
  type_name=nulls value_pattern="null" _encode_json_values "$@"
}

function encode_json_autos() {
  if [[ $# == 0 ]]; then return; fi
  if [[ $# == 1 ]]; then
    if [[ \"$1\" =~ $_json_bash_auto_pattern ]]; then echo -n "$1"
    else encode_json_strings "$1"; fi
    return
  fi
  
  # Bash 5.2 supports & match references in substitutions, which would make it
  # easy to do this match & substitution in-process (without looping). But 5.2
  # is not yet widely available, so we'll fork a sed process to do this instead.
  encode_json_strings "$@" | sed -Ee "s/${_json_bash_auto_pattern:?}/\1/g"
  [[ "${PIPESTATUS[*]}" == "0 0" ]] || return 1
}

function encode_json_raws() {
  # Caller is responsible for ensuring values are valid JSON!
  local IFS; IFS=${join:-,}; echo -n "$*";  # join by ,
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
#   type         = ":" ( "string" | "number" | "bool"
#                      | "null" | "raw" | "auto" ) [ "[]" ]
#
#   inline-key   = /^[^:=@]*/
#   inline-value = /^=.*/
#   ref-key      = /^@\w+/
#   ref-value    = /^@=\w+/
# 

# TODO: should the standalone-value rule be the value for objects as well as
# arrays? i.e. `json foo` is {"": "foo"}  or ["foo"]. For objects the key is the
# value if nothing is provided. Or the key is the var name if @ is used.
# foo=123 json_type=auto json @foo :string=sdfs # {"foo":123,"foo":"123"}

function json() {
  # TODO: we don't need _ prefixes
  local _type _key _val _arg_pattern _number_pattern _json_type _json_val _result_format
  _arg_pattern='^(@(\w+)|([^:=@]+))?(:(auto|bool|null|number|raw|string)(\[\])?)?(@=(\w+)|=(.*))?$'

  entries=()
  _json_type=${json_type:-object}

  [[ $_json_type == object || $_json_type == array ]] || {
    echo "json(): json_type must be object or array or empty: '$_json_type'"
    return 1
  }

  for arg in "$@"; do
    if [[ $arg =~ $_arg_pattern ]]; then
      _type=${BASH_REMATCH[5]:-${json_value_type:-string}}
      _array=${BASH_REMATCH[6]/[]/true}
      # If no value is set, the key is the value. 
      if [[ ${BASH_REMATCH[7]} == "" ]]; then   # no value - value is key
        if [[ ${BASH_REMATCH[2]} != "" ]]; then # key is a ref
          _key="${BASH_REMATCH[2]}"             # key is ref name
          local -n _value="${BASH_REMATCH[2]}"  # value is the key's reference
        else _key=${BASH_REMATCH[3]}; _value=${BASH_REMATCH[3]}; fi
      else
        if [[ ${BASH_REMATCH[2]} != "" ]]; then local -n _key="${BASH_REMATCH[2]}"
        else _key=${BASH_REMATCH[3]}; fi
        if [[ ${BASH_REMATCH[8]} != "" ]]; then local -n _value="${BASH_REMATCH[8]}"
        else _value=${BASH_REMATCH[9]}; fi
      fi
    else
      echo "json(): invalid argument: '$arg'" >&2; return 1;
    fi
    
    # Handle the common object string value case a little more efficiently
    if [[ $_type == string && $_json_type == object && $_array == false ]]; then
      entries+=("$(join=: encode_json_strings "$_key" "$_value")") || return 1
      continue
    fi

    _encode_fn="encode_json_${_type:?}s"
    if [[ $_array == true ]]; then _json_val="[$("$_encode_fn" "${_value[@]}")]"
    else _json_val=$("$_encode_fn" "${_value}"); fi
    [[ $? == 0 ]] || { echo "json(): failed to encode ${arg@A} ${_value@A}" >&2; return 1; }

    if [[ $_json_type == object ]]; then
      entries+=("$(encode_json_strings "$_key"):${_json_val:?}")
    else
      entries+=("${_json_val:?}")
    fi
  done

  local IFS; IFS=,;
  if   [[ $_json_type == object ]]; then echo -n "{${entries[*]}}"
  else echo -n "[${entries[*]}]"; fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then # we're being executed directly
  json "$@" && printf '\n' || exit $?
fi
