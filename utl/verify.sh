#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/o2i-verify.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [all|licensing|governance|model|foundation|haskell|paper]\n' "$0" >&2
  exit 2
fi

stage=${1:-all}
case "$stage" in
  all | licensing | governance | model | foundation | haskell | paper) ;;
  *)
    printf 'Usage: %s [all|licensing|governance|model|foundation|haskell|paper]\n' "$0" >&2
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

require_version() {
  subject=$1
  expected=$2
  actual=$3
  if [ "$actual" != "$expected" ]; then
    printf '[o2i|error] %s %s is required; found %s.\n' \
      "$subject" "$expected" "${actual:-unknown}" >&2
    exit 1
  fi
}

cd "$root"

diff_base=
if command -v git >/dev/null 2>&1 && \
  git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
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

verify_licensing() {
  require reuse

  reuse_entry=$(command -v reuse)
  reuse_python=$(sed -n '1s/^#!\([^[:space:]]*\).*$/\1/p' "$reuse_entry")
  if [ -z "$reuse_python" ] || [ ! -x "$reuse_python" ]; then
    printf '[o2i|error] Cannot resolve the Python runtime of REUSE 6.2.0.\n' >&2
    exit 1
  fi

  info "Checking canonical license-text integrity."
  ./utl/licensing/check-license-texts.sh

  actual_version=$(reuse --version | sed -n '1s/^reuse, version //p')
  if [ "$actual_version" != "6.2.0" ]; then
    printf '[o2i|error] REUSE 6.2.0 is required; found %s.\n' \
      "${actual_version:-unknown}" >&2
    exit 1
  fi

  info "Testing the repository licensing-assignment contract."
  "$reuse_python" -E -B -m unittest discover \
    -s utl/licensing -p 'test_license_assignments.py'

  info "Checking exactly one path-based license assignment per file."
  "$reuse_python" -E -B utl/licensing/check_license_assignments.py

  info "Checking exhaustive repository licensing with REUSE 3.3."
  reuse --no-multiprocessing lint

  info "Checking package-local Apache-2.0 license copies."
  ./utl/haskell/check-package-licenses.sh
}

verify_governance() {
  require python3

  info "Checking O2I change governance."
  python3 -B -m unittest discover \
    -s utl/governance -p 'test_github_governance.py'
  python3 -B -m unittest discover \
    -s utl/verification -p 'test_verification_scope.py'
}

verify_model() {
  require python3

  info "Checking ArchiMate model hygiene, View contracts, and tests."
  python3 -B utl/model/audit-archimate-model.py
  python3 -B utl/model/extract-archimate-view.py --preset all --check
  python3 -B -m unittest discover \
    -s utl/model -p 'test_archimate_profile.py'
  python3 -B -m unittest discover \
    -s utl/model -p 'test_render_archimate_profile.py'
  python3 -B utl/model/render-archimate-profile.py --check
  python3 -B -m unittest discover \
    -s utl/model -p 'test_*archimate_model.py'
  python3 -B -m unittest discover \
    -s utl/model -p 'test_extract_archimate_view.py'
  python3 -B -m unittest discover \
    -s utl/model -p 'test_check_executable_views.py'
}

