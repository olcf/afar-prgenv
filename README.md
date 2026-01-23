# AFAR PrgEnv Module for Frontier

[![Paper](https://img.shields.io/badge/paper-PDF-blue)](paper/afar-prgenv.pdf) [![Docs](https://img.shields.io/badge/docs-afar__modules%2Fdocs-brightgreen)](afar_modules/docs/documentation-plan.md)

<img src="assets/readme/afar_prgenv.png" alt="AFAR PrgEnv overview" width="100%">

This repository provides a relocatable Lmod module tree for AFAR compiler +
ROCm drops on Frontier. The tree is designed to be copied into a site
modulepath with only a root path update and regeneration.

## Quick Start (User)
1) Add the modulepath:
   `module use /path/to/afar_modules/modulefiles`
2) Load a compatible programming environment:
   `module load cpe/25.09`
   `module load PrgEnv-amd`
3) Load MPI and targets:
   `module load cray-mpich/9.0.1`
   `module load craype-x86-trento`
   `module load craype-accel-amd-gfx90a`
4) Load an AFAR drop:
   `module load afar-prgenv/22.2.0-8873`
5) Verify wrapper behavior:
   `ftn --version`
   `cc --version`
6) Verify MPICH flavor selection:
   `echo "$CRAY_MPICH_VERSION"`
   `echo "$AFAR_MPICH_FLAVOR"`
   `pkg-config --cflags mpichf90`

## Documentation Map
- [afar_modules/docs/user-guide.md](afar_modules/docs/user-guide.md): day-to-day usage, build examples, and runtime checks.
- [afar_modules/docs/pkgconfig.md](afar_modules/docs/pkgconfig.md): `pkg-config` primer, `.pc` format, and AFAR shims.
- [afar_modules/docs/architecture.md](afar_modules/docs/architecture.md): how the AFAR modules, wrappers, and pkg-config glue fit together.
- [afar_modules/docs/mpich.md](afar_modules/docs/mpich.md): Cray MPICH 8.x vs 9.x integration, mpichf90.pc layout, and validation.
- [afar_modules/docs/wrappers.md](afar_modules/docs/wrappers.md): ftn/cc/CC wrapper behavior, offload arch injection, and overrides.
- [afar_modules/docs/module-generation.md](afar_modules/docs/module-generation.md): generating modulefiles, adding new AFAR drops, and config inputs.
- [afar_modules/docs/troubleshooting.md](afar_modules/docs/troubleshooting.md): common issues and diagnostics.
- [afar_modules/docs/testing.md](afar_modules/docs/testing.md): local test harness and repro layout.
- [afar_modules/docs/admin-handoff.md](afar_modules/docs/admin-handoff.md): site admin checklist for deployment and updates.
- [afar_modules/docs/documentation-plan.md](afar_modules/docs/documentation-plan.md): documentation maintenance plan and best practices.
- [paper/afar-prgenv.pdf](paper/afar-prgenv.pdf): AFAR module paper (PDF).

## Repository Layout (High Level)
```
assets/         # README images and overview graphics
afar_modules/   # AFAR module tree (modulefiles, wrappers, pkg-config)
  bin/            # compiler wrapper scripts (ftn/cc/CC)
  config/         # AFAR root + version mapping + Cray MPICH libdir
  docs/           # detailed documentation
  modulefiles/    # generated Lmod modulefiles
  pkgconfig/      # generated pkg-config files
  scripts/        # generator scripts
logs/           # test logs (untracked)
paper/          # paper sources and PDF
repro/          # repro cases for the test harness
scripts/        # test harness and helper scripts
.modules        # known-good module sequence (workspace)
```

## Maintenance Checklist (Short)
- Add new drops and regenerate: [afar_modules/docs/module-generation.md](afar_modules/docs/module-generation.md)
- Run the test harness (`scripts/run_afar_tests.sh --keep-going`); logs live in `logs/` and are untracked.
- Keep MPICH 8.x/9.x mapping current: [afar_modules/docs/mpich.md](afar_modules/docs/mpich.md)
- Verify wrapper behavior after changes: [afar_modules/docs/wrappers.md](afar_modules/docs/wrappers.md)
- Update admin-facing steps after PE/ROCm changes: [afar_modules/docs/admin-handoff.md](afar_modules/docs/admin-handoff.md)
- Refresh examples and tests: [afar_modules/docs/troubleshooting.md](afar_modules/docs/troubleshooting.md)
- Review pkg-config shims when library modules change: [afar_modules/docs/pkgconfig.md](afar_modules/docs/pkgconfig.md)

## Notes
- Use `.modules` in this workspace for the known-good module sequence.
- If PE/MPICH or AFAR versions change, update `.modules` to keep the sequence current.
- Regenerate modulefiles after AFAR drop or MPICH path changes:
  `afar_modules/scripts/generate_afar_modules.sh`

## Paper
- [paper/afar-prgenv.pdf](paper/afar-prgenv.pdf)

## Citation
```bibtex
@misc{AfarPrgenv2025,
  author = {Hernandez, Oscar and Elwasif, Wael},
  title = {Afar-prgenv: A configurable programming environment for AMD AFAR drops on Cray HPE systems},
  year = {2025},
  note = {Internal tool used at OLCF Frontier}
}
```
