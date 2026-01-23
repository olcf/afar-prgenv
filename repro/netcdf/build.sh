#!/usr/bin/env bash
set -euo pipefail

label="${AFAR_TEST_LABEL:-default}"
out_dir="${AFAR_TEST_OUT_DIR:-build}/${label}"
mkdir -p "${out_dir}"

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
check_ldd="${root_dir}/scripts/check_ldd.sh"

pnetcdf_root=""
if [[ -n "${PNETCDF_DIR:-}" ]]; then
  pnetcdf_root="${PNETCDF_DIR}"
elif [[ -n "${CRAY_PARALLEL_NETCDF_DIR:-}" ]]; then
  pnetcdf_root="${CRAY_PARALLEL_NETCDF_DIR}"
elif [[ -n "${CRAY_PARALLEL_NETCDF_PREFIX:-}" ]]; then
  pnetcdf_root="${CRAY_PARALLEL_NETCDF_PREFIX}"
fi

if [[ -z "${pnetcdf_root}" ]]; then
  echo "SKIP: cray-parallel-netcdf module not loaded." >&2
  exit 0
fi

export PKG_CONFIG_PATH="${pnetcdf_root}/lib/pkgconfig${PE_AMD_FIXED_PKGCONFIG_PATH:+:${PE_AMD_FIXED_PKGCONFIG_PATH}}${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

if ! pkg-config --exists pnetcdf; then
  echo "SKIP: pnetcdf pkg-config not available." >&2
  exit 0
fi

cflags="$(pkg-config --cflags pnetcdf)"
clibs="$(pkg-config --libs pnetcdf)"

cc ${cflags} -c netcdf_c.c -o "${out_dir}/netcdf_c.o"
CC ${cflags} -c netcdf_cpp.cpp -o "${out_dir}/netcdf_cpp.o"

cc "${out_dir}/netcdf_c.o" ${clibs} -o "${out_dir}/netcdf_c"
CC "${out_dir}/netcdf_cpp.o" ${clibs} -o "${out_dir}/netcdf_cpp"

pnetcdf_inc_found="false"
for token in ${cflags}; do
  case "${token}" in
    -I*)
      incdir="${token#-I}"
      if [[ -f "${incdir}/pnetcdf.inc" ]]; then
        pnetcdf_inc_found="true"
        break
      fi
      ;;
  esac
done

ftn_enabled="true"
if [[ "${pnetcdf_inc_found}" != "true" ]]; then
  ftn_enabled="false"
  echo "SKIP: pnetcdf.inc not found on include path; skipping Fortran build." >&2
fi

if [[ "${ftn_enabled}" == "true" ]]; then
  ftn ${cflags} -c netcdf_f90.f90 -o "${out_dir}/netcdf_f90.o"
  ftn "${out_dir}/netcdf_f90.o" ${clibs} -o "${out_dir}/netcdf_f90"
fi

bins=("${out_dir}/netcdf_c" "${out_dir}/netcdf_cpp")
if [[ "${ftn_enabled}" == "true" ]]; then
  bins+=("${out_dir}/netcdf_f90")
fi

"${check_ldd}" "${bins[@]}"
