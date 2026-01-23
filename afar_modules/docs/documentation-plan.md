# Documentation Plan

This plan keeps AFAR module docs maintainable as new drops, PE versions, and
wrapper behavior evolve.

## Document Set (Recommended)
- [../../README.md](../../README.md): entry point and doc map.
- [docs/user-guide.md](user-guide.md): user workflows and build examples.
- [docs/pkgconfig.md](pkgconfig.md): `pkg-config` primer, `.pc` format, and shims.
- [docs/architecture.md](architecture.md): module load and runtime architecture.
- [docs/module-generation.md](module-generation.md): generator inputs, outputs, and update steps.
- [docs/wrappers.md](wrappers.md): wrapper behavior and environment overrides.
- [docs/mpich.md](mpich.md): MPICH 8.x vs 9.x behavior and validation.
- [docs/troubleshooting.md](troubleshooting.md): diagnostics and example tests.
- [docs/testing.md](testing.md): test harness and repro layout.
- [docs/admin-handoff.md](admin-handoff.md): admin checklist for deployment and updates.
- [../../paper/afar-prgenv.pdf](../../paper/afar-prgenv.pdf): AFAR module paper (PDF).

## Update Triggers
Update docs whenever:
- A new AFAR drop is added (update user guide examples and module generation).
- Cray MPICH major changes (update mpich mapping and tests).
- Wrapper behavior changes (update wrappers and architecture docs).
- Test harness or repro changes (update testing and troubleshooting docs).
- ROCm runtime layout changes (update fallback guidance).
- Library module changes affect `.pc` metadata or shims (update pkgconfig doc).

## Best Practices
- Single source of truth: describe behavior in generator/wrappers, not in
  scattered README fragments.
- Keep examples current: update versions in example commands after each PE or
  AFAR drop change.
- Separate user vs admin content: user guide should stay short; admin and
  generator details live in their own docs.
- Track invariants: document required directories (`include/mpich3.4a2`,
  `include/mpich4.3.1`) and expected env vars (`AFAR_*`, `CRAY_*`).
- Avoid duplication: link between docs rather than repeating long sections.

## Suggested Documentation Workflow
1) Make code or module changes.
2) Update the relevant doc(s) based on the change type.
3) Run a quick sanity build to validate any example command snippets.
4) Keep the doc map in [../../README.md](../../README.md) in sync with new files.

## Doc Review Checklist
- Are example module versions updated?
- Does [docs/mpich.md](mpich.md) match the current MPICH major mapping?
- Do wrappers docs match `bin/ftn`, `bin/cc`, `bin/CC` behavior?
- Do troubleshooting steps mention the latest common failures?
- Are pkg-config changes reflected in [docs/pkgconfig.md](pkgconfig.md)?
