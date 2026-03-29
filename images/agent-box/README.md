# agent-box image

This directory contains the agent-box image builder for this repo.

## Flake API

This subflake exposes:

- `lib.mkAgentBoxImage`

It does not expose `packages` or `apps` directly.

## Root flake API

From the repository root, this builder is re-exported as:

- `lib.mkAgentBoxImage`

## What it builds

`mkAgentBoxImage` returns an agent-box image artifact using the inputs from this repo plus local helpers such as `pkgs/git-hunk.nix`.

The builder is parameterized by:

- `system`
- user/group settings like `uid`, `gid`, `uname`, `gname`
- environment overrides such as `env` and `extraEnv`
- package extensions via `extraPackages`
- `workingDir`

Implementation lives in [`default.nix`](./default.nix).
