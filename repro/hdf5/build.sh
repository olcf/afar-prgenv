#!/usr/bin/env bash
set -euo pipefail

label="${AFAR_TEST_LABEL:-default}"
out_dir="${AFAR_TEST_OUT_DIR:-build}/${label}"
mkdir -p "${out_dir}"

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
check_ldd="${root_dir}/scripts/check_ldd.sh"

hdf5_root=""
if [[ -n "${HDF5_DIR:-}" ]]; then
  hdf5_root="${HDF5_DIR}"
elif [[ -n "${CRAY_HDF5_DIR:-}" ]]; then
  hdf5_root="${CRAY_HDF5_DIR}"
fi

if [[ -z "${hdf5_root}" ]]; then
  echo "SKIP: HDF5 module not loaded." >&2
  exit 0
fi

export PKG_CONFIG_PATH="${hdf5_root}/lib/pkgconfig${PE_AMD_FIXED_PKGCONFIG_PATH:+:${PE_AMD_FIXED_PKGCONFIG_PATH}}${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

if ! pkg-config --exists hdf5; then
  echo "SKIP: HDF5 pkg-config not available." >&2
  exit 0
fi

cflags="$(pkg-config --cflags hdf5)"
clibs="$(pkg-config --libs hdf5)"

cpp_enabled="true"
cppflags=""
cpplibs=""
if pkg-config --exists hdf5_cpp; then
  cppflags="$(pkg-config --cflags hdf5_cpp)"
  cpplibs="$(pkg-config --libs hdf5_cpp)"
else
  cpp_enabled="false"
  echo "SKIP: HDF5 C++ pkg-config not available." >&2
fi

cc ${cflags} -c hdf5_c.c -o "${out_dir}/hdf5_c.o"
cc "${out_dir}/hdf5_c.o" ${clibs} -o "${out_dir}/hdf5_c"

if [[ "${cpp_enabled}" == "true" ]]; then
  CC ${cppflags} -c hdf5_cpp.cpp -o "${out_dir}/hdf5_cpp.o"
  CC "${out_dir}/hdf5_cpp.o" ${cpplibs} -o "${out_dir}/hdf5_cpp"
fi

shim_dir="${out_dir}/fortran-shim"
mkdir -p "${shim_dir}"

ftn -c hdf5_shim.f90 -J "${shim_dir}" -I "${shim_dir}" -o "${out_dir}/hdf5_shim.o"
ftn -I "${shim_dir}" -c hdf5_f90.f90 -o "${out_dir}/hdf5_f90.o"
ftn "${out_dir}/hdf5_f90.o" "${out_dir}/hdf5_shim.o" ${clibs} -o "${out_dir}/hdf5_f90"

bins=("${out_dir}/hdf5_c" "${out_dir}/hdf5_f90")
if [[ "${cpp_enabled}" == "true" ]]; then
  bins+=("${out_dir}/hdf5_cpp")
fi

"${check_ldd}" "${bins[@]}"
