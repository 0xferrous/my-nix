{
  description = "Public Nix building blocks";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://numtide.cachix.org"
      "https://cache.numtide.com"
      "https://noctalia.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    ash = {
      url = "github:0xferrous/ash";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Stable host VM manager, independent from the moving development input.
    ash-stable = {
      url = "github:0xferrous/ash/v0.1.15";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };
    # OpenCode source flake; exposes the `opencode-desktop` Electron app built
    # from source (see ./nix/desktop.nix upstream). Pinned to a release tag so
    # desktop builds are reproducible; follows this flake's nixpkgs so the
    # electron_41/bun pins resolve here.
    opencode = {
      url = "github:anomalyco/opencode/v1.18.26";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    libgit2-patched = {
      url = "github:0xferrous/libgit2?ref=fix/read-only-mmap-private";
      flake = false;
    };
    vicinae = {
      url = "github:vicinaehq/vicinae";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium = {
      url = "github:amaanq/helium-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codexbar = {
      url = "github:0xferrous/CodexBar-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    frs-xofi-menus = {
      url = "github:0xferrous/frs-wofi-menus";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvimpager = {
      url = "github:lucc/nvimpager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # noogle-cli = {
    #   url = "github:juliamertz/noogle-cli";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    numr = {
      url = "github:nasedkinpv/numr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wifitui = {
      url = "github:shazow/wifitui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    multiverse = {
      url = "github:fzakaria/nixpkgs-multiverse";
    };
    agent-box = {
      url = "github:0xferrous/agent-box";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    foundry-stable = {
      url = "github:shazow/foundry.nix/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    foundry-nightly = {
      url = "github:shazow/foundry.nix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agent-images = {
      url = "github:nothingnesses/agent-images";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Noctalia shell for the fr desktop configuration.
    # Deliberately NOT following this flake's nixpkgs: Noctalia pins a
    # nixpkgs tarball and publishes Cachix binaries against it, so following
    # would force a local Qt/C++ rebuild of the shell. Track the `cachix`
    # branch (latest commit with prebuilt binaries) for guaranteed cache hits.
    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    voxtype = {
      url = "github:peteonrails/voxtype";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agent-stuff = {
      url = "github:0xferrous/agent-stuff";
      flake = false;
    };
    hints = {
      url = "github:AlfredoSequeida/hints/0.1.1";
      flake = false;
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghmd = {
      url = "github:0xferrous/ghmd";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zj-radar = {
      url = "github:0xferrous/zj-radar?ref=fix/theme";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.fenix.follows = "fenix";
    };
    # agent-images = {
    #   url = "github:0xferrous/agent-images/feat/nix-ld";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    frs-nvim = {
      url = "path:./pkgs/frs-nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      frs-nvim,
      fenix,
      ghmd,
      impermanence,
      multiverse,
      noctalia-greeter,
      nix-index-database,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      zjRadarSource =
        (import inputs.nixpkgs {
          inherit system;
        }).applyPatches
          {
            name = "zj-radar-patched";
            src = inputs.zj-radar.outPath;
            patches = [ ./patches/zj-radar-crane-name.patch ];
          };
      zjRadar = (import "${zjRadarSource}/flake.nix").outputs {
        self = null;
        nixpkgs = inputs.nixpkgs;
        fenix = inputs.fenix;
        crane = inputs.zj-radar.inputs.crane;
        flake-utils = inputs.zj-radar.inputs.flake-utils;
      };
      overlay = import ./pkgs/overlay.nix {
        inherit inputs system;
        patchedZjRadar = zjRadar;
      };
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ overlay ];
        # Mirror config/agent/nixos.nix: allow only the unfree packages needed
        # by the ChatGPT/Codex desktop app and the Android SDK used for the
        # bb mobile APK.
        config.allowUnfreePredicate =
          pkg:
          builtins.elem (pkg.pname or "") [
            "codex-desktop"
            "android-sdk-build-tools"
            "android-sdk-cmdline-tools"
            "cmake"
            "android-sdk-ndk"
            "android-sdk-platform-tools"
            "android-sdk-platforms"
            "android-sdk-tools"
            "build-tools"
            "cmdline-tools"
            "ndk"
            "platform-tools"
            "platforms"
            "tools"
          ];
        # gradle 7.x (needed by tron-wallet-cli-java's shadow-jar plugin) is marked
        # insecure in nixpkgs due to unfixed CVEs; required to build it.
        config.permittedInsecurePackages = [
          "gradle-7.6.6"
          "pnpm-9.15.9"
        ];
      };
      lib = pkgs.lib;
      agentOciNixos = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          myNixInputs = inputs;
          inherit
            fenix
            ghmd
            home-manager
            impermanence
            nix-index-database
            ;
        };
        modules = [
          ./config/agent/nixos.nix
          ./config/agent/oci.nix
        ];
      };
    in
    {
      overlays.default = overlay;

      packages = lib.recursiveUpdate frs-nvim.packages {
        ${system} = {
          inherit (pkgs)
            fr-frame-summon
            fr-kbd-backlight
            dev-essentials
            git-hunk
            ironclaw
            jj-hunk
            google-authenticator-transfer-decode
            oh-my-pi
            opensrc
            nash
            obscura
            pi
            piDev
            abwrap
            pi-acp
            takopi
            tron-wallet-cli
            tron-wallet-cli-java
            terminal-control
            iroh-ssh
            ssh-tmp
            prime-agent
            flake-utils
            gruvbox-gtk-theme
            qwen3-server
            codex-desktop
            bb
            tolaria
            ;
          "bb-source" = pkgs.bbSource;
          "bb-android" = pkgs."bb-android";
          "bb-android-x86_64" = pkgs."bb-android-x86_64";
          "bb-android-arm64-v8a" = pkgs."bb-android-arm64-v8a";
          opencode-desktop = inputs.opencode.packages.${system}.opencode-desktop;
          "install-bin" = pkgs."install-bin";
          iron-proxy = pkgs.iron-proxy;
          agent-container-image =
            let
              agent = agentOciNixos;
            in
            pkgs.dockerTools.buildImageWithNixDb {
              name = "fr-agent";
              tag = "latest";
              compressor = "none";
              copyToRoot = agent.config.system.build.toplevel;
              keepContentsDirlinks = true;
              extraCommands = ''
                rm -f etc
                mkdir -p proc sys dev etc
              '';
              config = {
                Entrypoint = [ "/init" ];
                Env = [
                  "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
                  "NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-bundle.crt"
                ];
              };
            };
        };
      };
      apps = lib.recursiveUpdate frs-nvim.apps {
        ${system} = {
          pi = {
            type = "app";
            program = "${pkgs.pi}/bin/pi";
          };
          piDev = {
            type = "app";
            program = "${pkgs.piDev}/bin/pi";
          };
          abwrap = {
            type = "app";
            program = "${pkgs.abwrap}/bin/abwrap";
          };
          takopi = {
            type = "app";
            program = "${pkgs.takopi}/bin/takopi";
          };
          prime-agent = {
            type = "app";
            program = "${pkgs.prime-agent}/bin/prime-agent";
          };
          "install-bin" = {
            type = "app";
            program = "${pkgs."install-bin"}/bin/install-bin";
          };
          google-authenticator-transfer-decode = {
            type = "app";
            program = "${pkgs.google-authenticator-transfer-decode}/bin/google-authenticator-transfer-decode";
          };
          qwen3-server = {
            type = "app";
            program = "${pkgs.qwen3-server}/bin/qwen3-server";
          };
          qwen3-get-model = {
            type = "app";
            program = "${pkgs.qwen3-server}/bin/qwen3-get-model";
          };
          qwen3-bench = {
            type = "app";
            program = "${pkgs.qwen3-server}/bin/qwen3-bench";
          };
          bb = {
            type = "app";
            program = "${pkgs.bb}/bin/bb-desktop";
            meta = pkgs.bb.meta;
          };
          "bb-source" = {
            type = "app";
            program = "${pkgs.bbSource}/bin/bb-desktop";
            meta = pkgs.bbSource.meta;
          };
        };
      };

      formatter.${system} = pkgs.nixfmt-tree;

      lib.makeBbDesktopEntry = import ./lib/makeBbDesktopEntry.nix;
      lib.mkAgentBoxImage =
        args:
        import ./lib/mkAgentBoxImage.nix (
          args
          // {
            inputs = inputs // {
              foundry = inputs.foundry-stable;
            };
          }
        );
      homeManagerModules = import ./modules/home;
      nixosModules = import ./modules/nixos;
      homeConfigs = {
        fr =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            myNixInputs = inputs;
          in
          {
            imports = [
              inputs.agent-box.homeManagerModules.default
              (import ./config/fr/home.nix {
                inherit
                  config
                  lib
                  myNixInputs
                  pkgs
                  ;
              })
            ];
            _module.args.myNixInputs = inputs;
          };
      };
      homeConfigurations.agent = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs.myNixInputs = inputs;
        modules = [ ./config/agent/home.nix ];
      };

      nixosConfigs = {
        fr = import ./config/fr/nixos.nix {
          inherit
            fenix
            ghmd
            multiverse
            noctalia-greeter
            ;
        };
        agent = {
          imports = [ ./config/agent/nixos.nix ];
          _module.args = {
            myNixInputs = inputs;
            inherit
              fenix
              ghmd
              home-manager
              impermanence
              nix-index-database
              ;
          };
        };
        nash = {
          imports = [ ./config/agent/nash.nix ];
          _module.args = {
            myNixInputs = inputs;
            inherit
              fenix
              ghmd
              home-manager
              impermanence
              nix-index-database
              ;
          };
        };
      };

      nixosConfigurations = {
        agent = inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            myNixInputs = inputs;
            inherit
              fenix
              ghmd
              home-manager
              impermanence
              nix-index-database
              ;
          };
          modules = [
            ./config/agent/nixos.nix
          ];
        };

        nash = inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            myNixInputs = inputs;
            inherit
              fenix
              ghmd
              home-manager
              impermanence
              nix-index-database
              ;
          };
          modules = [
            ./config/agent/nash.nix
          ];
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          dhall
          dhall-json
          haskellPackages.dhall-toml
        ];
      };
    };
}
