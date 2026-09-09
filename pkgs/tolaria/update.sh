#!/usr/bin/env nix-shell
#! nix-shell -i bash -p curl jq nix
# Bump source-lock.nix to the latest Tolaria GitHub release.
#
# Tolaria publishes Linux builds as GitHub release assets with calendar
# tags (vYYYY-MM-DD). The amd64 deb asset name embeds the version as
# YYYY.M.D (leading zeros stripped, so it cannot be derived from the tag
# arithmetically) — read it from the asset name instead. The deb (~20 MB)
# is downloaded once to hash it; GitHub's release assets API exposes a
# digest, but the deb download also validates that the asset URL pattern
# still holds.
set -euo pipefail
cd "$(dirname "$0")"

repo="refactoringhq/tolaria"

release=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest")
tag=$(jq -er '.tag_name' <<<"$release")
asset=$(jq -er '[.assets[].name | select(test("_amd64\\.deb$"))] | join(" ")' <<<"$release")
[[ "$(wc -w <<<"$asset")" == 1 ]] || { echo "expected exactly one amd64 deb asset, got: $asset" >&2; exit 1; }
version="${asset#Tolaria_}"
version="${version%_amd64.deb}"
url="https://github.com/$repo/releases/download/$tag/$asset"

hash=$(nix store prefetch-file --json --hash-type sha256 "$url" | jq -er .hash)

cat > source-lock.nix <<EOF
# Pin for the Tolaria Linux desktop app.
#
# Tolaria (https://github.com/refactoringhq/tolaria) ships Linux builds as
# GitHub release assets (amd64 deb/rpm/AppImage). Releases are calendar-tagged
# (\`vYYYY-MM-DD\`) and the deb asset name embeds the same version as \`YYYY.M.D\`
# (leading zeros stripped), so the pin only goes stale when a new release
# ships (bump with ./update.sh). There is no apt repo to index and no
# upstream Nix build support, so the release deb is the authoritative binary
# distribution channel.
{
  version = "$version";
  src = {
    url = "$url";
    hash = "$hash";
  };
}
EOF

echo "bumped to $version ($tag)"
