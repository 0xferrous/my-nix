{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.fr.pass;

  storeType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Suffix for the generated pass wrapper, producing `pass-<name>`.";
      };

      store_dir = lib.mkOption {
        type = lib.types.str;
        description = "Password store directory exposed as PASSWORD_STORE_DIR for the generated wrapper.";
      };
    };
  };

  scriptText = ''
    exec pass "$@"
  '';

  mkStoreWrapper = store:
    pkgs.writeShellApplication {
      name = "pass-${store.name}";
      text = scriptText;
      runtimeEnv = {
        PASSWORD_STORE_DIR = store.store_dir;
      };
    };
in
{
  options.fr.pass = {
    enable = lib.mkEnableOption "pass/password-store helpers";

    stores = lib.mkOption {
      type = lib.types.listOf storeType;
      default = [ ];
      description = "Named password stores for which pass wrapper scripts should be generated.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.password-store = {
      enable = true;
      package = pkgs.pass.withExtensions (
        exts:
        builtins.attrValues {
          inherit (exts) pass-otp;
        }
      );
      settings = {
        PASSWORD_STORE_DIR = lib.mkDefault "$HOME/.password-store";
      };
    };

    programs.browserpass = {
      browsers = [ "firefox" ];
      enable = true;
    };

    home.packages = map mkStoreWrapper cfg.stores;
  };
}
