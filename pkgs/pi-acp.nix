{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  makeWrapper,
  pi,
}:

buildNpmPackage rec {
  pname = "pi-acp";
  version = "0.0.32";

  src = fetchFromGitHub {
    owner = "svkozak";
    repo = "pi-acp";
    rev = "v${version}";
    hash = "sha256-NksKacRpopm8lAaOG9tbHxJAcr4rlU0uL3dl/VkFbAA=";
  };

  npmDepsHash = "sha256-sRBrTwBwo8pcOy5WGDxHE86fvldgOtlppuvcbiB+7uc=";

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/pi-acp \
      --prefix PATH : ${lib.makeBinPath [ pi ]}
  '';

  meta = {
    description = "Agent Client Protocol adapter for the Pi coding agent";
    homepage = "https://github.com/svkozak/pi-acp";
    license = lib.licenses.mit;
    mainProgram = "pi-acp";
    platforms = lib.platforms.unix;
  };
}
