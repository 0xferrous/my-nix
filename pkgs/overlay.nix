{
  inputs,
  system,
}:
final: prev: {
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
  jj-hunk = final.callPackage ./jj-hunk.nix { };
  # ChatGPT/Codex Linux desktop app (preview). Not in nixpkgs: the upstream
  # `chatgpt` package is macOS-only and OpenAI publishes the Linux builds only
  # as .deb/.rpm under a moving `latest/` URL (see codex-desktop.nix).
  codex-desktop = final.callPackage ./codex-desktop.nix { };
  obscura = final.callPackage ./obscura/package.nix { };
  nash = final.callPackage ./nash.nix { };
  google-authenticator-transfer-decode =
    final.callPackage ./google-authenticator-transfer-decode.nix
      { };
  opensrc = final.callPackage ./opensrc.nix { };
  oh-my-pi = final.callPackage ./oh-my-pi.nix { };
  takopi = final.callPackage ./takopi.nix { };
  terminal-control = final.callPackage ./terminal-control.nix { };
  prime-agent = final.callPackage ./prime-agent.nix { };
  hints = final.callPackage ./hints.nix {
    source = inputs.hints;
    atspi2Core = final."at-spi2-core";
    gtkLayerShell = final."gtk-layer-shell";
  };
  "install-bin" = final.callPackage ./install-bin.nix { };
  flake-utils = final.callPackage ./flake-utils.nix { };
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
  pi-acp = final.callPackage ./pi-acp.nix { };

  # Direct llama.cpp server for Qwen3-Coder-30B-A3B (Vulkan backend — gfx1151
  # is unsupported by ROCm/vLLM). Binaries: qwen3-server, qwen3-get-model,
  # qwen3-bench.
  qwen3-server = final.callPackage ./qwen3-server.nix {
    llamaCpp = prev.llama-cpp.override { vulkanSupport = true; };
  };
  frsNvimPackage = inputs.frs-nvim.packages.${system}.default;
}
