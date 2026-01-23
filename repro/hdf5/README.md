# HDF5 (C/C++/Fortran)

Purpose: validate `cray-hdf5` and `cray-hdf5-parallel` include/link paths via the AFAR wrappers.

Build:
```
./build.sh
```

Notes:
- Runs when `HDF5_DIR` or `CRAY_HDF5_DIR` is set and `pkg-config hdf5` is available.
- C/C++ use HDF5 headers and libs from `pkg-config`.
- Fortran uses a local `hdf5.mod` shim compiled with AFAR (see `hdf5_shim.f90`).
  This avoids incompatible vendor `.mod` files while still linking against HDF5 C libs.
- `scripts/check_ldd.sh` validates linked binaries.
