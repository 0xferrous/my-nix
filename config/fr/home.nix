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
    ../../modules/home/symlinks.nix
    ../../modules/home/vcs.nix
    ../../modules/home/termfilechooser.nix
    ../../modules/home/programs/foundry.nix
    ../../modules/home/programs/pass.nix
    ../../modules/home/programs/ssh.nix
    ../../modules/home/programs/direnv.nix
    ./home/alacritty.nix
    ./home/atuin.nix
    ./home/editorconfig.nix
    ./home/enables.nix
    ./home/fonts.nix
    ./home/gpg.nix
    ./home/gtk.nix
    ./home/desktop-entries.nix
    ./home/helix.nix
    ./home/misc.nix
    ./home/neovim.nix
    ./home/service-misc.nix
    ./home/rofi.nix
    ./home/starship.nix
    ./home/wofi.nix
    ./home/zed.nix
  ];

  config = {
    fr.pass = {
      enable = true;
      stores = [
        {
          name = "fr";
          store_dir = "${config.home.homeDirectory}/dev/fr/pass";
        }
      ];
    };

    fr.termfilechooser = {
      enable = true;
      desktop = "niri";
      tui.program = "superfile";
      terminal.command = [
        "kitty"
        "--title"
        "termfilechooser"
      ];
    };

    fr.ssh = {
      enable = true;
      identities = [
        {
          name = "gh_fr";
          identityFile = "~/.ssh/ferrous.pub";
        }
      ];
    };

    fr.vcs.conditionalIdentities = lib.mkAfter [
      (frIdentity // { repo = "~/dev/fr/"; })
      (frIdentity // { repo = "~/dev/git/0xferrous/"; })
      (frIdentity // { repo = "~/dev/ag/0xferrous/"; })
    ];
  };
}
