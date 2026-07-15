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
  eza
  tree
  dua
  tokei

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
