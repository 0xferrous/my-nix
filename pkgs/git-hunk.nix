{
  pkgs,
  lib ? pkgs.lib,
}:

pkgs.rustPlatform.buildRustPackage rec {
  pname = "git-hunk";
  version = "0.1.3";

  src = pkgs.fetchFromGitHub {
    owner = "nexxeln";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-VMEoqwn1oW9ehbBawCsy8B/r7Bfm9rKGUMPB8hynNvo=";
  };

  cargoHash = "sha256-iiqlFZTAlFF6jy5m8jMcqLcRvNLkPdRlK/XoQucceoQ=";
  doCheck = false;

  postInstall = ''
    install -Dm0644 SKILL.md "$out/share/git-hunk/skills/git-hunk/SKILL.md"
  '';

  meta = with lib; {
    description = "Non-interactive hunk staging for AI agents";
    homepage = "https://github.com/nexxeln/git-hunk";
    license = licenses.asl20;
    mainProgram = "git-hunk";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
