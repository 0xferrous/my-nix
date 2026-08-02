{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fr.ash-vm-mdns;
in
{
  options.fr.ash-vm-mdns.enable = lib.mkEnableOption "Ash VM name publication through guest Avahi";

  config = lib.mkIf cfg.enable {
    # Avahi owns mDNS publication in the guest. Keep systemd-resolved from
    # running a second responder on the same interface.
    services.resolved.settings.Resolve.MulticastDNS = "no";

    services.avahi = {
      enable = true;
      ipv4 = true;
      ipv6 = false;
      openFirewall = false;
      publish = {
        enable = true;
        addresses = true;
      };
    };

    # Ash passes the VM's DNS-safe name and stable NIC MAC on the kernel command
    # line. Generate Avahi's runtime configuration from those per-VM values so
    # the immutable guest closure can publish <name>.ash.local without changing
    # the guest hostname. This runs outside avahi-daemon.service because that
    # service's ProcSubset=pid sandbox intentionally hides /proc/cmdline.
    systemd.services.ash-vm-mdns-config = {
      description = "Generate Ash VM Avahi configuration";
      requiredBy = [ "avahi-daemon.service" ];
      before = [ "avahi-daemon.service" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      unitConfig.ConditionKernelCommandLine = [
        "ash.mdns-host"
        "ash.mdns-mac"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu

        host=
        mac=
        for argument in $(${pkgs.coreutils}/bin/cat /proc/cmdline); do
          case "$argument" in
            ash.mdns-host=*) host=''${argument#ash.mdns-host=} ;;
            ash.mdns-mac=*) mac=''${argument#ash.mdns-mac=} ;;
          esac
        done

        case "$host" in
          ""|*[!a-z0-9-]*)
            echo "invalid ash.mdns-host kernel parameter: $host" >&2
            exit 1
            ;;
        esac
        case "$mac" in
          ""|*[!0-9a-f:]*)
            echo "invalid ash.mdns-mac kernel parameter: $mac" >&2
            exit 1
            ;;
        esac

        interface=
        for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
          for address_file in /sys/class/net/*/address; do
            [ -r "$address_file" ] || continue
            read -r interface_mac < "$address_file" || continue
            if [ "$interface_mac" = "$mac" ]; then
              interface=''${address_file%/address}
              interface=''${interface##*/}
              break
            fi
          done
          [ -n "$interface" ] && break
          ${pkgs.coreutils}/bin/sleep 1
        done

        if [ -z "$interface" ]; then
          echo "could not find interface for Ash MAC $mac" >&2
          exit 1
        fi

        ${pkgs.coreutils}/bin/cat > /run/avahi-daemon/ash.conf <<EOF
        [server]
        host-name=$host
        domain-name=ash.local
        use-ipv4=yes
        use-ipv6=no
        allow-interfaces=$interface
        allow-point-to-point=no

        [wide-area]
        enable-wide-area=no

        [publish]
        disable-publishing=no
        disable-user-service-publishing=yes
        publish-addresses=yes
        publish-hinfo=no
        publish-workstation=no
        publish-domain=no

        [reflector]
        enable-reflector=no
        EOF
        ${pkgs.coreutils}/bin/chmod 0644 /run/avahi-daemon/ash.conf
      '';
    };

    systemd.services.avahi-daemon = {
      requires = [ "ash-vm-mdns-config.service" ];
      after = [ "ash-vm-mdns-config.service" ];
      unitConfig.ConditionKernelCommandLine = [
        "ash.mdns-host"
        "ash.mdns-mac"
      ];
      serviceConfig.ExecStart = lib.mkForce (
        "${pkgs.avahi}/bin/avahi-daemon --syslog -f /run/avahi-daemon/ash.conf"
      );
    };
  };
}
