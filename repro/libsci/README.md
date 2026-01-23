# LibSci (C/C++/Fortran)

Purpose: validate `cray-libsci` headers and link flags via the AFAR wrappers.

Build:
```
./build.sh
```

Notes:
- Requires the `cray-libsci` module to be loaded.
- Uses `pkg-config libsci` to supply include and link flags.
- `scripts/check_ldd.sh` validates linked binaries.
