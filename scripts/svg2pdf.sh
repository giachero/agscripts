#!/usr/bin/env bash
#
# Author: Andrea Giachero <Andrea.Giachero@mib.infn.it>
# Date  : 08 April 2010 (revised 2026)
# Desc  : Convert SVG files to PDF (and optionally EPS and PNG) using
#         Inkscape. The PDF is cropped to the drawing and, if Ghostscript
#         is available, optimized for print (PDF 1.4, prepress settings).
#
# Usage : svg2pdf [--eps] [--png] [--dpi N] [file.svg ...]
#         With no files, converts every *.svg in the current directory.
#
# Options:
#   --eps     also create an EPS file (requires pdftops, from poppler-utils)
#   --png     also create a PNG file
#   --dpi N   PNG resolution (default: 300)
#   -h        show this help

set -uo pipefail

usage() { sed -n '9,16s/^# \{0,1\}//p' "$0"; }
die()   { echo "svg2pdf: $*" >&2; exit 1; }

eps=0
png=0
dpi=300
files=()

while (( $# > 0 )); do
  case $1 in
    --eps)     eps=1 ;;
    --png)     png=1 ;;
    --dpi)     [[ ${2:-} =~ ^[0-9]+$ ]] || die "--dpi needs a number"
               dpi=$2; shift ;;
    -h|--help) usage; exit 0 ;;
    -*)        die "unknown option: $1 (see -h)" ;;
    *)         files+=("$1") ;;
  esac
  shift
done

# ---- Check the required tools before starting ----
command -v inkscape >/dev/null 2>&1 || die "Inkscape not found (sudo apt install inkscape)"
if (( eps )); then
  command -v pdftops >/dev/null 2>&1 || die "pdftops not found (sudo apt install poppler-utils)"
fi
have_gs=0
command -v gs >/dev/null 2>&1 && have_gs=1

# ---- Default: all SVG files in the current directory ----
if (( ${#files[@]} == 0 )); then
  shopt -s nullglob
  files=(*.svg)
  shopt -u nullglob
  (( ${#files[@]} > 0 )) || die "the current directory contains no SVG file"
fi

failed=0
for svg in "${files[@]}"; do
  if [[ ! -f $svg ]]; then
    echo "File $svg not found, skipping" >&2
    failed=$((failed + 1))
    continue
  fi

  # Remove only the final extension, keeping the directory:
  # ./figs/plot.v2.svg -> ./figs/plot.v2
  name=${svg%.*}

  echo "Converting $svg -> $name.pdf"
  if ! inkscape "$svg" --export-area-drawing --export-type=pdf \
       --export-filename="$name.pdf" >/dev/null 2>&1; then
    echo "  Inkscape failed on $svg, skipping" >&2
    failed=$((failed + 1))
    continue
  fi

  # Optimize the PDF with Ghostscript; keep the Inkscape version if it fails
  if (( have_gs )); then
    tmp="$name.tmp.$$.pdf"
    if gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/prepress \
          -dNOPAUSE -dQUIET -dBATCH -dSAFER -sOutputFile="$tmp" "$name.pdf"; then
      mv -f -- "$tmp" "$name.pdf"
    else
      rm -f -- "$tmp"
      echo "  Ghostscript optimization failed, keeping the Inkscape PDF" >&2
    fi
  fi

  if (( eps )); then
    echo "Converting $svg -> $name.eps"
    pdftops -eps "$name.pdf" "$name.eps" || { echo "  EPS conversion failed" >&2; failed=$((failed + 1)); }
  fi

  if (( png )); then
    echo "Converting $svg -> $name.png ($dpi dpi)"
    inkscape "$svg" --export-area-drawing --export-type=png --export-dpi="$dpi" \
      --export-filename="$name.png" >/dev/null 2>&1 \
      || { echo "  PNG conversion failed" >&2; failed=$((failed + 1)); }
  fi
done

(( failed == 0 )) || { echo "svg2pdf: $failed problem(s), see messages above" >&2; exit 1; }
