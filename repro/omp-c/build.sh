#!/usr/bin/env bash
set -euo pipefail

label="${AFAR_TEST_LABEL:-default}"
out_dir="${AFAR_TEST_OUT_DIR:-build}/${label}"
mkdir -p "${out_dir}"

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
check_ldd="${root_dir}/scripts/check_ldd.sh"

cc -fopenmp omp_test.c -o "${out_dir}/omp_test_c"

"${check_ldd}" "${out_dir}/omp_test_c"

if [[ "${AFAR_TEST_RUN:-0}" == "1" ]]; then
  export OMP_NUM_THREADS="${OMP_NUM_THREADS:-2}"
  "${out_dir}/omp_test_c"
fi
