{
  lib,
  fetchFromGitHub,
  rustPlatform,
  zig_0_15,
  gitMinimal,
  pkg-config,
  callPackage,
}:
let
  # Pinned by libghostty-vt-sys 0.2.1 (build.rs GHOSTTY_COMMIT). The build
  # script refuses to fetch Ghostty itself inside the Nix sandbox, so point it
  # at a store copy and supply a prefetched zig package cache (see
  # ./terminal-control/ghostty-deps.nix); ghostty's build graph resolves its
  # lazy dependencies eagerly, so the cache carries every zon dependency.
  ghosttySrc = fetchFromGitHub {
    owner = "ghostty-org";
    repo = "ghostty";
    rev = "a887df42c56f6de86c0fe6da9c4eeca37931e083";
    hash = "sha256-1Zz65SCk3rkJ9+Q0MmyNOTNiDSLBRIHRd3IvFM4iNXw=";
  };

  ghosttyVtZigDeps = callPackage ./terminal-control/ghostty-deps.nix {
    name = "terminal-control-ghostty-vt-zig-deps";
  };
in
rustPlatform.buildRustPackage {
  pname = "terminal-control";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "anomalyco";
    repo = "terminal-control";
    rev = "v0.6.0";
    hash = "sha256-gM3mBaIHuLnt3G3dxvdvqZaMNCb0sx8krnEThrcurbc=";
  };

  cargoHash = "sha256-7K2b3sbTHQvz+aezv/wOjYYJUvHokjy79GoR3loHgwc=";

  nativeBuildInputs = [
    zig_0_15
    gitMinimal
    pkg-config
  ];

  # nixpkgs' zig setup hook would hijack cargo's build/install phases; the
  # only zig build here is the one libghostty-vt-sys invokes inside its own
  # cargo build script.
  dontUseZigConfigure = true;
  dontUseZigBuild = true;
  dontUseZigCheck = true;
  dontUseZigInstall = true;

  # libghostty-vt-sys build.rs honors both: GHOSTTY_SOURCE_DIR replaces its
  # build-time GitHub fetch, GHOSTTY_ZIG_SYSTEM_DIR makes `zig build` resolve
  # packages from a store path instead of the network (--system).
  env = {
    GHOSTTY_SOURCE_DIR = ghosttySrc;
    GHOSTTY_ZIG_SYSTEM_DIR = ghosttyVtZigDeps;
  };

  # The vt build compiles a fair amount of C/C++ via zig; keep the debug
  # profile fast and quiet.
  doCheck = false;

  meta = {
    description = "Control, inspect, test, and capture real terminal applications for agents and TUI review";
    homepage = "https://github.com/anomalyco/terminal-control";
    license = lib.licenses.mit;
    mainProgram = "termctrl";
    platforms = lib.platforms.linux;
  };
}
