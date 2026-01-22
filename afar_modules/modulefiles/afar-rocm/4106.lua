-- AFAR ROCm toolkit module
local MOD_LEVEL = "4106"
local AFAR_DROP_DIR = "rocm-afar-4106"
local DROP_VERSION = "4106"
local BUILD_ID = ""
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
