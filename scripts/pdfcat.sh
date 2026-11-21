#!/usr/bin/env bash
#
# Author: Andrea Giachero <Andrea.Giachero@mib.infn.it>
# Date  : 14 Agosto 2010 (revised 2026)
# Desc  : Concatenate PDF files into a single PDF using Ghostscript.
#
# Usage:
#   pdfcat                         merge all *.pdf in the current directory
#                                  (natural order) into output.pdf
#   pdfcat a.pdf b.pdf             merge into output.pdf
#   pdfcat a.pdf b.pdf out.pdf     merge into out.pdf (last argument is the
#                                  output when it does not exist yet)
#   pdfcat -o out.pdf a.pdf b.pdf  explicit output file
#
# Options:
#   -o FILE   output file (default: output.pdf)
#   -f        overwrite the output file if it already exists
#   -p LEVEL  compression preset: screen, ebook, printer, prepress
#   -n        dry run: show the command without running it
#   -h        show this help

set -euo pipefail

DEFAULT_OUT="output.pdf"

usage() { sed -n '7,22s/^# \{0,1\}//p' "$0"; }
die()   { echo "pdfcat: $*" >&2; exit 1; }

outfile=""
force=0
dryrun=0
preset=""

while getopts "o:fp:nh" opt; do
  case $opt in
    o) outfile=$OPTARG ;;
    f) force=1 ;;
    p) preset=$OPTARG ;;
    n) dryrun=1 ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

command -v gs >/dev/null 2>&1 || die "Ghostscript (gs) is not installed"

if [[ -n $preset ]]; then
  case $preset in
    screen|ebook|printer|prepress) ;;
    *) die "invalid preset '$preset' (use screen, ebook, printer or prepress)" ;;
  esac
fi

# ---- Collect input files ----
inputs=()
if (( $# == 0 )); then
  # All PDFs in the current directory, natural order (file2 before file10).
  # Works with spaces in names and skips the output file itself.
  shopt -s nullglob nocaseglob
  out_check=${outfile:-$DEFAULT_OUT}
  while IFS= read -r -d '' f; do
    [[ $f -ef $out_check ]] && continue
    inputs+=("$f")
  done < <(printf '%s\0' *.pdf | sort -zV)
  shopt -u nullglob nocaseglob
  (( ${#inputs[@]} > 0 )) || die "the current directory contains no PDF file"
else
  inputs=("$@")
  # Legacy behavior: if no -o was given and the last argument does not
  # exist yet, treat it as the output file.
  if [[ -z $outfile ]] && (( $# > 1 )) && [[ ! -e ${!#} ]]; then
    outfile=${!#}
    unset 'inputs[-1]'
  fi
fi

outfile=${outfile:-$DEFAULT_OUT}

# ---- Sanity checks ----
for f in "${inputs[@]}"; do
  [[ -f $f ]] || die "input file not found: $f"
  [[ -r $f ]] || die "input file not readable: $f"
  [[ $f -ef $outfile ]] && die "output file '$outfile' is also an input"
done

if [[ -e $outfile && $force -eq 0 ]]; then
  die "'$outfile' already exists (use -f to overwrite)"
fi

# Ghostscript has no "--" end-of-options marker (it means something else),
# so protect file names starting with "-" by prefixing them with "./".
for i in "${!inputs[@]}"; do
  [[ ${inputs[i]} == -* ]] && inputs[i]="./${inputs[i]}"
done

# ---- Build the Ghostscript command ----
gs_cmd=(gs -dBATCH -dNOPAUSE -dQUIET -dSAFER -sDEVICE=pdfwrite)
[[ -n $preset ]] && gs_cmd+=("-dPDFSETTINGS=/$preset")

echo " Input files (${#inputs[@]}):"
printf '   %s\n' "${inputs[@]}"
echo " Output file: $outfile"

if (( dryrun )); then
  printf ' Command:'
  printf ' %q' "${gs_cmd[@]}" "-sOutputFile=$outfile" "${inputs[@]}"
  echo
  exit 0
fi

# Write to a temporary file first, so a failed run never leaves a
# truncated output behind or destroys an existing file.
tmp=$(mktemp --tmpdir="$(dirname -- "$outfile")" .pdfcat.XXXXXX.pdf)
trap 'rm -f -- "$tmp"' EXIT

"${gs_cmd[@]}" "-sOutputFile=$tmp" "${inputs[@]}" || die "Ghostscript failed"
mv -f -- "$tmp" "$outfile"
trap - EXIT

echo " Done: $(du -h -- "$outfile" | cut -f1)"
