# Parallel NetCDF (C/C++/Fortran)

Purpose: validate PnetCDF headers, modules, and linking with the AFAR wrappers.

Build:
```
./build.sh
```

Notes:
- Uses `pkg-config pnetcdf`.
- The `netcdf` profile loads `cray-parallel-netcdf` if available.
- Requires `PNETCDF_DIR` (or `CRAY_PARALLEL_NETCDF_DIR`/`CRAY_PARALLEL_NETCDF_PREFIX`)
  to be set by the module.
- Fortran uses `include 'pnetcdf.inc'` instead of compiler-specific `.mod` files;
  the build skips Fortran if `pnetcdf.inc` is missing.
- `scripts/check_ldd.sh` validates linked binaries.
