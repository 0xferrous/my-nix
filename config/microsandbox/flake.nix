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
            mkdir -p etc proc sys dev

            # microsandbox resolves the initial process before NixOS activation
            # has recreated the generated account database.
            cat > etc/passwd <<'EOF'
            root:x:0:0:root:/root:/bin/sh
            agent:x:1000:100:agent:/home/agent:/bin/sh
            EOF
            cat > etc/group <<'EOF'
            root:x:0:
            users:x:100:
            EOF
          '';
          config = {
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
