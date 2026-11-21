#!/usr/bin/env bash
#
# Author: Andrea Giachero <Andrea.Giachero@mib.infn.it>
# Desc  : Rename files replacing spaces with underscores in their names.
#         Only the file name is changed, never the directory it is in.
#
# Usage : despace "file with spaces.pdf" [more files ...]
#         despace *                      (all files in the current directory)

set -uo pipefail

if (( $# == 0 )); then
  echo "Usage: despace \"file with spaces\" [more files ...]" >&2
  exit 1
fi

failed=0
for file in "$@"; do
  if [[ ! -e $file && ! -L $file ]]; then
    echo "Not found: $file" >&2
    failed=$((failed + 1))
    continue
  fi

  file=${file%/}                  # allow "my dir/" as well as "my dir"
  dir=$(dirname -- "$file")
  base=$(basename -- "$file")
  new_base=${base// /_}

  [[ $base == "$new_base" ]] && continue      # no spaces, nothing to do

  if [[ $file == */* ]]; then new_file="$dir/$new_base"; else new_file=$new_base; fi
  if [[ -e $new_file || -L $new_file ]]; then
    echo "Skipping $file: $new_file already exists" >&2
    failed=$((failed + 1))
    continue
  fi

  mv -- "$file" "$new_file" && echo "$file -> $new_file"
done

(( failed == 0 ))
