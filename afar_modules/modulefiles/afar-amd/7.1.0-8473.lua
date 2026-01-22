-- AFAR AMD compiler module
family("compiler")
conflict("amd-mixed")

local MOD_LEVEL = "7.1.0-8473"
local AFAR_DROP_DIR = "rocm-afar-8473-drop-7.1.0"
local DROP_VERSION = "7.1.0"
local BUILD_ID = "8473"
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
  return "/autofs/nccs-svm1_sw/crusher/ums/compilers/afar"
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
  llvm_fallback = "/opt/rocm-7.0.2/llvm/lib"
end
if user_llvm_override and user_llvm_override ~= "" then
  if "/opt/rocm-7.0.2/llvm/lib" ~= "" and user_llvm_override ~= "/opt/rocm-7.0.2/llvm/lib" then
    remove_path("LD_LIBRARY_PATH", "/opt/rocm-7.0.2/llvm/lib")
  end
  if "/opt/rocm-7.0.2/lib/llvm/lib" ~= "" and user_llvm_override ~= "/opt/rocm-7.0.2/lib/llvm/lib" then
    remove_path("LD_LIBRARY_PATH", "/opt/rocm-7.0.2/lib/llvm/lib")
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
