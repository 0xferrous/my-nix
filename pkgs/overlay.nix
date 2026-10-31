{
  inputs,
}:
final: prev:
let
  targetSystem = final.stdenv.hostPlatform.system;
  activitywatchSource = final.fetchFromGitHub {
    owner = "ActivityWatch";
    repo = "activitywatch";
    tag = "v0.14.1";
    hash = "sha256-Euom8p8pdwPRX7C4FuUZYp+6mhFaWIeGcVR4xOi+zXE=";
    fetchSubmodules = true;
  };
  activitywatchBase = final.qt6Packages.callPackage (
    inputs.nixpkgs + "/pkgs/applications/office/activitywatch"
  ) { };
  activitywatchWebui = activitywatchBase.aw-webui.overrideAttrs (old: {
    version = "0.14.1";
    src = "${activitywatchSource}/aw-server-rust/aw-webui";
    npmDeps = final.fetchNpmDeps {
      name = "aw-webui-0.14.1-npm-deps";
      src = "${activitywatchSource}/aw-server-rust/aw-webui";
      hash = "sha256-8/eM6t9bOdqXkCTgqF4tcDwnTXdcq1jPL6Wayijt+is=";
    };
    patches = [
      (final.replaceVars (inputs.nixpkgs + "/pkgs/applications/office/activitywatch/commit-hash.patch") {
        commit_hash = "v0.14.1";
      })
    ];
    doCheck = false;
  });
  activitywatchServer = activitywatchBase.aw-server-rust.overrideAttrs (old: {
    version = "0.14.1";
    src = "${activitywatchSource}/aw-server-rust";
    cargoDeps = final.rustPlatform.fetchCargoVendor {
      pname = "aw-server-rust";
      version = "0.14.1";
      src = "${activitywatchSource}/aw-server-rust";
      hash = "sha256-x6Qp8nW3EbQbeVPrvV1UQdKMkU83qachrtNOGh30HWw=";
    };
    patches = [ ];
    postPatch = ''
      substituteInPlace aw-server/src/version.rs \
        --replace-fail 'format!("v{} (rust)", VERSION.unwrap_or("(unknown)"))' \
        'String::from("v0.14.1 (rust)")'
    '';
    cargoBuildFlags = [
      "-p"
      "aw-server"
    ];
    cargoTestFlags = [
      "-p"
      "aw-server"
    ];
    env = (old.env or { }) // {
      AW_WEBUI_DIR = activitywatchWebui;
    };
  });
  activitywatchPackage =
    final.callPackage (inputs.nixpkgs + "/pkgs/applications/office/activitywatch/wrapper.nix")
      {
        aw-server-rust = activitywatchServer;
        aw-qt = activitywatchBase.aw-qt;
        aw-notify = activitywatchBase.aw-notify;
        aw-watcher-afk = activitywatchBase.aw-watcher-afk;
        aw-watcher-window = activitywatchBase.aw-watcher-window;
      };
  # Ternary Bonsai 2 uses PrismML's PTQ1_0/PQ2_0 GGUF formats, which are not
  # understood by stock llama.cpp yet. Keep the fork pinned to a known PrismML
  # tag until those formats land upstream.
  prismLlamaCpp =
    backend:
    let
      base =
        if backend == "rocm" then
          prev.llama-cpp.override { rocmSupport = true; }
        else
          prev.llama-cpp.override { vulkanSupport = true; };
    in
    base.overrideAttrs (old: {
      pname = "llama-cpp-prism";
      version = "10743";
      src = final.fetchFromGitHub {
        owner = "PrismML-Eng";
        repo = "llama.cpp";
        tag = "prism-b10743-adfffbe";
        hash = "sha256-SNBAC+dNTwQxpGmKyG7i/8eqCNg6985DXtqGbzWgwFA=";
      };
      npmDepsHash = "sha256-2Q7XhaLAArmviOLdQsNbYTfdyDE5pW9lR26cRHEVl9k=";
      preConfigure = ''
        prependToVar cmakeFlags "-DLLAMA_BUILD_COMMIT:STRING=adfffbe"
        pushd ${old.npmRoot}
        LLAMA_BUILD_NUMBER=10743 npm run build
        popd
      '';
      # This fork is pinned to a PrismML tag; do not let the dynamic package
      # updater inherit llama.cpp's upstream update script.
      passthru = (old.passthru or { }) // {
        updateScript = null;
      };
      meta = old.meta // {
        description = "PrismML llama.cpp fork with ternary Bonsai GGUF support";
        homepage = "https://github.com/PrismML-Eng/llama.cpp";
      };
    });
