{
  lib,
  pkgs,
  myNixInputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [
    ../../modules/home/programs/direnv.nix
    ../../modules/home/programs/foundry.nix
  ];

  home = {
    username = "agent";
    homeDirectory = "/home/agent";
    stateVersion = "26.05";
    packages = [ myNixInputs.codexbar.packages.${system}.default ];
  };

  # Nushell creates a starter config when this file is absent. Remove it before
  # Home Manager links its declarative replacement.
  home.activation.removeNushellStarterConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ -e "$HOME/.config/nushell/config.nu" ] && [ ! -L "$HOME/.config/nushell/config.nu" ]; then
      rm -f "$HOME/.config/nushell/config.nu"
    fi
  '';

  programs.herdr = {
    enable = true;
    settings = {
      onboarding = false;
      theme.name = "gruvbox";
    };
  };

  systemd.user.services.herdr = {
    Unit.Description = "Herdr agent multiplexer server";
    Service = {
      ExecStart = "${pkgs.herdr}/bin/herdr server";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };

  programs.devenv = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.nix-your-shell = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.nushell = {
    enable = true;
    environmentVariables.DEVENV_SHELL_TYPE = "nu";
    settings.show_banner = false;
    # Load after the fzf/zoxide snippets supplied by Home Manager.
    extraConfig = lib.mkAfter (builtins.readFile ../shared/nushell/kitty-ssh-cwd.nu);
  };

  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
    enableZshIntegration = lib.mkForce false;
    options = [
      "--cmd"
      "cd"
    ];
  };

  fr.direnv = {
    enable = true;
    devenv.enable = true;
    poetry.enable = true;
    layoutDir = {
      enable = true;
      baseDir = "/home/agent/.cache/direnv/layouts";
    };
  };
}
