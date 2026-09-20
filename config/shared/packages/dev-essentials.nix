{
  AIPackages,
  config ? null,
  includeAbwrap ? true,
  includeOhMyPi ? true,
  pkgs,
  ...
}:
let
  gitPackage =
    if config != null && config.programs.git.enable then config.programs.git.package else pkgs.git;

  jjPackage =
    if config != null && config.programs.jujutsu.enable then
      config.programs.jujutsu.package
    else
      pkgs.jujutsu;

  # Slim build without the heavy preview/archive helpers pulled in by
  # nixpkgs' default optionalDeps (ffmpeg, imagemagick, poppler, resvg,
  # etc.). Shared via lib/slim-yazi.nix so all call sites with the same
  # args resolve to one derivation (see config/fr/home.nix termfilechooser
  # pin: duplicates collide on /bin/yazi in home-manager buildEnv).
  yaziPackage = import ../../../lib/slim-yazi.nix { inherit pkgs; };

  hunkPackage = pkgs.symlinkJoin {
    name = "wrapped-hunk";
    paths = [ AIPackages.hunk ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/hunk --set PAGER "less -FRX"
    '';
  };
in
(with pkgs; [
  # Version control and GitHub workflows
  gitPackage
  jjPackage
  git-lfs
  gh
  hunkPackage

  # Search, navigation, and file inspection
  ripgrep
  fd
  bat
  _7zz
  eza
  tree
  dua
  tokei
  yaziPackage

  # Structured data and text processing
  jq
  yq
  fx

  # Build/task runners and shell helpers
  just
  direnv
  fzf

  # Terminal multiplexers
  tmux
  zellij

  # Documentation and help
  tealdeer
  glow
  less

  # Network and remote access
  curl
  httpie
  doggo
  openssh

  # Nix workflows
  nh
  comma
  nix-output-monitor
  nix-search-tv

  # Python/project workflows
  uv

  # Containers
  docker-client
  docker-compose

  # AI agent tooling
  prime-agent
])
++ pkgs.lib.optional includeAbwrap pkgs.abwrap
++ pkgs.lib.optional includeOhMyPi pkgs.oh-my-pi
