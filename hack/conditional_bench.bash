#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../json.bash"

count=${COUNT:?}
method=${METHOD:?}
value=${VALUE:-}
value2=${VALUE2:-}


echo "${count@A} ${method@A} ${value@A}" >&2

if [[ $method == if-else-2 ]]; then
  for ((id=0; id<$count; ++id)) do
    if [[ ${value:?} == 0 ]]; then
      echo 0
    else echo 1; fi
  done
elif [[ $method == if-else-3 ]]; then
  for ((id=0; id<$count; ++id)) do
    if [[ ${value:?} == 0 ]]; then
      echo 0
    elif [[ ${value:?} == 1 ]]; then
      echo 1
    else echo 2; fi
  done
elif [[ $method == case-2 ]]; then
  for ((id=0; id<$count; ++id)) do
    case ${value:?} in
      0) echo 0;;
      *) echo 1;;
    esac
  done
elif [[ $method == case-3 ]]; then
  for ((id=0; id<$count; ++id)) do
    case ${value:?} in
      0) echo 0;;
      1) echo 1;;
      *) echo 2;;
    esac
  done
elif [[ $method == if-else-2x2 ]]; then
  for ((id=0; id<$count; ++id)) do
    if [[ ${value:?} == 0 ]]; then
      if [[ $value2 == '' ]]; then
        echo "a ${value}_${value2}"
      else
        echo "b ${value}_${value2}"
      fi
    elif [[ ${value2} == '' ]]; then
      echo "c ${value}_${value2}"
    else
      echo "d ${value}_${value2}"
    fi
  done
elif [[ $method == case-2x2 ]]; then
  for ((id=0; id<$count; ++id)) do
      case "${value}_${value2}" in
      0_) echo "a ${value}_${value2}";;
      0_*) echo "b ${value}_${value2}";;
      *_) echo "c ${value}_${value2}";;
      *) echo "d ${value}_${value2}";;
      esac
  done
else
  echo "$0: unknown ${method@A}" >&2
  exit 1
fi
