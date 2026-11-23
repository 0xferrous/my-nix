{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  makeWrapper,
  nix-update-script,
  pi,
}:

buildNpmPackage rec {
  pname = "pi-acp";
  version = "0.0.35";

  src = fetchFromGitHub {
    owner = "svkozak";
    repo = "pi-acp";
    rev = "v${version}";
    hash = "sha256-/5ga4YEi5GZ95ru+9gDpXp9iWVqmLeInIHddskO4uXg=";
  };

  npmDepsHash = "sha256-BtLtlL0zpoOzN094Wf9GZrpfQm4eVpcITzMxfEeMpKI=";

  nativeBuildInputs = [ makeWrapper ];

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

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
