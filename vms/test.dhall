let Types = ./lib/virtie_types.dhall

let KernelParams = ./lib/kernel-params.dhall

let kernelParams =
      KernelParams.toList
        { base = [ "8250.nr_uarts=1", "console=ttyS0", "earlyprintk=ttyS0", "loglevel=7", "systemd.show_status=1", "rd.systemd.show_status=1", "udev.log_level=debug", "lsm=landlock,yama,bpf" ]
        , init = env:VIRTIE_INIT
        , regInfo = env:VIRTIE_REGINFO
        }

in  { host_name = Some "test"
    , working_dir = Some "/home/dmnt"
    , state_dir = Some "/home/dmnt/vms/test"
    , qemu =
      { exec = Some [ "/home/dmnt/.nix-profile/bin/qemu-system-x86_64" ]
      , fwd_tunnel_exec = Some [ "/home/dmnt/.nix-profile/bin/nc", "{{.Host}}", "{{.Port}}" ]
      , user = None Text
      , seccomp = Some True
      , machine_options = None { accel : Text, pcie : Text }
      , qmp_socket = Some "qmp.sock"
      , guest_agent_socket = Some "qga.sock"
      }
    , machine = { type = Some Types.MachineType.microvm, id = None Text, memory = Some 2048, vcpu = Some 2, cpu = None Text, kvm = Some True }
    , kernel = { path = env:VIRTIE_KERNEL, initrd_path = env:VIRTIE_INITRD, params = Some kernelParams, serial = Some Types.KernelSerial.off }
    , graphics = Some { backend = Some Types.GraphicsBackend.headless }
    , ssh = { user = Some "agent", exec = Some [ "/home/dmnt/.nix-profile/bin/ssh", "-o", "ProxyCommand=systemd-ssh-proxy %h %p", "-o", "ProxyUseFdpass=yes", "-o", "CheckHostIP=no", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "GlobalKnownHostsFile=/dev/null" ], ready_socket = None Text, retry_delay = None Double, autoprovision = Some False }
    , vsock = Some { cid_range = Some { min = 0, max = 0 } }
    , mounts = Some [ { type = Some Types.MountType.virtiofs
          , tag = Some "ro-store"
          , source = "/nix/store"
          , target = Some ""
          , read_only = Some True
          , virtiofs = Some { socket = Some "/run/virtiofs-nix-store.sock", bin = Some "", args = Some ([] : List Text) }
          , `9p` = None Types.NineP
          , image = None Types.Image
          }, { type = Some Types.MountType.image
          , tag = None Text
          , source = "/home/dmnt/vms/test/persist.img"
          , target = None Text
          , read_only = Some False
          , virtiofs = None Types.Virtiofs
          , `9p` = None Types.NineP
          , image = Some
            { size = Some 512
            , fs = Some Types.Filesystem.ext4
            , format = None Types.BlockFormat
            , create = Some True
            , label = Some "persist"
            , direct = Some False
            , serial = None Text
            }
          }, { type = Some Types.MountType.image
          , tag = None Text
          , source = "/home/dmnt/vms/test/home.img"
          , target = None Text
          , read_only = Some False
          , virtiofs = None Types.Virtiofs
          , `9p` = None Types.NineP
          , image = Some
            { size = Some 2048
            , fs = Some Types.Filesystem.ext4
            , format = None Types.BlockFormat
            , create = Some True
            , label = None Text
            , direct = Some False
            , serial = None Text
            }
          } ]
    , workspace = Some { guest_dir = "/home/agent/workspace", host_dir = "/home/dmnt/vms/test/workspace", mount_cwd = False }
    , hotplug = None { mounts : Optional (List Types.Mount), networks : Optional (List Types.Network) }
    , run = Some ([] : List Types.Run)
    , networks = Some [ { id = "test-net", mac = "02:02:00:00:00:10", type = Some Types.NetworkType.user, forward = None (List Types.Forward) } ]
    , balloon = Some { enabled = Some False, deflate_on_oom = Some False, free_page_reporting = Some False, controller = None Types.BalloonController }
    , write_files = Some ([] : List Types.WriteFile)
    , notifications = Some { exec = None (List Text), states = Some ([] : List Text) }
    }
