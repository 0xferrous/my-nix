{ pkgs, ... }:
{
  home.packages = with pkgs; [
    bash-language-server
    biome
    clang-tools
    lua-language-server
    marksman
    nil
    nixfmt-rfc-style
    pyright
    shellcheck
    shfmt
    taplo
    typescript-language-server
    vscode-langservers-extracted
    yaml-language-server
  ];

  programs.helix = {
    enable = true;
    settings = {
      theme = "gruvbox_dark_hard";

      editor = {
        line-number = "relative";
        mouse = true;
        bufferline = "multiple";
        color-modes = true;
        cursorline = true;
        true-color = true;
        rulers = [ 100 ];
        scrolloff = 8;
        popup-border = "all";
        end-of-line-diagnostics = "hint";

        cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };

        file-picker = {
          hidden = false;
          git-ignore = true;
        };

        indent-guides = {
          render = true;
          character = "┊";
        };

        lsp = {
          display-messages = true;
          display-inlay-hints = true;
          display-signature-help-docs = true;
        };

        soft-wrap = {
          enable = true;
          wrap-at-text-width = true;
        };

        statusline = {
          left = [
            "mode"
            "spinner"
            "file-name"
            "read-only-indicator"
            "file-modification-indicator"
          ];
          center = [ "version-control" ];
          right = [
            "diagnostics"
            "selections"
            "register"
            "position"
            "file-encoding"
            "file-line-ending"
            "file-type"
          ];
          separator = "│";
          mode.normal = "NORMAL";
          mode.insert = "INSERT";
          mode.select = "SELECT";
        };

        whitespace = {
          render = {
            space = "none";
            tab = "all";
            newline = "none";
          };
          characters = {
            tab = "→";
            tabpad = "·";
          };
        };
      };

      keys.normal = {
        space.w = ":write";
        space.q = ":quit";
        space.x = ":buffer-close";
        space.X = ":buffer-close!";
        space.e = "file_picker";
        space.E = "file_picker_in_current_directory";
        space.b = "buffer_picker";
        space.g = "changed_file_picker";
        space.f = "global_search";
        space.F = "search_selection";
        space.r = "rename_symbol";
        space.a = "code_action";
        space.d = "diagnostics_picker";
        space.D = "workspace_diagnostics_picker";
        space.o = "symbol_picker";
        space.O = "workspace_symbol_picker";
        space.s = ":write";
        esc = [
          "collapse_selection"
          "keep_primary_selection"
        ];
      };
    };

    languages = {
      language-server.nil.config.nil = {
        formatting.command = [ "nixfmt" ];
        nix.flake.autoArchive = true;
      };

      language = [
        {
          name = "nix";
          auto-format = true;
          formatter.command = "nixfmt";
          language-servers = [ "nil" ];
        }
        {
          name = "bash";
          auto-format = true;
          formatter.command = "shfmt";
        }
        {
          name = "rust";
          auto-format = true;
        }
        {
          name = "toml";
          auto-format = true;
        }
        {
          name = "json";
          auto-format = true;
          formatter = {
            command = "biome";
            args = [
              "format"
              "--stdin-file-path"
              "buffer.json"
            ];
          };
        }
        {
          name = "markdown";
          soft-wrap.enable = true;
          text-width = 100;
        }
        {
          name = "git-commit";
          rulers = [ 72 ];
          text-width = 72;
        }
      ];
    };
  };
}
