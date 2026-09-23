vms_base_dir := env_var_or_default("VMS_BASE_DIR", "/home/dmnt/vms")
agent_vm_artifacts_dir := "artifacts/agent-vm"
agent_vm_kernel_dir := agent_vm_artifacts_dir / "kernel"
agent_vm_initramfs_dir := agent_vm_artifacts_dir / "initramfs"
agent_vm_system_dir := agent_vm_artifacts_dir / "system"
agent_vm_closure_info_dir := agent_vm_artifacts_dir / "closure-info"
agent_vm_kernel_params_file := agent_vm_artifacts_dir / "kernel-params.dhall"

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

# Refresh the codex-desktop pin (version + SRI hash) from OpenAI's moving
# `latest/` URL.
update-codex-desktop:
  ./pkgs/codex-desktop-update.sh

# Build codex-desktop, refreshing the pin and retrying only when the pinned
# hash went stale (the `latest/` URL moves as OpenAI ships).
build-codex-desktop:
  nix build .#codex-desktop || { ./pkgs/codex-desktop-update.sh && nix build .#codex-desktop; }

# Build bb-source from a local Git checkout and branch without changing the
# checkout's working tree or the flake's pinned upstream source.
build-bb-source repo branch:
  #!/usr/bin/env bash
  set -euo pipefail
  source_repo={{quote(repo)}}
  source_branch={{quote(branch)}}
  expression='let flake = builtins.getFlake (toString ./.); source = builtins.fetchGit { ref = builtins.getEnv "BB_SOURCE_BRANCH"; url = builtins.getEnv "BB_SOURCE_REPO"; }; hash = builtins.getEnv "BB_PNPM_DEPS_HASH"; in flake.packages.${builtins.currentSystem}."bb-source".override { sourceOverride = source; pnpmDepsHashOverride = if hash == "" then null else hash; }'
  printf 'Building bb-source from %s at %s\n' "$source_repo" "$source_branch"
  run_build() {
    BB_SOURCE_REPO="$source_repo" BB_SOURCE_BRANCH="$source_branch" BB_PNPM_DEPS_HASH="$1" nix build --accept-flake-config --impure --no-link --print-out-paths --expr "$expression"
  }
  if output=$(run_build "" 2>&1); then
    printf '%s\n' "$output"
    exit 0
  fi
  pinned_failure="$output"
  printf 'Pinned pnpm dependencies do not match; calculating the branch dependency hash\n' >&2
  if output=$(run_build sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= 2>&1); then
    printf '%s\n' "$output"
    exit 0
  fi
  printf '%s\n' "$pinned_failure" >&2
  printf '%s\n' "$output" >&2
  deps_hash=$(printf '%s\n' "$output" | sed -n 's/.*got:[[:space:]]*\(sha256-[^[:space:]]*\).*/\1/p' | tail -1)
  if [ -z "$deps_hash" ]; then
    exit 1
  fi
  run_build "$deps_hash"

# Run the ChatGPT/Codex desktop app, same stale-hash self-healing as
# build-codex-desktop.
run-codex-desktop:
  nix run .#codex-desktop || { ./pkgs/codex-desktop-update.sh && nix run .#codex-desktop; }

build-agent-kernel:
  mkdir -p "{{agent_vm_artifacts_dir}}"
  nix build .#nixosConfigurations.agent.config.system.build.kernel -o "{{agent_vm_kernel_dir}}"

build-agent-initramfs:
  mkdir -p "{{agent_vm_artifacts_dir}}"
  nix build .#nixosConfigurations.agent.config.system.build.initialRamdisk -o "{{agent_vm_initramfs_dir}}"

build-agent-system:
  mkdir -p "{{agent_vm_artifacts_dir}}"
  nix build .#nixosConfigurations.agent.config.system.build.toplevel -o "{{agent_vm_system_dir}}"

switch-agent-nixos:
  nh -e sudo os switch . --hostname agent

switch-agent-hm:
  nh home switch . -c agent

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
