{
  inputs,
  system,
}:
final: prev:
let
  nushellSrc = final.fetchFromGitHub {
    owner = "nushell";
    repo = "nushell";
    rev = "9a251561a90277d0af466ee845dff706bbf3c3d9";
    hash = "sha256-aGmgsHfa35oGQJ+z6kxqHsM15QP03C9nSdv5g9hQwOA=";
  };
in
{
  # TODO: Remove this source build and use nixpkgs' Nushell 0.116.0 once it
  # is released.
  nushell = prev.nushell.overrideAttrs (_: {
    version = "0.115.1-unstable";
    src = nushellSrc;
    cargoDeps = final.rustPlatform.fetchCargoVendor {
      src = nushellSrc;
      hash = "sha256-ZnaGMD+ONwFoJGEMQY3VX/J4BZSDnWajvgM2cBWR9M4=";
    };
  });

  herdr = inputs.llm-agents.packages.${system}.herdr;

  ashWrappers = import ./ash-portal-wrappers.nix {
    inherit (final) lib runCommand symlinkJoin;
    ashPackage = inputs.ash.packages.${system}.all or inputs.ash.packages.${system}.ash;
  };
  fr-frame-summon = final.callPackage ./frame-summon.nix { };
  fr-kbd-backlight = final.callPackage ./keyboard-backlight.nix { };
  git-hunk = final.callPackage ./git-hunk.nix { };
  ironclaw = final.callPackage ./ironclaw.nix { };
  iron-proxy = final.callPackage ./iron-proxy.nix { };
  ssh-tmp = final.callPackage ./ssh-tmp.nix { };
  jj-hunk = final.callPackage ./jj-hunk.nix { };
  # ChatGPT/Codex Linux desktop app (preview). Not in nixpkgs: the upstream
  # `chatgpt` package is macOS-only and OpenAI publishes the Linux builds only
  # as .deb/.rpm under a moving `latest/` URL (see codex-desktop.nix).
  codex-desktop = final.callPackage ./codex-desktop.nix { };
  bb = final.callPackage ./bb/appimage.nix {
    codex = inputs.llm-agents.packages.${system}.codex;
    pi = final.pi;
  };
  bbSource = final.callPackage ./bb/source.nix {
    codex = inputs.llm-agents.packages.${system}.codex;
    electron = final.electron_41;
    pi = final.pi;
  };
  "bb-android-x86_64" = final.callPackage ./bb/android.nix {
    androidAbi = "x86_64";
  };
  "bb-android-arm64-v8a" = final.callPackage ./bb/android.nix {
    androidAbi = "arm64-v8a";
  };
  # Keep the original name as the Waydroid-compatible default.
  "bb-android" = final."bb-android-x86_64";
  tolaria = final.callPackage ./tolaria/source.nix { };
  dev-essentials = final.callPackage ./dev-essentials.nix {
    AIPackages = inputs.llm-agents.packages.${system};
  };
  obscura = final.callPackage ./obscura/package.nix { };
  nash = final.callPackage ./nash.nix { };
  google-authenticator-transfer-decode =
    final.callPackage ./google-authenticator-transfer-decode.nix
      { };
  opensrc = final.callPackage ./opensrc.nix { };
  oh-my-pi = final.callPackage ./oh-my-pi.nix { };
  takopi = final.callPackage ./takopi.nix { };
  tron-wallet-cli = final.callPackage ./tron-wallet-cli { };
  tron-wallet-cli-java = final.callPackage ./tron-wallet-cli/java.nix { };
  terminal-control = final.callPackage ./terminal-control.nix { };
  iroh-ssh = final.callPackage ./iroh-ssh.nix { };
  prime-agent = final.callPackage ./prime-agent.nix { };
  hints = final.callPackage ./hints.nix {
    source = inputs.hints;
    atspi2Core = final."at-spi2-core";
    gtkLayerShell = final."gtk-layer-shell";
  };
  "install-bin" = final.callPackage ./install-bin.nix { };
  flake-utils = final.callPackage ./flake-utils.nix { };
  gruvbox-gtk-theme = final.callPackage ./gruvbox-gtk-theme.nix { };
  plannotator-pi-extension = final.callPackage ./plannotator-pi-extension.nix { };
  pi = final.callPackage ./pi.nix {
    piPackage = inputs.llm-agents.packages.${system}.pi;
    agentStuffSrc = inputs."agent-stuff";
    gitHunk = final.git-hunk;
    jjHunk = final.jj-hunk;
    plannotatorPiExtension = final.plannotator-pi-extension;
    zjRadarCli = inputs.zj-radar.packages.${system}.zj-radar-cli;
  };
  piDev = final.pi.override {
    agentStuffPath = "~/dev/fr/agent-stuff";
  };
  abwrap = final.callPackage ./abwrap/package.nix {
    AIPackages = inputs.llm-agents.packages.${system};
    codex = inputs.llm-agents.packages.${system}.codex;
    opencode = inputs.llm-agents.packages.${system}.opencode;
  };
  pi-acp = final.callPackage ./pi-acp.nix { };

  # Direct llama.cpp server for Qwen3-Coder-30B-A3B (Vulkan backend — gfx1151
  # is unsupported by ROCm/vLLM). Binaries: qwen3-server, qwen3-get-model,
  # qwen3-bench.
  qwen3-server = final.callPackage ./qwen3-server.nix {
    llamaCpp = prev.llama-cpp.override { vulkanSupport = true; };
  };
  frsNvimPackage = inputs.frs-nvim.packages.${system}.default;
}
