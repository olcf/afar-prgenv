#!/usr/bin/env bash
set -euo pipefail

label="${AFAR_TEST_LABEL:-default}"
out_dir="${AFAR_TEST_OUT_DIR:-build}/${label}"
mkdir -p "${out_dir}"

if [[ -z "${CRAY_LIBSCI_PREFIX_DIR:-}" ]]; then
  echo "SKIP: cray-libsci not loaded." >&2
  exit 0
fi

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
check_ldd="${root_dir}/scripts/check_ldd.sh"

export PKG_CONFIG_PATH="${CRAY_LIBSCI_PREFIX_DIR}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

cflags="$(pkg-config --cflags libsci)"
libs="$(pkg-config --libs libsci)"

cc ${cflags} -c libsci_c.c -o "${out_dir}/libsci_c.o"
CC ${cflags} -c libsci_cpp.cpp -o "${out_dir}/libsci_cpp.o"
ftn ${cflags} -c libsci_f90.f90 -o "${out_dir}/libsci_f90.o"

cc "${out_dir}/libsci_c.o" ${libs} -o "${out_dir}/libsci_c"
CC "${out_dir}/libsci_cpp.o" ${libs} -o "${out_dir}/libsci_cpp"
ftn "${out_dir}/libsci_f90.o" ${libs} -o "${out_dir}/libsci_f90"

"${check_ldd}" "${out_dir}/libsci_c" "${out_dir}/libsci_cpp" "${out_dir}/libsci_f90"
