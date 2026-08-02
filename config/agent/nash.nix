{
  myNixInputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  ashDbusProxy = myNixInputs.ash.packages.${system}."ash-dbus-proxy";
in
{
  imports = [
    ./nixos.nix
  ];

  home-manager.users.agent = {
    home.packages = [
      ashDbusProxy
    ];

    systemd.user.services.ash-dbus-proxy = {
      Unit.Description = "Ash host notification D-Bus bridge";
      Service = {
        ExecStart = "${ashDbusProxy}/bin/ash-dbus-proxy connect --listen %t/ash-dbus-proxy/bus.sock --cid 2 --managed";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
