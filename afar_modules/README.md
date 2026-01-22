# AFAR Module Tree (Local)

This directory provides a relocatable Lmod module tree for AFAR compiler +
ROCm drops on Frontier. The tree is designed to be copied into a site
modulepath with only a root path update and regeneration.

## Quick Start (User)
1) Add the modulepath:
   `module use /path/to/afar_modules/modulefiles`
2) Load a compatible programming environment:
   `module load PrgEnv-amd`
3) Load an AFAR drop:
   `module load afar-prgenv/22.2.0-8873`
4) Verify wrapper behavior:
   `ftn --version`
   `cc --version`
5) Verify MPICH flavor selection:
   `echo "$CRAY_MPICH_VERSION"`
   `echo "$AFAR_MPICH_FLAVOR"`
   `pkg-config --cflags mpichf90`

## Documentation Map
- `docs/user-guide.md`: day-to-day usage, build examples, and runtime checks.
- `docs/architecture.md`: how the AFAR modules, wrappers, and pkg-config glue fit together.
- `docs/mpich.md`: Cray MPICH 8.x vs 9.x integration, mpichf90.pc layout, and validation.
- `docs/wrappers.md`: ftn/cc/CC wrapper behavior, offload arch injection, and overrides.
- `docs/module-generation.md`: generating modulefiles, adding new AFAR drops, and config inputs.
- `docs/troubleshooting.md`: common issues and diagnostics.
- `docs/testing.md`: local test harness and repro layout.
- `docs/admin-handoff.md`: site admin checklist for deployment and updates.
- `docs/documentation-plan.md`: documentation maintenance plan and best practices.

## Repository Layout (High Level)
```
afar_modules/
  bin/            # compiler wrapper scripts (ftn/cc/CC)
  config/         # AFAR root + version mapping + Cray MPICH libdir
  docs/           # detailed documentation
  modulefiles/    # generated Lmod modulefiles
  pkgconfig/      # generated pkg-config files
  scripts/        # generator scripts
```

## Maintenance Checklist (Short)
- Add new drops and regenerate: `docs/module-generation.md`
- Keep MPICH 8.x/9.x mapping current: `docs/mpich.md`
- Verify wrapper behavior after changes: `docs/wrappers.md`
- Update admin-facing steps after PE/ROCm changes: `docs/admin-handoff.md`
- Refresh examples and tests: `docs/troubleshooting.md`

## Notes
- Use `.modules` in this workspace for the known-good module sequence.
- If ROCm/AMD versions change, update `.modules` to keep them paired.
- Regenerate modulefiles after AFAR drop or MPICH path changes:
  `afar_modules/scripts/generate_afar_modules.sh`
