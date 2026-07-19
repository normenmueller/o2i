#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/o2i-verify.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

info() {
  printf '[o2i|info] %s\n' "$1"
}

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '[o2i|error] Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

for command in \
  cabal git hindent md2pdf pandoc pandoc-crossref pandoc-include \
  pdflatex pdftoppm python3; do
  require "$command"
done

cabal_config="$work/cabal.config"
cabal_logs="$work/cabal-logs"
mkdir -p "$cabal_logs"
if [ -f "${CABAL_CONFIG:-$HOME/.cabal/config}" ]; then
  sed '/^[[:space:]]*logs-dir:/d' \
    "${CABAL_CONFIG:-$HOME/.cabal/config}" >"$cabal_config"
else
  cabal --config-file="$cabal_config" user-config init
fi
printf '\nlogs-dir: %s\n' "$cabal_logs" >>"$cabal_config"
export CABAL_CONFIG="$cabal_config"

cd "$root"

info "Checking repository diff."
git diff --check HEAD --

info "Checking ArchiMate model contracts and extractor tests."
python3 -B utl/extract-archimate-view.py --preset all --check
python3 -B -m unittest discover -s utl -p 'test_*.py'

info "Checking package licenses and metadata."
./utl/check-package-licenses.sh
for package in \
  spc/lib/core \
  spc/lib/inspection \
  spc/lib/adapter/amx \
  spc/cli; do
  (cd "$package" && cabal --config-file="$cabal_config" -v0 check)
done

build="$work/dist-newstyle"
logs="$work/logs"
mkdir -p "$logs"
build_log="$logs/\$compiler-\$pkgid.log"
test_log="$logs/\$compiler-\$pkgid-\$test-suite.log"

info "Building and testing the Haskell specification with warnings as errors."
cabal --config-file="$cabal_config" -v0 --project-dir=spc build all \
  --builddir="$build" \
  --build-log="$build_log" \
  --ghc-options=-Werror
cabal --config-file="$cabal_config" -v0 --project-dir=spc test all \
  --builddir="$build" \
  --build-log="$build_log" \
  --test-log="$test_log" \
  --ghc-options=-Werror

info "Building Haskell API documentation."
cabal --config-file="$cabal_config" -v0 --project-dir=spc haddock all \
  --builddir="$build" \
  --build-log="$build_log"

info "Checking Haskell formatting."
find spc \
  -path '*/dist-newstyle' -prune -o \
  -type f -name '*.hs' \
  -exec hindent --line-length 80 --validate {} +

info "Checking the expanded White Paper source."
pandoc o2i.md --filter pandoc-include -t markdown >/dev/null

paper="$work/paper"
mkdir -p "$paper/spc/lib/core"
cp o2i.md README.md ACKNOWLEDGEMENTS.md "$paper/"
cp -R acc img "$paper/"
cp -R spc/lib/core/src "$paper/spc/lib/core/"

info "Rendering TikZ figures in an isolated paper workspace."
./utl/render-paper-figures.sh "$paper"
for figure in \
  "O2I Nachweisfolge.png" \
  "O2I Frameworkarchitektur.png"; do
  if [ ! -s "$paper/img/$figure" ]; then
    printf '[o2i|error] Figure rendering produced no output: %s\n' "$figure" >&2
    exit 1
  fi
done

info "Building the White Paper in an isolated paper workspace."
(cd "$paper" && md2pdf -o "$work/o2i.pdf" -- o2i.md)
if [ ! -s "$work/o2i.pdf" ]; then
  printf '[o2i|error] White Paper build produced no PDF.\n' >&2
  exit 1
fi

printf '[o2i|success] All verification stages passed.\n'
