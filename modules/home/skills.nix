{
  config,
  lib,
  ...
}:

# Declarative Agent Skills. Each entry is linked whole into the shared
# `~/.agents/skills` directory, the cross-agent location that Pi, Codex, and the
# `skills` CLI read (and that a project's `.agents/skills` mirrors). Linking the
# directory rather than its files keeps a skill's scripts, references, and
# assets next to its `SKILL.md`, where the skill expects them.
let
  cfg = config.fr.skills;

  # A skill source is either a directory path or a derivation whose output is
  # that directory (the usual case for a fetched skill tree).
  sourceOf = entry: if lib.isDerivation entry then "${entry}" else toString entry;

  # Agent Skills names are lowercase alphanumerics separated by single hyphens,
  # at most 64 characters. Agents use the directory name as the skill name, so
  # validate it here instead of letting a malformed name load silently.
  validName = name: (builtins.match "[a-z0-9]+(-[a-z0-9]+)*" name) != null;

  entryChecks = lib.concatLists (
    lib.mapAttrsToList (name: entry: [
      {
        assertion = validName name && builtins.stringLength name <= 64;
        message = "fr.skills.entries.${name}: skill directory names must be lowercase letters, digits, and single hyphens, at most 64 characters.";
      }
      {
        assertion = builtins.pathExists (sourceOf entry + "/SKILL.md");
        message = "fr.skills.entries.${name}: ${sourceOf entry} has no SKILL.md.";
      }
    ]) cfg.entries
  );
in
{
  options.fr.skills = {
    enable = lib.mkEnableOption "declarative Agent Skills in the shared skills directory";

    directory = lib.mkOption {
      type = lib.types.str;
      default = ".agents/skills";
      description = ''
        Directory for the links, relative to the home directory. The default is
        the cross-agent Agent Skills location.
      '';
    };

    entries = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.package lib.types.path);
      default = { };
      example = lib.literalExpression ''
        {
          lightpanda = pkgs.lightpanda-skills;
          pandascript = "''${pkgs.lightpanda-skills}/pandascript";
        }
      '';
      description = ''
        Skills to link, keyed by the name agents see. Each value is the skill's
        directory as a path, or a derivation that outputs it. Home Manager
        refuses to replace a real directory at a link path, so remove a
        hand-installed copy (for example one added by `npx skills add`) before
        switching.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = entryChecks;

    home.file = lib.mapAttrs' (
      name: entry: lib.nameValuePair "${cfg.directory}/${name}" { source = sourceOf entry; }
    ) cfg.entries;
  };
}
