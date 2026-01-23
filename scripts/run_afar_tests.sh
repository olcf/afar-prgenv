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
LIBSCI_ACC_MODULE_DEFAULT="${AFAR_TEST_LIBSCI_ACC_MODULE:-cray-libsci_acc}"
HDF5_SERIAL_MODULE_DEFAULT="${AFAR_TEST_HDF5_SERIAL_MODULE:-cray-hdf5}"
HDF5_MODULE_DEFAULT="${AFAR_TEST_HDF5_MODULE:-cray-hdf5-parallel}"
FFTW_MODULE_DEFAULT="${AFAR_TEST_FFTW_MODULE:-cray-fftw}"
DSMML_MODULE_DEFAULT="${AFAR_TEST_DSMML_MODULE:-cray-dsmml}"
PAR_NETCDF_MODULE_DEFAULT="${AFAR_TEST_PARALLEL_NETCDF_MODULE:-cray-parallel-netcdf}"

PROFILES_DEFAULT="${AFAR_TEST_PROFILES:-base,libsci,libsci-acc,hdf5,hdf5-serial,fftw,dsmml,netcdf}"
LIB_ORDER_DEFAULT="${AFAR_TEST_LIB_ORDER:-both}"

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
  --lib-order <value>   Library load order: before, after, both (default: ${LIB_ORDER_DEFAULT})
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
LIB_ORDER="${LIB_ORDER_DEFAULT}"

RESULTS=()

record_result() {
  local profile="$1"
  local repro="$2"
  local status="$3"
  local reason="$4"
  reason="${reason//$'
'/ }"
  RESULTS+=("${profile}	${repro}	${status}	${reason}")
}

