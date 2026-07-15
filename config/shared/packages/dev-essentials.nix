{
  config ? null,
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

  yaziPackage = pkgs.yazi.override {
    # Keep yazi itself, without the heavy preview/archive helpers pulled in by
    # nixpkgs' default optionalDeps (ffmpeg, imagemagick, poppler, resvg, etc.).
    optionalDeps = [ ];
  };
in
with pkgs;
[
  # Version control and GitHub workflows
  gitPackage
  jjPackage
  git-lfs
  gh

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
]
