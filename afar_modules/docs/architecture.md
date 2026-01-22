# Architecture Overview

This document explains how the AFAR module tree is structured and how the
components work together at load time and compile time.

## Module Types and Responsibilities
The AFAR tree is split into three module types plus wrapper scripts:
- `afar-prgenv/<ver>` (meta): unloads conflicting system modules and loads the
  AFAR compiler + ROCm toolkit in the correct order. Also sets a default
  LLVM runtime fallback when needed.
- `afar-amd/<ver>` (compiler): wires AFAR compilers into the Cray PE hierarchy,
  sets compiler environment variables, and owns the wrapper behavior.
- `afar-rocm/<ver>` (toolkit): sets ROCm include/link options and ROCm paths.
- `bin/ftn`, `bin/cc`, `bin/CC` (wrappers): inject offload arch flags and
  re-sync MPICH pkg-config state at invocation time.

## Load and Environment Flow
1) User loads `PrgEnv-amd`, `cray-mpich`, and the `craype-*` target modules.
2) User loads `afar-prgenv/<ver>`:
   - Unloads any `rocm` or `amd` modules.
   - Loads `afar-rocm/<ver>` then `afar-amd/<ver>`.
   - Sets `AFAR_LLVM_LIB_DIR` when a fallback is needed.
3) `afar-rocm/<ver>` sets ROCm include/link options and pkg-config paths.
4) `afar-amd/<ver>` sets compiler paths, wrapper overrides, and MPICH
   integration, then mirrors fixed pkg-config paths into `PKG_CONFIG_PATH`.

The order ensures the compiler module is the last to modify `PATH` and
pkg-config search paths.

## PATH and Wrapper Precedence
`afar-amd`:
- Prepends AFAR compilers to `PATH`.
- Prepends `afar_modules/bin` to `PATH` so wrappers are always in front.
- Sets `AFAR_REAL_FTN`, `AFAR_REAL_CC`, and `AFAR_REAL_CXX` from `CRAYPE_DIR`
  when available, so wrappers can find the real Cray PE drivers.

`afar-rocm`:
- Prepends ROCm `bin`, `lib`, and `pkgconfig` directories for the AFAR drop.

## MPICH Integration Flow
1) The generator writes per-flavor `mpichf90.pc` files:
   - `pkgconfig/<ver>/mpich3.4a2/mpichf90.pc` (Cray MPICH 8.x)
   - `pkgconfig/<ver>/mpich4.3.1/mpichf90.pc` (Cray MPICH 9.x)
2) `afar-amd` selects the flavor based on `CRAY_MPICH_VERSION` and prepends
   the matching pkg-config directory to `PE_AMD_FIXED_PKGCONFIG_PATH`.
3) The wrappers re-check `CRAY_MPICH_VERSION` at compile time and prepend the
   correct per-flavor pkg-config directory if MPICH is loaded or swapped after
   `afar-prgenv`.

## Offload Arch Handling
- `craype-accel-amd-gfx90a` sets `CRAY_ACCEL_TARGET=amd_gfx90a`.
- `afar-amd` clears `CRAY_ACCEL_TARGET` and `CRAY_ACCEL_VENDOR` to avoid
  unsupported `-Xopenmp-target` flags for AFAR flang.
- `afar-amd` sets `AFAR_FTN_OFFLOAD_ARCH=gfx90a` when possible.
- Wrappers add `--offload-arch=gfx90a` only when `-fopenmp` is present and no
  `--offload-arch` is already specified.

## Wrapper Behavior at Compile Time
Each wrapper:
- Locates the real CrayPE compiler (`ftn`, `cc`, or `CC`).
- Injects `--offload-arch` when `-fopenmp` is used and no offload arch is set.
- Re-syncs `PE_AMD_FIXED_PKGCONFIG_PATH` and `PKG_CONFIG_PATH` for MPICH.

## LLVM Runtime Fallback
If an AFAR drop does not ship `libpgmath.so`, `libflang.so`, `libflangrti.so`,
or `libompstub.so`, `afar-amd` appends a fallback LLVM runtime lib directory.
The fallback is auto-detected from `/opt/rocm-*/llvm/lib` unless overridden by
`AFAR_LLVM_LIB_DIR` (or `AFAR_PGMATH_DIR`).

## Lmod Hierarchy Integration
`afar-amd` registers itself as an `amd/4.0` compiler in the Cray Lmod
hierarchy. This keeps `module avail` output consistent with the PE.

## Diagnostics
Useful quick checks:
```
which ftn
echo "$AFAR_VERSION"
echo "$CRAY_MPICH_VERSION"
pkg-config --cflags mpichf90
```
