# my-nix

Public Nix files extracted from my larger setup.

Current public building blocks include:

- [`pkgs/frs-nvim`](./pkgs/frs-nvim/README.md): portable Neovim wrapper config exposed via this repo's flake `packages` and `apps`
- [`images/agent-box`](./images/agent-box/README.md): agent-box image builder exposed via this repo's flake as `lib.mkAgentBoxImage`