in
{
  activitywatch = activitywatchPackage;
  herdr = inputs.llm-agents.packages.${targetSystem}.herdr;
  herdr-core = final.callPackage ./herdr-core.nix { };
  herdr-app = final.callPackage ./herdr-app.nix { inherit (final) herdr-core; };

  ashWrappers = import ./ash-portal-wrappers.nix {
    inherit (final) lib runCommand symlinkJoin;
    ashPackage = inputs.ash.packages.${targetSystem}.all or inputs.ash.packages.${targetSystem}.ash;
  };
  fr-frame-summon = final.callPackage ./frame-summon.nix { };
  fr-kbd-backlight = final.callPackage ./keyboard-backlight.nix { };
  waydroid-size = final.callPackage ./waydroid-size.nix { };
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
  bb-connect = final.callPackage ./bb-connect.nix {
    bbPackage = final.bb;
  };
  # Keep the Electron/Node build in the target-native package set so its
  # native-module closure can use the target's binary cache.
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
  vicu = final.callPackage ./vicu.nix { };
  hibi = final.callPackage ./hibi.nix { };
  lightpanda = final.callPackage ./lightpanda.nix { };
  # Upstream Lightpanda Agent Skills: the `lightpanda` skill at the repo root
  # plus its `pandascript` companion. Linked into ~/.agents/skills by
  # `fr.skills`. Bump the rev and hash together (nix flake prefetch
  # github:lightpanda-io/agent-skill).
  lightpanda-skills = final.fetchFromGitHub {
    owner = "lightpanda-io";
    repo = "agent-skill";
    rev = "387702e5b8d5034037a6a1ca7c41a727232e7cd4";
    hash = "sha256-4V6xBDlg01QWT2m1iT0OR4bSY37hfx1MOzxwN67VBJA=";
  };
  kero = final.callPackage ./kero.nix {
    source = inputs.kero-src;
    go_1_27 =
      (import inputs.kero-toolchain-nixpkgs {
        system = final.stdenv.hostPlatform.system;
      }).go_1_27;
  };
  # nixpkgs removed Framesh as unmaintained; retain the pinned AppImage package.
  framesh = final.callPackage ./framesh.nix { };
  dev-essentials = final.callPackage ./dev-essentials.nix {
    AIPackages = inputs.llm-agents.packages.${targetSystem};
  };
  executor = final.callPackage ./executor.nix { };
  obscura = final.callPackage ./obscura/package.nix { };
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
  hints = final.callPackage ./hints.nix {
    source = inputs.hints;
    atspi2Core = final."at-spi2-core";
    gtkLayerShell = final."gtk-layer-shell";
  };
  "install-bin" = final.callPackage ./install-bin.nix { };
  flake-utils = final.callPackage ./flake-utils.nix { };
  gruvbox-gtk-theme = final.callPackage ./gruvbox-gtk-theme.nix { };
  plannotator-pi-extension = final.callPackage ./plannotator-pi-extension.nix { };
  # Select packages from the platform being evaluated.
  pi = final.callPackage ./pi.nix {
    piPackage = inputs.llm-agents.packages.${targetSystem}.pi;
    agentStuffSrc = inputs."agent-stuff";
    gitHunk = final.git-hunk;
    jjHunk = final.jj-hunk;
    # Bundle the drydock skill so agents can preview OS config changes.
    drydockSkill = if inputs ? drydock then "${inputs.drydock}/skills/drydock" else null;
    plannotatorPiExtension =
      if targetSystem == "x86_64-linux" then final.plannotator-pi-extension else null;
  };
  piDev = final.pi.override {
    agentStuffPath = "~/dev/fr/agent-stuff";
  };
  # Prefer the target-native package so the wrapper's runtime closure can
  # substitute from the target's binary cache.
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

  # numr >= 0.8.0 moved its flake outputs to `numr.<system>.packages` instead
  # of the conventional `numr.packages.<system>`, and its new unit tests build
  # reqwest clients, which fail in the Nix sandbox without a CA bundle. Point
  # them at nixpkgs' cacert so the upstream test suite still runs.
  numr = inputs.numr.${targetSystem}.packages.default.overrideAttrs (old: {
    nativeCheckInputs = (old.nativeCheckInputs or [ ]) ++ [ final.cacert ];
    preCheck = (old.preCheck or "") + ''
      export SSL_CERT_FILE=${final.cacert}/etc/ssl/certs/ca-bundle.crt
    '';
  });

  microsandbox = final.callPackage ./microsandbox.nix { };
  llama-cpp-prism-rocm = prismLlamaCpp "rocm";
  llama-cpp-prism-vulkan = prismLlamaCpp "vulkan";
  # Short alias matching the upstream executable name.
  msb = final.microsandbox;
  frsNvimPackage = inputs.frs-nvim.packages.${targetSystem}.default;
}
