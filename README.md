# my-nix

Public Nix files extracted from my larger setup.

Current public building blocks include:

- [`pkgs/frs-nvim`](./pkgs/frs-nvim/README.md): portable Neovim wrapper config exposed via this repo's flake `packages` and `apps`
- [`images/agent-box-rt`](./images/agent-box-rt/README.md): image builder for environments intended to run inside [`agent-box`](https://github.com/0xferrous/agent-box), exposed via this repo's flake as `lib.mkAgentBoxImage`
