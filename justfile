vms_base_dir := env_var_or_default("VMS_BASE_DIR", "/home/dmnt/vms")
agent_vm_artifacts_dir := "artifacts/agent-vm"
agent_vm_kernel_dir := agent_vm_artifacts_dir / "kernel"
agent_vm_initramfs_dir := agent_vm_artifacts_dir / "initramfs"
agent_vm_system_dir := agent_vm_artifacts_dir / "system"
agent_vm_closure_info_dir := agent_vm_artifacts_dir / "closure-info"
agent_vm_kernel_params_file := agent_vm_artifacts_dir / "kernel-params.dhall"

build-agent-image:
  NIX_CONFIG=$'extra-substituters = https://numtide.cachix.org\nextra-trusted-public-keys = numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=' nom build --accept-flake-config --impure --expr "let flake = builtins.getFlake (toString ./.); in flake.lib.mkAgentBoxImage { system = builtins.currentSystem; uid = $(id -u); gid = $(id -g); uname = \"$(id -un)\"; gname = \"$(id -gn)\"; }"

load-agent-image: build-agent-image
  docker load -i result

load-agent-image-podman: build-agent-image
  podman load -i result

flake-update-frs-nvim:
  nix flake update --flake ./pkgs/frs-nvim
  nix flake update frs-nvim

# Update the core frs-nvim flake inputs while keeping standalone
# pkgs/frs-nvim's nixpkgs pin aligned with the root flake's nixpkgs pin.
flake-update-frs-nvim-wrapper-inputs:
  nix flake update nixpkgs
  set -eu; \
    nixpkgs_url="$(nix eval --impure --raw --expr 'let lock = builtins.fromJSON (builtins.readFile ./flake.lock); node = (builtins.getAttr lock.nodes.root.inputs.nixpkgs lock.nodes).locked; in "github:${node.owner}/${node.repo}/${node.rev}"')"; \
    (cd ./pkgs/frs-nvim && nix flake lock --override-input nixpkgs "$nixpkgs_url" && nix flake update nix-wrapper-modules)
  nix flake update frs-nvim

build-agent-kernel:
  mkdir -p "{{agent_vm_artifacts_dir}}"
  nix build .#nixosConfigurations.agent.config.system.build.kernel -o "{{agent_vm_kernel_dir}}"

build-agent-initramfs:
  mkdir -p "{{agent_vm_artifacts_dir}}"
  nix build .#nixosConfigurations.agent.config.system.build.initialRamdisk -o "{{agent_vm_initramfs_dir}}"

build-agent-system:
  mkdir -p "{{agent_vm_artifacts_dir}}"
  nix build .#nixosConfigurations.agent.config.system.build.toplevel -o "{{agent_vm_system_dir}}"

build-agent-closure-info:
  mkdir -p "{{agent_vm_artifacts_dir}}"
  nix build --impure --expr 'let flake = builtins.getFlake (toString ./.); system = flake.nixosConfigurations.agent; in system.pkgs.closureInfo { rootPaths = [ system.config.system.build.toplevel ]; }' -o "{{agent_vm_closure_info_dir}}"

build-agent-kernel-params:
  mkdir -p "{{agent_vm_artifacts_dir}}"
  nix eval --json .#nixosConfigurations.agent.config.system.build.toplevel.kernelParams | json-to-dhall 'List Text' --output "{{agent_vm_kernel_params_file}}"

render-vm-manifest vm-name: build-agent-kernel build-agent-initramfs build-agent-system build-agent-closure-info build-agent-kernel-params
  mkdir -p "{{vms_base_dir}}/{{vm-name}}"
  VIRTIE_KERNEL="\"$(readlink -f '{{agent_vm_kernel_dir}}/bzImage')\"" \
  VIRTIE_INITRD="\"$(readlink -f '{{agent_vm_initramfs_dir}}/initrd')\"" \
  VIRTIE_INIT="\"$(readlink -f '{{agent_vm_system_dir}}/init')\"" \
  VIRTIE_REGINFO="\"$(readlink -f '{{agent_vm_closure_info_dir}}/registration')\"" \
  VIRTIE_KERNEL_PARAMS="./{{agent_vm_kernel_params_file}}" \
  dhall-to-toml --file "./vms/{{vm-name}}.dhall" --output "{{vms_base_dir}}/{{vm-name}}/manifest.toml"

run-vm vm-name: (render-vm-manifest vm-name)
  virtie launch -vv --ssh --manifest="{{vms_base_dir}}/{{vm-name}}/manifest.toml"
