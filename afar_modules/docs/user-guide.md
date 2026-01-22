# User Guide

This guide covers the most common user workflows: loading AFAR modules,
building programs, and verifying GPU offload.

## Recommended Module Sequence
Use the workspace `.modules` when available. A typical sequence is:
```
module purge
module load cpe/25.09
module use /path/to/afar_modules/modulefiles
module load PrgEnv-amd
module load cray-mpich/9.0.1
module load craype-x86-trento
module load craype-accel-amd-gfx90a
module load afar-prgenv/22.2.0-8873
```

## Quick Sanity Checks
```
which ftn
which cc
which CC
ftn --version
cc --version
echo "$AFAR_VERSION"
echo "$CRAY_MPICH_VERSION"
pkg-config --cflags mpichf90
```

## Compile Examples
Fortran:
```
ftn hello.f90 -o hello
```

C:
```
cc hello.c -o hello
```

C++:
```
CC hello.cpp -o hello
```

MPI (Fortran example):
```
ftn -fopenmp mpi_hello.f90 -o mpi_hello
```

## OpenMP Offload (AMD)
The wrappers add `--offload-arch=<arch>` when `-fopenmp` is present and the
offload arch is known (for example, from `craype-accel-amd-gfx90a`).

Fortran:
```
ftn -fopenmp omp_test.f90 -o omp_test
```

C:
```
cc -fopenmp omp_test.c -o omp_test
```

To verify offload on a GPU node:
```
export OMP_TARGET_OFFLOAD=MANDATORY
export LIBOMPTARGET_INFO=4
./omp_test
```

## MPICH Flavor Validation
Cray MPICH 8.x:
```
module load cray-mpich/8.1.33
echo "$CRAY_MPICH_VERSION"     # 8.x
echo "$AFAR_MPICH_FLAVOR"      # mpich3.4a2
pkg-config --cflags mpichf90   # includes .../include/mpich3.4a2
```

Cray MPICH 9.x:
```
module load cpe/25.09
module load cray-mpich/9.0.1
echo "$CRAY_MPICH_VERSION"     # 9.x
echo "$AFAR_MPICH_FLAVOR"      # mpich4.3.1
pkg-config --cflags mpichf90   # includes .../include/mpich4.3.1
```

If you swap MPICH after loading AFAR:
```
module load afar-prgenv/22.2.0-8873
module swap cray-mpich/8.1.33 cray-mpich/9.0.1
ftn -fopenmp omp_test.f90 -o omp_test
```
The wrappers re-sync the mpich flavor on each invocation.

## Environment Variable Cheatsheet
Common overrides:
- `AFAR_LLVM_LIB_DIR=/path/to/llvm/lib`
- `AFAR_FTN_OFFLOAD_ARCH=gfx90a`
- `AFAR_CC_OFFLOAD_ARCH=gfx90a`
- `AFAR_CXX_OFFLOAD_ARCH=gfx90a`

## Notes
- Use `ftn` for Fortran sources. `cc` and `CC` are for C and C++.
- If `which ftn` points at the system Cray PE wrappers, reload `afar-prgenv`.