print_summary() {
  if [[ ${#RESULTS[@]} -eq 0 ]]; then
    echo "No repro results recorded."
    return 0
  fi
  echo ""
  echo "=== Test Summary ==="
  printf '%-14s %-22s %-7s %s
' "Profile" "Repro" "Status" "Reason"
  printf '%-14s %-22s %-7s %s
' "-------" "-----" "------" "------"
  local entry profile repro status reason
  for entry in "${RESULTS[@]}"; do
    IFS=$'	' read -r profile repro status reason <<< "${entry}"
    printf '%-14s %-22s %-7s %s
' "${profile}" "${repro}" "${status}" "${reason}"
  done
}

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
    --lib-order)
      LIB_ORDER="${2:-}"
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

module_available() {
  local name="$1"
  local output=""
  output="$(module -t avail "${name}" 2>/dev/null || true)"
  if command -v rg >/dev/null 2>&1; then
    rg -q "^${name}(/|$)" <<< "${output}"
  else
    echo "${output}" | grep -Eq "^${name}(/|$)"
  fi
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
  # Restore CPE defaults after module reset to avoid stale modulepath state.
  source /opt/cray/pe/cpe/25.09/restore_lmod_system_defaults.sh
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

add_pkgconfig_shims() {
  local shim_script="${ROOT_DIR}/afar_modules/scripts/generate_pkgconfig_shims.sh"
  if [[ ! -x "${shim_script}" ]]; then
    return 0
  fi
  local shim_dir
  shim_dir="$(${shim_script})" || return 0
  [[ -n "${shim_dir}" ]] || return 0
  export AFAR_PKGCONFIG_SHIM_DIR="${shim_dir}"
  case ":${PKG_CONFIG_PATH:-}:" in
    *":${shim_dir}:"*) return 0 ;;
  esac
  if [[ -n "${PKG_CONFIG_PATH:-}" ]]; then
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${shim_dir}"
  else
    export PKG_CONFIG_PATH="${shim_dir}"
  fi
}

run_repro() {
  local profile="$1"
  local repro_dir="$2"
  local repro_name
  repro_name="$(basename "${repro_dir}")"

  if [[ ! -x "${repro_dir}/build.sh" ]]; then
    echo "SKIP: ${repro_name} (missing build.sh)" >&2
    record_result "${profile}" "${repro_name}" "SKIP" "missing build.sh"
    return 0
  fi

  echo "==> ${repro_name}"
  local tmp_out
  tmp_out="$(mktemp)"
  local status="PASS"
  local reason=""

  if (cd "${repro_dir}" &&     AFAR_TEST_LABEL="${profile}"     AFAR_TEST_PROFILE="${profile}"     AFAR_TEST_OUT_DIR="${AFAR_TEST_OUT_DIR:-build}"     ./build.sh >"${tmp_out}" 2>&1); then
    local skip_line=""
    skip_line="$(grep -m1 '^SKIP:' "${tmp_out}" || true)"
    if [[ -n "${skip_line}" ]]; then
      status="SKIP"
      reason="${skip_line#SKIP: }"
    fi
  else
    status="FAIL"
    reason="$(grep -m1 -E 'ld.lld:|error:|ERROR:|fatal:' "${tmp_out}" || true)"
    if [[ -z "${reason}" ]]; then
      reason="exit code $?"
    fi
  fi

  cat "${tmp_out}"
  rm -f "${tmp_out}"

  record_result "${profile}" "${repro_name}" "${status}" "${reason}"

  if [[ "${status}" == "FAIL" ]]; then
    return 1
  fi
  return 0
}

run_profile_once() {
  local base_profile="$1"
  local profile_label="$2"
  local order="$3"
  shift 3
  local modules=("$@")

  local log_dir="${AFAR_TEST_LOG_DIR:-${ROOT_DIR}/logs}"
  mkdir -p "${log_dir}"
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local log_file="${log_dir}/${timestamp}-${profile_label}.log"

  {
    echo "=== Profile: ${profile_label}"
    echo "=== Module Order: ${order}"
    echo "=== Modules: ${modules[*]}"
    if ! module_load_all "${modules[@]}"; then
      echo "SKIP: profile ${profile_label} (module load failure)"
      record_result "${profile_label}" "(module-load)" "FAIL" "module load failure"
      return 1
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

    add_pkgconfig_shims

    if [[ "${base_profile}" == "libsci-acc" ]]; then
      local skip_reason="libsci-acc profile disabled (libsci_acc link not validated)."
      echo "SKIP: ${skip_reason}"
      local repro_dir
      for repro_dir in "${ROOT_DIR}/repro/"*; do
        [[ -d "${repro_dir}" ]] || continue
        record_result "${profile_label}" "$(basename "${repro_dir}")" "SKIP" "${skip_reason}"
      done
      return 0
    fi

    local repro_dir
    for repro_dir in "${ROOT_DIR}/repro/"*; do
      [[ -d "${repro_dir}" ]] || continue
      if ! run_repro "${profile_label}" "${repro_dir}"; then
        echo "FAIL: ${profile_label} -> $(basename "${repro_dir}")"
        if [[ "${KEEP_GOING}" != "true" ]]; then
          return 1
        fi
      fi
    done
  } > >(tee "${log_file}") 2>&1
}

run_profile() {
  local profile="$1"
  local base_modules=("${CPE_MODULE}" "${PRGENV_MODULE}" "${MPICH_MODULE}"     "${CPU_TARGET_DEFAULT}" "${GPU_TARGET_DEFAULT}")
  local lib_module=""
  case "${profile}" in
    base)
      lib_module=""
      ;;
    libsci)
      lib_module="${LIBSCI_MODULE_DEFAULT}"
      ;;
    libsci-acc)
      lib_module="${LIBSCI_ACC_MODULE_DEFAULT}"
      ;;
    hdf5)
      lib_module="${HDF5_MODULE_DEFAULT}"
      ;;
    hdf5-serial)
      lib_module="${HDF5_SERIAL_MODULE_DEFAULT}"
      ;;
    fftw)
      lib_module="${FFTW_MODULE_DEFAULT}"
      ;;
    dsmml)
      lib_module="${DSMML_MODULE_DEFAULT}"
      ;;
    netcdf)
      lib_module="${PAR_NETCDF_MODULE_DEFAULT}"
      ;;
    *)
      echo "Unknown profile: ${profile}" >&2
      return 1
      ;;
  esac

  local orders=()
  if [[ -z "${lib_module}" ]]; then
    orders=("before")
  else
    case "${LIB_ORDER}" in
      before)
        orders=("before")
        ;;
      after)
        orders=("after")
        ;;
      both|"")
        orders=("before" "after")
        ;;
      *)
        echo "Unknown library order: ${LIB_ORDER}" >&2
        return 1
        ;;
    esac
  fi

  local order
  local failures=0
  for order in "${orders[@]}"; do
    local profile_label="${profile}"
    if [[ -n "${lib_module}" && "${order}" == "after" ]]; then
      profile_label="${profile}-after"
    fi
    local modules=()
    if [[ -z "${lib_module}" ]]; then
      modules=("${base_modules[@]}" "${AFAR_MODULE}")
    elif [[ "${order}" == "before" ]]; then
      modules=("${base_modules[@]}" "${lib_module}" "${AFAR_MODULE}")
    else
      modules=("${base_modules[@]}" "${AFAR_MODULE}" "${lib_module}")
    fi

    if ! run_profile_once "${profile}" "${profile_label}" "${order}" "${modules[@]}"; then
      failures=$((failures + 1))
      if [[ "${KEEP_GOING}" != "true" ]]; then
        return 1
      fi
    fi
  done

  if [[ "${failures}" -gt 0 ]]; then
    return 1
  fi
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
  print_summary
  exit 1
fi

echo "AFAR test run completed successfully."
print_summary
