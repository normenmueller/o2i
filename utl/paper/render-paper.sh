#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$root"

python3 -B ./utl/paper/check-pdf-freshness.py renderer --root .
./utl/paper/render-paper-figures.sh
(cd doc/paper && md2pdf -- o2i.md -H ../resources/o2i.icl)
python3 -B ./utl/paper/check-pdf-freshness.py seal \
  --root . \
  --pdf doc/paper/o2i.pdf \
  --manifest doc/paper/o2i.pdf.manifest.json
