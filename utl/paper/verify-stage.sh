#!/bin/sh
# Lazy-loaded by utl/verify.sh only for the paper stage.
# Interface: verify_paper_stage ROOT WORK; the strict runner supplies info,
# require, the existing workspace and its cleanup. Do not execute standalone.

verify_paper_stage() {
  root=$1
  work=$2
  for command in \
    md2pdf pandoc pandoc-crossref pandoc-include pdflatex pdfinfo pdftoppm \
    pdftotext pdftohtml python3; do
    require "$command"
  done

  info "Checking White Paper source contracts."
  python3 -B utl/paper/check-pdf-freshness.py sources --root .

  info "Checking the expanded White Paper source."
  (cd doc/paper && pandoc o2i.md --filter pandoc-include -t markdown) >/dev/null
  python3 -B -m unittest discover \
    -s utl/paper -p 'test_check_paper_assets.py'
  python3 -B -m unittest discover \
    -s utl/paper -p 'test_check_pdf_freshness.py'

  info "Checking inline code through the O2I publication renderer."
  python3 -B utl/paper/check-inline-code.py --root "$root"

  paper="$work/paper"
  mkdir -p "$paper/spec/lib/core" "$paper/doc/paper"
  cp README.md ACKNOWLEDGEMENTS.md "$paper/"
  cp doc/paper/o2i.md "$paper/doc/paper/"
  cp -R doc/resources doc/images "$paper/doc/"
  cp -R spec/lib/core/src "$paper/spec/lib/core/"

  info "Rendering TikZ figures in an isolated paper workspace."
  ./utl/paper/render-paper-figures.sh "$paper"
  for figure in \
    "O2I Nachweisfolge.png" \
    "O2I Frameworkarchitektur.png"; do
    if [ ! -s "$paper/doc/images/$figure" ]; then
      printf '[o2i|error] Figure rendering produced no output: %s\n' "$figure" >&2
      exit 1
    fi
  done

  info "Checking White Paper image resources."
  if ! (cd "$paper/doc/paper" && pandoc o2i.md --filter pandoc-include -t json) \
    >"$work/paper.json" 2>"$work/pandoc-include.log"; then
    cat "$work/pandoc-include.log" >&2
    exit 1
  fi
  cat "$work/pandoc-include.log"
  if grep -Fq "[WARNING] Included file not found:" \
    "$work/pandoc-include.log"; then
    printf '[o2i|error] White Paper contains an unresolved include.\n' >&2
    exit 1
  fi
  python3 -B utl/paper/check-paper-assets.py \
    --root "$paper" \
    --source-directory "$paper/doc/paper" \
    "$work/paper.json"

  info "Building the White Paper in an isolated paper workspace."
  (cd "$paper/doc/paper" && md2pdf -o "$work/o2i.pdf" -- o2i.md -H ../resources/o2i.icl)
  if [ ! -s "$work/o2i.pdf" ]; then
    printf '[o2i|error] White Paper build produced no PDF.\n' >&2
    exit 1
  fi
  python3 -B utl/paper/check-pdf-freshness.py check \
    --root . \
    --versioned doc/paper/o2i.pdf \
    --rendered "$work/o2i.pdf" \
    --manifest doc/paper/o2i.pdf.manifest.json
}
