#!/bin/sh

set -eu

if [ "$#" -gt 1 ]; then
  printf '[o2i|error] Usage: %s [paper-root]\n' "$0" >&2
  exit 2
fi

root=${1:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT HUP INT TERM

render() {
  source=$1
  target=$2
  stem=$(basename "$source" .tex)

  pdflatex \
    -interaction=nonstopmode \
    -halt-on-error \
    -output-directory "$build" \
    "$root/$source" >/dev/null

  pdftoppm \
    -png \
    -r 240 \
    -singlefile \
    "$build/$stem.pdf" \
    "$root/$target"
}

render "acc/o2i-evidence-sequence.tex" "img/O2I Nachweisfolge"
render "acc/o2i-framework-architecture.tex" "img/O2I Frameworkarchitektur"
