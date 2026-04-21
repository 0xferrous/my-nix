{
  config,
  lib,
  pkgs,
  ...
}:
let
  vmName = "k3s";
  vmMem = 10240;
  vmVcpu = 4;
  kubeconfigPath = "/var/lib/k3s-vm/kubeconfig.yaml";
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/microvms/k3s/share 0755 microvm kvm -"
  ];

  microvm.vms.${vmName} = {
    pkgs = pkgs;
    config = {
      networking.hostName = vmName;
      system.stateVersion = "25.05";

      boot.kernelModules = [
        "overlay"
        "br_netfilter"
      ];

      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.bridge.bridge-nf-call-iptables" = 1;
        "net.bridge.bridge-nf-call-ip6tables" = 1;
      };

      networking.firewall.enable = false;

      microvm = {
        hypervisor = "qemu";
        optimize.enable = false;
        mem = vmMem;
        vcpu = vmVcpu;

        cpu = "host";

        # Use QEMU user-mode networking (SLIRP): the guest is behind QEMU NAT,
        # not bridged onto the host LAN. Outbound guest traffic works normally;
        # from inside the guest the host is reachable at 10.0.2.2. Inbound host
        # access only exists for explicit forwards below, and because they bind
        # to 127.0.0.1 they are reachable only from the host itself, not from
        # other LAN machines.
        interfaces = [
          {
            type = "user";
            id = "qemu";
            mac = "02:00:00:00:00:42";
          }
        ];

        # Host -> guest access through the SLIRP NAT:
        #   127.0.0.1:16443 -> guest :6443 (k3s API)
        # If you also want SSH from the host, add another forward such as
        # 127.0.0.1:2223 -> guest :22.
        forwardPorts = [
          {
            from = "host";
            proto = "tcp";
            host.address = "127.0.0.1";
            host.port = 16443;
            guest.port = 6443;
          }
        ];

        volumes = [
          {
            image = "k3s-rancher.img";
            mountPoint = "/var/lib/rancher/k3s";
            size = 20480;
            label = "k3s-rancher";
          }
        ];

        # 9p share used by the guest to write state back to the host, notably
        # the kubeconfig at `${kubeconfigPath}`.
        shares = [
          {
            proto = "9p";
            tag = "k3s-state";
            source = "share";
            mountPoint = "/var/lib/k3s-vm";
          }
        ];
      };

      services.k3s = {
        enable = true;
        role = "server";
        clusterInit = true;
        nodeName = vmName;
        disable = [ "traefik" ];
        extraFlags = [
          "--write-kubeconfig-mode=0644"
          "--write-kubeconfig=${kubeconfigPath}"
          "--tls-san=127.0.0.1"
          "--tls-san=localhost"
          "--tls-san=${vmName}"
        ];
      };

      systemd.services.k3s.serviceConfig.RequiresMountsFor = [
        "/var/lib/k3s-vm"
        "/var/lib/rancher/k3s"
      ];
    };
  };
}
