# OpenMP Offload (Fortran)

Purpose: validate OpenMP compilation and offload flag injection in `ftn`.

Build:
```
./build.sh
```

Notes:
- Requires `craype-accel-amd-gfx90a` (or `AFAR_FTN_OFFLOAD_ARCH` set).
- Set `AFAR_TEST_RUN=1` to run the binary.
