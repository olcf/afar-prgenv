#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "${script_dir}/.." && pwd)"

shim_dir="${AFAR_PKGCONFIG_SHIM_DIR:-${root_dir}/pkgconfig/shims/${AFAR_VERSION:-unknown}}"
mkdir -p "${shim_dir}"

write_pc() {
  local name="$1"
  local prefix="$2"
  local libdir="$3"
  local includedir="$4"
  local libs="$5"
  local version="$6"
  local desc="$7"

  [[ -n "${prefix}" && -n "${libdir}" ]] || return 0

  if [[ -z "${includedir}" ]]; then
    includedir="${prefix}/include"
  fi

  cat > "${shim_dir}/${name}.pc" <<PC
prefix=${prefix}
libdir=${libdir}
includedir=${includedir}

Name: ${name}
Description: ${desc}
Version: ${version:-unknown}
Libs: -L${libdir} ${libs}
Cflags: -I${includedir}
PC
}

libs_from_candidates() {
  local libdir="$1"
  shift
  local flags=""
  local name
  for name in "$@"; do
    [[ -z "${name}" ]] && continue
    if [[ -f "${libdir}/lib${name}.so" || -f "${libdir}/lib${name}.a" ]]; then
      flags+=" -l${name}"
    fi
  done
  printf '%s' "${flags# }"
}

lib_flags_from_list() {
  local libdir="$1"
  local list="$2"
  local flags=""
  local entry
  local name

  IFS=":" read -r -a entries <<< "${list}"
  for entry in "${entries[@]}"; do
    [[ -z "${entry}" ]] && continue
    if [[ "${entry}" == -* ]]; then
      flags+=" ${entry}"
      continue
    fi

    name="${entry}"
    if [[ -f "${libdir}/lib${entry}.so" || -f "${libdir}/lib${entry}.a" ]]; then
      name="${entry}"
    elif [[ -f "${libdir}/${entry}.so" || -f "${libdir}/${entry}.a" ]]; then
      if [[ "${entry}" == lib* ]]; then
        name="${entry#lib}"
      fi
    elif [[ "${entry}" == lib* ]]; then
      name="${entry#lib}"
    fi
    flags+=" -l${name}"
  done

  printf '%s' "${flags# }"
}

maybe_write_pc() {
  local name="$1"
  local prefix="$2"
  local libs_list="$3"
  local version="$4"
  local desc="$5"
  local libdir="${prefix}/lib"
  local includedir="${prefix}/include"

  [[ -n "${prefix}" ]] || return 0
  [[ -d "${libdir}" ]] || return 0

  local libs=""
  libs="$(lib_flags_from_list "${libdir}" "${libs_list}")"
  if [[ -z "${libs}" ]]; then
    return 0
  fi

  write_pc "${name}" "${prefix}" "${libdir}" "${includedir}" "${libs}" "${version}" "${desc}"
}

