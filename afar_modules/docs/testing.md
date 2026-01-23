# AFAR Test Harness

This document covers the local test harness used to validate `afar-prgenv`
across multiple module stacks and libraries.

## Test Layout
Repro cases live under `repro/` at the workspace root. Each test has:
- `README.md`
- `build.sh`

Build outputs go under `build/<profile>` inside each repro directory.

## Runner Script
Script: `scripts/run_afar_tests.sh`

Default profiles:
- `base`: cpe + PrgEnv-amd + cray-mpich + gfx90a + afar-prgenv
- `libsci`: base + `cray-libsci`
- `libsci-acc`: base + `cray-libsci_acc`

Note: the `libsci-acc` profile is currently marked as SKIP for all repros because
the `libsci_acc` link step is not being validated in this AFAR drop.
- `hdf5`: base + `cray-hdf5-parallel`
- `hdf5-serial`: base + `cray-hdf5`
- `fftw`: base + `cray-fftw`
- `dsmml`: base + `cray-dsmml`
- `netcdf`: base + `cray-parallel-netcdf`

Run the full matrix:
```
scripts/run_afar_tests.sh --keep-going
```

By default the runner loads each library module both before and after
`afar-prgenv` to validate order-independence. Control this with:
```
# Only load libraries before afar-prgenv
scripts/run_afar_tests.sh --lib-order before

# Only load libraries after afar-prgenv
scripts/run_afar_tests.sh --lib-order after

# Default (both)
scripts/run_afar_tests.sh --lib-order both
```

Run only a subset:
```
scripts/run_afar_tests.sh --profiles base,libsci
```

Override modules:
```
AFAR_TEST_CPE=cpe/25.09 \
AFAR_TEST_MPICH=cray-mpich/9.0.1 \
scripts/run_afar_tests.sh --profiles base
```

Use system AFAR modules from `/sw/crusher/ums/compilers/modulefiles`:
```
AFAR_TEST_MODULEPATH=/sw/crusher/ums/compilers/modulefiles \
AFAR_TEST_AFAR_MODULE=afar/22.2.0-8873 \
scripts/run_afar_tests.sh --profiles base
```

## Repro Inventory
- `cmake-mpi-omp`: CMake MPI + OpenMP (C/Fortran) sanity build.
- `compile-only`: Fortran compile-only (`-c`) check.
- `wrapper-compile-link`: separate compile and link for C/C++/Fortran.
- `mpi-hello`: MPI hello world (Fortran).
- `omp-c`: OpenMP host + target (C).
- `omp-f90`: OpenMP host + target (Fortran).
- `libsci`: BLAS `dgemm` in C/C++/Fortran.
- `libsci-acc`: accelerator library link check (`cray-libsci_acc`).
- `hdf5`: HDF5 C/C++ + Fortran shim module (AFAR-compiled `hdf5.mod`).
- `fftw`: FFTW C/C++/Fortran link check.
- `dsmml`: DSMML C/Fortran link check.
- `netcdf`: PnetCDF (cray-parallel-netcdf) C/C++ + Fortran via `pnetcdf.inc`.

## Binary Dependency Checks
Most repros run `scripts/check_ldd.sh` after linking. The default allowlist
includes:
- `/autofs/nccs-svm1_sw/crusher/ums/compilers/afar`
- `/opt/cray`
- `/opt/amdgpu`
- `/opt/rocm-7.0.2` (MPI runtime dependencies)
- `/sw/frontier`
- `/lib*`, `/usr/lib*`

Override with:
```
AFAR_LDD_ALLOWED_PREFIXES=/path/one:/path/two
```

## pkg-config Shims
If a Cray library module does not ship a usable `.pc` file, the test runner
generates local shim files based on the module environment. The shims are
written under `afar_modules/pkgconfig/shims/<AFAR_VERSION>` and appended to
`PKG_CONFIG_PATH` for the duration of the profile.

You can generate them manually after loading modules:
```
afar_modules/scripts/generate_pkgconfig_shims.sh
```

For background on `.pc` files and `PKG_CONFIG_PATH`, see [docs/pkgconfig.md](pkgconfig.md).

The wrappers also refresh shims automatically when `AFAR_PKGCONFIG_SHIM_AUTO`
is enabled; the runner still generates them once per profile to keep results
consistent.

## Logs
Logs are written to `logs/<timestamp>-<profile>.log`. They are intentionally
untracked (see `logs/.gitignore`) so you can keep run history locally.
Override the location with:
```
AFAR_TEST_LOG_DIR=/path/to/logs
```

## Adding a New Test
1) Create `repro/<name>/`.
2) Add `README.md` and `build.sh`.
3) Keep the build script self-contained (use `ftn`, `cc`, or `CC`).
4) The runner automatically discovers new repro directories.
