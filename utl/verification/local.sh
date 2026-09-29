#!/bin/sh
set -eu

if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [all|checkpoint|licensing|governance|model|foundation|haskell|paper]\n' "$0" >&2
  exit 2
fi
stage=${1:-checkpoint}
case "$stage" in
  all|checkpoint|licensing|governance|model|foundation|haskell|paper) ;;
  *) printf 'Unknown verification stage: %s\n' "$stage" >&2; exit 2 ;;
esac

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
local_tools="$root/utl/verification/.local"
python_bin="$local_tools/python/bin"
if [ ! -x "$python_bin/python3" ] || [ ! -x "$python_bin/reuse" ] ||
   [ ! -x "$local_tools/bin/hindent" ] || [ ! -x "$local_tools/bin/md2pdf" ]; then
  printf 'Local verification environment is missing; see utl/verification/README.md.\n' >&2
  exit 1
fi
mkdir -p "$local_tools/tmp"
PATH="$local_tools/bin:$python_bin:$PATH"
TMPDIR=$(CDPATH= cd -- "$local_tools/tmp" && pwd -P)
# Fresh test directories must not accidentally discover the enclosing O2I Git repo.
GIT_CEILING_DIRECTORIES="$TMPDIR${GIT_CEILING_DIRECTORIES:+:$GIT_CEILING_DIRECTORIES}"
export PATH TMPDIR GIT_CEILING_DIRECTORIES
cd "$root"
exec "$root/utl/verify.sh" "$stage"
