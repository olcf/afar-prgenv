# Admin Handoff

This document is a checklist for site admins deploying or updating the AFAR
module tree on Frontier.

## Deployment Checklist
1) Choose a site module root (for example `/opt/afar/modulefiles`).
2) Copy or sync the entire `afar_modules/` tree:
   - `modulefiles/`
   - `bin/`
   - `pkgconfig/`
   - `config/`
   - `scripts/`
   - `docs/`
3) Ensure wrapper scripts are executable:
   - `chmod 755 bin/ftn bin/cc bin/CC`
4) Add the module path:
   `module use /path/to/afar_modules/modulefiles`

## Updating to a New AFAR Drop
1) Install the new AFAR drop under `AFAR_ROOT`.
2) Update `config/afar-versions.txt` (or scan):
   `scripts/generate_afar_modules.sh --scan --write-versions`
3) Update the Cray MPICH root if needed:
   `scripts/generate_afar_modules.sh --cray-mpich-dir /opt/cray/pe/mpich/<ver>/ofi/amd/6.0`
4) Regenerate modulefiles and pkg-config:
   `scripts/generate_afar_modules.sh`
5) Smoke test:
   ```
   module use /path/to/afar_modules/modulefiles
   module load PrgEnv-amd
   module load cray-mpich
   module load afar-prgenv/<ver>
   ftn -fopenmp hello.f90 -o hello
   pkg-config --cflags mpichf90
   ```

## Test Harness
- Run `scripts/run_afar_tests.sh --keep-going` after updates.
- Logs are written under `logs/` and intentionally untracked (see `logs/.gitignore`).
- `scripts/check_ldd.sh` allows `/opt/rocm-7.0.2` because MPI runtimes may pull it.

## pkg-config Notes
- The generator creates `mpichf90.pc` and `rocm-afar-<ver>.pc` files.
- Local shim `.pc` files are generated at runtime by
  `scripts/generate_pkgconfig_shims.sh` using the module environment.
- For background and manual maintenance guidance, see [docs/pkgconfig.md](pkgconfig.md).

## Cray MPICH 8.x vs 9.x
- Cray MPICH 8.x needs `include/mpich3.4a2` from the AFAR drop.
- Cray MPICH 9.x needs `include/mpich4.3.1`.
- The wrappers re-sync the MPICH flavor on each invocation, but the AFAR drop
  must include the correct module directory for the targeted MPICH major.

## ROCm Runtime Fallback
If the AFAR drop does not include the LLVM Fortran runtime libs, the module
uses the newest `/opt/rocm-*/llvm/lib` as a fallback. If that path changes,
update the site documentation and consider setting `AFAR_LLVM_LIB_DIR`.

## Files to Update When the PE Changes
- `config/cray-mpich-dir.txt`
- `config/afar-versions.txt`
- `.modules` (workspace guidance)
- [docs/mpich.md](mpich.md) and [docs/troubleshooting.md](troubleshooting.md) (examples and tests)
- [docs/pkgconfig.md](pkgconfig.md) (pkg-config baseline or shim behavior)

## Handoff Notes
- Generated modulefiles live under `modulefiles/`. Avoid editing them directly.
- Keep `scripts/generate_afar_modules.sh` as the authoritative source for
  modulefile behavior.
- If you add new wrapper logic, update [docs/wrappers.md](wrappers.md) and regenerate.
