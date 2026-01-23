# DSMML (C/Fortran)

Purpose: validate `cray-dsmml` headers and link flags via the AFAR wrappers.

Build:
```
./build.sh
```

Notes:
- Requires the `cray-dsmml` module to be loaded.
- Uses `pkg-config dsmml` flags.
- `scripts/check_ldd.sh` validates linked binaries.
