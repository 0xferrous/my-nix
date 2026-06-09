-- This file exports a package record, so consumers can use:
--
--   let Types = ./Manifest.dhall
--
--   in  { ... } : Types.Manifest
let ForwardProto = < tcp | udp >

let ForwardFrom = < host | guest >

let MountType = < virtiofs | `9p` | image >

let NinePSecurityModel = < mapped | none | passthrough >

let NetworkType = < user >

let MachineType = < microvm >

let GraphicsBackend = < headless | gtk | cocoa >

let KernelSerial = < off | print | console >

let BlockFormat = < raw | qcow2 >

let Filesystem = < ext4 >

let Image =
      { size : Optional Natural
      , fs : Optional Filesystem
      , format : Optional BlockFormat
      , create : Optional Bool
      , label : Optional Text
      , direct : Optional Bool
      , serial : Optional Text
      }

let Forward =
      { -- proto options: tcp, udp
        -- Default: tcp
        proto : Optional ForwardProto
      , from : Optional ForwardFrom
      , host : Text
      , guest : Text
      }

let Virtiofs =
      { socket : Optional Text
      , bin : Optional Text
      , args : Optional (List Text)
      }

let NineP =
      { -- Options: mapped, none, passthrough
        -- Default: mapped
        security_model : Optional NinePSecurityModel
      }

let Mount =
      { type : Optional MountType
      , tag : Optional Text
      , source : Text
      , target : Optional Text
      , read_only : Optional Bool
      , virtiofs : Optional Virtiofs
      , `9p` : Optional NineP
      , image : Optional Image
      }

let RunVars =
      { -- Additional template variable.
        -- Example: "org.freedesktop.*"
        -- Default/behavior: absent.
        Namespace : Optional Text
      , SocketDir : Optional Text
      }

let Run =
      { -- Run commands are host-side processes managed for VM lifetime.
        -- They start before QEMU and are stopped with the VM.
        --
        -- Template values include:
        --   {{.Workspace.GuestPath}}, {{.Workspace.HostPath}},
        --   {{.StateDir}}, {{.CID}}, vars entries, and {{.Env.USER}}.
        --
        -- Default/behavior: no additional template vars.
        vars : Optional RunVars
      , exec : List Text
      }

let Network =
      { -- Stable QEMU network id.
        id : Text
      , mac : Text
      , type : Optional NetworkType
      , forward : Optional (List Forward)
      }

let BalloonController =
      { -- MiB.
        -- Default/behavior: not specified in manifest-full.toml.
        min_actual : Optional Natural
      , max_actual : Optional Natural
      , grow_below_available : Optional Natural
      , reclaim_above_available : Optional Natural
      , step : Optional Natural
      , poll_interval_seconds : Optional Natural
      , reclaim_holdoff_seconds : Optional Natural
      }

let Balloon =
      { -- Balloon device is optional because it adds a QEMU device and depends
        -- on guest driver support.
        --
        -- Default: false.
        enabled : Optional Bool
      , deflate_on_oom : Optional Bool
      , free_page_reporting : Optional Bool
      , controller : Optional BalloonController
      }

let WriteFile =
      { guest_path : Text
      , chown : Optional Text
      , text : Optional Text
      , mode : Optional Text
      , overwrite : Optional Bool
      , follow_links : Optional Bool
      , write_back : Optional Bool
      , source : Optional Text
      }

let Workspace =
      { guest_dir : Text
      , host_dir : Text
      , mount_cwd : Bool
      }

let Notifications =
      { exec : Optional (List Text)
      , states : Optional (List Text)
      }

let Manifest =
      { -- Guest name. Also used to derive default lock/state names.
        --
        -- Default: "virtie"
        host_name : Optional Text
      , working_dir : Optional Text
      , state_dir : Optional Text
      , qemu :
          { -- QEMU argv. Extra args are appended after generated args.
            --
            -- Template values include:
            --   {{.HostName}}, {{.WorkingDir}}, {{.StateDir}},
            --   {{.HostOS}}, {{.HostArch}}, {{.HostSystem}},
            --   {{.Env.USER}}
            --
            -- Default: [ "qemu-system-$host_arch" ]
            exec : Optional (List Text)
          , fwd_tunnel_exec : Optional (List Text)
          , user : Optional Text
          , seccomp : Optional Bool
          , machine_options : Optional { accel : Text, pcie : Text }
          , qmp_socket : Optional Text
          , guest_agent_socket : Optional Text
          }
      , machine :
          { -- Backend-neutral VM shape.
            --
            -- Options: microvm
            -- Default: microvm
            type : Optional MachineType
          , id : Optional Text
          , memory : Optional Natural
          , vcpu : Optional Natural
          , cpu : Optional Text
          , kvm : Optional Bool
          }
      , kernel :
          { -- Guest kernel path. Required.
            path : Text
          , initrd_path : Text
          , params : Optional (List Text)
          , serial : Optional KernelSerial
          }
      , graphics :
          Optional
            { -- Options: headless, gtk, cocoa
              -- Default: headless
              backend : Optional GraphicsBackend
            }
      , ssh :
          { -- Guest SSH user.
            --
            -- Default: "agent"
            user : Optional Text
          , exec : Optional (List Text)
          , ready_socket : Optional Text
          , retry_delay : Optional Double
          , autoprovision : Optional Bool
          }
      , vsock :
          Optional
            { -- Runtime vsock CID allocation range.
              --
              -- Default: full allocatable CID range.
              cid_range : Optional { min : Natural, max : Natural }
            }
      , mounts : Optional (List Mount)
      , workspace : Optional Workspace
      , hotplug : Optional { mounts : Optional (List Mount), networks : Optional (List Network) }
      , run : Optional (List Run)
      , networks : Optional (List Network)
      , balloon : Optional Balloon
      , write_files : Optional (List WriteFile)
      , notifications : Optional Notifications
      }

in  { ForwardProto
    , ForwardFrom
    , MountType
    , NinePSecurityModel
    , NetworkType
    , MachineType
    , GraphicsBackend
    , KernelSerial
    , BlockFormat
    , Filesystem
    , Image
    , Forward
    , Virtiofs
    , NineP
    , Mount
    , RunVars
    , Run
    , Network
    , BalloonController
    , Balloon
    , WriteFile
    , Workspace
    , Notifications
    , Manifest
    }
