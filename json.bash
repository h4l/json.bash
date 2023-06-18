# shellcheck shell=bash
# set -euo pipefail
# shopt -s extglob

if [[ $0 == "${BASH_SOURCE[0]}" ]]; then
  echo "json.bash: this file must be sourced, not executed directly" >&2; exit 1
fi

# TODO: make a version of this for integers and other atomic types

# Encode the positional arguments as JSON strings, joined by commas.
function encode_json_strings() {
  strings=("${@//$'\\'/$'\\\\'}")             # escape \
  strings=("${strings[@]//$'"'/$'\\"'}")      # escape "
  strings=("${strings[@]/#/\"}")              # wrap in quotes
  strings=("${strings[@]/%/\"}")
  local IFS; IFS=${join:-,}; joined="${strings[*]}";   # join by ,
  while [[ $joined =~ [[:cntrl:]] ]]; do      # Escape special chars if needed
    declare -A escapes=([08]=b [09]=t [0a]=n [0c]=f [0d]=r)
    literal=${BASH_REMATCH[0]}
    hex=$(printf '%02x' "'$literal")
    escape=$(printf '\\%s' "${escapes[$hex]:-u00$hex}")
    joined=${joined//$literal/$escape}
  done
  echo -n "$joined"
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
  local _var _type _key _val _arg_pattern _number_pattern _json_type _json_val _result_format
  _arg_pattern='^(\w+)(:array|:raw|:auto|:bool|:number|:string|:null|:true|:false)?((=)(.*))?$'
  _number_pattern='^-?(0|[1-9][0-9]*)(\.[0-9]*)?([eE][+-]?[0-9]+)?$'
  _auto_raw_pattern='^(true|false|null)$|'"${_number_pattern:?}"
  entries=()
  _json_type=${json_type:-object}

  [[ $_json_type == object || $_json_type == array ]] || {
    echo "json(): json_type must be object or array or empty: '$_json_type'"
    return 1
  }

  for arg in "$@"; do
    if [[ $arg =~ $_arg_pattern ]]; then
      _var=${BASH_REMATCH[1]}
      _type=${BASH_REMATCH[2]:-:auto}
      _key=${BASH_REMATCH[5]:-$_var}
    else
      echo "json(): invalid argument: '$arg'" >&2; return 1;
    fi

    local -n _val="${_var:?}" # create a reference to the pre-defined var

    if [[ $_type == :array ]]; then
      _json_val="[$(encode_json_strings "${_val[@]}")]"
    elif [[ $_type == :raw || ( $_type == :auto && $_val =~ $_auto_raw_pattern ) ]]; then
      _json_val=$_val
    elif [[ $_type == :auto && $_val =~ $_auto_raw_pattern ]]; then
      _json_val=$_val
    elif [[ $_type == :number ]]; then
      [[ $_val =~ $_number_pattern ]] || { echo "json(): '$arg' value is not a number: '$_val'" >&2; return 1; }
      _json_val=$_val
    elif [[ $_type == :bool ]]; then
      [[ $_val != true && $_val != false ]] || { echo "json(): '$arg' value is not a bool: '$_val'" >&2; return 1; }
      _json_val=$_val
    elif [[ $_type == :null || $_type == :true || $_type == :false ]]; then
      _json_val="${_type:1}"
    elif [[ $_json_type == object ]]; then
      entries+=("$(join=: encode_json_strings "$_key" "$_val")")
      continue
    else
      _json_val="$(encode_json_strings "$_val")"
    fi

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
