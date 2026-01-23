#!/usr/bin/env bash
set -euo pipefail

texlive_core_module="${TEXLIVE_CORE_MODULE:-Core/24.00}"
texlive_module="${TEXLIVE_MODULE:-texlive/20220321}"

if ! command -v module >/dev/null 2>&1; then
  echo "ERROR: module command not found in PATH." >&2
  exit 1
fi

if ! module load "${texlive_core_module}"; then
  echo "ERROR: failed to load module ${texlive_core_module}." >&2
  exit 1
fi

if ! module load "${texlive_module}"; then
  echo "ERROR: failed to load module ${texlive_module}." >&2
  echo "Try: module spider texlive" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
paper_dir="${script_dir}/../paper"

bibtex_cmd=":"
if grep -R -h -E '\\cite' "${paper_dir}"/*.tex "${paper_dir}"/src/*.tex 2>/dev/null | \
  grep -v '^[[:space:]]*%' >/dev/null; then
  bibtex_cmd="bibtex"
fi

make -C "${paper_dir}" clean
make -C "${paper_dir}" BIBTEX="${bibtex_cmd}"
