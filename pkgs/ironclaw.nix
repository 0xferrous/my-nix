{
  lib,
  stdenvNoCC,
  fetchurl,
  nix-update-script,
}:
stdenvNoCC.mkDerivation rec {
  pname = "ironclaw";
  version = "1.0.0-rc.1";

  # IronClaw is not in nixpkgs. Use its upstream, statically linked release
  # rather than building its large Rust workspace locally.
  src = fetchurl {
    url = "https://github.com/nearai/ironclaw/releases/download/ironclaw-v${version}/ironclaw-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-uXnIMOna+bTCK5LFERi5qRYHa+DWGc1i7fXFTyLFtHg=";
  };

  sourceRoot = ".";

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version-regex"
      "ironclaw-v(.+)"
    ];
  };

  installPhase = ''
    runHook preInstall
    install -Dm755 ironclaw-x86_64-unknown-linux-musl/ironclaw -t $out/bin
    runHook postInstall
  '';

  meta = {
    description = "Secure personal AI assistant";
    homepage = "https://github.com/nearai/ironclaw";
    license = with lib.licenses; [
      mit
      asl20
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "ironclaw";
  };
}
