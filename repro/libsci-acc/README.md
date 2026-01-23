# LibSci Acc (C/C++/Fortran)

Purpose: validate `cray-libsci_acc` link paths for accelerator libraries via the AFAR wrappers.

Build:
```
./build.sh
```

Notes:
- Requires the `cray-libsci_acc` module to be loaded.
- Uses `AFAR_LIBSCI_ACC_LIBNAME` to override the default `sci_acc_amd_gfx90a` library name.
- `scripts/check_ldd.sh` validates linked binaries.
- Skips if `libamdhip64.so.6`/`librocblas.so.4` (ROCm 6 deps) are missing.
