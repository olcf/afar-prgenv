#!/usr/bin/env bash
set -euo pipefail

label="${AFAR_TEST_LABEL:-default}"
out_dir="${AFAR_TEST_OUT_DIR:-build}/${label}"
mkdir -p "${out_dir}"

ftn hello.f90 -o "${out_dir}/mpi_hello"

if [[ "${AFAR_TEST_RUN_MPI:-0}" == "1" ]]; then
  if command -v srun >/dev/null 2>&1; then
    srun -n 2 "${out_dir}/mpi_hello"
  elif command -v mpirun >/dev/null 2>&1; then
    mpirun -n 2 "${out_dir}/mpi_hello"
  else
    echo "MPI run skipped (no srun or mpirun found)." >&2
  fi
fi
