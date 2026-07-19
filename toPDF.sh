#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$root"

./utl/render-paper-figures.sh
exec md2pdf -- o2i.md
