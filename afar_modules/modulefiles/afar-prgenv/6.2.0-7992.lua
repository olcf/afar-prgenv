-- AFAR meta module: compiler + ROCm
local MOD_LEVEL = "6.2.0-7992"
local AFAR_DROP_DIR = "rocm-afar-7992-drop-6.2.0"
local DROP_VERSION = "6.2.0"
local BUILD_ID = "7992"
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

help([[
AFAR compiler + ROCm drop ]] .. MOD_LEVEL .. [[.

Recommended usage:
  module load PrgEnv-amd
  module load afar-prgenv/]] .. MOD_LEVEL .. [[
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
      default_llvm = "/opt/rocm-7.0.2/llvm/lib"
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
