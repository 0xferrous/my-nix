#!/usr/bin/env bash
# Refresh a Herdr release pin (`herdr-app` or `herdr-core`) from upstream's
# release manifest.
#
# Herdr publishes per-architecture tarballs from its own release host and keeps
# no GitHub releases, so nix-update has no version or asset to derive. The
# manifest at https://releases.herdr.dev/<channel>/latest.json carries the
# current version and the sha256 of every artifact, which is everything these
# pins need: the version attribute and one hash per Linux architecture.
#
# Usage: herdr-update.sh <attr>
#   attr      flake package attribute (herdr-app or herdr-core)
set -euo pipefail

attr=${1:?usage: herdr-update.sh <attr>}
channel=${attr#herdr-}

repo_root=$(git rev-parse --show-toplevel) || {
  echo "herdr-update: run this from the my-nix checkout" >&2
  exit 1
}
cd "$repo_root"

package_file="pkgs/${attr}.nix"
[ -f "$package_file" ] || {
  echo "herdr-update: $package_file does not exist" >&2
  exit 1
}

# Fetch the manifest through the Nix store, which is the one download stack this
# script can count on: it is neither cached across runs nor a second dependency.
manifest=$(
  nix store prefetch-file --json --name "herdr-${channel}-latest.json" \
    "https://releases.herdr.dev/${channel}/latest.json" 2>/dev/null |
    sed -n 's/.*"storePath":"\([^"]*\)".*/\1/p'
)
[ -n "$manifest" ] || {
  echo "herdr-update: could not fetch the ${channel} release manifest" >&2
  exit 1
}

# Read one field out of the manifest; the argument is a Nix attribute path.
from_manifest() {
  nix eval --impure --raw --expr \
    "(builtins.fromJSON (builtins.readFile ${manifest}))$1"
}

# The manifest publishes plain sha256 hex digests while the package expressions
# use SRI, so convert rather than downloading the artifacts a second time.
to_sri() {
  nix hash convert --hash-algo sha256 --to sri "$1"
}

# The pinned version and hashes come from the flake itself, so the script never
# has to parse the package expression.
from_flake() {
  nix eval --impure --raw --expr \
    "(builtins.getFlake (toString ./.)).legacyPackages.\"$1\".\"${attr}\"$2"
}

new_version=$(from_manifest .version)
new_x86_64=$(to_sri "$(from_manifest '.targets."linux-x86_64".sha256')")
new_aarch64=$(to_sri "$(from_manifest '.targets."linux-aarch64".sha256')")

old_version=$(from_flake x86_64-linux .version)
old_x86_64=$(from_flake x86_64-linux .src.outputHash)
old_aarch64=$(from_flake aarch64-linux .src.outputHash)

replace() {
  local old=$1 new=$2
  [ "$old" = "$new" ] && return 0
  grep -qF -- "$old" "$package_file" || {
    echo "herdr-update: $package_file has no '$old'" >&2
    exit 1
  }
  sed -i "s|${old}|${new}|g" "$package_file"
}

if [ "$new_version" = "$old_version" ] &&
  [ "$new_x86_64" = "$old_x86_64" ] &&
  [ "$new_aarch64" = "$old_aarch64" ]; then
  echo "herdr-update: $attr is already at $new_version"
  exit 0
fi

echo "herdr-update: $attr: $old_version -> $new_version"
replace "version = \"${old_version}\";" "version = \"${new_version}\";"
replace "$old_x86_64" "$new_x86_64"
replace "$old_aarch64" "$new_aarch64"