verify_haskell() {
  scope=${1:-complete}
  case "$scope" in
    foundation)
      project_file=cabal.foundation.project
      project_contract=spc/cabal.foundation.project
      freeze_contract=spc/cabal.foundation.project.freeze
      package_paths='spc/lib/core spc/ctr/archimate spc/lib/operation spc/lib/adapter/amx'
      ;;
    complete)
      project_file=cabal.project
      project_contract=spc/cabal.project
      freeze_contract=spc/cabal.project.freeze
      package_paths='spc/lib/core spc/lib/inspection spc/ctr/archimate spc/lib/operation spc/lib/adapter/amx spc/cli'
      ;;
    *)
      printf '[o2i|error] Unknown Haskell verification scope: %s.\n' \
        "$scope" >&2
      exit 2
      ;;
  esac

  for command in cabal ghc ghc-pkg hindent python3 tar; do
    require "$command"
  done

  info "Checking the exact Haskell toolchain."
  require_version \
    "spc/.ghc-version" "9.10.3" "$(tr -d '\r\n' <spc/.ghc-version)"
  require_version "GHC" "9.10.3" "$(ghc --numeric-version)"
  require_version "Cabal" "3.16.1.0" "$(cabal --numeric-version)"
  require_version \
    "base" "4.20.2.0" "$(ghc-pkg field base version --simple-output)"

  cabal_config="$work/cabal.config"
  cabal_logs="$work/cabal-logs"
  mkdir -p "$cabal_logs"
  if [ -f "${CABAL_CONFIG:-$HOME/.cabal/config}" ]; then
    sed \
      -e '/^[[:space:]]*logs-dir:/d' \
      -e '/^[[:space:]]*build-summary:/d' \
      "${CABAL_CONFIG:-$HOME/.cabal/config}" >"$cabal_config"
  else
    cabal --config-file="$cabal_config" user-config init
  fi
  printf '\nlogs-dir: %s\n' "$cabal_logs" >>"$cabal_config"
  export CABAL_CONFIG="$cabal_config"

  run_project_cabal() {
    cabal --config-file="$cabal_config" -v0 \
      --project-dir=spc \
      --project-file="$project_file" \
      "$@"
  }

  info "Checking compiled Haskell contract artifacts."
  python3 -B spc/lib/core/contract/compile.py --check
  python3 -B -m unittest discover \
    -s spc/lib/core/contract -p 'test_compile.py'
  python3 -B spc/ctr/archimate/contract/compile.py \
    --core-companion spc/lib/core/semantics.json \
    --check
  O2I_CORE_COMPANION=spc/lib/core/semantics.json \
    python3 -B -m unittest discover \
    -s spc/ctr/archimate/contract -p 'test_compile.py'
  python3 -B spc/lib/operation/contract/compile.py \
    --profile-companion spc/ctr/archimate/profile.json \
    --check
  O2I_PROFILE_COMPANION=spc/ctr/archimate/profile.json \
    python3 -B -m unittest discover \
    -s spc/lib/operation/contract -p 'test_compile.py'

  info "Checking package metadata."
  for package in $package_paths; do
    (cd "$package" && cabal --config-file="$cabal_config" -v0 check)
  done

  build="$work/dist-newstyle"
  logs="$work/logs"
  mkdir -p "$build" "$logs"
  build_log="$logs/\$compiler-\$pkgid.log"
  test_log="$logs/\$compiler-\$pkgid-\$test-suite.log"

  info "Building and testing the Haskell specification with warnings as errors."
  if [ "$scope" = foundation ]; then
    run_project_cabal build \
      o2i-core o2i-archimate-profile o2i-operation o2i-amx \
      --builddir="$build" \
      --build-log="$build_log" \
      --ghc-options=-Werror
  else
    run_project_cabal build all \
      --builddir="$build" \
      --build-log="$build_log" \
      --ghc-options=-Werror
  fi
  python3 -B utl/haskell/check_cabal_plan.py \
    --project "$project_contract" \
    --freeze "$freeze_contract" \
    --plan "$build/cache/plan.json"
  if [ "$scope" = foundation ]; then
    run_project_cabal test \
      o2i-core o2i-archimate-profile o2i-operation o2i-amx \
      --builddir="$build" \
      --build-log="$build_log" \
      --test-log="$test_log" \
      --ghc-options=-Werror
  else
    run_project_cabal test all \
      --builddir="$build" \
      --build-log="$build_log" \
      --test-log="$test_log" \
      --ghc-options=-Werror
  fi

  if [ "$scope" = complete ]; then
    info "Checking executable Candidate View acceptance."
    python3 -B -m unittest discover \
      -s utl/model -p 'test_check_executable_views.py'
    o2i_bin=$(run_project_cabal list-bin o2i --builddir="$build")
    python3 -B utl/model/check-executable-views.py \
      --o2i "$o2i_bin" \
      --model mdl/o2i.archimate
  fi

  info "Checking external Haskell API contracts."
  python3 -B -m unittest discover \
    -s utl/haskell -p 'test_*.py'
  if [ "$scope" = foundation ]; then
  python3 -B utl/haskell/check_haskell_api_contracts.py \
      --project-dir "$root/spc" \
      --project-file "$project_file" \
      --builddir "$build" \
      --package o2i-core \
      --package o2i-archimate-profile \
      --package o2i-operation
  else
    python3 -B utl/haskell/check_haskell_api_contracts.py \
      --project-dir "$root/spc" \
      --builddir "$build"
  fi

  info "Building Haskell API documentation."
  if [ "$scope" = foundation ]; then
    haddock_log="$logs/foundation-haddock.log"
    if run_project_cabal haddock \
        o2i-core o2i-archimate-profile o2i-operation o2i-amx \
        --builddir="$build" \
        --build-log="$build_log" >"$haddock_log" 2>&1; then
      cat "$haddock_log"
    else
      cat "$haddock_log" >&2
      exit 1
    fi
    if grep -Eq \
      'Missing documentation for:|^Warning: .* (is ambiguous|is out of scope)\.|^Warning: .*could not find link destinations for:' \
      "$haddock_log"; then
      printf '[o2i|error] Foundation Haddock reported a documentation or link warning.\n' >&2
      exit 1
    fi
  else
    run_project_cabal haddock all \
      --builddir="$build" \
      --build-log="$build_log"
  fi

  info "Checking independently buildable Haskell source distributions."
  source_dist="$work/source-dist"
  mkdir -p "$source_dist"
  run_project_cabal sdist \
    o2i-core o2i-archimate-profile o2i-operation o2i-amx \
    --output-directory="$source_dist"

  set -- "$source_dist"/o2i-core-*.tar.gz
  if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    printf '[o2i|error] Expected exactly one o2i-core source archive.\n' >&2
    exit 1
  fi
  core_archive=$1

  set -- "$source_dist"/o2i-archimate-profile-*.tar.gz
  if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    printf '[o2i|error] Expected exactly one ArchiMate Profile source archive.\n' >&2
    exit 1
  fi
  profile_archive=$1

  set -- "$source_dist"/o2i-operation-*.tar.gz
  if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    printf '[o2i|error] Expected exactly one Operation source archive.\n' >&2
    exit 1
  fi
  operation_archive=$1

  set -- "$source_dist"/o2i-amx-*.tar.gz
  if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    printf '[o2i|error] Expected exactly one AMX source archive.\n' >&2
    exit 1
  fi
  amx_archive=$1

  core_inventory="$source_dist/core-inventory.txt"
  profile_inventory="$source_dist/profile-inventory.txt"
  operation_inventory="$source_dist/operation-inventory.txt"
  amx_inventory="$source_dist/amx-inventory.txt"
  tar -tzf "$core_archive" >"$core_inventory"
  tar -tzf "$profile_archive" >"$profile_inventory"
  tar -tzf "$operation_archive" >"$operation_inventory"
  tar -tzf "$amx_archive" >"$amx_inventory"
  core_root=$(sed -n '1s#/.*##p' "$core_inventory")
  profile_root=$(sed -n '1s#/.*##p' "$profile_inventory")
  operation_root=$(sed -n '1s#/.*##p' "$operation_inventory")
  amx_root=$(sed -n '1s#/.*##p' "$amx_inventory")
  if ! grep -Eq '/semantic-diagnostic-evidence\.json$' "$core_inventory"; then
    printf '[o2i|error] Core source archive lacks the diagnostic companion.\n' >&2
    exit 1
  fi
  if ! grep -Eq \
    '/contract/generated/o2i\.core\.semantic-diagnostic-evidence-v1\.json$' \
    "$core_inventory"; then
    printf '[o2i|error] Core source archive lacks the generated diagnostic inventory.\n' >&2
    exit 1
  fi
  if ! grep -Eq '/profile\.json$' "$profile_inventory"; then
    printf '[o2i|error] ArchiMate Profile source archive lacks profile.json.\n' >&2
    exit 1
  fi
  if ! grep -Eq \
    '/src/O2I/ArchiMate/Profile/Internal/Generated\.hs$' \
    "$profile_inventory"; then
    printf '[o2i|error] ArchiMate Profile source archive lacks generated Haskell.\n' >&2
    exit 1
  fi
  if ! grep -Eq '/contract/compile\.py$' "$profile_inventory" || \
    ! grep -Eq '/contract/test_compile\.py$' "$profile_inventory"; then
    printf '[o2i|error] ArchiMate Profile source archive lacks compiler tooling.\n' >&2
    exit 1
  fi

  source_project="$source_dist/project"
  mkdir -p "$source_project"
  tar -xzf "$core_archive" -C "$source_project"
  tar -xzf "$profile_archive" -C "$source_project"
  tar -xzf "$operation_archive" -C "$source_project"
  tar -xzf "$amx_archive" -C "$source_project"
  if [ ! -d "$source_project/$core_root" ] || \
    [ ! -d "$source_project/$profile_root" ] || \
    [ ! -d "$source_project/$operation_root" ] || \
    [ ! -d "$source_project/$amx_root" ]; then
    printf '[o2i|error] Cannot resolve unpacked Haskell source archives.\n' >&2
    exit 1
  fi
  python3 -B utl/haskell/check_haskell_api_contracts.py \
    --core-package-root "$source_project/$core_root"
  printf 'packages:\n  ./%s\n  ./%s\n  ./%s\n  ./%s\n\nindex-state: 2026-08-07T18:07:13Z\n' \
    "$core_root" "$profile_root" "$operation_root" "$amx_root" \
    >"$source_project/cabal.project"
  cp "$freeze_contract" "$source_project/cabal.project.freeze"
  python3 -B "$source_project/$core_root/contract/compile.py" --check
  python3 -B -m unittest discover \
    -s "$source_project/$core_root/contract" \
    -p 'test_compile.py'
  python3 -B "$source_project/$profile_root/contract/compile.py" \
    --core-companion "$source_project/$core_root/semantics.json" \
    --check
  O2I_CORE_COMPANION="$source_project/$core_root/semantics.json" \
    python3 -B -m unittest discover \
    -s "$source_project/$profile_root/contract" \
    -p 'test_compile.py'
  python3 -B "$source_project/$operation_root/contract/compile.py" \
    --profile-companion "$source_project/$profile_root/profile.json" \
    --check
  O2I_PROFILE_COMPANION="$source_project/$profile_root/profile.json" \
    python3 -B -m unittest discover \
    -s "$source_project/$operation_root/contract" \
    -p 'test_compile.py'
  source_logs="$source_dist/logs"
  mkdir -p "$source_logs"
  cabal --config-file="$cabal_config" -v0 \
    --project-dir="$source_project" test all \
    --builddir="$source_project/dist-newstyle" \
    --build-log="$source_logs/\$compiler-\$pkgid.log" \
    --test-log="$source_logs/\$compiler-\$pkgid-\$test-suite.log" \
    --offline \
    --ghc-options=-Werror

  info "Checking Haskell formatting."
  if [ "$scope" = foundation ]; then
    find spc/lib/core spc/ctr/archimate spc/lib/operation \
      spc/lib/adapter/amx \
      -path '*/dist-newstyle' -prune -o \
      -type f -name '*.hs' \
      -exec hindent --line-length 80 --validate {} +
  else
    find spc \
      -path '*/dist-newstyle' -prune -o \
      -type f -name '*.hs' \
      -exec hindent --line-length 80 --validate {} +
  fi
}

