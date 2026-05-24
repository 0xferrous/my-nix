{ pkgs, lib ? pkgs.lib }:

pkgs.rustPlatform.buildRustPackage rec {
  pname = "opensrc";
  version = "0.7.2";

  src = pkgs.fetchFromGitHub {
    owner = "vercel-labs";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-yqdCkpehNPknUAWkJy7QKtpf4v3px1Xztg3djIUx0N4=";
  };

  cargoLock = {
    lockFile = "${src}/packages/opensrc/cli/Cargo.lock";
  };

  cargoHash = lib.fakeHash;

  sourceRoot = "${src.name}/packages/opensrc/cli";

  meta = with lib; {
    description = "Fetch and cache source code for packages and repos";
    homepage = "https://github.com/vercel-labs/opensrc";
    license = licenses.asl20;
    mainProgram = "opensrc";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
