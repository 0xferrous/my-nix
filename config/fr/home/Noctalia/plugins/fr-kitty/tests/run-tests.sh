#!/usr/bin/env bash
# Run the fr/kitty parser/search tests against the JSON fixture and the
# ls-filter.jq line output. Prefers luau + jq on PATH, falling back to
# `nix shell` so the tests run on a bare checkout.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
fixture="$here/fixture-ls.json"
filter="$root/ls-filter.jq"
spec="$here/kitty_spec.luau"

if ! command -v luau >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  exec nix shell --accept-flake-config nixpkgs#luau nixpkgs#jq -c "$0" "$@"
fi

tsv="$(jq -r -f "$filter" "$fixture")"
exec luau "$spec" -a "$(cat "$fixture")" "$tsv"
