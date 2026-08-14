#!/usr/bin/env nix-shell
#! nix-shell -i bash -p curl nix
# Bump pkgs/codex-desktop-source.nix to the current ChatGPT/Codex Linux
# desktop app build.
#
# OpenAI hosts a real apt repository (codex-app-prod/linux/deb). The
# dists/stable/main/binary-amd64/Packages index lists the current version,
# its versioned pool URL, and its sha256, so refreshing the pin is a single
# small HTTP GET — no need to download the ~390 MB deb. The pool URL is
# stable per version, unlike the moving `latest/` URL the download page
# points at, so the pin only goes stale when OpenAI ships a new build.
set -euo pipefail
cd "$(dirname "$0")"

packages_url="https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages"
base_url="https://persistent.oaistatic.com/codex-app-prod/linux/deb"

packages=$(curl -fsSL "$packages_url")
version=$(awk '/^$/{p=0} /^Package: chatgpt$/{p=1} p&&/^Version:/{print $2; exit}' <<<"$packages")
filename=$(awk '/^$/{p=0} /^Package: chatgpt$/{p=1} p&&/^Filename:/{print $2; exit}' <<<"$packages")
sha256=$(awk '/^$/{p=0} /^Package: chatgpt$/{p=1} p&&/^SHA256:/{print $2; exit}' <<<"$packages")

# The Packages index gives the sha256 in base16; fetchurl's `hash` needs SRI.
hash=$(nix hash convert --hash-algo sha256 --from base16 --to sri "$sha256")
url="$base_url/$filename"

cat > codex-desktop-source.nix <<EOF
# Pin for the ChatGPT/Codex Linux desktop app (preview).
#
# OpenAI hosts a real apt repository (codex-app-prod/linux/deb) whose
# dists/stable/main/binary-amd64/Packages index lists the current version
# and hash. The versioned pool URL below is stable per version, unlike the
# moving \`latest/\` URL used on the download page, so the pin only goes stale
# when OpenAI ships a new build (bump with ./codex-desktop-update.sh). The
# mac app uses a versioned \`sidekick\` URL in nixpkgs
# (\`pkgs/by-name/ch/chatgpt\`); the apt pool is the Linux equivalent.
{
  version = "$version";
  src = {
    url = "$url";
    hash = "$hash";
  };
}
EOF

echo "bumped to $version"
