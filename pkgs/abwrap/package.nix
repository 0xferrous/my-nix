{
  lib,
  stdenv,
  go,
  systemdMinimal,
  AIPackages,
  bash,
  bubblewrap,
  cacert,
  coreutils,
  kitty,
  ncurses,
  nix,
  pkgs,
  nushell,
  pi,
  codex,
  opencode,
}:
let
  # abwrap needs the individual tools inside its sandbox, not the aggregate
  # dev-essentials package. Disabling abwrap here breaks the otherwise circular
  # dev-essentials -> abwrap -> dev-essentials dependency.
  devEssentialPackages = import ../../config/shared/packages/dev-essentials.nix {
    inherit AIPackages pkgs;
    includeAbwrap = false;
  };

  sandboxPackages = devEssentialPackages ++ [
    bash
    coreutils
    ncurses
    nix
    nushell
    pi
    codex
    opencode
    systemdMinimal
  ];

  # Embed exact store paths so the Go binary needs no wrapper script. These
  # strings also retain every sandbox package as a runtime closure reference.
  linkerFlags = lib.concatStringsSep " " [
    "-s"
    "-w"
    "-X main.bwrapPath=${lib.getExe bubblewrap}"
    "-X main.posixShellPath=${lib.getExe bash}"
    "-X main.fallbackCABundlePath=${cacert}/etc/ssl/certs/ca-bundle.crt"
    "-X main.terminfoDirs=${kitty.terminfo}/share/terminfo:${ncurses}/share/terminfo"
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

    # The implementation uses only the standard library, so produce a static
    # binary and build the single source file without module resolution.
    export CGO_ENABLED=0
    export GO111MODULE=off
    export HOME="$TMPDIR"
    go build \
      -trimpath \
      -ldflags ${lib.escapeShellArg linkerFlags} \
      -o abwrap \
      ${./main.go}

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
