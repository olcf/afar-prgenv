#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"

MODULEFILES_DIR_DEFAULT="${ROOT_DIR}/modulefiles"
VERSIONS_FILE_DEFAULT="${CONFIG_DIR}/afar-versions.txt"
PKGCONFIG_DIR_DEFAULT="${ROOT_DIR}/pkgconfig"
META_MODULE_DIR_DEFAULT="afar-prgenv"
AFAR_ROOT_FILE="${CONFIG_DIR}/afar-root.lua"
AFAR_ROOT_DEFAULT="/autofs/nccs-svm1_sw/crusher/ums/compilers/afar"
CRAY_MPICH_DIR_FILE="${CONFIG_DIR}/cray-mpich-dir.txt"
AMD_VERSION_FILE="/opt/cray/pe/lmod/modulefiles/core/amd/.version"

usage() {
  cat <<'EOF'
Usage: generate_afar_modules.sh [options]

Options:
  --root <path>          Set AFAR root (also updates config/afar-root.lua)
  --output <dir>         Output modulefiles root (default: modulefiles/)
  --pkgconfig-dir <dir>  Output pkg-config dir (default: sibling of modulefiles/)
  --cray-mpich-dir <dir> Set Cray MPICH dir (also updates config/cray-mpich-dir.txt)
  --versions <file>      Versions mapping file (default: config/afar-versions.txt)
  --scan                 Scan AFAR root for rocm-afar* directories
  --write-versions       Write scanned versions to the versions file
  -h, --help             Show this help
EOF
}

ROOT_OVERRIDE="false"
AFAR_ROOT="${AFAR_ROOT:-}"
OUTPUT_DIR="${MODULEFILES_DIR_DEFAULT}"
VERSIONS_FILE="${VERSIONS_FILE_DEFAULT}"
PKGCONFIG_DIR="${PKGCONFIG_DIR_DEFAULT}"
OUTPUT_DIR_OVERRIDE="false"
PKGCONFIG_DIR_OVERRIDE="false"
CRAY_MPICH_DIR_OVERRIDE="false"
CRAY_MPICH_DIR_VALUE=""
META_MODULE_DIR="${AFAR_META_MODULE_DIR:-${META_MODULE_DIR_DEFAULT}}"
SCAN="false"
WRITE_VERSIONS="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      AFAR_ROOT="${2:-}"
      ROOT_OVERRIDE="true"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:-}"
      OUTPUT_DIR_OVERRIDE="true"
      shift 2
      ;;
    --pkgconfig-dir)
      PKGCONFIG_DIR="${2:-}"
      PKGCONFIG_DIR_OVERRIDE="true"
      shift 2
      ;;
    --cray-mpich-dir)
      CRAY_MPICH_DIR_VALUE="${2:-}"
      CRAY_MPICH_DIR_OVERRIDE="true"
      shift 2
      ;;
    --versions)
      VERSIONS_FILE="${2:-}"
      shift 2
      ;;
    --scan)
      SCAN="true"
      shift
      ;;
    --write-versions)
      WRITE_VERSIONS="true"
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

read_root_from_config() {
  if [[ -f "${AFAR_ROOT_FILE}" ]]; then
    sed -n 's/^return[[:space:]]*"\(.*\)".*/\1/p' "${AFAR_ROOT_FILE}" | head -n 1
  fi
}

read_cray_mpich_dir_from_config() {
  if [[ -f "${CRAY_MPICH_DIR_FILE}" ]]; then
    sed -n 's/[[:space:]]*$//p' "${CRAY_MPICH_DIR_FILE}" | head -n 1
  fi
}

has_llvm_runtime_libs() {
  local dir="$1"
  [[ -n "${dir}" ]] || return 1
  [[ -f "${dir}/libpgmath.so" ]] || return 1
  [[ -f "${dir}/libflang.so" ]] || return 1
  [[ -f "${dir}/libflangrti.so" ]] || return 1
  [[ -f "${dir}/libompstub.so" ]] || return 1
}

