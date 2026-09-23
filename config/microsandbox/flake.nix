{
  description = "Minimal NixOS bootstrap for a microsandbox guest";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      mkNixos =
        system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            "${nixpkgs}/nixos/modules/virtualisation/docker-image.nix"
            ./configuration.nix
          ];
        };
      mkImage =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          nixos = mkNixos system;
        in
        pkgs.dockerTools.buildLayeredImageWithNixDb {
          name = "microsandbox-nixos";
          tag = "latest";
          maxLayers = 125;
          contents = [ nixos.config.system.build.toplevel ];
          # Make the OCI runtime mount points writable. The NixOS module
          # carries the microsandbox contract and is imported by the bootstrap
          # configuration (and should be imported by replacement configs).
          extraCommands = ''
            rm -f etc
            mkdir -p etc proc sys dev home/agent
            chown 1000:100 home/agent
            chmod 0755 home/agent

            # microsandbox resolves the initial process before NixOS activation
            # has recreated the generated account database.
            cat > etc/passwd <<'EOF'
            root:x:0:0:root:/root:/bin/sh
            agent:x:1000:100:agent:/home/agent:/bin/sh
            EOF
            cat > etc/group <<'EOF'
            root:x:0:
            wheel:x:10:agent
            users:x:100:agent
            EOF
            cat > etc/sudoers <<'EOF'
            Defaults env_reset
            root ALL=(ALL:ALL) ALL
            %wheel ALL=(ALL:ALL) NOPASSWD: ALL
            EOF
            chmod 0440 etc/sudoers
          '';
          config = {
            # msb exec does not source /etc/profile. Give guest commands the
            # active NixOS and agent Home Manager profiles explicitly; agentd
            # prepends /.msb/scripts to this value.
            Env = [
              "PATH=/run/wrappers/bin:/run/current-system/sw/bin:/etc/profiles/per-user/agent/bin:/home/agent/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ];
            Entrypoint = [ "/init" ];
          };
        };
    in
    {
      nixosModules.microsandbox = import ./module.nix;

      nixosConfigurations = builtins.listToAttrs (
        map (system: {
          name = "microsandbox-${system}";
          value = mkNixos system;
        }) systems
      );

      packages = nixpkgs.lib.genAttrs systems (
        system:
        let
          image = mkImage system;
        in
        {
          inherit image;
          default = image;
        }
      );
    };
}
