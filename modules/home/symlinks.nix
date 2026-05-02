{
  config,
  lib,
  ...
}:

let
  cfg = config.fr.symlinks;

  fileType = lib.types.submodule {
    options = {
      target = lib.mkOption {
        type = lib.types.str;
        description = "Path relative to `fr.symlinks.root` for the managed out-of-store symlink.";
      };

      recursive = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to link directories recursively.";
      };

      onChange = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Shell commands to run when the target changes.";
      };
    };
  };

  mkFileAttrs = lib.mapAttrs (_: file: {
    source = config.lib.file.mkOutOfStoreSymlink "${cfg.root}/${file.target}";
    inherit (file) recursive onChange;
  });
in
{
  options.fr.symlinks = {
    root = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/dev/fr/my-nix";
      description = "Root directory used for managed out-of-store symlinks.";
    };

    configFiles = lib.mkOption {
      type = lib.types.attrsOf fileType;
      default = { };
      description = "Files to install under xdg.configFile.";
    };

    dataFiles = lib.mkOption {
      type = lib.types.attrsOf fileType;
      default = { };
      description = "Files to install under xdg.dataFile.";
    };

    homeFiles = lib.mkOption {
      type = lib.types.attrsOf fileType;
      default = { };
      description = "Files to install under home.file.";
    };
  };

  config = {
    home.activation.frSymlinkChecks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      set -eu

      missing=0

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: file: ''
          if [ ! -e ${lib.escapeShellArg "${cfg.root}/${file.target}"} ]; then
            echo "fr.symlinks.configFiles.${name}: missing target ${cfg.root}/${file.target}" >&2
            missing=1
          fi
        '') cfg.configFiles
        ++ lib.mapAttrsToList (name: file: ''
          if [ ! -e ${lib.escapeShellArg "${cfg.root}/${file.target}"} ]; then
            echo "fr.symlinks.dataFiles.${name}: missing target ${cfg.root}/${file.target}" >&2
            missing=1
          fi
        '') cfg.dataFiles
        ++ lib.mapAttrsToList (name: file: ''
          if [ ! -e ${lib.escapeShellArg "${cfg.root}/${file.target}"} ]; then
            echo "fr.symlinks.homeFiles.${name}: missing target ${cfg.root}/${file.target}" >&2
            missing=1
          fi
        '') cfg.homeFiles
      )}

      if [ "$missing" -ne 0 ]; then
        echo "fr.symlinks: one or more out-of-store targets are missing" >&2
        exit 1
      fi
    '';

    xdg.configFile = mkFileAttrs cfg.configFiles;
    xdg.dataFile = mkFileAttrs cfg.dataFiles;
    home.file = mkFileAttrs cfg.homeFiles;
  };
}
