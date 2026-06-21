{
  config,
  lib,
  myNixInputs,
  pkgs,
  ...
}:
let
  frIdentity = {
    name = "0xferrous";
    email = "0xferrous@proton.me";
    signingKey = "9BD4D23DAEEA11D820751C505E0FDEF1192666A9";
  };

  keyboardBacklightDevice = "tpacpi::kbd_backlight";
  keyboardBacklightPackage = pkgs.fr-kbd-backlight.override {
    device = keyboardBacklightDevice;
  };

  voxtypePackage = myNixInputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.vulkan;
  voiceRecordToggle = pkgs.writeShellApplication {
    name = "fr-voice-record-toggle";
    runtimeInputs = [
      pkgs.libnotify
      voxtypePackage
    ];
    text = ''
      state=$(voxtype status) || state=idle
      voxtype record toggle
      if [ "$state" = recording ]; then
        notify-send -t 2000 "voice recording stopped"
      else
        notify-send -t 2000 "voice recording started"
      fi
    '';
  };
in
{
  imports = [
    ../../modules/home/symlinks.nix
    ../../modules/home/vcs.nix
    ../../modules/home/termfilechooser.nix
    ../../modules/home/programs/foundry.nix
    ../../modules/home/programs/pass.nix
    ../../modules/home/programs/direnv.nix
    ../../modules/home/programs/ssh.nix
    ./home/alacritty.nix
    ./home/atuin.nix
    ./home/editorconfig.nix
    ./home/enables.nix
    ./home/fonts.nix
    ./home/gpg.nix
    ./home/gtk.nix
    ./home/desktop-entries.nix
    ./home/dank-material-shell.nix
    ./home/helix.nix
    ./home/kitty.nix
    ./home/misc.nix
    ./home/neovim.nix
    ./home/packages.nix
    ./home/service-misc.nix
    ./home/rofi.nix
    ./home/starship.nix
    ./home/wofi.nix
    ./home/zed.nix
    ./agent-vm.nix
    myNixInputs.nix-index-database.homeModules.default
    myNixInputs.dms.homeModules.dank-material-shell
    myNixInputs.dms-plugin-registry.homeModules.default
    myNixInputs.voxtype.homeManagerModules.default
  ];

  config = {
    nixpkgs.overlays = [
      (import ../../pkgs/overlay.nix {
        inputs = myNixInputs;
        system = pkgs.stdenv.hostPlatform.system;
      })
    ];

    home.packages = with pkgs; [
      keyboardBacklightPackage
      voiceRecordToggle
      install-bin
      # myNixInputs.agentspace.packages.${pkgs.system}.virtie
      virtiofsd
      qemu
    ];

    home.sessionPath = [ "${config.home.homeDirectory}/bin" ];

    home.shellAliases = {
      virtie = "~/dev/fr/open-source/agentspace/result/bin/virtie";
    };

    programs.nushell.shellAliases = {
      virtie = "~/dev/fr/open-source/agentspace/result/bin/virtie";
    };

    fr.pass = {
      enable = true;
      stores = [
        {
          name = "fr";
          store_dir = "${config.home.homeDirectory}/dev/fr/pass";
        }
      ];
    };

    fr.direnv = {
      enable = true;
      layoutDir = {
        enable = true;
        baseDir = "${config.home.homeDirectory}/.cache/direnv/layouts";
      };
      devenv.enable = true;
      poetry.enable = true;
    };

    programs.voxtype = {
      enable = true;
      package = voxtypePackage;
      model.name = "base.en";
      service.enable = true;
      settings = {
        hotkey.enabled = false;
        whisper.language = "en";
        output = {
          mode = "type";
          fallback_to_clipboard = true;
          notification = {
            on_recording_start = false;
            on_recording_stop = false;
            on_transcription = true;
          };
        };
      };
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

    xdg.userDirs.setSessionVariables = true;

    programs.nix-index.enable = true;
  };
}
