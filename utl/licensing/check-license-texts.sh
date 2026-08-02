#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    printf '[o2i|error] Required command not found: sha256sum or shasum\n' >&2
    exit 1
  fi
}

check_text() {
  expected=$1
  path=$2

  if [ ! -f "$path" ]; then
    printf '[o2i|error] Missing canonical license text: %s\n' "$path" >&2
    exit 1
  fi

  actual=$(hash_file "$path")
  if [ "$actual" != "$expected" ]; then
    printf '[o2i|error] Canonical license text differs from its official REUSE 6.2.0 source: %s\n' "$path" >&2
    exit 1
  fi
}

check_text \
  074e6e32c86a4c0ef8b3ed25b721ca23aca83df277cd88106ef7177c354615ff \
  "$root/LICENSES/Apache-2.0.txt"
check_text \
  d557539df68e771cc1eedcc91d13f70fca930e508d11eedcafa4b15db49e3744 \
  "$root/LICENSES/CC-BY-4.0.txt"

printf '[o2i|info] Canonical license texts match their official REUSE 6.2.0 sources.\n'