detect_latest_rocm_pgmath_libdir() {
  local candidates=()
  local rocm_dir=""
  shopt -s nullglob
  for rocm_dir in /opt/rocm-[0-9]*; do
    if has_llvm_runtime_libs "${rocm_dir}/llvm/lib"; then
      candidates+=("${rocm_dir}/llvm/lib")
    elif has_llvm_runtime_libs "${rocm_dir}/lib/llvm/lib"; then
      candidates+=("${rocm_dir}/lib/llvm/lib")
    fi
  done
  shopt -u nullglob

  if [[ ${#candidates[@]} -eq 0 ]]; then
    return 1
  fi
  printf '%s\n' "${candidates[@]}" | sort -V | tail -n 1
}

detect_system_pgmath_libdir() {
  local detected=""
  detected="$(detect_latest_rocm_pgmath_libdir || true)"
  if [[ -n "${detected}" ]]; then
    printf '%s\n' "${detected}"
    return 0
  fi
  local version=""
  if [[ -f "${AMD_VERSION_FILE}" ]]; then
    version="$(sed -n 's/.*ModulesVersion[[:space:]]*"\(.*\)".*/\1/p' "${AMD_VERSION_FILE}" | head -n 1)"
  fi
  if [[ -z "${version}" ]]; then
    return 1
  fi
  local dir="/opt/rocm-${version}/llvm/lib"
  if [[ -f "${dir}/libpgmath.so" ]]; then
    printf '%s\n' "${dir}"
    return 0
  fi
  return 1
}

write_root_config() {
  local root="$1"
  cat > "${AFAR_ROOT_FILE}" <<EOF
-- Default AFAR install root used by modulefiles.
-- Override at runtime with AFAR_ROOT.
return "${root}"
EOF
}

write_cray_mpich_dir_config() {
  local dir="$1"
  printf '%s\n' "${dir}" > "${CRAY_MPICH_DIR_FILE}"
}

if [[ -z "${AFAR_ROOT}" ]]; then
  AFAR_ROOT="$(read_root_from_config || true)"
fi
if [[ -z "${AFAR_ROOT}" ]]; then
  AFAR_ROOT="${AFAR_ROOT_DEFAULT}"
fi

SYSTEM_PGMATH_LIBDIR_DEFAULT="$(detect_system_pgmath_libdir || true)"
SYSTEM_PGMATH_LIBDIR_DEFAULT_ALT=""
if [[ -n "${SYSTEM_PGMATH_LIBDIR_DEFAULT}" ]]; then
  SYSTEM_PGMATH_LIBDIR_DEFAULT_ALT="${SYSTEM_PGMATH_LIBDIR_DEFAULT/\/llvm\/lib/\/lib\/llvm\/lib}"
  if [[ "${SYSTEM_PGMATH_LIBDIR_DEFAULT_ALT}" == "${SYSTEM_PGMATH_LIBDIR_DEFAULT}" ]]; then
    SYSTEM_PGMATH_LIBDIR_DEFAULT_ALT=""
  fi
fi

if [[ "${CRAY_MPICH_DIR_OVERRIDE}" != "true" ]]; then
  CRAY_MPICH_DIR_VALUE="$(read_cray_mpich_dir_from_config || true)"
fi
if [[ -z "${CRAY_MPICH_DIR_VALUE}" ]]; then
  CRAY_MPICH_DIR_VALUE="${CRAY_MPICH_DIR:-}"
fi
if [[ -z "${CRAY_MPICH_DIR_VALUE}" && -n "${MPICH_DIR:-}" ]]; then
  CRAY_MPICH_DIR_VALUE="${MPICH_DIR}"
fi

if [[ "${PKGCONFIG_DIR_OVERRIDE}" == "false" && "${OUTPUT_DIR_OVERRIDE}" == "true" ]]; then
  PKGCONFIG_DIR="$(dirname "${OUTPUT_DIR}")/pkgconfig"
fi

if [[ "${ROOT_OVERRIDE}" == "true" ]]; then
  write_root_config "${AFAR_ROOT}"
fi
if [[ "${CRAY_MPICH_DIR_OVERRIDE}" == "true" ]]; then
  write_cray_mpich_dir_config "${CRAY_MPICH_DIR_VALUE}"
fi

if [[ ! -d "${AFAR_ROOT}" ]]; then
  echo "AFAR root not found: ${AFAR_ROOT}" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}/${META_MODULE_DIR}" "${OUTPUT_DIR}/afar-amd" "${OUTPUT_DIR}/afar-rocm"
mkdir -p "${PKGCONFIG_DIR}"

scan_versions() {
  local root="$1"
  local entries=()
  local base
  for path in "${root}"/rocm-afar*; do
    [[ -d "${path}" ]] || continue
    base="$(basename "${path}")"
    if [[ "${base}" =~ ^rocm-afar-([0-9]+)-drop-(.+)$ ]]; then
      local build="${BASH_REMATCH[1]}"
      local drop="${BASH_REMATCH[2]}"
      entries+=("${drop}-${build}|${base}")
    elif [[ "${base}" =~ ^rocm-afar-([0-9]+)$ ]]; then
      local build="${BASH_REMATCH[1]}"
      entries+=("${build}|${base}")
    elif [[ "${base}" =~ ^rocm-afar([0-9]+)-([0-9]+)$ ]]; then
      local drop="${BASH_REMATCH[1]}"
      local build="${BASH_REMATCH[2]}"
      entries+=("${drop}-${build}|${base}")
    fi
  done

  printf '%s\n' "${entries[@]}" | sort -u -V
}

read_versions_file() {
  local file="$1"
  local entries=()
  while IFS='|' read -r version dir; do
    version="${version%%#*}"
    dir="${dir%%#*}"
    version="$(echo "${version}" | xargs)"
    dir="$(echo "${dir}" | xargs)"
    [[ -z "${version}" ]] && continue
    [[ -z "${dir}" ]] && continue
    entries+=("${version}|${dir}")
  done < "${file}"
  printf '%s\n' "${entries[@]}"
}

mpich_major_version() {
  local ver="$1"
  local major="${ver%%.*}"
  if [[ -z "${ver}" || -z "${major}" ]]; then
    return 1
  fi
  if [[ ! "${major}" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  printf '%s\n' "${major}"
}

prefer_afar_mpich_flavor() {
  local ver="$1"
  local major
  major="$(mpich_major_version "${ver}" || true)"
  if [[ -z "${major}" ]]; then
    echo ""
    return 0
  fi
  if (( major >= 9 )); then
    echo "mpich4.3.1"
  else
    echo "mpich3.4a2"
  fi
}

mpich_moddir_for_flavor() {
  local prefix="$1"
  local flavor="$2"
  if [[ "${flavor}" == "mpich4.3.1" ]]; then
    if [[ -d "${prefix}/include/mpich4.3.1" ]]; then
      echo "${prefix}/include/mpich4.3.1"
      return 0
    fi
  elif [[ "${flavor}" == "mpich3.4a2" ]]; then
    if [[ -d "${prefix}/include/mpich3.4a2" ]]; then
      echo "${prefix}/include/mpich3.4a2"
      return 0
    fi
  fi
  echo ""
}

detect_afar_mpich_moddir() {
  local prefix="$1"
  local cray_mpich_ver="${2:-}"
  local prefer=""
  prefer="$(prefer_afar_mpich_flavor "${cray_mpich_ver}")"

  if [[ "${prefer}" == "mpich4.3.1" ]]; then
    local dir
    dir="$(mpich_moddir_for_flavor "${prefix}" "mpich4.3.1")"
    if [[ -n "${dir}" ]]; then
      echo "${dir}"
      return 0
    fi
    dir="$(mpich_moddir_for_flavor "${prefix}" "mpich3.4a2")"
    if [[ -n "${dir}" ]]; then
      echo "${dir}"
      return 0
    fi
  elif [[ "${prefer}" == "mpich3.4a2" ]]; then
    local dir
    dir="$(mpich_moddir_for_flavor "${prefix}" "mpich3.4a2")"
    if [[ -n "${dir}" ]]; then
      echo "${dir}"
      return 0
    fi
    dir="$(mpich_moddir_for_flavor "${prefix}" "mpich4.3.1")"
    if [[ -n "${dir}" ]]; then
      echo "${dir}"
      return 0
    fi
  else
    local dir
    dir="$(mpich_moddir_for_flavor "${prefix}" "mpich4.3.1")"
    if [[ -n "${dir}" ]]; then
      echo "${dir}"
      return 0
    fi
    dir="$(mpich_moddir_for_flavor "${prefix}" "mpich3.4a2")"
    if [[ -n "${dir}" ]]; then
      echo "${dir}"
      return 0
    fi
  fi
  echo ""
}

cray_mpich_version_from_dir() {
  local dir="$1"
  if [[ -z "${dir}" ]]; then
    echo "unknown"
    return 0
  fi
  echo "${dir}" | awk -F/ '{print $(NF-3)}'
}

write_pkgconfig_file() {
  local version="$1"
  local dir="$2"
  local out="${PKGCONFIG_DIR}/rocm-afar-${version}.pc"
  local out_ver_dir="${PKGCONFIG_DIR}/${version}"
  local out_ver="${out_ver_dir}/rocm-afar-${version}.pc"
  local prefix="${AFAR_ROOT}/${dir}"

  mkdir -p "${out_ver_dir}"
  cat > "${out}" <<EOF
# This pc file was produced with generate_afar_modules.sh

Name: rocm-afar-${version}
Version: ${version}
Description: ROCm Toolkit (AFAR)

rocm_prefix=${prefix}
includedir=\${rocm_prefix}/include
libdir=\${rocm_prefix}/lib

profiler_includedir=\${rocm_prefix}/include/rocprofiler
profiler_libdir=\${rocm_prefix}/lib/rocprofiler

tracer_includedir=\${rocm_prefix}/include/roctracer
tracer_libdir=\${rocm_prefix}/lib/roctracer

Cflags: -I\${includedir} -I\${profiler_includedir} -I\${tracer_includedir} -D__HIP_PLATFORM_AMD__
Libs: -L\${libdir} -L\${profiler_libdir} -L\${tracer_libdir} -lamdhip64
EOF
  cp -f "${out}" "${out_ver}"
}

write_mpichf90_pkgconfig_file() {
  local include_dir="$1"
  local cray_mpich_dir="$2"
  local cray_mpich_ver="$3"
  local out="$4"

  mkdir -p "$(dirname "${out}")"
  cat > "${out}" <<EOF
# This pc file was produced with generate_afar_modules.sh

mpifclibname=mpifort_amd
cray_prefix=${cray_mpich_dir}
version=${cray_mpich_ver}
prefix=\${cray_prefix}
libdir=\${prefix}/lib
includedir=${include_dir}

Name: mpichf90
Description: Cray MPI Fortran library (AFAR modules)
Version: ${cray_mpich_ver}

Requires: mpich
Libs: -L\${libdir} -l\${mpifclibname}
Cflags: -I\${includedir}
EOF
}

write_mpichf90_pkgconfig() {
  local version="$1"
  local dir="$2"
  local prefix="${AFAR_ROOT}/${dir}"
  local mpich_moddir=""
  local mpich3_moddir=""
  local mpich4_moddir=""
  local cray_mpich_dir="${CRAY_MPICH_DIR_VALUE}"
  local cray_mpich_ver
  local out_ver_dir="${PKGCONFIG_DIR}/${version}"
  local out="${out_ver_dir}/mpichf90.pc"

  if [[ -z "${cray_mpich_dir}" ]]; then
    echo "WARNING: CRAY_MPICH_DIR not set; skipping mpichf90 override for ${version}" >&2
    return 0
  fi
  if [[ ! -d "${cray_mpich_dir}" ]]; then
    echo "WARNING: CRAY_MPICH_DIR does not exist: ${cray_mpich_dir}" >&2
    return 0
  fi

  cray_mpich_ver="$(cray_mpich_version_from_dir "${cray_mpich_dir}")"
  mpich3_moddir="$(mpich_moddir_for_flavor "${prefix}" "mpich3.4a2")"
  mpich4_moddir="$(mpich_moddir_for_flavor "${prefix}" "mpich4.3.1")"

  if [[ -n "${mpich3_moddir}" ]]; then
    write_mpichf90_pkgconfig_file "${mpich3_moddir}" "${cray_mpich_dir}" "${cray_mpich_ver}" \
      "${out_ver_dir}/mpich3.4a2/mpichf90.pc"
  fi
  if [[ -n "${mpich4_moddir}" ]]; then
    write_mpichf90_pkgconfig_file "${mpich4_moddir}" "${cray_mpich_dir}" "${cray_mpich_ver}" \
      "${out_ver_dir}/mpich4.3.1/mpichf90.pc"
  fi

  mpich_moddir="$(detect_afar_mpich_moddir "${prefix}" "${cray_mpich_ver}")"
  if [[ -n "${mpich_moddir}" ]]; then
    write_mpichf90_pkgconfig_file "${mpich_moddir}" "${cray_mpich_dir}" "${cray_mpich_ver}" "${out}"
    return 0
  fi
  echo "WARNING: no AFAR MPICH module dir found under ${prefix}/include" >&2
}

write_afar_module() {
  local version="$1"
  local dir="$2"
  local drop_version="$3"
  local build_id="$4"
  local out="${OUTPUT_DIR}/${META_MODULE_DIR}/${version}.lua"

  cat > "${out}" <<EOF
-- AFAR meta module: compiler + ROCm
local MOD_LEVEL = "${version}"
local AFAR_DROP_DIR = "${dir}"
local DROP_VERSION = "${drop_version}"
local BUILD_ID = "${build_id}"
local mod_dir = myFileName():gsub("/[^/]*$", "")

local function get_default_root()
  local cfg = pathJoin(mod_dir, "..", "..", "config", "afar-root.lua")
  local ok, chunk = pcall(loadfile, cfg)
  if ok and chunk then
    local val = chunk()
    if type(val) == "string" and val ~= "" then
      return val
    end
  end
  return "${AFAR_ROOT_DEFAULT}"
end

local AFAR_ROOT = os.getenv("AFAR_ROOT") or get_default_root()
local AFAR_PREFIX = pathJoin(AFAR_ROOT, AFAR_DROP_DIR)

help([[
AFAR compiler + ROCm drop ]] .. MOD_LEVEL .. [[.

Recommended usage:
  module load PrgEnv-amd
  module load ${META_MODULE_DIR}/]] .. MOD_LEVEL .. [[
]])

whatis("Loads AFAR compiler + ROCm drop " .. MOD_LEVEL)

setenv("AFAR_ROOT", AFAR_ROOT)
setenv("AFAR_PREFIX", AFAR_PREFIX)
setenv("AFAR_VERSION", MOD_LEVEL)
setenv("AFAR_DROP_VERSION", DROP_VERSION)
setenv("AFAR_BUILD_ID", BUILD_ID)

local function has_llvm_runtime_libs(dir)
  if dir == nil or dir == "" then
    return false
  end
  return isFile(pathJoin(dir, "libpgmath.so")) and
    isFile(pathJoin(dir, "libflang.so")) and
    isFile(pathJoin(dir, "libflangrti.so")) and
    isFile(pathJoin(dir, "libompstub.so"))
end

local user_llvm_override = os.getenv("AFAR_LLVM_LIB_DIR") or os.getenv("AFAR_PGMATH_DIR")
if user_llvm_override == nil or user_llvm_override == "" then
  local default_llvm = pathJoin(AFAR_PREFIX, "llvm", "lib")
  if not has_llvm_runtime_libs(default_llvm) then
    local alt = pathJoin(AFAR_PREFIX, "lib", "llvm", "lib")
    if has_llvm_runtime_libs(alt) then
      default_llvm = alt
    else
      default_llvm = "${SYSTEM_PGMATH_LIBDIR_DEFAULT}"
    end
  end
  if default_llvm ~= "" and has_llvm_runtime_libs(default_llvm) then
    setenv("AFAR_LLVM_LIB_DIR", default_llvm)
    setenv("AFAR_LLVM_LIB_DIR_SOURCE", "afar-prgenv")
  end
end

if isloaded("rocm") then
  unload("rocm")
end

if isloaded("amd") then
  unload("amd")
end

load("afar-rocm/" .. MOD_LEVEL)
load("afar-amd/" .. MOD_LEVEL)
EOF
}

write_afar_amd_module() {
  local version="$1"
  local dir="$2"
  local drop_version="$3"
  local build_id="$4"
  local out="${OUTPUT_DIR}/afar-amd/${version}.lua"

  cat > "${out}" <<EOF
-- AFAR AMD compiler module
family("compiler")
conflict("amd-mixed")

local MOD_LEVEL = "${version}"
local AFAR_DROP_DIR = "${dir}"
local DROP_VERSION = "${drop_version}"
local BUILD_ID = "${build_id}"
local mod_dir = myFileName():gsub("/[^/]*$", "")

local function get_default_root()
  local cfg = pathJoin(mod_dir, "..", "..", "config", "afar-root.lua")
  local ok, chunk = pcall(loadfile, cfg)
  if ok and chunk then
    local val = chunk()
    if type(val) == "string" and val ~= "" then
      return val
    end
  end
  return "${AFAR_ROOT_DEFAULT}"
end

local AFAR_ROOT = os.getenv("AFAR_ROOT") or get_default_root()
local AFAR_PREFIX = pathJoin(AFAR_ROOT, AFAR_DROP_DIR)
local PKGCONFIG_DIR = pathJoin(mod_dir, "..", "..", "pkgconfig")
local PKGCONFIG_VER_DIR = pathJoin(PKGCONFIG_DIR, MOD_LEVEL)

if isDir(PKGCONFIG_VER_DIR) then
  prepend_path("PE_AMD_FIXED_PKGCONFIG_PATH", PKGCONFIG_VER_DIR)
end

local function mpich_major_version(ver)
  if ver == nil or ver == "" then
    return nil
  end
  local major = ver:match("^(%d+)")
  if major == nil then
    return nil
  end
  return tonumber(major)
end

local function select_mpich_moddir()
  local has_mpich4 = isDir(pathJoin(AFAR_PREFIX, "include", "mpich4.3.1"))
  local has_mpich3 = isDir(pathJoin(AFAR_PREFIX, "include", "mpich3.4a2"))
  local major = mpich_major_version(os.getenv("CRAY_MPICH_VERSION") or "")

  if major ~= nil then
    if major >= 9 then
      if has_mpich4 then
        return pathJoin(AFAR_PREFIX, "include", "mpich4.3.1"), "mpich4.3.1"
      end
      if has_mpich3 then
        return pathJoin(AFAR_PREFIX, "include", "mpich3.4a2"), "mpich3.4a2"
      end
    else
      if has_mpich3 then
        return pathJoin(AFAR_PREFIX, "include", "mpich3.4a2"), "mpich3.4a2"
      end
      if has_mpich4 then
        return pathJoin(AFAR_PREFIX, "include", "mpich4.3.1"), "mpich4.3.1"
      end
    end
  end

  if has_mpich4 then
    return pathJoin(AFAR_PREFIX, "include", "mpich4.3.1"), "mpich4.3.1"
  end
  if has_mpich3 then
    return pathJoin(AFAR_PREFIX, "include", "mpich3.4a2"), "mpich3.4a2"
  end
  return "", ""
end

local mpich_moddir, mpich_flavor = select_mpich_moddir()
if mpich_moddir ~= "" then
  setenv("AFAR_MPICH_MODDIR", mpich_moddir)
  setenv("AFAR_MPICH_FLAVOR", mpich_flavor)
end

local function select_mpich_pkgconfig_dir(prefer_flavor)
  local has_pkg4 = isDir(pathJoin(PKGCONFIG_VER_DIR, "mpich4.3.1"))
  local has_pkg3 = isDir(pathJoin(PKGCONFIG_VER_DIR, "mpich3.4a2"))
  local major = mpich_major_version(os.getenv("CRAY_MPICH_VERSION") or "")

  if prefer_flavor ~= nil and prefer_flavor ~= "" then
    local preferred = pathJoin(PKGCONFIG_VER_DIR, prefer_flavor)
    if isDir(preferred) then
      return preferred
    end
  end

  if major ~= nil then
    if major >= 9 then
      if has_pkg4 then
        return pathJoin(PKGCONFIG_VER_DIR, "mpich4.3.1")
      end
      if has_pkg3 then
        return pathJoin(PKGCONFIG_VER_DIR, "mpich3.4a2")
      end
    else
      if has_pkg3 then
        return pathJoin(PKGCONFIG_VER_DIR, "mpich3.4a2")
      end
      if has_pkg4 then
        return pathJoin(PKGCONFIG_VER_DIR, "mpich4.3.1")
      end
    end
  end

  if has_pkg4 then
    return pathJoin(PKGCONFIG_VER_DIR, "mpich4.3.1")
  end
  if has_pkg3 then
    return pathJoin(PKGCONFIG_VER_DIR, "mpich3.4a2")
  end
  return ""
end

local mpich_pkg_dir = select_mpich_pkgconfig_dir(mpich_flavor)
if mpich_pkg_dir ~= "" then
  prepend_path("PE_AMD_FIXED_PKGCONFIG_PATH", mpich_pkg_dir)
end

local function split_path_list(val)
  local items = {}
  if val == nil or val == "" then
    return items
  end
  for entry in string.gmatch(val, "([^:]+)") do
    if entry ~= "" then
      table.insert(items, entry)
    end
  end
  return items
end

local fixed_pkgconfig = os.getenv("PE_AMD_FIXED_PKGCONFIG_PATH") or ""
local fixed_items = split_path_list(fixed_pkgconfig)
for i = #fixed_items, 1, -1 do
  prepend_path("PKG_CONFIG_PATH", fixed_items[i])
end

local rocm_version = os.getenv("CRAY_ROCM_VERSION") or ""
if rocm_version ~= "" and rocm_version ~= MOD_LEVEL then
  LmodError("afar-amd/" .. MOD_LEVEL .. " cannot be loaded while rocm/" .. rocm_version .. " is active.")
end

local accel_target = os.getenv("CRAY_ACCEL_TARGET") or ""
local user_offload_arch = os.getenv("AFAR_FTN_OFFLOAD_ARCH") or ""
local afar_offload_arch = user_offload_arch
if afar_offload_arch == "" and accel_target:match("^amd_gfx") then
  afar_offload_arch = accel_target:gsub("^amd_gfx", "gfx")
end
if accel_target ~= "" and accel_target ~= "host" then
  local libsci_acc_prefix = os.getenv("CRAY_LIBSCI_ACC_PREFIX_DIR") or ""
  local pkg_products = os.getenv("PE_PKGCONFIG_PRODUCTS") or ""
  local pkg_libs = os.getenv("PE_PKGCONFIG_LIBS") or ""
  local has_libsci_acc = libsci_acc_prefix ~= "" or pkg_products:find("PE_LIBSCI_ACC") or pkg_libs:find("libsci_acc")
  if has_libsci_acc then
  local libsci_acc_target = os.getenv("PE_LIBSCI_ACC_TARGET") or ""
  if libsci_acc_target == "" and afar_offload_arch ~= "" then
    setenv("PE_LIBSCI_ACC_TARGET", afar_offload_arch)
  end
  local libsci_acc_prgenv = os.getenv("PE_LIBSCI_ACC_PRGENV") or ""
  if libsci_acc_prgenv == "" then
    local pe_env = os.getenv("PE_ENV") or ""
    if pe_env == "" then
      pe_env = "amd"
    else
      pe_env = string.lower(pe_env)
    end
    setenv("PE_LIBSCI_ACC_PRGENV", pe_env)
  end
  local libsci_acc_pkg_vars = os.getenv("PE_LIBSCI_ACC_PKGCONFIG_VARIABLES") or ""
  if libsci_acc_pkg_vars:find("@accelerator@") and accel_target:match("^amd_gfx") then
    setenv("PE_LIBSCI_ACC_PKGCONFIG_VARIABLES", libsci_acc_pkg_vars:gsub("@accelerator@", accel_target))
  end
  end

  if mode() == "load" then
    local msg = "NOTE: clearing CRAY_ACCEL_TARGET/CRAY_ACCEL_VENDOR because CrayPE offload flags use -Xopenmp-target which AFAR flang does not accept."
    if afar_offload_arch ~= "" then
      msg = msg .. " AFAR will add --offload-arch=" .. afar_offload_arch .. " for ftn/cc/CC when -fopenmp is used."
    else
      msg = msg .. " Use -fopenmp --offload-arch=<gpu>."
    end
    LmodMessage(msg)
  end
  unsetenv("CRAY_ACCEL_TARGET")
  unsetenv("CRAY_ACCEL_VENDOR")
end

help([[
AFAR AMD compiler drop ]] .. MOD_LEVEL .. [[.

Provides amdclang/amdflang toolchain from:
  ]] .. AFAR_PREFIX .. [[
]])

whatis("AFAR AMD compiler drop " .. MOD_LEVEL)

prepend_path("PATH", pathJoin(AFAR_PREFIX, "bin"))
prepend_path("C_INCLUDE_PATH", pathJoin(AFAR_PREFIX, "llvm", "include"))
prepend_path("CPLUS_INCLUDE_PATH", pathJoin(AFAR_PREFIX, "llvm", "include"))
prepend_path("CMAKE_PREFIX_PATH", AFAR_PREFIX)
prepend_path("LD_LIBRARY_PATH", pathJoin(AFAR_PREFIX, "llvm", "lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(AFAR_PREFIX, "lib"))
local wrapper_dir = pathJoin(mod_dir, "..", "..", "bin")
if isDir(wrapper_dir) then
  prepend_path("PATH", wrapper_dir)
end
if mode() == "load" then
  local filter_file = pathJoin(mod_dir, "..", "..", "config", "wrapper-filter.txt")
  if isFile(filter_file) then
    LmodMessage("AFAR wrapper filter file: " .. filter_file)
  else
    LmodMessage("AFAR wrapper filter file not found: " .. filter_file)
  end
end
local craype_dir = os.getenv("CRAYPE_DIR") or ""
if craype_dir ~= "" and isFile(pathJoin(craype_dir, "bin", "ftn")) then
  setenv("AFAR_REAL_FTN", pathJoin(craype_dir, "bin", "ftn"))
end
if craype_dir ~= "" and isFile(pathJoin(craype_dir, "bin", "cc")) then
  setenv("AFAR_REAL_CC", pathJoin(craype_dir, "bin", "cc"))
end
if craype_dir ~= "" and isFile(pathJoin(craype_dir, "bin", "CC")) then
  setenv("AFAR_REAL_CXX", pathJoin(craype_dir, "bin", "CC"))
end
if afar_offload_arch ~= "" and user_offload_arch == "" then
  setenv("AFAR_FTN_OFFLOAD_ARCH", afar_offload_arch)
end

local function has_llvm_lib(libname)
  return isFile(pathJoin(AFAR_PREFIX, "llvm", "lib", libname)) or
    isFile(pathJoin(AFAR_PREFIX, "lib", "llvm", "lib", libname)) or
    isFile(pathJoin(AFAR_PREFIX, "lib", libname))
end

local llvm_runtime_libs = {
  "libpgmath.so",
  "libflang.so",
  "libflangrti.so",
  "libompstub.so",
}

local function needs_llvm_fallback()
  for _, lib in ipairs(llvm_runtime_libs) do
    if not has_llvm_lib(lib) then
      return true
    end
  end
  return false
end

local function has_any_llvm_lib(dir)
  if dir == nil or dir == "" then
    return false
  end
  for _, lib in ipairs(llvm_runtime_libs) do
    if isFile(pathJoin(dir, lib)) then
      return true
    end
  end
  return false
end

local user_llvm_override = os.getenv("AFAR_LLVM_LIB_DIR") or os.getenv("AFAR_PGMATH_DIR")
local llvm_source = os.getenv("AFAR_LLVM_LIB_DIR_SOURCE") or ""
local module_default = ""
if llvm_source == "afar-prgenv" and user_llvm_override ~= nil and user_llvm_override ~= "" then
  module_default = user_llvm_override
  user_llvm_override = ""
end

local llvm_fallback = ""
if user_llvm_override ~= nil and user_llvm_override ~= "" then
  llvm_fallback = user_llvm_override
elseif module_default ~= "" and has_any_llvm_lib(module_default) then
  llvm_fallback = module_default
else
  llvm_fallback = "${SYSTEM_PGMATH_LIBDIR_DEFAULT}"
end
if user_llvm_override and user_llvm_override ~= "" then
  if "${SYSTEM_PGMATH_LIBDIR_DEFAULT}" ~= "" and user_llvm_override ~= "${SYSTEM_PGMATH_LIBDIR_DEFAULT}" then
    remove_path("LD_LIBRARY_PATH", "${SYSTEM_PGMATH_LIBDIR_DEFAULT}")
  end
  if "${SYSTEM_PGMATH_LIBDIR_DEFAULT_ALT}" ~= "" and user_llvm_override ~= "${SYSTEM_PGMATH_LIBDIR_DEFAULT_ALT}" then
    remove_path("LD_LIBRARY_PATH", "${SYSTEM_PGMATH_LIBDIR_DEFAULT_ALT}")
  end
end

if llvm_fallback ~= "" and needs_llvm_fallback() then
  if has_any_llvm_lib(llvm_fallback) then
    append_path("LD_LIBRARY_PATH", llvm_fallback)
  end
end

setenv("CRAY_AMD_COMPILER_PREFIX", AFAR_PREFIX)
setenv("CRAY_AMD_COMPILER_VERSION", MOD_LEVEL)
setenv("AFAR_ROOT", AFAR_ROOT)
setenv("AFAR_PREFIX", AFAR_PREFIX)
setenv("AFAR_VERSION", MOD_LEVEL)
setenv("AFAR_DROP_VERSION", DROP_VERSION)
setenv("AFAR_BUILD_ID", BUILD_ID)

-- Integrate with Cray Lmod hierarchy when available.
setenv("CRAY_LMOD_COMPILER", "amd/4.0")
local LMOD_TEST_PREFIX = os.getenv("LMOD_TEST_PREFIX") or ""
local INSTALL_ROOT = "/opt/cray/pe/"
local MODULE_ROOT = "/opt/cray/pe/lmod/modulefiles"
local AMD_MOD_LIB_PATH = LMOD_TEST_PREFIX .. MODULE_ROOT .. "/compiler/amd/4.0"
local AMD_MIX_MOD_PATH = LMOD_TEST_PREFIX .. MODULE_ROOT .. "/mix_compilers"

prepend_path("MODULEPATH", AMD_MIX_MOD_PATH)
prepend_path("MODULEPATH", AMD_MOD_LIB_PATH)

local script_path = LMOD_TEST_PREFIX .. INSTALL_ROOT .. "lmod_scripts/default/scripts/lmodHierarchy.lua"
local ok, chunk = pcall(loadfile, script_path)
if ok and chunk then
  local lmodHierarchy = chunk()
  lmodHierarchy.handshake_comnet(LMOD_TEST_PREFIX .. INSTALL_ROOT)
  lmodHierarchy.handshake_comcpu(LMOD_TEST_PREFIX .. INSTALL_ROOT)
  lmodHierarchy.handshake_cncm(LMOD_TEST_PREFIX .. INSTALL_ROOT)
  lmodHierarchy.get_user_custom_path("COMPILER", "amd/4.0")
else
  if mode() == "load" then
    LmodMessage("WARNING: unable to load lmodHierarchy.lua; compiler hierarchy hooks not applied.")
  end
end
EOF
}

write_afar_rocm_module() {
  local version="$1"
  local dir="$2"
  local drop_version="$3"
  local build_id="$4"
  local out="${OUTPUT_DIR}/afar-rocm/${version}.lua"

  cat > "${out}" <<EOF
-- AFAR ROCm toolkit module
local MOD_LEVEL = "${version}"
local AFAR_DROP_DIR = "${dir}"
local DROP_VERSION = "${drop_version}"
local BUILD_ID = "${build_id}"
local mod_dir = myFileName():gsub("/[^/]*$", "")

local function get_default_root()
  local cfg = pathJoin(mod_dir, "..", "..", "config", "afar-root.lua")
  local ok, chunk = pcall(loadfile, cfg)
  if ok and chunk then
    local val = chunk()
    if type(val) == "string" and val ~= "" then
      return val
    end
  end
  return "${AFAR_ROOT_DEFAULT}"
end

local AFAR_ROOT = os.getenv("AFAR_ROOT") or get_default_root()
local AFAR_PREFIX = pathJoin(AFAR_ROOT, AFAR_DROP_DIR)
local PKGCONFIG_DIR = pathJoin(mod_dir, "..", "..", "pkgconfig")
local PKGCONFIG_VER_DIR = pathJoin(PKGCONFIG_DIR, MOD_LEVEL)

local amd_version = os.getenv("CRAY_AMD_COMPILER_VERSION") or ""
if amd_version ~= "" and amd_version ~= MOD_LEVEL then
  LmodError("afar-rocm/" .. MOD_LEVEL .. " cannot be loaded while amd/" .. amd_version .. " is active.")
end

help([[
AFAR ROCm toolkit drop ]] .. MOD_LEVEL .. [[.
]])

whatis("AFAR ROCm toolkit drop " .. MOD_LEVEL)

setenv("CRAY_ROCM_DIR", AFAR_PREFIX)
setenv("CRAY_ROCM_PREFIX", AFAR_PREFIX)
setenv("CRAY_ROCM_VERSION", MOD_LEVEL)
setenv("ROCM_PATH", AFAR_PREFIX)
setenv("HIP_LIB_PATH", pathJoin(AFAR_PREFIX, "lib"))

prepend_path("PATH", pathJoin(AFAR_PREFIX, "bin"))
prepend_path("MANPATH", pathJoin(AFAR_PREFIX, "share", "man"))
prepend_path("CMAKE_PREFIX_PATH", pathJoin(AFAR_PREFIX, "lib", "cmake", "hip"))
if isDir(PKGCONFIG_VER_DIR) then
  prepend_path("PKG_CONFIG_PATH", PKGCONFIG_VER_DIR)
end
if isDir(pathJoin(AFAR_PREFIX, "lib", "pkgconfig")) then
  prepend_path("PKG_CONFIG_PATH", pathJoin(AFAR_PREFIX, "lib", "pkgconfig"))
end
if isDir(pathJoin(AFAR_PREFIX, "lib64", "pkgconfig")) then
  prepend_path("PKG_CONFIG_PATH", pathJoin(AFAR_PREFIX, "lib64", "pkgconfig"))
end
prepend_path("PKG_CONFIG_PATH", "/usr/lib64/pkgconfig")
prepend_path("PKG_CONFIG_PATH", PKGCONFIG_DIR)

setenv("CRAY_ROCM_INCLUDE_OPTS", "-I" .. pathJoin(AFAR_PREFIX, "include") ..
  " -I" .. pathJoin(AFAR_PREFIX, "include", "rocprofiler") ..
  " -I" .. pathJoin(AFAR_PREFIX, "include", "roctracer") ..
  " -I" .. pathJoin(AFAR_PREFIX, "include", "hip") ..
  " -D__HIP_PLATFORM_AMD__")

setenv("CRAY_ROCM_POST_LINK_OPTS", " -L" .. pathJoin(AFAR_PREFIX, "lib") ..
  " -L" .. pathJoin(AFAR_PREFIX, "lib", "rocprofiler") ..
  " -L" .. pathJoin(AFAR_PREFIX, "lib", "roctracer") ..
  " -lamdhip64")

local function has_amdhip_soname(major)
  return isFile(pathJoin(AFAR_PREFIX, "lib", "libamdhip64.so." .. major)) or
    isFile(pathJoin(AFAR_PREFIX, "lib64", "libamdhip64.so." .. major))
end

local mpich_pkgconfig_vars = os.getenv("PE_MPICH_PKGCONFIG_VARIABLES") or ""
if mpich_pkgconfig_vars:find("PE_MPICH_GTL_", 1, true) and not has_amdhip_soname("6") then
  local keep = {}
  for item in string.gmatch(mpich_pkgconfig_vars, "([^:]+)") do
    if not item:find("PE_MPICH_GTL_", 1, true) then
      table.insert(keep, item)
    end
  end
  if mode() == "load" then
    LmodMessage("NOTE: disabling Cray MPICH GTL pkg-config vars to avoid ROCm 6 libamdhip64 dependency.")
  end
  if #keep == 0 then
    setenv("PE_MPICH_PKGCONFIG_VARIABLES", "")
  else
    setenv("PE_MPICH_PKGCONFIG_VARIABLES", table.concat(keep, ":"))
  end
  unsetenv("PE_MPICH_GTL_DIR")
  unsetenv("PE_MPICH_GTL_LIBS")
end

prepend_path("LD_LIBRARY_PATH", pathJoin(AFAR_PREFIX, "lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(AFAR_PREFIX, "lib", "rocprofiler"))
prepend_path("LD_LIBRARY_PATH", pathJoin(AFAR_PREFIX, "lib", "roctracer"))

append_path("PE_PRODUCT_LIST", "CRAY_ROCM")
prepend_path("PE_PKGCONFIG_LIBS", "rocm-afar-" .. MOD_LEVEL)

setenv("AFAR_ROOT", AFAR_ROOT)
setenv("AFAR_PREFIX", AFAR_PREFIX)
setenv("AFAR_VERSION", MOD_LEVEL)
setenv("AFAR_DROP_VERSION", DROP_VERSION)
setenv("AFAR_BUILD_ID", BUILD_ID)
EOF
}

entries=()
if [[ "${SCAN}" == "true" ]]; then
  mapfile -t entries < <(scan_versions "${AFAR_ROOT}")
  if [[ "${WRITE_VERSIONS}" == "true" ]]; then
    printf '# module-version|rocm-afar-dir\n' > "${VERSIONS_FILE}"
    printf '%s\n' "${entries[@]}" >> "${VERSIONS_FILE}"
  fi
else
  if [[ ! -f "${VERSIONS_FILE}" ]]; then
    echo "Versions file not found: ${VERSIONS_FILE}" >&2
    exit 1
  fi
  mapfile -t entries < <(read_versions_file "${VERSIONS_FILE}")
fi

for entry in "${entries[@]}"; do
  version="${entry%%|*}"
  dir="${entry#*|}"
  if [[ "${version}" == *-* ]]; then
    drop_version="${version%-*}"
    build_id="${version##*-}"
  else
    drop_version="${version}"
    build_id=""
  fi
  write_afar_module "${version}" "${dir}" "${drop_version}" "${build_id}"
  write_afar_amd_module "${version}" "${dir}" "${drop_version}" "${build_id}"
  write_afar_rocm_module "${version}" "${dir}" "${drop_version}" "${build_id}"
  write_pkgconfig_file "${version}" "${dir}"
  write_mpichf90_pkgconfig "${version}" "${dir}"
done
