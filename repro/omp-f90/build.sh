#!/usr/bin/env bash
set -euo pipefail

label="${AFAR_TEST_LABEL:-default}"
out_dir="${AFAR_TEST_OUT_DIR:-build}/${label}"
mkdir -p "${out_dir}"

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
check_ldd="${root_dir}/scripts/check_ldd.sh"

ftn -fopenmp omp_test.f90 -o "${out_dir}/omp_test_f90"

"${check_ldd}" "${out_dir}/omp_test_f90"

if [[ "${AFAR_TEST_RUN:-0}" == "1" ]]; then
  export OMP_NUM_THREADS="${OMP_NUM_THREADS:-2}"
  "${out_dir}/omp_test_f90"
fi
