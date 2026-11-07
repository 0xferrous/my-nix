{
  autoPatchelfHook,
  fetchurl,
  glibc,
  lib,
  nix-update-script,
  stdenvNoCC,
}:
let
  version = "18.18.0";
in
stdenvNoCC.mkDerivation {
  pname = "oh-my-pi";
  inherit version;

  # Oh My Pi is not in nixpkgs. Use the upstream compiled Bun executable to
  # avoid rebuilding its TypeScript/Rust monorepo and vendoring both lockfiles.
  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
    hash = "sha256-7CceDX30wPV6y2p6KPhYXUa9BQvO+ElPbTPbimwN+7o=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ glibc ];

  dontUnpack = true;
  dontStrip = true;

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/omp"
    runHook postInstall
  '';

  meta = {
    description = "AI coding agent for the terminal";
    homepage = "https://github.com/can1357/oh-my-pi";
    changelog = "https://github.com/can1357/oh-my-pi/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "omp";
    platforms = [ "x86_64-linux" ];
  };
}
