# abwrap

`abwrap` runs Nushell or another command inside a Bubblewrap filesystem and
process sandbox. It exposes the repository's development and agent tools on
`PATH` while giving every invocation an independent writable Nix local-overlay
store.

## Usage

```sh
abwrap --rw "$PWD"
abwrap --rw "$PWD" pi --model openai/gpt-5
abwrap --rw "$PWD" codex
abwrap --rw "$PWD" opencode
abwrap --env OPENAI_API_KEY --rw "$PWD" codex
```

Nushell is the default entrypoint. A positional command or
`--entrypoint COMMAND` selects another entrypoint. A Nix-provided Bash is also
available on `PATH` and mounted at `/bin/sh` for tools, including Pi's bash tool,
that assume a conventional POSIX shell path exists.

### Host access

Host files are absent unless explicitly mounted:

```sh
abwrap --ro /path/to/read-only
abwrap --rw /path/to/writable
```

The environment starts empty. Terminal and locale metadata are forwarded by
default; use `--env NAME` to forward another variable without putting its value
on the command line.

### Agent state

A directly selected agent automatically receives only its own writable state:

- `pi`: `~/.pi`
- `codex`: `~/.codex`
- `opencode`: its config, data, and state directories

A bare `abwrap` Nushell receives none. Use `--tool-state pi`,
`--tool-state codex`, `--tool-state opencode`, or `--tool-state all` when an
agent will be launched later from that shell. `--tool-state none` disables
automatic state mounting.

## Security model

`abwrap` provides filesystem, process, IPC, user, UTS, and cgroup namespace
isolation. It also:

- starts with a cleared environment;
- mounts the lower Nix store and database read-only;
- uses per-invocation temporary upper, work, and state directories;
- blocks `TIOCSTI` with a seccomp filter while preserving terminal resizing;
- disables nested user namespaces; and
- removes temporary overlay state after normal or handled-signal exits.

Networking remains shared with the host, explicitly mounted paths remain
accessible at the requested permission level, and no CPU, memory, process, or
network limits are applied. Treat it as strong protection against accidental
host modification, not as complete containment for hostile code.

## Implementation

`main.go` uses only the Go standard library, including `flag` for command-line
parsing. Nix injects the Bubblewrap path, default Nushell entrypoint, and
sandbox `PATH` through linker flags in `package.nix`. The Go process passes the
seccomp program to Bubblewrap through an inherited file descriptor and forwards
termination signals so cleanup can run.
