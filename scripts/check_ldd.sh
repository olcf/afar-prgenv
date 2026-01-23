#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  echo "Usage: $(basename "$0") <binary> [binary...]" >&2
  exit 2
fi

allowed_prefixes_default=(
  /autofs/nccs-svm1_sw/crusher/ums/compilers/afar
  /opt/cray
  /opt/amdgpu
  /opt/rocm-7.0.2
  /sw/frontier
  /lib
  /lib64
  /usr/lib
  /usr/lib64
)

if [[ -n "${AFAR_LDD_ALLOWED_PREFIXES:-}" ]]; then
  IFS=":" read -r -a allowed_prefixes <<< "${AFAR_LDD_ALLOWED_PREFIXES}"
else
  allowed_prefixes=("${allowed_prefixes_default[@]}")
fi

fail=0

check_path_allowed() {
  local path="$1"
  local prefix
  for prefix in "${allowed_prefixes[@]}"; do
    [[ -z "${prefix}" ]] && continue
    if [[ "${path}" == "${prefix}"* ]]; then
      return 0
    fi
  done
  return 1
}

for bin in "$@"; do
  if [[ ! -x "${bin}" ]]; then
    echo "ldd check: missing executable ${bin}" >&2
    fail=1
    continue
  fi

  while IFS= read -r line; do
    if [[ "${line}" == *"not found"* ]]; then
      echo "ldd check: missing library: ${line}" >&2
      fail=1
      continue
    fi

    path=""
    if [[ "${line}" == *"=>"* ]]; then
      path="${line#*=> }"
      path="${path%% *}"
    elif [[ "${line}" == /* ]]; then
      path="${line%% *}"
    fi

    [[ -z "${path}" ]] && continue
    [[ "${path}" != /* ]] && continue

    if ! check_path_allowed "${path}"; then
      echo "ldd check: unexpected library path: ${path}" >&2
      fail=1
    fi
  done < <(ldd "${bin}")

done

exit "${fail}"
