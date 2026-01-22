# Compiler Wrappers (ftn/cc/CC)

The AFAR module tree ships lightweight wrappers for the Cray PE compiler
drivers. These wrappers keep the Cray build flow intact while fixing AFAR
specific details (OpenMP offload and MPICH pkg-config).

Wrapper scripts:
- `afar_modules/bin/ftn`
- `afar_modules/bin/cc`
- `afar_modules/bin/CC`

## PATH Precedence
`afar-amd` prepends `afar_modules/bin` to `PATH`, ensuring the wrappers take
precedence over the system `ftn`, `cc`, and `CC`. Verify:
```
which ftn
which cc
which CC
```

## Real Compiler Resolution
Each wrapper finds the underlying Cray PE driver in this order:
1) `AFAR_REAL_FTN` / `AFAR_REAL_CC` / `AFAR_REAL_CXX` (explicit override)
2) `CRAYPE_DIR/bin/ftn|cc|CC`
3) First matching driver in `PATH` (excluding the wrapper dir)

This keeps the wrappers robust even if module order changes.

## MPICH pkg-config Re-sync
The wrappers re-check MPI state at invocation time and adjust pkg-config paths:
- Determine the Cray MPICH major version from `CRAY_MPICH_VERSION`.
- Select `mpich3.4a2` for 8.x and `mpich4.3.1` for 9.x.
- Prepend the matching `pkgconfig/<ver>/<flavor>` directory to
  `PE_AMD_FIXED_PKGCONFIG_PATH`.
- Mirror `PE_AMD_FIXED_PKGCONFIG_PATH` into `PKG_CONFIG_PATH`.
- Export `AFAR_MPICH_FLAVOR` for diagnostics.

This handles the case where `cray-mpich` is loaded or swapped after
`afar-prgenv`.

## OpenMP Offload Arch Injection
If the wrapper sees `-fopenmp` and there is no explicit `--offload-arch`, it
adds the correct offload arch flag:
- Fortran: `AFAR_FTN_OFFLOAD_ARCH`
- C: `AFAR_CC_OFFLOAD_ARCH` (falls back to `AFAR_FTN_OFFLOAD_ARCH`)
- C++: `AFAR_CXX_OFFLOAD_ARCH` (falls back to `AFAR_FTN_OFFLOAD_ARCH`)

The `afar-amd` module sets `AFAR_FTN_OFFLOAD_ARCH` automatically when
`craype-accel-amd-gfx90a` is loaded. To override manually:
```
export AFAR_FTN_OFFLOAD_ARCH=gfx90a
export AFAR_CC_OFFLOAD_ARCH=gfx90a
export AFAR_CXX_OFFLOAD_ARCH=gfx90a
```

If you pass `--offload-arch` explicitly, the wrappers do not modify it.

## Debugging the Wrappers
To see what the wrapper passes to the real compiler:
```
AFAR_REAL_CC=/usr/bin/env cc -fopenmp hello.c -o hello
AFAR_REAL_FTN=/usr/bin/env ftn -fopenmp hello.f90 -o hello
```
The `/usr/bin/env` trick prints the final argument list without executing
the real compiler.

## Unsupported Flag Audit
Wrappers load an unsupported-flag pattern list and print matches to stderr.
Use this to identify flags injected by build systems (CMake, Autotools) that
AFAR flang does not accept.

Default patterns live in:
- `config/wrapper-unsupported-flags.txt`

You can override the file path with:
- `AFAR_WRAPPER_UNSUPPORTED=/path/to/unsupported.txt`

The default filter includes `-dynamic` so `CRAYPE_LINK_TYPE=dynamic` does not
break AFAR builds even if modules are loaded out of order.

## Wrapper Filter and Mapping
Wrappers can ignore or replace arguments based on a filter file. This is
useful when you want to translate unsupported flags into supported ones.

Default filter file:
- `config/wrapper-filter.txt`

Set a custom file path with:
- `AFAR_WRAPPER_FILTER=/path/to/wrapper-filter.txt`

Filter file syntax:
```
ignore <pattern>
replace <pattern> <replacement...>
```
Patterns use shell globs. Replacements are whitespace-separated arguments.

## Best Practices
- Prefer `ftn`, `cc`, and `CC` wrappers for builds unless explicitly testing
  direct `amdflang` or `amdclang`.
- Keep wrapper scripts executable (`chmod 755`).
- If you add new wrapper logic, update `docs/wrappers.md` and
  `docs/architecture.md` to keep behavior in sync.
