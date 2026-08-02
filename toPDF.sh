#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$root"

python3 -B ./utl/paper/check-pdf-freshness.py renderer --root .
python3 -B ./utl/model/render-archimate-profile.py
./utl/paper/render-paper-figures.sh
md2pdf -- o2i.md -H acc/o2i.icl
python3 -B ./utl/paper/check-pdf-freshness.py seal \
  --root . \
  --pdf o2i.pdf \
  --manifest o2i.pdf.manifest.json
