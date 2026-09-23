# Microsandbox bootstrap

This standalone flake builds the small NixOS Docker image used by
microsandbox. The image enables Nix flakes and the `nix` command, installs Git
and Nix, and explicitly keeps `nixos-rebuild` available.

Build and load the image from the host:

```sh
nix build ./config/microsandbox#image
# On another architecture, select it explicitly:
# nix build ./config/microsandbox#packages.aarch64-linux.image
docker load < result

msb create --name microsandbox-nixos --init /init microsandbox-nixos:latest
msb exec microsandbox-nixos -- sh -lc 'nixos-rebuild switch --flake /path/to/your/flake#hostname'
```

Use `msb create` plus `msb exec` because `/init` keeps systemd as PID 1; a
one-shot `msb run` waits for that init process to exit.

For an interactive guest shell, use:

```sh
msb exec microsandbox-nixos -- sh -l
```

Then switch to any target configuration that is available in the guest.
Replacement configurations should import the microsandbox module so the
runtime-provided networking and unsupported-service defaults remain intact:

```nix
{
  inputs.microsandbox.url = "path:/path/to/config/microsandbox";

  outputs = { self, nixpkgs, microsandbox, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        microsandbox.nixosModules.microsandbox
        ./configuration.nix
      ];
    };
  };
}
```

Then apply it in the guest:

```sh
nixos-rebuild switch --flake /path/to/your/flake#example
```

This repository also exposes the full agent environment as a switchable target;
no separate agent OCI image is required:

```sh
mkdir -p .microsandbox-agent-persist
msb create \
  --name microsandbox-agent \
  --net public \
  --init /init \
  --mount-dir "$PWD:/workspace:ro" \
  --mount-dir "$PWD/.microsandbox-agent-persist:/persist" \
  microsandbox-nixos:latest
msb exec microsandbox-agent -- \
  nixos-rebuild switch --flake /workspace#agent-microsandbox
```

The module disables DHCP, resolvconf, the firewall, sysctl, and unsupported
serial/network services with ordinary NixOS defaults rather than image-level
masks. It also merges the NixOS CA bundle with the per-sandbox MITM CA at boot.

Images are provided for `x86_64-linux` and `aarch64-linux`, covering Linux
machines and Apple Silicon Macs. microsandbox supplies the kernel while
`/init` hands PID 1 to NixOS/systemd.
