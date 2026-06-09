let A = ./lib/agentspace.dhall

let KernelParams = ./lib/kernel-params.dhall

let kernelParamsConfig =
      { base =
        [ "8250.nr_uarts=1"
        , "console=ttyS0"
        , "earlyprintk=ttyS0"
        , "loglevel=7"
        , "systemd.show_status=1"
        , "rd.systemd.show_status=1"
        , "udev.log_level=debug"
        , "lsm=landlock,yama,bpf"
        ]
      , init = env:VIRTIE_INIT
      , regInfo = env:VIRTIE_REGINFO
      }

let kernelParams = KernelParams.toList kernelParamsConfig

let runtime =
      A.Runtime.default //
      { qemu = [ "/home/dmnt/.nix-profile/bin/qemu-system-x86_64" ]
      , netcat = [ "/home/dmnt/.nix-profile/bin/nc" ]
      , kernel = env:VIRTIE_KERNEL
      , initrd = env:VIRTIE_INITRD
      , kernelParams
      , ssh =
        [ "/home/dmnt/.nix-profile/bin/ssh"
        , "-o"
        , "ProxyCommand=systemd-ssh-proxy %h %p"
        , "-o"
        , "ProxyUseFdpass=yes"
        , "-o"
        , "CheckHostIP=no"
        , "-o"
        , "StrictHostKeyChecking=no"
        , "-o"
        , "UserKnownHostsFile=/dev/null"
        , "-o"
        , "GlobalKnownHostsFile=/dev/null"
        ]
      }

let workspace =
      A.Workspace.default //
      { hostDir = "/home/dmnt/vms/test/workspace" }

let sandbox =
      A.Sandbox.default //
      { name = "test"
      , workingDir = "/home/dmnt"
      , stateDir = "/home/dmnt/vms/test"
      , runtime
      , quiet = False
      , machine = A.Machine.default // { memory = 2048, vcpu = Some 2 }
      , workspace = Some workspace
      , networks = [ A.network "test-net" "02:02:00:00:00:10" ]
      , mounts =
        [ A.roVirtiofs "ro-store" "/nix/store" "/run/virtiofs-nix-store.sock" ""
        , A.labeledImage "/home/dmnt/vms/test/persist.img" 512 "persist"
        , A.image "/home/dmnt/vms/test/home.img" 2048
        ]
      }

in  A.Sandbox.toManifest sandbox
