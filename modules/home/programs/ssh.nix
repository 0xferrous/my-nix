{
  config,
  lib,
  ...
}:

let
  cfg = config.fr.ssh;

  identityType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Match block name.";
      };

      identityFile = lib.mkOption {
        type = lib.types.str;
        description = "SSH identity file path for this match block.";
      };
    };
  };

  identityMatchBlocks = builtins.listToAttrs (
    map (identity: {
      name = identity.name;
      value = {
        hostname = "github.com";
        inherit (identity) identityFile;
        extraOptions.pubkeyAuthentication = "yes";
      };
    }) cfg.identities
  );
in
{
  options.fr.ssh = {
    enable = lib.mkEnableOption "managed Home Manager SSH config";

    identities = lib.mkOption {
      type = lib.types.listOf identityType;
      default = [ ];
      description = "SSH match blocks to generate for GitHub identities.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = identityMatchBlocks // {
        "*" = {
          # Recommended by Filo Sottile's whoami.filippo.io to avoid
          # offering all public keys by default; configure explicit per-host
          # IdentityFile entries instead.
          # See: https://github.com/FiloSottile/whoami.filippo.io#how-do-i-stop-it
          identitiesOnly = true;
          extraOptions.pubkeyAuthentication = "no";
        };
      };
    };
  };
}
