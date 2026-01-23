# Cray MPICH Integration

This document explains how AFAR modules support both Cray MPICH 8.x and 9.x,
and how the correct MPI module files and pkg-config entries are selected.

For background on `.pc` files and `pkg-config`, see [docs/pkgconfig.md](pkgconfig.md).

## MPICH Flavor Mapping
Cray MPICH versions map to different MPI module file layouts:
- Cray MPICH 8.x -> `include/mpich3.4a2`
- Cray MPICH 9.x -> `include/mpich4.3.1`

AFAR drops may include one or both of these directories. The modulefiles and
wrappers select the best match based on `CRAY_MPICH_VERSION`.

## mpichf90.pc Layout
The generator writes per-flavor `mpichf90.pc` files:
- `pkgconfig/<ver>/mpich3.4a2/mpichf90.pc`
- `pkgconfig/<ver>/mpich4.3.1/mpichf90.pc`

`afar-amd` selects the flavor at module load time based on
`CRAY_MPICH_VERSION` and prepends the matching directory to
`PE_AMD_FIXED_PKGCONFIG_PATH`. The wrappers re-check this at compile time to
handle module swaps after `afar-prgenv` is loaded.

## Cray MPICH Root
The `mpichf90.pc` file references the Cray MPICH libdir:
- `config/cray-mpich-dir.txt` stores the default.
- You can override at generation time with `--cray-mpich-dir`.
- `CRAY_MPICH_DIR` or `MPICH_DIR` environment variables are also honored.

If the Cray MPICH installation moves or the PE changes, update the config and
regenerate.

## Validation Steps
Cray MPICH 8.x:
```
module load cray-mpich/8.1.31
echo "$CRAY_MPICH_VERSION"     # 8.x
echo "$AFAR_MPICH_FLAVOR"      # mpich3.4a2
pkg-config --cflags mpichf90   # includes .../include/mpich3.4a2
```

Cray MPICH 9.x:
```
module load cpe/25.09
module load cray-mpich/9.0.1
echo "$CRAY_MPICH_VERSION"     # 9.x
echo "$AFAR_MPICH_FLAVOR"      # mpich4.3.1
pkg-config --cflags mpichf90   # includes .../include/mpich4.3.1
```

If you swap MPICH after AFAR:
```
module load afar-prgenv/<ver>
module swap cray-mpich/8.1.31 cray-mpich/9.0.1
ftn -fopenmp hello.f90 -o hello
```
The wrapper re-syncs the flavor for the build.

## Common Failure Modes
- `pkg-config --cflags mpichf90` is missing or points at the wrong include:
  ensure the wrappers are on `PATH` and `PE_AMD_FIXED_PKGCONFIG_PATH` is
  mirrored into `PKG_CONFIG_PATH`.
- `AFAR_MPICH_FLAVOR` does not match `CRAY_MPICH_VERSION`:
  reload `afar-prgenv` or use the wrappers for the compile.