# HDF5 (serial or parallel)
if [[ -n "${HDF5_DIR:-}" || -n "${CRAY_HDF5_DIR:-}" || -n "${CRAY_HDF5_PARALLEL_DIR:-}" ]]; then
  if [[ -n "${CRAY_HDF5_PARALLEL_DIR:-}" || -n "${PE_HDF5_PARALLEL_DIR:-}" ]]; then
    hdf5_prefix="${HDF5_DIR:-${CRAY_HDF5_PARALLEL_PREFIX:-${CRAY_HDF5_PARALLEL_DIR:-}}}"
    hdf5_libs_list="${PE_HDF5_PARALLEL_PKGCONFIG_LIBS:-hdf5_parallel}"
    hdf5_version="${CRAY_HDF5_PARALLEL_VERSION:-}"
    maybe_write_pc "hdf5" "${hdf5_prefix}" "${hdf5_libs_list}" "${hdf5_version}" "AFAR shim for HDF5 parallel"
    hdf5_cpp_libs="${PE_HDF5_CXX_PKGCONFIG_LIBS:-}"
    if [[ -z "${hdf5_cpp_libs}" ]]; then
      hdf5_cpp_libs="$(libs_from_candidates "${hdf5_prefix}/lib" hdf5_hl_cpp_parallel hdf5_cpp_parallel hdf5_hl_cpp hdf5_cpp)"
    else
      hdf5_cpp_libs="$(lib_flags_from_list "${hdf5_prefix}/lib" "${hdf5_cpp_libs}")"
    fi
    if [[ -n "${hdf5_cpp_libs}" ]]; then
      write_pc "hdf5_cpp" "${hdf5_prefix}" "${hdf5_prefix}/lib" "${hdf5_prefix}/include" "${hdf5_cpp_libs}" "${hdf5_version}" "AFAR shim for HDF5 C++"
    fi
  else
    hdf5_prefix="${HDF5_DIR:-${CRAY_HDF5_PREFIX:-${CRAY_HDF5_DIR:-}}}"
    hdf5_libs_list="${PE_HDF5_PKGCONFIG_LIBS:-hdf5}"
    hdf5_version="${CRAY_HDF5_VERSION:-}"
    maybe_write_pc "hdf5" "${hdf5_prefix}" "${hdf5_libs_list}" "${hdf5_version}" "AFAR shim for HDF5"

    hdf5_cpp_libs="${PE_HDF5_CXX_PKGCONFIG_LIBS:-}"
    if [[ -n "${hdf5_cpp_libs}" ]]; then
      maybe_write_pc "hdf5_cpp" "${hdf5_prefix}" "${hdf5_cpp_libs}" "${hdf5_version}" "AFAR shim for HDF5 C++"
    fi
  fi
fi

# PnetCDF
if [[ -n "${PNETCDF_DIR:-}" || -n "${CRAY_PARALLEL_NETCDF_DIR:-}" || -n "${CRAY_PARALLEL_NETCDF_PREFIX:-}" ]]; then
  pnetcdf_prefix="${PNETCDF_DIR:-${CRAY_PARALLEL_NETCDF_PREFIX:-${CRAY_PARALLEL_NETCDF_DIR:-}}}"
  pnetcdf_libs="${PE_PARALLEL_NETCDF_PKGCONFIG_LIBS:-pnetcdf}"
  pnetcdf_version="${CRAY_PARALLEL_NETCDF_VERSION:-}"
  maybe_write_pc "pnetcdf" "${pnetcdf_prefix}" "${pnetcdf_libs}" "${pnetcdf_version}" "AFAR shim for PnetCDF"
fi

# DSMML
if [[ -n "${CRAY_DSMML_PREFIX:-}" || -n "${CRAY_DSMML_DIR:-}" ]]; then
  dsmml_prefix="${CRAY_DSMML_PREFIX:-${CRAY_DSMML_DIR:-}}"
  dsmml_libs="${PE_DSMML_PKGCONFIG_LIBS:-dsmml}"
  dsmml_version="${CRAY_DSMML_VERSION:-}"
  maybe_write_pc "dsmml" "${dsmml_prefix}" "${dsmml_libs}" "${dsmml_version}" "AFAR shim for DSMML"
fi

# FFTW
if [[ -n "${FFTW_ROOT:-}" || -n "${CRAY_FFTW_PREFIX:-}" ]]; then
  fftw_prefix="${FFTW_ROOT:-${CRAY_FFTW_PREFIX:-}}"
  fftw_libs="${PE_FFTW_PKGCONFIG_LIBS:-fftw3}"
  fftw_version="${CRAY_FFTW_VERSION:-${FFTW_VERSION:-}}"
  maybe_write_pc "fftw3" "${fftw_prefix}" "${fftw_libs}" "${fftw_version}" "AFAR shim for FFTW"
fi

# LibSci
if [[ -n "${CRAY_LIBSCI_PREFIX_DIR:-}" || -n "${CRAY_LIBSCI_PREFIX:-}" ]]; then
  libsci_prefix="${CRAY_LIBSCI_PREFIX_DIR:-${CRAY_LIBSCI_PREFIX:-}}"
  libsci_libs="${PE_LIBSCI_PKGCONFIG_LIBS:-libsci}"
  libsci_version="${CRAY_LIBSCI_VERSION:-}"
  maybe_write_pc "libsci" "${libsci_prefix}" "${libsci_libs}" "${libsci_version}" "AFAR shim for LibSci"
fi

printf '%s\n' "${shim_dir}"
