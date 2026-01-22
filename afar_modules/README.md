# AFAR Module Tree (Local)

This directory provides a relocatable Lmod module tree for AFAR compiler +
ROCm drops. The compiler and toolkit modules are separate, and a meta module
(`afar-prgenv/<ver>`) loads both. The tree is intended to be copied into a
site module path with only a root path update and regeneration.

## Goals and Scope
- Keep AFAR separate from system `amd`/`rocm` and system `afar` modules.
- Support multiple AFAR drops in parallel.
- Work cleanly with Cray PE wrappers (cc/CC/ftn).
- Provide compiler + ROCm toolkit only (no HDF5/hipfort builds here).

## Directory Layout
```
afar_modules/
  bin/
    ftn                    # wrapper to auto-add --offload-arch for AFAR
    cc                     # wrapper to auto-add --offload-arch for AFAR
    CC                     # wrapper to auto-add --offload-arch for AFAR
  config/
    afar-root.lua           # default AFAR install root
    afar-versions.txt       # mapping of module version -> AFAR drop dir
    cray-mpich-dir.txt      # Cray MPICH dir for mpichf90 pkg-config overrides
  modulefiles/
    afar-prgenv/            # meta modules (loads afar-amd + afar-rocm)
    afar-amd/               # compiler modules
    afar-rocm/              # ROCm toolkit modules
  pkgconfig/
    rocm-afar-<ver>.pc      # generated pkg-config files for wrappers
    <ver>/mpichf90.pc       # default AFAR MPI override (compat)
    <ver>/mpich3.4a2/       # mpichf90.pc for Cray MPICH 8.x
    <ver>/mpich4.3.1/       # mpichf90.pc for Cray MPICH 9.x
  scripts/
    generate_afar_modules.sh
```

## Module Types (What They Do)
- `afar-prgenv/<ver>`: meta module. Unloads system `rocm` and `amd` if loaded,
  then loads `afar-rocm/<ver>` and `afar-amd/<ver>` so the compiler module can
  finalize pkg-config selection.
- `afar-amd/<ver>`: compiler module. Adds AFAR compilers to `PATH`, sets
  `CRAY_AMD_COMPILER_PREFIX` and `CRAY_AMD_COMPILER_VERSION`, and hooks into
  the Cray Lmod compiler hierarchy (`CRAY_LMOD_COMPILER=amd/4.0` + handshake).
- `afar-rocm/<ver>`: ROCm toolkit module. Sets `CRAY_ROCM_DIR`, HIP include and
  link options, and prepends AFAR libs and pkg-config paths.
- `mpichf90.pc` override: generated per AFAR version to point Fortran module
  includes at the AFAR `mpi.mod` while linking against Cray MPICH libs.

## AFAR MPI Module Selection
The generator writes per-flavor `mpichf90.pc` files under:
- `pkgconfig/<ver>/mpich4.3.1/mpichf90.pc`
- `pkgconfig/<ver>/mpich3.4a2/mpichf90.pc`

At load time, `afar-amd` selects the matching flavor based on
`CRAY_MPICH_VERSION`:
- Cray MPICH 8.x -> `mpich3.4a2`
- Cray MPICH 9.x -> `mpich4.3.1`

The selected flavor is recorded in `AFAR_MPICH_FLAVOR`, and the corresponding
pkg-config directory is prepended to `PE_AMD_FIXED_PKGCONFIG_PATH`. `afar-amd`
also mirrors `PE_AMD_FIXED_PKGCONFIG_PATH` into `PKG_CONFIG_PATH` so
`pkg-config` works without extra setup.
If `cray-mpich` is loaded or swapped after `afar-prgenv`, the `ftn`/`cc`/`CC`
wrappers re-sync the mpich flavor and pkg-config paths at invocation time so
the correct AFAR `mpi.mod` include directory is still used.

The default `pkgconfig/<ver>/mpichf90.pc` still uses the configured Cray MPICH
path (`config/cray-mpich-dir.txt`) and is kept for compatibility.
If the Cray MPICH install path changes, update `config/cray-mpich-dir.txt` and
regenerate so the `mpichf90.pc` libdir stays in sync.

