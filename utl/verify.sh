#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/o2i-verify.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [all|governance|model|haskell|paper]\n' "$0" >&2
  exit 2
fi

stage=${1:-all}
case "$stage" in
  all | governance | model | haskell | paper) ;;
  *)
    printf 'Usage: %s [all|governance|model|haskell|paper]\n' "$0" >&2
    exit 2
    ;;
esac

info() {
  printf '[o2i|info] %s\n' "$1"
}

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '[o2i|error] Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

cd "$root"

git_worktree=false
git_clean=false
source_revision=
diff_base=
if command -v git >/dev/null 2>&1 && \
  git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_worktree=true
  source_revision=$(git rev-parse --verify HEAD)
  if [ -z "$(git status --porcelain --untracked-files=all)" ]; then
    git_clean=true
  fi
  info "Checking repository diff."
  git diff --check HEAD --
  diff_base=${O2I_DIFF_BASE:-}
  if [ -z "$diff_base" ] || \
    ! git cat-file -e "$diff_base^{commit}" 2>/dev/null; then
    if git cat-file -e 'HEAD^{commit}^' 2>/dev/null; then
      diff_base=HEAD^
    else
      diff_base=
    fi
  fi
  if [ -n "$diff_base" ]; then
    git diff --check "${diff_base}..HEAD" --
  fi
else
  info "Git metadata unavailable; skipping worktree-only diff checks."
fi

verify_governance() {
  require python3

  info "Checking O2I change governance."
  python3 -B -m unittest discover \
    -s utl -p 'test_change_governance.py'
  python3 -B utl/change-governance.py validate
}

verify_model() {
  require python3

  info "Checking ArchiMate model contracts and extractor tests."
  python3 -B utl/extract-archimate-view.py --preset all --check
  python3 -B -m unittest discover \
    -s utl -p 'test_extract_archimate_view.py'
}

verify_haskell() {
  for command in cabal hindent python3; do
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

  info "Checking package licenses and metadata."
  ./utl/check-package-licenses.sh
  for package in \
    spc/lib/build-provenance \
    spc/lib/core \
    spc/lib/inspection \
    spc/lib/adapter/amx \
    spc/cli; do
    (cd "$package" && cabal --config-file="$cabal_config" -v0 check)
  done

  build="$work/dist-newstyle"
  logs="$work/logs"
  mkdir -p "$build" "$logs"
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

  executable=$(
    cabal --config-file="$cabal_config" -v0 --project-dir=spc \
      list-bin o2i-cli:exe:o2i --builddir="$build"
  )
  if [ "$git_worktree" = true ] && [ "$git_clean" = true ]; then
    info "Checking the Git-bound executable revision."
    actual_revision=$("$executable" --build-revision)
    if [ "$actual_revision" != "$source_revision" ]; then
      printf '[o2i|error] Executable revision does not match Git HEAD.\n' >&2
      exit 1
    fi
  elif [ "$git_worktree" = false ]; then
    if [ -z "${O2I_BUILD_REVISION:-}" ]; then
      printf '%s\n' \
        '[o2i|error] O2I_BUILD_REVISION is required without Git metadata.' >&2
      exit 1
    fi
    info "Checking the explicitly bound executable revision."
    actual_revision=$("$executable" --build-revision)
    expected_revision=$(
      printf '%s' "$O2I_BUILD_REVISION" | tr '[:upper:]' '[:lower:]'
    )
    if [ "$actual_revision" != "$expected_revision" ]; then
      printf '%s\n' \
        '[o2i|error] Executable revision does not match build input.' >&2
      exit 1
    fi
  else
    info "Checking that a dirty worktree cannot claim a bound revision."
    if "$executable" --build-revision >/dev/null 2>&1; then
      printf '%s\n' \
        '[o2i|error] Dirty worktree produced a revision-bound executable.' >&2
      exit 1
    fi
  fi

  info "Checking external Haskell API contracts."
  python3 -B -m unittest discover \
    -s utl -p 'test_check_haskell_api_contracts.py'
  python3 -B utl/check_haskell_api_contracts.py \
    --project-dir "$root/spc" \
    --builddir "$build"

  info "Building Haskell API documentation."
  cabal --config-file="$cabal_config" -v0 --project-dir=spc haddock all \
    --builddir="$build" \
    --build-log="$build_log"

  info "Checking Haskell formatting."
  find spc \
    -path '*/dist-newstyle' -prune -o \
    -type f -name '*.hs' \
    -exec hindent --line-length 80 --validate {} +
}

verify_paper() {
  for command in \
    md2pdf pandoc pandoc-crossref pandoc-include pdflatex pdftoppm python3; do
    require "$command"
  done

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
}

case "$stage" in
  governance) verify_governance ;;
  model) verify_model ;;
  haskell) verify_haskell ;;
  paper) verify_paper ;;
  all)
    verify_governance
    verify_model
    verify_haskell
    verify_paper
    ;;
esac

printf '[o2i|success] Verification stage passed: %s.\n' "$stage"
