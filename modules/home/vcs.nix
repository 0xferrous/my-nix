{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.fr.vcs;

  # One identity schema is shared by both Git and Jujutsu so callers only
  # define names/emails/signing keys once under `fr.vcs`.
  identityOptions = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "VCS user name.";
    };
    email = lib.mkOption {
      type = lib.types.str;
      description = "VCS user email.";
    };
    signingKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "VCS signing key.";
    };
  };

  identityType = lib.types.submodule {
    options = identityOptions;
  };

  conditionalIdentityType = lib.types.submodule {
    options = identityOptions // {
      repo = lib.mkOption {
        type = lib.types.str;
        description = "Repository path/pattern for conditional VCS identity.";
      };
    };
  };

  # Optionally wrap a package so the tool always runs with a fixed TZ. This is
  # useful for reproducible timestamps without forcing callers to give up direct
  # control of other Home Manager VCS options.
  mkTimeZoneAgnosticPackage =
    {
      package,
      bin,
      timeZone ? cfg.timeZone,
    }:
    if timeZone == null then
      package
    else
      pkgs.symlinkJoin {
        name = "${bin}-with-tz";
        paths = [ package ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/${bin} --set TZ ${lib.escapeShellArg timeZone}
        '';
      };

  # Git and jj express per-repository identities differently. Both are derived
  # from the same `fr.vcs.conditionalIdentities` list.
  gitConditionalIncludes = lib.map (identity: {
    condition = "gitdir:${identity.repo}";
    contents.user = {
      inherit (identity) email name;
    }
    // lib.optionalAttrs (identity.signingKey != null) {
      signingKey = identity.signingKey;
    };
  }) cfg.conditionalIdentities;

  jjScopes = lib.map (identity: {
    "--when".repositories = [ identity.repo ];
    user = {
      inherit (identity) name email;
    };
    signing = lib.optionalAttrs (identity.signingKey != null) {
      key = identity.signingKey;
    };
  }) cfg.conditionalIdentities;
in
{
  options.fr.vcs = {
    # Shared identity inputs. Tool-specific behavior stays in the upstream Home
    # Manager modules (`programs.git` and `programs.jujutsu`).
    defaultIdentity = lib.mkOption {
      type = identityType;
      description = "Default identity shared by Git and Jujutsu.";
    };

    conditionalIdentities = lib.mkOption {
      type = lib.types.listOf conditionalIdentityType;
      default = [ ];
      description = "Per-repository identities shared by Git and Jujutsu.";
    };

    timeZone = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "UTC";
      description = ''
        Time zone used by timezone-agnostic package wrappers. Set to `null` to
        return the original package unchanged.
      '';
    };

    git.enable = lib.mkEnableOption "Git identity management";
    jj.enable = lib.mkEnableOption "Jujutsu identity management";
  };

  config = lib.mkMerge [
    # Only manage identity-related Git options. Users configure all other Git
    # behavior directly through Home Manager's `programs.git` options.
    (lib.mkIf cfg.git.enable {
      programs.git = {
        enable = lib.mkDefault true;
        package = lib.mkDefault (mkTimeZoneAgnosticPackage {
          package = pkgs.git;
          bin = "git";
        });
        includes = gitConditionalIncludes;
        settings.user = {
          inherit (cfg.defaultIdentity) email name;
        }
        // lib.optionalAttrs (cfg.defaultIdentity.signingKey != null) {
          signingKey = cfg.defaultIdentity.signingKey;
        };
      };
    })

    # Only manage identity-related Jujutsu options. Users configure all other jj
    # behavior directly through Home Manager's `programs.jujutsu` options.
    (lib.mkIf cfg.jj.enable {
      programs.jujutsu = {
        enable = lib.mkDefault true;
        package = lib.mkDefault (mkTimeZoneAgnosticPackage {
          package = pkgs.jujutsu;
          bin = "jj";
        });
        settings = {
          user = {
            inherit (cfg.defaultIdentity) name email;
          };
        }
        // lib.optionalAttrs (cfg.defaultIdentity.signingKey != null) {
          signing.key = cfg.defaultIdentity.signingKey;
        }
        // lib.optionalAttrs (jjScopes != [ ]) {
          "--scope" = jjScopes;
        };
      };
    })
  ];
}
