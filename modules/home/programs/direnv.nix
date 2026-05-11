{ config, lib, pkgs, ... }:
let
  cfg = config.fr.direnv;
in
{
  options.fr.direnv = {
    enable = lib.mkEnableOption "direnv shell integration";

    layoutDir = {
      enable = lib.mkEnableOption "direnv_layout_dir helper";

      baseDir = lib.mkOption {
        type = lib.types.str;
        default = ''
          ''${XDG_CACHE_HOME:-''${HOME}/.cache}/direnv/layouts
        '';
        description = "Base directory used by direnv_layout_dir.";
      };
    };

    devenv = {
      enable = lib.mkEnableOption "devenv direnv integration";
    };

    poetry = {
      enable = lib.mkEnableOption "Poetry direnv integration";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      lib.optionals cfg.devenv.enable [ pkgs.devenv ]
      ++ lib.optionals cfg.poetry.enable [ pkgs.poetry ];

    programs.direnv.stdlib = lib.concatStringsSep "\n\n" (
      lib.optional cfg.layoutDir.enable ''
        declare -A direnv_layout_dirs
        direnv_layout_dir() {
            local hash path
            echo "''${direnv_layout_dirs[$PWD]:=$(
                hash="$(sha1sum - <<< "$PWD" | head -c40)"
                path="''${PWD//[^a-zA-Z0-9]/-}"
                echo "${cfg.layoutDir.baseDir}/''${hash}''${path}"
            )}"
        }
      ''
      ++ lib.optional cfg.poetry.enable ''
        layout_poetry() {
          if ! command -v poetry >/dev/null 2>&1; then
            log_error "poetry not found"
            return 1
          fi

          local VENV
          VENV=$(poetry env info --path 2>/dev/null)

          if [ -z "$VENV" ]; then
            log_error "No poetry virtualenv found. Run 'poetry install' first."
            return 1
          fi

          export VIRTUAL_ENV="$VENV"
          export PATH="$VENV/bin:$PATH"
        }
      ''
      ++ lib.optional cfg.devenv.enable ''
        eval "$(devenv direnvrc)"
      ''
    );
  };
}
