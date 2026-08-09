{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fr.iron-proxy;
  yaml = pkgs.formats.yaml { };
  proxyListen = "${cfg.listenAddress}:${toString cfg.tunnelPort}";
  yamlConfig =
    lib.recursiveUpdate
      {
        dns = {
          enabled = false;
        };
        proxy = {
          # The HTTP/HTTPS listeners cannot be disabled and default to
          # ":80"/":443", which would conflict with Caddy on this host. Bind
          # them to loopback high ports; guests only use the tunnel listener.
          http_listen = "127.0.0.1:18081";
          https_listen = "127.0.0.1:18082";
          tunnel_listen = proxyListen;
        };
        metrics = {
          listen = "127.0.0.1:19090";
        };
        tls = {
          mode = "mitm";
          ca_cert = "${cfg.stateDir}/ca.crt";
          ca_key = "${cfg.stateDir}/ca.key";
        };
        transforms = cfg.transforms;
      }
      (
        lib.optionalAttrs cfg.management.enable {
          management = {
            listen = cfg.management.listen;
            api_key_env = cfg.management.apiKeyEnv;
          };
        }
        // cfg.extraConfig
      );
  configFile = yaml.generate "iron-proxy.yaml" yamlConfig;
  caCertFile = if cfg.caCertificate != null then toString cfg.caCertificate else "";
  # The module builds its own package instance so it does not depend on the
  # flake overlay being applied to the host's nixpkgs.
  ironProxy = pkgs.callPackage ../../pkgs/iron-proxy.nix { };
in
{
  options.fr.iron-proxy = {
    enable = lib.mkEnableOption "iron-proxy egress MITM proxy on the Ash VM bridge";

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.127.1";
      description = "IPv4 address iron-proxy binds to; defaults to the Ash VM bridge gateway.";
    };

    bridgeName = lib.mkOption {
      type = lib.types.str;
      default = "ash0";
      description = "Ash VM bridge interface on which the tunnel port is opened in the host firewall.";
    };

    tunnelPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port of the tunnel listener (plain HTTP proxy, CONNECT, and SOCKS5).";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/iron-proxy";
      description = "State directory holding the generated MITM CA key pair.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Environment file with the real secret values referenced by the
        `secrets` transform (e.g. `OPENAI_API_KEY=...`). Keep it root-only;
        iron-proxy swaps proxy tokens for these values at egress and never
        writes them back to clients or logs.
      '';
    };

    caCertificate = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        CA certificate to deploy instead of auto-generating one on first boot.
        Use this when guests must trust the CA at build time: generate the CA
        once with `iron-proxy generate-ca`, commit only the public `ca.crt` to
        the flake, and place the matching private `ca.key` in the state
        directory.
      '';
    };

    transforms = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      example = [
        {
          name = "secrets";
          config = {
            secrets = [
              {
                source = {
                  type = "env";
                  var = "OPENAI_API_KEY";
                };
                inject.header = "Authorization";
                inject.formatter = "Bearer {{ .Value }}";
                rules = [
                  {
                    host = "api.openai.com";
                  }
                ];
              }
            ];
          };
        }
      ];
      description = ''
        iron-proxy transform pipeline. Configure only the `secrets` transform
        to get token injection without any egress blocking; no allowlist
        transform is added automatically.
      '';
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra iron-proxy YAML settings merged over the generated config.";
    };

    management = {
      enable = lib.mkEnableOption "iron-proxy management API (POST /v1/reload)";

      listen = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:9092";
        description = "Address the management API listens on.";
      };

      apiKeyEnv = lib.mkOption {
        type = lib.types.str;
        default = "IRON_MANAGEMENT_API_KEY";
        description = "Environment variable holding the management API bearer token.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."iron-proxy/proxy.yaml".source = configFile;

    systemd.services.iron-proxy = {
      description = "iron-proxy MITM egress proxy";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      environment = {
        IRON_LOG_LEVEL = "info";
      };
      serviceConfig = {
        ExecStart = "${ironProxy}/bin/iron-proxy -config /etc/iron-proxy/proxy.yaml";
        Restart = "on-failure";
        RestartSec = "5s";
        StateDirectory = "iron-proxy";
        StateDirectoryMode = "0700";
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ExecStartPre = pkgs.writeShellScript "iron-proxy-generate-ca" ''
          set -eu
          state_dir=${lib.escapeShellArg cfg.stateDir}
          mkdir -p "$state_dir"
          chmod 0700 "$state_dir"
          if [ -n "${lib.escapeShellArg caCertFile}" ]; then
            if [ ! -f "$state_dir/ca.key" ]; then
              echo "iron-proxy: caCertificate is set but $state_dir/ca.key is missing;" >&2
              echo "place the matching private key there (0600) before starting." >&2
              exit 1
            fi
            install -m 0600 ${lib.escapeShellArg caCertFile} "$state_dir/ca.crt"
          elif [ ! -f "$state_dir/ca.crt" ] || [ ! -f "$state_dir/ca.key" ]; then
            ${ironProxy}/bin/iron-proxy generate-ca -outdir "$state_dir"
            chmod 0600 "$state_dir/ca.key" "$state_dir/ca.crt"
          fi
        '';
      };
    };

    # Expose only the tunnel port (and nothing else) to VMs on the Ash bridge.
    networking.firewall.interfaces.${cfg.bridgeName}.allowedTCPPorts = [
      cfg.tunnelPort
    ];
  };
}
