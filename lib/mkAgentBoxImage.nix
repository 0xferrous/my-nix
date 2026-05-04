{
  inputs,
  system,
  pkgs ? inputs.nixpkgs.legacyPackages.${system},
  lib ? pkgs.lib,
  uid ? 1000,
  gid ? uid,
  uname ? "agent",
  gname ? uname,
  includePiLocal ? false,
  env ? {
    EDITOR = "nvim";
  },
  extraPackages ? [ ],
  extraEnv ? { },
  workingDir ? "/workspace",
}:
assert builtins.isInt uid;
assert builtins.isInt gid;
assert builtins.isString uname;
assert builtins.isString gname;
let
  llmAgents = inputs.llm-agents.packages.${system};
  nixIndexDatabasePkgs = inputs.nix-index-database.packages.${system};
  agentBoxPkgs = inputs.agent-box.packages.${system};
  foundryPackage = inputs.foundry.defaultPackage.${system};
  mkAgentImage = inputs.agent-images.lib.mkAgentImage {
    inherit pkgs lib;
  };
  gitHunk = import ../pkgs/git-hunk.nix {
    inherit pkgs lib;
  };
  slimYazi = pkgs.yazi.override {
    optionalDeps = with pkgs; [
      jq
      fd
      ripgrep
      fzf
      zoxide
    ];
  };

  entrypoint = pkgs.writeShellScriptBin "entrypoint" ''
    if nix flake metadata &>/dev/null; then
      if [ $# -eq 0 ]; then
        exec nix develop --command bash
      else
        exec nix develop --command "$@"
      fi
    else
      if [ $# -eq 0 ]; then
        exec bash
      else
        exec "$@"
      fi
    fi
  '';

  upstreamBasePackages = with pkgs; [
    bashInteractive
    coreutils
    findutils
    gnugrep
    gawk
    git
    ripgrep
    less
    curl
    cacert
    gnused
    diffutils
    jq
    gnutar
    gzip
    which
  ];

  shellPackages = with pkgs; [
    bash
    wget
    tree
  ];

  editorPackages = with pkgs; [
    neovim
    slimYazi
    bat
    delta
    glow
  ];

  devPackages = with pkgs; [
    fd
    jujutsu
    gnumake
    gcc
    cmake
    pkg-config
    binutils
    patchelf
    tokei
    file
    dua
    direnv
    nix-search-tv
    gitHunk
  ];

  debugPackages = with pkgs; [
    strace
    lsof
    unixtools.netstat
  ];

  languagePackages = with pkgs; [
    nodejs_24
    python315
    bun
    uv
    ty
    mypy
  ];

  miscPackages = with pkgs; [
    gnupg
  ];

  aiPackages = with llmAgents; [
    pi
    claude-code
    tuicr
    codex
  ];

  agentPackages = [
    agentBoxPkgs.wrappers
    agentBoxPkgs.cli
  ];

  nixHelperPackages = [
    nixIndexDatabasePkgs.nix-index-with-db
    nixIndexDatabasePkgs.comma-with-db
    foundryPackage
  ];

  piLocalPackages =
    if includePiLocal then
      throw "includePiLocal is true, but agent-image.nix no longer wires piCodingAgent"
    else
      [ ];

  basePackages = lib.unique (
    upstreamBasePackages
    ++ shellPackages
    ++ editorPackages
    ++ devPackages
    ++ debugPackages
    ++ languagePackages
    ++ miscPackages
    ++ aiPackages
    ++ agentPackages
    ++ nixHelperPackages
    ++ piLocalPackages
    ++ extraPackages
  );
in
mkAgentImage {
  name = "agent-box";
  agent = entrypoint;
  entrypoint = [ "${entrypoint}/bin/entrypoint" ];

  user = uname;
  inherit
    uid
    gid
    workingDir
    basePackages
    ;
  withNix = true;
  withNixLd = true;
  extraPackages = [ ];
  extraEnv = env // extraEnv;

  # TODO: upstream mkAgentImage currently has no separate group-name parameter,
  # so gname is accepted here for API compatibility but not yet reflected in
  # /etc/group. If needed, extend mkAgentImage to support an explicit group name.
}
