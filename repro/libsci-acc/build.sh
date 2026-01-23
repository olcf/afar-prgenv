#!/usr/bin/env bash
set -euo pipefail

label="${AFAR_TEST_LABEL:-default}"
out_dir="${AFAR_TEST_OUT_DIR:-build}/${label}"
mkdir -p "${out_dir}"

if [[ -z "${CRAY_LIBSCI_ACC_PREFIX_DIR:-}" ]]; then
  echo "SKIP: cray-libsci_acc not loaded." >&2
  exit 0
fi

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
check_ldd="${root_dir}/scripts/check_ldd.sh"

libdir="${CRAY_LIBSCI_ACC_PREFIX_DIR}/lib"
libname="${AFAR_LIBSCI_ACC_LIBNAME:-}"
if [[ -z "${libname}" ]]; then
  arch=""
  if [[ -n "${AFAR_LIBSCI_ACC_ARCH:-}" ]]; then
    arch="${AFAR_LIBSCI_ACC_ARCH}"
  elif [[ -n "${CRAY_ACCEL_TARGET:-}" && "${CRAY_ACCEL_TARGET}" == amd_gfx* ]]; then
    arch="${CRAY_ACCEL_TARGET#amd_}"
  elif [[ -n "${AFAR_FTN_OFFLOAD_ARCH:-}" ]]; then
    arch="${AFAR_FTN_OFFLOAD_ARCH}"
  else
    arch="gfx90a"
  fi

  for candidate in "sci_acc_amd_${arch}" "sci_acc_cray_${arch}" "sci_acc_gnu_${arch}"; do
    if [[ -f "${libdir}/lib${candidate}.so" || -f "${libdir}/lib${candidate}.a" ]]; then
      libname="${candidate}"
      break
    fi
  done

  if [[ -z "${libname}" ]]; then
    for lib in "${libdir}"/libsci_acc_*_"${arch}".so; do
      [[ -e "${lib}" ]] || continue
      base="${lib##*/lib}"
      base="${base%.so*}"
      libname="${base}"
      break
    done
  fi
fi

if [[ -z "${libname}" ]]; then
  echo "SKIP: libsci_acc library not found in ${libdir}." >&2
  exit 0
fi

cc -c libsci_acc_c.c -o "${out_dir}/libsci_acc_c.o"
CC -c libsci_acc_cpp.cpp -o "${out_dir}/libsci_acc_cpp.o"
ftn -c libsci_acc_f90.f90 -o "${out_dir}/libsci_acc_f90.o"

cc "${out_dir}/libsci_acc_c.o" -L"${libdir}" -l"${libname}" -o "${out_dir}/libsci_acc_c"
CC "${out_dir}/libsci_acc_cpp.o" -L"${libdir}" -l"${libname}" -o "${out_dir}/libsci_acc_cpp"
ftn "${out_dir}/libsci_acc_f90.o" -L"${libdir}" -l"${libname}" -o "${out_dir}/libsci_acc_f90"

ldd_log="${out_dir}/libsci_acc_ldd.log"
if ! "${check_ldd}" "${out_dir}/libsci_acc_c" "${out_dir}/libsci_acc_cpp" "${out_dir}/libsci_acc_f90" 2>"${ldd_log}"; then
  if grep -q "libamdhip64\.so\.6" "${ldd_log}" || grep -q "librocblas\.so\.4" "${ldd_log}"; then
    echo "SKIP: libsci_acc depends on ROCm 6 libraries not present in this AFAR drop." >&2
    exit 0
  fi
  cat "${ldd_log}" >&2
  exit 1
fi
