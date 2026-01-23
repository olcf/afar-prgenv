#!/usr/bin/env bash
set -euo pipefail

label="${AFAR_TEST_LABEL:-default}"
out_dir="${AFAR_TEST_OUT_DIR:-build}/${label}"
mkdir -p "${out_dir}"

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
check_ldd="${root_dir}/scripts/check_ldd.sh"

if [[ -n "${CRAY_DSMML_PREFIX:-}" ]]; then
  export PKG_CONFIG_PATH="${CRAY_DSMML_PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
fi

if ! pkg-config --exists dsmml; then
  echo "SKIP: DSMML pkg-config not available." >&2
  exit 0
fi

cflags="$(pkg-config --cflags dsmml)"
libs="$(pkg-config --libs dsmml)"

cc ${cflags} -c dsmml_c.c -o "${out_dir}/dsmml_c.o"
ftn ${cflags} -c dsmml_f90.f90 -o "${out_dir}/dsmml_f90.o"

cc "${out_dir}/dsmml_c.o" ${libs} -o "${out_dir}/dsmml_c"
ftn "${out_dir}/dsmml_f90.o" ${libs} -o "${out_dir}/dsmml_f90"

"${check_ldd}" "${out_dir}/dsmml_c" "${out_dir}/dsmml_f90"
