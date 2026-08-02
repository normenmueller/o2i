#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
specification_root="$repository_root/spc"
canonical_license="$repository_root/LICENSES/Apache-2.0.txt"

if [[ ! -f "$canonical_license" ]]; then
  printf '[o2i|error] Missing canonical Apache-2.0 license: %s\n' \
    "$canonical_license" >&2
  exit 1
fi

while IFS= read -r cabal_file; do
  package_dir="$(dirname "$cabal_file")"
  package_license="$package_dir/LICENSE"

  if [[ ! -f "$package_license" ]]; then
    printf '[o2i|error] Missing package license: %s\n' "$package_license" >&2
    exit 1
  fi

  if ! cmp -s "$canonical_license" "$package_license"; then
    printf '[o2i|error] Package license differs from canonical Apache-2.0 text: %s\n' \
      "$package_license" >&2
    exit 1
  fi
done < <(
  find "$specification_root" \
    -path "$specification_root/dist-newstyle" -prune -o \
    -name '*.cabal' -type f -print | sort
)

printf '[o2i|info] Package licenses match the canonical Apache-2.0 text.\n'
