#!/usr/bin/env bash
set -euo pipefail

readarray -d '' builds \
  < <(find build -mindepth 2 -maxdepth 2 -type d -print0)

if [[ ${#builds[@]} == 0 ]]; then
  echo "No build output dirs found" >&2
  exit 1
fi

failures=()
for build in "${builds[@]}"; do
  if [[ -f "${build:?}/FAIL" ]]; then
    failures+=("${build:?}")
    log_files=("${build:?}"/*.log)
    if [[ "${#log_files[@]}" != 0 ]]; then
      echo "Build ${build:?} failed — log output follows:"
      cat "${log_files[@]}"
    else
      echo "Build ${build:?} failed — log file not found"
      fi
  else
    echo "Build ${build:?} passed"
  fi
done

if [[ ${#failures[@]} != 0 ]]; then exit 1; fi
