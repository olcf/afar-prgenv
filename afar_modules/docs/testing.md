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
- `hdf5`: base + `cray-hdf5-parallel`
- `fftw`: base + `cray-fftw`
- `dsmml`: base + `cray-dsmml`

Run the full matrix:
```
scripts/run_afar_tests.sh
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

Logs are written to `logs/<timestamp>-<profile>.log`.

## Adding a New Test
1) Create `repro/<name>/`.
2) Add `README.md` and `build.sh`.
3) Keep the build script self-contained (use `ftn`, `cc`, or `CC`).
4) The runner automatically discovers new repro directories.