verify_paper() {
  for command in \
    md2pdf pandoc pandoc-crossref pandoc-include pdflatex pdfinfo pdftoppm \
    pdftotext python3; do
    require "$command"
  done

  info "Checking White Paper source contracts."
  python3 -B utl/paper/check-pdf-freshness.py sources --root .

  info "Checking the expanded White Paper source."
  pandoc o2i.md --filter pandoc-include -t markdown >/dev/null
  python3 -B -m unittest discover \
    -s utl/paper -p 'test_check_paper_assets.py'
  python3 -B -m unittest discover \
    -s utl/paper -p 'test_check_pdf_freshness.py'

  paper="$work/paper"
  mkdir -p "$paper/spc/lib/core" "$paper/spc/ctr/archimate"
  cp o2i.md README.md ACKNOWLEDGEMENTS.md "$paper/"
  cp -R acc img "$paper/"
  cp -R spc/lib/core/src "$paper/spc/lib/core/"
  cp spc/ctr/archimate/profile.md "$paper/spc/ctr/archimate/"

  info "Rendering TikZ figures in an isolated paper workspace."
  ./utl/paper/render-paper-figures.sh "$paper"
  for figure in \
    "O2I Nachweisfolge.png" \
    "O2I Frameworkarchitektur.png"; do
    if [ ! -s "$paper/img/$figure" ]; then
      printf '[o2i|error] Figure rendering produced no output: %s\n' "$figure" >&2
      exit 1
    fi
  done

  info "Checking White Paper image resources."
  if ! (cd "$paper" && pandoc o2i.md --filter pandoc-include -t json) \
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
    "$work/paper.json"

  info "Building the White Paper in an isolated paper workspace."
  (cd "$paper" && md2pdf -o "$work/o2i.pdf" -- o2i.md -H acc/o2i.icl)
  if [ ! -s "$work/o2i.pdf" ]; then
    printf '[o2i|error] White Paper build produced no PDF.\n' >&2
    exit 1
  fi
  python3 -B utl/paper/check-pdf-freshness.py check \
    --root . \
    --versioned o2i.pdf \
    --rendered "$work/o2i.pdf" \
    --manifest o2i.pdf.manifest.json
}

case "$stage" in
  licensing) verify_licensing ;;
  governance) verify_governance ;;
  model) verify_model ;;
  foundation)
    verify_licensing
    verify_haskell foundation
    ;;
  haskell) verify_haskell complete ;;
  paper) verify_paper ;;
  all)
    verify_licensing
    verify_governance
    verify_model
    verify_haskell complete
    verify_paper
    ;;
esac

printf '[o2i|success] Verification stage passed: %s.\n' "$stage"
