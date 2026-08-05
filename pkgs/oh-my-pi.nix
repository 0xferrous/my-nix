{
  autoPatchelfHook,
  fetchurl,
  glibc,
  lib,
  stdenvNoCC,
}:
let
  version = "17.2.9";
in
stdenvNoCC.mkDerivation {
  pname = "oh-my-pi";
  inherit version;

  # Oh My Pi is not in nixpkgs. Use the upstream compiled Bun executable to
  # avoid rebuilding its TypeScript/Rust monorepo and vendoring both lockfiles.
  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
    hash = "sha256-T3rrM7LzR8EaWsjHNjDjHQLAo+7zaTRoiAufXo8CoCs=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ glibc ];

  dontUnpack = true;
  dontStrip = true;

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
