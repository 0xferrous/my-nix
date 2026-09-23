{
  inputs,
  patchedZjRadar ? inputs.zj-radar,
  patchedZjRadarByBuildSystem ? { },
  crossZjRadar ? null,
  crossPackages ? null,
  includeZjRadar ? true,
  useCustomNushell ? true,
}:
final: prev:
let
  buildSystem = final.stdenv.buildPlatform.system;
  targetSystem = final.stdenv.hostPlatform.system;
  patchedZjRadarForBuild = patchedZjRadarByBuildSystem.${buildSystem} or patchedZjRadar;
  isCross = buildSystem != targetSystem;
  useCrossPackages =
    isCross
    && crossPackages != null
    && crossPackages.stdenv.buildPlatform.system == buildSystem
    && crossPackages.stdenv.hostPlatform.system == targetSystem;
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
  nushell =
    if useCrossPackages then
      crossPackages.nushell
    else if !useCustomNushell then
      prev.nushell
    else
      prev.nushell.overrideAttrs (old: {
        version = "0.115.1-unstable";
        src = nushellSrc;
        cargoDeps = final.rustPlatform.fetchCargoVendor {
          src = nushellSrc;
          hash = "sha256-ZnaGMD+ONwFoJGEMQY3VX/J4BZSDnWajvgM2cBWR9M4=";
        };
        # The sandbox has no PTY, so these upstream tests see a 0-column table.
        checkPhase =
          final.lib.replaceStrings
            [ "--test-threads=$NIX_BUILD_CORES" ]
            [
              "--test-threads=$NIX_BUILD_CORES --skip=eval::eval_rendered_matches::case_3_literal_range --skip=eval::eval_rendered_matches::case_4_literal_list --skip=eval::eval_rendered_matches::case_5_literal_record --skip=eval::eval_rendered_matches::case_6_literal_table --skip=eval::eval_rendered_matches::case_8_call_spread"
            ]
            old.checkPhase;
      });

  herdr = inputs.llm-agents.packages.${targetSystem}.herdr;

  ashWrappers = import ./ash-portal-wrappers.nix {
    inherit (final) lib runCommand symlinkJoin;
    ashPackage = inputs.ash.packages.${targetSystem}.all or inputs.ash.packages.${targetSystem}.ash;
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
    codex = inputs.llm-agents.packages.${targetSystem}.codex;
    pi = final.pi;
  };
  # Keep the Electron/Node build in the target-native package set. It is a
  # local package, so this may use QEMU for the build itself, but cross-building
  # it causes its entire native-module closure to miss the ARM cache.
  bbSource = final.callPackage ./bb/source.nix {
    codex = inputs.llm-agents.packages.${targetSystem}.codex;
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
    AIPackages = inputs.llm-agents.packages.${targetSystem};
  };
  obscura =
    if useCrossPackages then crossPackages.obscura else final.callPackage ./obscura/package.nix { };
  nash = final.callPackage ./nash.nix { };
  google-authenticator-transfer-decode =
    final.callPackage ./google-authenticator-transfer-decode.nix
      { };
  opensrc = final.callPackage ./opensrc.nix { };
  oh-my-pi =
    if targetSystem == "x86_64-linux" then
      final.callPackage ./oh-my-pi.nix { }
    else
      final.writeShellScriptBin "omp" ''
        echo "oh-my-pi is unavailable on ${targetSystem}" >&2
        exit 1
      '';
  takopi = final.callPackage ./takopi.nix { };
  tron-wallet-cli = final.callPackage ./tron-wallet-cli { };
  tron-wallet-cli-java = final.callPackage ./tron-wallet-cli/java.nix { };
  terminal-control = final.callPackage ./terminal-control.nix { };
  iroh-ssh = final.callPackage ./iroh-ssh.nix { };
  # This is a prebuilt npm release; cross-building it only changes the
  # derivation hash and pulls a large cross Node/toolchain closure. Keep it in
  # the target-native package set so its dependencies can substitute.
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
  # Select packages from the platform tuple being evaluated. A cross package
  # set is used only when its build and host platforms match this one.
  zjRadar =
    if !includeZjRadar then
      null
    else if useCrossPackages && crossZjRadar != null then
      crossZjRadar.packages.${buildSystem}.zj-radar
    else
      patchedZjRadarForBuild.packages.${targetSystem}.zj-radar;
  pi = final.callPackage ./pi.nix {
    piPackage = inputs.llm-agents.packages.${targetSystem}.pi;
    agentStuffSrc = inputs."agent-stuff";
    gitHunk = final.git-hunk;
    jjHunk = final.jj-hunk;
    plannotatorPiExtension =
      if targetSystem == "x86_64-linux" then final.plannotator-pi-extension else null;
    inherit includeZjRadar;
    zjRadarCli =
      if !includeZjRadar then
        null
      else if useCrossPackages && crossZjRadar != null then
        crossZjRadar.packages.${buildSystem}.zj-radar-cli
      else
        patchedZjRadarForBuild.packages.${targetSystem}.zj-radar-cli;
  };
  piDev = final.pi.override {
    agentStuffPath = "~/dev/fr/agent-stuff";
  };
  # This is a tiny local wrapper, but cross-compiling it pulls the complete
  # cross stdenv/runtime closure. Prefer the cacheable target-native package;
  # only this derivation may fall back to QEMU when it is not substituted.
  abwrap = final.callPackage ./abwrap/package.nix {
    AIPackages = inputs.llm-agents.packages.${targetSystem};
    codex = inputs.llm-agents.packages.${targetSystem}.codex;
    opencode = inputs.llm-agents.packages.${targetSystem}.opencode;
  };
  pi-acp = final.callPackage ./pi-acp.nix { };
  # Use llm-agents.nix's pinned nixpkgs for zoxide: the corresponding
  # aarch64-linux and x86_64-linux outputs are available from cache.nixos.org,
  # while this flake's newer nixpkgs pin is not.
  zoxide = inputs.llm-agents.inputs.nixpkgs.legacyPackages.${targetSystem}.zoxide;

  # Direct llama.cpp server for Qwen3-Coder-30B-A3B (Vulkan backend — gfx1151
  # is unsupported by ROCm/vLLM). Binaries: qwen3-server, qwen3-get-model,
  # qwen3-bench.
  qwen3-server = final.callPackage ./qwen3-server.nix {
    llamaCpp = prev.llama-cpp.override { vulkanSupport = true; };
  };
  microsandbox = final.callPackage ./microsandbox.nix { };
  # Short alias matching the upstream executable name.
  msb = final.microsandbox;
  frsNvimPackage = inputs.frs-nvim.packages.${targetSystem}.default;
}
