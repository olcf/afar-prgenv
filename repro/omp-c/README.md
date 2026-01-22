# OpenMP Offload (C)

Purpose: validate OpenMP compilation and offload flag injection in `cc`.

Build:
```
./build.sh
```

Notes:
- Requires `craype-accel-amd-gfx90a` (or `AFAR_CC_OFFLOAD_ARCH` set).
- Set `AFAR_TEST_RUN=1` to run the binary.
