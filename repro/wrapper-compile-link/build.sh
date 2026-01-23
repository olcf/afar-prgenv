#!/usr/bin/env bash
set -euo pipefail

label="${AFAR_TEST_LABEL:-default}"
out_dir="${AFAR_TEST_OUT_DIR:-build}/${label}"
mkdir -p "${out_dir}"

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
check_ldd="${root_dir}/scripts/check_ldd.sh"

cc -c hello.c -o "${out_dir}/hello_c.o"
CC -c hello.cpp -o "${out_dir}/hello_cpp.o"
ftn -c hello.f90 -o "${out_dir}/hello_f90.o"

cc "${out_dir}/hello_c.o" -o "${out_dir}/hello_c"
CC "${out_dir}/hello_cpp.o" -o "${out_dir}/hello_cpp"
ftn "${out_dir}/hello_f90.o" -o "${out_dir}/hello_f90"

"${check_ldd}" "${out_dir}/hello_c" "${out_dir}/hello_cpp" "${out_dir}/hello_f90"
