# wallet-cli (TRON command-line wallet) — TypeScript implementation.
# Built from source with tsup; `node-hid` and `axios` are kept external by
# upstream's tsup config, so we ship the package together with its production
# node_modules (buildNpmPackage does this) instead of a single bundled file.
# Upstream also publishes prebuilt Bun binaries on GitHub Releases, and an
# older Java/Gradle CLI lives in java/ — neither is used here.
{
  pkgs,
  lib,
  version ? "4.12.0",
}:

pkgs.buildNpmPackage rec {
  pname = "tron-wallet-cli";
  inherit version;

  src = pkgs.fetchgit {
    url = "https://github.com/tronprotocol/wallet-cli";
    rev = "0190dab7e7ccffc18d9343ccac50db0714290dd3"; # wallet-cli-4.12.0
    hash = "sha256-k9lYh+vbtubIdI3qUs29Fo6YwmsRr83eGz6G4adA1T0=";
  };

  sourceRoot = "${src.name}/ts";

  npmDepsHash = "sha256-jo1ttBZJDve3KTPbVRDuHP1T2rdT4+ViYN1fb6JFK6Y=";

  # node-hid is kept external by upstream's tsup config and compiles its
  # bundled hidapi (libusb backend) during `npm install`.
  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ pkgs.libusb1 ];

  # The `bun` devDependency is only used by the `build:standalone` script; its
  # install script downloads a platform binary and fails under npm, so drop it.
  postPatch = ''
    ${pkgs.jq}/bin/jq 'del(.devDependencies.bun)' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  meta = with lib; {
    description = "Agent-first TRON command-line wallet (TypeScript)";
    homepage = "https://github.com/tronprotocol/wallet-cli";
    license = licenses.lgpl3Plus;
    mainProgram = "wallet-cli";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
