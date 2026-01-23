#!/usr/bin/env bash
set -euo pipefail

label="${AFAR_TEST_LABEL:-default}"
out_dir="${AFAR_TEST_OUT_DIR:-build}/${label}"
mkdir -p "${out_dir}"

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
check_ldd="${root_dir}/scripts/check_ldd.sh"

if [[ -z "${FFTW_ROOT:-}" && -z "${CRAY_FFTW_PREFIX:-}" ]]; then
  echo "SKIP: FFTW module not loaded." >&2
  exit 0
fi

if [[ -n "${FFTW_ROOT:-}" ]]; then
  export PKG_CONFIG_PATH="${FFTW_ROOT}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
elif [[ -n "${CRAY_FFTW_PREFIX:-}" ]]; then
  export PKG_CONFIG_PATH="${CRAY_FFTW_PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
fi

if ! pkg-config --exists fftw3; then
  echo "SKIP: FFTW pkg-config not available." >&2
  exit 0
fi

cflags="$(pkg-config --cflags fftw3)"
libs="$(pkg-config --libs fftw3)"

cc ${cflags} -c fftw_c.c -o "${out_dir}/fftw_c.o"
CC ${cflags} -c fftw_cpp.cpp -o "${out_dir}/fftw_cpp.o"
ftn ${cflags} -c fftw_f90.f90 -o "${out_dir}/fftw_f90.o"

cc "${out_dir}/fftw_c.o" ${libs} -o "${out_dir}/fftw_c"
CC "${out_dir}/fftw_cpp.o" ${libs} -o "${out_dir}/fftw_cpp"
ftn "${out_dir}/fftw_f90.o" ${libs} -o "${out_dir}/fftw_f90"

"${check_ldd}" "${out_dir}/fftw_c" "${out_dir}/fftw_cpp" "${out_dir}/fftw_f90"
