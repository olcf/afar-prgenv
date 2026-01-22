#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULEPATHS_DEFAULT="${AFAR_TEST_MODULEPATH:-${ROOT_DIR}/afar_modules/modulefiles:/sw/crusher/ums/compilers/modulefiles}"

AFAR_VERSION_DEFAULT="${AFAR_TEST_AFAR_VERSION:-22.2.0-8873}"
AFAR_MODULE_DEFAULT="${AFAR_TEST_AFAR_MODULE:-afar-prgenv/${AFAR_VERSION_DEFAULT}}"
CPE_DEFAULT="${AFAR_TEST_CPE:-cpe/25.09}"
PRGENV_DEFAULT="${AFAR_TEST_PRGENV:-PrgEnv-amd}"
MPICH_DEFAULT="${AFAR_TEST_MPICH:-cray-mpich/9.0.1}"
CPU_TARGET_DEFAULT="${AFAR_TEST_CPU_TARGET:-craype-x86-trento}"
GPU_TARGET_DEFAULT="${AFAR_TEST_GPU_TARGET:-craype-accel-amd-gfx90a}"

LIBSCI_MODULE_DEFAULT="${AFAR_TEST_LIBSCI_MODULE:-cray-libsci}"
HDF5_MODULE_DEFAULT="${AFAR_TEST_HDF5_MODULE:-cray-hdf5-parallel}"
FFTW_MODULE_DEFAULT="${AFAR_TEST_FFTW_MODULE:-cray-fftw}"
DSMML_MODULE_DEFAULT="${AFAR_TEST_DSMML_MODULE:-cray-dsmml}"

PROFILES_DEFAULT="${AFAR_TEST_PROFILES:-base,libsci,hdf5,fftw,dsmml}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --profiles <list>     Comma-separated profile list (default: ${PROFILES_DEFAULT})
  --modulepath <path>   AFAR modulefiles path (default: ${MODULEPATHS_DEFAULT})
  --afar-version <ver>  AFAR drop version (default: ${AFAR_VERSION_DEFAULT})
  --afar-module <name>  AFAR module to load (default: ${AFAR_MODULE_DEFAULT})
  --cpe <module>        CPE module (default: ${CPE_DEFAULT})
  --prgenv <module>     PrgEnv module (default: ${PRGENV_DEFAULT})
  --mpich <module>      Cray MPICH module (default: ${MPICH_DEFAULT})
  --keep-going          Continue after failures
  -h, --help            Show this help
EOF
}

PROFILES="${PROFILES_DEFAULT}"
MODULEPATHS="${MODULEPATHS_DEFAULT}"
AFAR_VERSION="${AFAR_VERSION_DEFAULT}"
AFAR_MODULE="${AFAR_MODULE_DEFAULT}"
CPE_MODULE="${CPE_DEFAULT}"
PRGENV_MODULE="${PRGENV_DEFAULT}"
MPICH_MODULE="${MPICH_DEFAULT}"
KEEP_GOING="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profiles)
      PROFILES="${2:-}"
      shift 2
      ;;
    --modulepath)
      MODULEPATHS="${2:-}"
      shift 2
      ;;
    --afar-version)
      AFAR_VERSION="${2:-}"
      shift 2
      ;;
    --afar-module)
      AFAR_MODULE="${2:-}"
      shift 2
      ;;
    --cpe)
      CPE_MODULE="${2:-}"
      shift 2
      ;;
    --prgenv)
      PRGENV_MODULE="${2:-}"
      shift 2
      ;;
    --mpich)
      MPICH_MODULE="${2:-}"
      shift 2
      ;;
    --keep-going)
      KEEP_GOING="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "${AFAR_MODULE}" != afar-prgenv/* ]]; then
  echo "AFAR test runner requires a local afar-prgenv module (got: ${AFAR_MODULE})." >&2
  exit 1
fi

if ! command -v module >/dev/null 2>&1; then
  if [[ -f /etc/profile.d/modules.sh ]]; then
    # shellcheck disable=SC1091
    source /etc/profile.d/modules.sh
  fi
fi

if [[ -z "${LMOD_CMD:-}" && -x /opt/cray/pe/lmod/lmod/libexec/lmod ]]; then
  export LMOD_CMD=/opt/cray/pe/lmod/lmod/libexec/lmod
fi

split_csv() {
  local input="$1"
  local IFS=","
  read -r -a items <<< "${input}"
  printf '%s\n' "${items[@]}"
}

module_use_paths() {
  local list="$1"
  local IFS=":"
  read -r -a paths <<< "${list}"
  local p
  for p in "${paths[@]}"; do
    [[ -z "${p}" ]] && continue
    module use "${p}"
  done
}

