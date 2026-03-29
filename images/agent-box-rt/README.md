# image builder for agent-box environments

This directory contains the image builder used to create environments intended to run inside [`agent-box`](https://github.com/0xferrous/agent-box).

## Flake API

This subflake exposes:

- `lib.mkAgentBoxImage`

It does not expose `packages` or `apps` directly.

## Root flake API

From the repository root, this builder is re-exported as:

- `lib.mkAgentBoxImage`

## What it builds

`mkAgentBoxImage` returns an image artifact for use with [`agent-box`](https://github.com/0xferrous/agent-box), using this repo's shared inputs plus local helpers such as `pkgs/git-hunk.nix`.

The builder is parameterized by:

- `system`
- user/group settings like `uid`, `gid`, `uname`, `gname`
- environment overrides such as `env` and `extraEnv`
- package extensions via `extraPackages`
- `workingDir`

Implementation lives in [`default.nix`](./default.nix).
