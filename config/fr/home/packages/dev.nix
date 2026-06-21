{
  pkgs,
  lib,
  config,
  myNixInputs,
  system,
  fenixPackages,
  ...
}:
let
  utils = import ../../../../modules/home/utils.nix;
in
with pkgs;
[
  # Git tools
  git-crypt
  git-cliff
  git-quick-stats
  lazygit
  gh
  gh-dash

  # Programming languages and runtimes
  go
  zig
  ruby
  jekyll
  deno
  bun
  fnm
  yarn
  pnpm
  typescript

  # Formatters and language tooling
  prettier
  stylua
  ruff
  topiary
  fnlfmt

  # Editors and development environment
  helix

  (utils.wrapWithEnv {
    inherit lib pkgs;
    pkg = pkgs.neovide;
    bin = "neovide";
    envVars = [
      {
        name = "ZK_NOTEBOOK_DIR";
        value = "${config.home.homeDirectory}/notes-zk";
      }
    ];
  })

  (pkgs.runCommand "nvimpager"
    {
      nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
    }
    (
      let
        nvimpkg = myNixInputs.frs-nvim.packages.${system}.default;
        nvimpager = myNixInputs.nvimpager.packages.${system}.default.overrideAttrs (_: {
          doCheck = false;
        });
        wrapperArgs = [
          "${nvimpager}/bin/nvimpager"
          "${placeholder "out"}/bin/nvimpager"
          "--inherit-argv0"
          "--set"
          "NVIMPAGER_NVIM"
          "${nvimpkg}/bin/nvim"
        ];
      in
      ''
        mkdir -p $out/bin
        makeWrapper ${lib.escapeShellArgs wrapperArgs}
      ''
    )
  )

  # IDEs
  vscodium

  # Build tools and compilers
  cmake
  meson
  gcc
  gnumake
  tree-sitter

  # Python tools
  poetry
  uv
  python312Packages.qrcode

  # Rust ecosystem
  bacon
  cargo-binstall
  kondo
  wasm-pack
  trunk
  cargo-nextest

  (fenixPackages.combine [
    fenixPackages.complete.toolchain
    fenixPackages.targets.wasm32-unknown-unknown.latest.toolchain
  ])

  # Debugging
  gdb

  # Development libraries
  libffi
  openssl
  pkg-config
  sqlite
  enchant

  # Lua
  luarocks
  luajit
  luajitPackages.fennel

  # Web development
  web-ext

  # AST tools
  ast-grep

  # Development services
  redis
  postgresql_17

  # DevOps and containers
  act
  devpod
  tectonic

  # Documentation
  graphviz
  mermaid-cli
  playwright-mcp

  # Merge and diff
  difftastic
  mergiraf

  # Version control
  git-lfs

  # Scripting
  rust-script
]
