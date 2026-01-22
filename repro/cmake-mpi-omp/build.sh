#!/usr/bin/env bash
set -euo pipefail

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake not found; skipping CMake test." >&2
  exit 0
fi

label="${AFAR_TEST_LABEL:-default}"
build_dir="build/${label}"
if [[ -d "${build_dir}" ]]; then
  rm -rf "${build_dir}"
fi
mkdir -p "${build_dir}"

export AFAR_FTN_OFFLOAD_ARCH=
export AFAR_CC_OFFLOAD_ARCH=
export AFAR_CXX_OFFLOAD_ARCH=

cmake -S . -B "${build_dir}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=cc \
  -DCMAKE_Fortran_COMPILER=ftn \
  ${AFAR_TEST_CMAKE_ARGS:-}

cmake --build "${build_dir}" -j "${AFAR_TEST_JOBS:-4}"
