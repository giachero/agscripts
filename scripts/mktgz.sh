#!/usr/bin/env bash
#
# Author: Andrea Giachero <Andrea.Giachero@mib.infn.it>
# Date  : 08 April 2010 (revised 2026, formerly webcpy)
# Desc  : Create a timestamped .tgz archive of each file or directory given,
#         in the current directory: mydir -> mydir_2026-11-21-10.30.00.tgz
#
# Usage : mktgz [-v] FILE_OR_DIR [...]
#
# Options:
#   -v   list the files while archiving
#   -h   show this help

set -uo pipefail

usage() { sed -n '8,12s/^# \{0,1\}//p' "$0"; }

verbose=""
targets=()
for arg in "$@"; do
  case $arg in
    -v)        verbose=v ;;
    -h|--help) usage; exit 0 ;;
    --noweb)   ;;   # accepted for compatibility with the old webcpy
    -*)        echo "mktgz: unknown option: $arg (see -h)" >&2; exit 1 ;;
    *)         targets+=("$arg") ;;
  esac
done

if (( ${#targets[@]} == 0 )); then
  usage >&2
  exit 1
fi

stamp=$(date +%Y-%m-%d-%H.%M.%S)
failed=0

for target in "${targets[@]}"; do
  if [[ ! -e $target ]]; then
    echo "Not found: $target, skipping" >&2
    failed=$((failed + 1))
    continue
  fi

  target=${target%/}                        # mydir/ -> mydir
  parent=$(dirname -- "$target")
  base=$(basename -- "$target")

  # Drop the extension for files only (notes.txt -> notes);
  # directory names like project-v1.2 are kept as they are
  name=$base
  [[ -f $target && $name == ?*.* ]] && name=${name%.*}

  archive="${name}_${stamp}.tgz"
  if [[ -e $archive ]]; then
    echo "Skipping $target: $archive already exists" >&2
    failed=$((failed + 1))
    continue
  fi

  echo "Creating $archive"
  # -C stores paths relative to the parent folder, so the archive
  # contains "mydir/..." instead of the full original path
  if ! tar -cz${verbose}f "$archive" -C "$parent" -- "$base"; then
    echo "  tar failed for $target" >&2
    rm -f -- "$archive"
    failed=$((failed + 1))
  fi
done

(( failed == 0 ))
