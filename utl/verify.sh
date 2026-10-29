#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/o2i-verify.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [all|checkpoint|licensing|governance|model|foundation|haskell|paper]\n' "$0" >&2
  exit 2
fi

stage=${1:-all}
case "$stage" in
  all | checkpoint | licensing | governance | model | foundation | haskell | paper) ;;
  *)
    printf 'Usage: %s [all|checkpoint|licensing|governance|model|foundation|haskell|paper]\n' "$0" >&2
    exit 2
    ;;
esac

info() {
  printf '[o2i|info] %s\n' "$1"
}

verification_phase=
verification_phase_started=

finish_phase() {
  if [ -z "${verification_phase:-}" ]; then
    return 0
  fi
  verification_phase_end=$(python3 -B "$root/utl/haskell/phase_clock.py" now 2>/dev/null) ||
    verification_phase_end=
  verification_elapsed=$(python3 -B "$root/utl/haskell/phase_clock.py" elapsed \
    "$verification_phase_started" "$verification_phase_end" 2>/dev/null) ||
    verification_elapsed=UNKNOWN
  info "Timing: $verification_phase; elapsed_seconds=$verification_elapsed; clock=monotonic_ns; exit_status=$1."
  verification_phase=
}

begin_phase() {
  finish_phase 0
  verification_phase=$1
  verification_phase_started=$(python3 -B "$root/utl/haskell/phase_clock.py" now 2>/dev/null) ||
    verification_phase_started=
}

# Preserve the failing check's status while reporting its active phase.
trap 'verification_exit=$?; finish_phase "$verification_exit"; rm -rf "$work"' EXIT HUP INT TERM

require() {
  isolated_command=
  if [ -n "${O2I_VERIFICATION_LOCAL_TOOLS:-}" ]; then
    case "$1" in
      python3 | reuse)
        isolated_command="$O2I_VERIFICATION_LOCAL_TOOLS/python/bin/$1" ;;
      hindent | md2pdf)
        isolated_command="$O2I_VERIFICATION_LOCAL_TOOLS/bin/$1" ;;
    esac
  fi
  if [ -n "$isolated_command" ] &&
    { [ ! -x "$isolated_command" ] ||
      [ "$(command -v "$1" 2>/dev/null || :)" != "$isolated_command" ]; }; then
    printf '[o2i|error] Required isolated tool missing or shadowed: %s; see utl/verification/README.md.\n' \
      "$isolated_command" >&2
    exit 1
  fi
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
  python3 -B utl/governance/ai4x_contract.py check
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
    -s utl/model -p 'test_*.py'
}

verify_haskell() {
  if [ ! -f "$root/utl/haskell/verify-stage.sh" ] ||
    [ ! -r "$root/utl/haskell/verify-stage.sh" ]; then
    printf '[o2i|error] Required Haskell verification module is missing or unreadable.\n' >&2
    exit 1
  fi
  . "$root/utl/haskell/verify-stage.sh"
  verify_haskell_stage "${1:-complete}"
}

verify_paper() {
  if [ ! -f "$root/utl/paper/verify-stage.sh" ] ||
    [ ! -r "$root/utl/paper/verify-stage.sh" ]; then
    printf '[o2i|error] Required paper verification module is missing or unreadable.\n' >&2
    exit 1
  fi
  . "$root/utl/paper/verify-stage.sh"
  verify_paper_stage "$root" "$work"
}

verify_checkpoint() {
  require python3
  python3 -B utl/verification/verification_scope.py \
    --event checkpoint --root "$root" --format stages >"$work/checkpoint-stages"
  if [ ! -s "$work/checkpoint-stages" ]; then
    printf '[o2i|error] Checkpoint verification selected no stages.\n' >&2
    exit 2
  fi
  while IFS= read -r checkpoint_stage <&3 || [ -n "$checkpoint_stage" ]; do
    info "Running checkpoint stage: $checkpoint_stage."
    case "$checkpoint_stage" in
      licensing) verify_licensing ;;
      governance) verify_governance ;;
      model) verify_model ;;
      haskell) verify_haskell complete ;;
      paper) verify_paper ;;
      *)
        printf '[o2i|error] Invalid checkpoint stage: %s\n' "$checkpoint_stage" >&2
        exit 2
        ;;
    esac
  done 3<"$work/checkpoint-stages"
}

case "$stage" in
  checkpoint) verify_checkpoint ;;
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
