# Wrapper Compile/Link (C/C++/Fortran)

Purpose: validate `cc`, `CC`, and `ftn` wrappers for separate compile and link steps.

Build:
```
./build.sh
```

Notes:
- The build compiles each language to objects, then links each object with the same wrapper.
- `scripts/check_ldd.sh` validates linked binaries for missing or unexpected library paths.
