#!/usr/bin/env bash

_json_bash_arg_pattern='^(@(\w+)|([^:=@-][^:=@]*))?(:(auto|bool|false|null|number|raw|string|true)(\[\])?)?(@=(\w+)|=(.*))?$'
_json_bash_number_pattern='-?(0|[1-9][0-9]*)(\.[0-9]*)?([eE][+-]?[0-9]+)?'
_json_bash_auto_pattern="\"(null|true|false|${_json_bash_number_pattern:?})\""
declare -gA _json_bash_escapes=(
                     [$'\x01']='\u0001' [$'\x02']='\u0002' [$'\x03']='\u0003'
  [$'\x04']='\u0004' [$'\x05']='\u0005' [$'\x06']='\u0006' [$'\x07']='\u0007'
  [$'\b']='\b'       [$'\t']='\t'       [$'\n']='\n'       [$'\x0b']='\u000b'
  [$'\f']='\f'       [$'\r']='\r'       [$'\x0e']='\u000e' [$'\x0f']='\u000f'
  [$'\x10']='\u0010' [$'\x11']='\u0011' [$'\x12']='\u0012' [$'\x13']='\u0013'
  [$'\x14']='\u0014' [$'\x15']='\u0015' [$'\x16']='\u0016' [$'\x17']='\u0017'
  [$'\x18']='\u0018' [$'\x19']='\u0019' [$'\x1a']='\u001a' [$'\x1b']='\u001b'
  [$'\x1c']='\u001c' [$'\x1d']='\u001d' [$'\x1e']='\u001e' [$'\x1f']='\u001f')

# Encode the positional arguments as JSON strings, joined by commas.
function encode_json_strings() {
  local strings joined literal escape
  strings=("${@//$'\\'/$'\\\\'}")             # escape \
  strings=("${strings[@]//$'"'/$'\\"'}")      # escape "
  strings=("${strings[@]/#/\"}")              # wrap in quotes
  strings=("${strings[@]/%/\"}")
  local IFS; IFS=${join:-,}; joined="${strings[*]}";  # join by ,
  while [[ $joined =~ [$'\x01'-$'\x1f\t\n\v\f\r'] ]]; do  # Escape special chars if needed
    literal=${BASH_REMATCH[0]:?}
    escape=${_json_bash_escapes[$literal]:?"no escape for ${literal@A}"}
    joined=${joined//$literal/$escape}
  done
  echo "$joined"
}

function _encode_json_values() {
  if [[ $# == 0 ]]; then return; fi
  values=("${@//$','/$'\\,'}")  # escape , (no-op unless input is invalid)
  local IFS; IFS=${join:-,}; joined="${values[*]}";  # join by ,
  if [[ ! ",$joined" =~ ^(,(${value_pattern:?}))+$ ]]; then
    echo "encode_json_${type_name:?}(): not all inputs are ${type_name:?}:$(printf " '%s'" "$@")" >&2
    return 1
  fi
  echo "$joined"
}

function encode_json_numbers() {
  type_name=numbers value_pattern=${_json_bash_number_pattern:?} _encode_json_values "$@"
}

function encode_json_bools() {
  type_name=bools value_pattern="true|false" _encode_json_values "$@"
}

function encode_json_falses() {
  type_name=false value_pattern="false" _encode_json_values "$@"
}

function encode_json_trues() {
  type_name=true value_pattern="true" _encode_json_values "$@"
}

function encode_json_nulls() {
  type_name=nulls value_pattern="null" _encode_json_values "$@"
}

function encode_json_autos() {
  if [[ $# == 0 ]]; then return; fi
  if [[ $# == 1 ]]; then
    if [[ \"$1\" =~ ^$_json_bash_auto_pattern$ ]]; then echo -n "$1"
    else encode_json_strings "$1"; fi
    return
  fi

  # Bash 5.2 supports & match references in substitutions, which would make it
  # easy to do this match & substitution in-process (without looping). But 5.2
  # is not yet widely available, so we'll fork a sed process to do this instead.
  sed <<<",$(encode_json_strings "$@")" -Ee "s/,${_json_bash_auto_pattern:?}/,\1/g" \
    | tail -c +2  # remove the , we added at the start
  [[ "${PIPESTATUS[*]}" == "0 0 0" ]] || return 1
}

function encode_json_raws() {
  # Caller is responsible for ensuring values are valid JSON!
  local IFS; IFS=${join:-,}; echo "$*";  # join by ,
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
  local _json_return _array _encode_fn _entries _json_val _key _type _value _match
  _entries=()
  _json_return=${json_return:-object}

  [[ $_json_return == object || $_json_return == array ]] || {
    echo "json(): json_return must be object or array or empty: '$_json_return'"
    return 1
  }

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

    # Handle the common object string value case a little more efficiently
    if [[ $_type == string && $_json_return == object && $_array == false ]]; then
      _entries+=("$(join=: encode_json_strings "$_key" "$_value")") || return 1
      continue
    fi

    _encode_fn="encode_json_${_type:?}s"
    if [[ $_array == true ]]; then _json_val="[$("$_encode_fn" "${_value[@]}")]"
    else _json_val=$("$_encode_fn" "${_value}"); fi
    [[ $? == 0 ]] || { echo "json(): failed to encode ${arg@A} ${_value@A}" >&2; return 1; }

    if [[ $_json_return == object ]]; then
      _entries+=("$(encode_json_strings "$_key"):${_json_val:?"json(): JSON value of ${arg@A} was empty"}")
    else
      _entries+=("${_json_val:?"json(): JSON value of ${arg@A} was empty"}")
    fi
  done

  local IFS; IFS=,;
  if   [[ $_json_return == object ]]; then echo "{${_entries[*]}}"
  else echo "[${_entries[*]}]"; fi
}

function json.object() {
  json_return=object json "$@"
}

function json.array() {
  json_return=array json "$@"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then # we're being executed directly
  json "$@" || exit $?
fi
