#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT HUP INT TERM

pdflatex \
  -interaction=nonstopmode \
  -halt-on-error \
  -output-directory "$build" \
  "$root/utl/o2i-evidence-sequence.tex" >/dev/null

pdftoppm \
  -png \
  -r 240 \
  -singlefile \
  "$build/o2i-evidence-sequence.pdf" \
  "$root/img/O2I Nachweisfolge"
