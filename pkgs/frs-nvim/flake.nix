{
  description = "Portable Neovim wrapper config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-wrapper-modules = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Missing plugins from nixpkgs: packaged via flake inputs + buildVimPlugin.
    plugin-ansi-nvim = {
      url = "github:0xferrous/ansi.nvim";
      flake = false;
    };
    plugin-eth-nvim = {
      url = "github:0xferrous/eth.nvim";
      flake = false;
    };
    plugin-vim-circom-syntax = {
      url = "github:iden3/vim-circom-syntax";
      flake = false;
    };
    plugin-flote = {
      url = "github:JellyApple102/flote.nvim";
      flake = false;
    };
    plugin-feed-nvim = {
      url = "github:neo451/feed.nvim";
      flake = false;
    };
    plugin-fff-nvim = {
      url = "github:dmtrKovalenko/fff.nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plugin-nightsky-vim = {
      url = "github:nvimdev/nightsky.vim";
      flake = false;
    };
    plugin-mcphub-nvim = {
      url = "github:ravitemer/mcphub.nvim";
      flake = false;
    };
    plugin-logger-nvim = {
      url = "github:rmagatti/logger.nvim";
      flake = false;
    };
    plugin-toggleterm-manager = {
      url = "github:ryanmsnyder/toggleterm-manager.nvim";
      flake = false;
    };
    plugin-stickybuf-nvim = {
      url = "github:stevearc/stickybuf.nvim";
      flake = false;
    };
    plugin-floating-help = {
      url = "github:Tyler-Barham/floating-help.nvim";
      flake = false;
    };
    plugin-neotest-foundry = {
      url = "github:llllvvuu/neotest-foundry";
      flake = false;
    };
    plugin-diffie-nvim = {
      url = "path:/home/dmnt/dev/fr/diffie.nvim";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-wrapper-modules,
      ...
    }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          mkPluginFromInput =
            pname: inputName:
            pkgs.vimUtils.buildVimPlugin {
              inherit pname;
              src = builtins.getAttr inputName inputs;
              version = toString ((builtins.getAttr inputName inputs).lastModifiedDate or "master");
              doCheck = false;
            };

          customVimPlugins = {
            ansi-nvim = mkPluginFromInput "ansi.nvim" "plugin-ansi-nvim";
            eth-nvim = mkPluginFromInput "eth.nvim" "plugin-eth-nvim";
            vim-circom-syntax = mkPluginFromInput "vim-circom-syntax" "plugin-vim-circom-syntax";
            flote-nvim = mkPluginFromInput "flote.nvim" "plugin-flote";
            feed-nvim = mkPluginFromInput "feed.nvim" "plugin-feed-nvim";
            fff-nvim = inputs.plugin-fff-nvim.packages.${system}.fff-nvim.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [
                ./patches/fff-full-relative-path-display.patch
              ];
            });
            gitlinker-nvim = pkgs.vimPlugins.gitlinker-nvim.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [
                ./patches/gitlinker-ssh-alias-host-resolution.patch
              ];
            });
            nightsky-vim = mkPluginFromInput "nightsky.vim" "plugin-nightsky-vim";
            mcphub-nvim = mkPluginFromInput "mcphub.nvim" "plugin-mcphub-nvim";
            logger-nvim = mkPluginFromInput "logger.nvim" "plugin-logger-nvim";
            toggleterm-manager-nvim = mkPluginFromInput "toggleterm-manager.nvim" "plugin-toggleterm-manager";
            stickybuf-nvim = mkPluginFromInput "stickybuf.nvim" "plugin-stickybuf-nvim";
            floating-help-nvim = mkPluginFromInput "floating-help.nvim" "plugin-floating-help";
            neotest-foundry-nvim = mkPluginFromInput "neotest-foundry" "plugin-neotest-foundry";
            diffie-nvim = mkPluginFromInput "diffie.nvim" "plugin-diffie-nvim";
          };

          supermavenMeta =
            {
              x86_64-linux = {
                url = "https://supermaven-public.s3.amazonaws.com/sm-agent/v2/8/linux-musl/x86_64/sm-agent";
                hash = "sha256-lsaS7IoNQUIkTL1Qo+UymeD8y4eX4mPR6XFC2qMlp4g=";
              };
              aarch64-linux = {
                url = "https://supermaven-public.s3.amazonaws.com/sm-agent/v2/8/linux-musl/aarch64/sm-agent";
                hash = "sha256-FXot8/QnrInCiJP+a+SnMOOOmCv1BHEwP9T58bXqe98=";
              };
              x86_64-darwin = {
                url = "https://supermaven-public.s3.amazonaws.com/sm-agent/v2/8/darwin/x86_64/sm-agent";
                hash = "sha256-ZUK4h3oAp1KWXhhJDE502v1jlhGLzV452u2W1z+IXK0=";
              };
              aarch64-darwin = {
                url = "https://supermaven-public.s3.amazonaws.com/sm-agent/v2/8/darwin/aarch64/sm-agent";
                hash = "sha256-wocLx/s6h98HNDVmUH3HV/oZOb9WgiIeTteZ1FzG3rc=";
              };
            }
            .${system};

          supermaven-agent =
            pkgs.runCommand "supermaven-agent"
              {
                src = pkgs.fetchurl {
                  inherit (supermavenMeta) url hash;
                };
              }
              ''
                install -Dm755 "$src" "$out/bin/sm-agent"
              '';

          # Lua config - no Fennel compilation needed
          luaConfig =
            pkgs.runCommand "nvim-config"
              {
                nativeBuildInputs = [ ];
              }
              ''
                mkdir -p $out/lua/cfg
                mkdir -p $out/lua/plugins
                mkdir -p $out/lua/ftplugin
                mkdir -p $out/lua/plugins/graveyard

                # Copy all Lua files from the repo
                cp ${./lua/cfg}/*.lua $out/lua/cfg/
                cp ${./lua/plugins}/*.lua $out/lua/plugins/ 2>/dev/null || true
                cp ${./lua/plugins/graveyard}/*.lua $out/lua/plugins/graveyard/ 2>/dev/null || true
                cp ${./lua/ftplugin}/*.lua $out/lua/ftplugin/ 2>/dev/null || true
                cp ${./lua}/*.lua $out/lua/ 2>/dev/null || true

                # Set up package path
                cat > "$out/init.lua" <<EOF
                package.path = "$out/lua/?.lua;$out/lua/?/init.lua;" .. package.path
                vim.opt.rtp:prepend("$out")
                vim.loader.enable()
                require("cfg")
                EOF
              '';

          defaultLspPackages = with pkgs; {
            go = go;
            gopls = gopls;
            lua-language-server = lua-language-server;
            typescript = typescript;
            typescript-language-server = typescript-language-server;
            ccls = ccls;
            marksman = marksman;
            zls = zls;
            zig = zig;
            ty = ty;
            nushell = nushell;
            zk = zk;
          };

          lspPackageOrder = [
            "go"
            "gopls"
            "lua-language-server"
            "typescript"
            "typescript-language-server"
            "ccls"
            "marksman"
            "zls"
            "zig"
            "ty"
            "nushell"
            "zk"
          ];

          mkWrappedNvim = lib.makeOverridable (
            {
              lspPackages ? { },
              extraRuntimePackages ? [ ],
            }:
            let
              resolvedLspPackages = defaultLspPackages // lspPackages;
              lspRuntimePackages = map (name: resolvedLspPackages.${name}) lspPackageOrder;
              wrappedNvimBase = nix-wrapper-modules.lib.evalPackage [
                (
                  { wlib, ... }:
                  {
                    imports = [ wlib.wrapperModules.neovim ];

                    binName = "nvim";

                    settings = {
                      config_directory = luaConfig;
                      aliases = [
                        "vi"
                        "vim"
                      ];
                    };

                    # Install plugins from nixpkgs rather than downloading at runtime.
                    # Keep packages in /opt and let lze drive loading behavior.
                    specs.nixpkgs = {
                      lazy = true;
                      pluginDeps = false;
                      collateGrammars = false;
                      data = with pkgs.vimPlugins; [
                        FixCursorHold-nvim
                        tabular
                        aw-watcher-nvim
                        aw-watcher-vim
                        blink-cmp
                        blink-compat
                        catppuccin-nvim
                        codecompanion-nvim
                        comment-nvim
                        conform-nvim
                        conflict-marker-vim
                        crates-nvim
                        dropbar-nvim
                        fidget-nvim
                        firenvim
                        friendly-snippets
                        vim-fugitive
                        customVimPlugins.gitlinker-nvim
                        gitsigns-nvim
                        goto-preview
                        gruvbox
                        gruvbox-material
                        harpoon2
                        hop-nvim
                        iceberg-vim
                        kanagawa-nvim
                        kitty-scrollback-nvim
                        lualine-nvim
                        mini-diff
                        mini-icons
                        mini-nvim
                        neo-tree-nvim
                        neodev-nvim
                        neorg
                        neotest
                        night-owl-nvim
                        nvim-autopairs
                        nvim-lspconfig
                        nvim-luapad
                        nvim-nio
                        nvim-paredit
                        nvim-pqf
                        (nvim-treesitter.withAllGrammars)
                        nvim-treesitter-textobjects
                        nvim-ufo
                        nvim-web-devicons
                        nui-nvim
                        octo-nvim
                        oil-nvim
                        orgmode
                        overseer-nvim
                        oxocarbon-nvim
                        plenary-nvim
                        promise-async
                        rainbow-delimiters-nvim
                        render-markdown-nvim
                        rose-pine
                        rustaceanvim
                        vim-sleuth
                        snacks-nvim
                        supermaven-nvim
                        symbols-outline-nvim
                        vim-table-mode
                        telescope-fzf-native-nvim
                        telescope-nvim
                        telescope-project-nvim
                        telescope-ui-select-nvim
                        telescope-undo-nvim
                        todo-comments-nvim
                        tokyonight-nvim
                        toggleterm-nvim
                        trouble-nvim
                        venn-nvim
                        vim-be-good
                        vim-eunuch
                        vim-illuminate
                        vim-matchup
                        vim-startuptime
                        vim-unimpaired
                        which-key-nvim
                        yats-vim
                        yuck-vim
                        zk-nvim
                      ];
                    };

                    specs.custom = {
                      lazy = true;
                      pluginDeps = false;
                      collateGrammars = false;
                      data = builtins.attrValues customVimPlugins;
                    };

                    # lze drives runtime lazy behavior, so it must be available at startup.
                    specs.lze = {
                      data = pkgs.vimPlugins.lze;
                      lazy = false;
                    };

                    # Runtime helpers + LSP servers for a self-contained wrapped Neovim.
                    extraPackages =
                      with pkgs;
                      [
                        git
                        fd
                        ripgrep
                      ]
                      ++ lspRuntimePackages
                      ++ extraRuntimePackages
                      ++ [
                        # Packaged Supermaven agent binary (sm-agent)
                        supermaven-agent
                      ];
                  }
                )
                { inherit pkgs; }
              ];
            in
            # Home Manager's Neovim module expects package.lua (like neovim-unwrapped.lua).
            wrappedNvimBase // {
              lua = pkgs.neovim-unwrapped.lua;
            }
          );

          wrappedNvim = mkWrappedNvim { };

          smoke = pkgs.writeShellScriptBin "nvim-smoke" ''
            set -euo pipefail
            tmp="$(mktemp -d)"
            trap 'rm -rf "$tmp"' EXIT
            export XDG_CACHE_HOME="$tmp/cache"
            export XDG_STATE_HOME="$tmp/state"
            export XDG_DATA_HOME="$tmp/data"
            exec ${wrappedNvim}/bin/nvim --headless "+luafile ${./scripts/smoke-lazy.lua}"
          '';

          smoke-lsp = pkgs.writeShellScriptBin "nvim-smoke-lsp" ''
            set -euo pipefail
            tmp="$(mktemp -d)"
            trap 'rm -rf "$tmp"' EXIT
            export XDG_CACHE_HOME="$tmp/cache"
            export XDG_STATE_HOME="$tmp/state"
            export XDG_DATA_HOME="$tmp/data"
            exec ${wrappedNvim}/bin/nvim --headless "+luafile ${./scripts/smoke-lsp.lua}"
          '';

          smoke-commands = pkgs.writeShellScriptBin "nvim-smoke-commands" ''
            set -euo pipefail
            tmp="$(mktemp -d)"
            trap 'rm -rf "$tmp"' EXIT
            export XDG_CACHE_HOME="$tmp/cache"
            export XDG_STATE_HOME="$tmp/state"
            export XDG_DATA_HOME="$tmp/data"
            exec ${wrappedNvim}/bin/nvim --headless "+luafile ${./scripts/smoke-commands.lua}"
          '';

          live = pkgs.writeShellScriptBin "nvim-live" ''
            set -euo pipefail

            root="''${NVIM_LIVE_CONFIG_ROOT:-$PWD}"
            if [ ! -f "$root/lua/cfg/init.lua" ]; then
              echo "nvim-live: expected lua/cfg/init.lua in config root: $root" >&2
              echo "Set NVIM_LIVE_CONFIG_ROOT to override (e.g. repo root)." >&2
              exit 1
            fi

            tmp="$(mktemp -d)"
            trap 'rm -rf "$tmp"' EXIT

            export HOME="''${NVIM_LIVE_HOME:-$tmp/home}"
            export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$tmp/cache}"
            export XDG_STATE_HOME="''${XDG_STATE_HOME:-$tmp/state}"
            export XDG_DATA_HOME="''${XDG_DATA_HOME:-$tmp/data}"
            mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$XDG_DATA_HOME"

            export PATH="${lib.makeBinPath [ pkgs.git pkgs.fd pkgs.ripgrep ]}:$PATH"
            export NVIM_LIVE_CONFIG_ROOT="$root"

            cat > "$tmp/init.lua" <<'EOF'
            local root = os.getenv("NVIM_LIVE_CONFIG_ROOT")
            if not root or root == "" then
              root = vim.fn.getcwd()
            end

            package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path
            vim.opt.rtp:prepend(root)
            vim.loader.enable()

            require("cfg")
            EOF

            exec ${wrappedNvim}/bin/nvim \
              -u "$tmp/init.lua" \
              "$@"
          '';

        in
        {
          nvim = wrappedNvim;
          smoke = smoke;
          smoke-lsp = smoke-lsp;
          smoke-commands = smoke-commands;
          live = live;
          default = wrappedNvim;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkg = self.packages.${system}.default;
          smoke = self.packages.${system}.smoke;
          smoke-lsp = self.packages.${system}.smoke-lsp;
          smoke-commands = self.packages.${system}.smoke-commands;
          live = self.packages.${system}.live;
        in
        {
          nvim = {
            type = "app";
            program = "${pkg}/bin/nvim";
          };
          smoke = {
            type = "app";
            program = "${smoke}/bin/nvim-smoke";
          };
          smoke-lsp = {
            type = "app";
            program = "${smoke-lsp}/bin/nvim-smoke-lsp";
          };
          smoke-commands = {
            type = "app";
            program = "${smoke-commands}/bin/nvim-smoke-commands";
          };
          live = {
            type = "app";
            program = "${live}/bin/nvim-live";
          };
          default = self.apps.${system}.nvim;
        }
      );
    };
}
