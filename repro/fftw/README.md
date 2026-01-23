# FFTW (C/C++/Fortran)

Purpose: validate `cray-fftw` include/link paths via the AFAR wrappers.

Build:
```
./build.sh
```

Notes:
- Requires the `cray-fftw` module to be loaded.
- Uses `pkg-config fftw3` flags for all languages.
- `scripts/check_ldd.sh` validates linked binaries.
