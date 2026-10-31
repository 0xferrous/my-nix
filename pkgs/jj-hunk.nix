{
  pkgs,
  lib ? pkgs.lib,
  nix-update-script,
}:

pkgs.rustPlatform.buildRustPackage rec {
  pname = "jj-hunk";
  version = "0.5.1";

  src = pkgs.fetchFromGitHub {
    owner = "laulauland";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-Pe0rLEUMXmq+8eUMmjuu5KvFJ/aN53bTQ6/1rE2YcT0=";
  };

  cargoHash = "sha256-tO4oGY92AieYb1SY3ylWSkOlcIKadbZLKOY6nTzXo48=";
  doCheck = false;

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  postInstall = ''
    install -Dm0644 SKILL.md "$out/share/jj-hunk/skills/jj-hunk/SKILL.md"
  '';

  meta = with lib; {
    description = "Programmatic hunk selection for jj";
    homepage = "https://github.com/laulauland/jj-hunk";
    license = licenses.mit;
    mainProgram = "jj-hunk";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
