#!/usr/bin/env bash
# Bump pkgs/codex-desktop-source.nix to the current ChatGPT/Codex Linux
# desktop app build (the published `latest/` URL moves as OpenAI ships).
set -euo pipefail
cd "$(dirname "$0")"

url="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/chatgpt.deb" "$url"
version=$(dpkg-deb -f "$tmp/chatgpt.deb" Version)
hash=$(nix-prefetch-url --type sha256 "file://$tmp/chatgpt.deb")

cat > codex-desktop-source.nix <<EOF
# Pin for the ChatGPT/Codex Linux desktop app (preview).
#
# OpenAI only publishes a moving \`latest/\` URL for the Linux packages, so the
# version is read from the deb's control metadata and the URL is re-fetched
# when bumping (see ./update.sh). The mac app uses a versioned \`sidekick\`
# URL in nixpkgs (\`pkgs/by-name/ch/chatgpt\`), but no equivalent exists for
# the Linux \`codex-app-prod\` bucket yet.
{
  version = "$version";
  src = {
    url = "$url";
    hash = "$hash";
  };
}
EOF

echo "bumped to $version"
