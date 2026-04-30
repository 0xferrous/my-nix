{ config, lib, ... }:
let
  cfg = config.fr.public;

  frIdentity = {
    name = "0xferrous";
    email = "0xferrous@proton.me";
    signingKey = "9BD4D23DAEEA11D820751C505E0FDEF1192666A9";
  };
in
{
  imports = [
    ../../modules/home/vcs.nix
    ../../modules/home/programs/foundry.nix
    ./alacritty.nix
    ./editorconfig.nix
    ./fonts.nix
  ];

  options.fr.public.enable = lib.mkEnableOption "public Home Manager baseline";

  config = lib.mkIf cfg.enable {
    fr.vcs.conditionalIdentities = lib.mkAfter [
      (frIdentity // { repo = "~/dev/fr/"; })
      (frIdentity // { repo = "~/dev/git/0xferrous/"; })
      (frIdentity // { repo = "~/dev/ag/0xferrous/"; })
    ];
  };
}