The per-flavor `mpichf90.pc` uses the AFAR `include/mpich*` directory in its
`Cflags` so `ftn`/`cc`/`CC` pull `mpi.mod` from the AFAR drop.

## Quick Start (User)
1) Add the modulepath:
   `module use /path/to/afar_modules/modulefiles`
2) Load a compatible programming environment (recommended):
   `module load PrgEnv-amd`
3) Load an AFAR drop:
   `module load afar-prgenv/22.2.0-8873`
4) Verify wrapper behavior:
   `cc --version`
   `ftn --version`
5) Verify MPICH flavor selection:
   `echo "$CRAY_MPICH_VERSION"`
   `echo "$AFAR_MPICH_FLAVOR"`
   `pkg-config --cflags mpichf90`

If you want to load them separately:
```
module load PrgEnv-amd
module load afar-amd/22.2.0-8873
module load afar-rocm/22.2.0-8873
```

To test with direct compilers:
```
amdflang program.f90 -o program
```

## OpenMP Offload (AMD)
- `craype-accel-amd-gfx90a` sets `CRAY_ACCEL_TARGET`, which makes CrayPE inject
  `-Xopenmp-target=amdgcn-amd-amdhsa`. AFAR flang does not accept that flag.
- `afar-amd` clears `CRAY_ACCEL_TARGET`/`CRAY_ACCEL_VENDOR` and uses the local
  `bin/ftn`, `bin/cc`, and `bin/CC` wrappers to add `--offload-arch=<arch>`
  when `-fopenmp` is present.
- The offload arch comes from `AFAR_FTN_OFFLOAD_ARCH` (auto-derived from
  `CRAY_ACCEL_TARGET` when possible). Override it to target a different GPU.
- The wrappers also unset `CRAYPE_LINK_TYPE=dynamic` defensively to avoid
  `-dynamic` being injected after AFAR loads.
- The wrappers are always on `PATH` once `afar-amd/<ver>` is loaded.

## Environment Variables
- `AFAR_ROOT`: override the AFAR install root at load time.
- `AFAR_PREFIX`: resolved AFAR prefix for the loaded drop.
- `AFAR_VERSION`: module version (for example, `22.2.0-8873`).
- `AFAR_DROP_VERSION`: drop version (for example, `22.2.0`).
- `AFAR_BUILD_ID`: build id (for example, `8873`).
- `AFAR_MPICH_FLAVOR`: selected AFAR MPI include flavor
  (`mpich3.4a2` or `mpich4.3.1`).
- `AFAR_MPICH_MODDIR`: resolved AFAR MPI module include directory.
- `AFAR_LLVM_LIB_DIR`: fallback directory for LLVM runtime libs
  (`libpgmath.so`, `libflang.so`, `libflangrti.so`, `libompstub.so`) when the
  AFAR drop does not ship them. When unset, `afar-prgenv` prefers the AFAR
  drop's `llvm/lib` if it contains those libs; otherwise it falls back to the
  newest `/opt/rocm-*/llvm/lib` it can find. Override it if you want a
  different LLVM runtime path.
- `AFAR_PGMATH_DIR`: legacy alias for `AFAR_LLVM_LIB_DIR`.
- `AFAR_FTN_OFFLOAD_ARCH`: when set, the AFAR `ftn`/`cc`/`CC` wrappers append
  `--offload-arch=<arch>` if `-fopenmp` is present.
- `AFAR_CC_OFFLOAD_ARCH`: optional override for the `cc` wrapper (falls back
  to `AFAR_FTN_OFFLOAD_ARCH`).
- `AFAR_CXX_OFFLOAD_ARCH`: optional override for the `CC` wrapper (falls back
  to `AFAR_FTN_OFFLOAD_ARCH`).
- `AFAR_REAL_FTN`: override path to the real CrayPE `ftn` used by the wrapper.
- `AFAR_REAL_CC`: override path to the real CrayPE `cc` used by the wrapper.
- `AFAR_REAL_CXX`: override path to the real CrayPE `CC` used by the wrapper.

## Configuration
- Default AFAR install root: `config/afar-root.lua`
- Default Cray MPICH dir: `config/cray-mpich-dir.txt`
- Override at load time:
  `export AFAR_ROOT=/path/to/afar`

