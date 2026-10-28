#!/usr/bin/env bash
# Refresh the hash of an architecture-specific fixed-output derivation for a
# package in this flake.
#
# nix-update can only refresh the hash for the system it runs on: building an
# aarch64 FOD on an x86_64 builder fails with "platform mismatch". Fetch the
# artifact directly with `nix store prefetch-file` instead, then replace the old
# hash in the package file.
#
# Usage: update-arch-hash.sh <attr> <system> [fod-attr]
#   attr      flake package attribute (e.g. hibi)
#   system    target system (e.g. aarch64-linux)
#   fod-attr  attribute holding the fixed-output derivation (default: src)
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel) || {
  echo "update-arch-hash: run this from the my-nix checkout" >&2
  exit 1
}
cd "$repo_root"

attr=${1:?usage: update-arch-hash.sh <attr> <system> [fod-attr]}
system=${2:?usage: update-arch-hash.sh <attr> <system> [fod-attr]}
fod_attr=${3:-src}

package_expr="let flake = builtins.getFlake (toString ./.); in flake.legacyPackages.\"$system\".\"$attr\".\"$fod_attr\""

old_hash=$(nix eval --impure --raw --expr "$package_expr.outputHash")
url=$(nix eval --impure --raw --expr "$package_expr.url")

new_hash=$(
  nix store prefetch-file --json --hash-type sha256 "$url" |
    sed -n 's/.*"hash":"\([^"]*\)".*/\1/p'
)

if [ -z "$new_hash" ]; then
  echo "update-arch-hash: could not fetch $url" >&2
  exit 1
fi

if [ "$old_hash" = "$new_hash" ]; then
  exit 0
fi

echo "update-arch-hash: $attr.$fod_attr ($system): $old_hash -> $new_hash"
grep -rlF --include='*.nix' "$old_hash" pkgs |
  xargs -r sed -i "s|$old_hash|$new_hash|g"
