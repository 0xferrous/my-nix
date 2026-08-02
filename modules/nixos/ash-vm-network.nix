{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fr.ash-vm-network;
  bridge = cfg.bridgeName;
in
{
  options.fr.ash-vm-network = {
    enable = lib.mkEnableOption "private bridged network for Ash VMs";

    bridgeName = lib.mkOption {
      type = lib.types.str;
      default = "ash0";
      description = "Host bridge to which Ash VM TAP interfaces are attached.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "192.168.127.1";
      description = "IPv4 gateway address assigned to the Ash VM bridge.";
    };

    prefixLength = lib.mkOption {
      type = lib.types.ints.between 0 32;
      default = 24;
      description = "IPv4 prefix length for the Ash VM network.";
    };

    dhcpRange = lib.mkOption {
      type = lib.types.str;
      default = "192.168.127.100,192.168.127.254,255.255.255.0,12h";
      description = "dnsmasq DHCP range specification for Ash VMs.";
    };

    dnsServers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "1.1.1.1"
        "9.9.9.9"
      ];
      description = "DNS servers advertised to Ash VMs over DHCP.";
    };

    qemuPackage = lib.mkPackageOption pkgs "qemu" { };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "tun" ];

    networking.bridges.${bridge}.interfaces = [ ];
    networking.interfaces.${bridge} = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = cfg.address;
          prefixLength = cfg.prefixLength;
        }
      ];
    };

    networking.networkmanager.unmanaged = [ "interface-name:${bridge}" ];

    networking.nftables.enable = true;
    networking.nat = {
      enable = true;
      internalInterfaces = [ bridge ];
    };

    networking.firewall.interfaces.${bridge}.allowedUDPPorts = [
      67 # DHCP
      5353 # mDNS
    ];

    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        interface = bridge;
        bind-interfaces = true;
        port = 0;
        dhcp-authoritative = true;
        dhcp-range = [ cfg.dhcpRange ];
        dhcp-option = [
          "option:router,${cfg.address}"
          "option:dns-server,${lib.concatStringsSep "," cfg.dnsServers}"
        ];
      };
    };

    # Reuse libvirtd's bridge helper and ACL when it is enabled. Otherwise,
    # provide the same wrapper directly for standalone Virtle/QEMU launches.
    virtualisation.libvirtd.allowedBridges = lib.mkIf config.virtualisation.libvirtd.enable [ bridge ];

    environment.etc."qemu/bridge.conf" = lib.mkIf (!config.virtualisation.libvirtd.enable) {
      text = ''
        allow ${bridge}
      '';
    };

    security.wrappers.qemu-bridge-helper = lib.mkIf (!config.virtualisation.libvirtd.enable) {
      source = "${cfg.qemuPackage}/libexec/qemu-bridge-helper";
      owner = "root";
      group = "root";
      setuid = true;
    };

    environment.systemPackages = lib.optional (!config.virtualisation.libvirtd.enable) cfg.qemuPackage;
  };
}
