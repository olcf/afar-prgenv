# MPI Hello (Fortran)

Purpose: validate AFAR `ftn` wrapper + MPICH module files.

Build:
```
./build.sh
```

Notes:
- The build uses `ftn` and expects `cray-mpich` + `afar-prgenv` to be loaded.
- Set `AFAR_TEST_RUN_MPI=1` to run with `srun` or `mpirun` if available.