When `AFAR_ROOT` changes, regenerate modulefiles so the generated
`pkgconfig/rocm-afar-<ver>.pc` files point at the new prefix.
When the Cray MPICH version changes, update `config/cray-mpich-dir.txt`
or use `--cray-mpich-dir` and regenerate so `mpichf90.pc` points at the
correct MPICH libdir.

## Version Mapping File
`config/afar-versions.txt` maps module versions to AFAR drop directories:
`<module-version>|<rocm-afar-dir>`

Examples:
```
22.2.0-8873|rocm-afar-8873-drop-22.2.0
7.0.5-8248|rocm-afar-8248-drop-7.0.5
5891|rocm-afar-5891
```

Naming rules used by the generator:
- `rocm-afar-<build>-drop-<drop>` -> `<drop>-<build>`
- `rocm-afar-<build>` -> `<build>`
- `rocm-afar<drop>-<build>` -> `<drop>-<build>`

## Generate or Update Modulefiles
The generator creates:
- `modulefiles/afar-prgenv/<ver>.lua`
- `modulefiles/afar-amd/<ver>.lua`
- `modulefiles/afar-rocm/<ver>.lua`
- `pkgconfig/rocm-afar-<ver>.pc`

Run:
```
scripts/generate_afar_modules.sh
```

Common options:
- `--root /path/to/afar` (also updates `config/afar-root.lua`)
- `--output /path/to/modulefiles`
- `--pkgconfig-dir /path/to/pkgconfig` (defaults to sibling of modulefiles/)
- `--cray-mpich-dir /path/to/mpich` (updates `config/cray-mpich-dir.txt`)
- `--versions /path/to/afar-versions.txt`
- `--scan` (auto-discover `rocm-afar*` directories)
- `--write-versions` (write discovered versions to `afar-versions.txt`)

### Typical Workflows
Add a new drop by scanning:
```
scripts/generate_afar_modules.sh --scan --write-versions --root /path/to/afar
```

Add a new drop manually:
1) Edit `config/afar-versions.txt` and add a line:
   `22.2.1-9000|rocm-afar-9000-drop-22.2.1`
2) Regenerate:
   `scripts/generate_afar_modules.sh`

Relocate the module tree:
```
scripts/generate_afar_modules.sh --output /new/modules --pkgconfig-dir /new/pkgconfig
```
Then set `MODULEPATH` to the new modulefiles path.

## Troubleshooting
Example test commands (Cray MPICH 8.x vs 9.x):
```
# MPICH 8.x
module purge
module use /path/to/afar_modules/modulefiles
module load PrgEnv-amd
module load cray-mpich/8.1.31
module load craype-accel-amd-gfx90a
module load afar-prgenv/22.2.0-8873
echo "$CRAY_MPICH_VERSION"
echo "$AFAR_MPICH_FLAVOR"
pkg-config --cflags mpichf90

# MPICH 9.x
module purge
module use /path/to/afar_modules/modulefiles
module load PrgEnv-amd
module load cray-mpich/9.0.1
module load craype-accel-amd-gfx90a
module load afar-prgenv/22.2.0-8873
echo "$CRAY_MPICH_VERSION"
echo "$AFAR_MPICH_FLAVOR"
pkg-config --cflags mpichf90
```

MPI Fortran module checksum errors (mpi.mod):
- Ensure `config/cray-mpich-dir.txt` matches the active `cray-mpich` path.
- Regenerate modulefiles so `pkgconfig/<ver>/mpichf90.pc` is updated.
- Verify the AFAR override is active:
  `pkg-config --cflags mpichf90` should point at `AFAR_PREFIX/include/mpich*`.
  The generated override lives in `pkgconfig/<ver>/mpichf90.pc` and is made
  visible via `PE_AMD_FIXED_PKGCONFIG_PATH` in `afar-amd/<ver>`.

`ftn` or `cc` complains about pkg-config:
- Ensure `afar-rocm/<ver>` and `afar-amd/<ver>` are loaded.
- Ensure `pkgconfig/rocm-afar-<ver>.pc` exists.
- Verify `PKG_CONFIG_PATH` includes `afar_modules/pkgconfig` (it should be
  mirrored automatically from `PE_AMD_FIXED_PKGCONFIG_PATH`).

