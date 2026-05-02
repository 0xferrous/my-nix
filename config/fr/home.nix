{ config, lib, ... }:
let
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
    ./atuin.nix
    ./editorconfig.nix
    ./enables.nix
    ./fonts.nix
    ./gtk.nix
    ./helix.nix
    ./misc.nix
    ./neovim.nix
  ];

  config = {
    fr.vcs.conditionalIdentities = lib.mkAfter [
      (frIdentity // { repo = "~/dev/fr/"; })
      (frIdentity // { repo = "~/dev/git/0xferrous/"; })
      (frIdentity // { repo = "~/dev/ag/0xferrous/"; })
    ];
  };
}