module_load_all() {
  local mods=("$@")
  if ! command -v module >/dev/null 2>&1; then
    if [[ -x /opt/cray/pe/lmod/lmod/libexec/lmod ]]; then
      export LMOD_CMD=/opt/cray/pe/lmod/lmod/libexec/lmod
    fi
    if [[ -f /opt/cray/pe/lmod/lmod/init/bash ]]; then
      # shellcheck disable=SC1091
      source /opt/cray/pe/lmod/lmod/init/bash
    fi
  fi
  if [[ -x /opt/cray/pe/lmod/lmod/libexec/lmod ]]; then
    export LMOD_CMD=/opt/cray/pe/lmod/lmod/libexec/lmod
  fi
  local local_modpath="${ROOT_DIR}/afar_modules/modulefiles"
  if [[ ":${MODULEPATHS}:" != *":${local_modpath}:"* ]]; then
    MODULEPATHS="${local_modpath}:${MODULEPATHS}"
  fi
  if [[ -z "${LMOD_SETTARG_CMD:-}" ]]; then
    # Force a harmless settarg command to avoid ':' builtin issues.
    export LMOD_SETTARG_CMD=/bin/true
  fi
  if [[ "${AFAR_TEST_DEBUG_MODULES:-}" == "1" ]]; then
    type -a : || true
    enable -p : || true
    echo "LMOD_SETTARG_CMD=${LMOD_SETTARG_CMD-<unset>}"
  fi
  if ! module reset >/dev/null 2>&1; then
    module purge
  fi
  module_use_paths "${MODULEPATHS}"
  local mod
  for mod in "${mods[@]}"; do
    if ! module load "${mod}"; then
      echo "Failed to load module: ${mod}" >&2
      return 1
    fi
  done
  module list
}

run_repro() {
  local profile="$1"
  local repro_dir="$2"
  local repro_name
  repro_name="$(basename "${repro_dir}")"

  if [[ ! -x "${repro_dir}/build.sh" ]]; then
    echo "SKIP: ${repro_name} (missing build.sh)" >&2
    return 0
  fi

  echo "==> ${repro_name}"
  (cd "${repro_dir}" && \
    AFAR_TEST_LABEL="${profile}" \
    AFAR_TEST_OUT_DIR="${AFAR_TEST_OUT_DIR:-build}" \
    ./build.sh)
}

run_profile() {
  local profile="$1"
  local modules=()
  case "${profile}" in
    base)
      modules=("${CPE_MODULE}" "${PRGENV_MODULE}" "${MPICH_MODULE}" \
        "${CPU_TARGET_DEFAULT}" "${GPU_TARGET_DEFAULT}" "${AFAR_MODULE}")
      ;;
    libsci)
      modules=("${CPE_MODULE}" "${PRGENV_MODULE}" "${MPICH_MODULE}" \
        "${CPU_TARGET_DEFAULT}" "${GPU_TARGET_DEFAULT}" "${LIBSCI_MODULE_DEFAULT}" \
        "${AFAR_MODULE}")
      ;;
    hdf5)
      modules=("${CPE_MODULE}" "${PRGENV_MODULE}" "${MPICH_MODULE}" \
        "${CPU_TARGET_DEFAULT}" "${GPU_TARGET_DEFAULT}" "${HDF5_MODULE_DEFAULT}" \
        "${AFAR_MODULE}")
      ;;
    fftw)
      modules=("${CPE_MODULE}" "${PRGENV_MODULE}" "${MPICH_MODULE}" \
        "${CPU_TARGET_DEFAULT}" "${GPU_TARGET_DEFAULT}" "${FFTW_MODULE_DEFAULT}" \
        "${AFAR_MODULE}")
      ;;
    dsmml)
      modules=("${CPE_MODULE}" "${PRGENV_MODULE}" "${MPICH_MODULE}" \
        "${CPU_TARGET_DEFAULT}" "${GPU_TARGET_DEFAULT}" "${DSMML_MODULE_DEFAULT}" \
        "${AFAR_MODULE}")
      ;;
    *)
      echo "Unknown profile: ${profile}" >&2
      return 1
      ;;
  esac

  local log_dir="${AFAR_TEST_LOG_DIR:-${ROOT_DIR}/logs}"
  mkdir -p "${log_dir}"
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local log_file="${log_dir}/${timestamp}-${profile}.log"

  {
    echo "=== Profile: ${profile}"
    echo "=== Modules: ${modules[*]}"
    if ! module_load_all "${modules[@]}"; then
      echo "SKIP: profile ${profile} (module load failure)"
      return 0
    fi
    local ftn_path=""
    local ftn_expected="${ROOT_DIR}/afar_modules/bin/ftn"
    ftn_path="$(command -v ftn || true)"
    if command -v readlink >/dev/null 2>&1; then
      ftn_path="$(readlink -f "${ftn_path}" 2>/dev/null || printf "%s" "${ftn_path}")"
      ftn_expected="$(readlink -f "${ftn_expected}" 2>/dev/null || printf "%s" "${ftn_expected}")"
    fi
    if [[ -z "${ftn_path}" || "${ftn_path}" != "${ftn_expected}" ]]; then
      echo "FAIL: ftn wrapper not from local AFAR module tree: ${ftn_path}" >&2
      return 1
    fi

    local repro_dir
    for repro_dir in "${ROOT_DIR}/repro/"*; do
      [[ -d "${repro_dir}" ]] || continue
      if ! run_repro "${profile}" "${repro_dir}"; then
        echo "FAIL: ${profile} -> $(basename "${repro_dir}")"
        if [[ "${KEEP_GOING}" != "true" ]]; then
          return 1
        fi
      fi
    done
  } 2>&1 | tee "${log_file}"
}

failures=0
while IFS= read -r profile; do
  [[ -z "${profile}" ]] && continue
  if ! run_profile "${profile}"; then
    failures=$((failures + 1))
    if [[ "${KEEP_GOING}" != "true" ]]; then
      break
    fi
  fi
done < <(split_csv "${PROFILES}")

if [[ "${failures}" -gt 0 ]]; then
  echo "AFAR test run completed with ${failures} failure(s)." >&2
  exit 1
fi

echo "AFAR test run completed successfully."
