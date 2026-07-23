{
  pkgs,
  lib ? pkgs.lib,
}:

pkgs.rustPlatform.buildRustPackage rec {
  pname = "jj-hunk";
  version = "0.3.0";

  src = pkgs.fetchFromGitHub {
    owner = "laulauland";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-ZUiCYeeFvthIoTX/iNLa9dYWQlLWyLEnhdGYy8fkJuM=";
  };

  cargoHash = "sha256-S8m3+wFebuezIwqW9Lxtd7PcDUfwJu1VeLMjJopqcSE=";
  doCheck = false;

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
