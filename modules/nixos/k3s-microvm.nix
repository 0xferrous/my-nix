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

        interfaces = [
          {
            type = "user";
            id = "qemu";
            mac = "02:00:00:00:00:42";
          }
        ];

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
