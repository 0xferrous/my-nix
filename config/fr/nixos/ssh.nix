{ config, lib, ... }:
let
  cfg = config.fr.public;
in
{
  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = lib.mkDefault true;
      settings = {
        AuthenticationMethods = lib.mkDefault "publickey";
        KbdInteractiveAuthentication = lib.mkDefault false;
        PasswordAuthentication = lib.mkDefault false;
        PubkeyAuthentication = lib.mkDefault true;
      };
    };
  };
}
