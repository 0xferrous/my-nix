build-agent-image:
  NIX_CONFIG=$'extra-substituters = https://numtide.cachix.org\nextra-trusted-public-keys = numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=' nom build --accept-flake-config --impure --expr "let flake = builtins.getFlake (toString ./.); in flake.lib.mkAgentBoxImage { system = builtins.currentSystem; uid = $(id -u); gid = $(id -g); uname = \"$(id -un)\"; gname = \"$(id -gn)\"; }"

load-agent-image: build-agent-image
  docker load -i result

load-agent-image-podman: build-agent-image
  podman load -i result

flake-update-frs-nvim:
  nix flake update --flake ./pkgs/frs-nvim
  nix flake update frs-nvim
