{
  lib,
  stdenv,
  go,
  AIPackages,
  bubblewrap,
  coreutils,
  nix,
  pkgs,
  nushell,
  pi,
  codex,
  opencode,
}:
let
  devEssentialPackages = import ../config/shared/packages/dev-essentials.nix {
    inherit AIPackages pkgs;
    includeAbwrap = false;
  };

  sandboxPackages = devEssentialPackages ++ [
    coreutils
    nix
    nushell
    pi
    codex
    opencode
  ];

  linkerFlags = lib.concatStringsSep " " [
    "-s"
    "-w"
    "-X main.bwrapPath=${lib.getExe bubblewrap}"
    "-X main.defaultEntrypoint=${lib.getExe nushell}"
    "-X main.sandboxPath=${lib.makeBinPath sandboxPackages}"
  ];
in
stdenv.mkDerivation {
  pname = "abwrap";
  version = "0.1.0";

  dontUnpack = true;
  nativeBuildInputs = [ go ];

  buildPhase = ''
    runHook preBuild

    export CGO_ENABLED=0
    export GO111MODULE=off
    export HOME="$TMPDIR"
    go build \
      -trimpath \
      -ldflags ${lib.escapeShellArg linkerFlags} \
      -o abwrap \
      ${./abwrap.go}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 abwrap "$out/bin/abwrap"

    runHook postInstall
  '';

  meta = {
    description = "Bubblewrap sandbox for Nushell and agent CLIs";
    license = lib.licenses.mit;
    mainProgram = "abwrap";
    platforms = lib.platforms.linux;
  };
}