`cc`/`CC` wrappers not picked up:
- Verify `which cc`/`which CC` points at `afar_modules/bin/cc` and
  `afar_modules/bin/CC`.
- The wrappers are prepended to `PATH` only when an offload arch is active
  (via `craype-accel-amd-gfx90a` or `AFAR_FTN_OFFLOAD_ARCH`).

LLVM runtime libs missing at runtime (`libpgmath.so`, `libflang.so`, ...):
- `afar-amd` appends a fallback LLVM lib path only if it finds the runtime libs.
- Override with `AFAR_LLVM_LIB_DIR=/path/to/llvm/lib` (or `AFAR_PGMATH_DIR`).

`craype-accel-amd-gfx90a` and `-dynamic` errors:
- `afar-amd` clears `CRAYPE_LINK_TYPE=dynamic` to avoid passing `-dynamic` to
  AFAR flang; dynamic linking remains the default in the wrapper.
- The `ftn`/`cc`/`CC` wrappers also unset `CRAYPE_LINK_TYPE=dynamic` in case it
  is set after AFAR loads.

`craype-accel-amd-gfx90a` and `-Xopenmp-target` errors:
- `craype-accel-*` sets `CRAY_ACCEL_TARGET`, which makes the CrayPE wrappers
  inject `-Xopenmp-target=amdgcn-amd-amdhsa`. AFAR flang does not accept that
  flag, so `afar-amd` clears `CRAY_ACCEL_TARGET`/`CRAY_ACCEL_VENDOR` on load.
- The `bin/ftn`, `bin/cc`, and `bin/CC` wrappers add `--offload-arch=<arch>`
  when `-fopenmp` is used.

cray-mpich GTL + ROCm version mismatch (libamdhip64.so.6 vs .7):
- `afar-rocm` strips Cray MPICH GTL pkg-config vars when AFAR does not provide
  `libamdhip64.so.6`, preventing `-lmpi_gtl_hsa` from pulling ROCm 6 libs.
- This disables GTL GPU-aware MPI for AFAR ROCm > 6; use a ROCm 6 AFAR drop if
  you need GTL.

Version mismatch errors:
- `afar-amd` and `afar-rocm` require the same `<ver>`.
- Unload mismatched modules and reload with the same version.

System `rocm` conflicts:
- `afar-prgenv` unloads `rocm` automatically. If you load `afar-amd` and
  `afar-rocm` manually, unload `rocm` yourself.

## Admin Handoff
- Copy the entire `afar_modules/` tree to the target location and preserve
  executable bits on `bin/ftn`, `bin/cc`, and `bin/CC`.
- Update `config/afar-root.lua` to point at the system AFAR root.
- Update `config/cray-mpich-dir.txt` to the active Cray MPICH libdir
  (for example, `/opt/cray/pe/mpich/9.0.1/ofi/amd/6.0`).
- Run `scripts/generate_afar_modules.sh` to refresh modulefiles and `.pc` files
  after any AFAR drop change or MPICH path update.
- Add `module use <new-path>/modulefiles` to site module init if desired.

Operational notes for admins:
- MPICH include/mod selection is dynamic: `afar-amd` chooses `mpich3.4a2` for
  cray-mpich/8.x and `mpich4.3.1` for 9.x at load time.
- If the MPICH libdir path changes with a new PE, update
  `config/cray-mpich-dir.txt` and regenerate so `mpichf90.pc` lib paths match.
- Ensure `/opt/rocm-*` runtime libs are available or set `AFAR_LLVM_LIB_DIR`
  if AFAR drops do not ship `libpgmath.so`/`libflang*.so`.

## Validation Checklist
- `module use <new-path>/modulefiles`
- `module load PrgEnv-amd`
- `module load afar-prgenv/<ver>`
- `ftn --version` (should report AFAR flang)
- `cc --version` (should report AFAR clang)
- `ftn -fopenmp --offload-arch=gfx90a test.f90 -o test` or
  `ftn -### -fopenmp test.f90 -o test` (confirm `-target-cpu gfx90a` appears)
- `ldd test` (confirm AFAR libs and expected ROCm libs are referenced)
